-- Location, geometry, vector, and line-of-sight utilities
local function Init(Fu)



function Fu.IsAllyHeroBetweenAllyAndEnemy( hAlly, hEnemy, vLoc, nRadius )

	local vStart = hAlly:GetLocation()
	local vEnd = vLoc
	local heroList = Fu.GetNearbyHeroes( hAlly, 1600, false, BOT_MODE_NONE )
	for i, hero in pairs( heroList )
	do
		if hero ~= hAlly
		then
			local tResult = PointToLineDistance( vStart, vEnd, hero:GetLocation() )
			if tResult ~= nil
				and tResult.within
				and tResult.distance <= nRadius + 50
			then
				return true
			end
		end
	end

	heroList = Fu.GetNearbyHeroes( hEnemy, 1600, true, BOT_MODE_NONE )
	for i, hero in pairs( heroList )
	do
		if hero ~= hAlly
		then
			local tResult = PointToLineDistance( vStart, vEnd, hero:GetLocation() )
			if tResult ~= nil
				and tResult.within
				and tResult.distance <= nRadius + 50
			then
				return true
			end
		end
	end

	return false

end



function Fu.IsInRange( bot, npcTarget, nRadius )
	if npcTarget == nil or not npcTarget:CanBeSeen() then
		return false
	end

	return GetUnitToUnitDistance( bot, npcTarget ) <= nRadius

end




function Fu.IsInLocRange( npcTarget, nLoc, nRadius )
	if not npcTarget:CanBeSeen() then
		return false
	end

	return GetUnitToLocationDistance( npcTarget, nLoc ) <= nRadius

end



function Fu.GetCorrectLoc( npcTarget, fDelay )

	local nStability = npcTarget:GetMovementDirectionStability()

	local vFirst = npcTarget:GetLocation()
	local vFuture = npcTarget:GetExtrapolatedLocation( fDelay )
	local vMidFutrue = ( vFirst + vFuture ) * 0.5
	local vLowFutrue = ( vFirst + vMidFutrue ) * 0.5
	local vHighFutrue = ( vFuture + vMidFutrue ) * 0.5


	if nStability < 0.5
	then
		return vLowFutrue
	elseif nStability < 0.7
	then
		return vMidFutrue
	elseif nStability < 0.9
	then
		return vHighFutrue
	end

	return vFuture
end


function Fu.GetLocationToLocationDistance( fLoc, sLoc )

	local x1 = fLoc.x
	local x2 = sLoc.x
	local y1 = fLoc.y
	local y2 = sLoc.y

	return math.sqrt( math.pow( ( y2-y1 ), 2 ) + math.pow( ( x2-x1 ), 2 ) )

end




function Fu.GetUnitTowardDistanceLocation( bot, towardTarget, nDistance )

	local npcBotLocation = bot:GetLocation()
	local tempVector = ( towardTarget:GetLocation() - npcBotLocation ) / GetUnitToUnitDistance( bot, towardTarget )

	return npcBotLocation + nDistance * tempVector

end




function Fu.GetLocationTowardDistanceLocation( bot, towardLocation, nDistance )

	local npcBotLocation = bot:GetLocation()
	local tempVector = ( towardLocation - npcBotLocation ) / GetUnitToLocationDistance( bot, towardLocation )

	return npcBotLocation + nDistance * tempVector

end




function Fu.GetFaceTowardDistanceLocation( bot, nDistance )

	local npcBotLocation = bot:GetLocation()
	local tempRadians = bot:GetFacing() * math.pi / 180
	local tempVector = Vector( math.cos( tempRadians ), math.sin( tempRadians ) )

	return npcBotLocation + nDistance * tempVector

end




