local X             = {}
local bot           = GetBot()

local Fu             = require( GetScriptDirectory()..'/FuncLib/func_utils' )
local AbilityCtx = require(GetScriptDirectory()..'/FuncLib/systems/ability_context')
local Army=require(GetScriptDirectory()..'/FuncLib/hero/minion_lib/chen_army')
local Minion        = require( GetScriptDirectory()..'/FuncLib/hero/minion' )
local sTalentList   = Fu.Skill.GetTalentList( bot )
local sAbilityList  = Fu.Skill.GetAbilityList( bot )
local sRole   = Fu.Item.GetRoleItemsBuyList( bot )

local tTalentTreeList = {
                        {--pos4
                            ['t25'] = {0, 10},
                            ['t20'] = {0, 10},
                            ['t15'] = {10, 0},
                            ['t10'] = {0, 10},
                        },
                        {--pos5
                            ['t25'] = {0, 10},
                            ['t20'] = {0, 10},
                            ['t15'] = {10, 0},
                            ['t10'] = {0, 10},
                        }
}

local tAllAbilityBuildList = {
                        {2,1,2,1,2,6,2,3,3,3,6,3,1,1,6},--pos4
                        {1,2,2,3,2,6,3,1,1,1,6,3,3,3,6},--pos5
}

local nAbilityBuildList
local nTalentBuildList

if sRole == "pos_4"
then
    nAbilityBuildList   = tAllAbilityBuildList[1]
    nTalentBuildList    = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
    nAbilityBuildList   = tAllAbilityBuildList[2]
    nTalentBuildList    = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_1'] = {
    "item_tango",
    "item_double_branches",
    "item_faerie_fire",

    "item_boots",
    "item_magic_wand",
    "item_dagon_2",
    "item_travel_boots",
    "item_aghanims_shard",
    "item_cyclone",
    "item_ultimate_scepter",
    "item_octarine_core",--
    "item_dagon_5",--
    "item_ultimate_scepter_2",
    "item_shivas_guard",
    "item_travel_boots_2",--
    "item_wind_waker",--
    "item_moon_shard",
}

sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_1']

sRoleItemsBuyList['pos_3'] = {
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_rod_of_atos",
	"item_gungir",--
	"item_aghanims_shard",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_4'] = {
    "item_blood_grenade",

	"item_priest_outfit",
	"item_mekansm",
    "item_vladmir",--
	"item_glimmer_cape",--
	"item_aghanims_shard",
	"item_guardian_greaves",--
	"item_spirit_vessel",--
--	"item_wraith_pact",
	"item_shivas_guard",--
	"item_sheepstick",--
    "item_ultimate_scepter_2",
	"item_moon_shard",
}

sRoleItemsBuyList['pos_5'] = {
	"item_mage_outfit",
	"item_shadow_amulet",
	"item_glimmer_cape",
	"item_pipe",
--	"item_wraith_pact",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_mystic_staff",
	"item_sheepstick",
	"item_octarine_core",--
	"item_ultimate_scepter_2",
}

X['sBuyList'] = sRoleItemsBuyList[sRole]

Pos4SellList = {
	
}

Pos5SellList = {
	
}

X['sSellList'] = {
	"item_shivas_guard",
	"item_magic_wand",

	"item_sheepstick",
	"item_magic_wand",
}


if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_antimage' }, {} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = Fu.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = Fu.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = false
X['bDeafaultItem'] = false

function X.MinionThink(hMinionUnit)
    if not Army.Think(bot,hMinionUnit,Fu)then Minion.MinionThink(hMinionUnit)end
end

local Penitence         = SafeAbility(bot:GetAbilityByName('chen_penitence'), 'chen_penitence', 'chen')
local HolyPersuasion    = SafeAbility(bot:GetAbilityByName('chen_holy_persuasion'), 'chen_holy_persuasion', 'chen')
local DivineFavor       = SafeAbility(bot:GetAbilityByName('chen_divine_favor'), 'chen_divine_favor', 'chen')
local SummonConvert     = SafeAbility(bot:GetAbilityByName('chen_summon_convert'), 'chen_summon_convert', 'chen')
local Zealot            = SafeAbility(bot:GetAbilityByName('chen_zealot'), 'chen_zealot', 'chen')
local HandOfGod         = SafeAbility(bot:GetAbilityByName('chen_hand_of_god'), 'chen_hand_of_god', 'chen')

