-- Turbo-first outpost tasks. Other combat/push/defence implementations untouched.
local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
local Path=require(GetScriptDirectory()..'/FuncLib/systems/shrine_path')
local X={}
local teams={}
local FIRST_LIMIT,RETRY_LIMIT,COOLDOWN,NEAR=90,30,60,2400
local RETRY_WALL_LIMIT=90 -- nearby retries: 30 seconds executing, 90 seconds total
local FIRST_WALL_LIMIT=90 -- combat pauses do not consume the 90-second execution allowance
local FOLLOWUP_WINDOW,FOLLOWUP_LIMIT,FOLLOWUP_ATTEMPTS=180,75,2
local function Valid(u) return u~=nil and not u:IsNull() end
local function Eligible(b)
    return Valid(b) and b:IsHero() and not b:IsIllusion() and not b.isBear
        and IsPlayerBot(b:GetPlayerID())
        and not b:HasModifier('modifier_arc_warden_tempest_double')
        and not b:HasModifier('modifier_meepo_divided_we_stand')
        and (not Fu.IsMeepoClone or not Fu.IsMeepoClone(b))
end
local function Center(side)
    -- Installed 7.41f map: South=Radiant original side, North=Dire original side.
    if side==TEAM_RADIANT then return Vector(-4096,-447.999298,256) end
    return Vector(3392,-448.000702,256)
end
local function Enemy(team) return team==TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT end
local function Trace(b,s,phase)
    if s.phase==phase then return end
    s.phase=phase
    local p=b:GetLocation()
    print(string.format('[OUTPOST_TASK] t=%.1f team=%d pid=%d kind=%s side=%s phase=%s pos=(%.0f,%.0f) mode=%s',
        DotaTime(),b:GetTeam(),b:GetPlayerID(),tostring(s.kind),tostring(s.side),phase,p.x,p.y,tostring(b:GetActiveMode())))
