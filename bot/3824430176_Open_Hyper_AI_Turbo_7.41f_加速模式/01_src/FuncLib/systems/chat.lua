-- ============================================================
-- Chat system: bot name display, item name localization, and
-- chat reply logic (keyword matching, taunt detection, mirroring)
-- ============================================================
local Chat = {}
local sRawLanguage = 'sRawName'
local Localization = require( GetScriptDirectory()..'/FuncLib/systems/localization' )
local Customize = require(GetScriptDirectory()..'/FuncLib/systems/custom_loader')

-- Data tables loaded from separate files
Chat['tItemNameList'] = require( GetScriptDirectory()..'/FuncLib/data/item_names' )
Chat['tHeroNameList'] = require( GetScriptDirectory()..'/FuncLib/data/hero_names' )

-- Build a fast lookup: internal item name -> Chinese display name
local sChineseItemNameIndexList = {}
for _, v in pairs( Chat['tItemNameList'] ) do
	sChineseItemNameIndexList[v['sRawName']] = v['sCnName']
end

-- Get the Chinese display name for an item's internal name
function Chat.GetItemCnName( sRawName )
	return sChineseItemNameIndexList[sRawName] or ("未定义:"..sRawName)
end

-- Get the localized hero name (based on current language setting)
function Chat.GetLocalName( bot )
	local tBotName = Chat['tHeroNameList'][bot:GetUnitName()]
	if tBotName ~= nil then
		return tBotName[sRawLanguage]
	end
end

-- Get the short Chinese nickname for a hero (used in debug/chat output)
function Chat.GetNormName( bot )
	local tBotName = Chat['tHeroNameList'][bot:GetUnitName()]
	return tBotName ~= nil and tBotName['sNormName'] or string.sub( bot:GetUnitName(), 10 )
end

-- ============================================================
-- Chat reply system
-- ============================================================
-- tChatStringTable format: { {keywords}, {team_replies}, {all_chat_replies} }
-- Build an index: keyword -> table index, merging duplicates
local tChatStringTable = require( GetScriptDirectory()..'/FuncLib/data/chat_table' )
local tChatStringIndex = {}

for idx = 1, #tChatStringTable do
	local keywords = tChatStringTable[idx][1]
	for _, keyword in pairs(keywords) do
		local existing = tChatStringIndex[keyword]
		if existing == nil then
			-- First time seeing this keyword
			tChatStringIndex[keyword] = idx
		else
			-- Keyword already mapped — merge replies into the existing entry
			for _, reply in pairs(tChatStringTable[idx][2]) do
				table.insert(tChatStringTable[existing][2], reply)
			end
			for _, reply in pairs(tChatStringTable[idx][3]) do
				table.insert(tChatStringTable[existing][3], reply)
			end
		end
	end
end

-- Look up the chat table index for a keyword (-1 if not found)
function Chat.GetChatStringTableIndex( sString )
	return tChatStringIndex[sString] or -1
end

-- Pick a random reply from the chat table (team or all-chat)
function Chat.GetChatTableString( nIndex, bAllChat )
	local replies = tChatStringTable[nIndex][bAllChat and 3 or 2]
	return replies[RandomInt( 1, #replies )]
end

-- Generate a reply to a chat message. Uses keyword matching, taunt detection,
-- or falls back to a random localized response.
function Chat.GetReplyString( sString, bAllChat )
	if not Chat.AllowTrashTalk(bAllChat) then return nil end

	local sReplyString = nil

	-- Try keyword-based reply (Chinese chat table)
	if Customize.Localization == 'zh' then
		local nIndex = Chat.GetChatStringTableIndex( sString )
		if nIndex ~= -1 then
			sReplyString = Chat.GetChatTableString( nIndex, bAllChat )
		else
			-- Try cheater detection (messages starting with '-')
			sReplyString = Chat.GetCheaterReplyString( sString )
			-- Try echo/mirror reply
			if sReplyString == nil then
				sReplyString = Chat.GetRepeatString( sString )
			end
		end
	end

	-- Fallback: random localized response (10% chance even if we found a reply)
	if sReplyString == nil or RandomInt( 1, 100 ) > 90 then
		local responses = Localization.Get('random_responses')
		sReplyString = responses[RandomInt( 1, #responses )]
	end

	return sReplyString
end

-- Check if trash talk is allowed based on user settings
function Chat.AllowTrashTalk(bAllChat)
	local level = Customize.Trash_Talk_Level
	return Customize.Allow_Trash_Talk
		and ((not bAllChat and (level == nil or level >= 2))
		or (bAllChat and (level == nil or level >= 1)))
end

-- Detect cheat commands (messages starting with '-')
function Chat.GetCheaterReplyString( sString )
	return string.byte( sString, 1 ) == string.byte( '-', 1 ) and "cheater" or nil
end

-- Mirror/echo a message back with word substitutions (Chinese only)
-- Transforms "你" -> removes, "吗?" -> affirmative, "我" -> "你", etc.
function Chat.GetRepeatString( sString )
	-- Ignore single-word messages that would produce empty replies
	local ignoreList = {"你们", "你", "我", "吗？", "吗", "吧", "？"}
	for _, word in ipairs(ignoreList) do
		if sString == word then return nil end
	end

	local sRawString = sString

	-- Special case: "我是你X" -> "我才是你X"
	if sString:find("我是你") then
		return sString:gsub("我是你", "我才是你")
	end

	-- Detect insults -> reply with a taunt
	local tauntWords = {"sb", "SB", "智障", "弱智", "脑残", "脑瘫", "猪", "傻", "菜", "笨", "蠢"}
	for _, word in ipairs(tauntWords) do
		if sString:find(word) then
			return Chat.GetReplyTauntString()
		end
	end

	-- Word substitutions to mirror the message
	local sMaReplyList = { "呀", "哦", "呀！", "哦！", "！", "" }
	local sMaReplyWord = sMaReplyList[RandomInt( 1, #sMaReplyList )]

	sString = string.gsub( sString, "你们", "" )
	sString = string.gsub( sString, "你", "" )
	sString = string.gsub( sString, "吗？", sMaReplyWord )
	sString = string.gsub( sString, "吗", sMaReplyWord )
	sString = string.gsub( sString, "吧", "啊" )
	sString = string.gsub( sString, "？", "！" )
	sString = string.gsub( sString, "?", "!" )
	sString = string.gsub( sString, "我", "你" )

	-- Only return if the message actually changed
	return sString ~= sRawString and sString or nil
end

-- Random taunt reply (Chinese)
local sReplyTauntList = {
	"你是在说你自己吗?",
	"你就只会说这个而已吗?",
	"我不允许你这么说你自己!",
	"别这么说你自己, 小伙汁.",
	"其实你不用这么来说你自己的.",
	"原来你自己就是酱紫的呀.",
	"自信点, 别这么说你自己.",
	"放松点, 就你这样没事的.",
	"反弹biubiubiu.",
	"给爷爬~~~",
}
function Chat.GetReplyTauntString()
	return sReplyTauntList[RandomInt( 1, #sReplyTauntList )]
end

-- Random "stop talking" reply (localized)
function Chat.GetStopReplyString()
	local msgs = Localization.Get('no_more_talking')
	return msgs[RandomInt( 1, #msgs )]
end


return Chat
