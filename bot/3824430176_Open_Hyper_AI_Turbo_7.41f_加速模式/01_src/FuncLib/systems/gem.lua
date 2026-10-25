-- One preferred carrier, short visible-drop pickup; no dedicated roaming for wards.
local X={};local teams={}
local Inventory=require(GetScriptDirectory()..'/FuncLib/systems/inventory_reservation')
local Utility=require(GetScriptDirectory()..'/FuncLib/systems/utility_slot')
local disposable={item_branches=true,item_quelling_blade=true,item_bracer=true,item_wraith_band=true,
 item_null_talisman=true,item_infused_raindrop=true,item_magic_stick=true,item_magic_wand=true}
local function Valid(b) return b and not b:IsNull() and b:IsHero() and b:IsAlive() and not b:IsIllusion() end
local function Dist(a,c) local dx,dy=a.x-c.x,a.y-c.y;return math.sqrt(dx*dx+dy*dy) end
local function Find(b,last)
 for i=0,last do local h=b:GetItemInSlot(i);if h and not h:IsNull() and h:GetName()=='item_gem' then return h,i end end
end
local function Slots(b)
 if b~=GetBot() then
  local seen=b._gemLocalStatus
  if seen and DotaTime()-seen.at<=1.5 then return seen.main,seen.bp end
  return nil
 end
 local safe=not b:WasRecentlyDamagedByAnyHero(3) and #(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE) or {})==0
 local main=Utility.Select(b,'gem',safe);local bp

 for i=6,8 do if not b:GetItemInSlot(i) then bp=i;break end end
 if main and (not b:GetItemInSlot(main) or bp) then return main,bp end
end
local function Budget(b,cost)
 local nextCost=b.currBuyingBasicItem and GetItemCost(b.currBuyingBasicItem) or 0
 return b:GetGold()>=cost+math.max(500,math.min(DotaTime()<1200 and 1200 or 600,nextCost))
end
local function Free(b)
 if b~=GetBot() then
  local seen=b._gemLocalStatus
  return Valid(b) and seen and DotaTime()-seen.at<=1.5 and seen.free or false
 end
 return Valid(b) and not b:IsInvulnerable() and not b:IsChanneling() and not b:IsUsingAbility()
  and not b:IsCastingAbility() and not b:IsStunned() and not b:IsRooted() and b:NumQueuedActions()==0
  and b:GetHealth()/math.max(1,b:GetMaxHealth())>=0.5 and b:GetActiveMode()~=BOT_MODE_RETREAT
  and not b:WasRecentlyDamagedByAnyHero(2)
  and #(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE) or {})==0
end
local function Team(b)
 local t=teams[b:GetTeam()];if not t then t={nextScan=0,nextBuy=0,purchases={},owners={},loans={}};teams[b:GetTeam()]=t end;return t
end
local function Log(b,phase,extra)
 print(string.format('[GEM_CARRIER] t=%.3f pid=%d phase=%s %s',DotaTime(),b:GetPlayerID(),phase,extra or ''))
end
-- Inspect only our own heroes and their couriers, including dead owners' stash.
local Defer
local function CloseReceipt(b,c,main)
 if GetUnitToUnitDistance(b,c)>900 or b:GetItemInSlot(main) or not Free(b)
  or not c:IsAlive() or b.SecretShop or b.SShopUser
  or c:GetHealth()/math.max(1,c:GetMaxHealth())<0.8 then return end
 local state=GetCourierState(c)
 if state==COURIER_STATE_DEAD then return end
 if state==COURIER_STATE_RETURNING_TO_BASE and (GetUnitToUnitDistance(b,c)>350 or c:GetHealth()/math.max(1,c:GetMaxHealth())<.95)then return end
 local now=DotaTime()
 if now<(b._gemReceiptNext or 0) then return end
 if b.GetNearbyTowers then
  for _,tower in ipairs(b:GetNearbyTowers(1500,true) or {}) do
   if not tower:IsNull() and tower:IsAlive() and GetUnitToUnitDistance(c,tower)<=900 then return end
  end
 end
 b._gemReceiptNext=now+3
 X.Deliver(b,c) -- same courier progress/command owner as the normal courier routine
end
local function TeamCargo()
 for i=1,5 do local a=GetTeamMember(i)
  if a and a:IsHero() and not a:IsIllusion() then
   local h,slot=Find(a,15);if h then return a,h,slot end
   local c=a.theCourier
   if c and not c:IsNull() then local cargo=Find(c,8);if cargo then return a,cargo,16 end end
   local seen=a._gemOwnedCargo
   if seen and seen.untilTime>DotaTime() and not seen.item:IsNull() and seen.slot>=9 then
    return a,seen.item,seen.slot
   end
  end
 end
end
-- Stash/courier cargo needs receiving capacity, not a persistently empty main
-- slot. The engine can refill an empty main slot without a Lua swap callback.
local function CanReceive(b)
 local pin=Inventory.Get(b)
 if pin and pin.owner=='gem'and not b:GetItemInSlot(pin.main)then return true end
 return Slots(b)~=nil
