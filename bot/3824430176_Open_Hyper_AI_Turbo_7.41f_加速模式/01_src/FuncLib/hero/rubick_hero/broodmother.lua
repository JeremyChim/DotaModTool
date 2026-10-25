local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local InsatiableHunger
local SpinWeb
local SilkenBola
local SpawnSpiderlings

local botTarget

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'broodmother_spawn_spiderlings'
    then
        SpawnSpiderlings = ability
        SpawnSpiderlingsDesire, SpirderlingsTarget = X.ConsiderSpawnSpiderlings()
        if SpawnSpiderlingsDesire > 0
        then
            bot:Action_UseAbilityOnEntity(SpawnSpiderlings, SpirderlingsTarget)
            return
        end
    end

    if abilityName == 'broodmother_spin_web'
    then
        SpinWeb = ability
        SpinWebDesire, SpinWebLocation = X.ConsiderSpinWeb()
        if SpinWebDesire > 0
        then
            bot:Action_UseAbilityOnLocation(SpinWeb, SpinWebLocation)
            return
        end
    end

    if abilityName == 'broodmother_silken_bola'
    then
        SilkenBola = ability
        SilkenBolaDesire, SilkenBolaTarget = X.ConsiderSilkenBola()
        if SilkenBolaDesire > 0
        then
            bot:Action_UseAbilityOnEntity(SilkenBola, SilkenBolaTarget)
            return
        end
    end

    if abilityName == 'broodmother_insatiable_hunger'
    then
        InsatiableHunger = ability
        InsatiableHungerDesire = X.ConsiderInsatiableHunger()
        if InsatiableHungerDesire > 0
        then
            bot:Action_UseAbility(InsatiableHunger)
            return
        end
    end
end

