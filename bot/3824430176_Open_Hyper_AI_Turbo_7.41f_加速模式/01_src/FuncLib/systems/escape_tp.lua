-- Retreat TP safety, using only visible enemies and public last-seen records.
-- No global TP rate reduction, no enemy cooldown reads and no forced forest trip.
local X={}
local noNativeInterrupt={npc_dota_hero_clinkz=true,npc_dota_hero_venomancer=true,npc_dota_hero_bristleback=true}
local function Dist(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Valid(u) return u and not u:IsNull() and u:IsAlive() and u:IsHero() and not u:IsIllusion() end
local function Log(b,phase,extra)
 local now=DotaTime();local s=b._escapeTPState
 if now<(s.logNext or -999) and s.phase==phase then return end
 s.phase=phase;s.logNext=now+4
 print(string.format('[ESCAPE_TP] t=%.2f pid=%d phase=%s %s',now,b:GetPlayerID(),phase,extra or ''))
end
function X.Observe(b)
 if not b or not b:IsAlive() then if b then b._escapeTPState=nil end;return end
 local now=DotaTime();local s=b._escapeTPState or {};b._escapeTPState=s
 if now<(s.nextScan or -999) then return end;s.nextScan=now+0.25
 local loc=b:GetLocation();local hp=b:GetHealth()
 s.speed= s.loc and Dist(loc,s.loc)/math.max(.1,now-(s.at or now)) or 0
 s.loss= s.hp and math.max(0,s.hp-hp)/math.max(.25,now-(s.at or now)) or 0
 s.loc=loc;s.hp=hp;s.at=now
end
local function Threats(b,channel)
 local visible={};local threats={};local loc=b:GetLocation()
 local invulnerable=b:IsInvulnerable()
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE) or {}) do
  if Valid(e) and e:CanBeSeen() then
   visible[e:GetPlayerID()]=true
   local distance=Dist(loc,e:GetLocation());local speed=math.max(200,e:GetCurrentMovementSpeed())
   -- Unknown interrupt availability stays a risk. Do not use hidden cooldowns.
   local interrupt=not noNativeInterrupt[e:GetUnitName()]
   for i=0,5 do local h=e:GetItemInSlot(i)
    if h and (h:GetName()=='item_abyssal_blade' or h:GetName()=='item_basher' or h:GetName()=='item_sheepstick'
     or h:GetName()=='item_cyclone' or h:GetName()=='item_wind_waker') then interrupt=true end
   end
   local bound=650+speed*channel
   if distance<bound then
    local range=e:GetAttackRange();local hitting=distance<range+speed*channel*.6
    local damage=hitting and e:GetAttackDamage()*channel/math.max(.25,e:GetSecondsPerAttack()) or 0
    local incoming=b:GetActualIncomingDamage(damage,DAMAGE_TYPE_PHYSICAL)
    threats[#threats+1]={loc=e:GetLocation(),distance=distance,risk=interrupt,damage=invulnerable and 0 or incoming}
   end
  end
 end
 for _,id in ipairs(GetTeamPlayers(GetOpposingTeam())) do
  if not visible[id] and IsHeroAlive(id) then
   local info=GetHeroLastSeenInfo(id);local last=info and info[1]
   if last and last.time_since_seen<=6 then
    local distance=Dist(loc,last.location)
    -- A lost enemy does not vanish at the old two-second cutoff. Expanding
    -- reach is bounded; old records outside it cannot veto an otherwise safe TP.
    if distance<700+380*(math.min(4,last.time_since_seen)+channel) then
     threats[#threats+1]={loc=last.location,distance=distance,risk=true,hidden=true,damage=0}
    end
   end
  end
 end
 return threats
end
local function Cover(b,threats)
 if not IsLocationPassable or not GetTreeLocation then return nil end
 local ancient=GetAncient(b:GetTeam());if not ancient or ancient:IsNull() then return nil end
 local loc=b:GetLocation();local home=ancient:GetLocation()
 local dx,dy=home.x-loc.x,home.y-loc.y;local norm=math.max(1,math.sqrt(dx*dx+dy*dy))
 local function Safe(p)
  if not require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,p) then return false end
  for _,e in ipairs(threats) do if Dist(p,e.loc)<e.distance+40 then return false end end
  return true
 end
 local s=b._escapeTPState
 if s.cover and DotaTime()<(s.coverUntil or -1) and Dist(loc,s.cover)>60 and Safe(s.cover) then return s.cover end
 local best,score
 for _,tree in ipairs(b:GetNearbyTrees(550) or {}) do
  local t=GetTreeLocation(tree)
  -- Use the homeward edge of nearby trees, never the tree centre/dead end.
  local p=Vector(t.x+dx/norm*130,t.y+dy/norm*130,loc.z)
  local step=Dist(loc,p);local forward=(p.x-loc.x)*dx/norm+(p.y-loc.y)*dy/norm
  local safe=forward>40 and step<=400 and step>100 and IsLocationPassable(p)
  if safe then
   local midpoint=Vector((loc.x+p.x)/2,(loc.y+p.y)/2,loc.z)
   safe=IsLocationPassable(midpoint)
  end
  if safe then safe=Safe(p) end
  if safe and (not score or step<score) then best,score=p,step end
 end
 -- A veto must not leave an idle retreating hero waiting for a tree. Only
 -- recover after observed lack of movement; normal retreat orders keep control.
 if not best and s.vetoAt and DotaTime()-s.vetoAt>=.8 and s.vetoOrigin
  and Dist(loc,s.vetoOrigin)<40 and b:GetCurrentActionType()==BOT_ACTION_TYPE_IDLE
  and b:GetActiveMode()==BOT_MODE_RETREAT then
  for _,angle in ipairs({0,45,-45,90,-90}) do
   local a=angle*math.pi/180;local x,y=dx/norm,dy/norm
   local p=Vector(loc.x+300*(x*math.cos(a)-y*math.sin(a)),loc.y+300*(x*math.sin(a)+y*math.cos(a)),loc.z)
   if Safe(p) then best=p;break end
  end
  if best then Log(b,'idle_retreat_recovery','actual_movement_not_observed') end
 end
 return best
end
function X.Allow(b,item,reason)
 X.Observe(b);local s=b._escapeTPState
 if not s then return false end
 local now=DotaTime()
 if now<(s.vetoUntil or -1) then return false end
 local channel=math.max(3,item.GetChannelTime and item:GetChannelTime() or 3)
 local threats=Threats(b,channel);local projected=0;local hidden=0;local interrupt=false
 for _,e in ipairs(threats) do projected=projected+e.damage;interrupt=interrupt or e.risk;if e.hidden then hidden=hidden+1 end end
 local damaged=b:WasRecentlyDamagedByAnyHero(3)
 if #threats==0 and not damaged then
  s.cover=nil;s.vetoAt=nil;s.vetoOrigin=nil;Log(b,'safe_tp',reason);return true
 end
 -- Keep a one-second stable exit window, rather than stopping immediately at
 -- the instant the enemy disappears. Original retreat movement continues.
 if #threats==0 then
  s.clearSince=s.clearSince or now
  if now-s.clearSince>=1 and s.loss<30 then Log(b,'stable_window_tp',reason);return true end
 else s.clearSince=nil end
 local fatal=projected+s.loss*channel*.7>b:GetHealth()*.8
 local moving=(s.speed or 0)>b:GetCurrentMovementSpeed()*.45
 if #threats>0 and not interrupt and not fatal then
  s.cover=nil;Log(b,'no_interrupt_tp',reason);return true
 end
 if #threats>0 then
  if not s.vetoAt or Dist(b:GetLocation(),s.vetoOrigin)>70 then s.vetoAt=now;s.vetoOrigin=b:GetLocation() end
  local cover=Cover(b,threats)
  if cover~=s.cover then s.cover=cover;s.coverUntil=now+1.2 end
  if cover and b:GetActiveMode()==BOT_MODE_RETREAT and not b:IsChanneling()
   and not b:IsUsingAbility() and not b:IsCastingAbility() and not b:IsStunned()
   and not b:IsRooted() and now>=(s.moveNext or -999) then
   s.moveNext=now+.6;b:Action_MoveToLocation(cover)
  end
  Log(b,cover and 'seek_nearby_cover' or 'continue_escape',string.format('threats=%d hidden=%d lethal=%s moving=%s',#threats,hidden,tostring(fatal),tostring(moving)))
  s.vetoUntil=now+0.4
  return false
 end
 s.cover=nil;Log(b,'continue_escape','recent_damage');return false
end
-- Optional short homeward adjustment. It never freezes, waits for a tree, or
-- owns normal movement; caller remains the original retreat mode.
function X.GetCover(b)
 local s=b._escapeTPState
 if s and s.cover and DotaTime()<s.coverUntil then return s.cover end
end
return X