end
-- A gem cannot enter a backpack. At our own fountain, exchange the real stash
-- gem directly with an eligible main item instead of reserving an empty slot
-- that native inventory management can refill before a courier unloads.
-- No movement, queued action, shop trip, or combat decision is requested here.
function X.PrepareAtBase(b)
 if b~=GetBot() or not Valid(b) or b:DistanceFromFountain()>600
  or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility()
  or b:IsStunned() or b:IsRooted() or b:WasRecentlyDamagedByAnyHero(3)
  or #(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE) or {})>0 then return end
 local now=DotaTime();if now<(b._gemBaseNext or -1)then return end;b._gemBaseNext=now+.5
 local h,where=Find(b,15)
 if h and where<=5 then
  if b._gemBaseOrder and now>=b._gemBaseOrder.at+.5 then
   Log(b,'base_receipt_observed','slot='..where);b._gemBaseOrder=nil
  end
  return
 end
 if h and where>=9 and where<=14 then
  local main=Utility.Select(b,'gem',true);local bp
  for i=6,8 do if not b:GetItemInSlot(i)then bp=i;break end end
  if not main or b:GetItemInSlot(main)and not bp then return end
  -- Native sorting can equip a dearer backpack item over a cheaper main
  -- item. Do not let this exchange indirectly displace boots or key saves.
  local displaced=b:GetItemInSlot(main)
  if displaced then
   local cost=GetItemCost(displaced:GetName())
   for i=0,5 do local q=b:GetItemInSlot(i)
    if q and i~=main and Utility.IsProtected(q:GetName())and GetItemCost(q:GetName())<=cost then
     Defer(b,'base_slot_guard');return
    end
   end
  end
  local pin=Inventory.Get(b)
  if pin and pin.owner~='gem'then return end
  if now<(b._gemBaseSwapNext or -1)then return end;b._gemBaseSwapNext=now+2
  if pin and pin.owner=='gem'then Inventory.Release(b,'gem')end
  if Inventory.Reserve(b,main,bp or main,'gem',30)then
   Inventory.Swap(b,where,main,'gem')
   b._gemBaseOrder={at=now,item=h};b._gemCourierNext=now+6
   Log(b,'base_receipt_order','from='..where..' slot='..main)
  end
  return
 end
 local c=b.theCourier
 if not h and c and not c:IsNull()and c:IsAlive()and Find(c,8)
  and not b.SecretShop and not b.SShopUser and now>=(b._gemBaseCourierNext or -1)then
  b._gemBaseCourierNext=now+6
  if GetUnitToUnitDistance(b,c)<=900 then X.Deliver(b,c)
  else b._gemCourierNext=now+6;b:ActionImmediate_Courier(c,COURIER_ACTION_RETURN_STASH_ITEMS);Log(b,'base_cargo_return')end
 end
end
-- Called from the existing courier routine AFTER its danger/return checks.
function X.Deliver(b,c)
 if not Valid(b) or not c or c:IsNull() or not c:IsAlive() or b.SecretShop or b.SShopUser then return false end
 local stash,where=Find(b,15);local cargo=Find(c,8)
 if stash and where<=8 then return false end
 if not (stash or cargo) then return false end
 local now=DotaTime();local pin=Inventory.Get(b)
 local finalVacancy=cargo and pin and pin.owner=='gem'and not b:GetItemInSlot(pin.main)
  and GetUnitToUnitDistance(b,c)<=350 and Free(b)and now>=(b._gemFinalTransferNext or -999)
 if finalVacancy then b._gemFinalTransferNext=now+1 end
 if now<(b._gemCourierNext or -1)and not finalVacancy then return stash~=nil or cargo~=nil end
 b._gemCourierNext=now+3
 if not CanReceive(b) then Defer(b,'delivery_inventory_full');return false end
 local state=GetCourierState(c)
 if state==COURIER_STATE_DEAD then return false end
 if cargo and GetUnitToUnitDistance(b,c)<=1500 and not Free(b)then
  Defer(b,'receipt_unsafe');return false
 end
 if cargo then
  -- Turbo's courier state can lag while it is already approaching. Preserve
  -- measurable progress instead of restarting transfer every three seconds.
  local distance=GetUnitToUnitDistance(b,c)
  local watch=b._gemDeliveryWatch
  if not watch or watch.courier~=c then watch={courier=c,distance=distance,progressAt=now};b._gemDeliveryWatch=watch end
  if distance<watch.distance-75 then watch.distance=distance;watch.progressAt=now end
  if not finalVacancy and state==COURIER_STATE_DELIVERING_ITEMS and now-watch.progressAt<12 then return true end
  if not finalVacancy and watch.issuedAt and now-watch.progressAt<10 then return true end
  if not finalVacancy and watch.issuedAt and now-watch.issuedAt<6 then return true end
  if state==COURIER_STATE_DELIVERING_ITEMS then Log(b,'delivery_stalled_retry','distance='..math.floor(distance))end
  watch.issuedAt=now;watch.distance=distance;watch.progressAt=now
  b:ActionImmediate_Courier(c,COURIER_ACTION_TRANSFER_ITEMS)
  Log(b,'courier_transfer','state='..tostring(state));return true
 end
 if (state==COURIER_STATE_AT_BASE or state==COURIER_STATE_IDLE)
  and c:DistanceFromFountain()<800 and c:GetHealth()/math.max(1,c:GetMaxHealth())>=0.8 then
  local action=COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS or COURIER_ACTION_TAKE_STASH_ITEMS
  local accepted=b:ActionImmediate_Courier(c,action)
  Log(b,'courier_take_stash','slot='..where..' accepted='..tostring(accepted)..' action='..tostring(action));return true
 end
 -- Pending stash belongs to this delivery, including the trip back to fetch it.
 if stash and not cargo and state~=COURIER_STATE_RETURNING_TO_BASE then
  b:ActionImmediate_Courier(c,COURIER_ACTION_RETURN_STASH_ITEMS)
  Log(b,'fetch_return','slot='..where)
 end
 return true
