-- Actual damage defence for T3/barracks/T4/Ancient; no field push changes.
local X={};local teams={}
local HOLD=12
local function Valid(u) return u and not u:IsNull() and u:IsAlive() end
local function Distance(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Health(b) return b:GetHealth()/math.max(1,b:GetMaxHealth()) end
local function Bots(team)
    local list,seen={},{}
    for _,b in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
        if Valid(b) and b:GetTeam()==team and not b:IsIllusion() and IsPlayerBot(b:GetPlayerID())
            and not b:HasModifier('modifier_arc_warden_tempest_double')
            and not b:HasModifier('modifier_meepo_divided_we_stand') and not b.isBear
            and not seen[b:GetPlayerID()] then seen[b:GetPlayerID()]=true;list[#list+1]=b end
    end
    return list
end
local function Urgent(p)
    return p and (p.isAncient or p.attackers==2 or DotaTime()-p.firstHit>=1.5) and DotaTime()-p.lastHit<4
end
local function Crisis(p)
    return p and p.isAncient and DotaTime()-p.lastHit<4
        and (Health(p.building)<0.65 or DotaTime()-p.firstHit>=2)
end
local function Available(b,p)
    if DotaTime()<(b._guardFailedUntil or -1) then return false end
    if DotaTime()<(b._guardUnavailableUntil or -1) then return false end
    if b:IsInvulnerable() or Health(b)<0.5 or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted()
        or (b:WasRecentlyDamagedByAnyHero(3) and not Crisis(p)) or b:GetActiveMode()==BOT_MODE_RETREAT
        or (b:GetActiveMode()==BOT_MODE_ROSHAN and not Urgent(p)) or b:GetActiveMode()==BOT_MODE_SIDE_SHOP
        or b:GetActiveMode()==BOT_MODE_WATCHER then return false end
    local t=b:GetAttackTarget()
    return Crisis(p) or not (Valid(t) and t:IsHero() and t:CanBeSeen() and Distance(b:GetLocation(),t:GetLocation())<1400)
end
local function Release(plan,reason)
    print(string.format('[HG_GUARD] t=%.1f phase=%s',DotaTime(),reason))
    plan.done=true
    for _,b in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
        if Valid(b) and plan.members[b:GetPlayerID()] then
            b._objectiveReturn={untilTime=DotaTime()+8,source='base_guard'}
        end
    end
end
local function Diagnose(s,bot,reason,building,count)
    local now=DotaTime()
    if now<(s.nextDiag or 0) then return end
    s.nextDiag=now+8
    print(string.format('[HG_GUARD_CHECK] t=%.1f team=%d reason=%s building=%s nearby=%d',
        now,bot:GetTeam(),reason,building and building:GetUnitName() or 'none',count or 0))
end
-- Per-player throttling survives mode changes; diagnostics never acquire movement.
local function Track(b,p,reason)
    local now=DotaTime();local d=b._hgGuardDiagnostic or {};b._hgGuardDiagnostic=d
    if now<(d.next or 0) and d.plan==p then return end
    d.next=now+3;d.plan=p
    print(string.format('[HG_GUARD_TRACK] t=%.1f team=%d pid=%d lane=%d mode=%s distance=%.0f reason=%s',
        now,b:GetTeam(),b:GetPlayerID(),p.lane,tostring(b:GetActiveMode()),
        Distance(b:GetLocation(),p.building:GetLocation()),reason))
end
local function State(b)
    local team=b:GetTeam();local now=DotaTime()
    local s=teams[team]
    if not s then s={nextScan=0,hp={},damageAt={},lossAt={}};teams[team]=s end
    if now<s.nextScan then return s end
    s.nextScan=now+0.5
    local ancient=GetAncient(team)
    local buildings={}
    for _,v in ipairs({{TOWER_TOP_3,LANE_TOP},{TOWER_MID_3,LANE_MID},{TOWER_BOT_3,LANE_BOT}}) do
        local tower=GetTower(team,v[1]);if Valid(tower) then buildings[#buildings+1]={u=tower,lane=v[2]} end
    end
    -- Barracks IDs 0..5: top melee/ranged, mid melee/ranged, bottom melee/ranged.
    for id=0,5 do local u=GetBarracks(team,id)
        if Valid(u) then buildings[#buildings+1]={u=u,lane=id<2 and LANE_TOP or id<4 and LANE_MID or LANE_BOT} end
    end
    for _,id in ipairs({TOWER_BASE_1 or 9,TOWER_BASE_2 or 10}) do
        local u=GetTower(team,id)
        if Valid(u) then
            local duplicate=false;for _,v in ipairs(buildings) do if v.u==u then duplicate=true end end
            if not duplicate then buildings[#buildings+1]={u=u,lane=LANE_MID} end
        end
    end
    if Valid(ancient) then buildings[#buildings+1]={u=ancient,lane=LANE_MID} end
    local victim,attacker,count=nil,nil,0
    local damagedBuilding,seen,targetMatches=nil,0,0
    local enemies,unique={},{}
    local function Add(list)
        for _,u in ipairs(list or {}) do
            if not unique[u] then unique[u]=true;enemies[#enemies+1]=u end
        end
    end
    Add(GetUnitList(UNIT_LIST_ENEMY_HEROES))
    if UNIT_LIST_ENEMIES then Add(GetUnitList(UNIT_LIST_ENEMIES)) end
    local baseEnemies=0
    for _,e in ipairs(enemies) do
        if Valid(e) and e:IsHero() and not e:IsIllusion() and e:CanBeSeen() and Valid(ancient)
            and Distance(e:GetLocation(),ancient:GetLocation())<3300 then baseEnemies=baseEnemies+1 end
    end
    for _,v in ipairs(buildings) do
        -- These are our own buildings. Their HP is authoritative even if the
        -- bot visibility API reports false, so do not lose a base damage episode.
        local hp=v.u:GetHealth()
        local damaged=hp and s.hp[v.u] and hp<s.hp[v.u]-1
        s.hp[v.u]=hp
        if damaged then
            damagedBuilding=v.u;s.damageAt[v.u]=now
            local previous=s.lossAt[v.u];s.lossAt[v.u]=now
            -- Ancient: one actual HP loss is urgent. Other base buildings need repeated loss
            -- unless an attack target confirms the first hit below.
            if v.u==ancient or (previous and now-previous<=2) then
                local priority=v.u==ancient and 3 or 1
                if not victim or priority>=(victim.priority or 0) then victim=v;victim.priority=priority;attacker=nil end
            end
        end
        for _,e in ipairs(enemies) do
            if Valid(e) and e:IsHero() and not e:IsIllusion() and e:CanBeSeen() then
                seen=seen+1;if e:GetAttackTarget()==v.u then targetMatches=targetMatches+1 end
            end
            if Valid(e) and not e:IsIllusion() and e:CanBeSeen()
                and e:GetAttackTarget()==v.u and damaged
                and Distance(e:GetLocation(),v.u:GetLocation())<=e:GetAttackRange()+300 then
                local priority=v.u==ancient and 3 or (v.lane==LANE_MID and 2 or 1)
                if not victim or priority>=(victim.priority or 0) then
                    victim=v;victim.priority=priority;attacker=e
                end
            end
        end
    end
    if damagedBuilding and not victim then
        Diagnose(s,b,targetMatches>0 and 'damage_target_out_of_range' or seen>0 and 'damage_no_hero_attack_target' or 'damage_no_visible_hero',damagedBuilding,0)
    elseif not damagedBuilding and not victim and baseEnemies>0 then
        Diagnose(s,b,'heroes_near_base_no_observed_building_damage',nil,baseEnemies)
    end
    local plan=s.plan
    -- One lane is one damage episode. Alternating rax/T3 hits must not reset
    -- the selected defenders or their escalation timer every half second.
    if victim and plan and not plan.done and victim.lane==plan.lane
        and victim.u~=plan.building and Valid(plan.building)
        and now-(s.damageAt[plan.building] or -999)<2
        and victim.u~=ancient
        and not string.find(victim.u:GetUnitName() or '', 'tower4',1,true) then
        victim={u=plan.building,lane=plan.lane};attacker=plan.attacker
        if now>=(s.sameLaneLogNext or 0) then
            s.sameLaneLogNext=now+4
            print(string.format('[HG_GUARD] t=%.1f phase=retain_same_lane_target lane=%d',now,plan.lane))
        end
    end
    -- Alternating hits on two lanes must not cancel and recreate the same return
    -- every half-second. Keep a still-damaged lane, but never delay a new T4/Ancient crisis.
    if victim and plan and not plan.done and not plan.isAncient and victim.lane~=plan.lane
        and victim.u~=ancient and not string.find(victim.u:GetUnitName() or '', 'tower4',1,true)
        and Valid(plan.building) and now-(s.damageAt[plan.building] or -999)<2 then
        victim={u=plan.building,lane=plan.lane};attacker=plan.attacker
        if now>=(s.laneHoldLogNext or 0) then
            s.laneHoldLogNext=now+4
            print(string.format('[HG_GUARD] t=%.1f phase=retain_damaged_lane lane=%d',now,plan.lane))
        end
    end
    -- Do not redirect Ancient defenders to a simultaneously damaged side lane.
    -- The deadline uses observed Ancient damage and is never renewed by this gate.
    if victim and plan and not plan.done and plan.isAncient and victim.u~=ancient
        and Valid(plan.building) and now-plan.lastHit<4 then victim=nil end
    if victim then
        for _,e in ipairs(enemies) do
            if Valid(e) and e:IsHero() and not e:IsIllusion() and e:CanBeSeen()
                and Distance(e:GetLocation(),victim.u:GetLocation())<1800 then count=count+1 end
        end
        if not plan or plan.done or plan.lane~=victim.lane then
            if plan and not plan.done then Release(plan,'new_lane_threat') end
            plan={building=victim.u,lane=victim.lane,firstHit=now,lastHit=now,members={},attacker=attacker}
            s.plan=plan
            print(string.format('[HG_GUARD] t=%.1f phase=actual_building_damage lane=%d hp=%.2f',now,plan.lane,Health(plan.building)))
        end
        if plan.building~=victim.u then
            local promotedAncient=victim.u==ancient and not plan.isAncient
            plan.building=victim.u;plan.damageHealth=victim.u:GetHealth()
            if promotedAncient then plan.damageStarted=now;plan.escalation=0 end
            plan.lastObservedHealth=victim.u:GetHealth()
            print(string.format('[HG_GUARD] t=%.1f phase=same_lane_handoff lane=%d',now,plan.lane))
        end
        -- Count a continuous damage episode, not the age of the entire lane task.
        if not plan.damageStarted or now-plan.lastHit>3 then
            plan.damageStarted=now;plan.damageHealth=victim.u:GetHealth();plan.escalation=0
        end
        plan.lastHit=now;plan.attacker=attacker;plan.isAncient=victim.u==ancient
        local actual=0
        for _,e in ipairs(enemies) do
            if Valid(e) and not e:IsIllusion() and e:CanBeSeen() then
                local target=e:GetAttackTarget()
                for _,v in ipairs(buildings) do
                    if v.lane==plan.lane and target==v.u and now-(s.damageAt[v.u] or -100)<2
                        and Distance(e:GetLocation(),v.u:GetLocation())<=e:GetAttackRange()+300 then actual=actual+1;break end
                end
            end
        end
        plan.attackers=math.min(2,actual)
    end
    if not plan then return s end
    if not Valid(plan.building) then
        local replacement,cost
        for _,v in ipairs(buildings) do
            if v.lane==plan.lane and Valid(v.u) then
                local d=Valid(plan.attacker) and Distance(plan.attacker:GetLocation(),v.u:GetLocation()) or 0
                if not cost or d<cost then replacement,cost=v.u,d end
            end
        end
        if replacement and now-plan.lastHit<HOLD then
            local promotedAncient=replacement==ancient and not plan.isAncient
            plan.building=replacement;plan.isAncient=replacement==ancient
            plan.damageHealth=replacement:GetHealth()
            if promotedAncient then plan.damageStarted=now;plan.escalation=0 end
            plan.lastObservedHealth=replacement:GetHealth()
            print(string.format('[HG_GUARD] t=%.1f phase=same_lane_handoff lane=%d',now,plan.lane))
        else Release(plan,'lane_buildings_destroyed_original_AI');s.plan=nil;return s end
    end
    local nearby=0
    for _,e in ipairs(enemies) do
        if Valid(e) and e:IsHero() and not e:IsIllusion() and e:CanBeSeen()
            and Distance(e:GetLocation(),plan.building:GetLocation())<1800 then nearby=nearby+1 end
    end
    if nearby>2 then Diagnose(s,b,'multiple_enemies_keep_selected_default_defence',plan.building,nearby) end
    local observedHealth=plan.building:GetHealth()
    if plan.lastObservedHealth and observedHealth<plan.lastObservedHealth then
        plan.lastHit=now;plan.observedHit=now
    end
    plan.lastObservedHealth=observedHealth
    if now-plan.lastHit>=HOLD then Release(plan,'quiet_release_original_AI');s.plan=nil;return s end
    local roster=Bots(team);local alive={};local size=0
    for _,ally in ipairs(roster) do alive[ally:GetPlayerID()]=ally end
    for pid,order in pairs(plan.members) do
        if not alive[pid] or now<(alive[pid]._guardFailedUntil or -1) then plan.members[pid]=nil
        else
            local ally=alive[pid];local target=ally:GetAttackTarget()
            local blocked=not Crisis(plan) and not ally._guardTravel and not ally:IsChanneling()
                and not ally:IsUsingAbility() and not ally:IsCastingAbility()
                and Distance(ally:GetLocation(),plan.building:GetLocation())>2000
                and (ally:WasRecentlyDamagedByAnyHero(3) or (Valid(target) and target:IsHero()
                    and target:CanBeSeen() and Distance(ally:GetLocation(),target:GetLocation())<1400))
            plan.blockedSince=plan.blockedSince or {}
            if blocked then plan.blockedSince[pid]=plan.blockedSince[pid] or now
            else plan.blockedSince[pid]=nil end
            if plan.blockedSince[pid] and now-plan.blockedSince[pid]>=6 then
                plan.members[pid]=nil;plan.blockedSince[pid]=nil;ally._guardUnavailableUntil=now+8
                print(string.format('[HG_GUARD] t=%.1f phase=replace_distant_combat pid=%d',now,pid))
            else size=size+1 end
        end
    end
    local ordered={};for pid in pairs(plan.members) do ordered[#ordered+1]=pid end
    table.sort(ordered,function(a,b) return plan.members[a]<plan.members[b] or plan.members[a]==plan.members[b] and a<b end)
    for i,pid in ipairs(ordered) do plan.members[pid]=i end
    local required=size>0 and size or 1
    -- Add the second only for sustained damage while the first has not contained it.
    if victim and nearby<=2 and ((plan.attackers==2 and (nearby>0 or plan.isAncient))
        or (now-plan.firstHit>=5 and Health(plan.building)<0.65)) then required=2 end
    if plan.isAncient and (victim or (plan.observedHit and now-plan.observedHit<4)) then
        required=math.max(2,size)
        local duration=now-(plan.damageStarted or now)
        local loss=((plan.damageHealth or plan.building:GetHealth())-plan.building:GetHealth())/math.max(1,plan.building:GetMaxHealth())
        local level=0
        if duration>=3 and (loss>=0.04 or Health(plan.building)<0.65) then level=1;required=math.max(required,3) end
        if (duration>=6 and loss>=0.08) or (duration>=1 and Health(plan.building)<0.35) then
            level=2;required=#roster
        end
        if level>(plan.escalation or 0) then
            plan.escalation=level
            print(string.format('[HG_GUARD] t=%.1f phase=ancient_escalation level=%d required=%d loss=%.3f',now,level,required,loss))
        end
    end
    -- Larger assaults stay with original team defence; keep already recalled members.
    if nearby>2 then required=math.max(required,2,size) end
    -- During the quiet hold, retain survivors but never recruit a fresh defender.
    if not victim and not (plan.isAncient and plan.observedHit and now-plan.observedHit<4) then required=size end
    while size<required do
        local chosen,score=nil,nil
        for _,ally in ipairs(roster) do
            local pid=ally:GetPlayerID()
            if not plan.members[pid] and Available(ally,plan) then
                local cost=Distance(ally:GetLocation(),plan.building:GetLocation())
                if Urgent(plan) then
                    local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
                    if Fu.Utils.EstimateDefendArrival then cost=Fu.Utils.EstimateDefendArrival(ally,plan.building:GetLocation())*350 end
                end
                -- Prefer a nearby defender; avoid pulling a second distant hero needlessly.
                if cost<1800 then cost=cost-2000 end
                cost=cost-ally:GetAttackRange()*0.5
                -- Wards take attacks, not spell damage. Arrival remains the main cost.
                local ward=Valid(plan.attacker) and string.find(plan.attacker:GetUnitName() or '', 'shadow_shaman_ward',1,true)
                if ward and ally.GetSecondsPerAttack then cost=cost-math.min(500,200/math.max(0.2,ally:GetSecondsPerAttack())) end
                if not score or cost<score then chosen,score=ally,cost end
            end
        end
        if not chosen then Diagnose(s,b,'no_available_defender',plan.building,nearby);break end
        size=size+1;plan.members[chosen:GetPlayerID()]=size
        print(string.format('[HG_GUARD] t=%.1f phase=assigned pid=%d slot=%d',now,chosen:GetPlayerID(),size))
    end
    return s
end
function X.HasActiveThreat(b)
    local p=State(b).plan
    return p~=nil and not p.done and DotaTime()-p.lastHit<4
end
function X.GetTPDestination(b)
    local p=X.Get(b)
    if p then return p.building:GetLocation(),p.isAncient,Urgent(p),Crisis(p) end
    return nil
end
function X.Get(b)
    X.ProtectReturn(b)
    local s=State(b);local p=s.plan
    if p and p.members[b:GetPlayerID()] and Valid(p.building) then
        if Health(b)<0.35 or b:GetActiveMode()==BOT_MODE_RETREAT then p.members[b:GetPlayerID()]=nil
        else
            local mode=b:GetActiveMode()
            if (mode==BOT_MODE_ROSHAN and not Urgent(p)) or mode==BOT_MODE_SIDE_SHOP or mode==BOT_MODE_WATCHER then Track(b,p,'major_objective');return nil end
            local defending=mode==BOT_MODE_DEFEND_TOWER_TOP or mode==BOT_MODE_DEFEND_TOWER_MID or mode==BOT_MODE_DEFEND_TOWER_BOT
            if b:IsChanneling() and not defending then Track(b,p,'other_channel');return nil end
            local target=b:GetAttackTarget()
            if Distance(b:GetLocation(),p.building:GetLocation())>2000
                and not Crisis(p)
                and (b:WasRecentlyDamagedByAnyHero(3) or (Valid(target) and target:IsHero() and target:CanBeSeen()
                    and Distance(b:GetLocation(),target:GetLocation())<1400)) then Track(b,p,'distant_combat');return nil end
            return p
        end
    end
    b._hgGuardOrder=nil
    return nil
end
function X.Think(b,lane)
    local p=X.Get(b)
    if not p or p.lane~=lane or Distance(b:GetLocation(),p.building:GetLocation())>1500 then return false end
    if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted() then return true end
    if b._hgGuardOrder~=p then
        print(string.format('[HG_GUARD] t=%.1f phase=local_guard_active pid=%d lane=%d',DotaTime(),b:GetPlayerID(),lane))
    end
    b._hgGuardOrder=p
    local anchor=p.building:GetLocation()
    local target,score=nil,nil
    local list={};for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do list[#list+1]=u end
    if UNIT_LIST_ENEMIES then for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do list[#list+1]=u end end
    -- Prefer units actually attacking the protected building, including ranged siege creeps.
    for _,u in ipairs(list) do
        if Valid(u) and u:CanBeSeen() and not u:IsIllusion()
            and Distance(u:GetLocation(),anchor)<2000
            and (u:GetAttackTarget()==p.building or (DotaTime()-p.lastHit<2 and not u:IsHero()
                and not u:IsBuilding() and Distance(u:GetLocation(),anchor)<=u:GetAttackRange()+300)) then
            local name=u:GetUnitName() or ''
            local weight=(string.find(name,'siege',1,true) and 3000 or u:IsHero() and 2000 or 1000)
                -Distance(b:GetLocation(),u:GetLocation())*0.1
            if not score or weight>score then target,score=u,weight end
        end
    end
    if target then
        if b:GetAttackTarget()~=target and DotaTime()>=(b._guardAttackNext or -1) then
            b._guardAttackNext=DotaTime()+0.6;b:Action_AttackUnit(target,false)
        end
        return true
    end
    if Valid(p.attacker) and p.attacker:CanBeSeen() and Distance(p.attacker:GetLocation(),anchor)<1200 then
        b:Action_AttackUnit(p.attacker,true);return true
    end
    -- Stay near the attacked building, clear the wave, and do not chase into trees.
    local creeps=b:GetNearbyLaneCreeps(900,true) or {}
    for _,c in ipairs(creeps) do
        if Valid(c) and Distance(c:GetLocation(),anchor)<1200 then b:Action_AttackUnit(c,true);return true end
    end
    if Distance(b:GetLocation(),anchor)>450 then b:Action_MoveToLocation(anchor)
    else b:Action_AttackMove(anchor) end
    return true
end
-- AbilityUsageThink already calls HandleIdleBotState each frame. Use that
-- live callback, while leaving all three Valve default defence Thinks intact.
function X.Priority(p)
    return p.isAncient and 0.98 or Urgent(p) and 0.94 or 0.82
end
-- Bound only selected T4/Ancient defenders while their damage plan is alive.
-- Normal field movement, local combat, spells, survival retreat and TP stay native.
function X.BlockBaseOrder(b,action,target)
    local area=b._guardBaseArea
    if not area or b._guardBoundaryOwn or DotaTime()>=area.untilTime or not b:IsAlive()
        or b:GetActiveMode()==BOT_MODE_RETREAT or Health(b)<0.3
        or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() then return false end
    local location=b:GetLocation()
    if Distance(location,area.anchor)>1800 then return false end
    local goal
    if string.find(action,'Move',1,true) then goal=target
    elseif string.find(action,'AttackUnit',1,true) and target and not target:IsNull() and target:IsHero() then goal=target:GetLocation()
    end
    if not goal or not goal.x or Distance(goal,area.anchor)<=1600
        or Distance(goal,area.anchor)<Distance(location,area.anchor) then return false end
    if DotaTime()>=(b._guardBoundaryNext or 0) then
        b._guardBoundaryNext=DotaTime()+0.6;b._guardBoundaryOwn=true
        b:Action_MoveToLocation(area.anchor);b._guardBoundaryOwn=nil
        if DotaTime()>=(b._guardBoundaryLog or 0) then
            b._guardBoundaryLog=DotaTime()+3
            print(string.format('[BASE_GUARD_AREA] t=%.2f pid=%d phase=keep_near_building',DotaTime(),b:GetPlayerID()))
        end
    end
    return true
end
function X.ThinkActive(b)
    if not b:IsAlive() or not b:IsHero() or b:IsIllusion() or b:IsInvulnerable() then return false end
    local p=X.Get(b)
    if not p then b._guardBaseArea=nil;return false end
    local name=p.building:GetUnitName() or ''
    local base=p.isAncient or string.find(name,'tower4',1,true)~=nil
    if base then b._guardBaseArea={anchor=p.building:GetLocation(),untilTime=DotaTime()+1}
    else b._guardBaseArea=nil end
    if X.ProtectReturn(b) then return true end
    if require(GetScriptDirectory()..'/FuncLib/systems/defend_execution').Try(b)then return true end
    if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted()
        or b.NumQueuedActions and b:NumQueuedActions()>0 then
        Track(b,p,'protected_action');return false
    end
    local mode=b:GetActiveMode()
    local lane=mode==BOT_MODE_DEFEND_TOWER_TOP and LANE_TOP
        or mode==BOT_MODE_DEFEND_TOWER_MID and LANE_MID
        or mode==BOT_MODE_DEFEND_TOWER_BOT and LANE_BOT
    local urgent=p.isAncient or Urgent(p)
    if lane~=p.lane and not urgent then Track(b,p,'waiting_defend_mode');return false end
    local distance=Distance(b:GetLocation(),p.building:GetLocation())
    if DotaTime()<(b._defendTPPending or -1) then Track(b,p,'tp_start_protected');return true end
    if distance>1500 then
        if not urgent then Track(b,p,'travelling_original_AI');return false end
        if DotaTime()<(b._hgGuardNextOrder or 0) then return true end
        b._hgGuardNextOrder=DotaTime()+0.5
        local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
        -- Reuse existing TP safety/landing policy verbatim; never alter generic TP handling.
        if Fu.Utils and Fu.Utils.ConsiderTPToTarget and DotaTime()>=(b._hgGuardNextTP or 0) then
            b._hgGuardNextTP=DotaTime()+2
            local ok,issued=pcall(Fu.Utils.ConsiderTPToTarget,b,p.building:GetLocation(),true,{urgent=true,combatEmergency=Crisis(p)})
            if ok and issued then b._hgGuardOrder=p;Track(b,p,'selected_return_tp');return true end
            if not ok then Track(b,p,'tp_helper_failed_walk_fallback: '..tostring(issued)) end
        end
        b._hgGuardOrder=p
        b:Action_MoveToLocation(p.building:GetLocation())
        Track(b,p,'selected_return_walk');return true
    end
    if base and X.LocalClearThink(b) then Track(b,p,'local_coordinated_clear');return true end
    Track(b,p,'local_native_handoff')
    return false
end
-- Only a winning mode may perform the extra siege-creep clearing actions.
local function ClearTarget(b,p)
 local best,score
 p.clearClaims=p.clearClaims or {}
 local now=DotaTime();local pid=b:GetPlayerID()
 -- Claims expire quickly; death, movement and mode changes cannot reserve a target.
 for id,claim in pairs(p.clearClaims) do
  if claim.untilTime<=now or not p.members[id] or not Valid(claim.unit) then p.clearClaims[id]=nil end
 end
 for _,c in ipairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
  local attacked=Valid(c) and c:GetAttackTarget()
  local ownBase=attacked==p.building or Valid(attacked) and attacked:IsBuilding()
   and attacked:GetTeam()==b:GetTeam() and Distance(attacked:GetLocation(),p.building:GetLocation())<1600
  if Valid(c) and c:CanBeSeen() and not c:IsHero() and not c:IsBuilding() and not c:IsIllusion()
   and ownBase and Distance(c:GetLocation(),p.building:GetLocation())<math.min(2000,1400+b:GetAttackRange()) then
   local name=c:GetUnitName() or ''
   local value=(string.find(name,'shadow_shaman_ward',1,true) and 3800 or string.find(name,'siege',1,true) and 3000 or 1000)-Distance(b:GetLocation(),c:GetLocation())
   local assigned=0
   for id,claim in pairs(p.clearClaims) do if id~=pid and claim.target==c then assigned=assigned+1 end end
   local damage=b.GetAttackDamage and b:GetAttackDamage() or 100
   if assigned>0 and c:GetHealth()<=damage*1.2 then value=value-4000
   else value=value-assigned*350 end
   if not score or value>score then best,score=c,value end
  end
 end
 return best
end
function X.LocalClearDesire(b)
 local p=X.Get(b)
 if not p or DotaTime()-p.lastHit>=4 or Health(b)<0.35
  or b:IsInvulnerable() or b:GetActiveMode()==BOT_MODE_RETREAT
  or Distance(b:GetLocation(),p.building:GetLocation())>1500 then b._guardClearTarget=nil;return 0 end
 local target=ClearTarget(b,p)
 if not target then b._guardClearTarget=nil;return 0 end
 for _,e in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
  if Valid(e) and e:CanBeSeen() and not e:IsIllusion() and Distance(b:GetLocation(),e:GetLocation())<1400 then
   -- During a critical Ancient crisis, a healthy safe defender may clear an
   -- already reachable attacker. Keep the first on combat when another is local.
   local otherLocal=false
   for _,a in ipairs(Bots(b:GetTeam())) do
    if a~=b and p.members[a:GetPlayerID()] and Distance(a:GetLocation(),p.building:GetLocation())<1500 then otherLocal=true;break end
   end
   local critical=p.isAncient and (Health(p.building)<0.65 or DotaTime()-(p.damageStarted or p.firstHit)>=3)
   if not critical or (p.members[b:GetPlayerID()]==1 and otherLocal)
    or Health(b)<0.5 or b:WasRecentlyDamagedByAnyHero(1) or e:GetAttackTarget()==b
    or Distance(b:GetLocation(),e:GetLocation())<math.max(500,e:GetAttackRange()+100)
    or Distance(b:GetLocation(),target:GetLocation())>b:GetAttackRange()+120 then
    b._guardClearTarget=nil;return 0
   end
  end
 end
 p.clearClaims[b:GetPlayerID()]={unit=b,target=target,untilTime=DotaTime()+1}
 b._guardClearTarget=target
 return 0.99
end
function X.LocalClearThink(b)
 if X.LocalClearDesire(b)<=0 then return false end
 if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted() then return true end
 local target=b._guardClearTarget
 b._guardClearOrder={target=target,untilTime=DotaTime()+0.7}
 if b:GetAttackTarget()~=target and DotaTime()>=(b._guardAttackNext or -1) then
  b._guardAttackNext=DotaTime()+0.6
  b._guardClearOwnOrder=true;b:Action_AttackUnit(target,false);b._guardClearOwnOrder=nil
  if DotaTime()>=(b._guardClearLog or 0) then
   b._guardClearLog=DotaTime()+2
   print(string.format('[BASE_CLEAR] t=%.2f pid=%d target=%s building=%s',DotaTime(),b:GetPlayerID(),target:GetUnitName(),X.Get(b).building:GetUnitName()))
  end
 end
 return true
end

-- Only a just-issued selected defender's safe building-attacker clear is held.
-- Spells, items, channeling and survival actions keep their normal priority.
function X.BlockClearOrder(b,action,target)
 local order=b._guardClearOrder
 if not order or b._guardClearOwnOrder or DotaTime()>=order.untilTime then return false end
 if string.find(action,'UseAbility',1,true) then return false end
 if b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() then return false end
 if X.LocalClearDesire(b)<=0 or b._guardClearTarget~=order.target then
  b._guardClearOrder=nil;return false
 end
 if string.find(action,'AttackUnit',1,true) and target==order.target then return false end
 return string.find(action,'Move',1,true)~=nil or string.find(action,'Attack',1,true)~=nil
  or action=='Action_ClearActions'
end

function X.ProtectReturn(b)
 local t=b._guardTravel;if not t then return false end
 local now=DotaTime()
 local function Done(phase,failed)
  print(string.format('[BASE_TP_RESULT] t=%.3f pid=%d phase=%s distance=%.0f',now,b:GetPlayerID(),phase,Distance(b:GetLocation(),t.destination)))
  b._guardTravel=nil;b._defendTPPending=nil
  if failed then b._guardFailedUntil=now+8 end
  return false
 end
 if not b:IsAlive() then return Done('death',true) end
 if Distance(b:GetLocation(),t.destination)<900 then require(GetScriptDirectory()..'/FuncLib/systems/defend_execution').AfterLand(b);return Done('landed',false) end
 if Health(b)<0.25 and b:WasRecentlyDamagedByAnyHero(1) then return Done('emergency_yield',false) end
 local channel=b:HasModifier('modifier_teleporting') or b:IsChanneling()
 if channel then
  if t.phase~='channeling' then t.phase='channeling';print(string.format('[BASE_TP_RESULT] t=%.3f pid=%d phase=channeling',now,b:GetPlayerID())) end
  if now>t.deadline then return Done('channel_timeout',true) end
  return true
 end
 if t.phase=='channeling' then return Done('interrupted',true) end
 if now<=t.at+1.2 then return true end
 return Done('not_started',true)
end
return X
