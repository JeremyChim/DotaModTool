dofile('bots/Buff/Helper')

if XP == nil
then
    XP = {}
end

-- local XPNeeded = {
--     [1]  = 240,
--     [2]  = 400,
--     [3]  = 520,
--     [4]  = 600,
--     [5]  = 680,
--     [6]  = 760,
--     [7]  = 800,
--     [8]  = 900,
--     [9]  = 1000,
--     [10] = 1100,
--     [11] = 1200,
--     [12] = 1300,
--     [13] = 1400,
--     [14] = 1500,
--     [15] = 1600,
--     [16] = 1700,
--     [17] = 1800,
--     [18] = 1900,
--     [19] = 2000,
--     [20] = 2200,
--     [21] = 2400,
--     [22] = 2600,
--     [23] = 2800,
--     [24] = 3000,
--     [25] = 4000,
--     [26] = 5000,
--     [27] = 6000,
--     [28] = 7000,
--     [29] = 7500,
--     [30] = 0,
-- }

-- -- just eyeballed
-- function XP.UpdateXP(bot, nTeam)
--     local gameTime = Helper.DotaTime()
--     local botPos = Helper.GetPosition(bot, nTeam)

--     local xp = 1
--     if botPos == 1 then
--         xp = 5
--     elseif botPos == 2 then
--         xp = 4
--     elseif botPos == 3 then
--         xp = 3
--     end

--     if bot:IsAlive() and gameTime > 0 and math.floor(gameTime) % 2 == 0 then
--         bot:AddExperience(math.floor(xp), 0, false, true)
--     end
-- end

-- 每秒，加经验
function XP.UpdateXP(bot, xp)
    local gameTime = Helper.DotaTime()
    local minute = math.floor(gameTime / 60)
    if minute >= 20 then
        xp = xp * 2
    end

    -- if not bot:IsAlive() then
    --     xp = xp * 2
    -- end

    bot:AddExperience(xp, 0, false, true, bot:GetPlayerOwnerID())
end

-- 死亡时，一次性加经验
function XP.UpdateXPWhenDeath(bot, xp)
    -- local gameTime = Helper.DotaTime()
    -- local minute = math.floor(gameTime / 60)
    -- if minute >= 10 then xp = xp * 2
    -- elseif minute >= 20 then xp = xp * 3
    -- elseif minute >= 30 then xp = xp * 4
    -- end

    if bot:IsAlive() then
        bot.__buff_xp_rewarded_for_death = false
        return
    end
    if bot.__buff_xp_rewarded_for_death then return end

    bot:AddExperience(xp, 0, false, true, bot:GetPlayerOwnerID())
    bot.__buff_xp_rewarded_for_death = true
end

return XP
