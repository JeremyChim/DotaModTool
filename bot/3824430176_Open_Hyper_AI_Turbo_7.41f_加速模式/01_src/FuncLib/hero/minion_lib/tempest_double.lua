-- Tempest Double has independent spells/items, but shares the owner's local objective.
local X={}
local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function Enemy(u)return V(u)and u:CanBeSeen()and not u:IsInvulnerable()and not u:IsAttackImmune()end
local function IsDouble(u)return V(u)and u:GetUnitName()=='npc_dota_hero_arc_warden'and u:HasModifier('modifier_arc_warden_tempest_double')end
function X.Main(d)
 for _,u in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)or{})do
  if u~=d and V(u)and u:GetUnitName()=='npc_dota_hero_arc_warden'and u:GetPlayerID()==d:GetPlayerID()and not IsDouble(u)then return u end
 end
end
local function Ready(a)return a and not a:IsNull()and not a:IsHidden()and a:IsFullyCastable()end
local function Log(d,phase)
 if DotaTime()>=(d._tempestLog or -999)then d._tempestLog=DotaTime()+1
  print('[TEMPEST_MICRO] t='..DotaTime()..' owner='..d:GetPlayerID()..' actor='..tostring(d)..' phase='..phase)end
end
local function Cast(d,a,t,point)
 if t then if point then d:Action_UseAbilityOnLocation(a,t)else d:Action_UseAbilityOnEntity(a,t)end else d:Action_UseAbility(a)end
 d._tempestCastUntil=DotaTime()+math.max(.25,a:GetCastPoint()+.15);Log(d,a:GetName());return true
end
local function Item(d,n)for i=0,5 do local a=d:GetItemInSlot(i);if a and a:GetName()==n and Ready(a)then return a end end end
local function Move(d,p)
 if not p or GetUnitToLocationDistance(d,p)<100 or not Safe(d,p)then return end
 if DotaTime()<(d._tempestMoveNext or -999)then return end;d._tempestMoveNext=DotaTime()+.45;d:Action_MoveToLocation(p)
end
function X.Think(owner,d)
 if not IsDouble(d)or not V(owner)or owner:GetPlayerID()~=d:GetPlayerID()then return false end
 if d:IsChanneling()or d:IsUsingAbility()or d:IsCastingAbility()or d:IsStunned()or d:IsHexed()
  or DotaTime()<(d._tempestCastUntil or -999)then return true end
 if not d._tempestSeen then d._tempestSeen=true;Log(d,'dedicated_control')end
 local enemies=d:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{};local target=owner:GetAttackTarget()
 if not Enemy(target)or target:IsHero()and Fu.IsSuspiciousIllusion(target)or GetUnitToUnitDistance(d,target)>1600 then target=nil end
 if not target then for _,e in ipairs(enemies)do if Enemy(e)and not Fu.IsSuspiciousIllusion(e)
  and(not target or e:GetHealth()<target:GetHealth())then target=e end end end
 local hp=d:GetHealth()/math.max(1,d:GetMaxHealth());local retreat=Fu.IsRetreating(owner)
 local threatened=#enemies>0 and(hp<.4 or retreat)
 if threatened then
  local bkb=Item(d,'item_black_king_bar');if bkb and not d:IsMagicImmune()and d:WasRecentlyDamagedByAnyHero(1)and Cast(d,bkb)then return true end
  local ghost=Item(d,'item_ghost');if ghost and hp<.3 and Cast(d,ghost)then return true end
  if owner:CanBeSeen()and GetUnitToUnitDistance(owner,d)>300 then Move(d,owner:GetLocation());return true end
 end
 if Enemy(target)and target:IsHero()then
  for _,n in ipairs({'item_sheepstick','item_bloodthorn','item_orchid','item_rod_of_atos'})do local a=Item(d,n)
   if a and not target:IsMagicImmune()and not target:IsStunned()and not target:IsHexed()
    and GetUnitToUnitDistance(d,target)<=a:GetCastRange()and not Fu.IsReflectingSpells(target)then
    if not target:HasModifier('modifier_orchid_malevolence_debuff')and not target:HasModifier('modifier_bloodthorn_debuff')then return Cast(d,a,target)end
   end
  end
  local gleipnir=Item(d,'item_gungir');if gleipnir and not target:IsMagicImmune()and not Fu.IsDisabled(target)
   and GetUnitToUnitDistance(d,target)<=gleipnir:GetCastRange()then return Cast(d,gleipnir,target:GetLocation(),true)end
  local flux=d:GetAbilityByName('arc_warden_flux')
  if Ready(flux)and not target:IsMagicImmune()and not Fu.IsReflectingSpells(target)
   and GetUnitToUnitDistance(d,target)<=flux:GetCastRange()then
   -- Current Flux is most valuable on isolated targets. Check only visible enemy units.
   local grouped=false;local radius=flux:GetSpecialValueInt('search_radius');if radius<=0 then radius=225 end
   for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMIES)or{})do
    if u~=target and V(u)and u:CanBeSeen()and GetUnitToUnitDistance(u,target)<radius then grouped=true;break end
   end
   if not grouped then return Cast(d,flux,target)end
  end
  local spark=d:GetAbilityByName('arc_warden_spark_wraith')
  if Ready(spark)and GetUnitToUnitDistance(d,target)<=spark:GetCastRange()then
   local delay=math.min(1.5,math.max(.2,spark:GetSpecialValueFloat('activation_delay')))
   local aim=Fu.IsDisabled(target)and target:GetLocation()or target:GetExtrapolatedLocation(delay)
   return Cast(d,spark,aim,true)
  end
 end
 if Enemy(target)then
  local field=d:GetAbilityByName('arc_warden_magnetic_field')
  if Ready(field)and not d:HasModifier('modifier_arc_warden_magnetic_field')and GetUnitToUnitDistance(d,target)<=d:GetAttackRange()+100 then
   return Cast(d,field,d:GetLocation(),true)
  end
  local lightning=Item(d,'item_mjollnir');if lightning and d:WasRecentlyDamagedByAnyHero(1)then return Cast(d,lightning,d)end
  if d:GetAttackTarget()~=target then d:Action_AttackUnit(target,false);Log(d,'local_focus')end
  return true
 end
 local life=d:GetRemainingLifespan()
 if life>2 then
  local midas=Item(d,'item_hand_of_midas')
  if midas then for _,u in ipairs(d:GetNearbyCreeps(midas:GetCastRange(),true)or{})do
   if Enemy(u)and not u:IsAncientCreep()and not u:IsHero()then return Cast(d,midas,u)end
  end end
 end
 if owner:CanBeSeen()then Move(d,owner:GetLocation())end
 return true
end
return X
