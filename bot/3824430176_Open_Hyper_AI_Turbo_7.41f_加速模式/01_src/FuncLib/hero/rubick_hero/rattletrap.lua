local bot
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local BatteryAssault
local PowerCogs
local RocketFlare
local Jetpack
local Overclocking
local Hookshot

local cogsTime = -1
local ScoutRoshanTime = -1

local botTarget

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'rattletrap_overclocking'
    then
        Overclocking = ability
        OverclockingDesire = X.ConsiderOverclocking()
        if OverclockingDesire > 0
        then
            bot:Action_UseAbility(Overclocking)
            return
        end
    end

    if abilityName == 'rattletrap_hookshot'
    then
        Hookshot = ability
        HookshotDesire, HookshotTarget = X.ConsiderHookshot()
        if HookshotDesire > 0
        then
            bot:Action_UseAbilityOnLocation(Hookshot, HookshotTarget)
            return
        end
    end

    if abilityName == 'rattletrap_power_cogs'
    then
        PowerCogs = ability
        PowerCogsDesire = X.ConsiderPowerCogs()
        if PowerCogsDesire > 0
        then
            bot:Action_UseAbility(PowerCogs)
            cogsTime = DotaTime()
            return
        end
    end

    if abilityName == 'rattletrap_battery_assault'
    then
        BatteryAssault = ability
        BatteryAssaultDesire = X.ConsiderBatteryAssault()
        if BatteryAssaultDesire > 0
        then
            bot:Action_UseAbility(BatteryAssault)
            return
        end
    end

    if abilityName == 'rattletrap_rocket_flare'
    then
        RocketFlare = ability
        RocketFlareDesire, RocketFlareLocation = X.ConsiderRocketFlare()
        if RocketFlareDesire > 0
        then
            bot:Action_UseAbilityOnLocation(RocketFlare, RocketFlareLocation)
            return
        end
    end

    if abilityName == 'rattletrap_jetpack'
    then
        Jetpack = ability
        JetpackDesire = X.ConsiderJetpack()
        if JetpackDesire > 0
        then
            bot:Action_UseAbility(Jetpack)
            return
        end
    end
end

