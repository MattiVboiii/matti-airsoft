-- server.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Utility function to get player name
local function GetPlayerNameById(playerId)
    local player = QBCore.Functions.GetPlayer(playerId)
    if player and player.PlayerData.charinfo then
        return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    else
        return 'Unknown Player'
    end
end

-- Utility function to handle item addition or removal
local function HandlePlayerItem(playerId, itemName, amount, action)
    local player = QBCore.Functions.GetPlayer(playerId)
    if player then
        if action == 'add' then
            player.Functions.AddItem(itemName, amount)
        elseif action == 'remove' then
            player.Functions.RemoveItem(itemName, amount)
        end
        TriggerClientEvent('inventory:client:ItemBox', playerId, QBCore.Shared.Items[itemName], action)
    end
end

-- Utility function to handle weapon removal from player ped
local function RemoveWeaponFromPlayerPed(playerId, weaponName)
    local playerPed = GetPlayerPed(playerId)
    RemoveWeaponFromPed(playerPed, GetHashKey(weaponName))
end

-- Debugging entry point
RegisterServerEvent('matti-airsoft:debugZoneEntry')
AddEventHandler('matti-airsoft:debugZoneEntry', function(playerName, action)
    if Config.Debug then
        print(playerName .. ' has ' .. action .. ' the airsoft zone.')
    end
end)

-- Events for handling items and weapons
RegisterServerEvent('matti-airsoft:giveWeapon')
AddEventHandler('matti-airsoft:giveWeapon', function(weaponName)
    HandlePlayerItem(source, weaponName, 1, 'add')
end)

RegisterServerEvent('matti-airsoft:giveItem')
AddEventHandler('matti-airsoft:giveItem', function(itemName, amount)
    HandlePlayerItem(source, itemName, amount, 'add')
end)

RegisterServerEvent('matti-airsoft:removeWeapon')
AddEventHandler('matti-airsoft:removeWeapon', function(weaponName)
    HandlePlayerItem(source, weaponName, 1, 'remove')
    RemoveWeaponFromPlayerPed(source, weaponName)
end)

RegisterServerEvent('matti-airsoft:removeItem')
AddEventHandler('matti-airsoft:removeItem', function(itemName, amount)
    HandlePlayerItem(source, itemName, amount, 'remove')
end)
