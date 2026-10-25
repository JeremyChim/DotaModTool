-- Punish a visible local wave cutter, then release. Never searches fog or teleports.
local X={};local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local skills={lion_voodoo='entity',lion_impale='point',shadow_shaman_voodoo='entity',
 crystal_maiden_frostbite='entity',lich_sinister_gaze='entity',sven_storm_bolt='entity',
 vengefulspirit_magic_missile='entity',chaos_knight_chaos_bolt='entity',
 nyx_assassin_impale='point',leshrac_split_earth='point',tiny_avalanche='point',
 lina_light_strike_array='point',jakiro_ice_path='point',earthshaker_fissure='point'}
local function Kind(a,wanted)
 local flags=a:GetBehavior();local entity=math.floor(flags/8)%2==1;local point=math.floor(flags/16)%2==1
 if wanted=='point'and point then return 'point' end
 if entity then return 'entity' end
 if point then return 'point' end
end
local function Ready(b,e,Fu)
 for slot=0,23 do local a=b:GetAbilityInSlot(slot)
  if a and not a:IsNull()and skills[a:GetName()]and not a:IsHidden()and a:GetLevel()>0 and a:IsFullyCastable()
   and GetUnitToUnitDistance(b,e)<=Fu.GetProperCastRange(false,b,a:GetCastRange())-20
   and b:GetMana()-a:GetManaCost()>=math.max(100,b:GetMaxMana()*.2)and Kind(a,skills[a:GetName()])then return a,Kind(a,skills[a:GetName()])end
 end
end
function X.Try(b,Fu)
 if b~=GetBot()or not V(b)or b:IsIllusion()or b:IsInvulnerable()or b:IsInvisible()or b:IsChanneling()
  or b:IsUsingAbility()or b:IsCastingAbility()or b:IsStunned()or b:IsHexed()or b:IsSilenced()
  or b:NumQueuedActions()>0 or b._enigmaCombo or b._invokerPlan or Fu.IsRetreating(b)
  or b:GetHealth()/math.max(1,b:GetMaxHealth())<.5 or DotaTime()<(b._ohaAbilityOrderAt or -999)+.35 then return false end
 local now=DotaTime();if now<(b._cutTryNext or -999)then return false end;b._cutTryNext=now+.3
 for _,e in ipairs(b:GetNearbyHeroes(900,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and e:GetUnitName()=='npc_dota_hero_furion'and not Fu.IsSuspiciousIllusion(e)
   and Fu.CanCastOnNonMagicImmune(e)and Fu.CanCastOnTargetAdvanced(e)and not Fu.IsDisabled(e)then
   local target=e:GetAttackTarget();local cutting=V(target)and not target:IsHero()and not target:IsBuilding()
    and target:GetTeam()==b:GetTeam()and target:GetUnitName():find('creep',1,true)
   if cutting and GetUnitToUnitDistance(b,e)<800 and #e:GetNearbyTowers(850,false)==0 then
    local foes=0
    for _,u in ipairs(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE)or{})do
     if V(u)and u:CanBeSeen()and u~=e and not Fu.IsSuspiciousIllusion(u)then foes=foes+1 end
    end
    if foes==0 then
     local a,kind=Ready(b,e,Fu)
     local own=b:GetAttackTarget()
     local attack=not a and GetUnitToUnitDistance(b,e)<=b:GetAttackRange()+35
      and(not V(own)or not own:IsHero()and not own:IsBuilding())
     if a or attack then
      for _,ally in ipairs(b:GetNearbyHeroes(1000,false,BOT_MODE_NONE)or{})do
       if ally~=b and V(ally)and(ally._cutResponse and now<ally._cutResponse.untilTime
        or IsPlayerBot(ally:GetPlayerID())and not ally:IsStunned()and not ally:IsHexed()and not ally:IsSilenced()
        and not ally:IsChanneling()and not ally:IsUsingAbility()and not Fu.IsRetreating(ally)
        and ally:GetHealth()/math.max(1,ally:GetMaxHealth())>.5
        and(GetUnitToUnitDistance(ally,e)<GetUnitToUnitDistance(b,e)-40
         or math.abs(GetUnitToUnitDistance(ally,e)-GetUnitToUnitDistance(b,e))<=40 and ally:GetPlayerID()<b:GetPlayerID())
        and Ready(ally,e,Fu))then return false end
      end
      b._cutResponse={unit=e,origin=b:GetLocation(),untilTime=now+1.2,lastSeen=now}
      b._cutTryNext=now+3
      if attack then b:Action_AttackUnit(e,false)
      elseif kind=='point'then b:Action_UseAbilityOnLocation(a,Fu.GetCorrectLoc(e,a:GetCastPoint()+.2))
      else b:Action_UseAbilityOnEntity(a,e)end
      print('[CUT_RESPONSE] t='..now..' pid='..b:GetPlayerID()..' phase='..(attack and'visible_in_range_attack'or'visible_in_range_control')..' spell='..(a and a:GetName()or'none'))
      return true
     end
    end
   end
  end
 end
 return false
end
function X.OrderGoal(b,action,target)
 local s=b and b._cutResponse
 if not s or DotaTime()>s.untilTime+1.5 then return nil end
 if V(s.unit)and s.unit:CanBeSeen()then s.lastSeen=DotaTime();return nil end
 if DotaTime()-s.lastSeen<.8 or D(b:GetLocation(),s.origin)<280 then return nil end
 if (action:find('AttackUnit',1,true)and target==s.unit or action:find('Move',1,true)and b:GetAttackTarget()==s.unit)
  and not b:IsChanneling()and not b:IsUsingAbility()and not b:IsCastingAbility()and Safe(b,s.origin)then return s.origin end
end
for name,fallback in pairs({Try=function()return false end,OrderGoal=function()end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,result=pcall(raw,b,...);if ok then return result end
  if b and DotaTime()>=(b._cutErrorNext or -999)then b._cutErrorNext=DotaTime()+10
   print('[EXECUTION_ERROR] module=cut_response function='..name..' error='..tostring(result))end
  return fallback()
 end
end
return X
