dofile('bots/Buff/Helper')

if GPM == nil
then
    GPM = {}
end

-- Reasonable GPM (XPM later)
function GPM.TargetGPM(time)
    if time <= 10 * 60 then
        return 450
    elseif time <= 20 * 60 then
        return 600
    elseif time <= 30 * 60 then
        return 750
    elseif time <= 50 * 60 then
        return 900
    else
        return 1050
    end
end

function GPM.UpdateBotGold(bot, nTeam)
    local isCore = Helper.IsCore(bot, nTeam)
    local gameTime = Helper.DotaTime()
    local targetGPM = GPM.TargetGPM(gameTime)

    local currentGPM = PlayerResource:GetGoldPerMin(bot:GetPlayerID())
    local missing = targetGPM - currentGPM
    local goldPerTick = 75/60

    if isCore then
        goldPerTick = goldPerTick + math.max(0, missing / 60)
    end

    if bot:IsAlive() and gameTime >= 60 then
        if Helper.IsTurboMode() then
            goldPerTick = isCore and 120/60 or 0
        end

        bot:ModifyGold(math.ceil(goldPerTick), true, 0)
    end
end

return GPM