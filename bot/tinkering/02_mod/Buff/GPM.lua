dofile('bots/Buff/Helper')

if GPM == nil
then
    GPM = {}
end

function GPM.UpdateBotGold(bot, gold)
    local gameTime = Helper.DotaTime()
    local minute = math.floor(gameTime / 60)

    if minute >= 15 then
        gold = gold * 2
    end

    if not bot:IsAlive() then
        gold = gold * 2
    end

    bot:ModifyGold(gold, true, 0)
end

return GPM