-- Only the assemble mode issues waiting movement. Team releases share one decision.
local X={};local teams={}
local function Dist(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Valid(u) return u and not u:IsNull() and u:IsAlive() and not u:IsIllusion() end
local function Team(b) local t=teams[b:GetTeam()];if not t then t={releaseUntil=-1};teams[b:GetTeam()]=t end;return t end
local function Counts(b)
 local own,enemy=0,0
 for _,id in ipairs(GetTeamPlayers(b:GetTeam(),true)) do if IsHeroAlive(id) then own=own+1 end end
 for _,id in ipairs(GetTeamPlayers(GetOpposingTeam(),true)) do if IsHeroAlive(id) then enemy=enemy+1 end end
 return own,enemy
end
local function Outnumbered(own,enemy)
 return enemy-own>=3 or own<=2 and enemy>=4
end
local function ReadyGroup(b,anchor)
 local near=0
 for i=1,5 do local a=GetTeamMember(i)
  if Valid(a) and a:IsHero() and a:GetTeam()==b:GetTeam()
   and not a:IsChanneling() and not a:HasModifier('modifier_teleporting')
   and a:GetHealth()/math.max(1,a:GetMaxHealth())>0.45
   and Dist(a:GetLocation(),b:GetLocation())<1800
   and Dist(a:GetLocation(),anchor)<4200 then near=near+1 end
 end
 return near
end
local function Log(b,phase,extra) print(string.format('[RESPAWN_REGROUP] t=%.3f pid=%d phase=%s %s',DotaTime(),b:GetPlayerID(),phase,extra or '')) end
local function Stop(b,s,why,group)
 s.wait=nil;s.used=true
 if why=='numbers_recovered_release'or why=='cohort_release'then b._regroupCautiousUntil=DotaTime()+12 end
 Log(b,why)
 if group then Team(b).releaseUntil=DotaTime()+1 end
end
function X.Update(b)
 if not b or not b:IsHero() or b:IsIllusion() then return nil end
 local now=DotaTime();local s=b._respawnRegroup or {};b._respawnRegroup=s;local t=Team(b)
 local deaths=type(GetHeroDeaths)=='function' and GetHeroDeaths(b:GetPlayerID()) or 0
 local revived=s.wasDead or s.lastDeaths and deaths>s.lastDeaths
 s.lastDeaths=deaths
 if not b:IsAlive() then
  if s.wait then Log(b,'death_release') end
  s.wasDead=true;s.wait=nil;s.used=nil;return nil
 end
 if revived then
  s.wasDead=false;s.used=true
  local a=GetAncient(b:GetTeam());local own,enemy=Counts(b)
  if now>=180 and now>t.releaseUntil and Valid(a) and Dist(b:GetLocation(),a:GetLocation())<4500 and Outnumbered(own,enemy) then
   s.wait={untilTime=now+15,started=now,anchor=a:GetLocation()};s.next=0
   Log(b,'hold_start','own='..own..' enemy='..enemy)
  end
 end
 if not s.wait then return nil end
 if now<=t.releaseUntil then Stop(b,s,'cohort_release',false);return nil end
 if now<(s.next or 0) then return s.wait end;s.next=now+0.5
 local own,enemy=Counts(b)
 local ready=ReadyGroup(b,s.wait.anchor)
 if enemy<=1 then Stop(b,s,'enemy_numbers_safe_release',true);return nil end
 if not Outnumbered(own,enemy) then
  -- Give freshly revived teammates a short opportunity to leave together; no
  -- distant attacking hero is recruited back to the fountain for this check.
  local nearby=0
  for i=1,5 do local a=GetTeamMember(i)
   if Valid(a) and a:IsHero() and Dist(a:GetLocation(),b:GetLocation())<1200
    and a:GetHealth()/math.max(1,a:GetMaxHealth())>0.45 then nearby=nearby+1 end
  end
  -- Global alive counts can recover while the revived partners are still at
  -- the fountain or crossing another lane. Release only a usable local group.
  if ready>=math.min(3,math.max(2,enemy-1)) and nearby>=2 then
   Stop(b,s,'numbers_recovered_release',true);return nil
  end
 end
 local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
 local human,ping=Fu.GetHumanPing()
 if human and ping and ping.normal_ping and GameTime()-ping.time<8 then Stop(b,s,'human_command_release',true);return nil end
 local safe=0
 for _,id in ipairs(GetTeamPlayers(GetOpposingTeam(),true)) do
  if IsHeroAlive(id) then local info=GetHeroLastSeenInfo(id);local d=info and info[1]
   if d and d.time_since_seen<3 and Dist(d.location,s.wait.anchor)>6500 then safe=safe+1 end
  end
 end
 if safe==enemy and safe>0 then Stop(b,s,'visible_safe_opportunity_release',true);return nil end
 if now>=s.wait.untilTime then
  if (Outnumbered(own,enemy) or ready<math.min(3,math.max(2,enemy-1))) and now-s.wait.started<45 then
   -- Waiting is local safe activity, not a team-wide halt. A timeout must not
   -- release every staggered respawn into an unchanged numerical disadvantage.
   s.wait.untilTime=math.min(s.wait.started+45,now+5)
   if not s.wait.loggedRisk then s.wait.loggedRisk=true;Log(b,'extend_unsafe_exit','own='..own..' enemy='..enemy) end
   return s.wait
  end
  -- A bounded hold ends in the original programme. For a short period only,
  -- prevent a fresh TP into a remote front with no living support; no recall.
  b._regroupCautiousUntil=now+12
  Stop(b,s,'timeout_local_reassess',false);return nil
 end
 return s.wait
end
function X.AllowFrontTP(b,loc)
 if DotaTime()>=(b._regroupCautiousUntil or -1) then return true end
 local n=0
 for i=1,5 do local a=GetTeamMember(i)
  if a~=b and Valid(a) and a:IsHero() and a:GetTeam()==b:GetTeam()
   and a:GetHealth()/math.max(1,a:GetMaxHealth())>.45 and Dist(a:GetLocation(),loc)<1600 then n=n+1 end
 end
 if n<2 then
  if DotaTime()>=(b._regroupTPLogNext or -1)then b._regroupTPLogNext=DotaTime()+3;Log(b,'front_tp_no_arrived_support','arrived='..n)end
  return false
 end
 return true
end
local function State(b)
 local s=X.Update(b);if not s then return nil end
 local Guard=require(GetScriptDirectory()..'/FuncLib/systems/highground_guard')
 if Guard.HasActiveThreat(b) or b:WasRecentlyDamagedByAnyHero(2) then return nil end
 for _,e in ipairs(b:GetNearbyHeroes(1400,true,BOT_MODE_NONE) or {}) do if Valid(e) and e:CanBeSeen() then return nil end end
 if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted() then return nil end
 return s
end
function X.IsWaiting(b) return State(b)~=nil end
function X.GetDesire(b) return State(b) and 0.93 or 0 end
function X.Think(b)
 local s=State(b);if not s then return false end
 if DotaTime()>=(s.nextOrder or 0) then
  s.nextOrder=DotaTime()+0.6
  local creeps=b:GetNearbyLaneCreeps(900,true) or {}
  for _,c in ipairs(creeps) do
   if Valid(c) and Dist(c:GetLocation(),s.anchor)<2600 then
    if b:GetAttackTarget()~=c then b:Action_AttackUnit(c,false) end;return true
   end
  end
  if Dist(b:GetLocation(),s.anchor)>1000 then b:Action_MoveToLocation(s.anchor) end
 end
 return true
end
return X
