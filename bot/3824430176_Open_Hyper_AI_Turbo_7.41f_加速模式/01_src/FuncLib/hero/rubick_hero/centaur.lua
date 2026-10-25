local bot
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local HoofStomp
local DoubleEdge
local WorkHorse
local HitchARide
local Stampede

local botTarget

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'centaur_mount'
    then
        HitchARide = ability
        HitchARideDesire, HitchARideTarget = X.ConsiderHitchARide()
        if HitchARideDesire > 0
        then
            bot:Action_UseAbilityOnEntity(HitchARide, HitchARideTarget)
            return
        end
    end

    if abilityName == 'centaur_work_horse'
    then
        WorkHorse = ability
        WorkHorseDesire, HitchARideTarget = X.ConsiderWorkHorse()
        if WorkHorseDesire > 0
        then
            bot:Action_UseAbility(WorkHorse)
            return
        end
    end

    if abilityName == 'centaur_stampede'
    then
        Stampede = ability
        StampedeDesire = X.ConsiderStampede()
        if StampedeDesire > 0
        then
            bot:Action_UseAbility(Stampede)
            return
        end
    end

    if abilityName == 'centaur_hoof_stomp'
    then
        HoofStomp = ability
        HoofStompDesire = X.ConsiderHoofStomp()
        if HoofStompDesire > 0
        then
            bot:Action_UseAbility(HoofStomp)
            return
        end
    end

    if abilityName == 'centaur_double_edge'
    then
        DoubleEdge = ability
        DoubleEdgeDesire, DoubleEdgeTarget = X.ConsiderDoubleEdge()
        if DoubleEdgeDesire > 0
        then
            bot:Action_UseAbilityOnEntity(DoubleEdge, DoubleEdgeTarget)
            return
        end
    end
end

