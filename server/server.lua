-- server.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- Utility function to get player name safely
local function GetPlayerName(source)
    local player = QBCore.Functions.GetPlayer(source)
    if player and player.charinfo then
        return player.charinfo.firstname .. " " .. player.charinfo.lastname
    else
        return "Unknown Player"
    end
end

RegisterServerEvent('qbcore:stunNotify')
AddEventHandler('qbcore:stunNotify', function(stunnedPlayerName)
    local _source = source
    local playerName = GetPlayerName(_source)
    
    if Config.Debug then
        -- Print debug information to the server console
        print(playerName .. " has stunned " .. stunnedPlayerName .. "!")
    end
end)

RegisterServerEvent('qbcore:debugZoneEntry')
AddEventHandler('qbcore:debugZoneEntry', function(playerName, action)
    if Config.Debug then
        -- Print debug information to the server console
        print(playerName .. " has " .. action .. " the airsoft zone.")
    end
end)