end
local function Roster(bot)
    local list,seen={},{}
    local function Add(b)
        if Eligible(b) and b:GetTeam()==bot:GetTeam() and not seen[b:GetPlayerID()] then
            seen[b:GetPlayerID()]=true;list[#list+1]=b
        end
    end
    for i=1,5 do Add(GetTeamMember(i)) end
    for _,b in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do Add(b) end
    Add(bot)
    table.sort(list,function(a,b) return a:GetPlayerID()<b:GetPlayerID() end)
    return list
end
local function StopOwn(bot,s)
    if s.issued and bot:IsAlive() and bot:GetActiveMode()==BOT_MODE_OUTPOST then
        bot:Action_ClearActions(true)
    end
    s.issued=false
end
local function ResetPath(s)
    s.path,s.job,s.index,s.progress,s.progressAt=nil,nil,nil,nil,nil
    s.step=96
end
local function Finish(bot,s,reason)
    StopOwn(bot,s);s.active=false;s.workRunning=false;ResetPath(s);Path.ResetNavigation(s)
    if bot:IsAlive() and reason~='death' then
        bot._objectiveReturn={untilTime=DotaTime()+8,source='outpost'}
    end
    local cooldown=s.kind=='retry' and s.side==bot:GetTeam() and reason~='owned_original_AI' and 20 or COOLDOWN
    s.nextTry=DotaTime()+cooldown
    Trace(bot,s,reason)
    local team=teams[bot:GetTeam()]
    if team and team.retry and team.retry.pid==bot:GetPlayerID() then
        team.retry=nil;team.nextRetry=DotaTime()+cooldown
    end
end
local function VisibleEnemy(bot)
    for _,e in pairs(bot:GetNearbyHeroes(1100,true,BOT_MODE_NONE) or {}) do
        if Valid(e) and e:IsAlive() and e:IsHero() and e:CanBeSeen()
            and e:GetTeam()~=bot:GetTeam() then return true end
    end
    return bot:WasRecentlyDamagedByAnyHero(3)
end
local formationCache={}
local function FormedPush(bot)
    local now=DotaTime();local team=bot:GetTeam();local c=formationCache[team]
    if c and now<c.next then return c.active end
    c={next=now+0.5,active=false};formationCache[team]=c
    local candidates,seen={},{}
    for _,ally in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
        if Valid(ally) and ally:IsAlive() and ally:IsHero() and not ally:IsIllusion()
            and ally:GetTeam()==team and not ally.isBear and not seen[ally:GetPlayerID()]
            and not ally:HasModifier('modifier_arc_warden_tempest_double')
            and not ally:HasModifier('modifier_meepo_divided_we_stand') then
            seen[ally:GetPlayerID()]=true
            local mode=ally:GetActiveMode()
            if Fu.IsPushing(ally) or mode==BOT_MODE_ATTACK or mode==BOT_MODE_ASSEMBLE or mode==BOT_MODE_TEAM_ROAM then
                candidates[#candidates+1]=ally
            end
        end
    end
    for _,anchor in ipairs(candidates) do
        local n=0;for _,ally in ipairs(candidates) do
            if Path.Distance(anchor:GetLocation(),ally:GetLocation())<1800 then n=n+1 end
        end
        if n>=3 then c.active=true;break end
    end
    return c.active
end
-- A first capture may use a naturally nearby, quiet group; never peel a lone
-- hero off a remote formed push. One bounded opportunity per first round.
local function NearbyGroupWindow(bot,first)
    if not first then return false end
    local t=teams[bot:GetTeam()];local f=t and t.first;local now=DotaTime()
    if not f or f.finished or now>=f.untilTime or f.captureWindowDone then return false end
    if require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(bot) then return false end
    local center=Center(Enemy(bot:GetTeam()))
    if Path.Distance(bot:GetLocation(),center)>1800 then return false end
    if f.captureWindowUntil then
        if now>=f.captureWindowUntil then f.captureWindowDone=true;return false end
        return true
    end
    local n=0
    for _,a in ipairs(Roster(bot)) do
        if a:IsAlive() and Path.Distance(a:GetLocation(),center)<=1800 then
            local target=a:GetAttackTarget()
            if VisibleEnemy(a) or Fu.IsRetreating(a) or Fu.IsDefending(a)
                or Fu.IsDoingRoshan(a) or Fu.IsDoingTormentor(a)
                or Valid(target) and target:IsAlive() and (target:IsHero() or target:IsBuilding()) then return false end
            if Fu.GetHP(a)>=0.65 then n=n+1 end
        end
    end
    if n<3 then return false end
    f.captureWindowUntil=now+18
    print(string.format('[OUTPOST_TASK] t=%.1f team=%d phase=nearby_group_capture_window members=%d deadline=%.1f',now,bot:GetTeam(),n,f.captureWindowUntil))
    return true
end
local function Busy(bot,first,assigned,side)
    if not bot:IsAlive() or bot:IsInvulnerable() then return 'unavailable' end
    if bot:IsChanneling() and bot:GetActiveMode()~=BOT_MODE_OUTPOST then return 'other_channel' end
    if VisibleEnemy(bot) then return 'combat' end
    local target=bot:GetAttackTarget()
    local distance=math.huge
    local sides=side and {side} or first and {Enemy(bot:GetTeam())} or {bot:GetTeam(),Enemy(bot:GetTeam())}
    for _,point in ipairs(sides) do distance=math.min(distance,Path.Distance(bot:GetLocation(),Center(point))) end
    -- A safe nearby individual may channel while the rest keep their push.
    -- Never interrupt an actual building/hero attack merely because it is nearby.
    local localOpportunity=distance<=900 and Fu.GetHP(bot)>=0.65
        and not (Valid(target) and target:IsAlive() and (target:IsHero() or target:IsBuilding()))
    local home=teams[bot:GetTeam()]
    if side==bot:GetTeam() and home and home.homeLostAt and DotaTime()-home.homeLostAt>=30
        and distance<=1800 and Fu.GetHP(bot)>=0.65 and not Fu.IsAttacking(bot)
        and not (Valid(target) and target:IsAlive() and (target:IsHero() or target:IsBuilding())) then localOpportunity=true end
    if FormedPush(bot) and not localOpportunity and not NearbyGroupWindow(bot,first) then return 'formed_push' end
    if require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(bot) then return 'base_under_attack' end
    if Fu.GetHP(bot)<(first and 0.5 or 0.65) then return 'low_health' end
    if Fu.IsRetreating(bot) or Fu.IsDefending(bot)
        or bot:GetActiveMode()==BOT_MODE_DEFEND_ALLY then return 'defence_or_retreat' end
    if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then return 'major_objective' end
    if not first and not assigned and not localOpportunity and (bot:GetActiveMode()==BOT_MODE_ROAM or (BOT_MODE_GANK and bot:GetActiveMode()==BOT_MODE_GANK)) then
        return 'gank'
    end
    local target=bot:GetAttackTarget()
    local heroTarget=Fu.GetProperTarget(bot)
    if Fu.IsGoingOnSomeone(bot) and Valid(heroTarget) and heroTarget:IsHero()
        and heroTarget:IsAlive() and heroTarget:CanBeSeen()
        and Path.Distance(bot:GetLocation(),heroTarget:GetLocation())<1600 then return 'gank_target' end
    if bot:GetActiveMode()==BOT_MODE_ATTACK and Valid(target) and target:IsHero() then return 'attack' end
    if Fu.IsPushing(bot) then
        -- First round may leave a quiet push mode, never an actual tower attack.
        if not localOpportunity and ((not first or not NearbyGroupWindow(bot,first))
            or (Fu.IsAttacking(bot) and Valid(target) and target:IsBuilding())) then return 'push' end
    end
    if Fu.GetEnemiesAroundAncient(bot,3200)>0 then return 'base_defence' end
    -- Keep the already accepted Lotus/Wisdom schedules intact.
    local lotus,wisdom=bot._earlyLotus,bot._wisdomOnce
    if (lotus and lotus.active) or (wisdom and wisdom.active) then return 'scheduled_objective' end
    return nil
end
local function Scan(team)
    local found={}
    local lists={UNIT_LIST_ALL}
    if UNIT_LIST_ALLIED_BUILDINGS then lists[#lists+1]=UNIT_LIST_ALLIED_BUILDINGS end
    if UNIT_LIST_ENEMY_BUILDINGS then lists[#lists+1]=UNIT_LIST_ENEMY_BUILDINGS end
    for _,kind in ipairs(lists) do
        for _,u in pairs(GetUnitList(kind) or {}) do
            if Valid(u) and not u:IsHero() then
                local name=string.lower(u:GetUnitName() or '')
                if string.find(name,'outpost',1,true) or string.find(name,'watch_tower',1,true) then
                    local p=u:GetLocation()
                    if p then
                        for _,side in ipairs({TEAM_RADIANT,TEAM_DIRE}) do
                            if Path.Distance(p,Center(side))<900 then found[side]=u end
                        end
                    end
                end
            end
        end
    end
    for side,u in pairs(found) do
        team.posts[side]=u
        local owner=u:GetTeam();team.observedOwners=team.observedOwners or {}
        if side==team.id then
            if owner==team.id then team.homeLostAt=nil
            else team.homeLostAt=team.homeLostAt or DotaTime() end
        end
        if team.observedOwners[side]~=owner then
            team.observedOwners[side]=owner
            print(string.format('[OUTPOST_OWNER] t=%.2f team=%d original_side=%d owner=%d',DotaTime(),team.id,side,owner))
        end
    end
end
local function Owned(team,side) local u=team.posts[side];return Valid(u) and u:GetTeam()==team.id end
local function Ready(team,side)
    local u=team.posts[side]
    return Valid(u) and u:GetTeam()~=team.id and not u:IsInvulnerable()
end
local function Tier2Down(team)
    for _,id in ipairs({TOWER_TOP_2,TOWER_MID_2,TOWER_BOT_2}) do
        local t=GetTower(Enemy(team.id),id)
        if not Valid(t) or not t:IsAlive() then return true end
    end
    return false
end
local function Reinforce(bot,team,now)
    local first=team.first
    if not first or first.success or Owned(team,Enemy(team.id)) or now>=first.untilTime or team.retry or now<(team.nextReinforce or 0) then return end
    team.nextReinforce=now+3
    local candidate,cost
    for _,ally in ipairs(Roster(bot)) do
        local pid=ally:GetPlayerID();local state=ally._outpostTask
        local distance=Path.Distance(ally:GetLocation(),Center(Enemy(team.id)))
        if first.members[pid]==nil and (not state or (not state.firstJoined and not state.active))
            and ally:IsAlive() and Fu.GetHP(ally)>=0.65 and ally:GetActiveMode()~=BOT_MODE_RETREAT
            and distance<=4500 and not Busy(ally,true,true)
            and Path.SafePoint(ally:GetLocation(),Path.Towers(ally))
            and distance*1.35/(ally.GetCurrentMovementSpeed and math.max(200,ally:GetCurrentMovementSpeed()) or 300)+8<=first.untilTime-now
            and (not cost or distance<cost) then candidate,cost=ally,distance end
    end
    if candidate then
        first.members[candidate:GetPlayerID()]=GetHeroDeaths(candidate:GetPlayerID())
        first.finished=false
        print(string.format('[OUTPOST_TASK] t=%.1f team=%d phase=first_reinforcement pid=%d distance=%.0f',now,team.id,candidate:GetPlayerID(),cost))
    end
end
local function Team(bot)
    local id=bot:GetTeam()
    if not teams[id] then teams[id]={id=id,posts={},nextScan=0,nextRetry=0} end
    local team=teams[id];local now=DotaTime()
    if now>=team.nextScan then
        team.nextScan=now+0.5
        Scan(team)
        if team.retry then
            local r=team.retry
            if now>=r.deadline or GetHeroDeaths(r.pid)>r.deaths
                or (IsHeroAlive and not IsHeroAlive(r.pid)) or Owned(team,r.side) then
                team.retry=nil;team.nextRetry=now+COOLDOWN
            end
        end
        local down=0
        for _,towerID in ipairs({TOWER_TOP_2,TOWER_MID_2,TOWER_BOT_2}) do
            local tower=GetTower(Enemy(id),towerID)
            if not Valid(tower) or not tower:IsAlive() then down=down+1 end
        end
        if down>(team.downCount or 0) then team.latestT2Time=now;team.nextReinforce=0 end
        team.downCount=down
        if not team.first and Tier2Down(team) then
            team.first={started=now,untilTime=now+FIRST_WALL_LIMIT,members={},finished=false,success=false,
                followupUntil=now+FIRST_WALL_LIMIT+FOLLOWUP_WINDOW,attempts=0}
            for _,ally in ipairs(Roster(bot)) do
                if ally:IsAlive() then team.first.members[ally:GetPlayerID()]=GetHeroDeaths(ally:GetPlayerID()) end
            end
            print(string.format('[OUTPOST_TASK] team=%d first_round t=%.1f deadline=%.1f',id,now,now+FIRST_WALL_LIMIT))
        end
        Reinforce(bot,team,now)
        local allDone=false
        if team.first and not team.first.finished and now>team.first.started+0.5 then
            allDone=true
            for _,ally in ipairs(Roster(bot)) do
                local deaths=team.first.members[ally:GetPlayerID()]
                local state=ally._outpostTask
                if deaths~=nil and ally:IsAlive() and GetHeroDeaths(ally:GetPlayerID())==deaths
                    and (not state or not state.firstJoined or (state.active and state.kind=='first')) then
                    allDone=false;break
                end
            end
        end
        if team.first and not team.first.finished
            and (Owned(team,Enemy(id)) or now>=team.first.untilTime or allDone) then
            team.first.success=Owned(team,Enemy(id))
            team.first.followupUntil=now+FOLLOWUP_WINDOW
            team.first.finished=true;team.nextRetry=now+(team.first.success and COOLDOWN or 10)
        end
    end
    return team
end
local function Start(bot,s,kind,side,deadline,deaths)
    s.active,s.kind,s.side,s.deadline,s.deaths=true,kind,side,deadline,deaths
    s.workLeft=kind=='first' and FIRST_LIMIT or kind=='retry' and RETRY_LIMIT or nil;s.workAt=DotaTime();s.workRunning=false
    if kind=='first' then s.firstJoined=true end
    s.assignedDistance=Path.Distance(bot:GetLocation(),Center(side))
    s.blocked={};s.nextOrder=0;s.nextPlan=0;s.nextCast=0;s.failures=0
    s.unit=nil;s.goals=nil;s.lastLocation=nil;s.awaitUntil=nil;s.nearbyWindowLogged=false
    ResetPath(s);Path.ResetNavigation(s);Trace(bot,s,'assigned')
end
local function PickRetry(bot,team)
    local now=DotaTime()
    -- Before broad elections, allow one already close hero a short capture.
    -- Never cancel a remote first mission or an actual fight/building attack.
    if (not team.retry or now>=team.retry.deadline)
        and now>=(bot._outpostLocalNext or 0) then
        bot._outpostLocalNext=now+0.5
        for _,side in ipairs({team.id,Enemy(team.id)}) do
            local post=team.posts[side]
            local distance=Path.Distance(bot:GetLocation(),Center(side))
            local state=bot._outpostTask
            if Ready(team,side) and post:CanBeSeen() and distance<=700
                and (not state or not state.active and now>=(state.nextLocalTry or 0))
                and not Busy(bot,false,true,side)
                and Path.SafePoint(bot:GetLocation(),Path.Towers(bot)) then
                team.retry={pid=bot:GetPlayerID(),side=side,kind='nearby',deadline=now+14,
                    deaths=GetHeroDeaths(bot:GetPlayerID())}
                if state then state.nextLocalTry=now+20 end
                print(string.format('[OUTPOST_TASK] t=%.1f team=%d pid=%d phase=nearby_opportunity distance=%.0f',now,team.id,bot:GetPlayerID(),distance))
                return
            end
        end
    end
    if team.retry or now<team.nextRetry or (team.first and not team.first.finished) then return end
    local first=team.first
    if first and not first.success and Owned(team,Enemy(team.id)) then first.success=true end
    if first and not first.success and now<first.followupUntil and first.attempts<FOLLOWUP_ATTEMPTS then
        local candidate,cost
        for _,ally in ipairs(Roster(bot)) do
            local state=ally._outpostTask
            local distance=Path.Distance(ally:GetLocation(),Center(Enemy(team.id)))
            if distance<=NEAR and ally:IsAlive() and not Busy(ally,false,true)
                and (not state or (not state.active and now>=(state.nextTry or 0)))
                and Path.SafePoint(ally:GetLocation(),Path.Towers(ally))
                and math.min(FOLLOWUP_LIMIT,first.followupUntil-now)>=30
                and distance*1.35/(ally.GetCurrentMovementSpeed and math.max(200,ally:GetCurrentMovementSpeed()) or 300)+8
                    <=math.min(FOLLOWUP_LIMIT,first.followupUntil-now)
                and (not cost or distance<cost) then candidate,cost=ally,distance end
        end
        team.nextRetry=now+3
        if candidate then
            first.attempts=first.attempts+1
            team.retry={pid=candidate:GetPlayerID(),side=Enemy(team.id),
                kind='followup',deadline=math.min(now+FOLLOWUP_LIMIT,first.followupUntil),
                deaths=GetHeroDeaths(candidate:GetPlayerID())}
            print(string.format('[OUTPOST_RETRY] t=%.1f team=%d first_incomplete_followup pid=%d attempt=%d distance=%.0f',now,team.id,candidate:GetPlayerID(),first.attempts,cost))
            return
        end
    end
    team.nextRetry=now+1 -- no all-roster election more than once per second
    local zones=Path.Towers(bot)
    local rejected={}
    -- Home outpost first; original map side remains fixed after ownership changes.
    for _,side in ipairs({team.id,Enemy(team.id)}) do
        if Ready(team,side) then
            local candidate,cost
            local radius=NEAR
            if side==team.id and team.homeLostAt then
                local age=now-team.homeLostAt
                radius=age>=90 and 4500 or age>=30 and 3600 or NEAR
            end
            for _,ally in ipairs(Roster(bot)) do
                local s=ally._outpostTask
                local distance=Path.Distance(ally:GetLocation(),Center(side))
                local busy=Busy(ally,false,false,side)
                local eta=distance*1.35/(ally.GetCurrentMovementSpeed and math.max(200,ally:GetCurrentMovementSpeed()) or 300)
                local reason=not ally:IsAlive() and 'dead' or distance>radius and 'far' or eta>20 and 'travel_time' or busy
                if reason then rejected[reason]=(rejected[reason] or 0)+1 end
                if ally:IsAlive() and distance<=radius and eta<=20 and not busy
                    and (not s or (not s.active and now>=(s.nextTry or 0)))
                    and Path.SafePoint(ally:GetLocation(),zones)
                    and (cost==nil or eta<cost) then candidate,cost=ally,eta end
            end
            if candidate then
                team.retry={pid=candidate:GetPlayerID(),side=side,deadline=now+RETRY_WALL_LIMIT,
                    deaths=GetHeroDeaths(candidate:GetPlayerID())}
                return
            end
        end
    end
    if next(rejected) and now>=(team.nextDiag or 0) then
        team.nextDiag=now+10
        local summary={}
        for reason,count in pairs(rejected) do summary[#summary+1]=reason..':'..count end
        table.sort(summary)
        print(string.format('[OUTPOST_RETRY] t=%.1f team=%d no_candidate %s',now,team.id,table.concat(summary,',')))
    end
end
function X.Update(bot)
    if not Eligible(bot) or DotaTime()<0 then return nil end
    local s=bot._outpostTask
    if not s then s={active=false,firstConsidered=false,nextTry=0};bot._outpostTask=s end
    local team=Team(bot);local now=DotaTime()
    if not s.firstJoined and team.first then
        s.firstConsidered=true
        local deaths=team.first.members[bot:GetPlayerID()]
        if not team.first.finished and deaths~=nil and bot:IsAlive() and GetHeroDeaths(bot:GetPlayerID())==deaths then
            Start(bot,s,'first',Enemy(team.id),team.first.untilTime,deaths)
        end
    end
    -- A pending distant first task must not make a hero walk past its own
    -- lost outpost. Switch only before this hero has issued travel/capture,
    -- with no combat/defence obligation; the other first-task members remain.
    local home=team.posts[team.id]
    if s.active and s.kind=='first' and s.side~=team.id and not s.issued and not s.casting
        and not team.retry and Ready(team,team.id) and home:CanBeSeen()
        and Path.Distance(bot:GetLocation(),Center(team.id))<=700
        and now>=(s.nextLocalTry or 0) and Fu.GetHP(bot)>=0.65
        and not Busy(bot,false,true,team.id) and Path.SafePoint(bot:GetLocation(),Path.Towers(bot)) then
        s.nextLocalTry=now+20
        team.retry={pid=bot:GetPlayerID(),side=team.id,kind='nearby',deadline=now+14,deaths=GetHeroDeaths(bot:GetPlayerID())}
        Start(bot,s,'nearby',team.id,now+14,GetHeroDeaths(bot:GetPlayerID()))
        Trace(bot,s,'nearby_home_before_distant_task')
    end
    if s.active then
        if s.workLeft then
            local elapsed=math.max(0,now-(s.workAt or now))
            if s.workRunning and bot:GetActiveMode()==BOT_MODE_OUTPOST and not Busy(bot,s.kind=='first',true) then
                s.workLeft=s.workLeft-elapsed
            end
            s.workAt=now
        end
        if not bot:IsAlive() or GetHeroDeaths(bot:GetPlayerID())>s.deaths then Finish(bot,s,'death')
        elseif Owned(team,s.side) then
            if team.first and s.side==Enemy(team.id) then team.first.success=true;team.first.finished=true;team.nextRetry=now+COOLDOWN end
            Finish(bot,s,'owned_original_AI')
        elseif s.kind=='first' and s.assignedDistance<=4500 and Path.Distance(bot:GetLocation(),Center(s.side))>6000 then Finish(bot,s,'displaced_original_AI')
        elseif s.kind=='retry' and Path.Distance(bot:GetLocation(),Center(s.side))>NEAR*2 then Finish(bot,s,'displaced_original_AI')
        elseif s.workLeft and s.workLeft<=0 then Finish(bot,s,'execution_budget_original_AI')
        elseif now>=s.deadline then Finish(bot,s,'timeout_original_AI') end
    end
    if not s.active and bot:IsAlive() then
        PickRetry(bot,team)
        local retry=team.retry
        if retry and retry.pid==bot:GetPlayerID() and now<retry.deadline
            and GetHeroDeaths(bot:GetPlayerID())==retry.deaths then
            Start(bot,s,retry.kind or 'retry',retry.side,retry.deadline,retry.deaths)
        end
    end
    return s,team
end
local function Goals(bot,center)
    local goals,zones={},Path.Towers(bot)
    for _,radius in ipairs({180,240}) do
        for i=0,11 do
            local a=i*math.pi/6;local p=Vector(center.x+math.cos(a)*radius,center.y+math.sin(a)*radius,center.z)
            if Path.SafePoint(p,zones) then goals[#goals+1]=p end
        end
    end
    return goals
end
function X.GetDesire(bot)
    local s,team=X.Update(bot)
    if not s or not s.active then return 0 end
    if s.kind=='first' and team.first.finished then Finish(bot,s,'first_round_finished');return 0 end
    s.workRunning=false
    local reason=Busy(bot,s.kind=='first',true,s.side)
    if reason then
        StopOwn(bot,s)
        s.casting=false;s.progress,s.progressAt=nil,nil;Path.Pause(s,true)
        if s.kind~='first' and (reason=='defence_or_retreat' or reason=='base_defence' or reason=='unavailable') then
            Finish(bot,s,'yield_'..reason)
        else Trace(bot,s,'pause_'..reason) end
        return 0
    end
    if not Path.OutsideTowers(bot:GetLocation(),Path.Towers(bot)) then
        StopOwn(bot,s)
        Path.Pause(s);Trace(bot,s,'pause_tower')
        return 0
    end
    local u=team.posts[s.side]
    if Valid(u) and u:CanBeSeen() and u:IsInvulnerable() then
        StopOwn(bot,s)
        if s.kind~='first' then Finish(bot,s,'locked') else Trace(bot,s,'pause_locked') end
        return 0
    end
    local center=Valid(u) and u:GetLocation() or Center(s.side)
    if Path.Distance(bot:GetLocation(),center)>260 then
        s.goals=s.goals or Goals(bot,center)
        if not Path.Prepare(bot,s,center,center.x<0 and LANE_BOT or LANE_TOP,s.goals) then
            StopOwn(bot,s);Trace(bot,s,'planning_original_AI')
            if (s.navFailures or 0)>=6 then Finish(bot,s,'route_failed_original_AI') end
            return 0
        end
    end
    s.workRunning=true -- charged only while OUTPOST is the actual active mode
    -- Existing combat/defence modes retain priority; no global desire changes.
    if bot:IsChanneling() and s.casting then return 0.9 end
    if Path.Distance(bot:GetLocation(),center)<=700 and Fu.GetHP(bot)>=0.65
        and Valid(u) and u:CanBeSeen() and Ready(team,s.side) then
        if not s.nearbyWindowLogged then s.nearbyWindowLogged=true;Trace(bot,s,'nearby_capture_window') end
        return 0.82
    end
    if s.kind=='first' then
        if NearbyGroupWindow(bot,true) then return 0.96 end
        if team.latestT2Time and DotaTime()-team.latestT2Time<=25
            and Fu.GetHP(bot)>=0.65 and Path.Distance(bot:GetLocation(),Center(s.side))<=3500 then
            local ours,theirs=0,0
            for _,pid in ipairs(GetTeamPlayers(team.id)) do if IsHeroAlive(pid) then ours=ours+1 end end
            for _,pid in ipairs(GetTeamPlayers(Enemy(team.id))) do if IsHeroAlive(pid) then theirs=theirs+1 end end
            if ours>=theirs+2 then Trace(bot,s,'advantage_capture_window');return 0.78 end
        end
        return 0.72
    end
    if s.kind=='followup' then return 0.66 end
    local distance=Path.Distance(bot:GetLocation(),Center(s.side))
    if s.kind=='nearby' then return 0.78 end
    return 0.4+0.24*math.max(0,1-distance/NEAR)
end
local function Walk(bot,s,center)
    if Path.Move(bot,s) then s.issued=true;s.workRunning=true;Trace(bot,s,'walking')
    else StopOwn(bot,s);Trace(bot,s,'route_retry_original_AI') end
end
function X.Think(bot)
    if X.GetDesire(bot)==0 then return end
    local s=bot._outpostTask;local team=teams[bot:GetTeam()]
    if bot:IsChanneling() then s.workRunning=s.casting;return end -- never reissue and restart capture
    if bot:IsUsingAbility() or bot:IsCastingAbility() or bot:IsStunned() or bot:IsRooted() then return end
    local unit=team.posts[s.side];local center=Valid(unit) and unit:GetLocation() or Center(s.side)
    if Path.Distance(bot:GetLocation(),center)>260 then s.casting=false;Walk(bot,s,center);return end
    if not Valid(unit) or not unit:CanBeSeen() then
        s.awaitUntil=s.awaitUntil or DotaTime()+3
        if DotaTime()>=s.awaitUntil then Finish(bot,s,'unit_not_exposed') end
        return
    end
    if unit:GetTeam()==bot:GetTeam() then Finish(bot,s,'owned_original_AI');return end
    if unit:IsInvulnerable() then return end
    if not Path.SafePoint(bot:GetLocation(),Path.Towers(bot)) then Finish(bot,s,'unsafe_entry');return end
    if DotaTime()<s.nextCast then return end
    local ability=bot:GetAbilityByName('ability_capture')
    if ability==nil or not ability:IsFullyCastable() then
        s.awaitUntil=s.awaitUntil or DotaTime()+3
        if DotaTime()>=s.awaitUntil then Finish(bot,s,'capture_unavailable') end
        return
    end
    bot:Action_UseAbilityOnEntity(ability,unit)
    s.issued,s.casting=true,true;s.workRunning=true;s.nextCast=DotaTime()+1
    Trace(bot,s,'channel_capture')
end
function X.OnEnd(bot)
    local s=bot._outpostTask
    if not s or not s.active then return end
    StopOwn(bot,s)
    s.casting=false;s.workRunning=false
    s.progress,s.progressAt=nil,nil;Path.Pause(s)
    -- Preserve the search during an unchanged pause, rebuild only after displacement.
    -- A short combat/push interruption keeps the existing bounded reservation.
    -- Emergency defence/death/deadline are handled by GetDesire/Update.
end
return X
