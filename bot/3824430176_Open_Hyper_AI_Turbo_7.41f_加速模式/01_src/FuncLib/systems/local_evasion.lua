-- Short local corrections for visible damaging shells; never selects a team task.
local X={}
local function Dist(a,c) local x,y=a.x-c.x,a.y-c.y;return math.sqrt(x*x+y*y) end
local function Valid(u) return u and not u:IsNull() and u:IsAlive() end
local function Own(b)
 return b==GetBot() and Valid(b) and b:IsHero() and not b:IsIllusion()
  and not b:IsInvulnerable() and not b:IsChanneling() and not b:IsUsingAbility()
  and not b:IsCastingAbility() and not b:IsStunned() and not b:IsRooted()
  and not b:IsHexed() and b:NumQueuedActions()==0
end
function X.Sources(b)
 if not Own(b) or not b:WasRecentlyDamagedByAnyHero(1) then return {} end
 local now=DotaTime();local s=b._localEvasion or {};b._localEvasion=s
 if now<(s.scanNext or -1) then return s.sources or {} end
 s.scanNext=now+.25;s.sources={}
 for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
  if Valid(u) and u:CanBeSeen() and not u:IsBuilding()
   and Dist(b:GetLocation(),u:GetLocation())<380
   and u:HasModifier('modifier_dark_seer_ion_shell') then s.sources[#s.sources+1]=u end
 end
 return s.sources
end
function X.Safe(b,p,towers)
 if not p or not IsLocationPassable(p) then return false end
 local loc=b:GetLocation()
 for _,f in ipairs({.25,.5,.75}) do
  if not IsLocationPassable(Vector(loc.x+(p.x-loc.x)*f,loc.y+(p.y-loc.y)*f,loc.z)) then return false end
 end
 local currentRisk,pointRisk=0,0
 for _,tower in ipairs(towers or b:GetNearbyTowers(1600,true) or {}) do
  if Valid(tower) then
   local radius=tower:GetAttackRange()+100
   local centre=tower:GetLocation()
   local vx,vy=p.x-loc.x,p.y-loc.y
   local f=math.max(0,math.min(1,((centre.x-loc.x)*vx+(centre.y-loc.y)*vy)/math.max(1,vx*vx+vy*vy)))
   local closest=Vector(loc.x+vx*f,loc.y+vy*f,loc.z)
   if Dist(loc,centre)>radius and Dist(closest,centre)<radius then return false end
   currentRisk=math.max(currentRisk,radius-Dist(loc,tower:GetLocation()))
   pointRisk=math.max(pointRisk,radius-Dist(p,tower:GetLocation()))
   -- Do not enter a fresh tower's range or move deeper into an existing one.
   if Dist(loc,tower:GetLocation())>radius and Dist(p,tower:GetLocation())<radius then return false end
  end
 end
 if pointRisk>math.max(0,currentRisk-40) then return false end
 return true
end
function X.Location(b,intended,zone)
 if not Own(b) then return intended,false end
 local sources=X.Sources(b)
 if #sources==0 and not zone then return intended,false end
 if #sources>0 then
  local st=b._localEvasion;local now=DotaTime()
  if not st.contactAt or now-st.contactAt>2.5 then st.started=now;st.anchor=b:GetLocation();st.yielded=nil end
  st.contactAt=now
  if b:GetHealth()/math.max(1,b:GetMaxHealth())>=.45 and b:GetActiveMode()~=BOT_MODE_RETREAT
   and (now-(st.started or now)>1.2 or Dist(b:GetLocation(),st.anchor or b:GetLocation())>400)then
   if not st.yielded then st.yielded=true;print('[LOCAL_EVASION] t='..now..' pid='..b:GetPlayerID()..' phase=bounded_yield_to_combat')end
   return intended,false
  end
 end
 local now=DotaTime();local s=b._localEvasion;local loc=b:GetLocation()
 local towers=b:GetNearbyTowers(1600,true) or {}
 local function Clearance(p)
  local n=99999
  for _,u in ipairs(sources) do if Valid(u) and u:CanBeSeen() then n=math.min(n,Dist(p,u:GetLocation())) end end
  return n
 end
 if s and s.goal and now<(s.holdUntil or -1) and Dist(loc,s.goal)>65
  and X.Safe(b,s.goal,towers) and (#sources==0 or Clearance(s.goal)>Clearance(loc)+40) then return s.goal,true end
 local home=GetAncient(b:GetTeam());if not Valid(home) then return intended,false end
 local axis=intended or home:GetLocation();local dx,dy=axis.x-loc.x,axis.y-loc.y
 local norm=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/norm,dy/norm
 local best,score;local current=Clearance(loc)
 for _,angle in ipairs({0,45,-45,90,-90,135,-135,180}) do
  local a=angle*math.pi/180;local x,y=dx*math.cos(a)-dy*math.sin(a),dx*math.sin(a)+dy*math.cos(a)
  local p=Vector(loc.x+x*260,loc.y+y*260,loc.z)
  local clear=Clearance(p)
  if X.Safe(b,p,towers) and (#sources==0 or clear>current+70) then
   local value=(#sources>0 and math.min(550,clear) or 0)-Dist(p,axis)*.6-Dist(p,home:GetLocation())*.02-(math.abs(angle)>100 and 100 or 0)
   if not score or value>score then best,score=p,value end
  end
 end
 if not best then return intended,false end
 s=s or {};b._localEvasion=s;s.goal=best;s.holdUntil=now+.8
 if now>=(s.logNext or -1) then
  s.logNext=now+3;print(string.format('[LOCAL_EVASION] t=%.2f pid=%d sources=%d x=%.0f y=%.0f',now,b:GetPlayerID(),#sources,best.x,best.y))
 end
 return best,true
end
function X.Try(b)
 if DotaTime()<(b._ohaAbilityOrderAt or -999)+.35 then return false end
 if not Own(b) or b:GetHealth()/math.max(1,b:GetMaxHealth())>.65 then return false end
 local sources=X.Sources(b);if #sources==0 then return false end
 local target=b:GetAttackTarget()
 -- Keep an immediate real kill rather than cancelling every attack near a shell.
 if Valid(target) and target:IsHero() and target:CanBeSeen()
  and not target:HasModifier('modifier_illusion')
  and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+30
  and target:GetHealth()<b:GetAttackDamage()*1.5 then return false end
 local goal,changed=X.Location(b,nil,false);if not changed then return false end
 local s=b._localEvasion
 if DotaTime()>=(s.orderNext or -1) then s.orderNext=DotaTime()+.4;b:Action_MoveToLocation(goal) end
 return true
end
return X
