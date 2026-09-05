dofile('bots/Buff/Helper')

if Attributes == nil then
    Attributes = {}
end

function Attributes.UpdateAttr(bot, attr)
    local gameTime = Helper.DotaTime()
    local minute = math.floor(gameTime / 60)
    if bot.__buff_attr_last_minute == nil then bot.__buff_attr_last_minute = -1 end
    if bot.__buff_attr_last_minute == minute then return end
    if minute < 1 or minute > 30 then return end
    if not bot:IsAlive() then attr = attr + 1 end
    bot:ModifyStrength(attr)
    bot:ModifyAgility(attr)
    bot:ModifyIntellect(attr)
    bot.__buff_attr_last_minute = minute
end

return Attributes
