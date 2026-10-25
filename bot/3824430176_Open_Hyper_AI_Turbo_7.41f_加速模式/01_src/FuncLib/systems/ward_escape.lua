-- A short, visible death-ward escape owns only local foot orders. Stolen wards count too.
local X={};local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Protected(b)return not V(b)or b~=GetBot()or b:IsIllusion()or b:IsInvulnerable()
 or b:IsStunned()or b:IsRooted()or b:IsHexed()or b:HasModifier('modifier_bloodseeker_rupture')end
function X.Update(b)
 if Protected(b)then return nil end
 local now=DotaTime();local s=b._wardEscape or{wards={}};b._wardEscape=s
 if now<(s.next or -1)then return s end;s.next=now+.15;s.wards={}
 for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMIES)or{})do
  if V(u)and u:CanBeSeen()and u:GetUnitName():find('witch_doctor_death_ward',1,true)
   and D(b:GetLocation(),u:GetLocation())<1800 then
   s.wards[#s.wards+1]={loc=u:GetLocation(),range=math.max(750,math.min(1000,u:GetAttackRange()+100))}
  end
 end
 local danger=false
 for _,u in ipairs(s.wards)do if D(b:GetLocation(),u.loc)<u.range then danger=true end end
 if not danger then s.goal=nil;s.hold=nil;return s end
 -- A currently protected offensive channel is only broken when already in lethal danger.
 if b:IsChanneling()and b:GetHealth()/math.max(1,b:GetMaxHealth())>.28 then s.goal=nil;s.hold=nil;return s end
 if b:IsUsingAbility()or b:IsCastingAbility()then return s end
 if s.goal and now<(s.hold or -1)and D(b:GetLocation(),s.goal)>60 then return s end
 local here=b:GetLocation()
 local function Risk(p)local v=0;for _,u in ipairs(s.wards)do v=v+math.max(0,u.range+120-D(p,u.loc))end;return v end
 local initial=Risk(here);local best,score
 local home=GetAncient(b:GetTeam());local homeLoc=V(home)and home:GetLocation()or here
 for i=0,15 do local angle=i*math.pi/8
  for _,step in ipairs({350,600,850})do
   local p=Vector(here.x+math.cos(angle)*step,here.y+math.sin(angle)*step,here.z)
   if Safe(b,p)then
    local gain=initial-Risk(p);local pathRisk=0
    for _,f in ipairs({.25,.5,.75})do pathRisk=math.max(pathRisk,Risk(Vector(here.x+(p.x-here.x)*f,here.y+(p.y-here.y)*f,here.z))-initial)end
    local value=gain-D(p,homeLoc)*.015-step*.025-pathRisk*3
    if gain>100 and(not score or value>score)then best,score=p,value end
   end
  end
 end
 if best then
  s.goal=best;s.hold=now+.7
  if now>=(s.logNext or -1)then s.logNext=now+2;print('[WARD_ESCAPE] t='..now..' pid='..b:GetPlayerID()..' phase=visible_ward_exit')end
 end
 return s
end
function X.Goal(b,action)
 local foot=action:find('Move',1,true)or action:find('Attack',1,true)or action=='Action_ClearActions'
 if not foot then return nil end
 local s=X.Update(b)
 return s and s.goal
end
function X.Try(b)
 local s=X.Update(b)
 if not s or not s.goal or b:IsUsingAbility()or b:IsCastingAbility()or b:NumQueuedActions()>0
  or DotaTime()<(b._ohaAbilityOrderAt or -999)+.35 then return false end
 if not b:IsChanneling()and not b:IsSilenced()then
  local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
  local names={npc_dota_hero_witch_doctor='witch_doctor_paralyzing_cask',npc_dota_hero_shadow_shaman='shadow_shaman_voodoo',
   npc_dota_hero_lion='lion_voodoo',npc_dota_hero_ogre_magi='ogre_magi_fireblast',npc_dota_hero_vengefulspirit='vengefulspirit_magic_missile',npc_dota_hero_enigma='enigma_malefice'}
  local name=names[b:GetUnitName()];local a=name and b:GetAbilityByName(name)
  if a and a:IsFullyCastable()then
   for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
    if V(e)and e:CanBeSeen()and e:IsChanneling()then
     local active=e:GetCurrentActiveAbility()
     if active and active:GetName()=='witch_doctor_death_ward'and Fu.CanCastOnNonMagicImmune(e)
      and Fu.CanCastOnTargetAdvanced(e)and GetUnitToUnitDistance(b,e)<=Fu.GetProperCastRange(false,b,a:GetCastRange())then
      b:Action_UseAbilityOnEntity(a,e);return true
     end
    end
   end
  end
 end
 if b:IsChanneling()then b:Action_ClearActions(true)end
 if DotaTime()>=(s.orderNext or -1)then s.orderNext=DotaTime()+.3;b:Action_MoveToLocation(s.goal)end
 return true
end

for name,fallback in pairs({Update=function()end,Goal=function()end,Try=function()return false end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,a,d=pcall(raw,b,...);if ok then return a,d end
  if b and DotaTime()>=(b._ward_escapeErrorNext or -1)then
   b._ward_escapeErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=ward_escape function='..name..' error='..tostring(a))
  end
  return fallback(b,...)
 end
end
return X
