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

RegisterServerEvent('matti-airsoft:stunNotify')
AddEventHandler('matti-airsoft:stunNotify', function(stunnedPlayerName)
    local _source = source
    local playerName = GetPlayerName(_source)
    
    if Config.Debug then
        -- Print debug information to the server console
        print(playerName .. " has stunned " .. stunnedPlayerName .. "!")
    end
end)

RegisterServerEvent('matti-airsoft:debugZoneEntry')
AddEventHandler('matti-airsoft:debugZoneEntry', function(playerName, action)
    if Config.Debug then
        -- Print debug information to the server console
        print(playerName .. " has " .. action .. " the airsoft zone.")
    end
end)

-- Handle giving weapons to players
RegisterServerEvent('matti-airsoft:giveWeapon')
AddEventHandler('matti-airsoft:giveWeapon', function(weaponName)
    local _source = source
    local player = QBCore.Functions.GetPlayer(_source)
    if player then
        player.Functions.AddItem(weaponName, 1)
        TriggerClientEvent('inventory:client:ItemBox', _source, QBCore.Shared.Items[weaponName], 'add')
    end
end)

-- Handle giving items to players
RegisterServerEvent('matti-airsoft:giveItem')
AddEventHandler('matti-airsoft:giveItem', function(itemName, amount)
    local _source = source
    local player = QBCore.Functions.GetPlayer(_source)
    if player then
        player.Functions.AddItem(itemName, amount)
        TriggerClientEvent('inventory:client:ItemBox', _source, QBCore.Shared.Items[itemName], 'add')
    end
end)

-- Handle removing weapons from players
RegisterServerEvent('matti-airsoft:removeWeapon')
AddEventHandler('matti-airsoft:removeWeapon', function(weaponName)
    local _source = source
    local player = QBCore.Functions.GetPlayer(_source)
    if player then
        player.Functions.RemoveItem(weaponName, 1)
        TriggerClientEvent('inventory:client:ItemBox', _source, QBCore.Shared.Items[weaponName], 'remove')
    end
end)

-- Handle removing items from players
RegisterServerEvent('matti-airsoft:removeItem')
AddEventHandler('matti-airsoft:removeItem', function(itemName, amount)
    local _source = source
    local player = QBCore.Functions.GetPlayer(_source)
    if player then
        player.Functions.RemoveItem(itemName, amount)
        TriggerClientEvent('inventory:client:ItemBox', _source, QBCore.Shared.Items[itemName], 'remove')
    end
end)
