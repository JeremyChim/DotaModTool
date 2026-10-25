-- Own-hero, short spell transactions. Uses the hero's existing legal-target considerations.
local X={}
local timeKeys={invoker_cold_snap='ColdSnap',invoker_ghost_walk='GhostWalk',invoker_tornado='Tornado',
 invoker_emp='EMP',invoker_alacrity='Alacrity',invoker_chaos_meteor='ChaosMeteor',
 invoker_sun_strike='Sunstrike',invoker_forge_spirit='ForgeSpirit',invoker_ice_wall='IceWall',invoker_deafening_blast='DeafeningBlast'}
local function Valid(u) return u and not u:IsNull() and u:IsAlive() and u:CanBeSeen() end
local function Log(b,phase,spell)
 local now=DotaTime();local times=b._invokerPlanLogNext
 if type(times)~='table' then times={};b._invokerPlanLogNext=times end
 if now<(times[phase] or -999) then return end
 times[phase]=now+2
 print(string.format('[INVOKER_PLAN] t=%.2f pid=%d phase=%s spell=%s',now,b:GetPlayerID(),phase,spell or 'none'))
end
local function Abort(b,why)
 local p=b._invokerPlan;b._invokerPlan=nil
 if p then Log(b,why,p.name) end
end
function X.Step(b,hero,spells,ctx)
 local now=DotaTime();local p=b._invokerPlan
 if not b:IsAlive() then Abort(b,'death_release');return false end
 if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() then return p~=nil end
 if p and (now>=p.deadline or ctx.retreat and not p.escape
  or not p.escape and b._spellSafety and b._spellSafety.goal and now<(b._spellSafety.hold or -1)
  or p.victim and not Valid(p.victim)) then
  if p.ownsQueue and b:NumQueuedActions()>0 then b._invokerOwnOrder=true;b:Action_ClearActions(false);b._invokerOwnOrder=nil end
  Abort(b,'invalid_release');p=nil
 end
 if p then
  local cooldown=p.ability:GetCooldownTimeRemaining()
  if p.castAt and cooldown>p.cooldown+0.1 then
   if ctx.last then ctx.last[p.spell=='Cataclysm' and 'Cataclysm' or timeKeys[p.name] or p.name]=p.castAt end
   if p.name=='invoker_tornado' or p.name=='invoker_chaos_meteor' then
    local speed=p.ability:GetSpecialValueFloat('travel_speed');if speed<=0 then speed=1000 end
    local flight=p.victim and GetUnitToUnitDistance(b,p.victim)/speed or .5
    b._invokerLink={victim=p.victim,at=p.castAt,name=p.name,untilTime=now+6,
      impactAt=p.castAt+p.ability:GetCastPoint()+math.min(2,flight)+.12}
   end
   if p.escape then b._invokerEscape={started=p.castAt,untilTime=now+4} end
   Abort(b,'cast_observed');return true
  end
  if p.castAt then
   if now-p.castAt<0.8 or b:NumQueuedActions()>0 then return true end
   Abort(b,'cast_unconfirmed_release');return true
  end
  if b:NumQueuedActions()>0 then return true end
  if hero.IsAbilityReadyForCast(p.ability) then
   -- Re-evaluate target and timing after invoke; this respects cyclone/meteor landing gates.
   local desire,target,wait=p.consider()
   if wait then
    p.waitAt=p.waitAt or now
    if now-p.waitAt>2.5 then Abort(b,'landing_window_timeout');return false end
    Log(b,'await_control_landing',p.name);return true
   end
   p.waitAt=nil
   if not desire or desire<=0 then Abort(b,'window_lost_release');return true end
   if p.victim and target and not target.x and target~=p.victim then Abort(b,'victim_changed_release');return false end
   if p.victim and target and target.x then
    local v=p.victim:GetLocation();local dx,dy=target.x-v.x,target.y-v.y
    if dx*dx+dy*dy>450*450 then Abort(b,'target_drift_release');return true end
   end
   if b:GetMana()<p.ability:GetManaCost()then Abort(b,'mana_release');return true end
   p.target=target;p.cooldown=cooldown;p.castAt=now
   hero.CastInvokerSpell(p.spell or p.ability,target);Log(b,'cast_order',p.name);return true
  end
  if hero.IsAbilityReadyForInvoke(p.ability) and now>=(p.invokeNext or 0) then
   local invoke=b:GetAbilityByName('invoker_invoke')
   if invoke and b:GetMana()<invoke:GetManaCost()+p.ability:GetManaCost()then Abort(b,'invoke_mana_release');return true end
   p.invokeNext=now+0.8;p.ownsQueue=true
   hero.InvokeActualSpell(p.ability);Log(b,'invoke_order',p.name)
  end
  return true
 end
 -- Build a short link from a currently observed allied control, not a predicted hidden cooldown.
 if ctx.fighting and Valid(ctx.target)and not ctx.retreat then
  local names={'modifier_stunned','modifier_crystal_maiden_frostbite','modifier_shadow_shaman_shackles','modifier_sheepstick_debuff'}
  for _,name in ipairs(names)do
   local i=ctx.target:GetModifierByName(name)
   if i and i>=0 and ctx.target:GetModifierRemainingDuration(i)>.6 then
    if not b._invokerLink or now>=b._invokerLink.untilTime then
     b._invokerLink={victim=ctx.target,name='team_control',at=now,untilTime=now+math.min(3,ctx.target:GetModifierRemainingDuration(i))}
    end
    break
   end
  end
 end
 local escape=b._invokerEscape
 if escape then
  local invisible=b.HasModifier and b:HasModifier('modifier_invoker_ghost_walk_self')
  local threatened=ctx.retreat or ctx.hp<0.55 or ctx.enemies and ctx.enemies>=2
  if now<escape.untilTime and invisible and threatened
   and not b:HasModifier('modifier_item_dustofappearance') then
   Log(b,'escape_hold','invoker_ghost_walk');return true
  end
  b._invokerEscape=nil
 end
 if b:NumQueuedActions()>0 then return true end
 if now<(b._invokerPlanNext or -999) then return true end
 b._invokerPlanNext=now+0.15
 local choice,best
 for _,s in ipairs(spells) do
  if not ctx.retreat or s.escape or s.ability:GetName()=='invoker_deafening_blast' then
   local consider=s.consider
   local link=b._invokerLink
   if hero.ConsiderLinkedSpell and link and now<link.untilTime and Valid(link.victim) and not ctx.retreat then
    consider=function()
     local d,t,w=hero.ConsiderLinkedSpell(s.ability,link.victim,link)
     if d and d>0 then return d,t,w end
     return s.consider()
    end
   end
   local desire,target=consider()
   if desire and desire>0 then
    local name=s.ability:GetName();local score=desire*10+s.weight
    if hero.IsAbilityReadyForCast(s.ability) then score=score+1 end
    if ctx.retreat and s.escape then score=score+20 end
    if ctx.hp<0.35 and s.escape then score=score+20 end
    if link and now<link.untilTime and Valid(link.victim) and (link.name=='invoker_tornado'or link.name=='team_control')
      and (name=='invoker_emp' or name=='invoker_chaos_meteor' or name=='invoker_sun_strike') then score=score+5 end
    if link and now<link.untilTime and Valid(link.victim) and link.name=='invoker_chaos_meteor' and name=='invoker_deafening_blast' then score=score+7 end
    if not ctx.fighting and (name=='invoker_alacrity' or name=='invoker_forge_spirit') then score=score+4 end
    if not best or score>best then best=score;choice={ability=s.ability,spell=s.spell,
      consider=consider,target=target,name=name,escape=s.escape,
      victim=not s.escape and link and now<link.untilTime and Valid(link.victim) and link.victim
        or not s.escape and ctx.fighting and Valid(ctx.target) and ctx.target or nil,
      deadline=now+(link and link.untilTime>now and math.min(6,link.untilTime-now+1)or 3.5),invokeNext=now} end
   end
  end
 end
 if not choice then return false end
 b._invokerPlan=choice;Log(b,'selected',choice.name)
 return X.Step(b,hero,spells,ctx)
end
return X
