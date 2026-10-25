-- Current Haunt and basic Shadow Step are independent abilities. Local execution only.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local function Body(u)return V(u)and not u:IsIllusion()and not u:HasModifier('modifier_arc_warden_tempest_double')end
function X.CanLand(b,t,Fu)
 if not V(t)or not t:IsHero()or t:IsInvulnerable()or t:IsAttackImmune()or Fu.IsSuspiciousIllusion(t)or HP(b)<.4
  or Fu.IsRetreating(b)or b:IsRooted()then return false end
 local p=t:GetLocation()
 if Fu.IsLocationInChrono(p)or Fu.IsLocationInBlackHole(p)
  or require(GetScriptDirectory()..'/FuncLib/systems/fountain_safety').Forbidden(b,p)then return false end
 local friends,foes=0,0;local seen={}
 for _,a in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)or{})do
  if a~=b and Body(a)and HP(a)>.35 and not a:IsStunned()and not a:IsHexed()and D(a:GetLocation(),p)<1000 then
   local id=a:GetPlayerID();if not seen[id]then seen[id]=true;friends=friends+1 end
  end
 end
 seen={}
 for _,e in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do
  if Body(e)and not Fu.IsSuspiciousIllusion(e)and D(e:GetLocation(),p)<1000 then
   local id=e:GetPlayerID();if not seen[id]then seen[id]=true;foes=foes+1 end
  end
 end
 return friends>=1 and friends+1>=foes or foes<=1 and HP(b)>.65
  and b:GetEstimatedDamageToTarget(true,t,3,DAMAGE_TYPE_PHYSICAL)>t:GetHealth()*.65
end
function X.Choose(b,a,global,Fu)
 if not a or a:IsHidden()or not a:IsTrained()or not a:IsFullyCastable()or Fu.IsRetreating(b)then return nil end
 local best,score
 for _,t in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do
  if V(t)and X.CanLand(b,t,Fu)then
   local d=GetUnitToUnitDistance(b,t)
   local supported=false
   for _,ally in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)or{})do
    if ally~=b and Body(ally)and HP(ally)>.35 and D(ally:GetLocation(),t:GetLocation())<1000
     and (ally:WasRecentlyDamagedByAnyHero(2)or ally:GetAttackTarget()==t)then supported=true;break end
   end
   if (global and supported and(d>1100 or Fu.IsInTeamFight(b,1200)))
    or (not global and d>500 and d<=a:GetCastRange()and Fu.IsGoingOnSomeone(b))then
    local value=(t:IsChanneling()and 500 or 0)+(t:GetAttackRange()>400 and 150 or 0)
     +(1-HP(t))*200+(supported and 100 or 0)-math.min(6000,d)*.01
    if not score or value>score then best,score=t,value end
   end
  end
 end
 return best
end
function X.Follow(b,dagger,Fu)
 local s=b._spectreAssault;if not s then return false end
 if DotaTime()>s.untilTime or not X.CanLand(b,s.target,Fu)then b._spectreAssault=nil;return false end
 if b:IsUsingAbility()or b:IsCastingAbility()or b:IsChanneling()or b:NumQueuedActions()>0 then return true end
 if DotaTime()<s.after then return true end
 if s.stage=='dagger' then
  s.stage='manta';s.after=DotaTime()+.5
  if dagger:IsFullyCastable()and not b:IsSilenced()and GetUnitToUnitDistance(b,s.target)<=dagger:GetCastRange()then
   b:Action_UseAbilityOnEntity(dagger,s.target);return true
  end
 end
 if s.stage=='manta'then
  b._spectreAssault=nil
  if b:IsMuted()then return false end
  for i=0,5 do local a=b:GetItemInSlot(i)
   if a and a:GetName()=='item_manta'and a:IsFullyCastable()and GetUnitToUnitDistance(b,s.target)<=b:GetAttackRange()+220 then
    b:Action_UseAbility(a);return true
   end
  end
 end
 return false
end

do local raw=X.CanLand;X.CanLand=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spectre_planErrorNext or -1)then b._spectre_planErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spectre_plan function=CanLand error='..tostring(value))end
 return false
end end
do local raw=X.Choose;X.Choose=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spectre_planErrorNext or -1)then b._spectre_planErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spectre_plan function=Choose error='..tostring(value))end
 return nil
end end
do local raw=X.Follow;X.Follow=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._spectre_planErrorNext or -1)then b._spectre_planErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=spectre_plan function=Follow error='..tostring(value))end
 return false
end end
return X
