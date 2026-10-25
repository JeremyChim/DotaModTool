-- Visible, distinct opponents and expected time in the army, not raw models.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Protected(u)
 return u:IsInvulnerable()or u:IsAttackImmune()or u:HasModifier('modifier_dazzle_shallow_grave')
  or u:HasModifier('modifier_oracle_false_promise_timer')or u:HasModifier('modifier_templar_assassin_refraction_absorb')
end
local function Held(u)
 if u:IsStunned()or u:IsRooted()or u:IsHexed()then return true end
 return u:HasModifier('modifier_enigma_black_hole_pull')or u:HasModifier('modifier_enigma_black_hole_pull_scepter')
end
local function EnemyBlackHole(b)
 for _,u in ipairs(b:GetNearbyHeroes(1600,false,BOT_MODE_NONE)or{})do
  if V(u)and (u:HasModifier('modifier_enigma_black_hole_pull')or u:HasModifier('modifier_enigma_black_hole_pull_scepter'))then return true end
 end
 return false
end
function X.Choose(b,a,target,Fu)
 if not a:IsFullyCastable()or b:IsChanneling()then return nil end
 local radius=a:GetSpecialValueInt('second_radius');if radius<100 then return nil end
 local range=a:GetSpecialValueInt('cast_range');local delay=math.max(.6,a:GetCastPoint()+.3)
 local hp=b:GetHealth()/math.max(1,b:GetMaxHealth())
 if hp<.3 or Fu.IsRetreating(b)then return nil end
 local enemies=Fu.GetEnemiesNearLoc(b:GetLocation(),math.min(1600,range+radius))or{}
 local list,ids={},{}
 for _,u in ipairs(enemies)do if V(u)and not Fu.IsSuspiciousIllusion(u)and not Protected(u)then
  local id=u:GetPlayerID();if not ids[id]then ids[id]=true;list[#list+1]=u end
 end end
 if #list==0 then return nil end
 local allies=Fu.GetAlliesNearLoc(b:GetLocation(),1200)or{};local ready=0
 for _,u in ipairs(allies)do if u~=b and V(u)and u:GetHealth()/math.max(1,u:GetMaxHealth())>.4
  and not u:IsStunned()and not u:IsHexed()and not u:IsDisarmed()and not u:IsIllusion()
  and not u:HasModifier('modifier_arc_warden_tempest_double')then ready=ready+1 end end
 if hp<.5 and ready==0 and #list>=2 then return nil end
 local body=b._combatPosition;local loss=body and body.dps or 0
 if loss>0 and b:GetHealth()/loss<delay+2 then return nil end
 local home=GetAncient(b:GetTeam());local emergency=home and not home:IsNull()and GetUnitToUnitDistance(b,home)<2200
 if not emergency and #list>ready+2 then return nil end
 local best,score,reason;local hostileHole=EnemyBlackHole(b)
 for _,u in ipairs(list)do
  local point=Held(u)and u:GetLocation()or u:GetExtrapolatedLocation(delay)
  if point and D(b:GetLocation(),point)<=range and D(b:GetLocation(),point)<radius-100
   and not Fu.IsLocationInChrono(point)and not hostileHole then
   local count,held=0,0
   for _,e in ipairs(list)do
    local p=Held(e)and e:GetLocation()or e:GetExtrapolatedLocation(delay)
    if p and D(p,point)<radius*.72 then count=count+1;if Held(e)then held=held+1 end end
   end
   local single=false
   if count==1 and u==target and Held(u)and Fu.IsCore(u)and ready>=1
    and u:GetHealth()>b:GetAttackDamage()*3 then
    local damage=b:GetEstimatedDamageToTarget(true,u,3,DAMAGE_TYPE_PHYSICAL)
    single=damage>=u:GetHealth()*.45
   end
   local fort=GetAncient(b:GetTeam())
   local defending=fort and not fort:IsNull()and GetUnitToUnitDistance(b,fort)<2200
    and b:WasRecentlyDamagedByAnyHero(2)and count>=1 and held>=1
   if (count>=2 and(ready>=1 or hp>.65))or single or defending then
    local value=count*10+held*5-D(point,b:GetLocation())/1000
    if not score or value>score then best,score,reason=point,value,held>0 and'controlled_window'or'multiple_real_enemies'end
   end
  end
 end
 if best then
  if DotaTime()>=(b._wukongLogNext or -1)then b._wukongLogNext=DotaTime()+3
   print(string.format('[WUKONG_PLAN] t=%.2f pid=%d phase=%s',DotaTime(),b:GetPlayerID(),reason))end
  return best
 end
 return nil
end
function X.OrderGoal(b,action,target)
 local s=b._wukongArmy
 if not s or b~=GetBot()or not V(b)or DotaTime()>s.untilTime or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
  or b:IsStunned()or b:IsRooted()or b:GetHealth()/math.max(1,b:GetMaxHealth())<.5 then return nil end
 local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils');if Fu.IsRetreating(b)then return nil end
 local t=action:find('AttackUnit',1,true)and target or b:GetAttackTarget()
 if not V(t)or not t:IsHero()or t:GetTeam()==b:GetTeam()then return nil end
 local a=b:GetAbilityByName('monkey_king_wukongs_command')
 if not a or a:GetCooldownTimeRemaining()<1 then return nil end
 local radius=a:GetSpecialValueInt('second_radius');if radius<200 then return nil end
 local p=t:GetLocation();if D(p,s.loc)<radius-80 or D(b:GetLocation(),s.loc)>radius then return nil end
 if not(action:find('Move',1,true)or action:find('Attack',1,true))then return nil end
 local length=math.max(1,D(p,s.loc));local q=Vector(s.loc.x+(p.x-s.loc.x)/length*(radius-130),s.loc.y+(p.y-s.loc.y)/length*(radius-130),s.loc.z)
 local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
 if Safe(b,q)then return q end
end
local Raw=X.Choose
function X.Choose(b,...)
 local ok,result=pcall(Raw,b,...)
 if ok then return result end
 if DotaTime()>=(b._wukongErrorNext or -1)then b._wukongErrorNext=DotaTime()+10;print('[WUKONG_ERROR] '..tostring(result))end
 return nil
end
return X
