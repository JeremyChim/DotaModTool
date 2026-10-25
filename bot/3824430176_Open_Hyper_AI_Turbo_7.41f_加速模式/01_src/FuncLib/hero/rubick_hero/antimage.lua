local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local Blink
local CounterSpell
local CounterSpellAlly
local BlinkFragment
local ManaVoid

local botTarget

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'antimage_counterspell'
    then
        CounterSpell = ability
        CounterSpellDesire = X.ConsiderCounterSpell()
        if CounterSpellDesire > 0
        then
            Fu.SetQueuePtToINT(bot, false)
            bot:ActionQueue_UseAbility(CounterSpell)
            return
        end
    end

    if abilityName == 'antimage_mana_overload'
    then
        BlinkFragment = ability
        BlinkFragmentDesire, BlinkFragmentLocation = X.ConsiderBlinkFragment()
        if BlinkFragmentDesire > 0
        then
            bot:Action_UseAbilityOnLocation(BlinkFragment, BlinkFragmentLocation)
            return
        end
    end

    if abilityName == 'antimage_blink'
    then
        Blink = ability
        BlinkDesire, BlinkLocation = X.ConsiderBlink()
        if BlinkDesire > 0
        then
            Fu.SetQueuePtToINT(bot, false)
            bot:ActionQueue_UseAbilityOnLocation(Blink, BlinkLocation)
            return
        end
    end

    if abilityName == 'antimage_mana_void'
    then
        ManaVoid = ability
        ManaVoidDesire, ManaVoidTarget = X.ConsiderManaVoid()
        if ManaVoidDesire > 0
        then
            Fu.SetQueuePtToINT(bot, false)
            bot:ActionQueue_UseAbilityOnEntity(ManaVoid, ManaVoidTarget)
            return
        end
    end

    if abilityName == 'antimage_counterspell_ally'
    then
        CounterSpellAlly = ability
        CounterSpellAllyDesire, CounterSpellAllyTarget = X.ConsiderCounterSpellAlly()
        if CounterSpellAllyDesire > 0
        then
            Fu.SetQueuePtToINT(bot, false)
            bot:ActionQueue_UseAbilityOnEntity(CounterSpellAlly, CounterSpellAllyTarget)
            return
        end
    end
end

