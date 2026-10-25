-- Only modifies execution of an existing local pursuit/contact.
local X={};local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local Policy=require(GetScriptDirectory()..'/FuncLib/systems/engagement_policy')
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Protected(b)return not V(b)or b~=GetBot()or b:IsIllusion()or b:IsChanneling()
 or b:IsUsingAbility()or b:IsCastingAbility()or b:IsStunned()or b:IsRooted()or b:IsInvulnerable()
 or b:HasModifier('modifier_bloodseeker_rupture')end
function X.SpiderGoal(b,action,target,Fu)
 if Protected(b)or b:GetUnitName()~='npc_dota_hero_broodmother'then return nil end
 local now=DotaTime();local s=b._spiderCommit
 if s and s.goal and now<s.untilTime then return s.goal end
 if Fu.IsRetreating(b)or not Fu.IsGoingOnSomeone(b)then b._spiderCommit=nil;return nil end
 if not V(target)or not target:IsHero()then target=b:GetAttackTarget()end
 if not Policy.Real(b,target,Fu,true)then b._spiderCommit=nil;return nil end
 if not s or s.target~=target then s={target=target,at=now,origin=b:GetLocation()};b._spiderCommit=s end
 local d=GetUnitToUnitDistance(b,target)
 if d<b:GetAttackRange()+100 and b:GetEstimatedDamageToTarget(true,target,1,DAMAGE_TYPE_PHYSICAL)>target:GetHealth()*1.2 then return nil end
 local helpers=0
 for _,a in ipairs(b:GetNearbyHeroes(1400,false,BOT_MODE_NONE)or{})do
  if a~=b and V(a)and not a:IsIllusion()and not a:IsStunned()and a:GetHealth()/math.max(1,a:GetMaxHealth())>.35
   and D(a:GetLocation(),target:GetLocation())<math.max(650,a:GetAttackRange()+150)then helpers=helpers+1 end
 end
 local towers=target:GetNearbyTowers(850,false)or{}
 local enemies=#Policy.Enemies(b,target:GetLocation(),900,Fu,false)
 local overextend=helpers==0 and(#towers>0 or enemies>=2 and Fu.GetHP(b)<.65
  or now-s.at>5 and D(b:GetLocation(),s.origin)>900 and enemies>=1)
 if not overextend or now<(s.retryAt or -1)then return nil end
 local home=GetAncient(b:GetTeam());if not V(home)then return nil end
 local here=b:GetLocation();local a=home:GetLocation();local length=math.max(1,D(here,a))
 local point=Vector(here.x+(a.x-here.x)/length*380,here.y+(a.y-here.y)/length*380,here.z)
 if not Safe(b,point)then return nil end
 s.goal=point;s.untilTime=now+.8;s.retryAt=now+3
 print('[SPIDER_COMMIT] t='..now..' pid='..b:GetPlayerID()..' phase=unsupported_pursuit_exit')
 return point
end
function X.Support(b,Fu)
 if Protected(b)or b:NumQueuedActions()>0 or DotaTime()<(b._supportCastNext or -1)
  or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 then return false end
 local names={npc_dota_hero_witch_doctor='witch_doctor_paralyzing_cask',npc_dota_hero_crystal_maiden='crystal_maiden_frostbite',
  npc_dota_hero_techies='techies_sticky_bomb',npc_dota_hero_shadow_shaman='shadow_shaman_voodoo',npc_dota_hero_lion='lion_voodoo'}
 local name=names[b:GetUnitName()];if not name then return false end
 local a=b:GetAbilityByName(name);if not a or not a:IsFullyCastable()then return false end
 local range=Fu.GetProperCastRange(false,b,a:GetCastRange())
 local target=Policy.SupportTarget(b,range,Fu)
 if not target or not Fu.CanCastOnNonMagicImmune(target)or not Fu.CanCastOnTargetAdvanced(target)
  or Fu.IsDisabled(target)and not target:IsChanneling()then return false end
 b._supportCastNext=DotaTime()+.5
 if name=='techies_sticky_bomb'then b:Action_UseAbilityOnLocation(a,Fu.GetCorrectLoc(target,a:GetCastPoint()+.3))
 else b:Action_UseAbilityOnEntity(a,target)end
 print('[LOCAL_SUPPORT] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=in_range_control')
 return true