end
-- Bounded history; only our own heroes and inventory are inspected.
local function Recent(list,now)
 local n=0;for i=#list,1,-1 do if now-list[i]>600 then table.remove(list,i) else n=n+1 end end;return n
end
local function Deaths(b)
 return Recent(b._gemDeaths or {},DotaTime())
end
local defence={item_glimmer_cape=true,item_force_staff=true,item_hurricane_pike=true,
 item_black_king_bar=true,item_aeon_disk=true,item_ghost=true,item_cyclone=true,item_wind_waker=true}
local function Equipped(b)
 if b:GetMaxHealth()>=1400 then return true end
 for i=0,5 do local h=b:GetItemInSlot(i);if h and defence[h:GetName()] then return true end end
 return false
end
local function Ready(b,cost)
 if not Free(b) or b._guardTravel or b:GetHealth()/math.max(1,b:GetMaxHealth())<(DotaTime()<1200 and 0.65 or 0.55) then return false,'unsafe' end
 if require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(b) then return false,'base_threat' end
 local delay=Deaths(b)>=2 and (DotaTime()<1200 and 180 or 60) or 30
 if b._gemLastDeath and DotaTime()-b._gemLastDeath<delay then return false,'recent_deaths' end
 if not Equipped(b) then return false,'survival_equipment' end
 if not Budget(b,cost) then return false,'item_budget' end
 return true
end
Defer=function(b,reason)
 if DotaTime()>=(b._gemDeferNext or 0) then b._gemDeferNext=DotaTime()+30;Log(b,'purchase_deferred','reason='..reason) end
end
function X.ObserveLife(b)
 if not b or not b:IsHero() or b:IsIllusion() then return end
 local t=Team(b);local alive=b:IsAlive();local pid=b:GetPlayerID()
 if b==GetBot() then
  local main,bp=Slots(b)
  b._gemLocalStatus={at=DotaTime(),free=Free(b),main=main,bp=bp,queued=b:NumQueuedActions()}
 end
 if b._gemWasAlive and not alive then
  b._gemCargoSince=nil;b._gemDeliveryWatch=nil;b._gemReceiptNext=nil
  Inventory.Release(b,'gem') -- discard the delivery pin before the next life
  b._gemDeaths=b._gemDeaths or {};table.insert(b._gemDeaths,DotaTime());Recent(b._gemDeaths,DotaTime());b._gemLastDeath=DotaTime()
  if b._gemWasCarrier then b._gemOwnedCargo=nil
  elseif b._gemOwnedCargo then b._gemOwnedCargo.untilTime=DotaTime()+180 end
 end
 if b._gemWasAlive and not alive and (b._gemWasCarrier or t.buyer==pid) then
  t.repurchaser=t.buyer or pid;t.nextBuy=0
  if b._gemWasCarrier then
   t.losses=t.losses or {};table.insert(t.losses,DotaTime())
   local n=Recent(t.losses,DotaTime());t.lossUntil=DotaTime()+(n>=2 and 180 or 30)
   Log(b,'gem_lost_on_death','recent_losses='..n)
  end
  Log(b,'carrier_death','repurchaser='..t.repurchaser)
 end
 if b._gemWasAlive==false and alive and t.repurchaser==pid then
  t.nextBuy=0;b._gemSupplyNext=nil;Log(b,'respawn_shop_check')
 end
 b._gemWasAlive=alive
 if alive then
  local delivered,where=Find(b,15)
  local ownCourier=b.theCourier
  local ownCargo=ownCourier and not ownCourier:IsNull() and Find(ownCourier,8)
  b._gemOwnedCargo=delivered and {item=delivered,slot=where,untilTime=DotaTime()+15}
   or ownCargo and {item=ownCargo,slot=16,untilTime=DotaTime()+15} or nil
  if delivered and where~=b._gemDeliverySlot then
   b._gemDeliverySlot=where;Log(b,'inventory_observed','slot='..where)
  elseif not delivered then b._gemDeliverySlot=nil end
  if delivered and where<=8 and t.pending and t.pending.pid==pid then t.pending=nil end
  local h=Find(b,8);b._gemWasCarrier=h~=nil
  -- Keep item identity across a death/drop; never infer ownership of an unrelated gem.
  if h and t.buyer==pid and not t.owners[h] then
   t.owners[h]={pid=pid,epoch=t.purchases[pid] or 0}
  end
 end
