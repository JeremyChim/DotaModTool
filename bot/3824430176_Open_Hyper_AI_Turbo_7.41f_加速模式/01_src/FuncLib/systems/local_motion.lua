-- Local recovery only: preserve modes, objectives and normal fighting.
local X={}
local E=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion')
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Valid(b)return b and not b:IsNull() and b:IsAlive()end
local function Protected(b)
 return b~=GetBot() or not Valid(b) or not b:IsHero() or b:IsIllusion() or b:IsInvulnerable()
  or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted()
  or b:IsHexed() or b:NumQueuedActions()>0
end
local function Log(b,p)local t=DotaTime();if t>=(b._motionLogNext or -1)then b._motionLogNext=t+3;print('[LOCAL_MOTION] t='..t..' pid='..b:GetPlayerID()..' phase='..p)end end
function X.Remember(b,p)
 if b~=GetBot() or not p or b._motionOwn then return end
 local s=b._motionState or {};b._motionState=s
 s.goal=p;s.orderAt=DotaTime()
end
local function Safe(b,p)
 if not E.Safe(b,p)then return false end
 local a=b:GetLocation();local radius=b:GetBoundingRadius()+24
 local trees=b:GetNearbyTrees(500)or{}
 for i=1,8 do
  local q=Vector(a.x+(p.x-a.x)*i/8,a.y+(p.y-a.y)*i/8,a.z)
  if not IsLocationPassable(q)or math.abs(GetHeightLevel(q)-GetHeightLevel(a))>1 then return false end
  for _,id in ipairs(trees)do if D(q,GetTreeLocation(id))<radius then return false end end
 end
 return true
end
function X.Redirect(b,p)
 local s=b._motionState
 if b._motionOwn or not s or not s.exit or DotaTime()>=(s.holdUntil or -1)or Protected(b)then return p end
 if D(b:GetLocation(),s.exit)<65 or not Safe(b,s.exit)then s.exit=nil;return p end
 return s.exit
end
function X.AttackExit(b,target)
 local s=b._motionState
 if not s or not s.exit or DotaTime()>=(s.holdUntil or -1)or Protected(b)then return nil end
 if Valid(target)and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+80 then return nil end
 return X.Redirect(b,s.exit)
end
function X.Think(b)
 if Protected(b)then return false end
 local now=DotaTime();if now<0 then return false end
 local s=b._motionState or {};b._motionState=s
 local p=b:GetLocation();local action=b:GetCurrentActionType()
 local moving=action==BOT_ACTION_TYPE_MOVE_TO or action==BOT_ACTION_TYPE_IDLE and s.goal and now-(s.orderAt or -999)<.6
 if not s.exit and(not moving or not s.goal or now-(s.orderAt or -999)>2 or D(p,s.goal)<160)then
  s.anchor=p;s.at=now;s.travel=0;s.last=p;return false
 end
 if not s.exit and now<(s.sampleNext or -1)then return false end
 local tower=false
 for _,u in ipairs(b:GetNearbyTowers(1100,true)or{})do if Valid(u)and u:GetAttackTarget()==b then tower=true;break end end
 local target=b:GetAttackTarget()
 if not moving and Valid(target)and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+(target:IsBuilding()and 0 or target:GetBoundingRadius())+80
  and (not tower or target:IsBuilding()or target:IsHero()and target:GetHealth()<b:GetAttackDamage()*2)then return false end
 if s.exit and now<(s.holdUntil or -1)then
  if D(p,s.exit)<65 then s.exit=nil;return false end
  if not Safe(b,s.exit)then s.exit=nil;return false end
  if now>=(s.nextOrder or 0)then
   b._motionOwn=true;b:Action_MoveToLocation(s.exit);b._motionOwn=nil;s.nextOrder=now+.45
  end
  return true
 end
 if s.exit then
  if D(p,s.exit)>90 then s.failed=s.exit;s.failedUntil=now+10 end
  s.exit=nil
 end
 if not moving or not s.goal or now-(s.orderAt or -999)>2 or D(p,s.goal)<160 then s.anchor=p;s.at=now;s.travel=0;s.last=p;return false end
 if not s.anchor or now-(s.sampleAt or -999)>.75 then s.anchor=p;s.at=now;s.travel=0;s.last=p end
 if now<(s.sampleNext or -1)then return false end
 s.sampleNext=now+.25;s.sampleAt=now;s.travel=(s.travel or 0)+D(p,s.last or p);s.last=p
 if D(p,s.anchor)>320 then s.anchor=p;s.at=now;s.travel=0;return false end
 if now-(s.at or now)<(tower and 1.5 or 3)or now<(s.retryAt or -1)then return false end
 -- A move order that makes no useful progress, or repeated local reversals.
 if D(p,s.anchor)>70 and s.travel<300 then return false end
 local home=GetAncient(b:GetTeam());if not Valid(home)then return false end
 local goal=tower and home:GetLocation()or s.goal;local dx,dy=goal.x-p.x,goal.y-p.y
 local n=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/n,dy/n
 local best,score
 for _,deg in ipairs({0,60,-60,90,-90,135,-135,180})do
  local a=deg*math.pi/180;local q=Vector(p.x+(dx*math.cos(a)-dy*math.sin(a))*280,p.y+(dx*math.sin(a)+dy*math.cos(a))*280,p.z)
  if Safe(b,q)and(not s.failed or now>(s.failedUntil or 0)or D(q,s.failed)>140)then
   local v=D(q,goal)+(tower and D(q,home:GetLocation())or 0)
   if not score or v<score then best,score=q,v end
  end
 end
 s.retryAt=now+4
 if not best then Log(b,'no_verified_exit');return false end
 s.exit=best;s.holdUntil=now+1.4;s.nextOrder=now+.45;s.anchor=p;s.at=now;s.travel=0
 b._motionOwn=true;b:Action_ClearActions(false);b:Action_MoveToLocation(best);b._motionOwn=nil
 Log(b,tower and 'tower_exit' or 'blocked_move_exit');return true
end

-- Release supplemental advice on native API failure; keep the original AI running.
local defaults={Remember=function()end,Redirect=function(_,p)return p end,AttackExit=function()end,Think=function()return false end}
for name,fallback in pairs(defaults)do
 local raw=X[name]
 X[name]=function(b,...)
  if b and DotaTime()<(b._motionFaultUntil or -999)then return fallback(b,...)end
  local ok,a,c=pcall(raw,b,...)
  if ok then return a,c end
  if b then b._motionOwn=nil;b._motionState=nil;b._motionFaultUntil=DotaTime()+10;print('[LOCAL_ADVICE_ERROR] module=local_motion function='..name..' error='..tostring(a))end
  return fallback(b,...)
 end
end
return X
