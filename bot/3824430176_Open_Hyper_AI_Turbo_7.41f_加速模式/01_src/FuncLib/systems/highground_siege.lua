-- Only restrain deep hero pursuits in the enemy base. Never change field Gank.
local X={}
local function Valid(u) return u and not u:IsNull() and u:IsAlive() end
local function Distance(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Trace(bot,s,reason,issued)
    -- Independent of short-lived pursuit state; alternating phases cannot flood the console.
    local d=bot._highgroundSiegeTrace or {};bot._highgroundSiegeTrace=d
    local now=DotaTime()
    if now<(d[reason] or 0) then return end
    d[reason]=now+5
    local p=bot:GetLocation()
    print(string.format('[HG_SIEGE] t=%.1f team=%d pid=%d phase=%s pos=(%.0f,%.0f) mode=%s issued=%s',
        now,bot:GetTeam(),bot:GetPlayerID(),reason,p.x,p.y,tostring(bot:GetActiveMode()),tostring(issued==true)))
end
local function Protected(bot)
    return not bot:IsAlive() or not bot:IsHero() or bot:IsIllusion() or bot:IsInvulnerable()
        or bot:IsChanneling() or bot:IsUsingAbility() or bot:IsCastingAbility() or bot:IsStunned() or bot:IsRooted()
end
local function ApproachSafe(bot,p,fountain)
    local origin=bot:GetLocation();local start=Distance(origin,fountain)
    local previous=start
    for i=1,16 do
        local q=Vector(origin.x+(p.x-origin.x)*i/16,origin.y+(p.y-origin.y)*i/16,origin.z)
        local d=Distance(q,fountain)
        if not IsLocationPassable(q) or (start>1600 and d<1600) or (start<=1600 and d<previous-1) then return false end
        previous=d
    end
    return true
end
local function Buildings(bot,enemy)
    local list={}
    local function Add(u)
        if Valid(u) and u:CanBeSeen() and not u:IsInvulnerable() then list[#list+1]=u end
    end
    for _,id in ipairs({TOWER_TOP_3,TOWER_MID_3,TOWER_BOT_3,9,10}) do Add(GetTower(enemy,id)) end
    for id=0,5 do Add(GetBarracks(enemy,id)) end
    Add(GetAncient(enemy))
    return list
end
local function Anchor(bot,enemy,fountain)
    local chosen,cost
    for _,building in ipairs(Buildings(bot,enemy)) do
        local p=building:GetLocation();local d=Distance(bot:GetLocation(),p)
        if Distance(p,fountain)>1700 and d<2300 and (not cost or d<cost) then chosen,cost=building,d end
    end
    return chosen
end
local function QuickKill(bot,target)
    if target:IsInvulnerable() or target:GetHealth()>target:GetMaxHealth()*0.25 then return false end
    if Distance(bot:GetLocation(),target:GetLocation())>bot:GetAttackRange()+400 then return false end
    local damage=bot:GetEstimatedDamageToTarget(true,target,1.5,DAMAGE_TYPE_PHYSICAL)
    for _,ally in ipairs(bot:GetNearbyHeroes(900,false,BOT_MODE_NONE) or {}) do
        if ally~=bot and Valid(ally) and not ally:IsIllusion() and not ally:IsStunned() and not ally:IsChanneling()
            and ally:GetAttackTarget()==target and Distance(ally:GetLocation(),target:GetLocation())<=ally:GetAttackRange()+100 then
            damage=damage+ally:GetEstimatedDamageToTarget(true,target,1.5,DAMAGE_TYPE_PHYSICAL)
        end
    end
    return damage>=target:GetHealth()*1.25 -- conservative estimate, not a kill guarantee
end
local function Reposition(bot,s,fountain,anchor,ancient,phase)
    if s.pointAnchor~=anchor or s.pointPhase~=phase then s.escapePoint=nil end
    s.pointAnchor=anchor;s.pointPhase=phase
    if s.escapePoint and ApproachSafe(bot,s.escapePoint,fountain)
        and Distance(bot:GetLocation(),s.escapePoint)>120 then
        bot:Action_MoveToLocation(s.escapePoint);return true
    end
    s.escapePoint=nil
    local target=anchor and anchor:GetLocation() or ancient:GetLocation()
    local dx,dy=target.x-fountain.x,target.y-fountain.y
    local len=math.max(1,math.sqrt(dx*dx+dy*dy))
    local stand=Vector(target.x+dx/len*400,target.y+dy/len*400,target.z)
    if ApproachSafe(bot,stand,fountain) then s.escapePoint=stand;bot:Action_MoveToLocation(stand);return true end
    local p=bot:GetLocation();dx,dy=p.x-fountain.x,p.y-fountain.y;len=math.max(1,math.sqrt(dx*dx+dy*dy))
    for _,step in ipairs({300,600}) do
    for _,a in ipairs({0,0.25,-0.25,0.5,-0.5,0.75,-0.75,1,-1,1.25,-1.25,1.5,-1.5}) do
        local q=Vector(p.x+(dx*math.cos(a)-dy*math.sin(a))/len*step,
            p.y+(dx*math.sin(a)+dy*math.cos(a))/len*step,p.z)
        if ApproachSafe(bot,q,fountain) then s.escapePoint=q;bot:Action_MoveToLocation(q);return true end
    end
    end
    return false -- never issue an unvalidated blind move
end
function X.Think(bot)
    if Protected(bot) then
        -- Preserve short pursuit allowance / escape state through casting, but never interrupt it.
        if not bot:IsAlive() then bot._highgroundSiege=nil end
        return false
    end
    local mode=bot:GetActiveMode()
    if mode~=BOT_MODE_ATTACK and mode~=BOT_MODE_ROAM and mode~=BOT_MODE_TEAM_ROAM
        and mode~=BOT_MODE_PUSH_TOWER_TOP and mode~=BOT_MODE_PUSH_TOWER_MID and mode~=BOT_MODE_PUSH_TOWER_BOT then
        bot._highgroundSiege=nil;return false
    end
    local enemy=bot:GetTeam()==TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
    local ancient=GetAncient(enemy)
    if not Valid(ancient) then return false end
    local p=bot:GetLocation();local base=ancient:GetLocation()
    if Distance(p,base)>3000 or (GetHeightLevel and GetHeightLevel(p)<GetHeightLevel(base)) then
        bot._highgroundSiege=nil;return false
    end
    -- Lazy require avoids the func_utils/global_overrides initialization cycle.
    local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
    local fountain=Fu.GetEnemyFountain()
    local now=DotaTime();local s=bot._highgroundSiege or {};bot._highgroundSiege=s
    local target=bot:GetAttackTarget()
    if not Valid(target) or not target:IsHero() then target=Fu.GetProperTarget(bot) end
    local hero=Valid(target) and target:IsHero() and not target:IsIllusion() and target:CanBeSeen() and target:GetTeam()==enemy
    local ours=Distance(p,fountain)
    if ours<=1600 then s.escapeUntil=now+2 end
    local inside=ours<=1600 or (s.escapeUntil and now<s.escapeUntil and ours<1800)
    local dangerTarget=hero and Distance(target:GetLocation(),fountain)<=1800
    -- A distant hero near their fountain is not a reason to pull the whole siege back.
    local hard=inside or (dangerTarget and ours<=2300)
    if not hero and not hard then s.pursuit=nil;s.holdUntil=nil;return false end
    if now>=(s.nextAnchor or 0) or (s.anchor and not Valid(s.anchor))
        or (s.anchorPosition and Distance(p,s.anchorPosition)>500) then
        s.anchor=Anchor(bot,enemy,fountain);s.nextAnchor=now+0.5;s.anchorPosition=p
    end
    local anchor=s.anchor
    if anchor and (not anchor:CanBeSeen() or anchor:IsInvulnerable()) then anchor=nil;s.anchor=nil end
    if not hard then
        local targetRadius=Distance(target:GetLocation(),fountain)
        local deep=ours<2800 and targetRadius<2300 and targetRadius<ours-450
            and Distance(p,target:GetLocation())>bot:GetAttackRange()+350
        if not deep then s.pursuit=nil;s.allowTarget=nil;return false end
        -- Require measured movement toward the fountain, not just an assigned combat target.
        local track=s.pursuit
        if not track or track.target~=target or now-track.last>1 then
            track={target=target,start=now,radius=ours,last=now};s.pursuit=track
        end
        track.last=now
        if now-track.start<1 or track.radius-ours<120 then return false end
        if QuickKill(bot,target) then
            if s.allowTarget~=target then s.allowTarget=target;s.allowAt=now end
            if now-s.allowAt<2 then Trace(bot,s,'allow_short_kill');return false end
        end
        if bot:GetHealth()/math.max(1,bot:GetMaxHealth())<0.45 then return false end
    end
    if now<(s.nextOrder or 0) then return true end
    local issued=false
    local wave=false
    if anchor then
        for _,creep in ipairs(bot:GetNearbyLaneCreeps(1600,false) or {}) do
            if Valid(creep) and Distance(creep:GetLocation(),anchor:GetLocation())<1000 then wave=true;break end
        end
    end
    if anchor and wave and not inside and Distance(p,anchor:GetLocation())<=bot:GetAttackRange()+100 then
        bot:Action_AttackUnit(anchor,true);issued=true;Trace(bot,s,'stop_deep_chase_attack_building',true)
    else
        if not inside and not wave then
            -- Cancel only the risky pursuit, then let original AI choose its next objective.
            if s.cancelTarget~=target or now>=(s.cancelUntil or 0) then
                bot:Action_ClearActions(false);s.cancelTarget=target;s.cancelUntil=now+1
                Trace(bot,s,'stop_risky_chase_original_AI',true)
            end
            s.nextOrder=now+0.25
            return true
        end
        issued=Reposition(bot,s,fountain,anchor,ancient,inside and 'escape' or 'siege')
        Trace(bot,s,issued and (inside and 'fountain_escape_order' or 'return_siege_position') or 'safe_route_unavailable',issued)
    end
    if not issued and hard then
        -- No safe route: stop the old forward chase instead of silently handing it back.
        bot:Action_ClearActions(false)
        Trace(bot,s,'fountain_chase_cancelled',true)
        s.nextOrder=now+0.25
        return true
    end
    if issued then s.nextOrder=now+0.25 end
    return issued
end
return X
