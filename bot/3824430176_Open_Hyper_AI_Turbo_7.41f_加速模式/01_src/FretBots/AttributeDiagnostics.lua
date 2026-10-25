-- Read-only snapshots. A missing diagnostic API never interrupts bonuses.
local X={}
local Emit=require('bots/FuncLib/systems/log').emit or print
local function Read(bot,method,...)
 local ok,value=pcall(function(...) return bot[method](bot,...) end,...)
 return ok and type(value)=='number' and string.format('%.3f',value) or 'unavailable'
end
function X.Snapshot(bot,phase)
 local ok,err=pcall(function()
  local time=-999
  if GameRules and GameRules.GetDOTATime then time=GameRules:GetDOTATime(false,false) end
  local awards=bot.stats and bot.stats.awards or {}
  Emit(string.format('[FRET_ATTR] t=%.2f hero=%s phase=%s difficulty=%s maxhp=%s str=%s agi=%s int=%s armor_base=%s armor_total=%s magic_base=%s awarded_stats=%s awarded_armor=%s awarded_magic=%s',
   time,bot:GetUnitName(),phase,tostring(Settings and Settings.difficulty),Read(bot,'GetMaxHealth'),
   Read(bot,'GetStrength'),Read(bot,'GetAgility'),Read(bot,'GetIntellect'),Read(bot,'GetPhysicalArmorBaseValue'),
   Read(bot,'GetPhysicalArmorValue',false),Read(bot,'GetBaseMagicalResistanceValue'),
   tostring(awards.stats),tostring(awards.armor),tostring(awards.magicResist)))
 end)
 if not ok then Emit('[FRET_ATTR] diagnostic_unavailable '..tostring(err)) end
end
return X
