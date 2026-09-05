dofile('bots/Buff/Helper')

if GPM == nil
then
    GPM = {}
end

function GPM.UpdateBotGold(bot, gold)
	bot:ModifyGold(gold, true, 0)
end

return GPM