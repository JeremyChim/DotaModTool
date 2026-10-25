-- Reassesses an existing local building commitment; never starts a push or gathers allies.
local X={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Own(b)return b==GetBot()and V(b)and b:IsHero()and not b:IsIllusion()end
local function Protected(b)
 return not Own(b)or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()or b:IsStunned()
  or b:IsRooted()or b:IsHexed()or b:IsInvulnerable()or b:IsInvisible()or b._guardTravel or b._guardBaseArea
  or b:HasModifier('modifier_smoke_of_deceit')or b:HasModifier('modifier_bloodseeker_rupture')
end
local function Highground(b,t)
 local fort=GetAncient(b:GetTeam()==2 and 3 or 2)
 return V(fort)and V(t)and D(t:GetLocation(),fort:GetLocation())<2700
end
local function Log(b,phase,target)
 local s=b._siegeExec;local now=DotaTime()
 if now>=(s.logNext or -1)then s.logNext=now+3
  print(string.format('[SIEGE_EXEC] t=%.2f pid=%d phase=%s target=%s',now,b:GetPlayerID(),phase,target and not target:IsNull()and target:GetUnitName()or'none'))end
end
local function DamageRate(b,t)
 return math.max(1,b:GetEstimatedDamageToTarget(true,t,2,DAMAGE_TYPE_PHYSICAL)/2)
end
local function Sample(b)
 local now=DotaTime();local s=b._siegeExec or{};b._siegeExec=s
 if not s.bodyAt or now-s.bodyAt>=.2 then
  local dt=s.bodyAt and now-s.bodyAt or 0
  s.bodyLoss=dt>=.2 and dt<1.2 and math.max(0,((s.bodyHP or b:GetHealth())-b:GetHealth())/dt)or 0
  s.bodyAt=now;s.bodyHP=b:GetHealth()
 end
 return s
end
local function ExitPoint(b,enemies)
 local here=b:GetLocation();local home=GetAncient(b:GetTeam());if not V(home)then return nil end
 local away=home:GetLocation();local best,score
 for i=-3,3 do
  local dx,dy=away.x-here.x,away.y-here.y;local length=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/length,dy/length
  local a=i*30*math.pi/180;local p=Vector(here.x+(dx*math.cos(a)-dy*math.sin(a))*420,here.y+(dx*math.sin(a)+dy*math.cos(a))*420,here.z)
  if Safe(b,p)then
   local before,after=99999,99999
   for _,e in ipairs(enemies)do before=math.min(before,D(here,e:GetLocation()));after=math.min(after,D(p,e:GetLocation()))end
   local value=after-before-D(p,away)*.03
   if after>before+60 and(not score or value>score)then best,score=p,value end
  end
 end
 return best
end
function X.AfterContact(b,target)
 if not Own(b)or Protected(b)then return nil end
 local s=Sample(b);local now=DotaTime()
 if not s.last or now-s.last>3 or not s.contactLoc or D(b:GetLocation(),s.contactLoc)>650
  or not b:WasRecentlyDamagedByAnyHero(1)or b:GetHealth()/math.max(1,b:GetMaxHealth())>=.45
  or(s.bodyLoss or 0)<=0 or b:GetHealth()/s.bodyLoss>2.5 then return nil end
 if V(target)and target:IsHero()and target:CanBeSeen()and not target:IsIllusion()
  and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+100
  and b:GetEstimatedDamageToTarget(true,target,1,DAMAGE_TYPE_PHYSICAL)>target:GetHealth()*1.1 then return nil end
 local enemies={}
 for _,e in ipairs(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and not e:IsIllusion()then enemies[#enemies+1]=e end
 end
 if #enemies==0 then return nil end
 local goal=ExitPoint(b,enemies);if not goal then return nil end
 s.goal=goal;s.untilTime=now+.8;Log(b,'after_building_lethal_contact',target);return goal
end
function X.Check(b,target)
 if not Own(b)or (DotaTime()<1080 and not Highground(b,target)) or not V(target)or not target:IsBuilding()or target:GetTeam()==b:GetTeam()
  or not target:CanBeSeen()or target:IsInvulnerable()or target:IsAttackImmune()then return true end
 if Protected(b)or GetUnitToUnitDistance(b,target)>b:GetAttackRange()+300 then return true end
 local now=DotaTime();local s=Sample(b);s.contactLoc=b:GetLocation()
 if s.target~=target then s.target=target;s.at=now;s.hp=b:GetHealth();s.buildingHP=target:GetHealth();s.loss=0;s.progress=0;s.progressObserved=nil end
 if now>=(s.next or -1)then
  local dt=now-s.at
  if dt>=.4 then
   s.loss=dt<=2 and math.max(0,(s.hp-b:GetHealth())/dt)or 0
   s.progress=dt<=2 and math.max(0,(s.buildingHP-target:GetHealth())/dt)or 0;s.progressObserved=dt<=2
   s.at=now;s.hp=b:GetHealth();s.buildingHP=target:GetHealth()
  end
  s.next=now+.2
 end
 s.last=now
 local enemies={};local ids={}
 for _,e in ipairs(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and not e:IsIllusion()and not e:HasModifier('modifier_illusion')then
   local id=e:GetPlayerID();if not ids[id]then ids[id]=true;enemies[#enemies+1]=e end
  end
 end
 if Highground(b,target)and #enemies>=2 and b:WasRecentlyDamagedByAnyHero(1)then
  local arrived=0
  for _,a in ipairs(b:GetNearbyHeroes(900,false,BOT_MODE_NONE)or{})do
   if a~=b and V(a)and not a:IsIllusion()and not a:IsStunned()and a:GetHealth()/math.max(1,a:GetMaxHealth())>.35
    and GetUnitToUnitDistance(a,target)<a:GetAttackRange()+300 then arrived=arrived+1 end
  end
  if arrived==0 and #(b:GetNearbyLaneCreeps(800,false)or{})==0 and b:GetHealth()/b:GetMaxHealth()<.7
   and target:GetHealth()/DamageRate(b,target)>2 then
   local point=ExitPoint(b,enemies)
   if point then s.goal=point;s.untilTime=now+1;Log(b,'unsupported_highground_contact',target);return false end
  end
 end
 if not b:WasRecentlyDamagedByAnyHero(1)or #enemies==0 then s.goal=nil;return true end
 if #enemies==1 and(not s.bodyLoss or s.bodyLoss<=0 or b:GetHealth()/s.bodyLoss>2.5)then s.goal=nil;return true end
 local hp=b:GetHealth()/math.max(1,b:GetMaxHealth());local dps=DamageRate(b,target);local helpers=0
 for _,u in ipairs(b:GetNearbyHeroes(1100,false,BOT_MODE_NONE)or{})do
  if u~=b and V(u)and not u:IsIllusion()and not u:IsStunned()and not u:IsHexed()
   and u:GetHealth()/math.max(1,u:GetMaxHealth())>.3 and u:GetAttackTarget()==target
   and GetUnitToUnitDistance(u,target)<=u:GetAttackRange()+100 then
   helpers=helpers+1;dps=dps+DamageRate(u,target)
  end
 end
 local finish=target:GetHealth()/math.max(1,dps)
 if s.at and s.last and now-s.last<1 and s.progress>=0 and s.progressObserved then finish=target:GetHealth()/math.max(1,s.progress)end
 if finish<2 and hp>.3 then s.goal=nil;Log(b,'short_finish_preserved',target);return true end
 local lethal=s.loss>0 and b:GetHealth()/s.loss or 999
 -- A short exit keeps its execution owner when the original AI switches to a hero.
 local noWave=Highground(b,target)and #(b:GetNearbyLaneCreeps(800,false)or{})==0
 local unsafe=noWave and hp<.65 and helpers==0 and s.progressObserved and s.progress<20 and finish>4
  or hp<.55 and(finish>lethal+1 or helpers==0 and hp<.4 and finish>4)
  or hp<.45 and s.progress<20 and finish>4
 if not unsafe then s.goal=nil;return true end
 local best=ExitPoint(b,enemies)
 if not best then return true end
 s.goal=best;s.untilTime=now+1;Log(b,'unsafe_building_commit',target);return false
end
function X.OrderGoal(b,action,target)
 if require(GetScriptDirectory()..'/FuncLib/systems/base_execution').InScope(b)then return nil end
 if not Own(b)or Protected(b)then return nil end
 if action=='Action_AttackUnit'or action=='ActionPush_AttackUnit'or action=='ActionQueue_AttackUnit'then
  if not V(target)or not target:IsBuilding()then
   local goal=X.AfterContact(b,target);if goal then return goal end
   local s=b._siegeExec
   if s and s.goal and DotaTime()<(s.untilTime or -1)and b:WasRecentlyDamagedByAnyHero(1)then return s.goal end
   if s then s.goal=nil end;return nil end
  if not X.Check(b,target)then return b._siegeExec.goal end
 end
 local s=b._siegeExec
 if not s or not s.goal or DotaTime()>(s.untilTime or -1)then return nil end
 local foot=action=='Action_MoveToLocation'or action=='Action_MoveDirectly'or action=='Action_AttackMove'
  or action=='ActionPush_MoveToLocation'or action=='ActionQueue_MoveToLocation'
 if foot and V(s.target)and b:WasRecentlyDamagedByAnyHero(1)then return s.goal end
 return nil
end
-- Execution only inside a highground already reached by the original AI.
-- No desire, gathering, lane selection, teleport or map-wide push task.
local function LocalMode(b)
 local m=b:GetActiveMode()
 return m==BOT_MODE_PUSH_TOWER_TOP or m==BOT_MODE_PUSH_TOWER_MID or m==BOT_MODE_PUSH_TOWER_BOT
  or m==BOT_MODE_ATTACK or m==BOT_MODE_TEAM_ROAM
end
local function Attackable(b,u)
 return V(u)and u:IsBuilding()and u:GetTeam()~=b:GetTeam()and u:CanBeSeen()
  and not u:IsInvulnerable()and not u:IsAttackImmune()
  and not u:HasModifier('modifier_fountain_glyph')and not u:HasModifier('modifier_backdoor_protection_active')
end
local function LocalGoal(b)
 if not Own(b)or Protected(b)or not LocalMode(b)or b._siegeOwnOrder or b._enigmaCombo or b._invokerPlan
  or b._hazardOwnOrder or DotaTime()<(b._hazardExitUntil or -999)
  or b._staticLinkEscape or b._counterTask or b._localRescueUntil and DotaTime()<b._localRescueUntil
  or b:GetHealth()/math.max(1,b:GetMaxHealth())<.55 then return nil end
 local fort=GetAncient(GetOpposingTeam())
 if not V(fort)or GetUnitToUnitDistance(b,fort)>2850 then return nil end
 local m=b:GetActiveMode();local old=b._siegeExec
 local pushing=m==BOT_MODE_PUSH_TOWER_TOP or m==BOT_MODE_PUSH_TOWER_MID or m==BOT_MODE_PUSH_TOWER_BOT
 local allied=b:GetNearbyHeroes(1200,false,BOT_MODE_NONE)or{}
 local localOrder=old and DotaTime()-(old.last or -999)<12
 for _,a in ipairs(allied)do
  if V(a)and not a:IsIllusion()and Attackable(b,a:GetAttackTarget())then localOrder=true end
 end
 if not pushing and not localOrder then return nil end
 local list=b:GetNearbyTowers(1500,true)or{}
 for _,u in ipairs(b:GetNearbyBarracks(1500,true)or{})do list[#list+1]=u end
 list[#list+1]=fort
 local target,score
 local held=old and old.localTarget
 local holding=held and DotaTime()<(old.localUntil or -999)and Attackable(b,held)
  and GetUnitToUnitDistance(b,held)<=b:GetAttackRange()+700
 local current=b:GetAttackTarget()
 if not holding and Attackable(b,current)and Highground(b,current)then held=current;holding=true end
 for _,u in ipairs(list)do
  if Attackable(b,u)and Highground(b,u)then
   local distance=GetUnitToUnitDistance(b,u)
   if distance<=b:GetAttackRange()+650 then
    local value=distance+(u==fort and -10000 or u==held and holding and -6000 or u:GetUnitName():find('tower',1,true)and -2000 or 0)
    if not score or value<score then target,score=u,value end
   end
  end
 end
 if not target then return nil end
 local healthy,seen={},{};local function Add(a)
  if V(a)and not a:IsIllusion()and not a:IsStunned()and not a:IsHexed()and not a:IsDisarmed()
   and a:GetHealth()/math.max(1,a:GetMaxHealth())>=.5 and GetUnitToUnitDistance(a,target)<=a:GetAttackRange()+700 then
   local id=a:GetPlayerID();if not seen[id]then seen[id]=true;healthy[#healthy+1]=a end
  end
 end
 Add(b);for _,a in ipairs(allied)do Add(a)end
 local enemies={};for _,e in ipairs(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and not e:IsIllusion()then enemies[#enemies+1]=e end
 end
 if #enemies>#healthy or #healthy<2 and #enemies>0 then return nil end
 if #(b:GetNearbyLaneCreeps(1000,false)or{})==0 and target~=fort then return nil end
 local body=Sample(b)
 if b:WasRecentlyDamagedByAnyHero(.8)and (body.bodyLoss or 0)>0 and b:GetHealth()/body.bodyLoss<4 then return nil end
 local hero=b:GetAttackTarget()
 if V(hero)and hero:IsHero()and hero:CanBeSeen()and not hero:IsIllusion()
  and GetUnitToUnitDistance(b,hero)<=b:GetAttackRange()+80
  and b:GetEstimatedDamageToTarget(true,hero,1,DAMAGE_TYPE_PHYSICAL)>hero:GetHealth()*1.2 then return nil end
 local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
 table.sort(healthy,function(a,c)
  local ar,cr=Fu.GetPosition(a),Fu.GetPosition(c)
  if ar~=cr then return ar<cr end
  return a:GetPlayerID()<c:GetPlayerID()
 end)
 local builder=healthy[1]==b or healthy[2]==b
 if not builder then return nil end
 -- Keep the existing building-loss and solo-contact stop-loss checks.
 if not X.Check(b,target)then return nil end
 local distance=GetUnitToUnitDistance(b,target);local point
 local reach=b:GetAttackRange()+b:GetBoundingRadius()+target:GetBoundingRadius()
 if distance>reach+20 then
  local here,to=b:GetLocation(),target:GetLocation();local step=math.min(650,math.max(0,distance-math.max(100,reach-60)))
  point=Vector(here.x+(to.x-here.x)/math.max(1,distance)*step,here.y+(to.y-here.y)/math.max(1,distance)*step,here.z)
  for i=1,6 do
   local q=Vector(here.x+(point.x-here.x)*i/6,here.y+(point.y-here.y)*i/6,here.z)
   if not Safe(b,q)then return nil end
  end
 end
 if point then
  local hazard=require(GetScriptDirectory()..'/FuncLib/systems/combat_hazards')
  if hazard.AllowApproach and not hazard.AllowApproach(b,point)then return nil end
 end
 return target,point
end
function X.LocalTry(b)
 local base=require(GetScriptDirectory()..'/FuncLib/systems/base_execution')
 if base.InScope(b)then return base.Try(b)end
 if not Own(b)or b._siegeOwnOrder or b:NumQueuedActions()>0 or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 then return false end
 local target,point=LocalGoal(b);if not target then return false end
 local s=b._siegeExec
 if s.localTarget~=target then s.localTarget=target;s.localUntil=DotaTime()+1.25 end
 if not point and b:GetAttackTarget()==target then return true end
 if DotaTime()<(s.localNext or -999)and (point or b:GetAttackTarget()==target)then return true end
 s.localNext=DotaTime()+.35;b._siegeOwnOrder=true
 if point then b:Action_MoveToLocation(point);Log(b,'local_building_approach',target)
 else b:Action_AttackUnit(target,false);Log(b,'local_building_commit',target)end
 b._siegeOwnOrder=nil;return true
end
function X.Intercept(b,action,target)
 local base=require(GetScriptDirectory()..'/FuncLib/systems/base_execution')
 if base.InScope(b)then return base.Intercept(b,action,target)end
 if not Own(b)or b._siegeOwnOrder then return false end
 local foot=action=='Action_MoveToLocation'or action=='Action_MoveDirectly'or action=='Action_AttackMove'
  or action=='Action_AttackUnit'
 if not foot then return false end
 -- Survival, hazard exits, channels and ability queues are resolved before this hook.
 return X.LocalTry(b)
end
function X.Try(b)
 local base=require(GetScriptDirectory()..'/FuncLib/systems/base_execution');if base.InScope(b)then return base.Try(b)end
 if X.LocalTry(b)then return true end
 if Own(b)then Sample(b)end
 if not Own(b)or Protected(b)or b:NumQueuedActions()>0 or DotaTime()<(b._ohaAbilityOrderAt or -999)+.25 then return false end
 local previous=b._siegeExec
 if previous and previous.target and not previous.target:IsNull()and not previous.target:IsAlive()
  and DotaTime()-(previous.last or -99)<5 and not b:WasRecentlyDamagedByAnyHero(1)then
  local mode=b:GetActiveMode()
  if mode==BOT_MODE_PUSH_TOWER_TOP or mode==BOT_MODE_PUSH_TOWER_MID or mode==BOT_MODE_PUSH_TOWER_BOT or mode==BOT_MODE_ATTACK or mode==BOT_MODE_TEAM_ROAM then
   local enemies=b:GetNearbyHeroes(850,true,BOT_MODE_NONE)or{};local creeps=b:GetNearbyLaneCreeps(800,false)or{}
   if #enemies==0 and #creeps>0 then
    local list=b:GetNearbyTowers(900,true)or{}
    for _,u in ipairs(b:GetNearbyBarracks(900,true)or{})do list[#list+1]=u end
    local fort=GetAncient(GetOpposingTeam());if V(fort)then table.insert(list,1,fort)end
    for _,u in ipairs(list)do
     if V(u)and u:CanBeSeen()and not u:IsInvulnerable()and not u:IsAttackImmune()
      and GetUnitToUnitDistance(b,u)<=b:GetAttackRange()+180 then
      Log(b,'local_target_handoff',u);b:Action_AttackUnit(u,false);return true
     end
    end
   end
  end
 end
 local target=b:GetAttackTarget()
 if V(target)and target:IsHero()then
  local goal=X.AfterContact(b,target)
  if goal then b:Action_MoveToLocation(goal);return true end
  local s=b._siegeExec
  if s and s.goal and DotaTime()<(s.untilTime or -1)and b:WasRecentlyDamagedByAnyHero(1)then b:Action_MoveToLocation(s.goal);return true end
  if s then s.goal=nil end;return false end
 if V(target)and target:IsBuilding()then X.Check(b,target)end
 local s=b._siegeExec
 if not s or not s.goal or DotaTime()>(s.untilTime or -1)or not b:WasRecentlyDamagedByAnyHero(1)then return false end
 if b:GetCurrentActionType()~=BOT_ACTION_TYPE_MOVE_TO or DotaTime()>=(s.orderNext or -1)then
  s.orderNext=DotaTime()+.25;b:Action_MoveToLocation(s.goal)
 end
 return true
end
for name,fallback in pairs({AfterContact=function()end,Check=function()return true end,OrderGoal=function()end,LocalTry=function()return false end,Intercept=function()return false end,Try=function()return false end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,result=pcall(raw,b,...);if ok then return result end
  if b and DotaTime()>=(b._siegeErrorNext or -1)then b._siegeErrorNext=DotaTime()+10;print('[SIEGE_EXEC_ERROR] '..tostring(result))end
  return fallback()
 end
end
return X
