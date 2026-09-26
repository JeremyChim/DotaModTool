dofile('bots/Buff/Helper')

if XP == nil
then
    XP = {}
end

function XP.UpdateXP(bot, xp)
    local gameTime = Helper.DotaTime()
    local minute = math.floor(gameTime / 60)

    if minute >= 15 then
        xp = xp * 2
    end

    if not bot:IsAlive() then
        xp = xp * 2
    end

    bot:AddExperience(xp, 0, false, true, bot:GetPlayerOwnerID())
end

return XP