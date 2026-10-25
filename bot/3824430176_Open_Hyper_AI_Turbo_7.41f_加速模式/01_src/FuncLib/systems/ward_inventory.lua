-- Inventory preparation only: never acquires movement or changes a team task.
local X={}
local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
local P=require(GetScriptDirectory()..'/FuncLib/systems/ward_plan')
local Inventory=require(GetScriptDirectory()..'/FuncLib/systems/inventory_reservation')
local Utility=require(GetScriptDirectory()..'/FuncLib/systems/utility_slot')
local function V(b)return b and not b:IsNull()and b:IsHero()and not b:IsIllusion()end
local function Kind(h)
 if not h or h:IsNull()then return nil end
 local n=h:GetName();if n=='item_ward_observer'then return'obs'end
 if n=='item_ward_sentry'then return'sentry'end
 if n=='item_ward_dispenser'then return h:GetCurrentCharges()>0 and'obs'or h:GetSecondaryCharges()>0 and'sentry'or nil end
end
local function Log(b,phase,why)
 print('[WARD_INVENTORY] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase='..phase..' detail='..(why or'none'))
end
function X.Suitable(b,placement)
 if not V(b)or not b:IsAlive()or b:IsInvulnerable()or Fu.GetPosition(b)<=3 or Fu.CanNotUseAction(b)
  or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()or b:NumQueuedActions()>0 then return false end
 local pin=Inventory.Get(b)
 if pin and pin.owner~='ward'then return false end
 if (b._earlyLotus and b._earlyLotus.active)or(b._wisdomOnce and b._wisdomOnce.active)
  or(b._outpostTask and b._outpostTask.active)or b._guardTravel or b._guardBaseArea
  or b:HasModifier('modifier_smoke_of_deceit')then return false end
 local passing=placement and Fu.IsPushing(b)and b:GetAttackTarget()==nil
 if Fu.IsRetreating(b)or Fu.IsDefending(b)or Fu.IsGoingOnSomeone(b)and not passing
  or b:GetActiveMode()==BOT_MODE_DEFEND_ALLY or(b:GetActiveMode()==BOT_MODE_RUNE and DotaTime()>0)
  or b:WasRecentlyDamagedByAnyHero(5)or #(b:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{})>0
  or not passing and Fu.Utils.IsTeamPushingSecondTierOrHighGround(b)then return false end
 local ancient=GetAncient(b:GetTeam())
 return not(ancient and Fu.Utils.CountEnemyHeroesNear(ancient:GetLocation(),3200)>0)
end
local function Capacity(b)
 for i=0,8 do if Kind(b:GetItemInSlot(i))then return true end end
 local main=Utility.Select(b,'ward',true)
 if not main then return false end
 if not b:GetItemInSlot(main)then return true end
 for i=6,8 do if not b:GetItemInSlot(i)then return true end end
 return false
end
function X.Report(b)
 if not V(b)or b~=GetBot()then return end
 local now=DotaTime();if now<(b._wardReportNext or -999)then return end;b._wardReportNext=now+.5
 local obs,sentry,free=0,0,0
 local function Count(u,last)
  for i=0,last do local h=u:GetItemInSlot(i);local kind=Kind(h)
   if kind then
    local n=h:GetName()
    obs=obs+((kind=='obs')and math.max(1,h:GetCurrentCharges())or 0)
    sentry=sentry+(n=='item_ward_dispenser'and h:GetSecondaryCharges()or kind=='sentry'and math.max(1,h:GetCurrentCharges())or 0)
   end
  end
 end
 Count(b,14)
 for i=0,8 do if not b:GetItemInSlot(i)then free=free+1 end end
 local c=b.theCourier;if c and not c:IsNull()then Count(c,8)end
 b._wardReport={at=now,obs=obs,sentry=sentry,room=free>0 or obs+sentry>0,canReceive=Capacity(b),role=Fu.GetPosition(b)}
end
local function Release(b,s,reason)
 Inventory.Release(b,'ward');b._wardReady=nil;s.next=DotaTime()+15;Log(b,reason)
