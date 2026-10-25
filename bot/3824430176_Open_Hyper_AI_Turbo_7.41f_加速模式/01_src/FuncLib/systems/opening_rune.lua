local X={};local teams={}
local function Valid(b) return b and not b:IsNull() and b:IsAlive() and b:IsHero() and not b:IsIllusion() end
local function Busy(b) return b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted() end
local function Eligible(b) return Valid(b) and not b:IsInvulnerable() and not Busy(b)
    and b:GetHealth()/math.max(1,b:GetMaxHealth())>=0.35 and b:GetActiveMode()~=BOT_MODE_RETREAT end
local function Log(b,s,p) print(string.format('[OPENING_RUNE] t=%.3f pid=%d rune=%d phase=%s team=%d distance=%.0f status=%s',DotaTime(),b:GetPlayerID(),s.id,p,b:GetTeam(),GetUnitToLocationDistance(b,s.loc),tostring(GetRuneStatus(s.id)))) end
local function Stop(b,s,reason)
    b._openingRuneLock=nil;local c=teams[b:GetTeam()]
    if Valid(b) and s.pickupAt and b:GetCurrentActionType()==BOT_ACTION_TYPE_PICK_UP_RUNE then
        b._openingOwnOrder=true;b:Action_ClearActions(true);b._openingOwnOrder=nil
    end
    if c and c[s.id] and c[s.id].pid==b:GetPlayerID() then c[s.id].finished=reason=='unavailable_release';c[s.id].deadline=DotaTime() end
    Log(b,s,reason)
