-- One nearby opportunity per team at 7:00. Never rotate substitutes.
-- Lightweight allocation; full safe pathfinding runs only for selected bots.
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')
local Path = require(GetScriptDirectory()..'/FuncLib/systems/shrine_path')
local X = {}
local START, LIMIT, EMPTY_WAIT, DESIRE = 420, 30, 1, 0.92
local plans = {}
local diagnostics = {}
local function Valid(u) return u ~= nil and not u:IsNull() end
local function Eligible(b)
    return Valid(b) and b:IsHero() and not b:IsIllusion() and not b.isBear
        and IsPlayerBot(b:GetPlayerID())
        and not b:HasModifier('modifier_arc_warden_tempest_double')
        and not b:HasModifier('modifier_meepo_divided_we_stand')
        and (not Fu.IsMeepoClone or not Fu.IsMeepoClone(b))
end
local function Center(lane)
    -- Installed 7.41f map entities; deliberately usable without shrine vision.
    if lane == LANE_TOP then return Vector(-8088,768,38.955624) end
    return Vector(8167.431641,-1142.111816,37.803406)
end
local function CapturePoints(bot,center)
    local points,zones={},Path.Towers(bot)
    for _,radius in ipairs({160,208,240}) do
        for index=0,23 do
            local a=index*math.pi/12
            local p=Vector(center.x+math.cos(a)*radius,center.y+math.sin(a)*radius,center.z)
            if Path.SafePoint(p,zones) then points[#points+1]=p end
        end
    end
    local location=bot:GetLocation()
    table.sort(points,function(a,b) return Path.Distance(location,a)<Path.Distance(location,b) end)
    return points
end
local function Trace(bot,state,phase)
    if state.phase==phase then return end
    state.phase=phase
    local p=bot:GetLocation()
    print(string.format('[WISDOM_ONCE] t=%.1f team=%d pid=%d hero=%s side=%s phase=%s pos=(%.0f,%.0f) mode=%s',
        DotaTime(),bot:GetTeam(),bot:GetPlayerID(),bot:GetUnitName(),tostring(state.lane),phase,p.x,p.y,tostring(bot:GetActiveMode())))
end
local function Busy(bot,assigned)
    local mode=bot:GetActiveMode()
    if Fu.IsPushing and Fu.IsPushing(bot) then return true end
    if mode==BOT_MODE_ASSEMBLE then return true end
    if bot==GetBot() then
        for _,e in ipairs(bot:GetNearbyHeroes(1100,true,BOT_MODE_NONE) or {}) do
            if Valid(e) and e:IsAlive() and e:CanBeSeen() then return true end
        end
    end
    if require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(bot) then return true end
    local grouping=0
    for i=1,5 do local a=GetTeamMember(i)
        if a and a~=bot and a:IsAlive() and Path.Distance(a:GetLocation(),bot:GetLocation())<1400 then
            local m=a:GetActiveMode()
            if m==BOT_MODE_ASSEMBLE or (Fu.IsPushing and Fu.IsPushing(a)) then grouping=grouping+1 end
        end
    end
    if grouping>=2 then return true end
    if Fu.IsRetreating(bot) or (Fu.IsDefending and Fu.IsDefending(bot)) then return true end
    if (Fu.IsDoingRoshan and Fu.IsDoingRoshan(bot)) or (Fu.IsDoingTormentor and Fu.IsDoingTormentor(bot)) then return true end
    if bot:IsChanneling() then return true end
    local target=bot.GetAttackTarget and bot:GetAttackTarget()
    if Valid(target) and target:IsAlive() and Fu.IsAttacking and Fu.IsAttacking(bot)
        and (target:IsHero() or target:IsBuilding()) then return true end
    local heroTarget=Fu.GetProperTarget and Fu.GetProperTarget(bot)
    if Fu.IsGoingOnSomeone and Fu.IsGoingOnSomeone(bot) and Valid(heroTarget)
        and heroTarget:IsHero() and heroTarget:IsAlive() and heroTarget:CanBeSeen()
        and Path.Distance(bot:GetLocation(),heroTarget:GetLocation())<1600 then return true end
    if Fu.GetHP and Fu.GetHP(bot)<0.5 then return true end
    return bot:WasRecentlyDamagedByAnyHero(3)
end
local function NewPlan(bot)
    local plan={candidates={},jobs={},assignments={},index=1,ready=false,rejected={busy=0,unsafe_start=0,far=0}}
    local seen={}
    local function Add(ally)
        if Eligible(ally) and ally:IsAlive() and ally:GetTeam()==bot:GetTeam() then
            local pid=ally:GetPlayerID()
            if seen[pid] then return end
            seen[pid]=true
            plan.candidates[#plan.candidates+1]={bot=ally,pid=pid,deaths=GetHeroDeaths(pid),costs={}}
        end
    end
    for i=1,5 do Add(GetTeamMember(i)) end
    for _,ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do Add(ally) end
    Add(bot)
    table.sort(plan.candidates,function(a,b) return a.pid<b.pid end)
    local zones=Path.Towers(bot)
    for _,candidate in ipairs(plan.candidates) do
        local start=candidate.bot:GetLocation()
        local busy=Busy(candidate.bot,false)
        local safe=Path.SafePoint(start,zones)
        if busy then plan.rejected.busy=plan.rejected.busy+1
        elseif not safe then plan.rejected.unsafe_start=plan.rejected.unsafe_start+1 end
        if not busy and safe then
            for _,lane in ipairs({LANE_TOP,LANE_BOT}) do
                local goal=Center(lane)
                local cost=Path.Distance(start,goal)
                -- Cheap conservative tower-detour estimate, not ten A* searches.
                for _,zone in ipairs(zones) do
                    local dx,dy=goal.x-start.x,goal.y-start.y
                    local length=dx*dx+dy*dy
                    local t=length>0 and ((zone.location.x-start.x)*dx+(zone.location.y-start.y)*dy)/length or 0
                    t=math.max(0,math.min(1,t))
                    local nearest=Vector(start.x+t*dx,start.y+t*dy,start.z)
                    if Path.Distance(nearest,zone.location)<zone.radius then cost=cost+zone.radius*2 end
                end
                -- Compare travel time, rather than treating slow and fast heroes as identical.
                local speed=candidate.bot.GetCurrentMovementSpeed and math.max(200,candidate.bot:GetCurrentMovementSpeed()) or 300
                if cost/speed<=10 then candidate.costs[lane]=cost*300/speed end
            end
            if not next(candidate.costs) then plan.rejected.far=plan.rejected.far+1 end
        end
    end
    return plan
end
local function Allocate(plan)
    local choice,side,best
    for _,c in ipairs(plan.candidates) do
        for _,lane in ipairs({LANE_TOP,LANE_BOT}) do
            if c.costs[lane] and (not best or c.costs[lane]<best) then choice,side,best=c,lane,c.costs[lane] end
        end
    end
    if choice then
        plan.assignments[choice.pid]={lane=side,deaths=choice.deaths}
        plan.used=true
        print(string.format('[WISDOM_ONCE] nearby_opportunity t=%.1f team=%d pid=%d eta=%.1f',DotaTime(),plan.team,choice.pid,best/300))
    elseif not diagnostics[plan.team] then
        diagnostics[plan.team]=true
        print(string.format('[WISDOM_CHECK] t=%.1f team=%d phase=no_nearby_idle_candidate alive=%d busy=%d unsafe_start=%d far=%d',
            DotaTime(),plan.team,#plan.candidates,plan.rejected.busy,plan.rejected.unsafe_start,plan.rejected.far))
    end
    plan.ready=true
end
local function StopOwn(bot,state)
    if state.issuedAction and bot:IsAlive() and bot:GetActiveMode()==BOT_MODE_TEAM_ROAM then
        bot:Action_ClearActions(true)
    end
    state.issuedAction=false
end
local function ResetRoute(state)
    state.path,state.job,state.index=nil,nil,nil
    state.routeStep,state.nextOrder=96,0
    state.progressPoint,state.progressAt=nil,nil
end
local function Finish(bot,state,reason)
    if not state.active or state.lane==nil then return end
    StopOwn(bot,state)
    Path.ResetNavigation(state)
    state.active=false
    state.arrivedAt,state.emptyAt,state.path,state.job=nil,nil,nil,nil
    state.reason=reason
    local plan=plans[bot:GetTeam()]
    if plan then plan.assignments[bot:GetPlayerID()]=nil;plan.used=true end
    Trace(bot,state,reason)
end
local function Combat(bot)
    for _,enemy in pairs(bot:GetNearbyHeroes(1000,true,BOT_MODE_NONE) or {}) do
        if Valid(enemy) and enemy:IsAlive() and enemy:IsHero() and enemy:CanBeSeen()
            and enemy:GetTeam()~=bot:GetTeam() then
            local range=math.min(900,math.max(500,enemy:GetAttackRange()+150,bot:GetAttackRange()+150))
            if GetUnitToUnitDistance(bot,enemy)<=range then return true end
        end
    end
    return bot:WasRecentlyDamagedByAnyHero(3) or Fu.IsRetreating(bot)
end
local function FindShrine(center)
    for _,unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
        if Valid(unit) and not unit:IsHero() and unit:CanBeSeen()
            and Path.Distance(unit:GetLocation(),center)<1500 then
            local name=string.lower(unit:GetUnitName() or '')
            local ok,ability=pcall(function() return unit:GetAbilityByName('ability_xp_fountain') end)
            if string.find(name,'xp_fountain',1,true) or string.find(name,'wisdom',1,true)
                or (ok and ability~=nil) then return unit end
        end
    end
end
local function Charges(shrine)
    if not Valid(shrine) or not shrine:CanBeSeen() then return nil,nil end
    local ok,ability=pcall(function() return shrine:GetAbilityByName('ability_xp_fountain') end)
    if not ok or ability==nil then return nil,nil end
    local success,count=pcall(function() return ability:GetCurrentCharges() end)
    if success and type(count)=='number' and count>=0 then return count,ability end
    return nil,ability
end
function X.Update(bot)
    if not Eligible(bot) then return nil end
    local now=DotaTime()
    local state=bot._wisdomOnce
    if not state then state={active=false,issuedAction=false,decided=false};bot._wisdomOnce=state end
    if now<START then return state end
    local team=bot:GetTeam()
    local teamPlan=plans[team]
    if not teamPlan and now>=START+10 then state.decided=true;return state end
    if not teamPlan or (not teamPlan.used and now<START+10 and now>=(teamPlan.nextElection or 0)) then
        teamPlan=NewPlan(bot);teamPlan.team=team;teamPlan.nextElection=now+2
        Allocate(teamPlan);plans[team]=teamPlan
    end
    if not state.decided then
        if now>=START+LIMIT then state.decided=true;return state end
        local team=bot:GetTeam()
        if plans[team]==nil then plans[team]=NewPlan(bot);plans[team].team=team end
        local plan=plans[team]
        if not plan.ready then return state end
        local assignment=plan.assignments[bot:GetPlayerID()]
        if not assignment then
            if plan.used or now>=START+10 then state.decided=true end
            return state
        end
        state.decided=true
        if assignment and bot:IsAlive() and GetHeroDeaths(bot:GetPlayerID())==assignment.deaths then
            state.active,state.lane,state.deaths=true,assignment.lane,assignment.deaths
            state.center=Center(state.lane)
            state.deadline=math.min(now+20,START+LIMIT)
            state.blockedPoints={}
            state.candidates=CapturePoints(bot,state.center)
            ResetRoute(state)
            Trace(bot,state,'scheduled')
        end
    end
    if state.active then
        if not bot:IsAlive() or GetHeroDeaths(bot:GetPlayerID())>state.deaths then
            Finish(bot,state,'dead_original_AI')
        elseif now>=state.deadline then Finish(bot,state,'timeout_original_AI') end
    end
    return state
end
function X.IsActive(bot)
    local s=X.Update(bot);return s~=nil and s.active
end
function X.GetDesire(bot)
    local s=X.Update(bot)
    if not s or not s.active or bot:IsInvulnerable() then return 0 end
    if Combat(bot) or Busy(bot,true) or not Path.OutsideTowers(bot:GetLocation(),Path.Towers(bot)) then
        Finish(bot,s,'interrupted_original_AI');return 0
    end
    s.busySince=nil
    if Path.Distance(bot:GetLocation(),s.center)>250 then
        if not Path.Prepare(bot,s,s.center,s.lane,s.candidates) then
            StopOwn(bot,s);Trace(bot,s,'planning_original_AI')
            if (s.navFailures or 0)>=1 then Finish(bot,s,'route_failed_replace_original_AI') end
            return 0
        end
    end
    return DESIRE
end
function X.HasPriority(bot)
    if X.GetDesire(bot)>0 then return true end
    local s=bot._wisdomOnce
    local plan=plans[bot:GetTeam()]
    -- Avoid a Roshan announcement in the short allocation/planning interval.
    return s~=nil and not s.decided and plan~=nil and not plan.ready
        and DotaTime()>=START and DotaTime()<START+LIMIT and not Combat(bot)
end
function X.OwnsMovement(bot)
    local s=bot._wisdomOnce
    return s~=nil and s.active and s.issuedAction
        and bot:GetActiveMode()==BOT_MODE_TEAM_ROAM and not Combat(bot)
end
local function Walk(bot,s)
    if Path.Move(bot,s) then s.issuedAction=true;Trace(bot,s,'walking_safe_route')
    else StopOwn(bot,s);Trace(bot,s,'route_retry_original_AI') end
end
function X.Think(bot)
    if X.GetDesire(bot)==0 then return false end
    local s=bot._wisdomOnce
    if bot:IsUsingAbility() or bot:IsCastingAbility() or bot:IsChanneling()
        or bot:IsStunned() or bot:IsRooted() then return true end
    if Path.Distance(bot:GetLocation(),s.center)>250 then
        s.arrivedAt,s.emptyAt,s.sawAvailable=nil,nil,nil;Walk(bot,s);return true
    end
    local now=DotaTime()
    if now>=(s.nextSearchAt or 0) then
        s.shrine=FindShrine(s.center)
        s.nextSearchAt=now+0.2
    end
    local shrine=s.shrine
    local charges,ability=Charges(shrine)
    if s.loggedCharges~=charges or not s.chargeLogAt or now-s.chargeLogAt>=3 then
        s.loggedCharges=charges;s.chargeLogAt=now
        print(string.format('[WISDOM_RESULT] t=%.2f team=%d pid=%d side=%s charges=%s level=%d xp_needed=%s',
            now,bot:GetTeam(),bot:GetPlayerID(),tostring(s.lane),tostring(charges),bot:GetLevel(),tostring(bot:GetXPNeededToLevel())))
    end
    if not s.arrivedAt then
        StopOwn(bot,s);bot:Action_ClearActions(false);s.issuedAction=true
        s.arrivedAt=now;s.level=bot:GetLevel();s.xp=bot:GetXPNeededToLevel()
        s.captureTime=3
        if ability then
            local ok,n=pcall(function() return ability:GetSpecialValueFloat('countdown_time') end)
            if ok and type(n)=='number' and n>0 then s.captureTime=n end
        end
        Trace(bot,s,'observing_capture')
    end
    local elapsed=now-s.arrivedAt
    if charges and charges>0 then s.sawAvailable=true;s.emptyAt=nil end
    if charges==0 then
        if s.sawAvailable and (bot:GetLevel()>s.level or bot:GetXPNeededToLevel()<s.xp) then
            Finish(bot,s,'collected_original_AI');return true
        end
        if not s.emptyAt then s.emptyAt=now end
        if now-s.emptyAt>=EMPTY_WAIT then Finish(bot,s,'empty_original_AI');return true end
    elseif elapsed>=s.captureTime then
        if charges==nil and (bot:GetLevel()>s.level or bot:GetXPNeededToLevel()<s.xp) then
            Finish(bot,s,'xp_changed_unconfirmed_original_AI');return true
        end
        -- Some clients hide passive charges. Complete the real countdown FIRST,
        -- then give one second to confirm the result, never abort it at 1s.
        if charges==nil and elapsed>=s.captureTime+EMPTY_WAIT then
            Finish(bot,s,'unavailable_original_AI');return true
        end
        if charges and charges>0 and elapsed>=s.captureTime+8 then
            Finish(bot,s,'contested_or_unavailable_original_AI');return true
        end
    end
    return true
end
function X.OnEnd(bot)
    local s=bot._wisdomOnce
    if not s or not s.active then return end
    StopOwn(bot,s);Path.Pause(s)
    s.arrivedAt,s.emptyAt,s.sawAvailable=nil,nil,nil
end
return X
