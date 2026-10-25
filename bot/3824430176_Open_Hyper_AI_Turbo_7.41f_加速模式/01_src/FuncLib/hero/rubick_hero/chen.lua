local bot
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local Penitence
local HolyPersuasion
local DivineFavor
local HandOfGod

local botTarget

local nChenCreeps = {}

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'chen_hand_of_god'
    then
        HandOfGod = ability
        HandOfGodDesire = X.ConsiderHandOfGod()
        if HandOfGodDesire > 0
        then
            bot:Action_UseAbility(HandOfGod)
            return
        end
    end

    if abilityName == 'chen_penitence'
    then
        Penitence = ability
        PenitenceDesire, PenitenceTarget = X.ConsiderPenitence()
        if PenitenceDesire > 0
        then
            bot:Action_UseAbilityOnEntity(Penitence, PenitenceTarget)
            return
        end
    end

    if abilityName == 'chen_holy_persuasion'
    then
        HolyPersuasion = ability
        HolyPersuasionDesire, HolyPersuasionTarget = X.ConsiderHolyPersuasion()
        if HolyPersuasionDesire > 0
        then
            bot:Action_UseAbilityOnEntity(HolyPersuasion, HolyPersuasionTarget)
            return
        end
    end

    if abilityName == 'chen_divine_favor'
    then
        DivineFavor = ability
        DivineFavorDesire, DivineFavorTarget = X.ConsiderDivineFavor()
        if DivineFavorDesire > 0
        then
            bot:Action_UseAbilityOnEntity(DivineFavor, DivineFavorTarget)
            return
        end
    end
end

