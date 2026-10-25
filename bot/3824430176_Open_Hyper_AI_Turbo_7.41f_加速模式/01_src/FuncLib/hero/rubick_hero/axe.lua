local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')

local BerserkersCall
local BattleHunger
local CullingBlade

local botTarget

local nMP, hEnemyList, hAllyList

function X.ConsiderStolenSpell(ability)
    bot = GetBot()

    if Fu.CanNotUseAbility(bot) then return end

    nMP = bot:GetMana() / bot:GetMaxMana()
    hEnemyList = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	hAllyList = Fu.GetAlliesNearLoc( bot:GetLocation(), 1600 )

    botTarget = Fu.GetProperTarget(bot)
    local abilityName = ability:GetName()

    if abilityName == 'axe_culling_blade'
    then
        CullingBlade = ability
        CullingBladeDesire, CullingBladeTarget = X.ConsiderCullingBlade()
        if CullingBladeDesire > 0
        then
            bot:Action_UseAbilityOnEntity(CullingBlade, CullingBladeTarget)
            return
        end
    end

    if abilityName == 'axe_berserkers_call'
    then
        BerserkersCall = ability
        BerserkersCallDesire = X.ConsiderBerserkersCall()
        if BerserkersCallDesire > 0
        then
            bot:Action_UseAbility(BerserkersCall)
            return
        end
    end

    if abilityName == 'axe_battle_hunger'
    then
        BattleHunger = ability
        BattleHungerDesire, BattleHungerTarget = X.ConsiderBattleHunger()
        if BattleHungerDesire > 0
        then
            bot:Action_UseAbilityOnEntity(BattleHunger, BattleHungerTarget)
            return
        end
    end
end

function X.ConsiderBerserkersCall()
	if not BerserkersCall:IsFullyCastable() then return 0 end

	local nRadius = BerserkersCall:GetSpecialValueInt( 'radius' )
	local nManaCost = BerserkersCall:GetManaCost()
	local nInRangeEnemyList = Fu.GetAroundEnemyHeroList( nRadius - 50 )

	for _, npcEnemy in pairs( nInRangeEnemyList )
	do
		if npcEnemy:IsChanneling()
			and not npcEnemy:IsMagicImmune()
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	
	if Fu.IsGoingOnSomeone( bot )
	then
		if Fu.IsValidHero( botTarget )
			and Fu.IsInRange( botTarget, bot, nRadius - 90 )
			and Fu.CanCastOnNonMagicImmune( botTarget )			
			and not Fu.IsDisabled( botTarget )
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	if ( Fu.IsPushing( bot ) or Fu.IsDefending( bot ) or Fu.IsFarming( bot ) )
		and Fu.IsAllowedToSpam( bot, nManaCost )
		and bot:GetAttackTarget() ~= nil
		and DotaTime() > 6 * 60
		and #hAllyList <= 2 
		and #hEnemyList == 0
	then
		local laneCreepList = bot:GetNearbyLaneCreeps( nRadius - 50, true )
		if #laneCreepList >= 4
			and not laneCreepList[1]:HasModifier( "modifier_fountain_glyph" )
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	if bot:GetActiveMode() == BOT_MODE_ROSHAN
	then
		if Fu.IsRoshan( botTarget )
			and not Fu.IsDisabled( botTarget )
			and not botTarget:IsDisarmed()
			and Fu.IsInRange( botTarget, bot, nRadius )
            and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	

	return BOT_ACTION_DESIRE_NONE


end


