-- Local building execution only. Original push scheduling and hero combat remain authoritative.
local X={};local serial=0;local outlines={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function Body(u)return V(u)and u:IsHero()and not u:IsIllusion()and not u:HasModifier('modifier_arc_warden_tempest_double')end
local function D(a,c)local x,y=a.x-c.x,a.y-c.y;return math.sqrt(x*x+y*y)end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local function Own(b)return b and b==GetBot()and Body(b)end
local function Enemy(b)return b:GetTeam()==2 and 3 or 2 end
local function Push(b)local m=b:GetActiveMode();return m==BOT_MODE_PUSH_TOWER_TOP or m==BOT_MODE_PUSH_TOWER_MID or m==BOT_MODE_PUSH_TOWER_BOT end
local function Travel(b)return b._guardTravel or b._counterTask or b:HasModifier('modifier_teleporting')end
local function Protected(b)return not Own(b)or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()or b:IsStunned()or b:IsHexed()or b:IsRooted()or b:IsInvulnerable()or b:IsInvisible()or b:NumQueuedActions()>0 end
local function Fountain(b)return require(GetScriptDirectory()..'/FuncLib/systems/fountain_safety').Location(b)end
local function Clear(b,why)
 local s=b._baseExec;if s and s.member then print('[BASE_EXEC] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=release reason='..why)end
 b._baseExec=nil;b._baseCombatTarget=nil;b._baseIntentAt=nil;b._baseCandidateAt=nil;b._baseRetry=DotaTime()+1
end
local function Phase(b,s,name,why)
 if s.phase~=name then s.phase=name;s.changed=DotaTime();s.nextOrder=nil;if name=='combat'or name=='exit'then s.attackTarget=nil end end
 if DotaTime()>=(s.logNext or -1)or s.logged~=name then
  s.logNext=DotaTime()+3;s.logged=name
  print('[BASE_EXEC] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase='..name..' epoch='..s.epoch..' reason='..(why or'')..' target='..(V(s.target)and s.target:GetUnitName()or'none'))
 end
end
-- Remember real base structures before they fall. The expanded convex boundary excludes
-- similarly high outpost/cliff terrain; the outer release radius supplies hysteresis only.
local function Remember(b)
 local team=Enemy(b);local r=outlines[team]or{points={},hulls={}};outlines[team]=r
 if DotaTime()<(r.next or -999)then return r end;r.next=DotaTime()+2
 local function Keep(key,u)if V(u)and not r.points[key]then r.points[key]=u:GetLocation();r.hulls={}end end
 Keep('fort',GetAncient(team))
 for _,id in ipairs({TOWER_TOP_3,TOWER_MID_3,TOWER_BOT_3,TOWER_BASE_1,TOWER_BASE_2})do Keep('tower'..id,GetTower(team,id))end
 for i=0,5 do Keep('rax'..i,GetBarracks(team,i))end
 return r
end
local function Region(b,p,pad)
 local r=Remember(b);local hull=r.hulls[pad]
 if not hull then
  local a={};for _,q in pairs(r.points)do for _,d in ipairs({{-pad,-pad},{-pad,pad},{pad,-pad},{pad,pad}})do a[#a+1]={x=q.x+d[1],y=q.y+d[2]}end end
  if #a<3 then return false end
  table.sort(a,function(u,v)return u.x<v.x or u.x==v.x and u.y<v.y end)
  local function Cross(o,u,v)return(u.x-o.x)*(v.y-o.y)-(u.y-o.y)*(v.x-o.x)end
  hull={};for _,q in ipairs(a)do while #hull>=2 and Cross(hull[#hull-1],hull[#hull],q)<=0 do table.remove(hull)end;hull[#hull+1]=q end
  local lower=#hull;for i=#a-1,1,-1 do local q=a[i];while #hull>lower and Cross(hull[#hull-1],hull[#hull],q)<=0 do table.remove(hull)end;hull[#hull+1]=q end
  r.hulls[pad]=hull
 end
 for i=1,#hull-1 do local a,c=hull[i],hull[i+1];if(c.x-a.x)*(p.y-a.y)-(c.y-a.y)*(p.x-a.x)<0 then return false end end;return true
end
function X.InScope(b)
 if not V(b)then return false end;local f=GetAncient(Enemy(b));return V(f)and D(b:GetLocation(),f:GetLocation())<4100
end
local function Building(b,u)return V(u)and u:IsBuilding()and u:GetTeam()~=b:GetTeam()end
local function Attackable(b,u)return Building(b,u)and u:CanBeSeen()and not u:IsInvulnerable()and not u:IsAttackImmune()and not u:HasModifier('modifier_fountain_glyph')and not u:HasModifier('modifier_backdoor_protection_active')end
local function Friends(b,r)
 local a,ids={},{};local function Add(u)if Body(u)and not ids[u:GetPlayerID()]and D(u:GetLocation(),b:GetLocation())<r and HP(u)>.35 and not Travel(u)and not u:IsInvulnerable()and not u:IsStunned()and not u:IsHexed()and(not GetHeightLevel or GetHeightLevel(u:GetLocation())>=GetHeightLevel(b:GetLocation()))then ids[u:GetPlayerID()]=true;a[#a+1]=u end end
 Add(b);for _,u in ipairs(b:GetNearbyHeroes(math.min(1600,r),false,BOT_MODE_NONE)or{})do Add(u)end;return a
end
local function Enemies(b,r)
 local a,ids={},{};for _,u in ipairs(b:GetNearbyHeroes(math.min(1600,r),true,BOT_MODE_NONE)or{})do
  if Body(u)and u:CanBeSeen()and not ids[u:GetPlayerID()]then ids[u:GetPlayerID()]=true;a[#a+1]=u end
 end;return a
end
local function Wave(b,t)
 for _,c in ipairs(b:GetNearbyLaneCreeps(1600,false)or{})do if V(c)and D(c:GetLocation(),t:GetLocation())<1100 then return true end end;return false
end
local function Threat(b,list)
 local chosen,score
 for _,e in ipairs(list)do
  local dist=GetUnitToUnitDistance(b,e);local p=e:GetLocation();local fd=D(p,Fountain(b))
  local active=e:GetAttackTarget();local victim=V(active)and active:GetTeam()==b:GetTeam()and active:IsHero()
  local danger=dist<math.max(425,b:GetAttackRange()+100)or victim and dist<1000 or b:WasRecentlyDamagedByHero(e,.8)and dist<1100
  if danger and fd>1750 then local v=1500-dist+(victim and 350 or 0)+(e:IsChanneling()and 250 or 0)
   if not score or v>score then chosen,score=e,v end
  end
 end;return chosen
end
function X.Observe(b)
 if not Own(b)then if b and b._baseExec then Clear(b,'not_alive_body')end;return end
 local now=DotaTime();local f=GetAncient(Enemy(b));if not V(f)then if b._baseExec then Clear(b,'ancient_gone')end;return end
 Remember(b)
 local p=b:GetLocation();local distance=D(p,f:GetLocation());local sample=b._baseSample
 if sample and now>sample.at and now-sample.at<1 and D(p,sample.loc)>math.max(900,b:GetCurrentMovementSpeed()*(now-sample.at)+350)then
  if distance<3600 and (sample.distance>3500 or D(p,Fountain(b))<1900)then b._baseDisplacedUntil=now+3 end
 end
 if not sample or now-sample.at>=.2 then b._baseSample={at=now,loc=p,distance=distance}end
 local t=b:GetAttackTarget()
 if distance<4500 and (Push(b)or Building(b,t)and GetUnitToUnitDistance(b,t)<b:GetAttackRange()+500)then b._baseIntentAt=now end
 local s=b._baseExec
 if s and (distance>4050 or Travel(b)or b:GetActiveMode()==BOT_MODE_DEFEND_TOWER_TOP or b:GetActiveMode()==BOT_MODE_DEFEND_TOWER_MID or b:GetActiveMode()==BOT_MODE_DEFEND_TOWER_BOT)then Clear(b,'leave_or_other_task');return end
 if s and HP(b)<.3 then s.exit=true end
 if s and b:GetActiveMode()==BOT_MODE_RETREAT then
  s.retreatAt=s.retreatAt or now;if HP(b)<.5 then s.exit=true;s.exitReason='low_hp_retreat' end
 elseif s then s.retreatAt=nil end
 if s and now-(s.progressAt or s.entered)>18 then Clear(b,'no_effective_progress');b._baseRetry=now+4;return end
 if not s then
  if distance>3300 or distance<100 or Travel(b)or HP(b)<.55 or now<(b._baseRetry or -1)or now<(b._baseDisplacedUntil or -1)
   or not b._baseIntentAt or now-b._baseIntentAt>5 or b:GetActiveMode()==BOT_MODE_RETREAT then return end
  if GetHeightLevel and GetHeightLevel(p)<GetHeightLevel(f:GetLocation())then return end
  if not Region(b,p,600)then return end
  local friends=Friends(b,1400);local ready=0;local wave=false
  for _,a in ipairs(friends)do
   local at=a:GetAttackTarget();if Push(a)or Building(a,at)or a._baseExec and a._baseExec.member then ready=ready+1 end
   if # (a:GetNearbyLaneCreeps(1100,false)or{})>0 then wave=true end
  end
  if #friends<2 or ready<1 or not wave or #Enemies(b,1300)>#friends then b._baseCandidateAt=nil;return end
  b._baseCandidateAt=b._baseCandidateAt or now;if now-b._baseCandidateAt<.5 then return end
  serial=serial+1;s={member=true,epoch=serial,entered=now,progressAt=now,lastLoc=p};b._baseExec=s;Phase(b,s,'select','original_local_push')
 end
 if V(s.target)then
  local hp=s.target:GetHealth();if s.targetHP and hp<s.targetHP-1 then s.progressAt=now end;s.targetHP=hp
 elseif s.target then s.progressAt=now;s.target=nil end
 if s.lastLoc and D(p,s.lastLoc)>100 then s.progressAt=now;s.lastLoc=p end
 local en=Enemies(b,1400);b._baseCombatTarget=Threat(b,en)
end
function X.Active(b)return Own(b)and b._baseExec and b._baseExec.member or false end
function X.InCombat(b)return X.Active(b)and V(b._baseCombatTarget)and b._baseExec.phase=='combat' or false end
function X.CombatTarget(b)return X.Active(b)and V(b._baseCombatTarget)and b._baseCombatTarget:CanBeSeen()and b._baseCombatTarget or nil end
local function Pick(b,s)
 local enemy=Enemy(b);local f=GetAncient(enemy)
 local t4a,t4b=GetTower(enemy,TOWER_BASE_1 or 9),GetTower(enemy,TOWER_BASE_2 or 10)
 if not V(t4a)and not V(t4b)and Attackable(b,f)then s.finishing=true;return f end
 s.finishing=false
 if Attackable(b,s.target)then return s.target end
 local friends=Friends(b,1600)
 for _,a in ipairs(friends)do local o=a._baseExec
  if a~=b and o and o.member and Attackable(b,o.target)and D(b:GetLocation(),o.target:GetLocation())<2600 then return o.target end
 end
 local target,cost
 local function Add(u,value)
  if Attackable(b,u)then local d=GetUnitToUnitDistance(b,u);if d<3000 then local n=d+value;if not cost or n<cost then target,cost=u,n end end end
 end
 for _,v in ipairs({{TOWER_TOP_3,0},{TOWER_MID_3,2},{TOWER_BOT_3,4}})do
  local tower=GetTower(enemy,v[1]);if V(tower)then Add(tower,250)
  else for i=v[2],v[2]+1 do Add(GetBarracks(enemy,i),0)end end
 end
 Add(t4a,100);Add(t4b,100);return target
end
-- Assault paths may enter the selected tower's range only with a real wave and local support.
local function Path(b,p,t,assault)
 local here=b:GetLocation();local f=Fountain(b);local height=GetHeightLevel and GetHeightLevel(here)
 for i=1,6 do local q=Vector(here.x+(p.x-here.x)*i/6,here.y+(p.y-here.y)*i/6,here.z)
  local radius=D(q,f);local start=D(here,f)
  if not IsLocationPassable(q)or radius<math.min(1800,start)-1 or start<1800 and radius<start-1 then return false end
  if assault and height and GetHeightLevel(q)<height and D(q,GetAncient(Enemy(b)):GetLocation())<3000 then return false end
  if not require(GetScriptDirectory()..'/FuncLib/systems/spell_safety').SafePoint(b,q)then return false end
 end
 for _,tower in ipairs(b:GetNearbyTowers(1600,true)or{})do if V(tower)then
  local r=tower:GetAttackRange()+100;local was=D(here,tower:GetLocation());local after=D(p,tower:GetLocation())
  if after<r and after<was-25 then
   local tank=tower:GetAttackTarget();local covered=V(tank)and tank:GetTeam()==b:GetTeam()and tank~=b
   if not assault or not V(t)or not Wave(b,t)or #Friends(b,1200)<2 or not covered and HP(b)<.7 then return false end
  end
 end end;return true
end
X.SafePath=Path
local function Step(b,to,t,assault)
 local here=b:GetLocation();local dist=D(here,to);local length=math.max(1,dist);local best,score
 for _,a in ipairs({0,.35,-.35,.7,-.7,1.05,-1.05})do
  local dx,dy=to.x-here.x,to.y-here.y;local n=math.min(420,dist)
  local p=Vector(here.x+(dx*math.cos(a)-dy*math.sin(a))/length*n,here.y+(dx*math.sin(a)+dy*math.cos(a))/length*n,here.z)
  if Path(b,p,t,assault)then local v=D(p,to);if not score or v<score then best,score=p,v end end
 end;return best
end
local function OrderLog(b,s,kind,target,point)
 if DotaTime()<(s.orderLogNext or -1)then return end;s.orderLogNext=DotaTime()+1
 local p=point or target and target:GetLocation()or b:GetLocation()
 print('[BASE_ORDER] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase='..s.phase..' epoch='..s.epoch..' owner='..s.owner..' action='..kind..' x='..math.floor(p.x)..' y='..math.floor(p.y)..' target='..(V(target)and target:GetUnitName()or'none'))
end
local function Issue(b,s,target,point,reason)
 if DotaTime()<(s.nextOrder or -1)then return true end
 b._baseOwnOrder=true;s.owner=reason
 if point then
  if not s.move or D(point,s.move)>80 or DotaTime()>(s.moveAt or -1)+.8 then b:Action_MoveToLocation(point);OrderLog(b,s,'move',nil,point);s.move=point;s.moveAt=DotaTime();s.attackTarget=nil end
 elseif b:GetAttackTarget()~=target and(s.attackTarget~=target or DotaTime()>(s.attackAt or -1)+math.max(1.2,b:GetSecondsPerAttack()+.3))then b:Action_AttackUnit(target,false);OrderLog(b,s,'attack',target,nil);s.move=nil;s.attackTarget=target;s.attackAt=DotaTime()end
 b._baseOwnOrder=nil;s.nextOrder=DotaTime()+.25;s.owner=reason
 return true
end
function X.Try(b)
 X.Observe(b);local s=b and b._baseExec;if not s or not s.member or Protected(b)or b._baseOwnOrder then return false end
 if b._enigmaCombo or b._invokerPlan or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 then return false end
 if not require(GetScriptDirectory()..'/FuncLib/systems/spell_safety').SafePoint(b,b:GetLocation())then Phase(b,s,'survival','current_point_danger');return false end
 if b._staticLinkEscape or DotaTime()<(b._hazardExitUntil or -1)or b._battleExit and DotaTime()<b._battleExit.untilTime then Phase(b,s,'survival','hazard_or_lost_fight');return false end
 local now=DotaTime();local f=GetAncient(Enemy(b));local here=b:GetLocation();local friends=Friends(b,1400);local en=Enemies(b,1400)
 if b:GetActiveMode()==BOT_MODE_RETREAT and not s.exit and(b:WasRecentlyDamagedByAnyHero(1.2)or #en>#friends)then Phase(b,s,'combat','original_retreat_under_actual_threat');s.combatUntil=now+.8;return false end
 if D(here,Fountain(b))<1750 then s.deepExit=true end
 if s.deepExit and D(here,Fountain(b))>2050 then s.deepExit=nil end
 if s.exit or s.deepExit or #friends<=1 and #en>=2 then
  Phase(b,s,'exit',s.exitReason or'unsafe_or_separated');local home=GetAncient(b:GetTeam());local q=V(home)and Step(b,home:GetLocation(),nil,false)
  if q then Issue(b,s,nil,q,'exit')end
  if D(here,f:GetLocation())>3500 or #en==0 and HP(b)>.55 and not s.exit and not s.deepExit then Clear(b,'recovered_outside')end
  return q~=nil
 end
 local target=Pick(b,s)
 if target~=s.target then s.target=target;s.targetHP=V(target)and target:GetHealth()or nil;s.progressAt=now end
 local builders={};for _,a in ipairs(friends)do builders[#builders+1]=a end
 table.sort(builders,function(a,c)
  local av=a:GetEstimatedDamageToTarget(true,target or f,2,DAMAGE_TYPE_PHYSICAL);local cv=c:GetEstimatedDamageToTarget(true,target or f,2,DAMAGE_TYPE_PHYSICAL)
  if av~=cv then return av>cv end;return a:GetPlayerID()<c:GetPlayerID()
 end)
 local chosen={};local ids={}
 for _,a in ipairs(friends)do local state=a._baseExec;if state and state.builder and HP(a)>.45 and not state.exit and #chosen<2 then chosen[#chosen+1]=a;ids[a:GetPlayerID()]=true end end
 for _,a in ipairs(builders)do if #chosen<2 and not ids[a:GetPlayerID()]then chosen[#chosen+1]=a;ids[a:GetPlayerID()]=true end end
 local main=ids[b:GetPlayerID()]or false;s.builder=main
 local threat=X.CombatTarget(b)
 if threat and main and threat:GetAttackTarget()~=b and not b:WasRecentlyDamagedByHero(threat,.8)and GetUnitToUnitDistance(b,threat)>425 and not threat:IsChanneling()then threat=nil end
 if threat then
  local finish=s.finishing and V(target)and target:GetHealth()<b:GetEstimatedDamageToTarget(true,target,2,DAMAGE_TYPE_PHYSICAL)*#friends*.6
  if not finish or HP(b)<.6 or threat:IsChanneling()then Phase(b,s,'combat','near_visible_threat');s.combatUntil=now+.8;return false end
 end
 if now<(s.combatUntil or -1)then Phase(b,s,'combat','brief_handoff_hold');return false end
 if not target then
  Phase(b,s,'wait','no_attackable_building');s.waitAt=s.waitAt or now
  if now-s.waitAt>3 then Clear(b,'no_valid_target');b._baseRetry=now+3 end;return false
 end;s.waitAt=nil
 if #en>#friends or HP(b)<.45 then Phase(b,s,'combat','local_defence_needed');return false end
 local rate=b:GetEstimatedDamageToTarget(true,target,2,DAMAGE_TYPE_PHYSICAL)/2
 if b:WasRecentlyDamagedByAnyHero(.8)and s.hpAt and now>s.hpAt+.25 then
  local loss=math.max(0,(s.hp-b:GetHealth())/math.max(.25,now-s.hpAt))
  if loss>0 and b:GetHealth()/loss<3 then s.exit=true;return X.Try(b)end
 end
 if not s.hpAt or now>s.hpAt+.5 then s.hpAt=now;s.hp=b:GetHealth()end
 if not s.finishing and not Wave(b,target)then Phase(b,s,'wait','wave_required');return false end
 local reach=b:GetAttackRange()+b:GetBoundingRadius()+target:GetBoundingRadius()-25
 local distance=GetUnitToUnitDistance(b,target)
 local bodyCount=0;for _,a in ipairs(friends)do if HP(a)>.45 then bodyCount=bodyCount+1 end end
 if bodyCount<2 then Phase(b,s,'wait','not_enough_arrived');return false end
 if distance<=reach+15 then
  Phase(b,s,s.finishing and 'finish' or 'building','local_original_commit')
  if D(here,Fountain(b))<1800 then s.exit=true;return false end
  return Issue(b,s,target,nil,'building_attack')
 end
 local dx,dy=here.x-target:GetLocation().x,here.y-target:GetLocation().y;local n=math.max(1,math.sqrt(dx*dx+dy*dy))
 local stand=Vector(target:GetLocation().x+dx/n*math.max(100,reach-30),target:GetLocation().y+dy/n*math.max(100,reach-30),here.z)
 if s.routeTarget~=target then s.via=nil;s.routeTarget=target end
 if s.via and D(here,s.via)<280 then s.via=nil end
 local point=Step(b,s.via or stand,target,true)
 if not point and distance>700 then
  -- When adjacent ramps have a concave edge, route through the base interior,
  -- never through the lower ground or the fountain to reach another lane.
  local t4a,t4b=GetTower(Enemy(b),TOWER_BASE_1),GetTower(Enemy(b),TOWER_BASE_2)
  local anchor=V(t4a)and V(t4b)and Vector((t4a:GetLocation().x+t4b:GetLocation().x)/2,(t4a:GetLocation().y+t4b:GetLocation().y)/2,here.z)or f:GetLocation()
  for _,d in ipairs({{0,0},{-280,0},{0,-280},{280,0},{0,280}})do local q=Vector(anchor.x+d[1],anchor.y+d[2],here.z)
   if D(here,q)>300 then local step=Step(b,q,target,true);if step then s.via=q;point=step;break end end
  end
 end
 if not point then
  s.blockedAt=s.blockedAt or now;s.pathReadyAt=nil;Phase(b,s,'wait','no_safe_path')
  if now-s.blockedAt>2 then Clear(b,'route_unavailable');b._baseRetry=now+3;return false end
  -- A brief route failure keeps one owner. Stop a now-unsafe previous move once;
  -- never hand it back and take it away again on each ordinary callback.
  if not s.routeHeld and s.move and b:GetCurrentActionType()==BOT_ACTION_TYPE_MOVE_TO then s.routeHeld=true;Issue(b,s,nil,here,'route_pause')end
  return true
 end
 if s.blockedAt then
  s.pathReadyAt=s.pathReadyAt or now
  if now-s.pathReadyAt<.3 then
   if now-s.blockedAt>2 then Clear(b,'unstable_route');b._baseRetry=now+3;return false end
   return true
  end
 end
 s.blockedAt=nil;s.pathReadyAt=nil;s.routeHeld=nil;Phase(b,s,s.finishing and 'finish' or 'building','local_original_commit');return Issue(b,s,nil,point,'building_approach')
end
function X.Intercept(b,action,target,location)
 if not Own(b)or b._baseOwnOrder or b._sproutOwnOrder or not X.Active(b)then return false end
 local foot=action:find('Move',1,true)or action:find('Attack',1,true)or action=='Action_ClearActions';if not foot or Protected(b)then return false end
 local s=b._baseExec
 if s.phase=='combat'or s.phase=='wait' then
  local goal=target and target.x and target or target and not target:IsNull()and target:GetLocation()
  if goal and (D(goal,Fountain(b))<1850 or D(goal,GetAncient(Enemy(b)):GetLocation())>3600)and HP(b)>.45 and b:GetActiveMode()~=BOT_MODE_RETREAT then
   local anchor=V(s.target)and s.target:GetLocation()or GetAncient(Enemy(b)):GetLocation()
   local q=Step(b,anchor,s.target,false)
   if q then return Issue(b,s,nil,q,'bounded_combat')end
   if not s.chaseStopped then s.chaseStopped=true;b._baseOwnOrder=true;b:Action_MoveToLocation(b:GetLocation());b._baseOwnOrder=nil end
   return true
  end;if s.phase=='combat'then return false end
 end
 return X.Try(b)
end
function X.Minion(b,u)
 if not X.Active(b)or not V(u)or u:GetHealth()/math.max(1,u:GetMaxHealth())<.3 or u:IsHero()or u:IsChanneling()or u:IsStunned()or u:IsRooted()then return false end
 local s=b._baseExec
 if s.phase=='exit'or s.phase=='survival'then
  local home=GetAncient(b:GetTeam());local here=u:GetLocation();local to=V(home)and home:GetLocation();if not to then return false end
  local n=math.max(1,D(here,to));local p=Vector(here.x+(to.x-here.x)/n*350,here.y+(to.y-here.y)/n*350,here.z)
  if IsLocationPassable(p)and D(p,Fountain(b))>=math.min(1800,D(here,Fountain(b)))-1 then
   if DotaTime()>=(u._baseMinionNext or -1)then u._baseMinionNext=DotaTime()+.5;u:Action_MoveToLocation(p)end;return true
  end;return false
 end
 if s.phase~='building'and s.phase~='finish'then return false end
 if not Attackable(b,s.target)or D(u:GetLocation(),s.target:GetLocation())>1600 then return false end
 if D(u:GetLocation(),Fountain(b))<1750 then return false end
 if u:GetAttackTarget()~=s.target then u:Action_AttackUnit(s.target,false)end;return true
end
for _,name in ipairs({'Observe','Try','Intercept','Minion'})do local raw=X[name];X[name]=function(b,...)
 local ok,v=pcall(raw,b,...);if ok then return v end
 if b and DotaTime()>=(b._baseExecErrorNext or -1)then b._baseExecErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=base_execution function='..name..' error='..tostring(v))end
 if b then b._baseOwnOrder=nil;b._baseExec=nil end;return false
end end
return X