local PenitenceDesire, PenitenceTarget
local HolyPersuasionDesire, HolyPersuasionTarget
local DivineFavorDesire, DivineFavorTarget
local SummonConvertDesire
local ZealotDesire
local HandOfGodDesire

local nChenCreeps = {}

local botTarget

local bAttacking
function X.SkillsComplement()
    HolyPersuasion=SafeAbility(bot:GetAbilityByName('chen_holy_persuasion'),'chen_holy_persuasion','chen')
    Zealot=SafeAbility(bot:GetAbilityByName('chen_zealot'),'chen_zealot','chen')
    nChenCreeps=Army.Units(bot)
	if Fu.CanNotUseAbility(bot) then return end

	local ctx = AbilityCtx.Build(bot)
	bAttacking = Fu.IsAttacking(bot)

    botTarget = ctx.target

    HandOfGodDesire = X.ConsiderHandOfGod()
    if HandOfGodDesire > 0
    then
        bot:Action_UseAbility(HandOfGod)
        return
    end

    PenitenceDesire, PenitenceTarget = X.ConsiderPenitence()
    if PenitenceDesire > 0
    then
        bot:Action_UseAbilityOnEntity(Penitence, PenitenceTarget)
        return
    end

    SummonConvertDesire = X.ConsiderSummonConvert()
    if SummonConvertDesire > 0
    then
        bot:Action_UseAbility(SummonConvert)
        return
    end

    ZealotDesire = X.ConsiderZealot()
    if ZealotDesire > 0
    then
        bot:Action_UseAbilityOnEntity(Zealot,bot)
        return
    end

    HolyPersuasionDesire, HolyPersuasionTarget = X.ConsiderHolyPersuasion()
    if HolyPersuasionDesire > 0
    then
        bot:Action_UseAbilityOnEntity(HolyPersuasion, HolyPersuasionTarget)
        return
    end

    DivineFavorDesire, DivineFavorTarget = X.ConsiderDivineFavor()
    if DivineFavorDesire > 0
    then
        bot:Action_UseAbilityOnEntity(DivineFavor, DivineFavorTarget)
        return
    end
    Army.RouteRecruit(bot,HolyPersuasion,Fu)
end

function X.ConsiderPenitence()
    if not Penitence:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = Fu.GetProperCastRange(false, bot, Penitence:GetCastRange())
    local nAttackRange = bot:GetAttackRange()

    local nAllyHeroes = Fu.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
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
            and Fu.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and allyHero:GetCurrentMovementSpeed() < nAllyInRangeEnemy[1]:GetCurrentMovementSpeed()
            and not Fu.IsDisabled(nAllyInRangeEnemy[1])
            and not Fu.IsTaunted(nAllyInRangeEnemy[1])
            and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
            then
                return BOT_ACTION_DESIRE_HIGH, nAllyInRangeEnemy[1]
            end
        end
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and not Fu.IsSuspiciousIllusion(botTarget)
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                if Fu.IsChasingTarget(bot, botTarget)
                and bot:GetCurrentMovementSpeed() < botTarget:GetCurrentMovementSpeed()
                then
                    return BOT_ACTION_DESIRE_HIGH, botTarget
                end

                nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
                if Fu.IsInRange(bot, botTarget, nAttackRange)
                and bAttacking
                and Fu.GetHeroCountAttackingTarget(nInRangeAlly, botTarget) >= 2
                then
                    return BOT_ACTION_DESIRE_HIGH, botTarget
                end
            end
		end
	end

	if Fu.IsRetreating(bot)
	then
        local nInRangeEnemy = Fu.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if Fu.IsValidHero(enemyHero)
            and Fu.IsChasingTarget(enemyHero, bot)
            and not Fu.IsSuspiciousIllusion(enemyHero)
            and not Fu.IsDisabled(enemyHero)
            then
                local nInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
                local nTargetInRangeAlly = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and ((#nTargetInRangeAlly > #nInRangeAlly)
                    or bot:WasRecentlyDamagedByAnyHero(1.5))
                and bot:GetCurrentMovementSpeed() < enemyHero:GetCurrentMovementSpeed()
                then
                    return BOT_ACTION_DESIRE_HIGH, enemyHero
                end
            end
        end
	end

	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot)
	then
        local nInRangeAlly = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)

		if (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
        and Fu.IsInRange(bot, botTarget, nCastRange)
        and bAttacking
        and nInRangeAlly ~= nil and #nInRangeAlly >= 1
        and Fu.GetHeroCountAttackingTarget(nInRangeAlly, botTarget) >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderHolyPersuasion()
 return Army.Recruit(bot,HolyPersuasion,Fu)
end

function X.ConsiderDivineFavor()
 if not DivineFavor:IsFullyCastable()then return 0,nil end
 local army=Army.Units(bot);local active,wounded=0,0
 for _,u in ipairs(army)do
  if Fu.IsValid(u)and GetUnitToUnitDistance(bot,u)<1200 then
   if u:GetAttackTarget()then active=active+1 end
   if Fu.GetHP(u)<.65 then wounded=wounded+1 end
  end
 end
 if active>=2 or wounded>=2 and Fu.IsInTeamFight(bot,1200)then return BOT_ACTION_DESIRE_HIGH,bot end
 local range=Fu.GetProperCastRange(false,bot,DivineFavor:GetCastRange())
 for _,a in ipairs(bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)or{})do
  if Fu.IsValidHero(a)and not a:IsIllusion()and not a:HasModifier('modifier_chen_divine_favor_armor_buff')
   and not a:HasModifier('modifier_chen_divine_favor')and(a:WasRecentlyDamagedByAnyHero(2)and Fu.GetHP(a)<.7
    or Fu.IsCore(a)and Fu.IsGoingOnSomeone(a))then return BOT_ACTION_DESIRE_HIGH,a end
 end
 return 0,nil
