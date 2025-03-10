local api = require("api")

local cant_read_addon = {
	name = "Can't Read",
	author = "Michaelqt",
	version = "1.0",
	desc = "Automatic chat translation to language of choice."
}

local cantReadWindow

local clockTimer = 0
local clockResetTime = 100

local function writeChatToTranslatingFile(channel, unit, isHostile, name, message, speakerInChatBound, specifyName, factionName, trialPosition)
    if name ~= nil then 
        -- api.Log:Info("||||"..name.."||||"..message.."||||"..tostring(channel).."||||")
        api.File:Write("cant_read/to_be_translated.lua", {chatMsg=tostring"||||"..(channel).."||||"..name.."||||"..message.."||||"})
    end 
end 
local function split(s, sep)
    local fields = {}
    
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    
    return fields
end
local function sendDecoratedChatByChannel(message, sender, channel)
    -- TODO: Switch to using X2Locale:LocalizeUiText once available
    local prefix = "[Cant Read] -> "
    if tostring(channel) == "-3" then 
        -- Incoming Whispers CMF_WHISPER
        local formatted = prefix .. sender .. " to you: " .. message
        X2Chat:DispatchChatMessage(3, formatted)
        return 
    elseif tostring(channel) == "0" then
        -- Local CMF_SAY
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(56, "|cFFfbfbfb" .. formatted)
        return
    elseif tostring(channel) == "1" then
        -- Shout CMF_ZONE
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(56, "|cFFee6890" .. formatted)
        return
    elseif tostring(channel) == "2" then
        -- Trade CMF_TRADE
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(56, "|cFF35edc8" .. formatted)
        return
    elseif tostring(channel) == "3" then
        -- Looking for Group CMF_FIND_PARTY
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(56, formatted)
        return
    elseif tostring(channel) == "4" then
        -- Party CMF_PARTY
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(4, formatted)
        return
    elseif tostring(channel) == "5" then
        -- Raid CMF_RAID
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(5, formatted)
        return
    elseif tostring(channel) == "6" then
        -- Nation CMF_RACE 
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(56, "|cFF8eb131" .. formatted)
        return
    elseif tostring(channel) == "7" then
        -- Guild CMF_EXPEDITION
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(6, formatted)
        return
    elseif tostring(channel) == "9" then
        -- Family CMF_FAMILY
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(57, formatted)
        return
    elseif tostring(channel) == "10" then
        -- Command CMF_RAID_COMMAND
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(58, formatted)
        return
    elseif tostring(channel) == "11" then
        -- Trial CMF_TRIAL
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(59, formatted)
        return
    elseif tostring(channel) == "14" then
        -- Faction CMF_FACTION
        local formatted = prefix .. "[" .. sender .. "]: " .. message
        X2Chat:DispatchChatMessage(56, "|cFFfcfc01" .. formatted)
        return
    else
        return nil
    end
end
local function readLatestTranslatedMessage()
    local message = api.File:Read("cant_read/translated_messages")
    if message.chatMsg ~= nil then 
        -- api.Log:Info(tostring(message.chatMsg))
        local messageInfo = split(message.chatMsg, ";;;")
        -- api.Log:Info("Channel: " .. tostring(messageInfo[1]))
        -- api.Log:Info("Name: " .. tostring(messageInfo[2]))
        -- api.Log:Info("Message: " .. tostring(messageInfo[3]))
        local channelNumber = tonumber(messageInfo[1])
        -- api.Log:Info(message)
        sendDecoratedChatByChannel(messageInfo[3], messageInfo[2], messageInfo[1])
        -- X2Chat:DispatchChatMessage(channelNumber, messageInfo[3])
        api.File:Write("cant_read/translated_messages", {})
    end 
end 
local function OnUpdate(dt)
    if clockTimer + dt > clockResetTime then
        readLatestTranslatedMessage()
		clockTimer = 0	
    end 
    clockTimer = clockTimer + dt
end 

local function OnLoad()
	local settings = api.GetSettings("cant_read")

	cantReadWindow = api.Interface:CreateEmptyWindow("cantReadWindow", "UIParent")

	function cantReadWindow:OnEvent(event, ...)
		if event == "CHAT_MESSAGE" then
            if arg ~= nil then 
                writeChatToTranslatingFile(unpack(arg))
            end 
        end 
	end
	cantReadWindow:SetHandler("OnEvent", cantReadWindow.OnEvent)
	cantReadWindow:RegisterEvent("CHAT_MESSAGE")

    api.On("UPDATE", OnUpdate)
	api.SaveSettings()
end

local function OnUnload()
	api.On("UPDATE", function() return end)
	cantReadWindow:ReleaseHandler("OnEvent")
end

cant_read_addon.OnLoad = OnLoad
cant_read_addon.OnUnload = OnUnload

return cant_read_addon
