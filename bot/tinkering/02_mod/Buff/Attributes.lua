dofile('bots/Buff/Helper')

if Attributes == nil then
    Attributes = {}
end




-- 每分钟，加经验
function Attributes.UpdateAttr(bot, attr)
    local gameTime = Helper.DotaTime()
    local minute = math.floor(gameTime / 60)
    if bot.__buff_attr_last_minute == nil then bot.__buff_attr_last_minute = -1 end
    if bot.__buff_attr_last_minute == minute then return end
    if minute < 1 or minute > 20 then return end
    --if not bot:IsAlive() then
    bot:ModifyStrength(attr)
    bot:ModifyAgility(attr)
    bot:ModifyIntellect(attr)
    --end
    bot.__buff_attr_last_minute = minute
end




-- 死亡时，一次性加属性
function Attributes.UpdateAttrWhenDeath(bot, attr, max)
    if bot:IsAlive() then
        bot.__buff_attr_rewarded_for_death = false
        return
    end
    if bot.__buff_attr_rewarded_for_death then return end

    if bot.__buff_death_attr_total == nil then
        bot.__buff_death_attr_total = 0
    end

    local remaining = max - bot.__buff_death_attr_total
    if remaining <= 0 then return end

    local amount = math.min(attr, remaining)
    bot:ModifyStrength(amount)
    bot:ModifyAgility(amount)
    bot:ModifyIntellect(amount)
    bot.__buff_death_attr_total = bot.__buff_death_attr_total + amount
    bot.__buff_attr_rewarded_for_death = true
end

return Attributes
