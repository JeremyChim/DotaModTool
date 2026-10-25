-- Visible early counter-rotation. At most two team responders; no task after 11:00.
local X={};local teams={}
local function D(a,b)if not a or not b then return math.huge end;local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function V(u)
 if not u then return false end
 local ok,v=pcall(function()return not u:IsNull()and u:IsAlive()end);return ok and v or false
end
local function Seen(u)
 if not V(u)then return nil end
 local ok,id,p=pcall(function()if u:CanBeSeen()then return u:GetPlayerID(),u:GetLocation()end end)
 if ok and type(id)=='number'and p then return id,p end
end
local function Own(b)return V(b)and b==GetBot()and b:IsHero()and not b:IsIllusion()end
local function Cutoff()return GetGameMode and GetGameMode()==23 and 600 or 660 end
local function Fu()return require(GetScriptDirectory()..'/FuncLib/func_utils')end
local function Log(b,phase,detail)
 print(string.format('[COUNTER_ROTATION] t=%.2f pid=%d phase=%s %s',DotaTime(),b:GetPlayerID(),phase,detail or''))
end
local function Team(b)
 local t=teams[b:GetTeam()];if not t then t={history={},events={},tasks={},retry={},serial=0};teams[b:GetTeam()]=t end;return t
end
local apiShapeLogged=false
local function Lane(p)
 local best,score
 for _,lane in ipairs({LANE_TOP,LANE_MID,LANE_BOT})do
  local along,distance=GetAmountAlongLane(lane,p)
  if type(along)=='table'then distance=along.distance end
  if not apiShapeLogged then apiShapeLogged=true;print('[COUNTER_ROTATION_API] t='..DotaTime()..' result='..type(along)..' distance='..tostring(distance))end
  if type(distance)=='number'and distance<1100 and(not score or distance<score)then best,score=lane,distance end
 end
 return best
end
local function Tower(b,lane,tier)
 local id=lane==LANE_TOP and(tier==1 and TOWER_TOP_1 or TOWER_TOP_2)
  or lane==LANE_MID and(tier==1 and TOWER_MID_1 or TOWER_MID_2)
  or(tier==1 and TOWER_BOT_1 or TOWER_BOT_2)
 local u=GetTower(b:GetTeam(),id);return V(u)and u or nil
end
local function Step(a,p,length)
 local d=math.max(1,D(a,p));local f=math.min(1,length/d);return Vector(a.x+(p.x-a.x)*f,a.y+(p.y-a.y)*f,a.z)
end
local function BuildingBack(b,u,offset)
 local fort=GetAncient(b:GetTeam());if not V(fort)then return nil end
 local p,a=u:GetLocation(),fort:GetLocation();local d=math.max(1,D(p,a))
 return Vector(p.x+(a.x-p.x)/d*offset,p.y+(a.y-p.y)/d*offset,p.z)
end
local function Safe(b,p)
 return require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,p)
end
local function Protected(b)
 return not V(b)or b:IsInvulnerable()or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
  or b:IsStunned()or b:IsRooted()or b:IsHexed()or b:NumQueuedActions()>0
  or b:HasModifier('modifier_bloodseeker_rupture')
end
local function Busy(b)
 local f=Fu();local mode=b:GetActiveMode()
 return f.IsPushing(b)or f.IsDefending(b)or f.IsDoingRoshan(b)or f.IsDoingTormentor(b)
  or mode==BOT_MODE_ASSEMBLE or mode==BOT_MODE_RUNE or mode==BOT_MODE_DEFEND_ALLY
  or(b._earlyLotus and b._earlyLotus.active)or(b._wisdomOnce and b._wisdomOnce.active)
  or(b._outpostTask and b._outpostTask.active)or b._guardTravel or b._guardBaseArea
  or b._enigmaCombo or b._invokerPlan or b._openingRuneLock