function X.ConsiderBatteryAssault()
    if not BatteryAssault:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

	local nRadius = BatteryAssault:GetSpecialValueInt('radius')

    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nRadius, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
    do
        local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)

        if Fu.IsValidHero(allyHero)
        and Fu.IsRetreating(allyHero)
        and Fu.IsCore(allyHero)
        and allyHero:WasRecentlyDamagedByAnyHero(1.5)
        and not allyHero:IsIllusion()
        then
            if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
            and Fu.IsValidHero(nAllyInRangeEnemy[1])
            and Fu.CanCastOnNonMagicImmune(nAllyInRangeEnemy[1])
            and Fu.IsInRange(bot, nAllyInRangeEnemy[1], nRadius)
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and not Fu.IsDisabled(nAllyInRangeEnemy[1])
            and not Fu.IsTaunted(nAllyInRangeEnemy[1])
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
            then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
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

    if Fu.IsRetreating(bot)
    and bot:GetActiveModeDesire() > 0.5
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.IsInRange(bot, enemyHero, nRadius)
            and Fu.IsChasingTarget(enemyHero, bot)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not Fu.IsDisabled(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly)
                    or bot:WasRecentlyDamagedByAnyHero(1.5))
                then
                    return BOT_ACTION_DESIRE_HIGH
                end
            end
        end
	end

    if Fu.IsPushing(bot) or Fu.IsDefending(bot)
    then
        local nEnemyCreeps = bot:GetNearbyLaneCreeps(nRadius, true)
        if nEnemyCreeps ~= nil and #nEnemyCreeps >= 3
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    if Fu.IsDoingRoshan(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and Fu.IsAttacking(bot)
		then
            return BOT_ACTION_DESIRE_HIGH
		end
	end

    if Fu.IsDoingTormentor(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and Fu.IsAttacking(bot)
		then
            return BOT_ACTION_DESIRE_HIGH
		end
	end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderPowerCogs()
    if not PowerCogs:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE
	end

	local nRadius = PowerCogs:GetSpecialValueInt('cogs_radius')
	local nDuration = PowerCogs:GetSpecialValueFloat('duration')

	if DotaTime() < cogsTime + nDuration
    then
		return BOT_ACTION_DESIRE_NONE
	end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius - 25)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
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

    if Fu.IsRetreating(bot)
    and bot:GetActiveModeDesire() > 0.5
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.IsChasingTarget(enemyHero, bot)
            and Fu.IsInRange(bot, enemyHero, nRadius + 200)
            and not Fu.IsInRange(bot, enemyHero, nRadius)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not Fu.IsDisabled(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly)
                    or bot:WasRecentlyDamagedByAnyHero(2))
                then
                    return BOT_ACTION_DESIRE_HIGH
                end
            end
        end
	end

	return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderRocketFlare()
    if not RocketFlare:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, 0
	end

	local nCastPoint = RocketFlare:GetCastPoint()
	local nRadius = RocketFlare:GetSpecialValueInt('radius')
    local nDamage = RocketFlare:GetSpecialValueInt('damage')
	local nCastRange = 1600
    local RoshanLocation = Fu.GetCurrentRoshanLocation()
    local nTeamFightLocation = Fu.GetTeamFightLocation(bot)

    local nEnemyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if Fu.IsValidTarget(enemyHero)
        and Fu.CanCastOnNonMagicImmune(enemyHero)
        and Fu.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
        and not Fu.IsSuspiciousIllusion(enemyHero)
        and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
        and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
        and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
        and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
        and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
        then
            return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(nCastPoint)
        end
    end

    if nTeamFightLocation ~= nil
    then
        if GetUnitToLocationDistance(bot, nTeamFightLocation) > bot:GetCurrentVisionRange()
        then
            return BOT_ACTION_DESIRE_HIGH, nTeamFightLocation
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, bot:GetCurrentVisionRange())
        and Fu.IsChasingTarget(bot, botTarget)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not Fu.IsDisabled(botTarget)
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                nInRangeEnemy = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), nRadius)
                if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
                then
                    return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nInRangeEnemy)
                else
                    return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(nCastPoint)
                end
            end
		end
	end

    if Fu.IsRetreating(bot)
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.CanCastOnNonMagicImmune(enemyHero)
            and Fu.IsInRange(bot, enemyHero, nRadius)
            and Fu.IsChasingTarget(enemyHero, bot)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not Fu.IsDisabled(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly)
                    or bot:WasRecentlyDamagedByAnyHero(2))
                then
                    return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
                end
            end
        end
	end

	if Fu.IsPushing(bot) or Fu.IsDefending(bot)
	then
		local nLocationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0)
        local nEnemyLanecreeps = bot:GetNearbyLaneCreeps(nCastRange, true);

		if nLocationAoE.count >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, nLocationAoE.targetloc
		end

		nLocationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0)
		if nLocationAoE.count >= 4 and #nEnemyLanecreeps >= 4
		then
			return BOT_ACTION_DESIRE_MODERATE, Fu.GetCenterOfUnits(nEnemyLanecreeps)
		end
	end

    if Fu.IsDoingRoshan(bot)
    then
        if Fu.IsRoshan(botTarget)
        and Fu.CanCastOnNonMagicImmune(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and Fu.IsAttacking(bot)
		then
            return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end

        if GetUnitToLocationDistance(bot, RoshanLocation) > 1600
        and DotaTime() > ScoutRoshanTime + 15
        and Fu.GetManaAfter(RocketFlare:GetManaCost()) * bot:GetMana() > Hookshot:GetManaCost()
        then
            ScoutRoshanTime = DotaTime()
            return BOT_ACTION_DESIRE_HIGH, RoshanLocation
        end
    end

    if Fu.IsDoingTormentor(bot)
	then
		if Fu.IsRoshan(botTarget)
        and Fu.IsInRange(bot, botTarget, nRadius)
        and Fu.IsAttacking(bot)
		then
            return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderHookshot()
    if not Hookshot:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, 0
    end

    local nCastPoint = Hookshot:GetCastPoint()
	local nCastRange = Fu.GetProperCastRange(false, bot, Hookshot:GetCastRange())
	local nRadius = Hookshot:GetSpecialValueInt('stun_radius')
	local nSpeed = Hookshot:GetSpecialValueInt('speed')

	if Fu.IsGoingOnSomeone(bot)
	then
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), nCastRange)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidTarget(enemyHero)
            and Fu.CanCastOnNonMagicImmune(enemyHero)
            and Fu.IsInRange(bot, enemyHero, nCastRange)
            and GetUnitToLocationDistance(enemyHero, Fu.GetEnemyFountain()) > 1000
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
            and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
                local eta = (GetUnitToUnitDistance(bot, enemyHero) / nSpeed) + nCastPoint
                local targetLoc = enemyHero:GetExtrapolatedLocation(eta)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and #nInRangeAlly >= #nTargetInRangeAlly
                and not Fu.IsAllyHeroBetweenMeAndTarget(bot, enemyHero, targetLoc, nRadius)
                and not Fu.IsCreepBetweenMeAndTarget(bot, enemyHero, targetLoc, nRadius)
                and not Fu.IsLocationInChrono(targetLoc)
                and not Fu.IsLocationInArena(targetLoc, 800)
                then
                    if #nInRangeAlly == 0 and #nTargetInRangeAlly == 0
                    then
                        if bot:GetEstimatedDamageToTarget(true, enemyHero, 5, DAMAGE_TYPE_ALL) > enemyHero:GetHealth()
                        and PowerCogs:IsFullyCastable()
                        and BatteryAssault:IsFullyCastable()
                        then
                            bot:SetTarget(enemyHero)
                            return BOT_ACTION_DESIRE_HIGH, targetLoc
                        end
                    else
                        if #nInRangeAlly >= 1
                        then
                            bot:SetTarget(enemyHero)
                            return BOT_ACTION_DESIRE_HIGH, targetLoc
                        end
                    end
                end
            end
        end
	end

    if Fu.IsRetreating(bot)
    and bot:GetActiveModeDesire() > 0.75
	then
        local nAllyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), nCastRange)
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)

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
                    or bot:WasRecentlyDamagedByAnyHero(2))
                then
                    for _, allyHero in pairs(nAllyHeroes)
                    do
                        if Fu.IsValidHero(allyHero)
                        and bot:DistanceFromFountain() > 1600
                        and allyHero:DistanceFromFountain() > 1600
                        and bot:DistanceFromFountain() > allyHero:DistanceFromFountain()
                        and GetUnitToUnitDistance(bot, allyHero) > 1200
                        and not Fu.IsNotSelf(bot, allyHero)
                        then
                            local eta = (GetUnitToUnitDistance(bot, allyHero) / nSpeed) + nCastPoint
                            local targetLoc = allyHero:GetExtrapolatedLocation(eta)

                            if not Fu.IsHeroBetweenMeAndTarget(bot, allyHero, targetLoc, nRadius)
                            and not Fu.IsCreepBetweenMeAndTarget(bot, allyHero, targetLoc, nRadius)
                            and not Fu.IsLocationInChrono(targetLoc)
                            and not Fu.IsLocationInArena(targetLoc, 800)
                            then
                                return BOT_ACTION_DESIRE_HIGH, targetLoc
                            end
                        end
                    end
                end
            end
        end

        local nNeutralCamps = GetNeutralSpawners()
		local escapeLoc = Fu.GetEscapeLoc()
		local targetLoc = GetUnitToLocationDistance(bot, escapeLoc)

		for _, camp in pairs(nNeutralCamps)
        do
			local campDist = Fu.GetDistance(camp.location, escapeLoc)

			if campDist < targetLoc
			and GetUnitToLocationDistance(bot, camp.location) > 700
			then
				if not Fu.IsHeroBetweenMeAndLocation(bot, camp.location, nRadius)
				and not Fu.IsCreepBetweenMeAndLocation(bot, camp.location, nRadius)
                and not Fu.IsLocationInChrono(camp.location)
                and not Fu.IsLocationInArena(camp.location, 800)
				then
					return BOT_ACTION_DESIRE_HIGH, camp.location
				end
			end
		end
	end

    return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderJetpack()
    if not Jetpack:IsTrained()
    or not Jetpack:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    if Fu.IsRetreating(bot)
    and bot:GetActiveModeDesire() > 0.5
    then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.IsInRange(bot, enemyHero, 800)
            and Fu.IsChasingTarget(enemyHero, bot)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly)
                    or bot:WasRecentlyDamagedByAnyHero(2.5))
                then
                    return BOT_ACTION_DESIRE_HIGH
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderOverclocking()
    if not Overclocking:IsTrained()
    or not Overclocking:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    if Fu.IsInTeamFight(bot, 1200)
    then
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)

        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2
        and Fu.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

return X