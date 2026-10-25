-- Early side-lane lotus visits. Fixed starts: 1:30, 3:00, 4:30, 6:00.
-- A round never restarts after success/death; no visits after the fourth round.
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')
local X = {}
local STARTS = {90, 180, 270, 360}
local EMPTY_WAIT = 1
local ROUND_LIMIT = 90
local DESIRE = 0.82 -- above ordinary laning; combat explicitly yields below
local LOTUS_VALUE = {item_famango = 1, item_great_famango = 3, item_greater_famango = 9}

local function Trace(bot, state, phase)
    if state.phase == phase then return end
    state.phase = phase
    print(string.format('[LOTUS_V2] t=%.1f hero=%s round=%d lane=%s phase=%s',
        DotaTime(), bot:GetUnitName(), state.slot, tostring(state.lane), phase))
end

local function AnnounceLoaded(bot, state)
    if state.announced then return end
    state.announced = true
    print('[LOTUS_V2] loaded for '..bot:GetUnitName()..'; executor=TEAM_ROAM')
    local lowest = bot:GetPlayerID()
    for _, pid in pairs(GetTeamPlayers(bot:GetTeam())) do
        if IsPlayerBot(pid) and pid < lowest then lowest = pid end
    end
    if lowest == bot:GetPlayerID() then
        bot:ActionImmediate_Chat('[Lotus v2] loaded: 1:30 / 3:00 / 4:30 / 6:00', true)
    end
end

local function Valid(unit)
    return unit ~= nil and not unit:IsNull()
end

local function Eligible(bot)
    return Valid(bot) and bot:IsHero() and not bot:IsIllusion()
        and not bot:HasModifier('modifier_arc_warden_tempest_double')
        and not bot:HasModifier('modifier_meepo_divided_we_stand')
        and not bot.isBear
end

local function Inventory(bot)
    local count, free = 0, false
    for slot = 0, 8 do
        local item = bot:GetItemInSlot(slot)
        if item == nil then
            free = true
        elseif LOTUS_VALUE[item:GetName()] then
            count = count + LOTUS_VALUE[item:GetName()] * math.max(1, item:GetCurrentCharges())
        end
    end
    return count, free
end

local function StopOwnAction(bot, state)
    -- Never cancel an order issued by the original combat/retreat modes.
    if state.issuedAction and bot:IsAlive()
        and (bot:GetActiveMode() == BOT_MODE_TEAM_ROAM or bot:GetActiveMode() == BOT_MODE_LOTUS_POOL) then
        bot:Action_ClearActions(true)
    end
    state.issuedAction = false
end

local function Finish(bot, state, reason)
    StopOwnAction(bot, state)
    state.active = false
    state.reason = reason
    state.arrivedAt = nil
    state.pool = nil
    Trace(bot, state, reason)
end

local function IsEnemyHero(bot, unit)
    return Valid(unit) and unit:IsAlive() and unit:IsHero()
        and unit:GetTeam() ~= bot:GetTeam() and unit:CanBeSeen()
end

local function Combat(bot)
    -- Lane opponents merely visible at 1600 must not prevent the scheduled departure.
    -- Yield in actual engagement range; stale GetTarget() values are not a fight.
    for _, enemy in pairs(bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE) or {}) do
        if IsEnemyHero(bot, enemy) then
            local range = math.min(900, math.max(500, enemy:GetAttackRange() + 150, bot:GetAttackRange() + 150))
            if GetUnitToUnitDistance(bot, enemy) <= range then return true end
        end
    end
    return bot:WasRecentlyDamagedByAnyHero(3)
        or Fu.IsRetreating(bot)
end

