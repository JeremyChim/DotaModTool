local bot = GetBot()
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')
local X = {}

-- Vengeful Spirit Scepter Illusion
function X.ConsiderMagicMissile(hMinionUnit, MagicMissile)
    if not MagicMissile:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

	local nCastRange = Fu.GetProperCastRange(false, hMinionUnit, MagicMissile:GetCastRange())
    local nDamage = MagicMissile:GetSpecialValueInt('magic_missile_damage')
    local nEnemyHeroes = hMinionUnit:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)

    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if Fu.IsValidHero(enemyHero)
        and Fu.CanCastOnNonMagicImmune(enemyHero)
        and not Fu.IsSuspiciousIllusion(enemyHero)
        then
            if enemyHero:IsChanneling()
            then
                return BOT_ACTION_DESIRE_HIGH, enemyHero
            end

            if Fu.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
            and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
            and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
            and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
            and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
            and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
            then
                return BOT_ACTION_DESIRE_HIGH, enemyHero
            end
        end
    end

    local nAllyHeroes = hMinionUnit:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE)
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
            and Fu.CanCastOnNonMagicImmune(nAllyInRangeEnemy[1])
            and Fu.CanCastOnTargetAdvanced(nAllyInRangeEnemy[1])
            and Fu.IsInRange(hMinionUnit, nAllyInRangeEnemy[1], nCastRange)
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and nAllyInRangeEnemy[1]:IsFacingLocation(allyHero:GetLocation(), 30)
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

	local target = nil
	local dmg = 0

	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if Fu.IsValidHero(enemyHero)
		and Fu.CanCastOnNonMagicImmune(enemyHero)
		and not Fu.IsSuspiciousIllusion(enemyHero)
		and not Fu.IsDisabled(enemyHero)
		and not enemyHero:HasModifier('modifier_enigma_black_hole_pull')
		and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
		and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
		then
			local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			local currDmg = enemyHero:GetEstimatedDamageToTarget(true, hMinionUnit, 5, DAMAGE_TYPE_ALL)

			if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
			and #nInRangeAlly >= #nTargetInRangeAlly
			and dmg < currDmg
			then
				dmg = currDmg
				target = enemyHero
			end
		end
	end

	if target ~= nil
	then
		return BOT_ACTION_DESIRE_HIGH, target
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderWaveOfTerror(hMinionUnit, WaveOfTerror)
    if not WaveOfTerror:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, 0
    end

    local nCastRange = Fu.GetProperCastRange(false, hMinionUnit, WaveOfTerror:GetCastRange())
	local nRadius = WaveOfTerror:GetSpecialValueInt('wave_width')
    local nDamage = WaveOfTerror:GetAbilityDamage()
    local nEnemyHeroes = hMinionUnit:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)

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
            local nTargetInRangeAlly = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), nRadius)

            if nTargetInRangeAlly ~= nil and #nTargetInRangeAlly >= 1
            then
                return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nTargetInRangeAlly)
            end

            return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
        end
    end

	local target = nil
	local dmg = 0

	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if Fu.IsValidHero(enemyHero)
		and Fu.CanCastOnNonMagicImmune(enemyHero)
		and not Fu.IsSuspiciousIllusion(enemyHero)
		and not Fu.IsDisabled(enemyHero)
		and not enemyHero:HasModifier('modifier_enigma_black_hole_pull')
		and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
		and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
		then
			local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			local currDmg = enemyHero:GetEstimatedDamageToTarget(true, hMinionUnit, 5, DAMAGE_TYPE_ALL)

			if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
			and #nInRangeAlly >= #nTargetInRangeAlly
			and dmg < currDmg
			then
				dmg = currDmg
				target = enemyHero
			end
		end
	end

	if target ~= nil
	then
		nEnemyHeroes = Fu.GetEnemiesNearLoc(target:GetLocation(), nRadius)
		if nEnemyHeroes ~= nil and #nEnemyHeroes >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nEnemyHeroes)
		end

		return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
	end

    local nLocationAoE = hMinionUnit:FindAoELocation(true, false, hMinionUnit:GetLocation(), nCastRange, nRadius, 0, 0)
    local nEnemyLaneCreeps = hMinionUnit:GetNearbyLaneCreeps(nCastRange, true)

    if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 3
    and nLocationAoE.count >= 3
    and not Fu.IsThereNonSelfCoreNearby(1000)
    then
        return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nEnemyLaneCreeps)
    end

	return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderNetherSwap(hMinionUnit, NetherSwap)
    if not NetherSwap:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = Fu.GetProperCastRange(false, hMinionUnit, NetherSwap:GetCastRange())

    local nAllyHeroes = hMinionUnit:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
    do
        if Fu.IsValidHero(allyHero)
        and Fu.IsCore(allyHero)
        and not Fu.IsSuspiciousIllusion(allyHero)
        then
            if allyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
            or allyHero:HasModifier('modifier_enigma_black_hole_pull')
            or allyHero:HasModifier('modifier_legion_commander_duel')
            or (allyHero:HasModifier('modifier_mars_arena_of_blood_leash')
                and not hMinionUnit:HasModifier('modifier_mars_arena_of_blood_leash'))
            then
                return BOT_ACTION_DESIRE_HIGH, allyHero
            end
        end
    end

	local target = nil
	local dmg = 0
	local nInRangeEnemy = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

	for _, enemyHero in pairs(nInRangeEnemy)
	do
		if Fu.IsValidHero(enemyHero)
		and Fu.CanCastOnNonMagicImmune(enemyHero)
		and not Fu.IsInRange(hMinionUnit, enemyHero, nCastRange / 2)
		and not Fu.IsSuspiciousIllusion(enemyHero)
		and not Fu.IsDisabled(enemyHero)
		and not enemyHero:HasModifier('modifier_enigma_black_hole_pull')
		and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
		and not enemyHero:HasModifier('modifier_legion_commander_duel')
		and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
		and not enemyHero:WasRecentlyDamagedByAnyHero(2)
		then
			local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			local currDmg = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)

			if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
			and #nInRangeAlly >= #nTargetInRangeAlly
			and #nInRangeAlly >= 1
			and not (#nInRangeAlly > #nTargetInRangeAlly + 2)
			and dmg < currDmg
			then
				dmg = currDmg
				target = enemyHero
			end
		end
	end

	if target ~= nil
	then
		return BOT_ACTION_DESIRE_HIGH, target
	end

    return BOT_ACTION_DESIRE_NONE, nil
end

return X