-- Bounded corrections inside an existing fight; never assigns a team task.
local X={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Protected(b)
 return b~=GetBot()or not V(b)or not b:IsHero()or b:IsIllusion()or b:IsInvulnerable()
  or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()or b:IsStunned()or b:IsRooted()
  or b:IsHexed()or b:IsInvisible()or b:HasModifier('modifier_smoke_of_deceit')
  or b:HasModifier('modifier_bloodseeker_rupture')or b:HasModifier('modifier_batrider_flaming_lasso')
  or b:HasModifier('modifier_phoenix_sun_ray')or b:HasModifier('modifier_phoenix_icarus_dive')
end
local function Visible(b,enemies)
 local result={}
 for _,u in ipairs(b:GetNearbyHeroes(1200,enemies,BOT_MODE_NONE)or{})do
  if V(u)and u:CanBeSeen()and not u:IsIllusion()then result[#result+1]=u end
 end
 return result
end
function X.Update(b)
 if b~=GetBot()or not V(b)then return end
 local now=DotaTime();local s=b._combatPosition or{};b._combatPosition=s
 s.dps=s.dps or 0;s.hp=s.hp or b:GetHealth()
 if s.sampleAt and now>=s.sampleAt and now<s.sampleAt+.2 then return end
 local dt=now-(s.sampleAt or now);local loss=(s.hp or b:GetHealth())-b:GetHealth()
 s.dps=dt>=.15 and dt<1.2 and math.max(0,loss/dt)or 0
 s.hp=b:GetHealth();s.sampleAt=now
 if b._plEscapeAt then
  if b:HasModifier('modifier_phantom_lancer_doppelwalk_phase')or b:IsInvulnerable()then s.plHidden=true end
  if s.plHidden and not b:IsInvulnerable()and not b:HasModifier('modifier_phantom_lancer_doppelwalk_phase')then
   if now-b._plEscapeAt<3 and b:WasRecentlyDamagedByAnyHero(2)then
    local p=X.EscapeLocation(b,240)
    if p then X.Hold(b,p,'doppel_exit')end
   end
   b._plEscapeAt=nil;s.plHidden=nil
  elseif now-b._plEscapeAt>3 then b._plEscapeAt=nil;s.plHidden=nil end
 end
 local hiding=b:HasModifier('modifier_phoenix_supernova_hiding')
 if s.hiding and not hiding then s.hatchedUntil=now+2 end
 s.hiding=hiding
end
function X.ReadyAllies(b,range)
 local n=0
 for _,a in ipairs(Visible(b,false))do
  if a~=b and D(a:GetLocation(),b:GetLocation())<range and a:GetHealth()/math.max(1,a:GetMaxHealth())>.3
   and not a:IsStunned()and not a:IsHexed()and not a:HasModifier('modifier_phoenix_supernova_hiding')then n=n+1 end
 end
 return n
end
-- Choose a reachable landing/step that increases visible-enemy clearance.
-- Blink still uses conservative passable segments to avoid stranded landings.
function X.EscapeLocation(b,range)
 local home=GetAncient(b:GetTeam());if not V(home)then return nil end
 local loc=b:GetLocation();local enemies=Visible(b,true);if #enemies==0 then return nil end
 local function Clearance(p)local c=99999;for _,e in ipairs(enemies)do c=math.min(c,D(p,e:GetLocation()))end;return c end
 local dx,dy=home:GetLocation().x-loc.x,home:GetLocation().y-loc.y
 local norm=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/norm,dy/norm
 local towers=b:GetNearbyTowers(1600,true)or{};local best,score;local current=Clearance(loc)
 for _,angle in ipairs({0,35,-35,70,-70,110,-110,180})do
  local a=angle*math.pi/180;local p=Vector(loc.x+(dx*math.cos(a)-dy*math.sin(a))*range,loc.y+(dx*math.sin(a)+dy*math.cos(a))*range,loc.z)
  local clear=Clearance(p)
  if clear>current+60 and Safe(b,p,towers)then
   local value=math.min(1200,clear)-D(p,home:GetLocation())*.025
   if not score or value>score then best,score=p,value end
  end
 end
 return best
end
function X.Emergency(b)
 local s=b._combatPosition
 return s and b:GetHealth()/math.max(1,b:GetMaxHealth())<.48 and b:WasRecentlyDamagedByAnyHero(1)
  and (b:GetHealth()<(s.dps or 0)*2 or b:GetHealth()/math.max(1,b:GetMaxHealth())<.22)
end
function X.Hold(b,goal,reason)
 local s=b._combatPosition or{};b._combatPosition=s
 s.goal=goal;s.untilTime=DotaTime()+.7;s.nextCorrection=DotaTime()+4;s.reason=reason
 print(string.format('[COMBAT_POSITION] t=%.2f pid=%d phase=%s x=%.0f y=%.0f',DotaTime(),b:GetPlayerID(),reason,goal.x,goal.y))
end
local function ImmediateKill(b)
 local t=b:GetAttackTarget()
 return V(t)and t:CanBeSeen()and t:IsHero()and not t:IsIllusion()
  and GetUnitToUnitDistance(b,t)<=b:GetAttackRange()+30 and t:GetHealth()<b:GetAttackDamage()*1.4
end
function X.OrderGoal(b,action)
 local s=b._combatPosition
 if not s or not s.goal or DotaTime()>s.untilTime or Protected(b)or b:NumQueuedActions()>0 or ImmediateKill(b)then return nil end
 if action~='Action_AttackUnit'and action~='Action_AttackMove'and action~='Action_MoveToLocation'
  and action~='Action_MoveDirectly'then return nil end
 if D(b:GetLocation(),s.goal)<65 or not Safe(b,s.goal)then return nil end
 return s.goal
end
local AOE={npc_dota_hero_axe=true,npc_dota_hero_abyssal_underlord=true,npc_dota_hero_magnataur=true,
 npc_dota_hero_earthshaker=true,npc_dota_hero_sven=true,npc_dota_hero_enigma=true}
function X.Try(b)
 X.Update(b)
 if DotaTime()<360 or Protected(b)or b:NumQueuedActions()>0
  or DotaTime()<(b._ohaAbilityOrderAt or -999)+.35 or ImmediateKill(b)then return false end
 local s=b._combatPosition;local now=DotaTime()
 if s.goal and now<s.untilTime then
  local p=X.OrderGoal(b,'Action_MoveToLocation');if p then b:Action_MoveToLocation(p);return true end
 end
 if now<(s.nextCorrection or -1)or not b:WasRecentlyDamagedByAnyHero(1)then return false end
 local enemies=Visible(b,true);if #enemies==0 then return false end
 local towers=b:GetNearbyTowers(1000,true)or{};local targeted=false
 for _,t in ipairs(towers)do if V(t)and t:GetAttackTarget()==b then targeted=true end end
 local postEgg=now<(s.hatchedUntil or -1)and #enemies>=2 and X.ReadyAllies(b,700)==0
 if (X.Emergency(b)and(targeted or X.ReadyAllies(b,700)<#enemies))or postEgg then
  local p=X.EscapeLocation(b,280)
  if p then X.Hold(b,p,postEgg and'post_egg_exit'or'focused_exit');b:Action_MoveToLocation(p);return true end
 end
 -- Spread a rear hero only during actual AoE contact, at most one short step per four seconds.
 if b:GetAttackRange()<400 then return false end
 local aoe=false
 for _,e in ipairs(enemies)do if AOE[e:GetUnitName()]and D(e:GetLocation(),b:GetLocation())<850 then aoe=true end end
 if not aoe then return false end
 local friends={}
 for _,a in ipairs(Visible(b,false))do if a~=b and D(a:GetLocation(),b:GetLocation())<220 then friends[#friends+1]=a end end
 if #friends<2 then return false end
 local loc=b:GetLocation();local nearest=enemies[1]:GetLocation();local dx,dy=loc.x-nearest.x,loc.y-nearest.y
 local norm=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/norm,dy/norm
 local function Separation(p)local n=99999;for _,a in ipairs(friends)do n=math.min(n,D(p,a:GetLocation()))end;return n end
 for _,sign in ipairs(b:GetPlayerID()%2==0 and{1,-1}or{-1,1})do
  local p=Vector(loc.x-dy*sign*210+dx*50,loc.y+dx*sign*210+dy*50,loc.z)
  local good=Separation(p)>Separation(loc)+90 and Safe(b,p,towers)
  for _,e in ipairs(enemies)do if D(p,e:GetLocation())<D(loc,e:GetLocation())-40 then good=false end end
  if good then X.Hold(b,p,'contact_spacing');b:Action_MoveToLocation(p);return true end
 end
 return false
end
return X
