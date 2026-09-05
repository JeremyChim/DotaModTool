dofile('bots/Buff/Helper')

if XP == nil
then
    XP = {}
end

function XP.UpdateXP(bot, xp)
	bot:AddExperience(xp, 0, false, true, bot:GetPlayerOwnerID())
end

return XP