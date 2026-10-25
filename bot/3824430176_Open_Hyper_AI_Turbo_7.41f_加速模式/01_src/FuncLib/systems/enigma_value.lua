-- Evaluate the current Black Hole opportunity again after refresh; never pre-authorize two casts.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
function X.Allow(b,Fu,loc,hole,afterRefresh)
 local policy=require(GetScriptDirectory()..'/FuncLib/systems/engagement_policy')
 local targets=policy.Enemies(b,loc,hole:GetSpecialValueInt('radius')*.85,Fu,true)
 if #targets==0 then return false end
 if require(GetScriptDirectory()..'/FuncLib/systems/defence_boundary').Goal(b,'Action_MoveToLocation',loc)then return false end
 if #targets>=2 then return true end
 local t=targets[1]
 if t:HasModifier('modifier_enigma_black_hole_pull')or t:HasModifier('modifier_item_aeon_disk_buff')or t:HasModifier('modifier_dazzle_shallow_grave')then return false end
 local allies=b:GetNearbyHeroes(1400,false,BOT_MODE_NONE)or{};local ready,damage=0,0
 for _,a in ipairs(allies)do if a~=b and V(a)and not a:IsIllusion()and not a:IsStunned()and not a:IsHexed()then
  if GetUnitToUnitDistance(a,t)<=a:GetAttackRange()+150 then ready=ready+1
   if a:GetAttackTarget()==t then damage=damage+a:GetEstimatedDamageToTarget(true,t,1.2,DAMAGE_TYPE_PHYSICAL)end
  end
 end end
 if damage>t:GetHealth()*1.15 then return false end
 local disabled=require(GetScriptDirectory()..'/FuncLib/systems/control_chain').Remaining(t)
 if disabled>1.5 and HP(t)<.45 and ready>0 then return false end
 local emergency=Fu.IsDefending(b)and ready<=1 or b:WasRecentlyDamagedByHero(t,1)and HP(b)<.4
 local valuable=t:IsChanneling()or t:GetEstimatedDamageToTarget(true,b,3,DAMAGE_TYPE_PHYSICAL)>b:GetMaxHealth()*.55
 local recent=b._lastBlackHole and DotaTime()-b._lastBlackHole.at<20
 if afterRefresh or recent then return emergency or valuable and HP(t)>.5 and ready>=1 end
 return emergency or HP(t)>.4 and ready>=1 or valuable
end
function X.Record(b,Fu,loc,hole)
 local ids={};for _,t in ipairs(require(GetScriptDirectory()..'/FuncLib/systems/engagement_policy').Enemies(b,loc,hole:GetSpecialValueInt('radius'),Fu,true))do ids[#ids+1]=t:GetPlayerID()end
 b._lastBlackHole={at=DotaTime(),ids=ids}
end
function X.Refresh(b,Fu,item)
 if b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()or b._enigmaCombo then return false end
 local hole=b:GetAbilityByName('enigma_black_hole');if not hole or hole:IsNull()or hole:GetCooldownTimeRemaining()<10 then return false end
 if b:GetMana()<hole:GetManaCost()+item:GetManaCost()+50 then return false end
 for _,t in ipairs(b:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{})do
  if V(t)and t:CanBeSeen()and not Fu.IsSuspiciousIllusion(t)and X.Allow(b,Fu,t:GetLocation(),hole,true)then return true end
 end;return false
end
return X
