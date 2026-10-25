-- Local control handoff; no movement, team tasks, or global cast queue changes.
local X={}
local modifiers={'modifier_lina_light_strike_array','modifier_skeleton_king_hellfire_blast',
 'modifier_shadow_shaman_shackles','modifier_shadow_shaman_voodoo','modifier_stunned',
 'modifier_beastmaster_primal_roar','modifier_crystal_maiden_frostbite','modifier_sven_storm_bolt','modifier_lion_voodoo','modifier_lion_impale','modifier_sheepstick_debuff',
 'modifier_alchemist_unstable_concoction','modifier_witch_doctor_paralyzing_cask','modifier_nyx_assassin_impale'}
function X.Remaining(target)
 if not target or target:IsNull()or not target:CanBeSeen()then return 0 end
 local remaining=0
 for _,name in ipairs(modifiers)do local i=target:GetModifierByName(name)
  if i and i>=0 then remaining=math.max(remaining,target:GetModifierRemainingDuration(i))end
 end
 return remaining
end
function X.RecordLocation(b,ability,loc)
 local delay=ability:GetCastPoint()+ability:GetSpecialValueFloat('light_strike_array_delay_time')
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE) or {}) do
  if e and not e:IsNull() and e:IsAlive() and e:CanBeSeen() and GetUnitToLocationDistance(e,loc)<=180 then
   e._ohaControlIntent={caster=b,at=DotaTime(),untilTime=DotaTime()+math.min(1.5,delay+0.25)}
  end
 end
end
local entityControl={lion_voodoo=true,shadow_shaman_voodoo=true,shadow_shaman_shackles=true,
 skeleton_king_hellfire_blast=true,vengefulspirit_magic_missile=true,sven_storm_bolt=true,
 chaos_knight_chaos_bolt=true,ogre_magi_fireblast=true,bane_nightmare=true}
function X.RecordEntity(b,a,t)
 if b~=GetBot()or not a or not entityControl[a:GetName()]or not t or t:IsNull()or not t:CanBeSeen()
  or t:GetTeam()==b:GetTeam()or not t:IsHero()then return end
 local delay=math.max(.1,a:GetCastPoint())
 if a:GetName()=='skeleton_king_hellfire_blast'or a:GetName()=='sven_storm_bolt'or a:GetName()=='vengefulspirit_magic_missile'then delay=delay+GetUnitToUnitDistance(b,t)/1000 end
 t._ohaControlIntent={caster=b,at=DotaTime(),untilTime=DotaTime()+math.min(1.5,delay+.25)}
end
function X.ShouldWait(b,target,ability,projectileSpeed)
 if not target or target:IsNull() or not target:IsAlive() or not target:IsHero() or not target:CanBeSeen()
  or target:GetTeam()==b:GetTeam() or target:IsChanneling() or target:IsUsingAbility() or target:IsCastingAbility() or b:GetHealth()/math.max(1,b:GetMaxHealth())<0.45
  or b:WasRecentlyDamagedByAnyHero(1) and b:GetHealth()/math.max(1,b:GetMaxHealth())<.65 or target:GetHealth()/math.max(1,target:GetMaxHealth())<0.25 then return false end
 local travel=ability:GetCastPoint()+(projectileSpeed and GetUnitToUnitDistance(b,target)/projectileSpeed or 0)
 local remaining=0
 for _,name in ipairs(modifiers) do
  local index=target:GetModifierByName(name)
  if index and index>=0 then remaining=math.max(remaining,target:GetModifierRemainingDuration(index)) end
 end
 local intent=target._ohaControlIntent
 local pending=intent and intent.caster and intent.caster~=b
     and not intent.caster:IsNull() and intent.caster:IsAlive() and intent.caster:GetTeam()==b:GetTeam()
     and DotaTime()<intent.untilTime and DotaTime()-intent.at<1.5
 local wait=remaining>travel+0.35 or pending
 if wait and DotaTime()>=(b._controlChainLogNext or 0) then
  b._controlChainLogNext=DotaTime()+3
  print(string.format('[CONTROL_CHAIN] t=%.2f pid=%d phase=await_control remaining=%.2f pending=%s',DotaTime(),b:GetPlayerID(),remaining,tostring(pending or false)))
 end
 return wait
end
function X.ShouldWaitLocation(b,loc,ability,delay,killDamage)
 if not loc then return false end
 local selected,count=nil,0
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE) or {}) do
  if e and not e:IsNull() and e:IsAlive() and e:CanBeSeen() and GetUnitToLocationDistance(e,loc)<=250 then
   count=count+1;selected=e
  end
 end
 if count~=1 then return false end -- Preserve multi-target area controls.
 if killDamage and selected:GetActualIncomingDamage(killDamage,DAMAGE_TYPE_MAGICAL)>=selected:GetHealth() then return false end
 local remaining=0
 for _,name in ipairs(modifiers) do local i=selected:GetModifierByName(name)
  if i and i>=0 then remaining=math.max(remaining,selected:GetModifierRemainingDuration(i)) end
 end
 if remaining<=ability:GetCastPoint()+(delay or 0)+0.35 then return false end
 return X.ShouldWait(b,selected,ability,nil)
end
function X.ShouldWaitEntity(b,target,ability,speed)
 if not target or target:IsNull() or not target:CanBeSeen() then return false end
 if ability:GetAbilityDamage()>0 and target:GetActualIncomingDamage(ability:GetAbilityDamage(),DAMAGE_TYPE_MAGICAL)>=target:GetHealth() then return false end
 local count=0
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE) or {}) do
  if e and not e:IsNull() and e:IsAlive() and e:CanBeSeen() and GetUnitToUnitDistance(e,target)<280 then count=count+1 end
 end
 if count>1 then return false end -- Preserve splash/bounce opportunities.
 return X.ShouldWait(b,target,ability,speed)
end

-- Only known single-target disables. Damage channels, area spells and items stay with hero logic.
local sequence={lion_voodoo=0,shadow_shaman_voodoo=0,shadow_shaman_shackles=0,
 skeleton_king_hellfire_blast=1000,vengefulspirit_magic_missile=1000,sven_storm_bolt=1000,
 chaos_knight_chaos_bolt=1000,ogre_magi_fireblast=0,beastmaster_primal_roar=0}
function X.AllowEntityOrder(b,a,t)
 local ok,result=pcall(function()
  if b~=GetBot()or not a or a:IsItem()or not sequence[a:GetName()]or not t or t:IsNull()
   or not t:IsAlive()or not t:IsHero()or t:IsIllusion()or t:GetTeam()==b:GetTeam()or not t:CanBeSeen()then return true end
  local victim=t:GetAttackTarget()
  if victim and not victim:IsNull()and victim:IsAlive()and victim:GetTeam()==b:GetTeam()
   and victim:GetHealth()/math.max(1,victim:GetMaxHealth())<.45 and victim:WasRecentlyDamagedByHero(t,1)then return true end
  local speed=sequence[a:GetName()]
  return not X.ShouldWaitEntity(b,t,a,speed>0 and speed or nil)
 end)
 if ok then return result end
 if b and DotaTime()>=(b._controlChainErrorNext or -1)then b._controlChainErrorNext=DotaTime()+10;print('[CONTROL_CHAIN_ERROR] '..tostring(result))end
 return true
end
return X
