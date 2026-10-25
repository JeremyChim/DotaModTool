-- Combat-local evidence only. Never query the real position of an unseen hero.
local X={};local teams={}
local Inventory=require(GetScriptDirectory()..'/FuncLib/systems/inventory_reservation')
local function Valid(u) return u and not u:IsNull() and u:IsAlive() and not u:IsIllusion() end
local function Dist(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Free(b)
    if b~=GetBot() then
        local seen=b and b._detectionReady
        return Valid(b) and seen and DotaTime()-seen.at<.5 and seen.free or false
    end
    local ready=Valid(b) and not b:IsChanneling() and not b:IsUsingAbility() and not b:IsCastingAbility()
        and not b:IsStunned() and not b:IsRooted() and not b:IsMuted() and not b:IsHexed() and b:NumQueuedActions()==0
    if b then b._detectionReady={at=DotaTime(),free=ready} end
    return ready
end
local function Team(b)
    local t=teams[b:GetTeam()];if not t then t={memory={},nextPurchase=0};teams[b:GetTeam()]=t end;return t
end
local function RevealItem(b)
    for i=0,5 do local h=b:GetItemInSlot(i)
        if h then local n=h:GetName()
            if (n=='item_dust' or n=='item_ward_sentry' or n=='item_ward_dispenser' and h:GetSecondaryCharges()>0)
                and h:IsFullyCastable() then return h end
        end
    end
end
local function Covered(b,loc)
    local now=DotaTime()
    for i=1,5 do local a=GetTeamMember(i);local last=a and a._combatReveal
        if last and now-last.at<2.5 and Dist(last.loc,loc)<650 then return true end
    end
    local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
    return Fu.Site and Fu.Site.IsLocationHaveTrueSight(loc) or false
end
function X.IsSuppressed(b) return Covered(b,b:GetLocation()) end
local function Evidence(b)
    local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
    local now=DotaTime();local t=Team(b)
    if now>=(t.nextScan or 0) then
        t.nextScan=now+0.25
        local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
        for _,e in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
            if Valid(e) and e:CanBeSeen() then
                local pid=e:GetPlayerID();local m=t.memory[pid] or {};t.memory[pid]=m
                m.loc=e:GetLocation();m.at=now;m.invis=Fu.HasInvisibilityOrItem(e)
                m.burrow=e:HasModifier('modifier_nyx_assassin_burrow')
                m.exposed=Fu.HasInvisCounterBuff(e)
                m.fading=Fu.IsUnitWillGoInvisible(e);m.seen=now
            end
        end
    end
    local threat,best
    if b:HasModifier('modifier_invoker_ghost_walk_enemy')then
        for _,pid in ipairs(GetTeamPlayers(GetOpposingTeam()))do
            if GetSelectedHeroName(pid)=='npc_dota_hero_invoker'and IsHeroAlive(pid)and not Covered(b,b:GetLocation())then
                return {loc=b:GetLocation(),id=pid,reason='ghost_walk_aura'}
            end
        end
    end
    for _,id in ipairs(GetTeamPlayers(GetOpposingTeam())) do
        if IsHeroAlive(id) then
            local m=t.memory[id]
            local info=GetHeroLastSeenInfo(id);local d=info and info[1]
            -- API last-seen information is shared vision, not hidden coordinates.
            if d and d.location and d.time_since_seen<6 and (not m or now-(m.at or -100)>d.time_since_seen+0.1) then
                m=m or {};t.memory[id]=m;m.loc=d.location;m.at=now-d.time_since_seen
            end
            if m and m.loc then
                local age=now-(m.at or -100);local distance=Dist(b:GetLocation(),m.loc)
                local hurt=b:WasRecentlyDamagedByPlayer(id,1.5)
                local disappearing=age>0.15 and age<2.5 and m.invis
                    and (b:WasRecentlyDamagedByAnyHero(2) or Fu.IsGoingOnSomeone(b))
                local fading=m.fading and age<0.4 and not m.exposed
                -- Stationary burrow evidence lasts longer only while this player still deals damage.
                local name=GetSelectedHeroName(id)
                local known=name=='npc_dota_hero_nyx_assassin' or name=='npc_dota_hero_riki'
                    or name=='npc_dota_hero_bounty_hunter' or name=='npc_dota_hero_clinkz'
                local hit=hurt and age>0.15 and age<(m.burrow and 30 or 6) and (m.invis or known)
                if distance<1050 and (hit or disappearing or fading) and not Covered(b,m.loc) then
                    local score=(hit and 2000 or 1000)-distance
                    if not best or score>best then threat={loc=m.loc,id=id,burrow=m.burrow,reason=hit and 'unseen_damage' or 'recent_invisibility'};best=score end
                end
            end
        end
    end
    return threat
end
function X.Consider(b,h)
    if not Free(b) or not h or not h:IsFullyCastable() then return nil end
    local n=h:GetName();local threat=Evidence(b);if not threat then return nil end
    local distance=Dist(b:GetLocation(),threat.loc)
    local range=n=='item_dust' and 1000 or (h:GetCastRange()>0 and h:GetCastRange() or 500)
    -- Do not acquire movement to place combat detection outside cast range.
    if distance>range then return nil end
    if n=='item_ward_dispenser' and h:GetSecondaryCharges()<=0 then return nil end
    for i=1,5 do local a=GetTeamMember(i)
        if a and a~=b and IsPlayerBot(a:GetPlayerID()) and Free(a) then
            local item=RevealItem(a)
            if item then local an=item:GetName();local ad=Dist(a:GetLocation(),threat.loc)
                local ar=an=='item_dust' and 1000 or (item:GetCastRange()>0 and item:GetCastRange() or 500)
                if ad<=ar and (ad<distance or ad==distance and a:GetPlayerID()<b:GetPlayerID()) then return nil end
            end
        end
    end
    return threat.loc,threat
end
function X.Update(b)
    if DotaTime()<0 then return false end
    if not Free(b) then return false end
    local now=DotaTime();if b._revealHold and now<b._revealHold then return true end
    if now<(b._revealNext or -1) then return false end;b._revealNext=now+0.25
    Inventory.Observe(b)
    if not Inventory.Get(b) and not b._lotusSlotPin and not b:WasRecentlyDamagedByAnyHero(3)
        and #(b:GetNearbyHeroes(1000,true,BOT_MODE_NONE) or {})==0 and now-(b.itemSwapTime or 0)>11 then
        for bp=6,8 do local h=b:GetItemInSlot(bp)
            if h and (h:GetName()=='item_dust' or h:GetName()=='item_ward_sentry' or h:GetName()=='item_ward_dispenser' and h:GetSecondaryCharges()>0) then
                local slot=nil
                for i=0,5 do local gear=b:GetItemInSlot(i)
                    if not gear then slot=i;break end
                    if gear:GetName()=='item_branches' or gear:GetName()=='item_quelling_blade' then slot=slot or i end
                end
                if slot then
                    if not Inventory.Reserve(b,slot,bp,'detection',18) then return false end
                    Inventory.Swap(b,bp,slot,'detection')
                    b._revealReadyAt=now+6.2
                    print(string.format('[COMBAT_REVEAL] t=%.1f pid=%d phase=prepare_main_order item=%s',now,b:GetPlayerID(),h:GetName()))
                    return false
                end
            end
        end
    end
    for i=0,5 do local h=b:GetItemInSlot(i)
        if h then local n=h:GetName()
            if n=='item_dust' or n=='item_ward_sentry' or n=='item_ward_dispenser' then
                local loc,t=nil,nil
                if now>=(b._revealReadyAt or -1) then loc,t=X.Consider(b,h) end
                if loc then
                    if n=='item_ward_dispenser' and h:GetToggleState() then
                        b:Action_UseAbilityOnEntity(h,b);b._revealHold=now+0.2;return true
                    end
                    if n=='item_dust' then b:Action_UseAbility(h) else b:Action_UseAbilityOnLocation(h,loc) end
                    Inventory.Release(b,'detection')
                    b._combatReveal={at=now,loc=loc};b._revealHold=now+0.3
                    print(string.format('[COMBAT_REVEAL] t=%.1f pid=%d enemy=%d item=%s reason=%s phase=order',now,b:GetPlayerID(),t.id,n,t.reason))
                    return true
                end
            end
        end
    end
    return false
end
function X.Supply(b,pos,known)
    local now=DotaTime();local t=Team(b)
    if not known or not Valid(b) or now<(b._revealSupplyNext or 0) or now<t.nextPurchase then return end
    b._revealSupplyNext=now+10
    if b:GetLevel()<5 or b:GetGold()<GetItemCost('item_dust') then return end
    local count,nearby,slots=0,0,0
    for i=0,8 do if not b:GetItemInSlot(i) then slots=slots+1 end end
    if slots==0 then return end
    for i=0,15 do local h=b:GetItemInSlot(i)
        if h and (h:GetName()=='item_dust' or h:GetName()=='item_ward_sentry' or h:GetName()=='item_ward_dispenser' and h:GetSecondaryCharges()>0 or h:GetName()=='item_gem') then return end
    end
    for i=1,5 do local a=GetTeamMember(i)
        if Valid(a) then
            local carries=false
            for j=0,5 do local h=a:GetItemInSlot(j)
                if h and (h:GetName()=='item_dust' or h:GetName()=='item_ward_sentry' or h:GetName()=='item_gem' or h:GetName()=='item_ward_dispenser' and h:GetSecondaryCharges()>0) then carries=true;break end
            end
            if carries then count=count+1;if Dist(a:GetLocation(),b:GetLocation())<2500 then nearby=nearby+1 end end
        end
    end
    if count>=2 or nearby>0 or pos<4 and now<180 then return end
    if pos<4 then
        for i=1,5 do local a=GetTeamMember(i)
            if Valid(a) and a~=b and IsPlayerBot(a:GetPlayerID()) and Dist(a:GetLocation(),b:GetLocation())<1800
                and a:GetPlayerID()<b:GetPlayerID() and a:GetGold()>=GetItemCost('item_dust') then return end
        end
    end
    t.nextPurchase=now+3;b:ActionImmediate_PurchaseItem('item_dust')
    print(string.format('[COMBAT_REVEAL] t=%.1f pid=%d phase=supply_order',now,b:GetPlayerID()))
end
return X
