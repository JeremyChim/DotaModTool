local X = {}
local bot
local Fu = require( GetScriptDirectory()..'/FuncLib/func_utils' )

-- Visage's Familiars
local StoneForm
local IsAttackingSomethingNotHero = false
function X.FamiliarThink(hero, hMinionUnit)
	if Fu.CanNotUseAbility(hMinionUnit) then return end

	bot = hero
	StoneForm = hMinionUnit:GetAbilityByName('visage_summon_familiars_stone_form')

	Desire = ConsiderStoneForm(hMinionUnit, StoneForm)
	if Desire > 0
	then
		hMinionUnit:Action_UseAbilityOnLocation(StoneForm, hMinionUnit:GetLocation())
		return
	end

	RetreatDesire, RetreatLocation = ConsiderFamiliarRetreat(hMinionUnit)
	if RetreatDesire > 0
	then
		hMinionUnit:Action_MoveToLocation(RetreatLocation)
		return
	end

	AttackDesire, AttackTarget = ConsiderFamiliarAttack(hMinionUnit)
	if AttackDesire > 0
	then
		hMinionUnit:Action_AttackUnit(AttackTarget, false)
		return
	end

	MoveDesire, MoveLocation = ConsiderFamiliarMove(hMinionUnit)
	if MoveDesire > 0
	then
		hMinionUnit:Action_MoveToLocation(MoveLocation)
		return
	end
end

function ConsiderStoneForm(hMinionUnit, ability)
	if not ability:IsFullyCastable()
	or hMinionUnit:HasModifier('modifier_visage_summon_familiars_stone_form_buff')
	then
		return BOT_ACTION_DESIRE_NONE
	end

	local nRadius = ability:GetSpecialValueInt('stun_radius')

	if Fu.IsRetreating(bot)
	then
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy)
		do
			if Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsChasingTarget(enemyHero, bot)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			then
				local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

				if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
				and ((#nTargetInRangeAlly > #nInRangeAlly)
					or bot:WasRecentlyDamagedByAnyHero(2.5))
				then
					local nFamiliarInRangeEnemy = hMinionUnit:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE)
					if nFamiliarInRangeEnemy ~= nil and #nFamiliarInRangeEnemy >= 1
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end

	if Fu.GetHP(hMinionUnit) < 0.49
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	local nEnemyHeroes = hMinionUnit:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if Fu.IsValidHero(enemyHero)
		and Fu.CanCastOnNonMagicImmune(enemyHero)
		and enemyHero:IsChanneling()
		and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	local attackTarget = hMinionUnit:GetAttackTarget()
	if Fu.IsValidHero(attackTarget)
	and not Fu.IsSuspiciousIllusion(attackTarget)
	and not Fu.IsDisabled(attackTarget)
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	return BOT_ACTION_DESIRE_NONE
end

function ConsiderFamiliarRetreat(hMinionUnit)
	if hMinionUnit:HasModifier('modifier_visage_summon_familiars_stone_form_buff')
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	if not bot:IsAlive()
	then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetEscapeLoc()
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

function ConsiderFamiliarAttack(hMinionUnit)
	if hMinionUnit:HasModifier('modifier_visage_summon_familiars_stone_form_buff')
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local botTarget = Fu.GetProperTarget(bot)

	if Fu.IsValidHero(botTarget)
	or Fu.IsValidBuilding(botTarget)
	then
		IsAttackingSomethingNotHero = false
		return BOT_ACTION_DESIRE_HIGH, botTarget
	end

	local nUnits = bot:GetNearbyCreeps(700, true)
	for _, creep in pairs(nUnits)
	do
		if Fu.IsValid(creep)
		and Fu.CanBeAttacked(creep)
		and GetUnitToUnitDistance(bot, hMinionUnit) < 1600
		then
			IsAttackingSomethingNotHero = true
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end

	nUnits = bot:GetNearbyTowers(700, true)
	for _, tower in pairs(nUnits)
	do
		if Fu.IsValidBuilding(tower)
		and Fu.CanBeAttacked(tower)
		and tower:GetAttackTarget() ~= hMinionUnit
		and not hMinionUnit:WasRecentlyDamagedByTower(1)
		then
			local nInRangeEnemy = Fu.GetEnemiesNearLoc(tower:GetLocation(), 700)

			if nInRangeEnemy ~= nil and #nInRangeEnemy == 0
			and GetUnitToUnitDistance(bot, hMinionUnit) < 1600
			then
				IsAttackingSomethingNotHero = true
				return BOT_ACTION_DESIRE_HIGH, tower
			end
		end
	end

	IsAttackingSomethingNotHero = false

	return BOT_ACTION_DESIRE_NONE, 0
end

function ConsiderFamiliarMove(hMinionUnit)
	if hMinionUnit:HasModifier('modifier_visage_summon_familiars_stone_form_buff')
	or not bot:IsAlive()
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local nEnemyHeroes = hMinionUnit:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if Fu.IsValidHero(enemyHero)
		and Fu.CanCastOnNonMagicImmune(enemyHero)
		and enemyHero:IsChanneling()
		and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local nInRangeEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

			if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
			and #nInRangeAlly >= #nInRangeEnemy
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end

	if GetUnitToUnitDistance(hMinionUnit, bot) > hMinionUnit:GetAttackRange()
	and not IsAttackingSomethingNotHero
	then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation() + RandomVector(hMinionUnit:GetAttackRange())
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

