local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local botTarget

local MistCoil
local AphoticShield

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'abaddon_aphotic_shield'
    then
        AphoticShield = ability
        AphoticShieldDesire, AphoticShieldTarget = X.ConsiderAphoticShield()
        if AphoticShieldDesire > 0
        then
            bot:Action_UseAbilityOnEntity(AphoticShield, AphoticShieldTarget)
            return
        end
    end

    if abilityName == 'abaddon_death_coil'
    then
        MistCoil = ability
        MistCoilDesire, MistCoilTarget = X.ConsiderMistCoil()
        if MistCoilDesire > 0
        then
            bot:Action_UseAbilityOnEntity(MistCoil, MistCoilTarget)
            return
        end
    end
end

function X.ConsiderMistCoil()
    if not MistCoil:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE, nil
	end

    local nCastRange  = Fu.GetProperCastRange(false, bot, MistCoil:GetCastRange())
	local nDamage = MistCoil:GetSpecialValueInt('target_damage')
    local nDamageType = DAMAGE_TYPE_MAGICAL

    local nEnemyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if Fu.IsValidHero(enemyHero)
        and Fu.CanCastOnMagicImmune(enemyHero)
        and Fu.CanKillTarget(enemyHero, nDamage, nDamageType)
        and not Fu.IsSuspiciousIllusion(enemyHero)
        and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
        and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
        and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
        then
            return BOT_ACTION_DESIRE_HIGH, enemyHero
        end
    end

    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nAllyHeroes)
	do
        if Fu.IsValidHero(allyHero)
        and not allyHero:IsInvulnerable()
        and not allyHero:IsIllusion()
        and (allyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
            or allyHero:HasModifier('modifier_enigma_black_hole_pull'))
        then
            return BOT_ACTION_DESIRE_HIGH, allyHero
        end

		if Fu.IsValidHero(allyHero)
		and Fu.IsInRange(bot, allyHero, nCastRange)
		and not allyHero:HasModifier('modifier_legion_commander_press_the_attack')
		and not allyHero:IsMagicImmune()
		and not allyHero:IsInvulnerable()
        and not allyHero:IsIllusion()
		and allyHero:CanBeSeen()
		then
			if Fu.IsRetreating(allyHero)
            and Fu.GetHP(allyHero) < 0.6
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end

			if Fu.IsGoingOnSomeone(allyHero)
			then
                local allyTarget = allyHero:GetAttackTarget()

				if Fu.IsValidHero(allyTarget)
				and allyHero:IsFacingLocation(allyTarget:GetLocation(), 30)
				and Fu.IsInRange(allyHero, allyTarget, 300)
                and Fu.GetHP(allyHero) < 0.8
                and Fu.GetHP(bot) > 0.2
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end

    if Fu.IsRetreating(bot)
    and Fu.IsInRange(bot, botTarget, nCastRange)
	then
        local nInRangeAlly = Fu.GetNearbyHeroes(bot,nCastRange + 200, false, BOT_MODE_NONE)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and ((#nInRangeAlly == 0 and #nInRangeEnemy >= 1)
            or (#nInRangeAlly >= 1
                and Fu.GetHP(bot) < 0.25
                and bot:WasRecentlyDamagedByAnyHero(1)
                and not bot:HasModifier('modifier_abaddon_borrowed_time')))
        and Fu.IsValidHero(nInRangeEnemy[1])
        and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not Fu.IsDisabled(nInRangeEnemy[1])
        then
            return BOT_ACTION_DESIRE_HIGH, bot
        end
	end

    if Fu.IsDoingRoshan(bot)
    then
        if Fu.IsRoshan(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, 400)
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderAphoticShield()
    if not AphoticShield:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange  = Fu.GetProperCastRange(false, bot, AphoticShield:GetCastRange())

    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
	do
        if Fu.IsValidHero(allyHero)
        and not allyHero:IsInvulnerable()
        and not allyHero:IsIllusion()
        and (allyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
            or allyHero:HasModifier('modifier_enigma_black_hole_pull')
            or allyHero:HasModifier('modifier_legion_commander_duel'))
        then
            return BOT_ACTION_DESIRE_HIGH, allyHero
        end

        if Fu.IsValidHero(allyHero)
        and Fu.IsDisabled(allyHero)
        and not allyHero:IsMagicImmune()
		and not allyHero:IsInvulnerable()
        and not allyHero:IsIllusion()
        then
            return BOT_ACTION_DESIRE_HIGH, allyHero
        end

		if Fu.IsValidHero(allyHero)
        and not allyHero:HasModifier('modifier_abaddon_aphotic_shield')
        and not allyHero:HasModifier('modifier_item_solar_crest_armor_addition')
		and not allyHero:IsMagicImmune()
		and not allyHero:IsInvulnerable()
        and not allyHero:IsIllusion()
        and Fu.IsNotSelf(bot, allyHero)
		then
            local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 800, true, BOT_MODE_NONE)

            if Fu.IsRetreating(allyHero)
            and allyHero:WasRecentlyDamagedByAnyHero(1.6)
            and not allyHero:IsIllusion()
            then
                if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
                and Fu.IsValidHero(nAllyInRangeEnemy[1])
                and Fu.IsInRange(allyHero, nAllyInRangeEnemy[1], 400)
                and Fu.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
                and Fu.IsRunning(allyHero)
                and nAllyInRangeEnemy[1]:IsFacingLocation(allyHero:GetLocation(), 30)
                and not Fu.IsDisabled(nAllyInRangeEnemy[1])
                and not Fu.IsTaunted(nAllyInRangeEnemy[1])
                and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
                and not nAllyInRangeEnemy[1]:HasModifier('modifier_legion_commander_duel')
                and not nAllyInRangeEnemy[1]:HasModifier('modifier_enigma_black_hole_pull')
                and not nAllyInRangeEnemy[1]:HasModifier('modifier_faceless_void_chronosphere_freeze')
                and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
                then
                    return BOT_ACTION_DESIRE_HIGH, allyHero
                end
            end

			if Fu.IsGoingOnSomeone(allyHero)
			then
				local allyTarget = allyHero:GetAttackTarget()

				if Fu.IsValidHero(allyTarget)
				and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange())
                and not Fu.IsSuspiciousIllusion(allyTarget)
                and not allyTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
                and not allyTarget:HasModifier('modifier_enigma_black_hole_pull')
                and not allyTarget:HasModifier('modifier_necrolyte_reapers_scythe')
				then
                    local nAllInRangeAlly = Fu.GetNearbyHeroes(allyHero, 800, false, BOT_MODE_NONE)
                    local nTargetInRangeAlly = Fu.GetNearbyHeroes(allyTarget, 800, false, BOT_MODE_NONE)

                    if nAllInRangeAlly ~= nil and  nTargetInRangeAlly ~= nil
                    and #nAllInRangeAlly >= #nTargetInRangeAlly
                    then
                        return BOT_ACTION_DESIRE_HIGH, allyHero
                    end
				end
			end
		end
	end

	if Fu.IsGoingOnSomeone(bot)
    then
		local nInRangeAlly = Fu.GetNearbyHeroes(bot,1000, false, BOT_MODE_NONE)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1000, true, BOT_MODE_NONE)

		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not Fu.IsDisabled(botTarget)
        and not botTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
        and not botTarget:HasModifier('modifier_enigma_black_hole_pull')
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
            and #nInRangeAlly >= #nTargetInRangeAlly
            then
                if Fu.IsValidHero(nInRangeAlly[1])
                and Fu.IsInRange(bot, nInRangeAlly[1], nCastRange)
                and Fu.IsCore(nInRangeAlly[1])
                and not nInRangeAlly[1]:HasModifier('modifier_abaddon_aphotic_shield')
                and not nInRangeAlly[1]:IsMagicImmune()
                and not nInRangeAlly[1]:IsInvulnerable()
                and not nInRangeAlly[1]:IsIllusion()
                then
                    return BOT_ACTION_DESIRE_HIGH, nInRangeAlly[1]
                end

                if not bot:HasModifier('modifier_abaddon_aphotic_shield')
                and not bot:HasModifier("modifier_abaddon_borrowed_time")
                then
                    return BOT_ACTION_DESIRE_MODERATE, bot
                end
            end
	    end

        if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and #nInRangeAlly == 0 and #nInRangeEnemy >= 1
        and Fu.IsValidHero(nInRangeEnemy[1])
        and Fu.IsInRange(bot, nInRangeEnemy[1], 500)
        and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not Fu.IsDisabled(nInRangeEnemy[1])
        and not bot:HasModifier('modifier_abaddon_aphotic_shield')
        and not bot:HasModifier("modifier_abaddon_borrowed_time")
        then
            return BOT_ACTION_DESIRE_MODERATE, bot
        end
    end

    if Fu.IsRetreating(bot)
    then
        local nInRangeAlly = Fu.GetNearbyHeroes(bot,800, false, BOT_MODE_NONE)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,800, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy
        and Fu.IsValidHero(nInRangeEnemy[1])
        and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
        and Fu.IsInRange(bot, nInRangeEnemy[1], nCastRange)
        and Fu.IsRunning(nInRangeEnemy[1])
        and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
        and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not Fu.IsDisabled(nInRangeEnemy[1])
        and not nInRangeEnemy[1]:HasModifier('modifier_enigma_black_hole_pull')
        and not nInRangeEnemy[1]:HasModifier('modifier_faceless_void_chronosphere_freeze')
        and not nInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
        then
            local nTargetInRangeAlly = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and ((#nTargetInRangeAlly > #nInRangeAlly)
                or (Fu.GetHP(bot) < 0.55 and bot:WasRecentlyDamagedByAnyHero(2)))
            then
                return BOT_ACTION_DESIRE_HIGH, bot
            end
        end
    end

    if Fu.IsDoingRoshan(bot)
    then
        if Fu.IsRoshan(botTarget)
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        then
            local weakestAlly = Fu.GetAttackableWeakestUnit(bot, nCastRange, true, false)

            if weakestAlly ~= nil
            and not weakestAlly:HasModifier('modifier_abaddon_aphotic_shield')
            then
                return BOT_ACTION_DESIRE_HIGH, weakestAlly
            end
        end
    end

    if Fu.IsDoingTormentor(bot)
    then
        if Fu.IsTormentor(botTarget)
        and Fu.IsInRange(bot, botTarget, 400)
        and Fu.IsAttacking(bot)
        then
            local weakestAlly = Fu.GetAttackableWeakestUnit(bot, nCastRange, true, false)

            if weakestAlly ~= nil
            and not weakestAlly:HasModifier('modifier_abaddon_aphotic_shield')
            then
                return BOT_ACTION_DESIRE_HIGH, weakestAlly
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE, nil
end

return X