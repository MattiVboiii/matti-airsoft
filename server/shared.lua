lib.versionCheck('MattiVboiii/matti-airsoft')

QBCore = nil
OxCore = nil

if Config.Framework == 'ox' then
    OxCore = exports.ox_core:GetCoreObject()
else
    QBCore = exports['qb-core']:GetCoreObject()
end

Data = {
    arenaStats = {},
    lobbies = {},
    playerLobbies = {},
    playerTeams = {},
    teamScores = {},
    recentAttackers = {},
    activeLobbyInArena = nil,
    nextLobbyId = 1
}

Utils = {}

function Utils.GetRecentAttacker(victimId)
    local entry = Data.recentAttackers[victimId]
    if not entry then
        return nil
    end

    local grace = Config.ScoreboardHitGracePeriod or 5000
    if (GetGameTimer() - entry.timestamp) > grace then
        Data.recentAttackers[victimId] = nil
        return nil
    end

    return entry.attackerId
end

function Utils.GetPlayer(playerId)
    if Config.Framework == 'ox' then
        if OxCore then
            return OxCore.GetPlayer(playerId)
        end
        return nil
    end

    return QBCore.Functions.GetPlayer(playerId)
end

function Utils.GetPlayerName(playerId)
    local player = Utils.GetPlayer(playerId)
    if player then
        if Config.Framework == 'ox' then
            return player.get('firstName') .. ' ' .. player.get('lastName')
        else
            if player.PlayerData and player.PlayerData.charinfo then
                return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            end
        end
    end
    return 'Player ' .. playerId
end

function Utils.HandlePlayerItem(playerId, itemName, amount, action)
    local player = Utils.GetPlayer(playerId)
    if not player then return false end

    if Config.InventorySystem == 'ox_inventory' then
        if action == 'add' then
            return exports.ox_inventory:AddItem(playerId, itemName, amount)
        elseif action == 'remove' then
            return exports.ox_inventory:RemoveItem(playerId, itemName, amount)
        end
    else
        if action == 'add' then
            return player.Functions.AddItem(itemName, amount)
        elseif action == 'remove' then
            return player.Functions.RemoveItem(itemName, amount)
        end
    end

    return false
end

function Utils.RemoveWeaponFromPed(playerId, weaponName)
    if not playerId or not weaponName then
        return false
    end
    TriggerClientEvent('matti-airsoft:client:removeWeaponFromPed', playerId, weaponName)
    return true
end
