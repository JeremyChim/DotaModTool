-- Only visible native zone/ongoing-channel evidence. No enemy hidden-position queries.
local X={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Free(b)return V(b)and b==GetBot()and b:IsHero()and not b:IsIllusion()and not b:IsInvulnerable()and not b:IsChanneling()and not b:IsUsingAbility()and not b:IsCastingAbility()and not b:IsStunned()and not b:IsHexed()and not b:IsRooted()and not b:HasModifier('modifier_bloodseeker_rupture')and not b:HasModifier('modifier_batrider_flaming_lasso')end
local profiles={
 {modifier='modifier_abyssal_underlord_pit_of_malice_thinker',kind='pit',radius=430,margin=90},
 {modifier='modifier_invoker_sun_strike',kind='sunstrike',radius=175,margin=80},
 {modifier='modifier_invoker_sun_strike_thinker',kind='sunstrike',radius=175,margin=80},
 {modifier='modifier_invoker_ice_wall_thinker',kind='icewall',radius=380,margin=80},
 {modifier='modifier_invoker_chaos_meteor_land',kind='meteor',radius=260,margin=100}}
function X.Update(b)
 if not V(b)or b~=GetBot()or b:IsIllusion()then return nil end
 local now=DotaTime();local s=b._spellSafety or{zones={}};b._spellSafety=s
 if now<(s.next or -1)then return s end;s.next=now+.16
 for _,u in ipairs(GetUnitList(UNIT_LIST_ALL)or{})do
  if u and not u:IsNull()and u:GetTeam()~=b:GetTeam()and u:CanBeSeen()and D(b:GetLocation(),u:GetLocation())<1900 then
   local name=u:GetUnitName()
   if name:find('thinker',1,true)or name:find('invoker',1,true)or name:find('underlord',1,true)then
    for _,cfg in ipairs(profiles)do if u:HasModifier(cfg.modifier)then
     local key=tostring(u)..cfg.modifier;local old=s.zones[key];local duration=1
     local index=u:GetModifierByName(cfg.modifier)
     if index and index>=0 then duration=math.max(.2,u:GetModifierRemainingDuration(index))end
     -- A pit already known in fog retains its original lifetime, never a newly sampled hidden location.
     s.zones[key]={loc=u:GetLocation(),radius=cfg.radius+cfg.margin,kind=cfg.kind,untilTime=now+duration,
      first=old and old.first or now}
    end end
   end
  end
 end
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()then
   local a=e:GetCurrentActiveAbility()
   if a and not a:IsNull()and e:IsChanneling()and a:GetName()=='crystal_maiden_freezing_field'then
    local radius=a:GetAOERadius();if radius<300 then radius=800 end
    s.zones['field'..e:GetPlayerID()]={loc=e:GetLocation(),radius=radius+80,kind='freezing_field',untilTime=now+.4}
   end
  end
 end
 for k,z in pairs(s.zones)do if now>z.untilTime then s.zones[k]=nil end end
 return s
end
local function Risk(s,p)
 local risk=0
 for _,z in pairs(s.zones)do risk=risk+math.max(0,z.radius-D(p,z.loc))end
 return risk
end
function X.SafePoint(b,p)
 local s=X.Update(b);return not s or Risk(s,p)==0
end
local function Goal(b,destination)
 local s=X.Update(b);if not s or not Free(b)then return nil end
 local here=b:GetLocation();local risk=Risk(s,here);local now=DotaTime()
 local old=s.goal
 if old and now<(s.hold or -1)and D(here,old)>65 and Safe(b,old)and Risk(s,old)<math.max(1,risk)then return old end
 if risk<=0 then
  if not destination then return nil end
  local unsafe=false
  for i=1,6 do local p=Vector(here.x+(destination.x-here.x)*i/6,here.y+(destination.y-here.y)*i/6,here.z)
   if Risk(s,p)>0 then unsafe=true;break end
  end
  if not unsafe then s.goal=nil;return nil end
 end
 local best,score
 for _,step in ipairs({300,520,720})do for i=0,15 do
  local angle=(i*22.5+(b:GetPlayerID()%5)*7)*math.pi/180
  local p=Vector(here.x+math.cos(angle)*step,here.y+math.sin(angle)*step,here.z)
  local cost=Risk(s,p)
  if cost<math.max(1,risk)and Safe(b,p)then
   local increasing=false
   for j=1,5 do local q=Vector(here.x+(p.x-here.x)*j/5,here.y+(p.y-here.y)*j/5,here.z)
    if Risk(s,q)>risk+35 then increasing=true end
   end
   if not increasing then
    local value=-cost*10-step*.06-(destination and D(p,destination)*.05 or 0)
    for _,e in ipairs(b:GetNearbyHeroes(1400,true,BOT_MODE_NONE)or{})do
     if V(e)and e:CanBeSeen()and D(p,e:GetLocation())<D(here,e:GetLocation())-120 then value=value-220 end
    end
    if not score or value>score then best,score=p,value end
   end
  end
 end end
 if best then
  s.goal=best;s.hold=now+1.1;b._hazardExitUntil=now+1.1
  if now>=(s.logNext or -1)then s.logNext=now+2;print('[SPELL_SAFETY] t='..now..' pid='..b:GetPlayerID()..' phase=stable_exit')end
 end
 return best
end
function X.OrderGoal(b,action,target)
 if b._spellOwnOrder or not Free(b)then return nil end
 if not(action:find('Move',1,true)or action:find('Attack',1,true))then return nil end
 local p=target and target.x and target or target and not target:IsNull()and target:GetLocation()
 if p and target and not target.x and action:find('AttackUnit',1,true)then
  local d=D(b:GetLocation(),p);local reach=b:GetAttackRange()+80
  if d<=reach then p=nil
  else local h=b:GetLocation();p=Vector(h.x+(p.x-h.x)*(d-reach)/d,h.y+(p.y-h.y)*(d-reach)/d,h.z)end
 end
 return Goal(b,p)
end
local interrupts={lion_voodoo='unit',lion_impale='point',shadow_shaman_voodoo='unit',shadow_shaman_shackles='unit',
 vengefulspirit_magic_missile='unit',sven_storm_bolt='unit',chaos_knight_chaos_bolt='unit',
 nyx_assassin_impale='point',lina_light_strike_array='point',dragon_knight_dragon_tail='unit',
 monkey_king_boundless_strike='point',rubick_telekinesis='unit',witch_doctor_paralyzing_cask='unit'}
function X.Interrupt(b,Fu)
 if not Free(b)or b:IsSilenced()or b:NumQueuedActions()>0 then return false end
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and e:IsChanneling()and not Fu.IsSuspiciousIllusion(e)and Fu.CanCastOnNonMagicImmune(e)then
   local active=e:GetCurrentActiveAbility();local name=active and active:GetName()
   if name=='crystal_maiden_freezing_field'or name=='witch_doctor_death_ward'then
    for i=0,23 do local a=b:GetAbilityInSlot(i);local kind=a and interrupts[a:GetName()]
     if kind and not a:IsHidden()and a:IsFullyCastable()and GetUnitToUnitDistance(b,e)<=a:GetCastRange()
      and Fu.CanCastOnTargetAdvanced(e)and not Fu.IsReflectingSpells(e)then
      if kind=='unit'then b:Action_UseAbilityOnEntity(a,e)else b:Action_UseAbilityOnLocation(a,e:GetLocation())end
      return true
     end
    end
   end
  end
 end
 return false
end
function X.Try(b,Fu)
 if not Free(b)or b:NumQueuedActions()>0 or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 then return false end
 if X.Interrupt(b,Fu)then return true end
 local p=Goal(b);if not p then return false end
 b._spellOwnOrder=true;b:Action_MoveToLocation(p);b._spellOwnOrder=nil;return true
end

do local raw=X.Update;X.Update=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spell_safetyErrorNext or -1)then b._spell_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spell_safety function=Update error='..tostring(value))end
 return nil
end end
do local raw=X.SafePoint;X.SafePoint=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spell_safetyErrorNext or -1)then b._spell_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spell_safety function=SafePoint error='..tostring(value))end
 return true
end end
do local raw=X.OrderGoal;X.OrderGoal=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spell_safetyErrorNext or -1)then b._spell_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spell_safety function=OrderGoal error='..tostring(value))end
 return nil
end end
do local raw=X.Interrupt;X.Interrupt=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spell_safetyErrorNext or -1)then b._spell_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spell_safety function=Interrupt error='..tostring(value))end
 return false
end end
do local raw=X.Try;X.Try=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spell_safetyErrorNext or -1)then b._spell_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spell_safety function=Try error='..tostring(value))end
 return false
end end
return X
