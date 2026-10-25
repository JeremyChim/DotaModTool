-- Local self-preservation spells; never moves a hero or changes team tasks.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local function Log(b,phase,t)
 local now=DotaTime()
 if now>=(b._survivalLogNext or -1)then b._survivalLogNext=now+1
  print(string.format('[SURVIVAL_SPELL] t=%.2f pid=%d phase=%s target=%s',now,b:GetPlayerID(),phase,t:GetUnitName()))
 end
end
function X.Sunder(b,a,Fu)
 if b~=GetBot()or not a:IsFullyCastable()then return BOT_ACTION_DESIRE_NONE,nil end
 local now=DotaTime();local hp=HP(b);local old=b._sunderHealth
 local dt=old and now-old.at or 0
 local loss=old and old.loss or 0
 if old and dt>=.12 then loss=dt<1.2 and math.max(0,(old.hp-b:GetHealth())/dt)or 0 end
 if not old or now-old.at>=.12 then b._sunderHealth={at=now,hp=b:GetHealth(),loss=loss}end
 if not b:WasRecentlyDamagedByAnyHero(1)then loss=0 end
 local urgent=hp<.35 or hp<.55 and loss>0 and b:GetHealth()/loss<a:GetCastPoint()+1.1
 if not urgent then return BOT_ACTION_DESIRE_NONE,nil end
 local range=Fu.GetProperCastRange(false,b,a:GetCastRange());local best,score
 for _,u in ipairs(Fu.GetNearbyHeroes(b,range,true,BOT_MODE_NONE)or{})do
  if V(u)and u:IsHero()and u:GetTeam()~=b:GetTeam()and not Fu.IsSuspiciousIllusion(u)
   and Fu.CanCastOnNonMagicImmune(u)and Fu.CanCastOnTargetAdvanced(u)
   and GetUnitToUnitDistance(b,u)<=range then
   local gain=HP(u)-hp
   if gain>=.18 and gain*b:GetMaxHealth()>=100 and(not score or gain>score)then best,score=u,gain end
  end
 end
 if best then Log(b,hp<.35 and'sunder_low_health'or'sunder_lethal_rate',best);return BOT_ACTION_DESIRE_HIGH,best end
 return BOT_ACTION_DESIRE_NONE,nil
end
function X.Cleanse(b,a,Fu)
 if b~=GetBot()or not a:IsTrained()or not a:IsFullyCastable()then return BOT_ACTION_DESIRE_NONE,nil end
 local range=Fu.GetProperCastRange(false,b,a:GetCastRange());local list=Fu.GetNearbyHeroes(b,range,false,BOT_MODE_NONE)or{}
 local units={b};for _,u in ipairs(list)do if u~=b then units[#units+1]=u end end
 local best,score
 for _,u in ipairs(units)do
  if V(u)and u:IsHero()and u:GetTeam()==b:GetTeam()and not u:IsIllusion()and not Fu.IsSuspiciousIllusion(u)
   and not u:IsInvulnerable()and GetUnitToUnitDistance(b,u)<=range
   and not u:HasModifier('modifier_shadow_demon_demonic_cleanse')
   and not u:HasModifier('modifier_legion_commander_duel')
   and not u:HasModifier('modifier_doom_bringer_doom')
   and not u:HasModifier('modifier_faceless_void_chronosphere_freeze')
   and not u:HasModifier('modifier_enigma_black_hole_pull')
   and not u:HasModifier('modifier_necrolyte_reapers_scythe')then
   local disabled=u:IsStunned()or u:IsRooted()or u:IsHexed()or u:IsSilenced()or Fu.IsTaunted(u)
   if disabled and u:WasRecentlyDamagedByAnyHero(2)then
    local value=(1-HP(u))*2+(u:IsStunned()and 1 or 0)+(u:IsHexed()and 1 or 0)
    if not score or value>score then best,score=u,value end
   end
  end
 end
 if best then Log(b,'cleanse_ally_control',best);return BOT_ACTION_DESIRE_HIGH,best end
 return BOT_ACTION_DESIRE_NONE,nil
end
return X
