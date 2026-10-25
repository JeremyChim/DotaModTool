-- Local, incremental path planning for wisdom visits only. No global avoidance
-- zones are installed, and no default MoveToLocation shortcut crosses a tower.
local X = {}
local STEP = 96
local MARGIN = 128
local TOWER_HULL_ALLOWANCE = 128 -- fixed conservative allowance; no fog-restricted tower hull query
local LIMIT = 18000
local DIRECTIONS = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}

local function Distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
X.Distance = Distance

function X.Towers(bot)
    local zones = {}
    local opposing = bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
    for id = 0, 10 do
        local tower = GetTower(opposing, id)
        if tower ~= nil and not tower:IsNull() and tower:IsAlive() then
            -- The existing API override reports only 200 attack range in fog.
            -- Normal towers have 700 range; never trust that fog fallback.
            zones[#zones + 1] = {
                location = tower:GetLocation(),
                radius = math.max(700, tower:GetAttackRange())
                    + TOWER_HULL_ALLOWANCE + bot:GetBoundingRadius() + MARGIN
            }
        end
    end
    return zones
end

function X.OutsideTowers(point, zones)
    for _, zone in ipairs(zones) do
        if Distance(point, zone.location) <= zone.radius then return false end
    end
    return true
end

function X.SafePoint(point, zones)
    return X.OutsideTowers(point,zones) and IsLocationPassable(point)
end

local function SegmentDistance(a, b, point)
    local dx, dy = b.x-a.x, b.y-a.y
    local length = dx*dx+dy*dy
    local t = length > 0 and ((point.x-a.x)*dx+(point.y-a.y)*dy)/length or 0
    t = math.max(0, math.min(1, t))
    return Distance(Vector(a.x+t*dx, a.y+t*dy, a.z), point)
end

function X.SafeSegment(a, b, zones)
    for _, zone in ipairs(zones) do
        if SegmentDistance(a, b, zone.location) <= zone.radius then return false end
    end
    local samples = math.max(1, math.ceil(Distance(a,b)/16))
    local previousHeight
    for index = 0, samples do
        local t = index/samples
        local point=Vector(a.x+(b.x-a.x)*t, a.y+(b.y-a.y)*t, a.z)
        if not IsLocationPassable(point) then
            return false
        end
        if GetHeightLevel then
            local height=GetHeightLevel(point)
            if previousHeight~=nil and math.abs(height-previousHeight)>1 then return false end
            previousHeight=height
        end
    end
    return true
end

local function Push(heap, entry)
    local index = #heap+1
    while index > 1 do
        local parent = math.floor(index/2)
        if heap[parent].score <= entry.score then break end
        heap[index] = heap[parent]
        index = parent
    end
    heap[index] = entry
end

local function Pop(heap)
    local first, last = heap[1], table.remove(heap)
    if #heap == 0 then return first end
    local index = 1
    while index*2 <= #heap do
        local child = index*2
        if child < #heap and heap[child+1].score < heap[child].score then child=child+1 end
        if last.score <= heap[child].score then break end
        heap[index] = heap[child]
        index = child
    end
    heap[index] = last
    return first
end

local function Key(x,y) return tostring(x)..':'..tostring(y) end
local function Point(job, x,y)
    return Vector(job.start.x+x*job.step, job.start.y+y*job.step, job.start.z)
end