-- Lone Druid's Bear
local sBearItems = {
    "item_six_branches",

    "item_phase_boots",
    "item_diffusal_blade",
    "item_harpoon",--
    "item_aghanims_shard",
    "item_assault",--
    "item_basher",
    "item_skadi",--
    "item_disperser",--
    "item_monkey_king_bar",--
	"item_bloodthorn",--
}

local Return
local botTarget

function X.BearThink(hero, hMinionUnit)
    bot = hero
    botTarget = Fu.GetProperTarget(bot)
    Return = hMinionUnit:GetAbilityByName('lone_druid_spirit_bear_return')

	Desire = ConsiderReturn(hMinionUnit, Return)
	if Desire > 0
	then
		hMinionUnit:Action_UseAbility(Return)
		return
	end

	RetreatDesire, RetreatLocation = ConsiderBearRetreat(hMinionUnit)
	if RetreatDesire > 0
	then
		hMinionUnit:Action_MoveToLocation(RetreatLocation)
		return
	end

	AttackDesire, AttackTarget = ConsiderBearAttack(hMinionUnit)
	if AttackDesire > 0
	then
		hMinionUnit:Action_AttackUnit(AttackTarget, false)
		return
	end

	MoveDesire, MoveLocation = ConsiderBearMove(hMinionUnit)
	if MoveDesire > 0
	then
		hMinionUnit:Action_MoveToLocation(MoveLocation)
		return
	end
end

function ConsiderReturn(hMinionUnit, ability)
    if not ability:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    if GetUnitToUnitDistance(bot, hMinionUnit) > 1100
    then
        hMinionUnit:SetTarget(nil)
        return BOT_ACTION_DESIRE_HIGH
    end

    return BOT_ACTION_DESIRE_NONE
end

function ConsiderBearRetreat(hMinionUnit)
    if Fu.IsRetreating(bot)
    then
        local nInRangeAlly = hMinionUnit:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
        local nInRangeEnemy = hMinionUnit:GetNearbyHeroes(1600, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and #nInRangeEnemy > #nInRangeAlly
        then
            return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
        end
    end

    if hMinionUnit:WasRecentlyDamagedByTower(1)
    and Fu.GetHP(hMinionUnit) < 0.5
    then
        local nEnemyTower = hMinionUnit:GetNearbyTowers(700, true)
        if nEnemyTower ~= nil and #nEnemyTower >= 1
        and GetUnitToUnitDistance(hMinionUnit, nEnemyTower[1]) < 700
        then
            return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
        end
    end

	return BOT_ACTION_DESIRE_NONE, 0
end

function ConsiderBearAttack(hMinionUnit)
    if Fu.IsPushing(bot) or Fu.IsDefending(bot)
    then
        local nEnemyTower = hMinionUnit:GetNearbyTowers(1200, true)
        if nEnemyTower ~= nil and #nEnemyTower >= 1
        then
            return BOT_ACTION_DESIRE_HIGH, nEnemyTower[1]
        end

        local nEnemyLaneCreeps = hMinionUnit:GetNearbyLaneCreeps(1600, true)
        if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 1
        then
            return BOT_ACTION_DESIRE_HIGH, nEnemyLaneCreeps[1]
        end
    end

    if Fu.IsLaning(bot)
    then
        local nEnemyLaneCreeps = hMinionUnit:GetNearbyLaneCreeps(bot:GetAttackRange(), true)

        if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 1
        then
            for _, creep in pairs(nEnemyLaneCreeps)
            do
                if Fu.IsValid(creep)
                and Fu.CanBeAttacked(creep)
                and creep:GetHealth() <= hMinionUnit:GetAttackDamage()
                then
                    return BOT_ACTION_DESIRE_HIGH, creep
                end
            end
        end
    end

    if Fu.IsFarming(bot)
    then
        local nCreeps = hMinionUnit:GetNearbyCreeps(1600, true)
        if nCreeps ~= nil and #nCreeps >= 1
        and Fu.IsAttacking(bot)
        then
            local target = nil
            local hp = 0
            for _, creep in pairs(nCreeps)
            do
                if Fu.IsValid(creep)
                and Fu.CanBeAttacked(creep)
                and hp < creep:GetHealth()
                then
                    hp = creep:GetHealth()
                    target = creep
                end
            end

            if target ~= nil
            then
                return BOT_ACTION_DESIRE_HIGH, target
            end
        end
    end

    if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot)
    then
        if (Fu.IsRoshan(bot) or Fu.IsDoingTormentor(bot))
        and Fu.IsInRange(bot, botTarget, 500)
        and Fu.IsAttacking(bot)
        then
            hMinionUnit:SetTarget(botTarget)
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderBearMove(hMinionUnit)
    if not Fu.IsInRange(bot, hMinionUnit, 700)
    then
        return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
    end

    return BOT_ACTION_DESIRE_NONE, 0
end

return X