end

function X.ConsiderSummonConvert()
    if not SummonConvert:IsFullyCastable()
    or X.IsThereChenCreepAlive()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    if Fu.IsGoingOnSomeone(bot)
	then
		if Fu.IsValidTarget(botTarget)
        and Fu.IsInRange(bot, botTarget, 900)
        and not Fu.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
		then
            local nInRangeAlly = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
            local nInRangeEnemy = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
            and #nInRangeAlly >= #nInRangeEnemy
            then
                return BOT_ACTION_DESIRE_HIGH
            end
		end
	end

    if (Fu.IsFarming(bot) or Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsLaning(bot))
    and bAttacking
    then
        return BOT_ACTION_DESIRE_HIGH
    end

    if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot)
	then
		if (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
        and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
        and bAttacking
		then
            return BOT_ACTION_DESIRE_HIGH
        end
	end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderZealot()
 return Army.Recall(bot,Zealot,Fu)
end

function X.ConsiderHandOfGod()
	if not HandOfGod:IsFullyCastable()
    then
		return BOT_ACTION_DESIRE_NONE
	end

    local nTeamFightLocation = Fu.GetTeamFightLocation(bot)

    if nTeamFightLocation ~= nil
    then
        local nAllyList = Fu.GetAlliesNearLoc(nTeamFightLocation, 1600)

        for _, allyHero in pairs(nAllyList)
        do
            if Fu.IsValidHero(allyHero)
            and Fu.IsCore(allyHero)
            and Fu.GetHP(allyHero) < 0.5
            and not allyHero:IsIllusion()
            and not allyHero:IsAttackImmune()
			and not allyHero:IsInvulnerable()
            and not allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
            and not allyHero:HasModifier('modifier_oracle_false_promise_timer')
            then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES))
    do
        local nAllyInRangeEnemy = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)

        if Fu.IsValidHero(allyHero)
        and Fu.IsRetreating(allyHero) and allyHero:GetActiveModeDesire() >= 0.65
        and Fu.IsCore(allyHero)
        and Fu.GetHP(allyHero) < 0.5
        and allyHero:WasRecentlyDamagedByAnyHero(1)
        and not allyHero:IsIllusion()
        and not allyHero:IsAttackImmune()
		and not allyHero:IsInvulnerable()
        and not allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
        and not allyHero:HasModifier('modifier_oracle_false_promise_timer')
        then
            if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
            and Fu.IsValidHero(nAllyInRangeEnemy[1])
            and Fu.IsChasingTarget(nAllyInRangeEnemy[1], allyHero)
            and not Fu.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
            then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE
end

function X.IsThereChenCreepAlive()
 return #Army.Units(bot)>0
end

return X