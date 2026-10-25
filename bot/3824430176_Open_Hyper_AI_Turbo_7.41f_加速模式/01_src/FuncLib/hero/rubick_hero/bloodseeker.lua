local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local Bloodrage
local BloodRite
local BloodMist
local Rupture

local botTarget
local nHP

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

	nHP = bot:GetHealth()/bot:GetMaxHealth()

    if abilityName == 'bloodseeker_blood_mist'
    then
        BloodMist = ability
        BloodMistDesire = X.ConsiderBloodMist()
        if BloodMistDesire > 0
        then
            bot:Action_UseAbility(BloodMist)
            return
        end
    end

	if abilityName == 'bloodseeker_rupture'
    then
        Rupture = ability
        RuptureDesire, RuptureTarget = X.ConsiderRupture()
        if RuptureDesire > 0
        then
            bot:Action_UseAbilityOnEntity(Rupture, RuptureTarget)
            return
        end
    end

    if abilityName == 'bloodseeker_bloodrage'
    then
        Bloodrage = ability
        BloodrageDesire, BloodrageTarget = X.ConsiderBloodrage()
        if BloodrageDesire > 0
        then
            bot:Action_UseAbilityOnEntity(Bloodrage, BloodrageTarget)
            return
        end
    end

    if abilityName == 'bloodseeker_blood_bath'
    then
        BloodRite = ability
        BloodRiteDesire, BloodRiteLocation = X.ConsiderBloodRite()
        if BloodRiteDesire > 0
        then
            bot:Action_UseAbilityOnLocation(BloodRite, BloodRiteLocation)
            return
        end
    end
end

function X.ConsiderBloodrage()

	if not Bloodrage:IsFullyCastable() then return 0 end

	local nCastRange = Fu.GetProperCastRange(false, bot, Bloodrage:GetCastRange())
	local nDamage = bot:GetAttackDamage()

	if Fu.IsInTeamFight( bot, 1200 ) or Fu.IsPushing( bot ) or Fu.IsDefending( bot )
	then
		local tableNearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE )

		if #tableNearbyEnemyHeroes >= 1 then
			local tableNearbyAllyHeroes = Fu.GetNearbyHeroes(bot, nCastRange + 200, false, BOT_MODE_NONE )
			local highesAD = 0
			local highesADUnit = nil

			for _, npcAlly in pairs( tableNearbyAllyHeroes )
			do
				local AllyAD = npcAlly:GetAttackDamage()
				if ( Fu.IsValid( npcAlly )
					and npcAlly:GetAttackTarget() ~= nil
					and Fu.CanCastOnNonMagicImmune( npcAlly )
					and ( Fu.GetHP( npcAlly ) > 0.18 or Fu.GetHP( npcAlly:GetAttackTarget() ) < 0.18 )
					and not npcAlly:HasModifier( 'modifier_bloodseeker_bloodrage' )
					and AllyAD > highesAD )
				then
					highesAD = AllyAD
					highesADUnit = npcAlly
				end
			end

			if highesADUnit ~= nil then
				return BOT_ACTION_DESIRE_HIGH, highesADUnit
			end

		end

	end

	if Fu.IsGoingOnSomeone( bot )
	then
		if Fu.IsValidHero( botTarget )
			and Fu.CanCastOnMagicImmune( botTarget )
			and Fu.IsInRange( botTarget, bot, 600 )
		then
			if not bot:HasModifier( 'modifier_bloodseeker_bloodrage' )
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end

	if Fu.IsValid( botTarget ) and botTarget:GetTeam() == TEAM_NEUTRAL
		and not bot:HasModifier( 'modifier_bloodseeker_bloodrage' )
	then
		local tableNearbyCreeps = bot:GetNearbyCreeps( 1000, true )
		for _, ECreep in pairs( tableNearbyCreeps )
		do
			if Fu.IsValid( ECreep ) and not Fu.CanKillTarget( ECreep, nDamage, DAMAGE_TYPE_PHYSICAL ) 
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end

	if ( bot:GetActiveMode() == BOT_MODE_ROSHAN )
	then
		if not bot:HasModifier( 'modifier_bloodseeker_bloodrage' )
			and bot:GetAttackTarget() ~= nil
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end


	return BOT_ACTION_DESIRE_NONE, 0

end