end
-- An already visible Earthshaker is enough to avoid packing a rear hero with summons.
function X.EchoSpacing(b)
 if Protected(b)or b:GetAttackRange()<400 or b:NumQueuedActions()>0
  or DotaTime()<(b._echoSpaceNext or -1)or DotaTime()<(b._ohaAbilityOrderAt or -999)+.4 then return false end
 local shaker
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and e:GetUnitName()=='npc_dota_hero_earthshaker'then shaker=e;break end
 end
 if not shaker then return false end
 local crowd=0;local here=b:GetLocation()
 for _,u in ipairs(GetUnitList(UNIT_LIST_ALLIES)or{})do
  if V(u)and u~=b and not u:IsBuilding()and not u:GetUnitName():find('ward',1,true)
   and D(here,u:GetLocation())<350 then crowd=crowd+1 end
 end
 if crowd<4 then return false end
 local e=shaker:GetLocation();local dx,dy=here.x-e.x,here.y-e.y;local length=math.max(1,D(here,e));dx,dy=dx/length,dy/length
 local p=Vector(here.x+dx*280-dy*240*(b:GetPlayerID()%2==0 and 1 or -1),here.y+dy*280+dx*240*(b:GetPlayerID()%2==0 and 1 or -1),here.z)
 if not Safe(b,p)then return false end
 local after=0
 for _,u in ipairs(GetUnitList(UNIT_LIST_ALLIES)or{})do if V(u)and u~=b and not u:IsBuilding()and D(p,u:GetLocation())<350 then after=after+1 end end
 if after>=crowd then return false end
 b._echoSpaceNext=DotaTime()+3;b._echoSpaceGoal=p;b._echoSpaceUntil=DotaTime()+.6
 b:Action_MoveToLocation(p)
 print('[ECHO_SPACING] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=visible_shaker_unit_crowd')
 return true
end
function X.MinionSpacing(owner,u)
 if not V(owner)or not V(u)or u:IsChanneling()or u:IsUsingAbility()or u:IsCastingAbility()
  or DotaTime()<(u._echoSpaceNext or -1)or GetUnitToUnitDistance(owner,u)>450 then return false end
 local name=u:GetUnitName()
 if not u:IsIllusion()and not name:find('spider',1,true)then return false end
 local target=u:GetAttackTarget();if V(target)and target:IsBuilding()then return false end
 local shaker=false
 for _,e in ipairs(owner:GetNearbyHeroes(1400,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and e:GetUnitName()=='npc_dota_hero_earthshaker'then shaker=true end
 end
 if not shaker then return false end
 local allies=owner:GetNearbyHeroes(650,false,BOT_MODE_NONE)or{};local rear
 for _,a in ipairs(allies)do if a~=owner and V(a)and not a:IsIllusion()and a:GetAttackRange()>400 and GetUnitToUnitDistance(a,u)<300 then rear=a;break end end
 if not rear then return false end
 local here=u:GetLocation();local a=rear:GetLocation();local len=math.max(1,D(here,a));local dx,dy=(here.x-a.x)/len,(here.y-a.y)/len
 if len<20 then local angle=(u:GetPlayerID()%5)*math.pi*.4;dx,dy=math.cos(angle),math.sin(angle)end
 local p=Vector(here.x+dx*280,here.y+dy*280,here.z)
 if not Safe(u,p)then return false end
 u._echoSpaceNext=DotaTime()+2;u:Action_MoveToLocation(p);return true
end

for name,fallback in pairs({SpiderGoal=function()end,Support=function()return false end,EchoSpacing=function()return false end,MinionSpacing=function()return false end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,a,d=pcall(raw,b,...);if ok then return a,d end
  if b and DotaTime()>=(b._local_commitmentErrorNext or -1)then
   b._local_commitmentErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=local_commitment function='..name..' error='..tostring(a))
  end
  return fallback(b,...)
 end
end
return X
