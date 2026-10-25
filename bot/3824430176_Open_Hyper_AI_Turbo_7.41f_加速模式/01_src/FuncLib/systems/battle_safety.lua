-- Reject only fresh unsafe commitments into an observed lost engagement. No task/desire changes.
local X={};local teams={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local function Body(u)return V(u)and u:IsHero()and not u:IsIllusion()and not u:HasModifier('modifier_arc_warden_tempest_double')and not u:HasModifier('modifier_meepo_divided_we_stand')end
local function Free(b)return V(b)and b==GetBot()and Body(b)and not b:IsInvulnerable()and not b:IsChanneling()and not b:IsUsingAbility()and not b:IsCastingAbility()and not b:IsStunned()and not b:IsHexed()and not b:IsRooted()and not b:HasModifier('modifier_bloodseeker_rupture')and not b:HasModifier('modifier_batrider_flaming_lasso')end
function X.Update(b)
 if not b or b~=GetBot()or not b:IsHero()or b:IsIllusion()then return nil end
 local now=DotaTime();local team=b:GetTeam();local s=teams[team]or{deaths={},losses={}};teams[team]=s
 if now<(s.next or -1)then return s end;s.next=now+.25;s.dead=0;s.ready={}
 for i=1,5 do local a=GetTeamMember(i)
  if a and not a:IsNull()and a:IsHero()and not a:IsIllusion()and not a:HasModifier('modifier_arc_warden_tempest_double')then
   local id=a:GetPlayerID();local count=GetHeroDeaths(id)
   if s.deaths[id]and count>s.deaths[id]then s.losses[#s.losses+1]={at=now,loc=a:GetLocation(),id=id}end
   s.deaths[id]=count
   if not a:IsAlive()then s.dead=s.dead+1
   elseif HP(a)>.4 and not a:IsStunned()and not a:IsHexed()then s.ready[#s.ready+1]=a end
  end
 end
 for i=#s.losses,1,-1 do if now-s.losses[i].at>12 then table.remove(s.losses,i)end end
 s.enemyAlive=0;for _,id in ipairs(GetTeamPlayers(GetOpposingTeam()))do if IsHeroAlive(id)then s.enemyAlive=s.enemyAlive+1 end end
 return s
end
function X.Unsafe(b,p)
 local s=X.Update(b);if not s or DotaTime()<600 or not p then return false end
 local fort=GetAncient(b:GetTeam());local here=b:GetLocation()
 if V(fort)and D(p,fort:GetLocation())<1900 then return false end -- Necessary base defence is never suppressed.
 local friends=0
 for _,a in ipairs(s.ready)do if D(a:GetLocation(),p)<1100 then friends=friends+1 end end
 local enemies,ids=0,{}
 for _,e in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do
  if V(e)and e:CanBeSeen()and not e:IsIllusion()and D(e:GetLocation(),p)<1300 then
   local id=e:GetPlayerID();if not ids[id]then ids[id]=true;enemies=enemies+1 end
  end
 end
 local recent=0
 for _,loss in ipairs(s.losses)do if D(loss.loc,p)<1600 then recent=recent+1 end end
 return friends<=2 and s.dead>=3 and s.enemyAlive>=3 and (enemies>=2 or recent>=2)
  or friends<=1 and s.dead>=2 and recent>=2 and enemies>=2
end
local function Exit(b,s)
 local here=b:GetLocation();local fort=GetAncient(b:GetTeam());if not V(fort)then return nil end
 local anchor=fort:GetLocation();local cost=D(here,anchor)
 for _,a in ipairs(s.ready or{})do if a~=b and D(a:GetLocation(),fort:GetLocation())<D(here,fort:GetLocation())then
  local d=D(here,a:GetLocation());if d<cost then anchor,cost=a:GetLocation(),d end
 end end
 local dx,dy=anchor.x-here.x,anchor.y-here.y;local length=math.max(1,D(here,anchor))
 local threats={};for _,e in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do if V(e)and e:CanBeSeen()and not e:IsIllusion()then threats[#threats+1]=e end end
 local best,score
 for _,angle in ipairs({0,.4,-.4,.8,-.8,1.2,-1.2})do
  local p=Vector(here.x+(dx*math.cos(angle)-dy*math.sin(angle))/length*420,here.y+(dx*math.sin(angle)+dy*math.cos(angle))/length*420,here.z)
  if Safe(b,p)then
   local risk=0
   for _,e in ipairs(threats)do local d=D(p,e:GetLocation());risk=risk+math.max(0,850-d)*2 end
   local value=D(p,anchor)*.2+risk
   if not score or value<score then best,score=p,value end
  end
 end
 return best
end
function X.OrderGoal(b,action,target)
 if not Free(b)or b._battleOwnOrder or b:NumQueuedActions()>0 then return nil end
 local foot=action:find('Move',1,true)or action:find('Attack',1,true)
 if not foot then return nil end
 local p=target and target.x and target or target and not target:IsNull()and target:GetLocation()
 if not p then return nil end
 if target and not target.x and (target:GetTeam()==b:GetTeam()or not target:IsHero()and not target:IsBuilding())then return nil end
 local s=X.Update(b);if not s then return nil end
 local hold=b._battleExit
 if not X.Unsafe(b,p)and not(hold and DotaTime()<hold.untilTime and D(p,hold.battle)<1400 and s.dead>=2)then return nil end
 if hold and DotaTime()<hold.untilTime and D(b:GetLocation(),hold.goal)>70 and Safe(b,hold.goal)then return hold.goal end
 local q=Exit(b,s);if not q then return nil end
 b._battleExit={goal=q,battle=hold and DotaTime()<hold.untilTime and hold.battle or p,untilTime=DotaTime()+3}
 if DotaTime()>=(b._battleLog or -1)then b._battleLog=DotaTime()+3;print('[BATTLE_SAFETY] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=lost_fight_exit dead='..s.dead)end
 return q
end
-- Prevent an unstarted teleport from adding another isolated body to a lost fight.
function X.BlockArrival(b,a,point)
 if not Free(b)or not a or not point then return false end
 local name=a:GetName()
 if name~='item_tpscroll'and name~='item_travel_boots'and name~='item_travel_boots_2'
  and name~='furion_teleportation'and name~='wisp_relocate'then return false end
 local loc=point.x and point or not point:IsNull()and point:GetLocation()
 if not loc or not X.Unsafe(b,loc)then return false end
 if DotaTime()>=(b._battleArrivalLog or -1)then b._battleArrivalLog=DotaTime()+3;print('[BATTLE_SAFETY] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=lost_fight_arrival_cancel')end
 return true
end
function X.Try(b)
 if not Free(b)or b:NumQueuedActions()>0 or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 then return false end
 local t=b:GetAttackTarget();local hold=b._battleExit
 if (not V(t)or not t:IsHero()or t:GetTeam()==b:GetTeam())and hold and DotaTime()<hold.untilTime then
  local s=X.Update(b);if s and s.dead>=2 and b:WasRecentlyDamagedByAnyHero(2)then
   local q=Exit(b,s);if q then hold.goal=q;b._battleOwnOrder=true;b:Action_MoveToLocation(q);b._battleOwnOrder=nil;return true end
  end
 end
 if not V(t)or not t:IsHero()or t:GetTeam()==b:GetTeam()then return false end
 local q=X.OrderGoal(b,'Action_AttackUnit',t);if not q then return false end
 b._battleOwnOrder=true;b:Action_MoveToLocation(q);b._battleOwnOrder=nil;return true
end
function X.RoshanSpacing(b,Fu)
 if not Free(b)or b:NumQueuedActions()>0 or not Fu.IsDoingRoshan(b)or Fu.GetPosition(b)<4
  or b:GetAttackRange()<400 or DotaTime()<(b._roshanSpaceNext or -1)then return false end
 local enemies=b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{};local threat
 for _,e in ipairs(enemies)do if V(e)and e:CanBeSeen()and not Fu.IsSuspiciousIllusion(e)then threat=e;break end end
 if not threat then return false end
 local crowded=0;for _,a in ipairs(b:GetNearbyHeroes(350,false,BOT_MODE_NONE)or{})do if a~=b and Body(a)then crowded=crowded+1 end end
 if crowded<2 then return false end
 local here=b:GetLocation();local p=threat:GetLocation();local dx,dy=here.x-p.x,here.y-p.y;local length=math.max(1,D(here,p));local sign=b:GetPlayerID()%2==0 and 1 or -1
 local q=Vector(here.x+dx/length*230-dy/length*sign*160,here.y+dy/length*230+dx/length*sign*160,here.z)
 if not Safe(b,q)then return false end
 b._roshanSpaceNext=DotaTime()+3;b._battleOwnOrder=true;b:Action_MoveToLocation(q);b._battleOwnOrder=nil
 print('[BATTLE_SAFETY] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=roshan_rear_spacing');return true
end

do local raw=X.Update;X.Update=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._battle_safetyErrorNext or -1)then b._battle_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=battle_safety function=Update error='..tostring(value))end
 return nil
end end
do local raw=X.Unsafe;X.Unsafe=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._battle_safetyErrorNext or -1)then b._battle_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=battle_safety function=Unsafe error='..tostring(value))end
 return false
end end
do local raw=X.OrderGoal;X.OrderGoal=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._battle_safetyErrorNext or -1)then b._battle_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=battle_safety function=OrderGoal error='..tostring(value))end
 return nil
end end
do local raw=X.Try;X.Try=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._battle_safetyErrorNext or -1)then b._battle_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=battle_safety function=Try error='..tostring(value))end
 return false
end end
do local raw=X.RoshanSpacing;X.RoshanSpacing=function(b,...)
 local ok,value=pcall(raw,b,...);if ok then return value end
 if b and DotaTime()>=(b._battle_safetyErrorNext or -1)then b._battle_safetyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=battle_safety function=RoshanSpacing error='..tostring(value))end
 return false
end end
return X
