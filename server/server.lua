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

QBCore.Functions.CreateCallback('matti-airsoft:canAffordLoadout', function(source, cb, price)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        if player.Functions.RemoveMoney('bank', price, 'airsoft') then
            cb(true)
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

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

QBCore.Commands.Add('exitarena', Lang:t('command.description_exitarena'), {{name = 'id', help = Lang:t('command.help_exitarena')}}, false, function(source, args)
    local playerId = tonumber(args[1]) or source
    if playerId then
        local targetPlayer = QBCore.Functions.GetPlayer(playerId)
        if targetPlayer then
            TriggerClientEvent('matti-airsoft:checkIfInArena', playerId, source)
        else
            TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
        end
    else
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
    end
end, 'admin')

RegisterNetEvent('matti-airsoft:reportArenaStatus')
AddEventHandler('matti-airsoft:reportArenaStatus', function(adminId, isInArena)
    if isInArena then
        TriggerClientEvent('matti-airsoft:forceExitArena', source)
        TriggerClientEvent('matti-airsoft:sendNotification', adminId, Lang:t('command.player_removed'), 'success')
    else
        TriggerClientEvent('matti-airsoft:sendNotification', adminId, Lang:t('command.player_not_in_arena'), 'error')
    end
end)

-- Version checker
PerformHttpRequest('https://raw.githubusercontent.com/MattiVboiii/matti-airsoft/main/VERSION', function(Error, OnlineVersion, Header)
    OfflineVersion = LoadResourceFile('matti-airsoft', 'VERSION')
    if Error ~= 200 then
        error('^3 [ERROR]: There was an error, it is: HTTP' .. Error)
        return 0
    else
    if OnlineVersion == OfflineVersion then 
        print('^3 [LATEST]: ^2 You are running the latest version of this script.')
    end
    if OnlineVersion > OfflineVersion then
        print('^3 [UPDATE]: ^1 There is a new version of this script available!')
        print('^3 [UPDATE]: ^7 Check out on Github: https://github.com/MattiVboiii/matti-airsoft')
    end
    if OnlineVersion < OfflineVersion then 
        print("^3 [FUTURE??]: ^1 Are you living in the future? Because this version of the script has not been released yet...")
    end
end
end)