end
local function Diagnose(b)
 local now=DotaTime()
 if now < -15 or now>6 or not Valid(b) or now<(b._openingDiagNext or -999) then return end
 b._openingDiagNext=now+2
 local points={}
 for _,id in ipairs({RUNE_BOUNTY_1,RUNE_BOUNTY_2,RUNE_POWERUP_1,RUNE_POWERUP_2}) do
  local p=GetRuneSpawnLocation(id)
  points[#points+1]=string.format('%d:%.0f,%s,(%.0f,%.0f)',id,GetUnitToLocationDistance(b,p),tostring(GetRuneStatus(id)),p.x,p.y)
 end
 print(string.format('[OPENING_RUNE_CHECK] t=%.2f pid=%d mode=%s eligible=%s reason=%s points=%s',
  now,b:GetPlayerID(),tostring(b:GetActiveMode()),tostring(Eligible(b)),
  b:IsInvulnerable() and 'invulnerable' or Busy(b) and 'cast_or_disable' or not Eligible(b) and 'health_or_retreat' or 'ready',table.concat(points,';')))
end
local function State(b)
    Diagnose(b)
    local now=DotaTime();local s=b._openingRuneLock
    if not Valid(b) then if s then Stop(b,s,'death_release') end;return nil end
    if now < -12 or now>6 then if s then Stop(b,s,'window_end_release') end;return nil end
    if not Eligible(b) then
        -- Casting or a short disable pauses the owner; it does not donate the rune to another caster.
        if s and (b:GetHealth()/math.max(1,b:GetMaxHealth())<0.35 or b:GetActiveMode()==BOT_MODE_RETREAT) then Stop(b,s,'unsafe_release') end
        return nil
    end
    local claims=teams[b:GetTeam()] or {};teams[b:GetTeam()]=claims
    if s then
        local status=GetRuneStatus(s.id)
        if now>=0 and status==RUNE_STATUS_AVAILABLE then
            s.seenAvailable=true;s.availableAt=s.availableAt or now
            if now-s.availableAt>=2.6 then Stop(b,s,'pickup_failed_release');return nil end
        end
        if now>=0 and status==RUNE_STATUS_MISSING and (s.seenAvailable or now>=1.2) then
            Stop(b,s,'unavailable_release');return nil
        end
        if now>s.deadline or GetUnitToLocationDistance(b,s.loc)>(now<0 and 2300 or 1500) or s.hp-b:GetHealth()>b:GetMaxHealth()*0.25 then Stop(b,s,'timeout_or_danger_release');return nil end
        return s
    end
    if now>3 then return nil end
    local radius=now<0 and 2000 or 650
    local attempted=b._openingRuneAttempts or {};b._openingRuneAttempts=attempted
    for _,id in ipairs({RUNE_BOUNTY_1,RUNE_BOUNTY_2,RUNE_POWERUP_1,RUNE_POWERUP_2}) do
        local claim=claims[id]
        if claim and not claim.finished and (now>claim.deadline or not Valid(claim.owner)) then claims[id]=nil end
        local loc=GetRuneSpawnLocation(id);local d=GetUnitToLocationDistance(b,loc)
        if not attempted[id] and not claims[id] and d<=radius and (now<0 or GetRuneStatus(id)==RUNE_STATUS_AVAILABLE) then
            local selected=true
            for i=1,5 do local a=GetTeamMember(i)
                if Valid(a) and a~=b then local ad=GetUnitToLocationDistance(a,loc)
                    if (not IsPlayerBot(a:GetPlayerID()) and ad<300) or (IsPlayerBot(a:GetPlayerID()) and Eligible(a)
                        and not a._openingRuneLock and not (a._openingRuneAttempts and a._openingRuneAttempts[id]) and ad<=radius
                        and (ad<d or ad==d and a:GetPlayerID()<b:GetPlayerID())) then selected=false;break end
                end
            end
            if selected then
                s={id=id,loc=loc,hp=b:GetHealth(),deadline=6,nextOrder=now,seenAvailable=now>=0 and GetRuneStatus(id)==RUNE_STATUS_AVAILABLE}
                claims[id]={pid=b:GetPlayerID(),owner=b,deadline=s.deadline};attempted[id]=true;b._openingRuneLock=s
                Log(b,s,now<0 and 'preposition_claim' or 'pickup_claim');return s
            end
        end
    end
end
-- Protect only the brief, real available-rune pickup; never gate the whole match.
function X.BlockOrder(b,action)
 local s=b._openingRuneLock;local now=DotaTime()
 if not s or b._openingOwnOrder or now<0 or now>6 or now>s.deadline
  or not Eligible(b) or GetRuneStatus(s.id)~=RUNE_STATUS_AVAILABLE
  or GetUnitToLocationDistance(b,s.loc)>650 then return false end
 return string.find(action,'Move',1,true)~=nil or string.find(action,'Attack',1,true)~=nil or action=='Action_ClearActions'
end
function X.GetDesire(b) return State(b) and 1.05 or 0 end
function X.Think(b)
    local s=State(b);if not s then return false end
    local now=DotaTime()
    if now>=s.nextOrder then
        if now<0 or GetRuneStatus(s.id)~=RUNE_STATUS_AVAILABLE then
            s.nextOrder=now+0.4
            if GetUnitToLocationDistance(b,s.loc)>80 then b._openingOwnOrder=true;b:Action_MoveToLocation(s.loc);b._openingOwnOrder=nil end
        else
            -- Preserve the author's pickup-in-progress guard. Reissuing the
            -- same native action every 0.2 seconds is not completion evidence.
            local action=b:GetCurrentActionType()
            if s.pickupAt and now-s.pickupAt<0.35 then return true end
            if s.pickupAt and now-(s.availableAt or s.pickupAt)>.7 and not s.nudged and GetUnitToLocationDistance(b,s.loc)<80 then
                for i=0,7 do
                    local angle=i*math.pi/4
                    local point=Vector(s.loc.x+math.cos(angle)*90,s.loc.y+math.sin(angle)*90,s.loc.z)
                    if not IsLocationPassable or IsLocationPassable(point) then
                        s.nudged=true;s.nudgePoint=point;s.nextOrder=now+0.15
                        b._openingOwnOrder=true;b:Action_ClearActions(true);b:Action_MoveToLocation(point);b._openingOwnOrder=nil
                        Log(b,s,'pickup_stalled_nudge');return true
                    end
                end
            end
            if action==BOT_ACTION_TYPE_PICK_UP_RUNE and not s.nudged then return true end
            if s.nudgePoint and GetUnitToLocationDistance(b,s.nudgePoint)>30 and now-s.pickupAt<1.5 then return true end
            if s.pickupAt and s.nudged and s.retried then return true end
            if s.pickupAt then s.retried=true end
            s.pickupAt=now;s.nextOrder=now+0.35
            b._openingOwnOrder=true
            if action~=BOT_ACTION_TYPE_PICK_UP_RUNE then b:Action_ClearActions(false)end
            b:Action_PickUpRune(s.id)
            b._openingOwnOrder=nil
            Log(b,s,'pickup_order_'..tostring(action))
            if not s.logged then s.logged=true;Log(b,s,'pickup_window') end
        end
    end
    return true
end
return X