end
function X.HasTrueSightAt(b,loc)
 for i=1,5 do local a=GetTeamMember(i)
  if Valid(a) then local h=Find(a,5)
   if h then
    local radius=h.GetSpecialValueInt and h:GetSpecialValueInt('radius') or 0
    if radius<=0 then radius=900 end
    if Dist(a:GetLocation(),loc)<=radius then return true end
   end
  end
 end
 return false
end
-- A revealed ward is a short local opportunity, never a separate ward-hunting route.
function X.CanDeward(b,ward)
 if not Valid(b) or not ward or ward:IsNull() or not ward:IsAlive() or not ward:CanBeSeen()
  or ward:GetTeam()==b:GetTeam() then return false end
 local name=ward:GetUnitName()
 if name~='npc_dota_observer_wards' and name~='npc_dota_sentry_wards' then return false end
 if not Free(b) or b._guardTravel or b:IsDisarmed() or b:GetActiveMode()==BOT_MODE_ATTACK
  or b:GetActiveMode()==BOT_MODE_ROSHAN or DotaTime()<(b._gemPickupUntil or -1) then return false end
 if require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(b) then return false end
 if Dist(b:GetLocation(),ward:GetLocation())>math.min(900,b:GetAttackRange()+250) then return false end
 local target=b:GetAttackTarget()
 if target and not target:IsNull() and target:IsAlive() and (target:IsHero() or target:IsBuilding()) then return false end
 -- Do not approach a ward inside a known nearby enemy tower's firing range.
 for _,tower in ipairs(b:GetNearbyTowers(1600,true) or {}) do
  if tower and not tower:IsNull() and tower:IsAlive() then
   local radius=tower:GetAttackRange()+150
   if Dist(tower:GetLocation(),b:GetLocation())<=radius
    or Dist(tower:GetLocation(),ward:GetLocation())<=radius then return false end
  end
 end
 return true
end
function X.ShouldDeward(b,ward)
 local t=Team(b);t.wards=t.wards or {}
 if not ward or ward:IsNull() or not ward:IsAlive() then
  if ward then
   local old=t.wards[ward]
   if old then Log(old,not ward:IsNull() and not ward:IsAlive() and 'ward_dead_observed' or 'ward_handle_removed') end
   t.wards[ward]=nil
  end;return false
 end
 local owner=t.wards[ward]
 if owner and not X.CanDeward(owner,ward) then t.wards[ward]=nil;owner=nil end
 if not owner then
  local best=nil
  for i=1,5 do local a=GetTeamMember(i)
   if a and IsPlayerBot(a:GetPlayerID()) and X.CanDeward(a,ward) then
    local d=Dist(a:GetLocation(),ward:GetLocation())
    if not best or d<best or d==best and a:GetPlayerID()<owner:GetPlayerID() then owner=a;best=d end
   end
  end
  t.wards[ward]=owner
 end
 return owner==b and X.CanDeward(b,ward)
end
function X.AttackWard(b,ward)
 if not X.ShouldDeward(b,ward) then return false end
 if b:GetAttackTarget()~=ward or DotaTime()>=(b._gemWardOrderNext or 0) then
  b:Action_AttackUnit(ward,false);b._gemWardOrderNext=DotaTime()+0.6
  if DotaTime()>=(b._gemWardLogNext or 0) then
   b._gemWardLogNext=DotaTime()+2;Log(b,'ward_attack_order','target='..ward:GetUnitName())
  end
 end
 return true
