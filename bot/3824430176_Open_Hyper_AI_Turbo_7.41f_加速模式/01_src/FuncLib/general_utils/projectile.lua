-- Projectile detection and enemy spell casting checks
local function Init(Fu)

function Fu.IsAllyUnitSpell( sAbilityName )
	return Fu.Skill['sAllyUnitAbilityIndex'][sAbilityName] == true
end

function Fu.IsProjectileUnitSpell( sAbilityName )
	return Fu.Skill['sProjectileAbilityIndex'][sAbilityName] == true
end

function Fu.IsOnlyProjectileSpell( sAbilityName )
	return Fu.Skill['sOnlyProjectileAbilityIndex'][sAbilityName] == true
end

function Fu.IsStunProjectileSpell( sAbilityName )
	return Fu.Skill['sStunProjectileAbilityIndex'][sAbilityName] == true
end

function Fu.IsWillBeCastUnitTargetSpell( bot, nRadius )
	if nRadius > 1600 then nRadius = 1600 end
	local enemyList = Fu.GetNearbyHeroes(bot, nRadius, true, BOT_MODE_NONE )
	for _, npcEnemy in pairs( enemyList )
	do
		if npcEnemy ~= nil and npcEnemy:IsAlive()
			and ( npcEnemy:IsCastingAbility() or npcEnemy:IsUsingAbility() )
			and npcEnemy:IsFacingLocation( bot:GetLocation(), 20 )
		then
			local nAbility = npcEnemy:GetCurrentActiveAbility()
			if nAbility ~= nil
				and nAbility:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET
			then
				local sAbilityName = nAbility:GetName()
				if not Fu.IsAllyUnitSpell( sAbilityName )
				then
					if Fu.IsInRange( npcEnemy, bot, 330 )
						or not Fu.IsProjectileUnitSpell( sAbilityName )
					then
						if not Fu.IsHumanPlayer( npcEnemy )
						then
							return true
						else
							local nCycle = npcEnemy:GetAnimCycle()
							local nPoint = nAbility:GetCastPoint()
							if nCycle > 0.1 and nPoint * ( 1 - nCycle ) < 0.27
							then
								return true
							end
						end
					end
				end
			end
		end
	end
	return false
end

function Fu.IsWillBeCastPointSpell( bot, nRadius )
	local enemyList = Fu.GetNearbyHeroes(bot, nRadius, true, BOT_MODE_NONE )
	for _, npcEnemy in pairs( enemyList )
	do
		if npcEnemy ~= nil and npcEnemy:IsAlive()
			and ( npcEnemy:IsCastingAbility() or npcEnemy:IsUsingAbility() )
			and npcEnemy:IsFacingLocation( bot:GetLocation(), 50 )
		then
			local nAbility = npcEnemy:GetCurrentActiveAbility()
			if nAbility ~= nil
			then
				if nAbility:GetBehavior() == ABILITY_BEHAVIOR_POINT
					or nAbility:GetBehavior() == ABILITY_BEHAVIOR_NO_TARGET
					or nAbility:GetBehavior() == 48
				then
					return true
				end
			end
		end
	end
	return false
end

function Fu.IsProjectileIncoming( bot, range )
	local incProj = bot:GetIncomingTrackingProjectiles()
	for _, p in pairs( incProj )
	do
		if p.is_dodgeable
			and not p.is_attack
			and GetUnitToLocationDistance( bot, p.location ) < range
			and ( p.caster == nil or p.caster:GetTeam() ~= GetTeam() )
			and ( p.ability ~= nil
					and not Fu.IsOnlyProjectileSpell( p.ability:GetName() )
					and ( p.ability:GetName() ~= "medusa_mystic_snake"
							or p.caster == nil
							or p.caster:GetUnitName() == "npc_dota_hero_medusa" ) )
		then
			return true
		end
	end
	return false
end

function Fu.IsUnitTargetProjectileIncoming( bot, range )
	local incProj = bot:GetIncomingTrackingProjectiles()
	for _, p in pairs( incProj )
	do
		if not p.is_attack
			and GetUnitToLocationDistance( bot, p.location ) < range
			and ( p.caster == nil
				 or ( p.caster:GetTeam() ~= bot:GetTeam()
					 and p.caster:IsHero()
					 and p.caster:GetUnitName() ~= "npc_dota_hero_antimage"
					 and p.caster:GetUnitName() ~= "npc_dota_hero_templar_assassin" ) )
			and ( p.ability ~= nil
				 and ( p.ability:GetName() ~= "medusa_mystic_snake"
						or p.caster == nil
						or p.caster:GetUnitName() == "npc_dota_hero_medusa" ) )
			and ( p.ability:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET
				 or not Fu.IsOnlyProjectileSpell( p.ability:GetName() ) )
		then
			return true
		end
	end
	return false