end
local function Visible(b)
 local out,groups={},{};local f=Fu()
 for _,e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do
  -- Do not query location/skills of a hidden enemy, or trust replay illusion flags.
  if e and not e:IsNull()and e:CanBeSeen()and e:IsAlive()and e:IsHero()
   and e:GetTeam()~=b:GetTeam()and not f.IsSuspiciousIllusion(e)then
   local id=e:GetPlayerID();groups[id]=groups[id]or{};groups[id][#groups[id]+1]=e
  end
 end
 for _,g in pairs(groups)do if #g==1 then out[#out+1]=g[1]end end
 return out
end
local function Members()
 local a={};for i=1,5 do local u=GetTeamMember(i);if V(u)and u:IsHero()and not u:IsIllusion()then a[#a+1]=u end end;return a
end
local function NearEnemies(visible,p,r)
 local n=0;for _,e in ipairs(visible or{})do local id,q=Seen(e);if id and D(q,p)<r then n=n+1 end end;return n
end
local function SpellBudget(b)
 local n,minimum=0,nil
 for i=0,7 do local a=b:GetAbilityInSlot(i)
  if a and not a:IsHidden()and not a:IsPassive()and a:IsTrained()and a:IsFullyCastable()
   and not a:GetName():find('special_bonus_',1,true)then
   local cost=a:GetManaCost();if cost>0 then n=n+1;minimum=math.min(minimum or cost,cost)end
  end
 end
 return n,minimum or 0
end
local function Home(b)return Fu().GetExpectedLane(b)end
local function Ready(b)
 if not V(b)or b:IsIllusion()or Protected(b)or Busy(b)or Fu().IsGoingOnSomeone(b)or Fu().IsRetreating(b)
  or b:WasRecentlyDamagedByAnyHero(3)or b:GetHealth()/math.max(1,b:GetMaxHealth())<.55 then return false end
 local role=Fu().GetPosition(b)
 if role~=2 and role~=4 and role~=5 then return false end
 local n,cost=SpellBudget(b)
 return n>0 and b:GetMana()>=cost,role,cost
end
local function RetryKey(event)return event.retryKey or event.key end
local function Diagnose(b,t,key,reason)
 t.diagnosticAt=t.diagnosticAt or{}
 if DotaTime()>=(t.diagnosticAt[key]or -999)then
  t.diagnosticAt[key]=DotaTime()+15;Log(b,'not_assigned','reason='..reason..' event='..key)
 end
end
local function ReleaseDelay(s,reason)
 if reason=='tp_unconfirmed_release'or reason=='departure_invalid'or reason=='error_release'then return 1.5,4 end
 if reason=='tp_interrupted_release'or reason=='tp_unsafe_cancel'or reason=='source_interrupt_risk_release'
  or reason=='unsafe_departure_release'then return 2,6 end
 if not s.departed then return 1.5,2 end
 return 35,4
end
local function Finish(b,t,s,reason)
 if b._counterTask~=s then return end
 -- Clear only our own still-current movement, never a TP, cast or subsequent AI order.
 local move=b._originalMove
 if s.lastMove and move and D(move.loc,s.lastMove)<10 and math.abs(move.at-(s.moveAt or -999))<.15
  and b:GetActiveMode()==BOT_MODE_TEAM_ROAM and not b:IsChanneling()and not b:IsUsingAbility()
  and not b:IsCastingAbility()and b:GetCurrentActionType()==BOT_ACTION_TYPE_MOVE_TO then
  b._counterOwnOrder=true;b:Action_ClearActions(false);b._counterOwnOrder=nil
 end
 b._counterTask=nil;if t.tasks[b:GetPlayerID()]==s then t.tasks[b:GetPlayerID()]=nil end
 local delay,personal=ReleaseDelay(s,reason)
 local key=RetryKey(s);t.retry[key]=math.max(t.retry[key]or 0,DotaTime()+delay)
 b._counterRetry=math.max(b._counterRetry or 0,DotaTime()+personal);b._counterTPGuard=nil
 Log(b,reason,'event='..s.id..' retry='..delay)
end
local function Danger(b,event,visible,allies)
 local p=event.unit:GetLocation();local victim,best
 local defenders=0
 for _,a in ipairs(allies)do
  if Lane(a:GetLocation())==event.lane and D(a:GetLocation(),p)<1150 then
   defenders=defenders+1
   local d=D(a:GetLocation(),p)
   if not best or d<best then victim,best=a,d end
  end
 end
 if not victim then return nil end
 local enemies=NearEnemies(visible,victim:GetLocation(),1100)
 local attack=event.unit:GetAttackTarget()
 local engaged=attack==victim or victim:WasRecentlyDamagedByAnyHero(1.5)
 local tower=Tower(b,event.lane,1)
 local dive=tower and D(p,tower:GetLocation())<850 and D(victim:GetLocation(),tower:GetLocation())<1100
 if enemies<2 or(not engaged and not dive and enemies<=defenders)then return nil end
 return {victim=victim,defenders=defenders,enemies=enemies,urgent=dive and engaged,engaged=engaged}
end
local interrupt
local function Scan(b,t,now)
 if now<(t.scanAt or -999)then return end;t.scanAt=now+.25
 t.visible=Visible(b);local allies=Members();local active={};t.recentThreats=t.recentThreats or{}
 for _,e in ipairs(t.visible)do
  local id=e:GetPlayerID();local p=e:GetLocation();local lane=Lane(p);local h=t.history[id]or{votes={}};t.history[id]=h
  if p then
   local reach=1100
   for slot=0,23 do local a=e:GetAbilityInSlot(slot)
    if a and not a:IsHidden()and a:IsTrained()and interrupt and interrupt[a:GetName()]then reach=math.max(reach,a:GetCastRange()+e:GetCurrentMovementSpeed()*3+150)end
   end
   t.recentThreats[id]={at=now,loc=p,reach=math.min(2200,reach)}
  end
  local dt=h.seen and math.min(1,math.max(0,now-h.seen))or 0
  local base=GetAncient(e:GetTeam())
  if V(base)and D(p,base:GetLocation())<2500 then lane=nil end
  if lane then
   if not h.home then
    if now<240 then
     h.votes[lane]=(h.votes[lane]or 0)+dt
     if h.votes[lane]>=12 then h.home=lane end
    elseif now<420 then
     -- Late reconstruction requires an uninterrupted, visible quiet lane sample.
     -- Never learn an origin from an ongoing gank or from last-seen fog positions.
     local target=e:GetAttackTarget()
     local quiet=not e:WasRecentlyDamagedByAnyHero(3)and not(target and target:IsHero())
      and not Danger(b,{unit=e,lane=lane},t.visible,allies)
     if not quiet or h.lastLane~=lane or not h.seen or now-h.seen>1 then h.lateSince=nil end
     if quiet then h.lateSince=h.lateSince or now
      if now-h.lateSince>=24 then h.home=lane;Log(b,'origin_learned_late','enemy='..id..' lane='..lane)end
     end
     if not h.home then Diagnose(b,t,'origin:'..id,'origin_unknown')end
    end
   end
   local key='lane:'..lane
   if h.home and h.home~=lane then
    local danger=Danger(b,{unit=e,lane=lane},t.visible,allies)
    if danger then
     local ev=t.events[key]
     if not ev then t.eventSerial=(t.eventSerial or 0)+1;ev={key=key,first=now,token=key..':'..t.eventSerial};t.events[key]=ev end
     if now-(ev.last or now)>1 then ev.first=now end
     if not active[key]then ev.sources={}end;ev.sources[id]=true
     ev.id=id;ev.unit=e;ev.lane=lane;ev.loc=p;ev.last=now;ev.home=h.home;ev.danger=danger;active[key]=true
     h.swapSince=nil
    else
     if h.swapLane~=lane or not h.seen or now-h.seen>2 then h.swapSince=now;h.swapLane=lane end
     if h.swapSince and now-h.swapSince>=40 then h.home=lane;h.swapSince=nil end
    end
   else h.swapSince=nil end
  end
  h.seen=now;h.lastLane=lane
 end
 for key,event in pairs(t.events)do
  if not active[key]then event.danger=nil else
   local ids={};for id in pairs(event.sources)do ids[#ids+1]=id end;table.sort(ids)
   local parts={};for _,id in ipairs(ids)do parts[#parts+1]=tostring(id)end
   event.retryKey=event.token..':'..table.concat(parts,',')
  end
  if now-event.last>8 then t.events[key]=nil end
 end
 for pid,s in pairs(t.tasks)do
  if s.owner~=b and s.owner._counterTask~=s then
   -- Isolated LAN sandboxes cannot rely on another bot's Lua fields.
   -- Keep deterministic reservations and reconcile against allied observations.
   if V(s.owner)and s.owner:HasModifier('modifier_teleporting')then s.phase='external_tp';s.departed=true end
   if V(s.owner)and D(s.owner:GetLocation(),s.source)>1500 and D(s.owner:GetLocation(),s.point)<1150 then s.phase='contact';s.departed=true end
   if now-s.started>30 or now-s.started>8 and not s.departed then t.tasks[pid]=nil;t.retry[RetryKey(s)]=now+(s.departed and 35 or 2) end
  elseif now-s.heartbeat>2 or not V(s.owner)then t.tasks[pid]=nil;t.retry[RetryKey(s)]=now+(s.departed and 35 or 2) end
 end
end
local function OriginSafe(b,event,t,departing)
 local home=Home(b)
 if not home or home==event.lane then return false end
 local remaining={}
 for _,a in ipairs(Members())do if a~=b and not(departing and departing[a:GetPlayerID()])and Lane(a:GetLocation())==home then remaining[#remaining+1]=a end end
 for _,a in ipairs(remaining)do
  local enemies=NearEnemies(t.visible,a:GetLocation(),1200)
  if enemies>1 and(enemies>#remaining or a:WasRecentlyDamagedByAnyHero(2)or a:GetHealth()/a:GetMaxHealth()<.65)then return false end
 end
 local own=Tower(b,home,1)
 if own and own:WasRecentlyDamagedByAnyHero(3)and NearEnemies(t.visible,own:GetLocation(),1000)>0 then return false end
 return true
end
local function Landing(b,event,t)
 local tower=Tower(b,event.lane,1);if not tower then return nil end
 local point=BuildingBack(b,tower,260);if not point or not IsLocationPassable(point)then return nil end
 if D(point,event.danger.victim:GetLocation())>1500 then return nil end
 if NearEnemies(t.visible,point,650)>0 then return nil end
 return point,tower
end
-- Conservative departure screening: do not channel beside the original opponents.
-- Only visible enemies are inspected; range includes time for an enemy to walk in.
interrupt={lion_impale=true,lion_voodoo=true,shadow_shaman_voodoo=true,shadow_shaman_shackles=true,
 vengefulspirit_magic_missile=true,sven_storm_bolt=true,chaos_knight_chaos_bolt=true,
 pudge_meat_hook=true,mirana_arrow=true,earthshaker_fissure=true,nyx_assassin_impale=true,
 windrunner_shackleshot=true,clockwerk_hookshot=true,spirit_breaker_charge_of_darkness=true,
 disruptor_glimpse=true,tiny_avalanche=true,lina_light_strike_array=true,leshrac_split_earth=true,
 jakiro_ice_path=true,sandking_burrowstrike=true,vengefulspirit_nether_swap=true,
 rubick_telekinesis=true,lich_sinister_gaze=true,crystal_maiden_frostbite=true}
local function SourceSafe(b,t,p)
 if b:WasRecentlyDamagedByAnyHero(3)then return false end
 for _,r in pairs(t.recentThreats or{})do if DotaTime()-r.at<2.5 and D(r.loc,p)<r.reach then return false end end
 for _,e in ipairs(t.visible or{})do
  if V(e)and e:CanBeSeen()then
  local d=D(e:GetLocation(),p)
  if d<1100 then return false end
  if d<2200 then
   for slot=0,23 do local a=e:GetAbilityInSlot(slot)
    if a and not a:IsHidden()and a:IsTrained()and interrupt[a:GetName()]
     and a:IsFullyCastable()and d<a:GetCastRange()+450 then return false end
   end
  end
  end
 end
 return true
end
local function Candidate(b,event,t)
 local now=DotaTime();local ready,role,cost=Ready(b)
 local function Reject(why)Diagnose(b,t,event.key..':candidate:'..b:GetPlayerID(),why);return nil end
 local status={ready=ready,role=role,spellCost=cost or 0}
 if not V(b)then return Reject('candidate_invalid')end
 if not status.ready then return Reject('candidate_not_ready_mode_'..tostring(b:GetActiveMode())..'_role_'..tostring(Fu().GetPosition(b)))end
 if now<(b._counterRetry or -999)then return Reject('candidate_retry')end
 if b._counterTask then return Reject('candidate_reserved')end
 if not OriginSafe(b,event,t)then return Reject('candidate_origin_unsafe')end
 if status.role==2 and b:GetLevel()<6 and not event.danger.urgent then return Reject('candidate_mid_level')end
 local point,tower=Landing(b,event,t);if not point then return Reject('candidate_landing_unsafe_or_far')end
 local prepare
 if not SourceSafe(b,t,b:GetLocation())then
  local homeTower=Tower(b,Home(b),1);local back=homeTower and BuildingBack(b,homeTower,300)
  prepare=back and Step(b:GetLocation(),back,450)
  if not prepare or D(prepare,b:GetLocation())<100 or not Safe(b,prepare)or not SourceSafe(b,t,prepare)then return Reject('candidate_departure_interrupt_risk')end
 end
 local distance=D(b:GetLocation(),event.danger.victim:GetLocation())
 local walk=math.max(0,distance-650)/math.max(200,b:GetCurrentMovementSpeed())
 local tp=b:GetItemInSlot(15);local eta=walk;local useTP=false
 if distance>1800 and tp and tp:GetName()=='item_tpscroll'and tp:IsFullyCastable()
  and b:GetMana()>=tp:GetManaCost()+status.spellCost then
  local channel=math.max(3,tp:GetChannelTime())
  local travel=channel+math.max(0,D(point,event.danger.victim:GetLocation())-650)/math.max(200,b:GetCurrentMovementSpeed())+.4
  if travel<walk then eta=travel;useTP=true end
 end
 if not useTP and walk>3 then return Reject('candidate_no_usable_tp_or_walk_eta_'..string.format('%.1f',walk))end
 if not useTP then prepare=nil end
 if prepare then eta=eta+D(prepare,b:GetLocation())/math.max(200,b:GetCurrentMovementSpeed())end
 if eta>7 then return Reject('candidate_eta_'..string.format('%.1f',eta))end
 local victim=event.danger.victim;local watch=t.health and t.health[victim:GetPlayerID()]
 local life=watch and watch.loss>0 and victim:GetHealth()/watch.loss or math.huge
 if event.danger.engaged and life<eta+.8 and victim:GetHealth()/victim:GetMaxHealth()<.45 then return Reject('candidate_victim_life_budget')end
 -- Do not send one more hero into an already hopeless numerical disadvantage.
 if event.danger.enemies>event.danger.defenders+2 then return nil end
 return {owner=b,point=point,tower=tower,prepare=prepare,tp=useTP,eta=eta,score=eta+(status.role==2 and 1.5 or 0)}
end
local function UpdateHealth(t,now)
 t.health=t.health or{}
 for _,a in ipairs(Members())do local id=a:GetPlayerID();local old=t.health[id]
  if not old or now-old.at>=.5 then
   t.health[id]={at=now,hp=a:GetHealth(),loss=old and now-old.at<2 and math.max(0,(old.hp-a:GetHealth())/(now-old.at))or 0}
  end
 end
end
local function StartReturn(b,t,s,why)
 if s.phase=='return'then return end
 if not s.departed and D(b:GetLocation(),s.source)<550 and Lane(b:GetLocation())==s.home then
  Finish(b,t,s,'not_departed_original_AI');return
 end
 s.phase='return';s.returnAt=DotaTime();s.nextMove=0;s.returnGoal=GetLaneFrontLocation(b:GetTeam(),s.home,-400);Log(b,'return_started','event='..s.id..' reason='..why)
end
local function ThreatState(b,t,s,now)
 local near=false
 for _,e in ipairs(t.visible or{})do
  local id,p=Seen(e)
  if id and s.sources and s.sources[id]and(D(p,b:GetLocation())<1100
   or V(s.victim)and D(p,s.victim:GetLocation())<1100)then near=true end
 end
 local fighting=near or b:WasRecentlyDamagedByAnyHero(2)
  or V(s.victim)and s.victim:WasRecentlyDamagedByAnyHero(2)
 if fighting then return 'fighting' end
 local any,allHome=false,true
 for id in pairs(s.sources or{})do
  any=true;local h=t.history[id]
  if not h or h.lastLane~=h.home or not h.seen or now-h.seen>1 then allHome=false end
 end
 if any and allHome then return 'home' end
 return 'uncertain'
end
local function Advance(b,t,s,now)
 s.heartbeat=now
 if t.tasks[b:GetPlayerID()]~=s then Finish(b,t,s,'lease_lost_original_AI');return end
 if not V(b)then Finish(b,t,s,'death_release');return end
 if now>=Cutoff() and not(s.phase=='tp'and(b:HasModifier('modifier_teleporting')or b:IsChanneling()))then Finish(b,t,s,'cutoff_original_AI');return end
 if s.phase=='tp'then
  local channel=b:HasModifier('modifier_teleporting')or b:IsChanneling()
  if channel then s.sawChannel=true end
  if channel and b:WasRecentlyDamagedByAnyHero(.5)and b:GetHealth()/b:GetMaxHealth()<.25 then
   b._counterOwnOrder=true;b:Action_ClearActions(true);b._counterOwnOrder=nil;Finish(b,t,s,'tp_unsafe_cancel');return
  end
  if not channel and D(b:GetLocation(),s.point)<1000 and D(b:GetLocation(),s.source)>1500 then
   s.phase='approach';s.arrivedAt=now;s.departed=true;b._counterTPGuard=nil;Log(b,'tp_arrival_observed','event='..s.id)
  elseif not channel and s.sawChannel then b._counterTPGuard=nil;Finish(b,t,s,'tp_interrupted_release')
  elseif now>s.tpAt+12 or not channel and now>s.tpAt+1 and not s.sawChannel then b._counterTPGuard=nil;Finish(b,t,s,'tp_unconfirmed_release')end
  return
 end
 if Busy(b)or Fu().IsRetreating(b)or b:GetHealth()/math.max(1,b:GetMaxHealth())<.35 then
  Log(b,'handoff_detail',string.format('event=%d mode=%s hp=%.2f mana=%.0f busy=%s retreat=%s hurt=%s nearEnemies=%d',s.id,tostring(b:GetActiveMode()),b:GetHealth()/math.max(1,b:GetMaxHealth()),b:GetMana(),tostring(Busy(b)),tostring(Fu().IsRetreating(b)),tostring(b:WasRecentlyDamagedByAnyHero(2)),NearEnemies(t.visible,b:GetLocation(),1100)))
  Finish(b,t,s,'original_task_priority');return end
 local event=t.events[s.key]
 local fresh=event and event.danger and now-event.last<.8
 if s.phase=='return'then
  if Protected(b)or Fu().IsRetreating(b)or b:WasRecentlyDamagedByAnyHero(2)
   or NearEnemies(t.visible,b:GetLocation(),1100)>0 or now-s.returnAt>20
   or Home(b)~=s.home then Finish(b,t,s,'return_handoff_original_AI');return end
  local front=GetLaneFrontLocation(b:GetTeam(),s.home,-400)
  if Lane(b:GetLocation())==s.home and D(b:GetLocation(),front)<1200 then Finish(b,t,s,'home_lane_rejoined');return end
  s.returnGoal=front;return
 end
 if fresh then s.event=event;s.clearSince=nil;s.readyUncertain=nil else s.clearSince=s.clearSince or now end
 if D(b:GetLocation(),s.source)>550 then s.departed=true end
 local threat=ThreatState(b,t,s,now)
 if threat=='fighting'then s.clearSince=nil;s.homeSince=nil
 elseif threat=='home'then s.homeSince=s.homeSince or now else s.homeSince=nil end
 if not V(s.victim)then StartReturn(b,t,s,'victim_dead_no_chain_feed');return end
 if s.phase=='approach'and D(b:GetLocation(),s.victim:GetLocation())<1000 then
  s.phase='contact';s.arrivedAt=s.arrivedAt or now;Log(b,'contact_reached','event='..s.id)
 end
 if now-s.started>30 or s.phase~='ready'and(s.homeSince and now-s.homeSince>=1
  or s.clearSince and now-s.clearSince>=6)then StartReturn(b,t,s,'threat_over_or_budget');return end
 if s.phase=='approach'and(now-s.started>10 or b:WasRecentlyDamagedByAnyHero(1))then
  s.phase='contact';Log(b,'contact_original_combat','event='..s.id)
 end
end
local function Plan(b,t,event,now)
 local pending,total,departing=0,0,{}
 for pid,s in pairs(t.tasks)do
  total=total+1
  if s.phase~='return'then departing[pid]=true end
  if s.key==event.key and s.phase~='return'and s.phase~='contact'
   and not(Lane(s.owner:GetLocation())==event.lane and D(s.owner:GetLocation(),event.loc)<1150) then pending=pending+1 end
 end
 local need=event.danger.enemies-event.danger.defenders-pending
 if need<=0 and event.danger.urgent and pending==0 and event.danger.victim:GetHealth()/event.danger.victim:GetMaxHealth()<.5 then need=1 end
 if need<=0 then return end
 if need>2 or total+need>2 then Diagnose(b,t,event.key,'responder_limit_or_hopeless_numbers');return end
 local options={}
 for _,a in ipairs(Members())do if IsPlayerBot(a:GetPlayerID())and not t.tasks[a:GetPlayerID()]then
  local c=Candidate(a,event,t);if c then options[#options+1]=c end
 end end
 table.sort(options,function(a,c)if math.abs(a.score-c.score)<.01 then return a.owner:GetPlayerID()<c.owner:GetPlayerID()end;return a.score<c.score end)
 local selected
 for i=1,#options do
  local choices=need==1 and{options[i]}or nil
  for j=need==1 and i or i+1,need==1 and i or #options do
   choices=choices or{options[i],options[j]}
   local leaving={};for pid in pairs(departing)do leaving[pid]=true end
   for _,c in ipairs(choices)do leaving[c.owner:GetPlayerID()]=true end
   local legal=true;local channels=0
   for _,reserved in pairs(t.tasks)do if reserved.tp and reserved.key==event.key and now-reserved.started<25 then channels=channels+1 end end
   for _,c in ipairs(choices)do
    if not OriginSafe(c.owner,event,t,leaving)then legal=false end
    local delay=c.tp and channels*2 or 0;if c.tp then channels=channels+1 end
    local watch=t.health[event.danger.victim:GetPlayerID()]
    local life=watch and watch.loss>0 and event.danger.victim:GetHealth()/watch.loss or math.huge
    if c.eta+delay>7 or life<c.eta+delay+.8 and event.danger.victim:GetHealth()/event.danger.victim:GetMaxHealth()<.45 then legal=false end
   end
   if legal then selected=choices;break end;choices=nil
  end
  if selected then break end
 end
 if not selected then Diagnose(b,t,event.key,'no_safe_combination_source_landing_eta_mana');return end
 for _,c in ipairs(selected)do
  t.serial=t.serial+1;local owner=c.owner
  local s={id=t.serial,key=event.key,owner=owner,event=event,victim=event.danger.victim,home=Home(owner),point=c.point,
   retryKey=RetryKey(event),sources={},tower=c.tower,tp=c.tp,prepareGoal=c.prepare,eta=c.eta,phase='ready',started=now,heartbeat=now,nextMove=0,source=owner:GetLocation()}
  for id in pairs(event.sources or{})do s.sources[id]=true end
  t.tasks[owner:GetPlayerID()]=s
  Log(owner,'assigned',string.format('event=%d enemy=%d lane=%d eta=%.1f tp=%s responders=%d',s.id,event.id,event.lane,s.eta,tostring(s.tp~=nil),need))
 end
end
function X.Update(b)
 if not b or b~=GetBot()or not b:IsHero()or b:IsIllusion()then return end
 local now=DotaTime();local t=Team(b)
 if now<0 or now>=Cutoff() then
  if b._counterTask and b._counterTask.phase=='tp'and(b:HasModifier('modifier_teleporting')or b:IsChanneling())then return end
  if b._counterTask then Finish(b,t,b._counterTask,'cutoff_original_AI')end
  t.tasks[b:GetPlayerID()]=nil;b._counterYield=nil;b._counterStatus=nil;return
 end
 local ready,role,cost=Ready(b)
 b._counterStatus={at=now,ready=ready,role=role or Fu().GetPosition(b),spellCost=cost or 0,home=Home(b)}
 Scan(b,t,now);UpdateHealth(t,now)
 b._counterYield=nil
 if not b._counterTask and t.tasks[b:GetPlayerID()]then b._counterTask=t.tasks[b:GetPlayerID()]end
 if b._counterTask then Advance(b,t,b._counterTask,now);return end
 if not Own(b)then return end
 for _,event in pairs(t.events)do
  if event.danger and now-event.last<.8 and event.danger.enemies>event.danger.defenders
   and Lane(b:GetLocation())==event.lane and D(b:GetLocation(),event.loc)<1150 then
   local tower=Tower(b,event.lane,1);local behind=tower and BuildingBack(b,tower,260)
   local goal=behind and Step(b:GetLocation(),behind,550)
   if goal and D(b:GetLocation(),goal)>120 and Safe(b,goal)then b._counterYield={goal=goal,untilTime=now+.6}end
  end
 end
 for _,event in pairs(t.events)do
  if event.danger and now-event.last<.8 and now-event.first>=.35 and now>=(t.retry[RetryKey(event)]or -999)
   and(now<Cutoff()-30 or event.danger.urgent)and(now>=180 or event.danger.urgent)then
   Plan(b,t,event,now)
   if t.tasks[b:GetPlayerID()]then b._counterTask=t.tasks[b:GetPlayerID()];return end
  end
 end
end
function X.ProtectTP(b)
 local guard=b and b._counterTPGuard
 if not guard then return false end
 if not V(b)or DotaTime()>guard.deadline then b._counterTPGuard=nil;return false end
 if DotaTime()-guard.at<.75 or b:HasModifier('modifier_teleporting')or b:IsChanneling()then return true end
 b._counterTPGuard=nil;return false
end
function X.BlockOrder(b,action)
 return b==GetBot()and not b._counterOwnOrder and X.ProtectTP(b)
end
function X.OwnsMovement(b)
 local s=b and b._counterTask;return s and(s.phase=='ready'or s.phase=='tp'or s.phase=='approach'or s.phase=='return')or false
end
function X.ContactActive(b)
 local s=b and b._counterTask
 return s and s.phase=='contact'and DotaTime()<Cutoff() and V(b)and V(s.victim)
  and not Fu().IsRetreating(b)and not Busy(b)and b:GetHealth()/math.max(1,b:GetMaxHealth())>=.35
  and DotaTime()-s.started<=30 and D(b:GetLocation(),s.victim:GetLocation())<1400
  and not(s.clearSince and DotaTime()-s.clearSince>=6)or false
end
function X.GetDesire(b)
 X.Update(b)
 if Protected(b)then return 0 end
 local s=b._counterTask
 if s and(s.phase=='ready'or s.phase=='approach'or s.phase=='return')then return .84 end
 if b._counterYield and not Fu().IsRetreating(b)then return .83 end
 return 0
end
local function Move(b,s,p)
 if DotaTime()<(b._counterMoveNext or 0)then return true end
 if not p or not Safe(b,p)then return false end
 s.nextMove=DotaTime()+.5;b._counterMoveNext=s.nextMove;s.lastMove=p;s.moveAt=DotaTime()
 b._counterOwnOrder=true;b:Action_MoveToLocation(p);b._counterOwnOrder=nil;return true
end
function X.Think(b)
 X.Update(b);if X.ProtectTP(b)then return true end
 if Protected(b)then return false end
 local s=b._counterTask
 if not s then local y=b._counterYield;if y and not Fu().IsRetreating(b)then return Move(b,y,y.goal)end;return false end
 if s.phase=='ready'then
  local ev=Team(b).events[s.key]
  if not ev or not ev.danger or DotaTime()-ev.last>.8 then
   s.readyUncertain=s.readyUncertain or DotaTime()
   if DotaTime()-s.readyUncertain>=.9 then StartReturn(b,Team(b),s,'changed_before_departure')end
   return false
  end
  s.event=ev;s.readyUncertain=nil
  local pending,leaving=0,{}
  for pid,task in pairs(Team(b).tasks)do
   if task.phase~='return'then leaving[pid]=true end
   local viable=true
   if task.owner~=b and task.phase=='ready'then
    local partner=task.owner;local spells,cost=0,0
    if V(partner)then spells,cost=SpellBudget(partner)end
    viable=V(partner)and not Protected(partner)and not Busy(partner)and not Fu().IsRetreating(partner)
     and partner:GetHealth()/math.max(1,partner:GetMaxHealth())>=.55 and spells>0
    if task.tp then
     local item=partner:GetItemInSlot(15)
     viable=viable and not partner:IsMuted()and item and item:GetName()=='item_tpscroll'and item:IsFullyCastable()
      and partner:GetMana()>=item:GetManaCost()+cost and SourceSafe(partner,Team(b),partner:GetLocation())
    end
   end
   if viable and task.key==s.key and task.phase~='return'and task.phase~='contact'
    and not(Lane(task.owner:GetLocation())==ev.lane and D(task.owner:GetLocation(),ev.loc)<1150)then pending=pending+1 end
  end
  if not V(s.victim)or ev.danger.enemies>ev.danger.defenders+pending
   or not OriginSafe(b,ev,Team(b),leaving)then Finish(b,Team(b),s,'departure_threat_changed');return false end
  if s.tp then
   if not SourceSafe(b,Team(b),b:GetLocation())then
    if s.prepareGoal and D(b:GetLocation(),s.prepareGoal)>100 and DotaTime()-s.started<4 then
     if not s.prepareLogged then s.prepareLogged=true;Log(b,'source_reposition','event='..s.id)end
     if not Move(b,s,s.prepareGoal)then Finish(b,Team(b),s,'unsafe_departure_release')end
     return true
    end
    Finish(b,Team(b),s,'source_interrupt_risk_release');return false
   end
   -- Plans carry intent only. The executing hero must reacquire its own live item.
   local tp=b:GetItemInSlot(15)
   local _,spellCost=SpellBudget(b)
   if b:IsMuted()or not tp or tp:GetName()~='item_tpscroll'or not tp:IsFullyCastable()
    or b:GetMana()<tp:GetManaCost()+spellCost or not V(s.tower)
    or D(s.point,s.victim:GetLocation())>1500 or NearEnemies(Team(b).visible,s.point,650)>0 then Finish(b,Team(b),s,'departure_invalid');return false end
   s.phase='tp';s.tpAt=DotaTime();b._counterTPGuard={at=s.tpAt,deadline=s.tpAt+12}
   b._counterOwnOrder=true;b:Action_UseAbilityOnLocation(tp,s.point);b._counterOwnOrder=nil;Log(b,'tp_order','event='..s.id);return true
  end
  s.phase='approach'
 end
 if s.phase=='approach'then
  if not V(s.victim)then return false end
  local goal=Step(b:GetLocation(),s.victim:GetLocation(),550)
  if not Move(b,s,goal)and DotaTime()>=(s.nextMove or 0)then Finish(b,Team(b),s,'unsafe_approach_original_AI')end
  return true
 end
 if s.phase=='return'then
  local p=s.returnGoal and Step(b:GetLocation(),s.returnGoal,550)
  if not Move(b,s,p)and DotaTime()>=(s.nextMove or 0)then Finish(b,Team(b),s,'unsafe_return_original_AI')end
  return true
 end
 return false
end
function X.OrderGoal(b,action)
 if b~=GetBot()or DotaTime()>=Cutoff() or b._counterOwnOrder or Protected(b)or Fu().IsRetreating(b)then return nil end
 local y=b._counterYield
 if y and DotaTime()<y.untilTime and(action:find('Move',1,true)or action:find('Attack',1,true))and Safe(b,y.goal)then return y.goal end
end
for name,fallback in pairs({Update=false,GetDesire=0,Think=false})do
 local raw=X[name];X[name]=function(b,...)
  local ok,result=pcall(raw,b,...);if ok then return result end
  if b then
   b._counterOwnOrder=nil
   if DotaTime()>=(b._counterErrorNext or -999)then b._counterErrorNext=DotaTime()+10;Log(b,'error','function='..name..' error='..tostring(result))end
   if b._counterTask then Finish(b,Team(b),b._counterTask,'error_release')end
  end
  return fallback
 end
end
return X
