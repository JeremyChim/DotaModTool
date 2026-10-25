-- Target selection and prioritization
local function Init(Fu)
local Teamplay=require(GetScriptDirectory()..'/FuncLib/systems/teamplay')
Teamplay.SetHeroFilter(Fu.IsSuspiciousIllusion,function(b) return Fu.GetPosition(b) end)



function Fu.GetVulnerableWeakestUnit( bot, bHero, bEnemy, nRadius )
	local unitList = {}
	if bHero
	then
		unitList = Fu.GetNearbyHeroes(bot, nRadius, bEnemy, BOT_MODE_NONE )
	else
		unitList = bot:GetNearbyLaneCreeps( nRadius, bEnemy )
	end
    return Fu.GetAttackableWeakestUnitFromList( bot, unitList )
end




function Fu.GetVulnerableUnitNearLoc( bot, bHero, bEnemy, nCastRange, nRadius, vLoc )

	local unitList = {}
	local weakest = nil
	local weakestHP = 10000

	if bHero
	then
		unitList = Fu.GetNearbyHeroes(bot, nCastRange, bEnemy, BOT_MODE_NONE )
	else
		unitList = bot:GetNearbyLaneCreeps( nCastRange, bEnemy )
	end

	for _, u in pairs( unitList )
	do
		if GetUnitToLocationDistance( u, vLoc ) < nRadius
			and u:GetHealth() < weakestHP
			and Fu.CanCastOnNonMagicImmune( u )
		then
			weakest = u
			weakestHP = u:GetHealth()
		end
	end

	return weakest

end




function Fu.GetAoeEnemyHeroLocation( bot, nCastRange, nRadius, nCount )
	-- local cacheKey = 'GetAoeEnemyHeroLocation'..tostring(bot:GetPlayerID())..'-'..tostring(nCastRange) --..'-'..tostring(nRadius)..'-'..tostring(nCount)
	-- local cache = Fu.Utils.GetCachedVars(cacheKey, 0.2)
	-- if cache ~= nil then return cache end

	local nAoe = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0 )

	if nAoe.count >= nCount
	then
		local nEnemyHeroList = Fu.GetEnemyList( bot, 1600 )
		local nTrueCount = 0
		for _, enemy in pairs( nEnemyHeroList )
		do
			if GetUnitToLocationDistance( enemy, nAoe.targetloc ) <= nRadius
				and not enemy:IsMagicImmune()
			then
				nTrueCount = nTrueCount + 1
			end
		end

		if nTrueCount >= nCount
		then
			-- Fu.Utils.SetCachedVars(cacheKey, nAoe.targetloc)
			return nAoe.targetloc
		end
	end

	-- Fu.Utils.SetCachedVars(cacheKey, nil)
	return nil

end




function Fu.GetProperTarget( bot )
 local baseTarget=require(GetScriptDirectory()..'/FuncLib/systems/base_execution').CombatTarget(bot)
 if baseTarget then return baseTarget end

	local target = nil
	
	if ( bot:GetTeam() == GetBot():GetTeam() )
	then
		target = bot:GetTarget()
	end

	if target == nil and bot:CanBeSeen()
	then
		target = bot:GetAttackTarget()
	end

	if target ~= nil
		and target:GetTeam() == bot:GetTeam()
		and ( target:IsHero() or target:IsBuilding() )
	then
		target = nil
	end

	return Teamplay.Focus(bot,target)

end




function Fu.GetMostHpUnit( unitList )

	local mostHpUnit = nil
	local maxHP = 0
	for _, unit in pairs( unitList )
	do
		local uHp = unit:GetHealth()
		if unit ~= nil
		and not Fu.IsRoshan(unit)
		and not Fu.IsTormentor(unit)
		and uHp > maxHP
		then
			mostHpUnit = unit
			maxHP = uHp
		end
	end

	return mostHpUnit

end




function Fu.GetLeastHpUnit( unitList )

	local leastHpUnit = nil
	local minHP = 999999

	for _, unit in pairs( unitList )
	do
		local uHp = unit:GetHealth()
		if uHp < minHP
		then
			leastHpUnit = unit
			minHP = uHp
		end
	end

	return leastHpUnit

end



function Fu.GetAttackableWeakestUnit( bot, nRadius, bHero, bEnemy )
    local unitList = {}
	if nRadius > 1600 then nRadius = 1600 end
    if bHero then
        unitList = Fu.GetNearbyHeroes(bot, nRadius, bEnemy, BOT_MODE_NONE )
    else
        unitList = bot:GetNearbyLaneCreeps( nRadius, bEnemy )
    end
    return Fu.GetAttackableWeakestUnitFromList( bot, unitList )
end

-- The arg `bot` here can be nil