function X.New(bot, goal, lane, step, blockedPoints, goalCandidates, startOverride, extraZones)
    local start = startOverride or bot:GetLocation()
    local job = {start=start, goal=goal, lane=lane, step=step or STEP,
        zones=X.Towers(bot), open={}, nodes={}, passable={}, closed={}, expanded=0,
        goals={},goalRadius=0,
        minX=math.min(start.x,goal.x)-1600, maxX=math.max(start.x,goal.x)+1600,
        minY=math.min(start.y,goal.y)-1600, maxY=math.max(start.y,goal.y)+1600}
    for _,point in ipairs(blockedPoints or {}) do
        job.zones[#job.zones+1]={location=point,radius=48}
    end
    for _,zone in ipairs(extraZones or {}) do job.zones[#job.zones+1]=zone end
    for _,point in ipairs(goalCandidates or {goal}) do
        if X.SafePoint(point,job.zones) then
            job.goals[#job.goals+1]=point
            job.goalRadius=math.max(job.goalRadius,Distance(goal,point))
        end
    end
    if not X.SafePoint(start, job.zones) or #job.goals==0 then
        job.done=true
        return job
    end
    local root = {x=0,y=0,g=0}
    job.nodes['0:0'] = root
    Push(job.open, {key='0:0',score=math.max(0,Distance(start,goal)-job.goalRadius)})
    return job
end

local function Passable(job,x,y)
    local key=Key(x,y)
    if job.passable[key] == nil then
        local point=Point(job,x,y)
        job.passable[key] = point.x >= job.minX and point.x <= job.maxX
            and point.y >= job.minY and point.y <= job.maxY and X.SafePoint(point,job.zones)
    end
    return job.passable[key]
end

local function ForestCost(job, point)
    local along, distance = GetAmountAlongLane(job.lane,point)
    if type(along)=='table' then distance=along.distance end
    -- Prefer passable forest/jungle ground over the lane itself during transit.
    return type(distance)=='number' and distance<350 and 1.35 or 1
end

function X.Step(job, budget)
    if job.done then return job.path,true end
    for _ = 1, budget or 180 do
        if #job.open==0 or job.expanded>=LIMIT then job.done=true; return nil,true end
        local entry=Pop(job.open)
        if not job.closed[entry.key] then
            job.closed[entry.key]=true
            job.expanded=job.expanded+1
            local node=job.nodes[entry.key]
            local point=Point(job,node.x,node.y)
            local reached
            if Distance(point,job.goal)<=job.goalRadius+job.step*1.5 then
                local bestDistance
                for _,goal in ipairs(job.goals) do
                    local distance=Distance(point,goal)
                    if distance<=job.step*1.5 and (bestDistance==nil or distance<bestDistance)
                        and X.SafeSegment(point,goal,job.zones) then
                        reached,bestDistance=goal,distance
                    end
                end
            end
            if reached then
                local path={reached}
                local cursor=node
                while cursor do
                    table.insert(path,1,Point(job,cursor.x,cursor.y))
                    cursor=cursor.parent and job.nodes[cursor.parent] or nil
                end
                job.path,job.done,job.chosenGoal=path,true,reached
                return path,true
            end
            for _, direction in ipairs(DIRECTIONS) do
                local x,y=node.x+direction[1],node.y+direction[2]
                local key=Key(x,y)
                if not job.closed[key] and Passable(job,x,y) then
                    -- Reject diagonal corner cutting and every unsafe straight segment.
                    local nextPoint=Point(job,x,y)
                    if (direction[1]==0 or direction[2]==0
                        or (Passable(job,node.x+direction[1],node.y) and Passable(job,node.x,node.y+direction[2])))
                        and X.SafeSegment(point,nextPoint,job.zones) then
                        local g=node.g+Distance(point,nextPoint)*ForestCost(job,nextPoint)
                        if job.nodes[key]==nil or g<job.nodes[key].g then
                            job.nodes[key]={x=x,y=y,g=g,parent=entry.key}
                            Push(job.open,{key=key,score=g+math.max(0,Distance(nextPoint,job.goal)-job.goalRadius)})
                        end
                    end
                end
            end
        end
    end
    return nil,false
end


-- Shared bounded planning, with an overlapping next chunk and sparse move orders.
local sliceAt,remaining=-1,0
local function TreeZones(bot,s)
    local now,location=DotaTime(),bot:GetLocation()
    if not s.navTrees or now>=(s.navTreeAt or 0)
        or not s.navTreePos or Distance(location,s.navTreePos)>192 then
        s.navTrees={};s.navTreeAt=now+0.4;s.navTreePos=location
        if GetTreeLocation and bot.GetNearbyTrees then
            for _,id in ipairs(bot:GetNearbyTrees(800) or {}) do
                local p=GetTreeLocation(id)
                if p then s.navTrees[#s.navTrees+1]={location=p,radius=bot:GetBoundingRadius()+24} end
            end
        end
    end
    return s.navTrees
end
local function Zones(bot,s)
    local zones=X.Towers(bot)
    for _,zone in ipairs(TreeZones(bot,s)) do zones[#zones+1]=zone end
    return zones
end
local function Budget(s,now)
    if now<(s.navNext or 0) then return 0 end
    s.navNext=now+0.05
    if now-sliceAt>=0.049 or now<sliceAt then sliceAt,remaining=now,96 end
    local n=math.min(24,remaining);remaining=remaining-n;return n
end
local function Prefix(job,center)
    if job.expanded<24 then return nil end
    local best,score
    for key in pairs(job.closed) do
        local node=job.nodes[key];local p=Point(job,node.x,node.y)
        local progress=Distance(job.start,center)-Distance(p,center)
        if progress>240 and (not score or progress>score) then best,score=node,progress end
    end
    if not best then return nil end
    local path={};local cursor=best
    while cursor do
        table.insert(path,1,Point(job,cursor.x,cursor.y))
        cursor=cursor.parent and job.nodes[cursor.parent] or nil
    end
    while #path>14 do table.remove(path) end
    return path
end
local function Smooth(path,zones)
    local result={path[1]};local i=1
    while i<#path do
        -- Bound smoothing work when recovery produces a map-spanning route.
        -- The remaining grid edges were already validated by the search.
        if i>24 then
            for j=i+1,#path do result[#result+1]=path[j] end
            break
        end
        local chosen=i+1
        for j=math.min(#path,i+8),i+2,-1 do
            if Distance(path[i],path[j])<=720 and X.SafeSegment(path[i],path[j],zones) then chosen=j;break end
        end
        result[#result+1]=path[chosen];i=chosen
    end
    return result
end
local function Drop(s)
    s.navPath,s.navJob,s.navQueued,s.navDetour,s.navFull=nil,nil,nil,nil,nil
    s.navLastOrder,s.navProgress,s.navProgressAt,s.navTarget=nil,nil,nil,nil
end
local function Rejoin(s,location,zones)
    local path=s.navPath
    if not path then return end
    local best,score
    for i=math.max(2,s.navIndex or 2),#path do
        local d=Distance(location,path[i])
        if d<=800 and X.SafeSegment(location,path[i],zones) then
            -- Closest forward entry; break equal-distance ties toward the end.
            local cost=d+(#path-i)*2
            if not score or cost<score then best,score=i,cost end
        end
    end
    if best then s.navIndex=best else Drop(s) end
    s.navLastOrder=nil
end
local function Remaining(s,location)
    local path=s.navPath;if not path then return 0 end
    local distance=0;local prev=location
    for i=s.navIndex,#path do distance=distance+Distance(prev,path[i]);prev=path[i] end
    return distance
end
local function Install(s,path,zones)
    s.navPath,s.navIndex=Smooth(path,zones),2
    s.navJob,s.navQueued,s.navLastOrder=nil,nil,nil
    s.navProgress,s.navProgressAt,s.navTarget=nil,nil,nil
    s.navFailures=0
end
function X.Prepare(bot,s,center,lane,goals)
    local now,location=DotaTime(),bot:GetLocation();local zones=Zones(bot,s)
    if now>=(s.navDiagAt or 0) then
        s.navDiagAt=now+5
        print(string.format('[OBJECTIVE_ROUTE] t=%.1f team=%d pid=%d target=(%.0f,%.0f) pos=(%.0f,%.0f) mode=%s nodes=%d failures=%d moving=%s ahead=%s',
            now,bot:GetTeam(),bot:GetPlayerID(),center.x,center.y,location.x,location.y,
            tostring(bot:GetActiveMode()),s.navJob and s.navJob.expanded or 0,s.navFailures or 0,
            tostring(s.navPath~=nil),tostring(s.navQueued~=nil)))
    end
    local distance=Distance(location,center)
    if not s.navLoopAt or (s.navLastLocation and Distance(location,s.navLastLocation)>1400) then
        s.navLoopAt,s.navLoopDistance=now,distance
    elseif distance<(s.navLoopDistance or distance)-160 then
        s.navLoopAt,s.navLoopDistance=now,distance
    elseif not s.navRecover and s.navPath and now-s.navLoopAt>=12 then
        Drop(s);s.navRecover=true;s.navRetry=0;s.navNext=0
        s.navBlocked={} -- old artificial obstacles must not trap the full search
        print(string.format('[OBJECTIVE_ROUTE] t=%.1f pid=%d loop_recovery_full_route pos=(%.0f,%.0f)',now,bot:GetPlayerID(),location.x,location.y))
    end
    s.navLastLocation=location
    if s.navResume then Rejoin(s,location,zones);s.navResume=false end
    if s.navDetour then
        if Distance(location,s.navDetour)<40 then
            s.navDetour=nil;Rejoin(s,location,zones)
            s.navProgress,s.navProgressAt,s.navTarget=nil,nil,nil
        elseif X.SafeSegment(location,s.navDetour,zones) then return true
        else Drop(s) end
    end
    if s.navPath then
        local p=s.navPath[s.navIndex]
        while p and Distance(location,p)<40 do s.navIndex=s.navIndex+1;p=s.navPath[s.navIndex] end
        if not p then
            if s.navQueued then Install(s,s.navQueued,zones)
            else s.navPath=nil end
        elseif not X.SafeSegment(location,p,zones) then
            Rejoin(s,location,zones)
        end
    end
    local moving=s.navPath~=nil and s.navPath[s.navIndex]~=nil
    if moving and (s.navFull or Remaining(s,location)>850 or s.navQueued) then return true end
    if now<(s.navRetry or 0) then return moving end
    -- Next segment starts at the current route endpoint, not the moving hero.
    local start=moving and s.navPath[#s.navPath] or location
    if s.navJob and Distance(start,s.navJob.start)>(s.navRecover and 1200 or 256) then s.navJob=nil end
    if not s.navJob then
        s.navJob=X.New(bot,center,lane,s.navStep or 96,s.navBlocked,goals,start,TreeZones(bot,s))
        s.navStarted=now
    end
    local budget=Budget(s,now)
    if budget==0 then return moving end
    local job=s.navJob;local path,done=X.Step(job,budget)
    if not s.navRecover then path=path or Prefix(job,center) end
    if path and #path>=2 then
        if moving then
            s.navQueued=Smooth(path,zones);s.navJob=nil;s.navFailures=0
        else
            Install(s,path,zones)
            Rejoin(s,location,zones)
            if s.navPath and s.navRecover then
                s.navFull=true;s.navLoopAt=now;s.navLoopDistance=distance
                print(string.format('[OBJECTIVE_ROUTE] t=%.1f pid=%d recovered_full_route points=%d',now,bot:GetPlayerID(),#s.navPath))
            end
        end
        return s.navPath~=nil
    end
    if done or now-s.navStarted>=(s.navRecover and 10 or 2) then
        s.navJob=nil;s.navRetry=now+0.5
        s.navStep=(s.navStep or 96)==96 and 48 or 96
        s.navFailures=(s.navFailures or 0)+1
    end
    return moving
end
local function Detour(bot,s,p,location)
    local zones=Zones(bot,s);local a=math.atan2(p.y-location.y,p.x-location.x)
    local best,score
    for _,r in ipairs({112,176}) do
        for _,offset in ipairs({math.pi/3,-math.pi/3,math.pi/2,-math.pi/2}) do
            local q=Vector(location.x+r*math.cos(a+offset),location.y+r*math.sin(a+offset),location.z)
            if X.SafeSegment(location,q,zones) then
                local value=Distance(q,p)
                if not score or value<score then best,score=q,value end
            end
        end
    end
    return best
end
function X.Move(bot,s)
    local now,location=DotaTime(),bot:GetLocation()
    local p=s.navDetour or (s.navPath and s.navPath[s.navIndex])
    if not p then return false end
    if not X.SafeSegment(location,p,Zones(bot,s)) then Drop(s);return false end
    local distance=Distance(location,p)
    if s.navTarget~=p then
        s.navTarget,s.navProgress,s.navProgressAt,s.navBestDistance=p,location,now,distance
    elseif distance<(s.navBestDistance or distance)-18 then
        s.navProgress,s.navProgressAt,s.navBestDistance=location,now,distance
    elseif now-(s.navProgressAt or now)>1.1 then
        s.navBlocked=s.navBlocked or {}
        -- Remember the nearby obstruction, not a far-away route endpoint.
        local scale=math.min(1,80/math.max(1,distance))
        s.navBlocked[#s.navBlocked+1]=Vector(location.x+(p.x-location.x)*scale,location.y+(p.y-location.y)*scale,location.z)
        if #s.navBlocked>6 then table.remove(s.navBlocked,1) end
        s.navDetours=(s.navDetours or 0)+1
        local q=s.navDetours<=3 and not s.navDetour and Detour(bot,s,p,location) or nil
        s.navJob,s.navQueued=nil,nil
        if q then
            s.navDetour=q;s.navTarget=nil;s.navLastOrder=nil
            bot:Action_MoveDirectly(q);s.navLastOrder=q;s.navOrder=now
            print(string.format('[OBJECTIVE_ROUTE] t=%.1f pid=%d local_tree_detour pos=(%.0f,%.0f)',now,bot:GetPlayerID(),location.x,location.y))
            return true
        end
        Drop(s);s.navRetry=now+0.25;s.navFailures=(s.navFailures or 0)+1
        return false
    end
    -- Let the engine finish its existing move. Refresh only a changed target
    -- or an order that stopped making progress, not every 0.15 seconds.
    if s.navLastOrder~=p or (now-(s.navOrder or 0)>=0.8 and now-(s.navProgressAt or now)>0.65) then
        bot:Action_MoveDirectly(p);s.navLastOrder=p;s.navOrder=now
    end
    return true
end
function X.Pause(s,combat)
    s.navProgress,s.navProgressAt,s.navTarget,s.navLastOrder=nil,nil,nil,nil
    s.navResume=true
    -- Ordinary chunk handoffs must not keep resetting the loop watchdog.
    if combat then s.navLoopAt=DotaTime() end
    if s.navJob then s.navStarted=DotaTime() end
end
function X.ResetNavigation(s)
    Drop(s)
    s.navResume=false;s.navNext=0;s.navRetry=0;s.navStep=96
    s.navBlocked={};s.navDetours=0;s.navFailures=0
    s.navRecover,s.navLoopAt,s.navLoopDistance,s.navLastLocation=nil,nil,nil,nil
end
return X
