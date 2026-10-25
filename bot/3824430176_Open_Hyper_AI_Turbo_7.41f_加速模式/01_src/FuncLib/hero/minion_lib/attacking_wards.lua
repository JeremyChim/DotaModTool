local Fu = require(GetScriptDirectory()..'/FuncLib/func_utils')
local U = require(GetScriptDirectory()..'/FuncLib/hero/minion_lib/utils')

local X = {}

-- Shadow Shaman only: discover attackable structures without relying on
-- incoming-damage estimates, which can return zero for buildings.
local function SerpentBuildingTarget(ward, range)
    local function Attackable(unit)
        return U.IsValidTarget(unit) and unit:IsBuilding()
            and unit:GetTeam()~=ward:GetTeam() and not U.IsNotAllowedToAttack(unit)
            and GetUnitToUnitDistance(ward,unit)<=range+unit:GetBoundingRadius()
    end
    local current=ward:GetAttackTarget()
    if Attackable(current) then return current end
    local buildings={}
    for _,unit in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS) or {}) do
        buildings[#buildings+1]=unit
    end
    -- Minion proximity queries can omit buildings; combine both sources.
    for _,list in ipairs({ward:GetNearbyTowers(range,true) or {},
        ward:GetNearbyBarracks(range,true) or {},ward:GetNearbyFillers(range,true) or {}}) do
        for _,unit in pairs(list) do buildings[#buildings+1]=unit end
    end
    local enemyTeam=ward:GetTeam()==TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
    local ancient=GetAncient(enemyTeam)
    if ancient then buildings[#buildings+1]=ancient end
    local best,health
    for _,unit in pairs(buildings) do
        if Attackable(unit) and (health==nil or unit:GetHealth()<health) then
            best,health=unit,unit:GetHealth()
        end
    end
    return best
end

function X.Think(bot, hMinionUnit)
	-- Use the minion's own attack range. Owner's GetAttackRange() collapses to
	-- 200 via the override when the owner is not visible (glimmer, dead-fade,
	-- smoke), which would shrink the ward's search radius and starve it of
	-- targets even though the ward itself is fine.
	local thisMinionAttackRange = hMinionUnit:GetAttackRange()
	if thisMinionAttackRange == nil or thisMinionAttackRange < 400 then
		thisMinionAttackRange = 500
	end

	local target = U.GetWeakestHero(thisMinionAttackRange, hMinionUnit)
	if target == nil then
		target = U.GetWeakestCreep(thisMinionAttackRange, hMinionUnit)
		if target == nil then
			if string.find(hMinionUnit:GetUnitName(),'npc_dota_shadow_shaman_ward',1,true) then
                target=SerpentBuildingTarget(hMinionUnit,thisMinionAttackRange)
            else
                target = U.GetWeakestTower(thisMinionAttackRange, hMinionUnit)
            end
		end
	end

	if target == nil or U.IsNotAllowedToAttack(target) then
		return
	end

	-- Don't re-issue the same target every tick — that cancels the ward's
	-- attack windup and it ends up never landing a hit. Only issue when the
	-- target actually changes.
	if hMinionUnit._lastWardTarget == target and hMinionUnit:GetAttackTarget() == target then
		return
	end
	hMinionUnit._lastWardTarget = target
	hMinionUnit:Action_AttackUnit(target, false)
end

return X