function X.ConsiderBattleHunger()
	if not BattleHunger:IsFullyCastable() then return 0 end

	local nSkillLV = BattleHunger:GetLevel()
	local nCastRange = Fu.GetProperCastRange(false, bot, BattleHunger:GetCastRange())
	local nManaCost = BattleHunger:GetManaCost()
	local nDuration = BattleHunger:GetSpecialValueInt( 'duration' )
	local nDamage = BattleHunger:GetSpecialValueInt( 'damage_per_second' ) * nDuration
	local nInRangeEnemyList = Fu.GetAroundEnemyHeroList( nCastRange )
	local nInBonusEnemyList = Fu.GetAroundEnemyHeroList( nCastRange + 200 )

	for _, npcEnemy in pairs( nInRangeEnemyList )
	do 
		if Fu.IsValid( npcEnemy )
			and Fu.CanCastOnNonMagicImmune( npcEnemy )
			and Fu.CanCastOnTargetAdvanced( npcEnemy )
			and Fu.WillMagicKillTarget( bot, npcEnemy, nDamage , nDuration )
			and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
		end
	
	end
	
	if Fu.IsGoingOnSomeone( bot )
	then
		if Fu.IsValidHero( botTarget )
			and Fu.IsInRange( botTarget, bot, nCastRange )
			and Fu.CanCastOnNonMagicImmune( botTarget )			
			and Fu.CanCastOnTargetAdvanced( botTarget )
			and not botTarget:HasModifier( 'modifier_axe_battle_hunger_self' )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	
	if Fu.IsInTeamFight( bot, 1200 )
	then
		local npcWeakestEnemy = nil
		local npcWeakestEnemyHealth = 100000

		for _, npcEnemy in pairs( nInBonusEnemyList )
		do
			if Fu.IsValid( npcEnemy )
				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
				and Fu.CanCastOnNonMagicImmune( npcEnemy )
				and Fu.CanCastOnTargetAdvanced( npcEnemy )
			then
				local npcEnemyHealth = npcEnemy:GetHealth()
				if ( npcEnemyHealth < npcWeakestEnemyHealth )
				then
					npcWeakestEnemyHealth = npcEnemyHealth
					npcWeakestEnemy = npcEnemy
				end
			end
		end

		if npcWeakestEnemy ~= nil
		then
			return BOT_ACTION_DESIRE_HIGH, npcWeakestEnemy
		end
	end

	if Fu.IsLaning( bot ) and nMP > 0.5
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do 
			if Fu.IsValid( npcEnemy )
				and Fu.CanCastOnNonMagicImmune( npcEnemy )
				and Fu.CanCastOnTargetAdvanced( npcEnemy )
				and npcEnemy:GetAttackTarget() == nil
				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		
		end	
	end
	
	if Fu.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if Fu.IsValid( npcEnemy )
				and Fu.CanCastOnNonMagicImmune( npcEnemy )
				and Fu.CanCastOnTargetAdvanced( npcEnemy )
				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end

	if Fu.IsFarming( bot )
		and nSkillLV >= 2
		and Fu.IsAllowedToSpam( bot, nManaCost * 0.25 )
	then
		local neutralCreepList = bot:GetNearbyNeutralCreeps( nCastRange + 100 )

		local targetCreep = Fu.GetMostHpUnit( neutralCreepList )

		if Fu.IsValid( targetCreep )
			and not Fu.IsRoshan( targetCreep )
			and not targetCreep:HasModifier( 'modifier_axe_battle_hunger_self' )
			and ( targetCreep:GetMagicResist() < 0.3 )
			and not Fu.CanKillTarget( targetCreep, bot:GetAttackDamage() * 2.88, DAMAGE_TYPE_PHYSICAL )
		then
			return BOT_ACTION_DESIRE_HIGH, targetCreep
	    end
	end

	if bot:GetActiveMode() == BOT_MODE_ROSHAN
	then
		if Fu.IsRoshan( botTarget )
			and not Fu.IsDisabled( botTarget )
			and Fu.IsInRange( botTarget, bot, nCastRange )
			and not botTarget:HasModifier( 'modifier_axe_battle_hunger_self' )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

	return BOT_ACTION_DESIRE_NONE
end


function X.ConsiderCullingBlade()


	if not CullingBlade:IsFullyCastable() then return 0 end

	local nSkillLV = CullingBlade:GetLevel()
	local nCastRange = Fu.GetProperCastRange(false, bot, CullingBlade:GetCastRange())

	local nKillDamage = 150 + 100 * nSkillLV

	local nInBonusEnemyList = Fu.GetAroundEnemyHeroList( nCastRange + 200 )

	for _, npcEnemy in pairs( nInBonusEnemyList )
	do
		if Fu.IsValidHero( npcEnemy )
			and npcEnemy:CanBeSeen()
			and npcEnemy:GetHealth() + npcEnemy:GetHealthRegen() * 0.8 < nKillDamage
			and not Fu.IsHaveAegis( npcEnemy )
			and not npcEnemy:IsInvulnerable()
			and not npcEnemy:IsMagicImmune()
			and not X.HasSpecialModifier( npcEnemy )
			and not X.IsKillBotAntiMage( npcEnemy )
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
		end
	end


	return BOT_ACTION_DESIRE_NONE


end

function X.HasSpecialModifier( npcEnemy )

	if npcEnemy:HasModifier( 'modifier_winter_wyvern_winters_curse' )
		or npcEnemy:HasModifier( 'modifier_winter_wyvern_winters_curse_aura' )
		or npcEnemy:HasModifier( 'modifier_antimage_spell_shield' )
		or npcEnemy:HasModifier( 'modifier_item_lotus_orb_active' )
		or npcEnemy:HasModifier( 'modifier_item_aeon_disk_buff' )
		or npcEnemy:HasModifier( 'modifier_item_sphere_target' )
		or npcEnemy:HasModifier( 'modifier_illusion' )
	then
		return true
	else
		return false	
	end

end

function X.IsKillBotAntiMage( npcEnemy )

	if not npcEnemy:IsBot() 
		or npcEnemy:GetUnitName() ~= 'npc_dota_hero_antimage'
		or npcEnemy:IsStunned()
		or npcEnemy:IsHexed()
		or npcEnemy:IsNightmared()
		or npcEnemy:IsChanneling()
		or Fu.IsTaunted( npcEnemy )
	then
		return false
	end
	
	return true

end

return X