end
function X.Prepare(b)
 if not Valid(b) then Inventory.Release(b,'gem');return end
 if DotaTime()<(b._gemPrepareNext or -1) then return end;b._gemPrepareNext=DotaTime()+0.5
 Inventory.Observe(b)
 local wardTeam=Team(b)
 for ward,actor in pairs(wardTeam.wards or {}) do
  if actor==b and (ward:IsNull() or not ward:IsAlive() or not ward:CanBeSeen()) then
   Log(b,not ward:IsNull() and not ward:IsAlive() and 'ward_dead_observed' or 'ward_target_lost')
   wardTeam.wards[ward]=nil
  end
 end
 local h,slot=Find(b,8);local pin=Inventory.Get(b)
 if not h then
  b._gemMainObserved=nil
  local stored,where=Find(b,15)
  local courier=b.theCourier
  local travelling=courier and not courier:IsNull() and courier:IsAlive() and Find(courier,8)
  if stored and where>=9 or travelling then
   wardTeam.pending={pid=b:GetPlayerID(),owner=b,untilTime=DotaTime()+180}
   -- Turbo couriers cannot unload this gem into an empty backpack when all
   -- main slots are full. Make room only on the final safe approach, then
   -- protect that vacancy from ordinary inventory sorting until receipt.
   if travelling and GetUnitToUnitDistance(b,courier)<=1500 then
    if pin and pin.owner=='gem' and not Free(b)then
     Inventory.Release(b,'gem');Log(b,'receipt_yield_combat')
    elseif pin and pin.owner=='gem' then
     Inventory.Renew(b,'gem',DotaTime()+30)
     -- A command is not proof of a swap. Retry a still occupied receiving
     -- slot only when the same cheap item remains eligible and backpack free.
     if b:GetItemInSlot(pin.main)and (b._gemReceiveReversals or 0)>=3 then
      b._gemReceiptBackoff=DotaTime()+30;b._gemReceiveReversals=0;Inventory.Release(b,'gem');Log(b,'receipt_reversal_backoff');return
     end
     if b:GetItemInSlot(pin.main) and not b:GetItemInSlot(pin.bp)
      and Free(b) and not b:WasRecentlyDamagedByAnyHero(3)
      and DotaTime()>=(b._gemReceiveRetry or 0) then
      local eligible=Utility.Select(b,'gem',true)
      if eligible==pin.main then
       b._gemReceiveReversals=(b._gemReceiveReversals or 0)+1
       b._gemReceiveRetry=DotaTime()+0.75
       Inventory.Swap(b,pin.main,pin.bp,'gem')
      else Inventory.Release(b,'gem') end
     end
     CloseReceipt(b,courier,pin.main)
    elseif not pin and DotaTime()>=(b._gemReceiptBackoff or -1)and Free(b) and not b:WasRecentlyDamagedByAnyHero(3)
     and DotaTime()-(b.itemSwapTime or -999)>0.5 then
     local main,bp=Slots(b)
     if main and (not b:GetItemInSlot(main) or bp) and Inventory.Reserve(b,main,bp or main,'gem',30) then
      if b:GetItemInSlot(main) then Inventory.Swap(b,main,bp,'gem') end
      b._gemReceiveRetry=DotaTime()+0.75
      Log(b,'receive_slot_prepared','slot='..main)
      CloseReceipt(b,courier,main)
     end
    end
   elseif pin and pin.owner=='gem' then Inventory.Release(b,'gem') end
   b._gemCargoSince=b._gemCargoSince or DotaTime()
   if DotaTime()-b._gemCargoSince>=30 and DotaTime()>=(b._gemDeliveryDiagNext or 0) then
    b._gemDeliveryDiagNext=DotaTime()+30
    local main,bp=Slots(b)
    Log(b,'delivery_wait','seconds='..math.floor(DotaTime()-b._gemCargoSince)..' distance='..(courier and not courier:IsNull() and math.floor(GetUnitToUnitDistance(b,courier)) or -1)..' main='..tostring(main)..' bp='..tostring(bp)..' free='..tostring(Free(b))..' stash='..tostring(where)..' cargo='..tostring(travelling~=nil)..' state='..tostring(courier and GetCourierState(courier)))
   end
   return
  end
  local handoff=Team(b).handoff
  if handoff and handoff.receiver==b and DotaTime()<=handoff.untilTime then return end
  local pickup=Team(b).pickup
  if pickup and pickup.pid==b:GetPlayerID() and DotaTime()<=pickup.untilTime then return end
  local pending=wardTeam.pending
  if pin and pin.owner=='gem' and pending and pending.pid==b:GetPlayerID() and DotaTime()<=pending.untilTime then
   Inventory.Renew(b,'gem',pending.untilTime);return
  end
  if pin and pin.owner=='gem' then Inventory.Release(b,'gem');Log(b,'lost_or_removed') end
  return
 end
 b._gemCargoSince=nil;b._gemDeliveryWatch=nil;b._gemReceiveReversals=nil;b._gemReceiptBackoff=nil
 if slot<=5 then
  if pin and pin.owner=='gem'then Inventory.Release(b,'gem')end
  if not b._gemMainObserved then b._gemMainObserved=true;Log(b,'main_observed','slot='..slot)end
  return
 end
 b._gemMainObserved=nil
 if pin and pin.owner~='gem' then return end
 if Free(b) and DotaTime()-(b.itemSwapTime or -999)>0.5 and DotaTime()>=(b._gemPromoteNext or 0) then
  -- Swap the actual received gem directly. No empty-slot placeholder and no
  -- eleven-second retry loop when native inventory sorting reverses a swap.
  local main=Utility.Select(b,'gem',true)
  if main then
   b._gemPromoteNext=DotaTime()+1.5
   if pin and pin.owner=='gem' and (pin.main~=main or pin.bp~=slot) then Inventory.Release(b,'gem');pin=nil end
   if pin and pin.owner=='gem' then Inventory.Renew(b,'gem',DotaTime()+30)
   else Inventory.Reserve(b,main,slot,'gem',30) end
   Inventory.Swap(b,slot,main,'gem')
   if DotaTime()>=(b._gemPromoteLog or 0) then
    b._gemPromoteLog=DotaTime()+5;Log(b,'promote_order','from='..slot..' slot='..main)
   end
  end
 end