end

function Fu.IsStunProjectileIncoming( bot, range )
	local incProj = bot:GetIncomingTrackingProjectiles()
	for _, p in pairs( incProj )
	do
		if not p.is_attack
			and GetUnitToLocationDistance( bot, p.location ) < range
			and p.ability ~= nil
			and Fu.IsStunProjectileSpell( p.ability:GetName() )
		then
			return true
		end
	end
	return false
end

function Fu.IsAttackProjectileIncoming( bot, range )
	local incProj = bot:GetIncomingTrackingProjectiles()
	for _, p in pairs( incProj )
	do
		if p.is_attack
			and GetUnitToLocationDistance( bot, p.location ) < range
		then
			return true
		end
	end
	return false
end

function Fu.IsNotAttackProjectileIncoming( bot, range )
	local incProj = bot:GetIncomingTrackingProjectiles()
	for _, p in pairs( incProj )
	do
		if not p.is_attack
			and GetUnitToLocationDistance( bot, p.location ) < range
			and ( p.caster == nil or p.caster:GetTeam() ~= bot:GetTeam() )
			and ( p.ability ~= nil
					and ( p.ability:GetName() ~= "medusa_mystic_snake"
							or p.caster == nil
							or p.caster:GetUnitName() == "npc_dota_hero_medusa" ) )
		then
			return true
		end
	end
	return false
end

local sIgnoreAbilityIndex = {
	["antimage_blink"] = true,
	["arc_warden_magnetic_field"] = true,
	["arc_warden_spark_wraith"] = true,
	["arc_warden_tempest_double"] = true,
	["chaos_knight_phantasm"] = true,
	["clinkz_burning_army"] = true,
	["death_prophet_exorcism"] = true,
	["dragon_knight_elder_dragon_form"] = true,
	["juggernaut_healing_ward"] = true,
	["necrolyte_death_pulse"] = true,
	["necrolyte_sadist"] = true,
	["omniknight_guardian_angel"] = true,
	["phantom_assassin_blur"] = true,
	["pugna_nether_ward"] = true,
	["skeleton_king_mortal_strike"] = true,
	["sven_warcry"] = true,
	["sven_gods_strength"] = true,
	["templar_assassin_refraction"] = true,
	["templar_assassin_psionic_trap"] = true,
	["windrunner_windrun"] = true,
	["witch_doctor_voodoo_restoration"] = true,
}

function Fu.DidEnemyCastAbility()
	local bot = GetBot()
	local nEnemyHeroes = Fu.GetNearbyHeroes(bot,1200, true, BOT_MODE_NONE)
	for _, npcEnemy in pairs(nEnemyHeroes)
	do
		if npcEnemy ~= nil and npcEnemy:IsAlive()
		and npcEnemy:IsFacingLocation(bot:GetLocation(), 30)
		and (npcEnemy:IsCastingAbility() or npcEnemy:IsUsingAbility())
		then
			local nAbility = npcEnemy:GetCurrentActiveAbility()
			if nAbility ~= nil
			then
				local nAbilityBehavior = nAbility:GetBehavior()
				local sAbilityName = nAbility:GetName()
				if nAbilityBehavior ~= ABILITY_BEHAVIOR_UNIT_TARGET
				and (npcEnemy:IsBot() or npcEnemy:GetLevel() >= 5)
				and not sIgnoreAbilityIndex[sAbilityName]
				then
					return true
				end
				if nAbilityBehavior == ABILITY_BEHAVIOR_UNIT_TARGET
				and npcEnemy:GetLevel() >= 6
				and not npcEnemy:IsBot()
				and not Fu.IsAllyUnitSpell(sAbilityName)
				and (not Fu.IsProjectileUnitSpell(sAbilityName) or Fu.IsInRange(bot, npcEnemy, 400))
				then
					return true
				end
			end
		end
	end
	return false
end

end

return Init
