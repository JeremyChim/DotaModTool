-- Special unit data, Techies mines, power cogs, tower targeting
local function Init(Fu)

local SpecialUnits = {
	['npc_dota_clinkz_skeleton_archer'] = 0.75,
	['npc_dota_juggernaut_healing_ward'] = 0.9,
	['npc_dota_invoker_forged_spirit'] = 0.9,
	['npc_dota_grimstroke_ink_creature'] = 1,
	['npc_dota_ignis_fatuus'] = 1,
	['npc_dota_lone_druid_bear1'] = 0.9,
	['npc_dota_lone_druid_bear2'] = 0.9,
	['npc_dota_lone_druid_bear3'] = 0.9,
	['npc_dota_lone_druid_bear4'] = 0.9,
	['npc_dota_lycan_wolf_1'] = 0.75,
	['npc_dota_lycan_wolf_2'] = 0.75,
	['npc_dota_lycan_wolf_3'] = 0.75,
	['npc_dota_lycan_wolf_4'] = 0.75,
	['npc_dota_observer_wards'] = 1,
	['npc_dota_phoenix_sun'] = 1,
	['npc_dota_venomancer_plague_ward_1'] = 0.75,
	['npc_dota_venomancer_plague_ward_2'] = 0.75,
	['npc_dota_venomancer_plague_ward_3'] = 0.75,
	['npc_dota_venomancer_plague_ward_4'] = 0.75,
	['npc_dota_rattletrap_cog'] = 0.9,
	['npc_dota_sentry_wards'] = 1,
	['npc_dota_unit_tombstone1'] = 1,
	['npc_dota_unit_tombstone2'] = 1,
	['npc_dota_unit_tombstone3'] = 1,
	['npc_dota_unit_tombstone4'] = 1,
	['npc_dota_warlock_golem_1'] = 0.9,
	['npc_dota_warlock_golem_2'] = 0.9,
	['npc_dota_warlock_golem_3'] = 0.9,
	['npc_dota_warlock_golem_scepter_1'] = 0.9,
	['npc_dota_warlock_golem_scepter_2'] = 0.9,
	['npc_dota_warlock_golem_scepter_3'] = 0.9,
	['npc_dota_weaver_swarm'] = 0.9,
	['npc_dota_zeus_cloud'] = 0.75,
}
function Fu.GetSpecialUnits()
	return SpecialUnits
end

function Fu.IsUnitNearby(bot, tUnits, nRadius, sUnitName, bHero)
    for _, unit in pairs(tUnits) do
        if Fu.IsValid(unit)
        and Fu.IsInRange(bot, unit, nRadius)
        and unit:GetUnitName() == sUnitName
        then
			if bHero then
				if Fu.IsValidHero(unit) and not Fu.IsSuspiciousIllusion(unit) then
					return true
				end
			else
				return true
			end
        end
    end
    return false
end

function Fu.IsUnitTargetedByTower(hUnit, bTeam)
	local nUnitType = (bTeam and UNIT_LIST_ALLIED_BUILDINGS) or UNIT_LIST_ENEMY_BUILDINGS
	local nUnitList = GetUnitList(nUnitType)
	for _, building in pairs(nUnitList) do
		if Fu.IsValidBuilding(building) and building:GetAttackTarget() == hUnit then
			return true
		end
	end
	return false
end

function Fu.IsBigCamp(nUnits)
	for _, creep in pairs(nUnits)
	do
		if Fu.IsValid(creep)
		then
			if creep:GetUnitName() == 'npc_dota_neutral_satyr_hellcaller'
			or creep:GetUnitName() == 'npc_dota_neutral_polar_furbolg_ursa_warrior'
			or creep:GetUnitName() == 'npc_dota_neutral_dark_troll_warlord'
			or creep:GetUnitName() == 'npc_dota_neutral_centaur_khan'
			or creep:GetUnitName() == 'npc_dota_neutral_enraged_wildkin'
			or creep:GetUnitName() == 'npc_dota_neutral_warpine_raider'
			then
				return true
			end
		end
	end
end

function Fu.GetTechiesMines()
	local nMinesList = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES))
    do
		if unit ~= nil
        and unit:GetUnitName() == 'npc_dota_techies_land_mine'
        then
			table.insert(nMinesList, unit)
		end
	end
	return nMinesList
end

function Fu.GetTechiesMinesInLoc(loc, nRadius)
	local nMinesList = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES))
    do
		if unit ~= nil
        and unit:GetUnitName() == 'npc_dota_techies_land_mine'
		and GetUnitToLocationDistance(unit, loc) <= nRadius
        then
			table.insert(nMinesList, unit)
		end
	end
	return nMinesList
end

function Fu.GetPowerCogsCountInLoc(loc, nRadius)
	local count = 0
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL))
	do
		if Fu.IsValid(unit)
		and string.find(unit:GetUnitName(), 'rattletrap_cog')
		and GetUnitToLocationDistance(unit, loc) <= nRadius
		then
			count = count + 1
		end
	end
	return count
end

end

return Init