-- The arg `bot` here can be nil
function Fu.GetAttackableWeakestUnitFromList( bot, unitList )
	if bot == nil then bot = GetBot() end

    local weakest = nil
    local bestScore = math.huge
	local attackRange = bot:GetAttackRange()

    for _, unit in pairs( unitList ) do
		if Fu.IsValidTarget(unit) then
			local hp = unit:GetHealth()
			local offensivePower = 0
			local distance = GetUnitToUnitDistance(bot, unit)
			if Fu.IsValidHero(unit) then
				offensivePower = unit:GetRawOffensivePower()
			end
			if Fu.IsValid( unit )
				and not unit:IsAttackImmune()
				and not unit:IsInvulnerable()
				and not Fu.HasForbiddenModifier( unit )
				and not Fu.IsSuspiciousIllusion( unit )
				--and not Fu.IsAllyCanKill( unit )
				and not Fu.CannotBeKilled(bot, unit)
			then
				-- Calculate score: lower score is better
				-- Can adjust the weight factors for hp and offensive power to tune the behavior
				local hpWeight = 0.7
				local powerWeight = 0.3
				local score = (hp * hpWeight) - (offensivePower * powerWeight) -- - math.min(1, attackRange / distance) * 100
	
				-- If the new score is lower, choose this unit as the weakest
				if score < bestScore then
					bestScore = score
					weakest = unit
				end
			end
		end
    end

    return weakest
end


function Fu.ConsiderTarget()

	local bot = GetBot()

	if not Fu.IsRunning( bot )
		or bot:HasModifier( "modifier_item_hurricane_pike_range" )
	then return end

	local npcTarget = Fu.GetProperTarget( bot )
	if not Fu.IsValidHero( npcTarget ) then return end

	local nAttackRange = bot:GetAttackRange() + 69
	if nAttackRange > 1600 then nAttackRange = 1600 end
	if nAttackRange < 300 then nAttackRange = 350 end

	local nInAttackRangeWeakestEnemyHero = Fu.GetAttackableWeakestUnit( bot, nAttackRange, true, true )

	if Fu.IsValidHero( nInAttackRangeWeakestEnemyHero )
		and ( GetUnitToUnitDistance( npcTarget, bot ) > nAttackRange or Fu.HasForbiddenModifier( npcTarget ) )
	then
		bot:SetTarget( nInAttackRangeWeakestEnemyHero )
		return
	end

end



function Fu.GetMostHPPercent(listUnits, magicImmune)
	local mostPHP = 0;
	local mostPHPUnit = nil;
	for _,unit in pairs(listUnits)
	do
		local uPHP = unit:GetHealth() / unit:GetMaxHealth()
		if ( ( magicImmune and Fu.CanCastOnMagicImmune(unit) ) or ( not magicImmune and Fu.CanCastOnNonMagicImmune(unit) ) ) 
			and uPHP > mostPHP  
		then
			mostPHPUnit = unit;
			mostPHP = uPHP;
		end
	end
	return mostPHPUnit;
end


function Fu.GetCanBeKilledUnit(units, nDamage, nDmgType, magicImmune)
	local target = nil
	for _,unit in pairs(units)
	do
		if ((magicImmune and Fu.CanCastOnMagicImmune(unit) ) or ( not magicImmune and Fu.CanCastOnNonMagicImmune(unit)))
			   and Fu.CanKillTarget(unit, nDamage, nDmgType)
		then
			target = unit
		end
	end
	return target
end


function Fu.GetClosestUnit(units)
	local target = nil;
	if units ~= nil and #units >= 1 then
		return units[1];
	end
	return target;
end


function Fu.GetStrongestUnit(nRange, hUnit, bEnemy, bMagicImune, fTime)
	local units = Fu.GetNearbyHeroes(hUnit,nRange, bEnemy, BOT_MODE_NONE)
	local strongest = nil
	local maxPower = 0

	for i = 1, #units do
		if Fu.IsValidTarget(units[i])
		and Fu.IsValidTarget(hUnit)
		and ((bMagicImune == true and Fu.CanCastOnMagicImmune(units[i]) == true) or (bMagicImune == false and Fu.CanCastOnNonMagicImmune(units[i]) == true))
		then
			local power = units[i]:GetEstimatedDamageToTarget(true, hUnit, fTime, DAMAGE_TYPE_ALL)

			if power > maxPower
			then
				maxPower = power
				strongest = units[i]
			end
		end
	end
	return strongest
end


function Fu.GetStrongestEnemyHero(enemies)
	local strongestenemy = nil
	local highesthealth = 0

	for v, enemy in pairs(enemies) do
		if Fu.IsValidTarget(enemy) and Fu.IsNotImmune(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			if enemy:GetHealth() > highesthealth then
				strongestenemy = enemy
				highesthealth = enemy:GetHealth()
			end
		end
	end
	return strongestenemy
end


function Fu.GetWeakestUnit(nEnemyUnits)
	return Fu.GetAttackableWeakestUnitFromList( nil, nEnemyUnits )
end


function Fu.GetHeroCountAttackingTarget(nUnits, target)
	local count = 0
	for _, hero in pairs(nUnits)
	do
		if Fu.IsValidHero(hero)
		and Fu.IsInRange(hero, target, 1600)
		and Fu.IsGoingOnSomeone(hero)
		and hero:CanBeSeen()
		and (hero:GetAttackTarget() == target or hero:GetTarget() == target)
		and not Fu.IsSuspiciousIllusion(hero)
		then
			count = count + 1
		end
	end

	return count
end


end

return Init