end
function X.Supply(b,pos,known)
 local now=DotaTime();local t=Team(b)
 if t.handoff or now<900 or not Valid(b) or pos<4 or b:GetLevel()<(now<1200 and 15 or 12) then return end
 if now<(b._gemSupplyNext or -1) then return end;b._gemSupplyNext=now+1
 local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
 local owner,cargo,where=TeamCargo()
 if cargo then
  t.repurchaser=nil
  if where<=8 then t.pending=nil
  else t.pending={pid=owner:GetPlayerID(),owner=owner,untilTime=now+180} end
  return
 end
 local alive,core=0,0
 for i=1,5 do local a=GetTeamMember(i)
  if a and a:IsHero() and not a:IsIllusion() then
   local owned,where=Find(a,15)
   if owned then t.repurchaser=nil;if where<=8 then t.pending=nil end;return end
  end
  if Valid(a) then alive=alive+1;if Fu.GetPosition(a)<=3 and a:GetLevel()>=15 then core=core+1 end end
 end
 if t.pending then
  if t.pending.owner and not t.pending.owner:IsAlive() then return end
  if now<=t.pending.untilTime then return end
  Log(b,'delivery_not_observed','buyer='..t.pending.pid);t.pending=nil
 end
 if now<t.nextBuy then return end
 if now<(t.lossUntil or 0) then Defer(b,'recent_gem_losses');return end
 if alive<(now<1200 and 3 or 2) or core<1 then Defer(b,'team_not_ready');return end
 local cost=GetItemCost('item_gem')
 if cost<=0 or GetItemStockCount and GetItemStockCount('item_gem')<=0 then Defer(b,'shop_stock');return end
 local ownReady,ownReason=Ready(b,cost)
 if not Slots(b) then ownReady,ownReason=false,'no_safe_slot'
 elseif Inventory.Get(b) then ownReady,ownReason=false,'slot_reserved' end
 b._gemPurchaseStatus={at=now,ready=ownReady,reason=ownReason}
 local candidate,score=nil,nil
 for i=1,5 do local a=GetTeamMember(i)
  if Valid(a) and IsPlayerBot(a:GetPlayerID()) and Fu.GetPosition(a)>=4
   and a:GetLevel()>=(now<1200 and 15 or 12) then
   local seen=a._gemPurchaseStatus
   local ready=seen and now-seen.at<=1.5 and seen.ready
   local reason=seen and seen.reason or 'no_owner_report'
   if ready then
    local value=a:GetHealth()/math.max(1,a:GetMaxHealth())*1000+a:GetMaxHealth()*0.1-Deaths(a)*250
    if t.repurchaser==a:GetPlayerID() then value=value+500 end
    if t.buyer==a:GetPlayerID() then value=value+200 end
    value=value-a:GetPlayerID()*0.01
    if not score or value>score then candidate,score=a,value end
   elseif a==b then Defer(b,reason) end
  end
 end
 if candidate~=b then return end
 for _,d in ipairs(GetDroppedItemList() or {}) do
  if d.item and not d.item:IsNull() and d.item:GetName()=='item_gem'
   and IsLocationVisible and IsLocationVisible(d.location) and Dist(b:GetLocation(),d.location)<1800 then return end
 end
 -- Verify a usable eventual slot, but keep current gear equipped until arrival.
 local main,bp=Slots(b);if not main then Defer(b,'no_safe_slot');return end
 t.nextBuy=now+5
 local result=b:ActionImmediate_PurchaseItem('item_gem')
 if result==PURCHASE_ITEM_SUCCESS then
  t.buyer=b:GetPlayerID();t.nextBuy=now+30
  t.purchases[t.buyer]=(t.purchases[t.buyer] or 0)+1
  t.pending={pid=t.buyer,owner=b,untilTime=now+180}
  Log(b,'purchase_success','epoch='..t.purchases[t.buyer])
 end
 if result~=PURCHASE_ITEM_SUCCESS then Inventory.Release(b,'gem') end
 Log(b,'purchase_order','result='..tostring(result))
end

local function DropExists(s)
 for _,d in ipairs(GetDroppedItemList() or {}) do if d.item==s.item then return true end end
 return false
end
-- Returning a rescued gem is optional: no meeting route or persistent task takeover.
local function Claim(t,h)
 local o=t.owners[h]
 if o and not t.loans[h] then t.loans[h]={owner=o.pid,epoch=o.epoch,nextTry=0} end
end
local function Member(pid)
 for i=1,5 do local a=GetTeamMember(i);if a and a:GetPlayerID()==pid then return a end end
end
local function SafeMeeting(b)
 if not Free(b) or b._guardTravel then return false end
 local target=b:GetAttackTarget()
 if target and not target:IsNull() and target:IsAlive() then return false end
 if require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(b) then return false end
 local pin=Inventory.Get(b);return not pin or pin.owner=='gem'
end
local function EmptyMain(b)
 for i=0,5 do if not b:GetItemInSlot(i) then return i end end
 -- A return is less urgent than a rescue: do not swap any equipment for the exchange.
end
local function FinishReturn(t,s,phase)
 Inventory.Release(s.receiver,'gem')
 s.receiver._gemPickupUntil=nil;s.donor._gemPickupUntil=nil
 t.handoff=nil;t.pickup=nil
 Log(s.donor,phase,'receiver='..s.receiver:GetPlayerID())