function Fu.GetCastLocation( bot, npcTarget, nCastRange, nRadius )

	local nDistance = GetUnitToUnitDistance( bot, npcTarget )

	if nDistance <= nCastRange
	then
		return npcTarget:GetLocation()
	end

	if nDistance <= nCastRange + nRadius - 120
	then
		return Fu.GetUnitTowardDistanceLocation( bot, npcTarget, nCastRange )
	end

	if nDistance < nCastRange + nRadius - 18
		and ( ( Fu.IsDisabled( npcTarget ) or npcTarget:GetCurrentMovementSpeed() <= 160 )
				or npcTarget:IsFacingLocation( bot:GetLocation(), 45 )
				or ( bot:IsFacingLocation( npcTarget:GetLocation(), 45 ) and npcTarget:GetCurrentMovementSpeed() <= 220 ) )
	then
		return Fu.GetUnitTowardDistanceLocation( bot, npcTarget, nCastRange +18 )
	end

	if nDistance < nCastRange + nRadius + 28
		and npcTarget:IsFacingLocation( bot:GetLocation(), 30 )
		and bot:IsFacingLocation( npcTarget:GetLocation(), 30 )
		and npcTarget:GetMovementDirectionStability() > 0.95
		and npcTarget:GetCurrentMovementSpeed() >= 300
	then
		return Fu.GetUnitTowardDistanceLocation( bot, npcTarget, nCastRange + 18 )
	end

	return nil

end




function Fu.GetDelayCastLocation( bot, npcTarget, nCastRange, nRadius, nTime )

	local nFutureLoc = Fu.GetCorrectLoc( npcTarget, nTime )
	local nDistance = GetUnitToLocationDistance( bot, nFutureLoc )

	if nDistance > nCastRange + nRadius - 16
	then
		return nil
	end

	if nDistance > nCastRange - nRadius * 0.38
	then
		return Fu.GetLocationTowardDistanceLocation( bot, nFutureLoc, nCastRange +8 )
	end

	return nFutureLoc

end




function Fu.GetCenterOfUnits( nUnits )

	if #nUnits == 0
	then
		return Vector( 0.0, 0.0 )
	end

	local sum = Vector( 0.0, 0.0 )
	local num = 0

	for _, unit in pairs( nUnits )
	do
		if Fu.IsValid(unit)
		then
			sum = sum + unit:GetLocation()
			num = num + 1
		end
	end

	if num == 0 then return Vector( 0.0, 0.0 ) end

	return sum / num

end


function Fu.GetNearestLaneFrontLocation( nUnitLoc, bEnemy, fDeltaFromFront )

	local nTeam = GetTeam()
	if bEnemy then nTeam = GetOpposingTeam() end

	local nTopLoc = GetLaneFrontLocation( nTeam, LANE_TOP, fDeltaFromFront )
	local nMidLoc = GetLaneFrontLocation( nTeam, LANE_MID, fDeltaFromFront )
	local nBotLoc = GetLaneFrontLocation( nTeam, LANE_BOT, fDeltaFromFront )

	local nTopDist = Fu.GetLocationToLocationDistance( nUnitLoc, nTopLoc )
	local nMidDist = Fu.GetLocationToLocationDistance( nUnitLoc, nMidLoc )
	local nBotDist = Fu.GetLocationToLocationDistance( nUnitLoc, nBotLoc )

	if nTopDist < nMidDist and nTopDist < nBotDist
	then
		return nTopLoc
	end

	if nBotDist < nMidDist and nBotDist < nTopDist
	then
		return nBotLoc
	end

	return nMidLoc

end


function Fu.RandomForwardVector(length)

    local offset = RandomVector(length)

    if GetTeam() == TEAM_RADIANT then
        offset.x = offset.x > 0 and offset.x or -offset.x
        offset.y = offset.y > 0 and offset.y or -offset.y
    end

    if GetTeam() == TEAM_DIRE then
        offset.x = offset.x < 0 and offset.x or -offset.x
        offset.y = offset.y < 0 and offset.y or -offset.y
    end

    return offset
end


function Fu.GetDistance(s, t)
    return math.sqrt((s[1] - t[1]) * (s[1]-t[1]) + (s[2] - t[2]) * (s[2] - t[2]))
end