function X.ConsiderInsatiableHunger()
    if not InsatiableHunger:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    local nAttackRange = bot:GetAttackRange()

    if Fu.IsInTeamFight(bot, 1200)
	then
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)

        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2
        and Fu.GetHP(bot) < 0.75
        and Fu.IsAttacking(bot)
        then
			return BOT_ACTION_DESIRE_HIGH
        end
	end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nAttackRange + 150)
        and Fu.IsAttacking(bot)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not Fu.IsDisabled(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not botTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
        and not botTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                return BOT_ACTION_DESIRE_HIGH
            end
		end
	end

    if Fu.IsFarming(bot)
    then
        local nCreeps = bot:GetNearbyCreeps(700, true)

        if nCreeps ~= nil and #nCreeps > 0
        and Fu.GetHP(bot) < 0.4
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    if Fu.IsDoingRoshan(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderSpinWeb()
    if not SpinWeb:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, 0
    end

	local nCastRange = Fu.GetProperCastRange(false, bot, SpinWeb:GetCastRange())
    local nRadius = SpinWeb:GetSpecialValueInt('radius')
    local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange, true)
    local nEnemyTowers = bot:GetNearbyTowers(nCastRange, true)

    if Fu.IsStuck(bot)
    and not X.DoesLocationHaveWeb(bot:GetLocation(), nRadius)
	then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
	end

    if Fu.IsInTeamFight(bot, 1200)
	then
        local nLocationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0)
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(nLocationAoE.targetloc, nRadius / 1.7)

        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2
        and not X.DoesLocationHaveWeb(nLocationAoE.targetloc, nRadius)
        and not Fu.IsLocationInChrono(nLocationAoE.targetloc)
        and not Fu.IsLocationInBlackHole(nLocationAoE.targetloc)
        then
			return BOT_ACTION_DESIRE_HIGH, nLocationAoE.targetloc
        end
	end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not Fu.IsDisabled(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
        and not X.DoesLocationHaveWeb(botTarget:GetLocation(), nRadius)
        and not Fu.IsLocationInChrono(botTarget:GetLocation())
        and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
            end
		end
	end

    if Fu.IsRetreating(bot)
	then
        local nInRangeAlly = Fu.GetNearbyHeroes(bot,1200, false, BOT_MODE_NONE)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and Fu.IsValidHero(nInRangeEnemy[1])
        and Fu.IsInRange(bot, nInRangeEnemy[1], 600)
        and Fu.IsChasingTarget(nInRangeEnemy[1], bot)
        and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not Fu.IsDisabled(nInRangeEnemy[1])
        and not X.DoesLocationHaveWeb(bot:GetLocation(), nRadius)
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(nInRangeEnemy[1], 1200, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and ((#nTargetInRangeAlly > #nInRangeAlly)
                or (bot:WasRecentlyDamagedByAnyHero(1.5)))
            then
		        return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
            end
        end
    end

    if Fu.IsPushing(bot)
	then
		if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 4
        and not X.DoesLocationHaveWeb(Fu.GetCenterOfUnits(nEnemyLaneCreeps), nRadius)
        then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nEnemyLaneCreeps)
		end

		if nEnemyTowers ~= nil and #nEnemyTowers >= 1
        and Fu.CanBeAttacked(nEnemyTowers[1])
        and not X.DoesLocationHaveWeb(nEnemyTowers[1]:GetLocation(), nRadius)
		then
			return BOT_ACTION_DESIRE_HIGH, nEnemyTowers[1]:GetLocation()
		end
	end

    if Fu.IsLaning(bot)
    then
		if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 4
        and not X.DoesLocationHaveWeb(Fu.GetCenterOfUnits(nEnemyLaneCreeps), nRadius)
        then
			return BOT_MODE_DESIRE_HIGH, Fu.GetCenterOfUnits(nEnemyLaneCreeps)
		end
	end

    if Fu.IsDoingRoshan(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        and not X.DoesLocationHaveWeb(botTarget:GetLocation(), nRadius)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        and not X.DoesLocationHaveWeb(botTarget:GetLocation(), nRadius)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
        end
    end

    return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderSilkenBola()
	if not SilkenBola:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = Fu.GetProperCastRange(false, bot, SilkenBola:GetCastRange())
    local nDamage = SilkenBola:GetSpecialValueInt('impact_damage')

    local nEnemyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if Fu.IsValidHero(enemyHero)
        and Fu.CanCastOnNonMagicImmune(enemyHero)
        and Fu.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
        and not Fu.IsSuspiciousIllusion(enemyHero)
        and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
        and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
        and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
        and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
        and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
        then
            return BOT_ACTION_DESIRE_HIGH, enemyHero
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                return BOT_ACTION_DESIRE_HIGH, botTarget
            end
		end
	end

    if Fu.IsRetreating(bot)
	then
        local nInRangeAlly = Fu.GetNearbyHeroes(bot,1200, false, BOT_MODE_NONE)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and Fu.IsValidHero(nInRangeEnemy[1])
        and Fu.IsInRange(bot, nInRangeEnemy[1], nCastRange)
        and Fu.IsChasingTarget(nInRangeEnemy[1], bot)
        and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not nInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(nInRangeEnemy[1], 1200, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and ((#nTargetInRangeAlly > #nInRangeAlly)
                or (bot:WasRecentlyDamagedByAnyHero(1.5)))
            then
		        return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]
            end
        end
    end

    -- if Fu.IsLaning(bot)
	-- then
	-- 	local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange, true)

	-- 	for _, creep in pairs(nEnemyLaneCreeps)
	-- 	do
	-- 		if Fu.IsValid(creep)
	-- 		and (Fu.IsKeyWordUnit('ranged', creep) or Fu.IsKeyWordUnit('siege', creep) or Fu.IsKeyWordUnit('flagbearer', creep))
	-- 		and creep:GetHealth() <= nDamage
	-- 		then
	-- 			local nCreepInRangeHero = creep:GetNearbyHeroes(500, false, BOT_MODE_NONE)

	-- 			if nCreepInRangeHero ~= nil and #nCreepInRangeHero >= 1
    --             and Fu.GetMP(bot) > 0.49
	-- 			then
	-- 				return BOT_ACTION_DESIRE_HIGH, creep
	-- 			end
	-- 		end
	-- 	end
	-- end

    if Fu.IsDoingRoshan(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
    do
        local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)

        if Fu.IsValidHero(allyHero)
        and Fu.IsRetreating(allyHero)
        and Fu.GetMP(bot) > 0.45
        and allyHero:WasRecentlyDamagedByAnyHero(1.5)
        and not allyHero:IsIllusion()
        then
            if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
            and Fu.IsValidHero(nAllyInRangeEnemy[1])
            and Fu.CanCastOnNonMagicImmune(nAllyInRangeEnemy[1])
            and Fu.CanCastOnTargetAdvanced(nAllyInRangeEnemy[1])
            and Fu.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and not Fu.IsDisabled(nAllyInRangeEnemy[1])
            and not Fu.IsTaunted(nAllyInRangeEnemy[1])
            and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_legion_commander_duel')
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_enigma_black_hole_pull')
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_faceless_void_chronosphere_freeze')
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
            then
                return BOT_ACTION_DESIRE_HIGH, nAllyInRangeEnemy[1]
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderSpawnSpiderlings()
	if not SpawnSpiderlings:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local nCastRange = Fu.GetProperCastRange(false, bot, SpawnSpiderlings:GetCastRange())
	local nDamage = SpawnSpiderlings:GetSpecialValueInt('damage')

    local nEnemyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if Fu.IsValidHero(enemyHero)
        and Fu.CanCastOnNonMagicImmune(enemyHero)
        and Fu.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
        and not Fu.IsSuspiciousIllusion(enemyHero)
        and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
        and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
        and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
        and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
        and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
        then
            return BOT_ACTION_DESIRE_HIGH, enemyHero
        end
    end

    local nCreeps = bot:GetNearbyLaneCreeps(nCastRange, true)
    for _, creep in pairs(nCreeps)
    do
        if Fu.IsValid(creep)
        and Fu.CanBeAttacked(creep)
        and Fu.CanKillTarget(creep, nDamage, DAMAGE_TYPE_MAGICAL)
        and not Fu.IsRetreating(bot)
        then
            return BOT_ACTION_DESIRE_HIGH, creep
        end
    end

	return BOT_ACTION_DESIRE_NONE, 0
end

-- Helper Funcs
function X.DoesLocationHaveWeb(loc, nRadius)
	for _, u in pairs (GetUnitList(UNIT_LIST_ALLIES))
	do
		if Fu.IsValid(u)
        and u:GetUnitName() == 'npc_dota_broodmother_web'
        and GetUnitToLocationDistance(u, loc) < nRadius
		then
			return true
		end
	end

	return false
end

return X