end
local function Handoff(b)
 local t=Team(b);local now=DotaTime();local s=t.handoff
 if s then
  local received=Find(s.receiver,8)
  if received==s.item then
   t.loans[s.item]=nil;FinishReturn(t,s,'return_observed');return false
  end
  if Find(s.donor,8)==s.item then
   -- Drop was asynchronous or failed; no walking and no indefinite waiting.
   if now>s.untilTime then FinishReturn(t,s,'return_drop_timeout') end
   return false
  end
  local drop=nil
  for _,d in ipairs(GetDroppedItemList() or {}) do if d.item==s.item then drop=d;break end end
  local canReceive=now<=s.untilTime and SafeMeeting(s.receiver)
   and not Find(s.receiver,15) and (t.purchases[s.receiver:GetPlayerID()] or 0)==s.epoch
   and not s.receiver:GetItemInSlot(s.main)
  if not canReceive or not drop then
   s.receiver._gemPickupUntil=nil;s.donor._gemPickupUntil=nil
   -- Recover only when already in reach and safe. Danger immediately restores normal combat.
   if drop and b==s.donor and SafeMeeting(b) and EmptyMain(b)
    and Dist(b:GetLocation(),drop.location)<=120 then
    b:Action_PickUpItem(s.item)
    Log(b,'return_reclaim_order');FinishReturn(t,s,'return_aborted');b._gemPickupUntil=now+0.25;return true
   end
   if not drop or b==s.donor or now>s.untilTime+0.3 then FinishReturn(t,s,'return_aborted') end
   return false
  end
  if b==s.receiver and Dist(b:GetLocation(),drop.location)<=120 and now>=s.nextOrder then
   s.nextOrder=now+0.25;b:Action_PickUpItem(s.item);b._gemPickupUntil=now+0.25
   Log(b,'return_pickup_order');return true
  end
  return false
 end
 if now<(b._gemReturnNext or 0) then return false end;b._gemReturnNext=now+0.5
 local h=Find(b,5);local loan=h and t.loans[h]
 if not loan or loan.owner==b:GetPlayerID() or now<loan.nextTry then return false end
 local receiver=Member(loan.owner)
 if not receiver or not IsPlayerBot(receiver:GetPlayerID()) then return false end
 if (t.purchases[loan.owner] or 0)~=loan.epoch or Find(receiver,15) then
  t.loans[h]=nil;Log(b,'return_skip_rebought');return false
 end
 if not SafeMeeting(b) or not SafeMeeting(receiver) or Dist(b:GetLocation(),receiver:GetLocation())>100 then return false end
 local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
 if Fu.GetPosition(receiver)<4 or not Equipped(receiver) or Deaths(receiver)>=2 and Deaths(receiver)>Deaths(b)
  or receiver._gemLastDeath and now-receiver._gemLastDeath<30 then
  if now>=(loan.nextLog or 0) then loan.nextLog=now+30;Log(b,'return_keep_carrier','receiver='..loan.owner) end
  return false
 end
 local main=EmptyMain(receiver);if not main or Inventory.Get(receiver) then return false end
 if not Inventory.Reserve(receiver,main,main,'gem',2) then return false end
 loan.nextTry=now+30
 t.handoff={donor=b,receiver=receiver,item=h,main=main,epoch=loan.epoch,untilTime=now+1,nextOrder=now}
 Inventory.Release(b,'gem')
 b:Action_DropItem(h,receiver:GetLocation());b._gemPickupUntil=now+0.25
 Log(b,'return_drop_order','receiver='..loan.owner);return true
end
local function ReleasePickup(t,s,reason)
 if t.pickup~=s then return end
 local owner=Member(s.pid)
 if owner then owner._gemPickupUntil=nil;Inventory.Release(owner,'gem');Log(owner,reason)end
 t.dropRetry=t.dropRetry or{};local old=t.dropRetry[s.item]
 local attempts=(old and old.attempts or 0)+1
 t.dropRetry[s.item]={at=DotaTime(),untilTime=DotaTime()+math.min(60,10+attempts*5),attempts=attempts}
 t.pickup=nil
end
local function State(b)
 local t=Team(b);local now=DotaTime();local s=t.pickup
 if t.handoff then return nil end
 if s and(now>s.untilTime or not Valid(Member(s.pid)))then ReleasePickup(t,s,'pickup_timeout_backoff');s=nil end
 if s and s.pid==b:GetPlayerID() then
  if Find(b,8)==s.item then t.pickup=nil;if t.dropRetry then t.dropRetry[s.item]=nil end;Log(b,'pickup_observed');return nil end
  local Guard=require(GetScriptDirectory()..'/FuncLib/systems/highground_guard')
  if Guard.HasActiveThreat(b) then ReleasePickup(t,s,'pickup_yield_defence');return nil end
  if now>s.untilTime or not Free(b) or not DropExists(s)
   or not IsLocationVisible or not IsLocationVisible(s.loc) then ReleasePickup(t,s,'pickup_release_backoff');return nil end
  return s
 end
 if s and now<=s.untilTime then return nil end
 if t.dropRetry then for item,r in pairs(t.dropRetry)do if now-r.at>180 then t.dropRetry[item]=nil end end end
 if now<(b._gemPickupScan or -1) then return nil end;b._gemPickupScan=now+0.5
 if not Free(b) or Find(b,8) or Inventory.Get(b) or not Slots(b) then return nil end
 local Guard=require(GetScriptDirectory()..'/FuncLib/systems/highground_guard')
 if Guard.HasActiveThreat(b) then return nil end
 for _,d in ipairs(GetDroppedItemList() or {}) do
  if d.item and not d.item:IsNull() and d.item:GetName()=='item_gem'
   and(not t.dropRetry or not t.dropRetry[d.item]or now>=t.dropRetry[d.item].untilTime)
   and IsLocationVisible and IsLocationVisible(d.location) and Dist(b:GetLocation(),d.location)<1400 then
   local chosen=true;local dist=Dist(b:GetLocation(),d.location)
   for i=1,5 do local a=GetTeamMember(i)
    if a and a~=b and IsPlayerBot(a:GetPlayerID()) and Free(a) and not Find(a,8) and not Inventory.Get(a) and Slots(a) then
     local ad=Dist(a:GetLocation(),d.location)
     if ad<dist or ad==dist and a:GetPlayerID()<b:GetPlayerID() then chosen=false;break end
    end
   end
   if chosen then Claim(t,d.item);t.pickup={pid=b:GetPlayerID(),item=d.item,loc=d.location,untilTime=now+8,nextOrder=now}
    Log(b,'pickup_assigned','distance='..math.floor(dist));return t.pickup
   end
  end
 end