function X.ConsiderPenitence()
    if not Penitence:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = Fu.GetProperCastRange(false, bot, Penitence:GetCastRange())
    local nAttackRange = bot:GetAttackRange()

    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
    do
        local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)

        if Fu.IsValidHero(allyHero)
        and Fu.IsRetreating(allyHero)
        and allyHero:WasRecentlyDamagedByAnyHero(1.5)
        and not allyHero:IsIllusion()
        then
            if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
            and Fu.IsValidHero(nAllyInRangeEnemy[1])
            and Fu.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and allyHero:GetCurrentMovementSpeed() < nAllyInRangeEnemy[1]:GetCurrentMovementSpeed()
            and not Fu.IsDisabled(nAllyInRangeEnemy[1])
            and not Fu.IsTaunted(nAllyInRangeEnemy[1])
            and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
            then
                return BOT_ACTION_DESIRE_HIGH, nAllyInRangeEnemy[1]
            end
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                if Fu.IsChasingTarget(bot, botTarget)
                and bot:GetCurrentMovementSpeed() < botTarget:GetCurrentMovementSpeed()
                then
                    return BOT_ACTION_DESIRE_HIGH, botTarget
                end

                nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
                if Fu.IsInRange(bot, botTarget, nAttackRange)
                and Fu.IsAttacking(bot)
                and Fu.GetHeroCountAttackingTarget(nInRangeAlly, botTarget) >= 2
                then
                    return BOT_ACTION_DESIRE_HIGH, botTarget
                end
            end
		end
	end

	if Fu.IsRetreating(bot)
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.IsChasingTarget(enemyHero, bot)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not Fu.IsDisabled(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly)
                    or bot:WasRecentlyDamagedByAnyHero(1.5))
                and bot:GetCurrentMovementSpeed() < enemyHero:GetCurrentMovementSpeed()
                then
                    return BOT_ACTION_DESIRE_HIGH, enemyHero
                end
            end
        end
	end

	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot)
	then
        local nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)

		if (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and Fu.IsAttacking(bot)
        and nInRangeAlly ~= nil and #nInRangeAlly >= 1
        and Fu.GetHeroCountAttackingTarget(nInRangeAlly, botTarget) >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderHolyPersuasion()
	if not HolyPersuasion:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE, nil
	end

    local nCastRange = Fu.GetProperCastRange(false, bot, HolyPersuasion:GetCastRange())
    local nMaxUnit = HolyPersuasion:GetSpecialValueInt('max_units')
    local nMaxLevel = HolyPersuasion:GetSpecialValueInt('level_req')
	local nNeutralCreeps = bot:GetNearbyNeutralCreeps(nCastRange)

    local unitTable = {}
    for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES))
    do
        if string.find(unit:GetUnitName(), 'neutral')
        and unit:HasModifier('modifier_chen_holy_persuasion')
        then
            table.insert(unitTable, unit)
        end
    end

    nChenCreeps = unitTable

    local nGoodCreep = {
        "npc_dota_neutral_alpha_wolf",
        "npc_dota_neutral_centaur_khan",
        "npc_dota_neutral_polar_furbolg_ursa_warrior",
        "npc_dota_neutral_dark_troll_warlord",
        "npc_dota_neutral_satyr_hellcaller",
        "npc_dota_neutral_enraged_wildkin",
        "npc_dota_neutral_warpine_raider",
    }

    if nMaxLevel < 5
    then
        for _, creep in pairs(nNeutralCreeps)
        do
            if Fu.IsValid(creep)
            then
                return BOT_ACTION_DESIRE_HIGH, creep
            end
        end
    else
        if nChenCreeps ~= nil and #nChenCreeps < nMaxUnit
        then
            for _, creep in pairs(nNeutralCreeps)
            do
                if Fu.IsValid(creep)
                and creep:GetLevel() <= nMaxLevel
                then
                    for _, gCreep in pairs(nGoodCreep)
                    do
                        if creep:GetUnitName() == gCreep
                        then
                            return BOT_ACTION_DESIRE_HIGH, creep
                        end
                    end
                end
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderDivineFavor()
    if not DivineFavor:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = Fu.GetProperCastRange(false, bot, DivineFavor:GetCastRange())
    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)

	for _, allyHero in pairs(nAllyHeroes)
	do
		if Fu.IsValidHero(allyHero)
		and Fu.IsInRange(bot, allyHero, nCastRange)
        and not allyHero:HasModifier('modifier_abaddon_borrowed_time')
		and not allyHero:HasModifier('modifier_legion_commander_press_the_attack')
        and not allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
        and not allyHero:HasModifier('modifier_chen_penitence_attack_speed_buff')
        and not allyHero:HasModifier('modifier_chen_divine_favor_armor_buff')
        and not allyHero:IsIllusion()
		and not allyHero:IsInvulnerable()
		then
			if Fu.IsGoingOnSomeone(allyHero)
			then
				local allyTarget = Fu.GetProperTarget(allyHero)

				if Fu.IsValidTarget(allyTarget)
                and Fu.IsCore(allyHero)
				and Fu.IsInRange(allyHero, allyTarget, allyHero:GetCurrentVisionRange())
                and not Fu.IsSuspiciousIllusion(allyTarget)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end

            local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)

            if Fu.IsRetreating(allyHero)
            and allyHero:WasRecentlyDamagedByAnyHero(1.5)
            then
                if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
                and Fu.IsValidHero(nAllyInRangeEnemy[1])
                and Fu.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
                and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
                and not Fu.IsDisabled(nAllyInRangeEnemy[1])
                and not Fu.IsTaunted(nAllyInRangeEnemy[1])
                and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
                and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
                then
                    return BOT_ACTION_DESIRE_HIGH, nAllyInRangeEnemy[1]
                end
            end
		end
	end

    if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot)
	then
		if (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and Fu.IsAttacking(bot)
		then
            local target = Fu.GetAttackableWeakestUnit(bot, nCastRange, true, false)

            if target ~= nil
            then
                return BOT_ACTION_DESIRE_HIGH, target
            end
        end
	end

    if Fu.IsInTeamFight(bot, 1200)
    then
        local totDist = 0

        for _, creep in pairs(nChenCreeps)
        do
            local dist = GetUnitToUnitDistance(bot, creep)
            if dist > 1600
            then
                totDist = totDist + dist
            end
        end

        if nChenCreeps ~= nil and #nChenCreeps > 0
        then
            if (totDist / #nChenCreeps) > 1600
            then
                return BOT_ACTION_DESIRE_HIGH, bot
            end
        end
    end

    if Fu.IsRetreating(bot)
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.IsChasingTarget(enemyHero, bot)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not Fu.IsDisabled(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly and #nInRangeAlly <= 1)
                    or bot:WasRecentlyDamagedByAnyHero(2))
                then
                    return BOT_ACTION_DESIRE_HIGH, enemyHero
                end
            end
        end
	end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderHandOfGod()
	if not HandOfGod:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE
	end

    local nTeamFightLocation = Fu.GetTeamFightLocation(bot)

    if nTeamFightLocation ~= nil
    then
        local nAllyList = Fu.GetAlliesNearLoc(nTeamFightLocation, 1600)

        for _, allyHero in pairs(nAllyList)
        do
            if Fu.IsValidHero(allyHero)
            and Fu.IsCore(allyHero)
            and Fu.GetHP(allyHero) < 0.5
            and not allyHero:IsIllusion()
            and not allyHero:IsAttackImmune()
			and not allyHero:IsInvulnerable()
            and not allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
            and not allyHero:HasModifier('modifier_oracle_false_promise_timer')
            then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES))
    do
        local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)

        if Fu.IsValidHero(allyHero)
        and Fu.IsCore(allyHero)
        and Fu.GetHP(allyHero) < 0.5
        and allyHero:WasRecentlyDamagedByAnyHero(1)
        and not allyHero:IsIllusion()
        and not allyHero:IsAttackImmune()
		and not allyHero:IsInvulnerable()
        and not allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
        and not allyHero:HasModifier('modifier_oracle_false_promise_timer')
        then
            if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
            and Fu.IsValidHero(nAllyInRangeEnemy[1])
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
            then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE
end

return X