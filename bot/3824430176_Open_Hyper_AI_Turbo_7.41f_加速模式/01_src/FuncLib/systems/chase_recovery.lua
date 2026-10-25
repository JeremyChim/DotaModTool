-- Only intervene when chasing a visible real hero outside attack range.
local X={}
local Path=require(GetScriptDirectory()..'/FuncLib/systems/shrine_path')
local function Valid(u) return u and not u:IsNull() end
local function Distance(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Protected(b)
    return not b:IsAlive() or b:IsIllusion() or b:IsInvulnerable() or b:IsStunned() or b:IsRooted()
        or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility()
end
local function Safe(b,p)
    local origin=b:GetLocation()
    if not Path.SafeSegment(origin,p,Path.Towers(b)) then return false end
    local trees={}
    for _,id in ipairs(b:GetNearbyTrees(500) or {}) do trees[#trees+1]=GetTreeLocation(id) end
    for i=1,8 do
        local q=Vector(origin.x+(p.x-origin.x)*i/8,origin.y+(p.y-origin.y)*i/8,origin.z)
        if not IsLocationPassable(q) or math.abs(GetHeightLevel(q)-GetHeightLevel(origin))>1 then return false end
        for _,tree in ipairs(trees) do if Distance(q,tree)<b:GetBoundingRadius()+24 then return false end end
    end
    return true
end
function X.Think(b)
    if Protected(b) then b._chaseRecovery=nil;return false end
    local mode=b:GetActiveMode()
    if mode~=BOT_MODE_ATTACK and mode~=BOT_MODE_ROAM and mode~=BOT_MODE_TEAM_ROAM then b._chaseRecovery=nil;return false end
    local now=DotaTime();local s=b._chaseRecovery
    local area=b._chaseRecoveryArea
    if area and (now-area.lastAttempt>20 or Distance(b:GetLocation(),area.anchor)>480) then
        b._chaseRecoveryArea=nil;area=nil
    end
    local target=b:GetAttackTarget()
    if not Valid(target) and b.GetTarget then target=b:GetTarget() end
    local realTarget=Valid(target) and target:IsHero() and not target:IsIllusion() and target:IsAlive()
        and target:CanBeSeen() and target:GetTeam()~=b:GetTeam()
    if realTarget and Distance(b:GetLocation(),target:GetLocation())<=b:GetAttackRange()+target:GetBoundingRadius()+80 then
        b._chaseRecovery=nil;return false -- real combat always interrupts an escape
    end
    if s and s.untilTime and now<s.untilTime then
        if now>=(s.nextOrder or 0) and Safe(b,s.escape) then
            b:Action_ClearActions(false);b:Action_MoveToLocation(s.escape);s.nextOrder=now+0.5
        end
        return true
    end
    if not realTarget then b._chaseRecovery=nil;return false end
    local p=b:GetLocation();local distance=Distance(p,target:GetLocation())
    if distance<=b:GetAttackRange()+target:GetBoundingRadius()+80 then b._chaseRecovery=nil;return false end
    if not s or s.target~=target then
        if s and now-(s.lastSeen or s.at)<1.5 and Distance(p,s.pos)<80 then
            -- Switching heroes while stationary is still the same blocked pursuit.
            s.target=target;s.distance=distance;s.lastSeen=now
        else
        b._chaseRecovery={target=target,at=now,pos=p,distance=distance,nextCheck=now+0.5,tries=0};return false
        end
    end
    s.lastSeen=now
    if now<s.nextCheck then return false end
    s.nextCheck=now+0.5
    if Distance(p,s.pos)>80 or s.distance-distance>100 then
        s.pos=p;s.distance=distance;s.at=now;return false
    end
    if now-s.at<3 then return false end
    local dx,dy=target:GetLocation().x-p.x,target:GetLocation().y-p.y
    local len=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/len,dy/len
    local tries=area and Distance(p,area.anchor)<=320 and math.min(2,area.tries+1) or 1
    local angles=tries==1 and {math.pi/2,-math.pi/2,math.pi} or {math.pi,math.pi*0.75,-math.pi*0.75}
    local length=tries==1 and 224 or 320
    for _,angle in ipairs(angles) do
        local point=Vector(p.x+(dx*math.cos(angle)-dy*math.sin(angle))*length,
            p.y+(dx*math.sin(angle)+dy*math.cos(angle))*length,p.z)
        if Safe(b,point) then
            s.tries=tries;s.escape=point;s.untilTime=now+(tries==1 and 1.2 or 4)
            b._chaseRecoveryArea={anchor=area and area.anchor or p,lastAttempt=now,tries=tries}
            s.at=s.untilTime;s.pos=p;s.distance=distance;s.nextOrder=now+0.5
            b:Action_ClearActions(false);b:Action_MoveToLocation(point)
            print(string.format('[CHASE_RECOVERY] t=%.1f pid=%d target=%s phase=%s pos=(%.0f,%.0f)',
                now,b:GetPlayerID(),target:GetUnitName(),s.tries==1 and 'local_detour' or 'brief_abandon',p.x,p.y))
            return true
        end
    end
    -- No verified local exit: clear only the blocked chase, leave other modes untouched.
    b:Action_ClearActions(false);s.at=now+4;s.nextCheck=now+4
    b._chaseRecoveryArea={anchor=area and area.anchor or p,lastAttempt=now,tries=tries}
    print(string.format('[CHASE_RECOVERY] t=%.1f pid=%d phase=no_safe_detour_original_AI',now,b:GetPlayerID()))
    return true
end
return X