function Fu.IsHeroBetweenMeAndLocation(hSource, vLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vLoc
	local bot = GetBot()

	local nAllyHeroes = Fu.GetNearbyHeroes(bot,1600, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nAllyHeroes)
    do
		if allyHero ~= hSource
		then
			local tResult = PointToLineDistance(vStart, vEnd, allyHero:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
		end
	end

	local nEnemyHeroes = Fu.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
    do
		if enemyHero ~= hSource
		and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local tResult = PointToLineDistance(vStart, vEnd, enemyHero:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
		end
	end

	return false
end


function Fu.IsEnemyBetweenMeAndLocation(hSource, vLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vLoc
	local bot = GetBot()

	local nEnemyHeroes = Fu.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
    do
		if enemyHero ~= hSource
		and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local tResult = PointToLineDistance(vStart, vEnd, enemyHero:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
		end
	end

	return false
end


function Fu.IsHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vLoc

	local nAllyHeroes = Fu.GetNearbyHeroes(hSource,1600, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nAllyHeroes)
    do
		if allyHero ~= hTarget and allyHero ~= hSource
		then
			local tResult = PointToLineDistance(vStart, vEnd, allyHero:GetLocation())
			if tResult ~= nil and tResult.within == true and tResult.distance < nRadius then return true end
		end
	end

	local nEnemyHeroes = Fu.GetNearbyHeroes(hSource,1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
    do
		if enemyHero ~= hTarget and enemyHero ~= hSource
		then
			local tResult = PointToLineDistance(vStart, vEnd, enemyHero:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
		end
	end

	return false
end


function Fu.IsCreepBetweenMeAndLocation(hSource, vLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vLoc
	local bot = GetBot()

	local nAllyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	for _, creep in pairs(nAllyLaneCreeps)
    do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
		if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
	end

	local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, false)
	for _, creep in pairs(nEnemyLaneCreeps)
    do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())

		if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
	end

	return false
end


function Fu.IsUnitBetweenMeAndLocation(hSource, hTarget, vTargetLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vTargetLoc

	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL))
	do
		if Fu.IsValid(unit)
		and GetUnitToUnitDistance(GetBot(), unit) <= 1600
		and not unit:IsBuilding()
		and not string.find(unit:GetUnitName(), 'ward')
		and hSource ~= unit
		and hTarget ~= unit
		then
			local nRadius__ = nRadius + unit:GetBoundingRadius()
			local tResult = PointToLineDistance(vStart, vEnd, unit:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius__ then return true end end
	end

	return false
end


function Fu.IsCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vLoc
	local creeps = hSource:GetNearbyCreeps(1600, false)
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius then
			return true
		end
	end
	
	if hTarget:IsHero() then
		creeps = hTarget:GetNearbyCreeps(1600, true)
		for i,creep in pairs(creeps) do
			local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius then
				return true
			end
		end
	end
	
	creeps = hSource:GetNearbyCreeps(1600, true)
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius then
			return true
		end
	end
	
	if hTarget:IsHero() then
		creeps = hTarget:GetNearbyCreeps(1600, false)
		for i,creep in pairs(creeps) do
			local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius then
				return true
			end
		end
	end
	
	return false
end

-- function Fu.IsEnemyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
-- 	local vStart = hSource:GetLocation()
-- 	local vEnd = vLoc

-- 	local nAllyLaneCreeps = hTarget:GetNearbyLaneCreeps(1600, false)
-- 	for _, creep in pairs(nAllyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
-- 	end

-- 	local nEnemyLaneCreeps = hSource:GetNearbyLaneCreeps(1600, true)
-- 	for _, creep in pairs(nEnemyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
-- 	end

-- 	return false
-- end

-- function Fu.IsAllyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
-- 	local vStart = hSource:GetLocation()
-- 	local vEnd = vLoc

-- 	local nAllyLaneCreeps = hSource:GetNearbyLaneCreeps(1600, false)
-- 	for _, creep in pairs(nAllyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then
-- 			return true
-- 		end
-- 	end

-- 	local nEnemyLaneCreeps = hTarget:GetNearbyLaneCreeps(1600, true)
-- 	for _, creep in pairs(nEnemyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then
-- 			return true
-- 		end
-- 	end

-- 	return false
-- end


-- function Fu.IsEnemyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
-- 	local vStart = hSource:GetLocation()
-- 	local vEnd = vLoc

-- 	local nAllyLaneCreeps = hTarget:GetNearbyLaneCreeps(1600, false)
-- 	for _, creep in pairs(nAllyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
-- 	end

-- 	local nEnemyLaneCreeps = hSource:GetNearbyLaneCreeps(1600, true)
-- 	for _, creep in pairs(nEnemyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then return true end
-- 	end

-- 	return false
-- end

-- function Fu.IsAllyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
-- 	local vStart = hSource:GetLocation()
-- 	local vEnd = vLoc

-- 	local nAllyLaneCreeps = hSource:GetNearbyLaneCreeps(1600, false)
-- 	for _, creep in pairs(nAllyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then
-- 			return true
-- 		end
-- 	end

-- 	local nEnemyLaneCreeps = hTarget:GetNearbyLaneCreeps(1600, true)
-- 	for _, creep in pairs(nEnemyLaneCreeps)
-- 	do
-- 		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation())
-- 		if tResult ~= nil and tResult.within and tResult.distance < nRadius then
-- 			return true
-- 		end
-- 	end

-- 	return false
-- end

function Fu.IsAllyHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation()
	local vEnd = vLoc

	local nAllyHeroes = Fu.GetNearbyHeroes(hSource, 1600, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nAllyHeroes)
	do
		if allyHero ~= hSource
		then
			local tResult = PointToLineDistance(vStart, vEnd, allyHero:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then return true end
		end
	end

	local nEnemyHeroes = Fu.GetNearbyHeroes(hTarget, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if enemyHero ~= hSource
		and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local tResult = PointToLineDistance(vStart, vEnd, enemyHero:GetLocation())
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then return true end
		end
	end

	return false
end

function Fu.AdjustLocationWithOffset(vLoc, offset, target)
	local targetLoc = vLoc

	local facingDir = target:GetFacing()
	local offsetX = offset * math.cos(facingDir)
	local offsetY = offset * math.sin(facingDir)

	targetLoc = targetLoc + Vector(offsetX, offsetY)

	return targetLoc
end


function Fu.AdjustLocationWithOffsetTowardsFountain(loc, distance)
	return Fu.Utils.GetOffsetLocationTowardsTargetLocation(loc, Fu.GetTeamFountain(), distance)
end


function Fu.GetXUnitsTowardsLocation2(iLoc, tLoc, nUnits)
    local dir = (tLoc - iLoc):Normalized()
    return iLoc + dir * nUnits
end


function Fu.GetRandomLocationWithinDist(sLoc, minDist, maxDist)
	local randomAngle = math.random() * 2 * math.pi
	local randomDist = math.random(minDist, maxDist)
	local newX = sLoc.x + randomDist * math.cos(randomAngle)
	local newY = sLoc.y + randomDist * math.sin(randomAngle)
	return Vector(newX, newY, sLoc.z)
end


function Fu.AreTreesBetween(bot, loc, r)
	local nTrees = bot:GetNearbyTrees(GetUnitToLocationDistance(bot, loc))

	for _, tree in pairs(nTrees)
	do
		local x = GetTreeLocation(tree)
		local y = bot:GetLocation()
		local z = loc

		if x ~= y
		then
			local a = 1
			local b = 1
			local c = 0

			if x.x - y.x == 0
			then
				b = 0
				c = -x.x
			else
				a = -(x.y - y.y) / (x.x - y.x)
				c = -(x.y + x.x * a)
			end

			local d = math.abs((a*z.x+b*z.y+c)/math.sqrt(a*a+b*b))

			if d <= r
			and GetUnitToLocationDistance(bot,loc) > Fu.GetDistance(x, loc) + 50
			then
				return true
			end
		end
	end

	return false
end


function Fu.VectorTowards(vStart, vTowards, nDistance)
	local vDirection = (vTowards - vStart):Normalized()
	return vStart + (vDirection * nDistance)
end


function Fu.VectorAway(vStart, vTowards, nDistance)
	local vDirection = (vStart - vTowards):Normalized()
	return vStart + (vDirection * nDistance)
end


function Fu.GetBestRetreatTree(bot, nCastRange)
	local nTrees = bot:GetNearbyTrees(nCastRange)
	local dest = Fu.VectorTowards(bot:GetLocation(), Fu.GetTeamFountain(), 1000)

	local bestRetreatTree = nil
	local maxDist = 0

	for _, tree in pairs(nTrees)
	do
		local nTreeLoc = GetTreeLocation(tree)

		if not Fu.AreTreesBetween(bot, nTreeLoc, 100)
		and GetUnitToLocationDistance(bot, nTreeLoc) > maxDist
		and GetUnitToLocationDistance(bot, nTreeLoc) < nCastRange
		and Fu.GetDistance(nTreeLoc, dest) < 880
		then
			maxDist = GetUnitToLocationDistance(bot, nTreeLoc)
			bestRetreatTree = loc
		end
	end

	if bestRetreatTree ~= nil
	and maxDist > bot:GetAttackRange()
	then
		return bestRetreatTree
	end

	return bestRetreatTree
end


function Fu.GetBestTree(bot, enemyLoc, enemy, nCastRange, hitRadios)
	local bestTree = nil
	local nTrees = bot:GetNearbyTrees(nCastRange)
	local dist = 10000

	for _, tree in pairs(nTrees)
	do
		local x = GetTreeLocation(tree)
		local y = bot:GetLocation()
		local z = enemyLoc

		if x ~= y
		then
			local a = 1
			local b = 1
			local c = 0

			if x.x - y.x == 0
			then
				b = 0
				c = -x.x
			else
				a=-(x.y-y.y)/(x.x-y.x);
				c=-(x.y + x.x*a);
			end

			local d = math.abs((a * z.x + b * z.y + c) / math.sqrt(a * a + b * b))
			if d <= hitRadios
			and dist > GetUnitToLocationDistance(enemy, x)
			and (GetUnitToLocationDistance(enemy, x) <= GetUnitToLocationDistance(bot, x))
			then
				bestTree = tree
				dist = GetUnitToLocationDistance(enemy, x)
			end
		end
	end

	return bestTree
end


function Fu.GetUltLoc(bot, target, nManaCost, nCastRange, s)
	local v = target:GetVelocity()
	local sv = Fu.GetDistance(Vector(0,0), v)
	if sv > 800
	then
		v = (v / sv) * target:GetCurrentMovementSpeed()
	end

	local x= bot:GetLocation()
	local y= target:GetLocation()

	local a = v.x * v.x + v.y * v.y - s * s
	local b = -2 * (v.x * (x.x - y.x) + v.y * (x.y - y.y))
	local c = (x.x - y.x) * (x.x - y.x) + (x.y - y.y) * (x.y - y.y)

	local t = math.max((-b + math.sqrt(b * b - 4 * a * c)) / (2 * a), (-b - math.sqrt(b * b - 4 * a * c)) / (2 * a))
	local dest = (t + 0.35) * v + y

	if GetUnitToLocationDistance(bot, dest) > nCastRange
	or bot:GetMana() < 100 + nManaCost
	then
		return nil
	end

	if target:GetMovementDirectionStability() < 0.4
	or not bot:IsFacingLocation(target:GetLocation(), 60)
	then
		dest = Fu.VectorTowards(y, Fu.GetEnemyFountain(), 180)
	end

	if Fu.IsDisabled(target)
	then
		dest = target:GetLocation()
	end

	return dest
end


return J

end

return Init
