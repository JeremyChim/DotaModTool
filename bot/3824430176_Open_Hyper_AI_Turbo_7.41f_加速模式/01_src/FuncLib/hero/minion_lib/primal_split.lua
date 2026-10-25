-- Coordinated local Primal Split micro. Each unit keeps its own cast/order state.
local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
local U=require(GetScriptDirectory()..'/FuncLib/hero/minion_lib/utils')
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function Enemy(u)return V(u)and u:CanBeSeen()and not u:IsInvulnerable()and not u:IsAttackImmune()end
local function D(a,c)return math.sqrt((a.x-c.x)^2+(a.y-c.y)^2)end
local function Point(u,p,n)local a=u:GetLocation();local d=math.max(1,D(a,p));local k=math.min(1,n/d);return Vector(a.x+(p.x-a.x)*k,a.y+(p.y-a.y)*k,a.z)end
local function Busy(u)return not V(u)or u:IsUsingAbility()or u:IsCastingAbility()or u:IsChanneling()or u:IsStunned()or u:IsHexed()end
local function Ready(u,n)local a=u:GetAbilityByName(n);return a and not a:IsNull()and not a:IsHidden()and a:IsFullyCastable()and a or nil end
local function Log(u,phase)
 if DotaTime()>=(u._splitLog or -999)then u._splitLog=DotaTime()+2;print('[PRIMAL_MICRO] t='..DotaTime()..' unit='..u:GetUnitName()..' phase='..phase)end
end
local function Move(u,p)
 if not p or U.CantMove(u)or D(u:GetLocation(),p)<80 then return end
 if DotaTime()<(u._splitMoveNext or -999)then return end;u._splitMoveNext=DotaTime()+.4
 u:Action_MoveToLocation(p);Log(u,'local_reposition')
end
local function Anchor(owner,u)
 local best,dist
 for i=1,5 do local a=GetTeamMember(i)
  if a~=owner and V(a)and a:CanBeSeen()and not a:IsIllusion()then local d=GetUnitToUnitDistance(a,u)
   if d<1600 and(not dist or d<dist)then best,dist=a,d end
  end
 end
 if best then return best:GetLocation()end
 local fort=GetAncient(owner:GetTeam());if V(fort)then return Point(u,fort:GetLocation(),450)end
end
local function Cast(u,a,target,point)
 if not a then return false end
 if target then
  if point then u:Action_UseAbilityOnLocation(a,target)else u:Action_UseAbilityOnEntity(a,target)end
 else u:Action_UseAbility(a)end
 u._splitCastUntil=DotaTime()+math.max(.4,a:GetCastPoint()+.15);Log(u,a:GetName());return true
end
local buffs={'modifier_windrunner_windrun','modifier_omniknight_guardian_angel','modifier_item_ghost_scepter_active',
 'modifier_item_glimmer_cape_fade','modifier_rune_haste','modifier_rune_doubledamage','modifier_lich_frost_shield'}
local debuffs={'modifier_venomancer_venomous_gale','modifier_crystal_maiden_frostbite','modifier_ogre_magi_ignite',
 'modifier_silence','modifier_orchid_malevolence_debuff','modifier_bloodthorn_debuff'}