end
function X.Prepare(b)
 if not V(b)or b~=GetBot()then return false end
 X.Report(b)
 local now=DotaTime();local s=b._wardInventory or{};b._wardInventory=s
 local p=b._wardReady
 if not b:IsAlive()then if p then Release(b,s,'death_release')end;return false end
 if p then
  local main=b:GetItemInSlot(p.main);local bp=b:GetItemInSlot(p.bp)
  if main~=p.item then
   if bp==p.item and now-p.started<1 then return false end
   Release(b,s,bp==p.item and'native_reversal_backoff'or'item_changed_release');return false
  end
  if now>=p.untilTime then Release(b,s,'ready_window_release');return false end
  local pin=Inventory.Get(b)
  if not pin or pin.owner~='ward'then b._wardReady=nil;s.next=now+15;return false end
  -- No new move, attack, or casting order is suppressed while the item cools down.
  return now>=p.readyAt and X.Suitable(b)
 end
 if now<(s.next or -999)or now<(s.checkNext or -999)then return false end;s.checkNext=now+.5
 if not X.Suitable(b)or b._openingRuneLock then return false end
 if b.itemSwapTime and now-b.itemSwapTime<.6 then return false end
 for bp=6,8 do local h=b:GetItemInSlot(bp);local kind=Kind(h)
  if kind then
   local spot
   if now<0 and kind=='obs'then
    local W=require(GetScriptDirectory()..'/FuncLib/systems/ward')
    spot=W.GetClosestObserverWardSpot(b,W.GetAvailabeObserverWardSpots(b))
    if spot and GetUnitToLocationDistance(b,spot.location)>1800 then spot=nil end
   elseif now>=0 then
    local legacy=kind=='sentry'and require(GetScriptDirectory()..'/FuncLib/systems/ward').GetPossibleSentryWardSpots(b)or nil
    spot=P.Select(b,h,kind,legacy)
   end
   if spot then
    local main,gear=Utility.Select(b,'ward',true)
    if main and Inventory.Reserve(b,main,bp,'ward',12)then
     b._wardReady={main=main,bp=bp,item=h,gear=gear,started=now,readyAt=now+6.2,untilTime=now+12}
     Inventory.Swap(b,bp,main,'ward');Log(b,'prepare_order','kind='..kind..' slot='..main)
     s.next=now+15;return false
    end
   end
  end
 end
 return false
end
function X.OnPlaced(b)
 if b._wardReady then Inventory.Release(b,'ward');b._wardReady=nil end
 b._wardLastPlaced=DotaTime()
end
function X.Supply(b,pos)
 if not V(b)or not b:IsAlive()or b~=GetBot()or pos<4 then return end
 X.Report(b)
 local now=DotaTime();if now<(b._wardBuyNext or -999)then return end;b._wardBuyNext=now+2
 local own=b._wardReport;if not own or not own.room or not own.canReceive then return end
 local total=0;local buyer,role
 for i=1,5 do local a=GetTeamMember(i);local r=a and a._wardReport
  if V(a)and(not r or now-r.at>=3)then
   local obs,sentry,free=0,0,0
   for slot=0,14 do local h=a:GetItemInSlot(slot);local k=Kind(h)
    if k=='obs'then obs=obs+math.max(1,h:GetCurrentCharges())elseif k=='sentry'then sentry=sentry+math.max(1,h:GetCurrentCharges())end
    if slot<=8 and not h then free=free+1 end
   end
   local courier=a.theCourier;if courier and not courier:IsNull()then for slot=0,8 do local h=courier:GetItemInSlot(slot);if Kind(h)=='obs'then obs=obs+math.max(1,h:GetCurrentCharges())end end end
   r={at=now,obs=obs,sentry=sentry,room=free>0 or obs+sentry>0,canReceive=Capacity(a),role=Fu.GetPosition(a)}
  end
  if V(a)and r and now-r.at<3 then
   total=total+r.obs
   if a:IsAlive()and IsPlayerBot(a:GetPlayerID())and r.role>=4 and r.room and r.canReceive
    and r.obs==0 and now>=(a._wardBuyUntil or -999)then
    if not buyer or r.role>role or r.role==role and a:GetPlayerID()<buyer:GetPlayerID()then buyer,role=a,r.role end
   end
  end
 end
 if own.obs==0 and total<2 and buyer==b and GetItemStockCount('item_ward_observer')>0 then
  local result=b:ActionImmediate_PurchaseItem('item_ward_observer');b._wardBuyUntil=now+8
  Log(b,'observer_purchase_order','result='..tostring(result));X.Report(b)
 end
 -- Retain the designated sentry purchaser and reserve money for its current build.
 if pos==4 and now>300 and own.sentry<1 and GetItemStockCount('item_ward_sentry')>0
  and b:GetGold()>=GetItemCost('item_ward_sentry')+200 then
  b:ActionImmediate_PurchaseItem('item_ward_sentry');Log(b,'sentry_purchase_order')
 end
end
for name in pairs({Prepare=true,Supply=true})do
 local raw=X[name];X[name]=function(b,...)
  local ok,v=pcall(raw,b,...);if ok then return v end
  if b and DotaTime()>=(b._wardInventoryErrorNext or -999)then b._wardInventoryErrorNext=DotaTime()+10
   print('[WARD_INVENTORY_ERROR] function='..name..' error='..tostring(v))end
  return false
 end
end
return X