function X.ConsiderBloodRite()

	if not BloodRite:IsFullyCastable()  then return 0 end

	local nRadius = 600
	local nCastRange = Fu.GetProperCastRange(false, bot, BloodRite:GetCastRange())
	local nCastPoint = BloodRite:GetCastPoint()
	local nDelay = BloodRite:GetSpecialValueFloat( 'delay' )
	local nManaCost = BloodRite:GetManaCost()
	local nDamage = BloodRite:GetSpecialValueInt( 'damage' )

	local tableNearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
	local tableNearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )

	for _, npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if Fu.IsValid( npcEnemy ) and Fu.CanCastOnNonMagicImmune( npcEnemy ) and Fu.CanKillTarget( npcEnemy, nDamage, DAMAGE_TYPE_PURE )
		then
			if npcEnemy:GetMovementDirectionStability() >= 0.75 then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetExtrapolatedLocation( nDelay )
			else
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation()
			end
		end
	end

	if bot:GetActiveMode() == BOT_MODE_LANING and Fu.IsAllowedToSpam( bot, nManaCost )
	then
		local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), 1000, nRadius/2, nCastPoint, nDamage )
		if ( locationAoE.count >= 4 )
		then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc
		end
	end

	if ( Fu.IsPushing( bot ) or Fu.IsDefending( bot ) ) and Fu.IsAllowedToSpam( bot, nManaCost )
		and tableNearbyEnemyHeroes == nil or #tableNearbyEnemyHeroes == 0
		and #tableNearbyAllyHeroes <= 2
	then
		local lanecreeps = bot:GetNearbyLaneCreeps( 1000, true )
		local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), 1000, nRadius/2, nCastPoint, nDamage )
		if ( locationAoE.count >= 4 and #lanecreeps >= 4 )
		then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc
		end
	end

	if Fu.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( Fu.IsValid( npcEnemy ) and bot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) and Fu.CanCastOnNonMagicImmune( npcEnemy ) )
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end

	if Fu.IsInTeamFight( bot, 1200 )
	then
		local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange - 200, nRadius/2, nCastPoint, 0 )
		if ( locationAoE.count >= 2 )
		then
			local nInvUnit = Fu.GetInvUnitInLocCount( bot, nCastRange, nRadius/2, locationAoE.targetloc, false )
			if nInvUnit >= locationAoE.count then
				return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc
			end
		end
	end

	if Fu.IsGoingOnSomeone( bot )
	then
		if Fu.IsValidHero( botTarget )
			and Fu.CanCastOnNonMagicImmune( botTarget )
			and Fu.IsInRange( botTarget, bot, nCastRange + nRadius )
		then
			local nCastLoc = Fu.GetDelayCastLocation( bot, botTarget, nCastRange, nRadius, 2.0 )
			if nCastLoc ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nCastLoc
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0

end

function X.ConsiderRupture()
	if not Rupture:IsFullyCastable() then 	return 0 end

	local nCastRange = Rupture:GetCastRange()

	local tableNearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, nCastRange + 200, true, BOT_MODE_NONE )

	if Fu.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if bot:WasRecentlyDamagedByHero( npcEnemy, 1.0 )
				and Fu.CanCastOnNonMagicImmune( npcEnemy )
				and Fu.CanCastOnTargetAdvanced( npcEnemy )
				and not npcEnemy:HasModifier( 'modifier_bloodseeker_rupture' )
			then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy
			end
		end
	end

	if Fu.IsInTeamFight( bot, 1200 )
	then
		for _, npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if Fu.CanCastOnNonMagicImmune( npcEnemy )
				and Fu.CanCastOnTargetAdvanced( npcEnemy )
				and Fu.Role.IsCarry( npcEnemy:GetUnitName() )
				and not npcEnemy:HasModifier( 'modifier_bloodseeker_rupture' )
				and not Fu.IsDisabled( npcEnemy )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end

	if Fu.IsGoingOnSomeone( bot )
	then
		if Fu.IsValidHero( botTarget )
			and Fu.CanCastOnNonMagicImmune( botTarget )
			and Fu.CanCastOnTargetAdvanced( botTarget )
			and Fu.IsInRange( botTarget, bot, nCastRange + 100 )
			and not botTarget:HasModifier( 'modifier_bloodseeker_rupture' )
			and not Fu.IsDisabled( botTarget )
		then
			local allies = Fu.GetNearbyHeroes(botTarget,  1200, true, BOT_MODE_NONE )
			if ( allies ~= nil and #allies >= 2 )
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0

end

function X.ConsiderBloodMist()
	if not bot:HasScepter()
	or not BloodMist:IsFullyCastable()
	then
		return BOT_MODE_NONE
	end

	local nRadius = 450
	local nInRangeEnemyHeroList = Fu.GetNearbyHeroes(bot,nRadius, true, BOT_MODE_NONE)

	if BloodMist:GetToggleState() == true
	then
		if nHP < 0.2
		then
			return BOT_ACTION_DESIRE_HIGH
		end

		if #nInRangeEnemyHeroList == 0
		then
			return BOT_ACTION_DESIRE_ABSOLUTE
		end
	end

	if not BloodMist:GetToggleState() == false
	and nHP > 0.5
	then
		if Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, nRadius * 0.8)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	return BOT_MODE_NONE
end

return X