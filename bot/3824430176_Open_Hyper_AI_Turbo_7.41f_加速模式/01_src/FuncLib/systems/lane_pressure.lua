-- Shared, short-lived pressure signal. No movement/attack orders.
local X={}
function X.Get(bot)
    local now=DotaTime()
    local s=bot._lanePressure or {next=0,hp=bot:GetHealth(),last=now,untilTime=-1}
    bot._lanePressure=s
    if now<0 or now>600 then return {active=false} end
    if now<s.next then return {active=now<s.untilTime,target=s.target} end
    s.next=now+0.25
    local hp=bot:GetHealth();local lost=s.hp-hp;local elapsed=now-s.last
    s.hp=hp;s.last=now
    local target,count,hero=nil,0,false
    if UNIT_LIST_ENEMIES then
        for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
            if u and not u:IsNull() and u:IsAlive() and u:CanBeSeen() and not u:IsBuilding()
                and u:GetAttackTarget()==bot and GetUnitToUnitDistance(bot,u)<1100 then
                count=count+1
                if not target or u:IsHero() then target=u;hero=u:IsHero() end
            end
        end
    end
    -- Require real recent damage, rather than treating an enemy's presence as a threat.
    if elapsed<=0.6 and lost>=math.max(8,bot:GetMaxHealth()*0.01)
        and (target or lost>=bot:GetMaxHealth()*0.06) then
        s.untilTime=now+1.5;s.target=target
        if now>=(s.diagNext or 0) then
            s.diagNext=now+5
            print(string.format('[LANE_PRESSURE] t=%.1f pid=%d loss=%.0f attackers=%d hero=%s',
                now,bot:GetPlayerID(),lost,count,tostring(hero)))
        end
    end
    return {active=now<s.untilTime,target=s.target}
end
return X