local function FindPool(bot, lane)
    local best, bestScore
    local lists = {UNIT_LIST_ALL}
    if UNIT_LIST_ALLIED_BUILDINGS then lists[#lists + 1] = UNIT_LIST_ALLIED_BUILDINGS end
    if UNIT_LIST_ENEMY_BUILDINGS then lists[#lists + 1] = UNIT_LIST_ENEMY_BUILDINGS end
    for _, list in ipairs(lists) do
        for _, unit in pairs(GetUnitList(list) or {}) do
            if Valid(unit) and not unit:IsHero() then
                local name = string.lower(unit:GetUnitName() or '')
                -- Static objectives can expose localization tokens instead of NPC class names.
                local isPool = string.find(name, 'lotus', 1, true) ~= nil
                if not isPool and unit:IsBuilding() and unit:CanBeSeen() then
                    local ok, ability = pcall(function() return unit:GetAbilityByName('ability_lotus_pool') end)
                    isPool = ok and ability ~= nil
                end
                if isPool then
                    -- Assign by proximity to the side-lane path, rather than hardcoded map coordinates.
                    local location = unit:GetLocation()
                    local along, distance = GetAmountAlongLane(lane, location)
                    local score = type(along) == 'table' and along.distance or distance
                    if type(score) ~= 'number' then score = GetUnitToLocationDistance(bot, location) end
                    if bestScore == nil or score < bestScore then
                        best, bestScore = unit, score
                    end
                end
            end
        end
    end
    return best
end

function X.Update(bot)
    if not Eligible(bot) then return nil end
    local now = DotaTime()
    local state = bot._earlyLotus
    if state == nil then
        state = {slot = 0, active = false, issuedAction = false}
        bot._earlyLotus = state
        AnnounceLoaded(bot, state)
    end

    -- Advance to the latest scheduled round only: never replay missed rounds.
    local slot = 0
    for index, start in ipairs(STARTS) do
        if now >= start then slot = index end
    end
    if slot > state.slot then
        if state.active then Finish(bot, state, 'next_round') end
        state.slot = slot
        state.deadline = STARTS[slot] + ROUND_LIMIT
        state.lane = Fu.GetExpectedLane(bot)
        state.active = bot:IsAlive() and not bot:IsInvulnerable()
            and (state.lane == LANE_TOP or state.lane == LANE_BOT)
            and now < state.deadline
        state.arrivedAt, state.pool, state.nextOrderAt, state.nextSearchAt = nil, nil, 0, 0
        state.inventory = Inventory(bot)
        state.deaths = GetHeroDeaths(bot:GetPlayerID())
        state.reason = state.active and 'scheduled' or 'skipped'
        state.phase = nil
        Trace(bot, state, state.reason)
    end
    if not state.active then return state end
    local inventory = Inventory(bot)
    if not bot:IsAlive() or GetHeroDeaths(bot:GetPlayerID()) > state.deaths then
        Finish(bot, state, 'dead')
    elseif now >= state.deadline then
        Finish(bot, state, 'timeout')
    elseif Fu.GetExpectedLane(bot) ~= state.lane then
        Finish(bot, state, 'lane_changed')
    elseif inventory > state.inventory and (state.arrivedAt ~= nil
        or (Valid(state.pool) and state.issuedAction
            and GetUnitToLocationDistance(bot, state.pool:GetLocation()) <= 400)) then
        Finish(bot, state, 'collected')
    end
    -- Existing lotus consumption must not hide a later successful pickup.
    state.inventory = inventory
    return state
end

function X.GetDesire(bot)
    local state = X.Update(bot)
    if state == nil or not state.active or bot:IsInvulnerable() then return 0 end
    if Combat(bot) then
        StopOwnAction(bot, state)
        state.arrivedAt = nil -- resume with a fresh two-second observation after combat
        state.resumeAfter=DotaTime()+.75
        Trace(bot, state, 'combat_original_AI')
        return 0
    end
    if DotaTime()<(state.resumeAfter or -999)then return 0 end
    if (state.pool == nil or not Valid(state.pool)) and DotaTime() >= (state.nextSearchAt or 0) then
        state.pool = FindPool(bot, state.lane)
        state.nextSearchAt = DotaTime() + 1
        if state.pool ~= nil then
            local location = state.pool:GetLocation()
            print(string.format('[LOTUS_V2] pool=%s lane=%s x=%.0f y=%.0f',
                state.pool:GetUnitName(), tostring(state.lane), location.x, location.y))
        end
    end
    if state.pool == nil then
        -- Pool handles may not be exposed until they are visible to this bot.
        -- Retry discovery without taking control away from the original AI.
        Trace(bot, state, 'pool_not_exposed')
        return 0
    end
    local _, free = Inventory(bot)
    if not free and state.inventory == 0 then
        Finish(bot, state, 'inventory_full')
        return 0
    end
    if state.arrivedAt ~= nil and DotaTime() - state.arrivedAt >= EMPTY_WAIT
        and not bot:IsChanneling() then
        Finish(bot, state, 'empty_or_unavailable')
        return 0
    end
    return DESIRE
end

function X.Think(bot)
    if X.GetDesire(bot) == 0 then return false end
    local state = bot._earlyLotus
    if bot:IsUsingAbility() or bot:IsCastingAbility() or bot:IsChanneling() then return true end
    local now = DotaTime()
    local location = state.pool:GetLocation()
    -- Current lotus pools collect automatically inside their 350-unit aura.
    -- Older clients expose a hidden channelled ability on the hero instead.
    if GetUnitToLocationDistance(bot, location) > 200 then
        Trace(bot, state, 'moving_to_pool')
        state.arrivedAt = nil
        if now >= state.nextOrderAt then
            bot:Action_MoveToLocation(location)
            state.issuedAction = true
            state.nextOrderAt = now + 0.25
        end
        return true
    end
    if state.arrivedAt == nil then
        state.arrivedAt = now
        bot:Action_ClearActions(false)
        state.issuedAction = true
        Trace(bot, state, 'at_pool_waiting')
    end
    if now < state.nextOrderAt then return true end
    local passive = state.pool:GetAbilityByName('ability_lotus_pool')
    if passive ~= nil then return true end -- standing in the aura is the real pickup action
    local pluck = bot:GetAbilityByName('ability_pluck_lotus')
        or bot:GetAbilityByName('ability_pluck_famango')
    if pluck ~= nil and not bot:IsSilenced() and pluck:IsFullyCastable() then
        bot:Action_UseAbilityOnEntity(pluck, state.pool)
        state.issuedAction = true
        state.nextOrderAt = now + 0.75
    end
    return true
end

function X.OnEnd(bot)
    local state = bot._earlyLotus
    if state ~= nil then
        StopOwnAction(bot, state)
        state.arrivedAt = nil
    end
end

function X.IsActive(bot)
    local state = X.Update(bot)
    return state ~= nil and state.active
end

return X