function X.MinionThink(owner,u)
 if not V(owner)or Busy(u)or DotaTime()<(u._splitCastUntil or -999)then return end
 local enemies=u:GetNearbyHeroes(1500,true,BOT_MODE_NONE)or{};local here=u:GetLocation();local name=u:GetUnitName()
 local retreat=Fu.IsRetreating(owner);local anchor=Anchor(owner,u)
 local target;local ok,t=pcall(Fu.GetProperTarget,owner)
 if ok and Enemy(t)and GetUnitToUnitDistance(u,t)<1400 then target=t end
 if not target then
  for _,e in ipairs(enemies)do if Enemy(e)and(not target or e:GetHealth()<target:GetHealth())then target=e end end
 end
 local lifespan=u.GetRemainingLifespan and u:GetRemainingLifespan()or 99
 local nearEnd=lifespan>0 and lifespan<2.5
 local low=u:GetHealth()/math.max(1,u:GetMaxHealth())<.25
 local earth=name:find('brewmaster_earth',1,true)
 local storm=name:find('brewmaster_storm',1,true)
 -- Preserve a safe reform point; never order an entire-map trip to the fountain.
 if (retreat or nearEnd or earth and low)and anchor then
  if storm then local wind=Ready(u,'brewmaster_storm_wind_walk');if wind and not u:IsInvisible()and Cast(u,wind)then return end end
  local stone=earth and Ready(u,'brewmaster_earth_hurl_boulder')
  if stone then for _,e in ipairs(enemies)do if Enemy(e)and not e:IsMagicImmune()and not Fu.IsDisabled(e)
   and not Fu.IsReflectingSpells(e)and GetUnitToUnitDistance(u,e)<=stone:GetCastRange()then if Cast(u,stone,e)then return end end end end
  Move(u,anchor);return
 end
 if earth then
  local stone=Ready(u,'brewmaster_earth_hurl_boulder');local best
  if stone then
   for _,e in ipairs(enemies)do if Enemy(e)and not e:IsMagicImmune()and not Fu.IsDisabled(e)and not Fu.IsReflectingSpells(e)
    and GetUnitToUnitDistance(u,e)<=stone:GetCastRange()then
    if not best or e:IsChanneling()or e==target and not best:IsChanneling()then best=e end
   end end
   if best and Cast(u,stone,best)then return end
  end
 elseif storm then
  local cyclone=Ready(u,'brewmaster_storm_cyclone');local best
  if cyclone then
   for _,e in ipairs(enemies)do if Enemy(e)and not e:IsMagicImmune()and not Fu.IsDisabled(e)and not Fu.IsReflectingSpells(e)
    and GetUnitToUnitDistance(u,e)<=cyclone:GetCastRange()then
    if e:IsChanneling()then best=e;break end
    if e~=target and(not best or e:GetAttackDamage()>best:GetAttackDamage())then best=e end
   end end
   if best and Cast(u,cyclone,best)then return end
  end
  local dispel=Ready(u,'brewmaster_storm_dispel_magic')
  if dispel then
   local candidate
   for _,e in ipairs(enemies)do if Enemy(e)and GetUnitToUnitDistance(u,e)<=dispel:GetCastRange()+500 then
    local valuable=Fu.IsSuspiciousIllusion(e)
    for _,m in ipairs(buffs)do if e:HasModifier(m)then valuable=true end end
    if valuable then candidate=e;break end
   end end
   if not candidate then for _,a in ipairs(u:GetNearbyHeroes(1000,false,BOT_MODE_NONE)or{})do
    if V(a)and a:CanBeSeen()then for _,m in ipairs(debuffs)do if a:HasModifier(m)then candidate=a;break end end end
    if candidate then break end
   end end
   if candidate and Cast(u,dispel,Point(u,candidate:GetLocation(),dispel:GetCastRange()),true)then return end
  end
  local wind=Ready(u,'brewmaster_storm_wind_walk')
  if wind and not u:IsInvisible()and(target and GetUnitToUnitDistance(u,target)>450 or u:GetHealth()/u:GetMaxHealth()<.5)
   and Cast(u,wind)then return end
 end
 -- Only use actual abilities present on this unit; no stale void/vector ability names.
 local building=owner:GetAttackTarget()
 if (Fu.IsPushing(owner)or earth and Enemy(building)and building:IsBuilding())and Enemy(building)
  and building:IsBuilding()and GetUnitToUnitDistance(u,building)<1200 then target=building end
 if Enemy(target)then
  if u:GetAttackTarget()~=target then u:Action_AttackUnit(target,false);Log(u,'shared_focus')end
  return
 end
 if anchor then Move(u,anchor)end
end
return X
