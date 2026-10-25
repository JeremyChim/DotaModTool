-- Nearby visible Roshan resources: allocate, make room, verify pickup, then prepare use.
local X={};local names={item_aegis=true,item_cheese=true,item_refresher_shard=true,item_roshans_banner=true}
local expendable={item_branches=true,item_tango=true,item_tango_single=true,item_clarity=true,item_flask=true,item_enchanted_mango=true}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function HP(b)return b:GetHealth()/math.max(1,b:GetMaxHealth())end
function X.IsLoot(n)return names[n]or false end
local function Free(b)return b==GetBot()and V(b)and not b:IsIllusion()and not b:IsInvulnerable()and not b:IsChanneling()and not b:IsCastingAbility()and not b:IsUsingAbility()and not b:IsStunned()and not b:IsHexed()and not b:IsRooted()and not b:IsInvisible()and b:NumQueuedActions()==0 and not b._guardTravel and not b._counterTask and not b._enigmaCombo and not b._invokerPlan end
local function Space(b,name)
 local free=0;for i=0,(name=='item_aegis'and 5 or 8)do if not b:GetItemInSlot(i)then free=free+1 end end
 if free>0 then return true end
 if name=='item_aegis'then for i=6,8 do if not b:GetItemInSlot(i)then return true end end end
 for i=0,8 do local a=b:GetItemInSlot(i);if a and expendable[a:GetName()]then return true end end
 return false
end
local function MakeRoom(b,name)
 local last=name=='item_aegis'and 5 or 8
 for i=0,last do if not b:GetItemInSlot(i)then return true end end
 if name=='item_aegis'then
  local empty;for i=6,8 do if not b:GetItemInSlot(i)then empty=i;break end end
  if empty then local slot,cost
   for i=0,5 do local a=b:GetItemInSlot(i);if a and a:GetName()~='item_aegis'then local v=GetItemCost(a:GetName());if not cost or v<cost then slot,cost=i,v end end end
   if slot then b:ActionImmediate_SwapItems(slot,empty);return true end
  end
 end
 for i=8,0,-1 do local a=b:GetItemInSlot(i)
  if a and expendable[a:GetName()]then
   b._lootDiscard=a;b:Action_DropItem(a,b:GetLocation());return false
  end
 end;return false
end
local function Eligible(b,drop)
 return V(b)and b:IsHero()and not b:IsIllusion()and not b:HasModifier('modifier_arc_warden_tempest_double')and IsPlayerBot(b:GetPlayerID())
  and HP(b)>.45 and not b:IsChanneling()and GetUnitToLocationDistance(b,drop.location)<1000 and Space(b,drop.item:GetName())
  and b:FindItemSlot(drop.item:GetName())<0
end
local function Receiver(b,drop,Fu)
 local candidates={b};for _,a in ipairs(b:GetNearbyHeroes(1400,false,BOT_MODE_NONE)or{})do if a~=b then candidates[#candidates+1]=a end end
 local best,score;local name=drop.item:GetName()
 for _,a in ipairs(candidates)do if Eligible(a,drop)then
  local role=Fu.GetPosition(a);local value=GetUnitToLocationDistance(a,drop.location)
  if name=='item_aegis'then value=value+(role>3 and 600 or role*60)
  elseif name=='item_cheese'then value=value+HP(a)*150
  elseif name=='item_refresher_shard'then
   local ability=Fu.GetUltimateAbility(a);if not ability or ability:IsPassive()then value=value+900 else value=value-math.min(200,ability:GetCooldown())end
  end
  if not score or value<score or value==score and a:GetPlayerID()<best:GetPlayerID()then best,score=a,value end
 end end;return best
end
local function Prepare(b)
 if b:WasRecentlyDamagedByAnyHero(2)then return false end
 for _,name in ipairs({'item_cheese','item_refresher_shard','item_roshans_banner'})do
  local slot=b:FindItemSlot(name)
  if slot>=6 and slot<=8 and DotaTime()>=(b._lootSwapNext or -1)then
   local target,cost
   for i=0,5 do local a=b:GetItemInSlot(i)
    if not a then target=i;break end
    local n=a:GetName();if n~='item_aegis'and not names[n]then local v=GetItemCost(n);if not cost or v<cost then target,cost=i,v end end
   end
   if target then b:ActionImmediate_SwapItems(slot,target);b._lootSwapNext=DotaTime()+7;return true end
  end
 end;return false
end
function X.Try(b,Fu)
 if not Free(b)then return false end
 local state=b._roshanLoot
 if state then
  if b:FindItemSlot(state.name)>=0 then
   print('[ROSHAN_LOOT] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=pickup_confirmed item='..state.name);b._roshanLoot=nil
  elseif DotaTime()>state.untilTime then b._roshanLoot=nil;b._lootRetry=DotaTime()+1 end
 end
 if Prepare(b)then return false end
 if b:WasRecentlyDamagedByAnyHero(2)or HP(b)<.5 or b:GetActiveMode()==BOT_MODE_RETREAT or #(b:GetNearbyHeroes(1000,true,BOT_MODE_NONE)or{})>0 then return false end
 for _,drop in ipairs(GetDroppedItemList()or{})do
  local item=drop.item;local name=item and not item:IsNull()and item:GetName()
  if names[name]and IsLocationVisible(drop.location)and GetUnitToLocationDistance(b,drop.location)<900
   and DotaTime()>=(b._lootRetry or -1)and Receiver(b,drop,Fu)==b then
   b._roshanLoot={item=item,name=name,untilTime=DotaTime()+4}
   if not MakeRoom(b,name)then return true end
   local d=GetUnitToLocationDistance(b,drop.location)
   if d>100 then
    if require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,drop.location)then b:Action_MoveToLocation(drop.location);return true end
   else b:Action_PickUpItem(item);return true end
  end
 end;return false
end
function X.Banner(b,a)
 if not Free(b)or not a:IsFullyCastable()then return nil end
 local m=b:GetActiveMode();local base=require(GetScriptDirectory()..'/FuncLib/systems/base_execution')
 if not(base.Active(b)or m==BOT_MODE_PUSH_TOWER_TOP or m==BOT_MODE_PUSH_TOWER_MID or m==BOT_MODE_PUSH_TOWER_BOT)then return nil end
 local tower=(b:GetNearbyTowers(1600,true)or{})[1];local fort=GetAncient(b:GetTeam()==2 and 3 or 2)
 if not V(tower)and(not V(fort)or GetUnitToUnitDistance(b,fort)>2200)then return nil end
 for _,c in ipairs(b:GetNearbyLaneCreeps(1000,false)or{})do if V(c)then local p=c:GetLocation()
  if GetUnitToLocationDistance(b,p)<=a:GetCastRange()and IsLocationPassable(p)and not require(GetScriptDirectory()..'/FuncLib/systems/fountain_safety').Forbidden(b,p)then return p end
 end end;return nil
end
local raw=X.Try;X.Try=function(b,...)
 local ok,v=pcall(raw,b,...);if ok then return v end
 if b and DotaTime()>=(b._lootErrorNext or -1)then b._lootErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=roshan_loot error='..tostring(v))end;return false
end
return X