function X.ConsiderBlink()
	if not Blink:IsFullyCastable()
	or bot:IsRooted()
	or bot:HasModifier('modifier_bloodseeker_rupture')
	then return BOT_ACTION_DESIRE_NONE end

	local nCastRange = Blink:GetSpecialValueInt('AbilityCastRange') - 1
	local nCastPoint = Blink:GetCastPoint()
	local nAttackPoint = bot:GetAttackPoint()

	if Fu.IsStuck(bot)
	then
		local loc = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, loc, nCastRange)
	end

	if (Fu.IsStunProjectileIncoming(bot, 600) or Fu.IsUnitTargetProjectileIncoming(bot, 400))
	and CounterSpell ~= nil and not CounterSpell:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), nCastRange)
    end

	if not bot:HasModifier('modifier_sniper_assassinate')
	and not bot:IsMagicImmune()
	and CounterSpell ~= nil and not CounterSpell:IsFullyCastable()
	then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), nCastRange)
		end
	end

	if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
		and Fu.CanCastOnMagicImmune(botTarget)
		and not Fu.IsInRange(bot, botTarget, 400)
		and not botTarget:IsAttackImmune()
		and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
		and not botTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
		and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
		then
			local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

			if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
			and #nInRangeAlly >= #nInRangeEnemy
			then
				local targetLoc = botTarget:GetExtrapolatedLocation(nCastPoint + 0.53)

				if GetUnitToUnitDistance(bot, botTarget) > nCastRange
				then
					targetLoc = Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), nCastRange)
				end

				if Fu.IsInLaningPhase()
				then
					local nEnemysTowers = botTarget:GetNearbyTowers(700, false)
					if nEnemysTowers ~= nil and #nEnemysTowers == 0
					or (bot:GetHealth() > Fu.GetTotalEstimatedDamageToTarget(nInRangeEnemy, bot)
						and Fu.WillKillTarget(botTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL, 2))
					then
						bot:SetTarget(botTarget)
						return BOT_ACTION_DESIRE_HIGH, targetLoc
					end
				else
					bot:SetTarget(botTarget)
					return BOT_ACTION_DESIRE_HIGH, targetLoc
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
			and bot:DistanceFromFountain() > 600
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not Fu.IsRealInvisible(bot)
			then
				local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

				if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
				and ((#nTargetInRangeAlly > #nInRangeAlly)
					or bot:WasRecentlyDamagedByAnyHero(2)
					or (Fu.GetHP(bot) < 0.2 and Fu.IsChasingTarget(enemyHero, bot)))
				then
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), nCastRange)
				end
			end
        end
	end

	if Fu.IsLaning(bot)
	then
		-- local nLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange + 80, true)
		-- for _, creep in pairs( nLaneCreeps )
		-- do
		-- 	if Fu.IsValid(creep)
		-- 	and Fu.CanBeAttacked(creep)
		-- 	and (Fu.IsKeyWordUnit('ranged', creep) or Fu.IsKeyWordUnit('siege', creep) or Fu.IsKeyWordUnit('flagbearer', creep))
		-- 	and GetUnitToUnitDistance(bot, creep) > 500
		-- 	then
		-- 		local nCreepInRangeHero = creep:GetNearbyHeroes(creep:GetCurrentVisionRange(), false, BOT_MODE_NONE)
		-- 		local nCreepInRangeTower = creep:GetNearbyTowers(700, false)
		-- 		local nDamage = bot:GetAttackDamage()

		-- 		if Fu.WillKillTarget(creep, nDamage, DAMAGE_TYPE_PHYSICAL, nCastPoint + nAttackPoint + 0.53)
		-- 		and nCreepInRangeHero ~= nil and #nCreepInRangeHero == 0
		-- 		and nCreepInRangeTower ~= nil and #nCreepInRangeTower == 0
		-- 		and botTarget ~= creep
		-- 		then
		-- 			bot:SetTarget(creep)
		-- 			return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
		-- 		end
		-- 	end
		-- end

		local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)
		local nInRangeTower = bot:GetNearbyTowers(1600, true)
		if Fu.GetManaAfter(Blink:GetManaCost()) > 0.85
		and Fu.IsInLaningPhase()
		and bot:DistanceFromFountain() > 300
		and bot:DistanceFromFountain() < 6000
		and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
		and nInRangeTower ~= nil and #nInRangeTower == 0
		then
			local nLane = bot:GetAssignedLane()
			local nLaneFrontLocation = GetLaneFrontLocation(GetTeam(), nLane, 0)
			local nDistFromLane = GetUnitToLocationDistance(bot, nLaneFrontLocation)

			if nDistFromLane > nCastRange
			then
				local nLocation = Fu.Site.GetXUnitsTowardsLocation(bot, nLaneFrontLocation, nCastRange)
				if IsLocationPassable(nLocation)
				then
					return BOT_ACTION_DESIRE_HIGH, nLocation
				end
			end
		end
	end

	if Fu.IsPushing(bot)
	and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH
	then
        local nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), 600)
        local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		local nEnemyTowers = bot:GetNearbyTowers(700, true)
		local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(1200, true)

		if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 3
        and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
        and nInRangeAlly ~= nil and #nInRangeAlly <= 1
		and GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(nEnemyLaneCreeps)) > bot:GetAttackRange()
        and Fu.CanBeAttacked(nEnemyLaneCreeps[1])
		then
            local nEnemyTowers2 = nEnemyLaneCreeps[#nEnemyLaneCreeps]:GetNearbyTowers(700, false)
            if nEnemyTowers2 ~= nil and #nEnemyTowers2 == 0
            then
                return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nEnemyLaneCreeps)
            end
		end

        -- nInRangeEnemy = Fu.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)
		-- if bot.laneToPush ~= nil
		-- then
		-- 	if Fu.GetManaAfter(Blink:GetManaCost()) * bot:GetMana() > ManaVoid:GetManaCost() * 2
		-- 	and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
		-- 	and nEnemyTowers ~= nil and #nEnemyTowers == 0
		-- 	and GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), bot.laneToPush, 0)) > nCastRange
		-- 	and bot:IsFacingLocation(GetLaneFrontLocation(GetTeam(), bot.laneToPush, 0), 30)
		-- 	then
		-- 		return  BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, GetLaneFrontLocation(GetTeam(), bot.laneToPush, 0), nCastRange)
		-- 	end
		-- end
	end

	-- if Fu.IsDefending(bot)
	-- and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH
	-- then
    --     local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)
	-- 	if bot.laneToDefend ~= nil
	-- 	then
	-- 		if Fu.GetManaAfter(Blink:GetManaCost()) * bot:GetMana() > ManaVoid:GetManaCost() * 2
	-- 		and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
	-- 		and GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), bot.laneToDefend, 0)) > nCastRange
	-- 		and bot:IsFacingLocation(GetLaneFrontLocation(GetTeam(), bot.laneToDefend, 0), 30)
	-- 		then
	-- 			return  BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, GetLaneFrontLocation(GetTeam(), bot.laneToDefend, 0), nCastRange)
	-- 		end
	-- 	end
	-- end

	if Fu.IsDoingRoshan(bot)
    then
		local RoshanLocation = Fu.GetCurrentRoshanLocation()
        if GetUnitToLocationDistance(bot, RoshanLocation) > nCastRange
        then
			local targetLoc = Fu.Site.GetXUnitsTowardsLocation(bot, RoshanLocation, nCastRange)
			local nInRangeEnemy = Fu.GetEnemiesNearLoc(RoshanLocation, 1600)

			if nInRangeEnemy ~= nil and #nInRangeEnemy == 0
			and IsLocationPassable(targetLoc)
			then
				return BOT_ACTION_DESIRE_HIGH, targetLoc
			end
        end
    end

    if Fu.IsDoingTormentor(bot)
    then
		local TormentorLocation = Fu.GetTormentorLocation(GetTeam())
        if GetUnitToLocationDistance(bot, TormentorLocation) > nCastRange
        then
			local targetLoc = Fu.Site.GetXUnitsTowardsLocation(bot, TormentorLocation, nCastRange)
			local nInRangeEnemy = Fu.GetEnemiesNearLoc(targetLoc, 1600)

			if nInRangeEnemy ~= nil and #nInRangeEnemy == 0
			and IsLocationPassable(targetLoc)
			then
				return BOT_ACTION_DESIRE_HIGH, targetLoc
			end

        end
    end

	return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderCounterSpell()
	if not CounterSpell:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE
	end

	if Fu.IsUnitTargetProjectileIncoming(bot, 400)
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	if not bot:HasModifier('modifier_sniper_assassinate')
	and not bot:IsMagicImmune()
	then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 1400)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderManaVoid()
	if not ManaVoid:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE
	end

	local nCastRange = Fu.GetProperCastRange(false, bot, ManaVoid:GetCastRange())
	local nRadius = ManaVoid:GetSpecialValueInt('mana_void_aoe_radius')
	local nDamagaPerHealth = ManaVoid:GetSpecialValueFloat('mana_void_damage_per_mana')

	if Fu.IsInTeamFight(bot, 1200)
	then
		local nCastTarget = nil
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot,nCastRange + 200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy)
		do
			local nDamage = nDamagaPerHealth * (enemyHero:GetMaxMana() - enemyHero:GetMana())
			if Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsHaveAegis(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier('modifier_arc_warden_tempest_double')
				and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
				and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
				and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
			then
				nCastTarget = enemyHero
				break
				-- if Fu.IsCore(enemyHero)
				-- then
				-- 	nCastTarget = enemyHero
				-- 	break
				-- else
				-- 	nCastTarget = enemyHero
				-- end
			end
		end

		if nCastTarget ~= nil
		then
			bot:SetTarget(nCastTarget)
			return BOT_ACTION_DESIRE_HIGH, nCastTarget
		end
	end

	if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, nCastRange)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.CanCastOnTargetAdvanced(botTarget)
		and not Fu.IsHaveAegis(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and not botTarget:HasModifier('modifier_arc_warden_tempest_double')
		and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
		and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
		and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
		then
			local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nTargetInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local nDamage = nDamagaPerHealth * (botTarget:GetMaxMana() - botTarget:GetMana())

			if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
			and #nInRangeAlly >= #nTargetInRangeAlly
			then
				if Fu.CanKillTarget(botTarget, nDamage, DAMAGE_TYPE_MAGICAL)
				then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end

	return 0
end

function X.ConsiderCounterSpellAlly()
	if not CounterSpellAlly:IsTrained()
	or not CounterSpellAlly:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = Fu.GetProperCastRange(false, bot, CounterSpellAlly:GetCastRange())
	local nInRangeAlly = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)

	for _, allyHero in pairs(nInRangeAlly)
	do
		if Fu.IsValidHero(allyHero)
		and not Fu.IsSuspiciousIllusion(allyHero)
		and not allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
		then
			if Fu.IsUnitTargetProjectileIncoming(allyHero, 400)
			and not allyHero:IsMagicImmune()
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end

			if not allyHero:HasModifier('modifier_sniper_assassinate')
			and not allyHero:IsMagicImmune()
			then
				if Fu.IsWillBeCastUnitTargetSpell(allyHero, nCastRange)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderBlinkFragment()
	if not bot:HasScepter()
	or not BlinkFragment:IsTrained()
	or not BlinkFragment:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local nCastRange = Fu.GetProperCastRange(false, bot, BlinkFragment:GetCastRange())

	if Fu.IsGoingOnSomeone(bot)
	then
		local target = nil
		local hp = 99999
		local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), nCastRange)
		for _, enemyHero in pairs(nInRangeEnemy)
		do
			if Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and not Fu.IsInRange(bot, enemyHero, nCastRange / 2)
			and not enemyHero:IsAttackImmune()
			and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
			and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
			and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
			then
				local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

				if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
				and #nInRangeAlly >= #nTargetInRangeAlly
				and hp < enemyHero:GetHealth()
				then
					hp = enemyHero:GetHealth()
					target = enemyHero
				end
			end
		end

		if target ~= nil
		then
			return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
		end
	end

	if Fu.IsRetreating(bot)
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy)
        do
			if Fu.IsValidHero(enemyHero)
			and Fu.IsChasingTarget(enemyHero, bot)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not Fu.IsRealInvisible(bot)
			then
				local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

				if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
				and ((#nTargetInRangeAlly > #nInRangeAlly)
					or bot:WasRecentlyDamagedByAnyHero(1.2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
        end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

return X