function X.ConsiderHoofStomp()
    if not HoofStomp:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

	local nRadius = HoofStomp:GetSpecialValueInt('radius')
	local nDamage = HoofStomp:GetSpecialValueInt('stomp_damage')

    local nEnemyHeroes = Fu.GetNearbyHeroes(bot,nRadius, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if Fu.IsValidHero(enemyHero)
        and Fu.CanCastOnNonMagicImmune(enemyHero)
        and not Fu.IsSuspiciousIllusion(enemyHero)
        then
            if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero)
            then
                return BOT_ACTION_DESIRE_HIGH
            end

            if Fu.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
            and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
            and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
            and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
            and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
            and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
            then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius - 100)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not Fu.IsDisabled(botTarget)
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                if Stampede:IsTrained()
                and Stampede:IsFullyCastable()
                then
                    if bot:GetMana() - HoofStomp:GetManaCost() > Stampede:GetManaCost()
                    then
                        return BOT_ACTION_DESIRE_HIGH
                    end
                else
                    return BOT_ACTION_DESIRE_HIGH
                end
            end
		end
	end

    if Fu.IsRetreating(bot)
	then
        local nInRangeAlly = Fu.GetNearbyHeroes(bot,1200, false, BOT_MODE_NONE)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and Fu.IsValidHero(nInRangeEnemy[1])
        and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
        and Fu.IsInRange(bot, nInRangeEnemy[1], nRadius)
        and Fu.IsChasingTarget(nInRangeEnemy[1], bot)
        and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not Fu.IsDisabled(nInRangeEnemy[1])
        and not nInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(nInRangeEnemy[1], 1200, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and ((#nTargetInRangeAlly > #nInRangeAlly)
                or (bot:WasRecentlyDamagedByAnyHero(1.5)))
            then
		        return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    if Fu.IsDoingRoshan(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and Fu.IsAttacking(bot)
        and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderDoubleEdge()
	if not DoubleEdge:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE, 0
	end

    local nStrength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local nCastRange = Fu.GetProperCastRange(false, bot, DoubleEdge:GetCastRange())
    local nAttackRange = bot:GetAttackRange()
    local nStrengthDamageMul = DoubleEdge:GetSpecialValueInt("strength_damage") / 100
	local nDamage = DoubleEdge:GetSpecialValueInt("edge_damage") + (nStrength * nStrengthDamageMul)

    local nEnemyHeroes = Fu.GetNearbyHeroes(bot,nCastRange + nAttackRange, true, BOT_MODE_NONE)
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
        and bot:GetHealth() > nDamage * 1.2
        then
            return BOT_ACTION_DESIRE_HIGH, enemyHero
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange * 2)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
        and not botTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
        and bot:GetHealth() > nDamage * 1.5
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

    if (Fu.IsPushing(bot) or Fu.IsDefending(bot))
    then
        local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange * 2, true)

        if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 3
        and Fu.CanBeAttacked(nEnemyLaneCreeps[1])
        and Fu.IsAttacking(bot)
        and bot:GetHealth() > nDamage * 1.5
        and (bot:GetHealth() - nDamage) / bot:GetMaxHealth() > 0.5
        and Fu.GetHP(nEnemyLaneCreeps[1]) > 0.33
        then
            return BOT_ACTION_DESIRE_HIGH, nEnemyLaneCreeps[1]
        end
    end

    if Fu.IsFarming(bot)
    then
        if Fu.IsAttacking(bot)
        and Fu.GetHP(bot) > 0.3
        and bot:GetHealth() > nDamage * 1.5
        and (bot:GetHealth() - nDamage) / bot:GetMaxHealth() > 0.3
        then
            local nNeutralCreeps = bot:GetNearbyNeutralCreeps(nCastRange * 2)
            if nNeutralCreeps ~= nil and #nNeutralCreeps >= 1
            and Fu.GetHP(nNeutralCreeps[1]) > 0.33
            then
                return BOT_ACTION_DESIRE_HIGH, nNeutralCreeps[1]
            end

            local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange * 2, true)
            if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 3
            and Fu.CanBeAttacked(nEnemyLaneCreeps[1])
            and Fu.GetHP(nEnemyLaneCreeps[1]) > 0.33
            then
                return BOT_ACTION_DESIRE_HIGH, nEnemyLaneCreeps[1]
            end
        end
    end

    if Fu.IsLaning(bot)
	then
        local canKill = 0
        local creepList = {}
		local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange * 2, true)

		for _, creep in pairs(nEnemyLaneCreeps)
		do
			-- if Fu.IsValid(creep)
			-- and (Fu.IsKeyWordUnit('ranged', creep) or Fu.IsKeyWordUnit('siege', creep) or Fu.IsKeyWordUnit('flagbearer', creep))
			-- and creep:GetHealth() <= nDamage
			-- then
			-- 	local nCreepInRangeHero = creep:GetNearbyHeroes(500, false, BOT_MODE_NONE)

			-- 	if nCreepInRangeHero ~= nil and #nCreepInRangeHero >= 1
            --     and Fu.CanBeAttacked(creep)
            --     and Fu.GetHP(bot) > 0.3
            --     and bot:GetHealth() > nDamage * 1.5
            --     and (bot:GetHealth() - nDamage) / bot:GetMaxHealth() > 0.3
			-- 	then
			-- 		return BOT_ACTION_DESIRE_HIGH, creep
			-- 	end
			-- end

            if Fu.IsValid(creep)
            and creep:GetHealth() <= nDamage
            then
                canKill = canKill + 1
                table.insert(creepList, creep)
            end
		end

        if canKill >= 2
        and Fu.CanBeAttacked(creepList[1])
        and Fu.GetHP(bot) > 0.3
        and bot:GetHealth() > nDamage * 1.5
        and (bot:GetHealth() - nDamage) / bot:GetMaxHealth() > 0.3
        then
            return BOT_ACTION_DESIRE_HIGH, creepList[1]
        end

        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), nCastRange + 75)
        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
        and Fu.IsValidTarget(nInRangeEnemy[1])
        and (bot:GetHealth() - nDamage) / bot:GetMaxHealth() > 0.65
        then
            return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]
        end
	end

    if Fu.IsDoingRoshan(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange * 2)
        and Fu.IsAttacking(bot)
        and bot:GetHealth() > nDamage * 1.5
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange * 2)
        and Fu.IsAttacking(bot)
        and bot:GetHealth() > nDamage * 1.5
        and (bot:GetHealth() - nDamage) / bot:GetMaxHealth() > 0.45
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

	return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderStampede()
	if not Stampede:IsFullyCastable()
    or bot:HasModifier('modifier_centaur_cart')
    or bot:HasModifier('modifier_centaur_stampede')
    then
		return BOT_ACTION_DESIRE_NONE
	end

    if Fu.IsInTeamFight(bot, 1200)
	then
        local nTeamFightLocation = Fu.GetTeamFightLocation(bot)
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)

        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2
        and nTeamFightLocation ~= nil
        then
            if Fu.GetLocationToLocationDistance(bot:GetLocation(), nTeamFightLocation) < 600
            then
                return BOT_ACTION_DESIRE_HIGH
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
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(nInRangeEnemy[1], 1200, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and #nTargetInRangeAlly > #nInRangeAlly
            and #nTargetInRangeAlly >= 2
            and #nInRangeAlly <= 1
            and Fu.GetHP(bot) < 0.5
            then
		        return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderWorkHorse()
    if not WorkHorse:IsTrained()
    or not WorkHorse:IsFullyCastable()
    or bot:HasModifier('modifier_centaur_stampede')
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    if Fu.IsInTeamFight(bot, 1200)
	then
        local nTeamFightLocation = Fu.GetTeamFightLocation(bot)
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)

        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2
        and nTeamFightLocation ~= nil
        then
            if Fu.GetLocationToLocationDistance(bot:GetLocation(), nTeamFightLocation) < 600
            then
                return BOT_ACTION_DESIRE_HIGH
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
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(nInRangeEnemy[1], 1200, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and #nTargetInRangeAlly > #nInRangeAlly
            and #nTargetInRangeAlly >= 2
            and #nInRangeAlly <= 1
            and Fu.GetHP(bot) < 0.5
            then
		        return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderHitchARide()
    if HitchARide:IsHidden()
    or not HitchARide:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = Fu.GetProperCastRange(false, bot, HitchARide:GetCastRange())

    if Fu.IsGoingOnSomeone(bot)
    or Fu.IsInTeamFight(bot, 1200)
    then
        local nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), nCastRange)
        for _, allyHero in pairs(nInRangeAlly)
        do
            if Fu.IsValidHero(allyHero)
            and allyHero:WasRecentlyDamagedByAnyHero(1.1)
            and Fu.GetHP(allyHero) < 0.5
            and not allyHero:IsIllusion()
            and not allyHero:HasModifier('modifier_arc_warden_tempest_double')
            then
                return BOT_ACTION_DESIRE_HIGH, allyHero
            end
        end
    end

    if Fu.IsRetreating(bot)
    then
        local nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), nCastRange)
        for _, allyHero in pairs(nInRangeAlly)
        do
            if Fu.IsValidHero(allyHero)
            and Fu.IsRetreating(allyHero)
            and allyHero:WasRecentlyDamagedByAnyHero(1.1)
            and not allyHero:IsIllusion()
            and not allyHero:HasModifier('modifier_arc_warden_tempest_double')
            then
                return BOT_ACTION_DESIRE_HIGH, allyHero
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

return X