end
-- During fighting, only a gem already within pickup reach gets this brief priority.
-- No movement is acquired to run through the fight; casts, retreat and base defence win.
local function NearEligible(b,loc)
 local seen=b and b._gemLocalStatus
 local queued
 if b==GetBot() then queued=b:NumQueuedActions()
 elseif seen and DotaTime()-seen.at<=1.5 then queued=seen.queued
 else return false end
 if not Valid(b) or not IsPlayerBot(b:GetPlayerID()) or b:IsInvulnerable() or b:IsChanneling()
  or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted()
  or queued>0 or b:GetHealth()/math.max(1,b:GetMaxHealth())<0.35
  or b:GetActiveMode()==BOT_MODE_RETREAT or Dist(b:GetLocation(),loc)>120 or Find(b,8) or Inventory.Get(b) then return false end
 return Slots(b)~=nil
end
function X.TryImmediate(b)
 if DotaTime()<0 then return false end
 if Handoff(b) then return true end
 if b._gemPickupUntil and DotaTime()<b._gemPickupUntil then
  if Valid(b) and b:GetHealth()/math.max(1,b:GetMaxHealth())>=0.25 and b:GetActiveMode()~=BOT_MODE_RETREAT
   and not require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(b) then return true end
  b._gemPickupUntil=nil
 end
 if DotaTime()<(b._gemImmediateNext or -1) then return false end;b._gemImmediateNext=DotaTime()+0.15
 if not Valid(b) then return false end
 local Guard=require(GetScriptDirectory()..'/FuncLib/systems/highground_guard')
 if Guard.HasActiveThreat(b) then return false end
 local handoff=Team(b).handoff
 for _,d in ipairs(GetDroppedItemList() or {}) do
  if d.item and not d.item:IsNull() and d.item:GetName()=='item_gem'
   and (not handoff or d.item~=handoff.item)
   and IsLocationVisible and IsLocationVisible(d.location) and NearEligible(b,d.location) then
   local closest=true;local dist=Dist(b:GetLocation(),d.location)
   for i=1,5 do local a=GetTeamMember(i)
    if a and a~=b and NearEligible(a,d.location) then
     local ad=Dist(a:GetLocation(),d.location)
     if ad<dist or ad==dist and a:GetPlayerID()<b:GetPlayerID() then closest=false;break end
    end
   end
   if closest then
    local main,bp=Slots(b)
    if b:GetItemInSlot(main) then
     if not Inventory.Reserve(b,main,bp,'gem',12) then return false end
     -- This single rescue exchange may occur under fire. It never moves boots or critical gear.
     b._gemCombatSwap=true;local ok,err=pcall(Inventory.Swap,b,main,bp,'gem');b._gemCombatSwap=nil
     if not ok then Inventory.Release(b,'gem');error(err) end
     if b:GetItemInSlot(main) then Inventory.Release(b,'gem');return false end
     Log(b,'rescue_slot_freed','main='..main..' backpack='..bp)
    else Inventory.Reserve(b,main,main,'gem',12) end
    local t=Team(b);Claim(t,d.item);t.pickup={pid=b:GetPlayerID(),item=d.item,loc=d.location,untilTime=DotaTime()+1,nextOrder=DotaTime()+0.25}
    b:Action_PickUpItem(d.item);b._gemPickupUntil=DotaTime()+0.25
    Log(b,'near_rescue_order','distance='..math.floor(dist));return true
   end
  end
 end
 return false
end
function X.GetDesire(b) return State(b) and 0.96 or 0 end
function X.Think(b)
 local s=State(b);if not s then return false end
 if DotaTime()<s.nextOrder then return true end;s.nextOrder=DotaTime()+0.5
 local main,bp=Slots(b);if not main then return false end
 if b:GetItemInSlot(main) then
  local pin=Inventory.Get(b)
  if pin and pin.owner~='gem'or DotaTime()-(b.itemSwapTime or -999)<=.6 then return false end
  if not Inventory.Reserve(b,main,bp,'gem',12) then return false end
  Inventory.Swap(b,main,bp,'gem')
  if b:GetItemInSlot(main) then Inventory.Release(b,'gem');return false end
 end
 if Dist(b:GetLocation(),s.loc)>120 then b:Action_MoveToLocation(s.loc)
 else b:Action_PickUpItem(s.item);Log(b,'pickup_order') end
 return true
end
return X
