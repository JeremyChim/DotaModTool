-- Only objective participants get an eight-second opportunity to return to a group.
local X={}
local Path=require(GetScriptDirectory()..'/FuncLib/systems/shrine_path')
local function Valid(u) return u and not u:IsNull() and u:IsAlive() and not u:IsIllusion() end
local function Cancel(b) b._objectiveReturn=nil;return nil end
local function State(b)
    local s=b._objectiveReturn;local now=DotaTime()
    if not s then return nil end
    if now>=s.untilTime or not Valid(b) or b:GetHealth()/math.max(1,b:GetMaxHealth())<0.5 then return Cancel(b) end
    local mode=b:GetActiveMode()
    local defending=mode==BOT_MODE_DEFEND_TOWER_TOP or mode==BOT_MODE_DEFEND_TOWER_MID or mode==BOT_MODE_DEFEND_TOWER_BOT
    local releasedGuard=s.source=='base_guard' and (not b._hgGuardOrder or b._hgGuardOrder.done)
    if mode==BOT_MODE_RETREAT or mode==BOT_MODE_ROSHAN or (defending and not releasedGuard)
        or b:WasRecentlyDamagedByAnyHero(2) then return Cancel(b) end
    if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted() then return nil end
    if (b._outpostTask and b._outpostTask.active) or (b._earlyLotus and b._earlyLotus.active)
        or (b._wisdomOnce and b._wisdomOnce.active) then return Cancel(b) end
    for _,e in ipairs(b:GetNearbyHeroes(1100,true,BOT_MODE_NONE) or {}) do
        if Valid(e) and e:CanBeSeen() then return Cancel(b) end
    end
    local target=b:GetAttackTarget()
    if Valid(target) and (target:IsHero() or target:IsBuilding()) then return Cancel(b) end
    if now>=(s.nextScan or 0) then
        s.nextScan=now+0.5;s.point=nil
        local list={}
        for i=1,5 do
            local a=GetTeamMember(i)
            if Valid(a) and a~=b then
                local m=a:GetActiveMode()
                if m==BOT_MODE_ATTACK or m==BOT_MODE_ASSEMBLE or m==BOT_MODE_TEAM_ROAM
                    or m==BOT_MODE_PUSH_TOWER_TOP or m==BOT_MODE_PUSH_TOWER_MID or m==BOT_MODE_PUSH_TOWER_BOT then list[#list+1]=a end
            end
        end
        local chosen,best
        for _,a in ipairs(list) do
            local n=0;for _,other in ipairs(list) do if Path.Distance(a:GetLocation(),other:GetLocation())<1400 then n=n+1 end end
            local d=Path.Distance(b:GetLocation(),a:GetLocation())
            if n>=2 and d>1400 and d<=5000 and (not s.anchor or s.anchor==a)
                and (not best or d<best) then chosen,best=a,d end
        end
        if chosen then
            s.anchor=chosen -- Keep one group for this short return; do not oscillate between clusters.
            local p,q=b:GetLocation(),chosen:GetLocation();local step=math.min(650,best-1000)
            local waypoint=Vector(p.x+(q.x-p.x)*step/best,p.y+(q.y-p.y)*step/best,p.z)
            if Path.SafeSegment(p,waypoint,Path.Towers(b)) then s.point=waypoint end
        elseif s.anchor then
            return Cancel(b) -- Group dispersed or reached: original AI selects the next action.
        end
    end
    return s.point and s or nil
end
function X.GetDesire(b) return State(b) and 0.71 or 0 end
function X.Think(b)
    local s=State(b);if not s then return false end
    if DotaTime()>=(s.nextOrder or 0) then
        s.nextOrder=DotaTime()+0.6;b:Action_MoveToLocation(s.point)
        if not s.logged then s.logged=true;print(string.format('[OBJECTIVE_REGROUP] t=%.1f pid=%d source=%s',DotaTime(),b:GetPlayerID(),s.source)) end
    end
    return true
end
return X
