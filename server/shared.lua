if not lib then
    error('❌ ox_lib is required but not installed! Make sure you have ox_lib in your resources folder.')
end

local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

local function compareVersions(v1, v2)
    local parts1 = {v1:match("(%d+)%.(%d+)%.(%d+)")}
    local parts2 = {v2:match("(%d+)%.(%d+)%.(%d+)")}
    
    if #parts1 ~= 3 or #parts2 ~= 3 then return false end
    
    for i = 1, 3 do
        if tonumber(parts1[i]) > tonumber(parts2[i]) then return true end
        if tonumber(parts1[i]) < tonumber(parts2[i]) then return false end
    end
    return false
end

lib.versionCheck('MattiVboiii/matti-airsoft')

-- Fetch remote version from GitHub
PerformHttpRequest('https://raw.githubusercontent.com/MattiVboiii/matti-airsoft/main/fxmanifest.lua', function(code, result, headers)
    if code == 200 then
        local remoteVersion = result:match("version%(%'([%d%.]+)%'%)")
        if remoteVersion and compareVersions(currentVersion, remoteVersion) then
            print('^3[matti-airsoft]^7 ⚠️ Warning: Local version ' .. currentVersion .. ' is newer than remote version ' .. remoteVersion)
        else
            print('^2[matti-airsoft]^7 Script loaded v' .. currentVersion .. ' - Version check passed')
        end
    else
        print('^2[matti-airsoft]^7 Script loaded v' .. currentVersion .. ' - Version check passed')
    end
end, 'GET')

QBCore = nil

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

function Utils.HandlePlayerItem(playerId, itemName, amount, action, options)
    local player = Utils.GetPlayer(playerId)
    if not player then return false end

    options = options or {}
    local metadata = options.metadata
    local slot = options.slot

    if Config.InventorySystem == 'ox_inventory' then
        if action == 'add' then
            return exports.ox_inventory:AddItem(playerId, itemName, amount, metadata, slot)
        elseif action == 'remove' then
            return exports.ox_inventory:RemoveItem(playerId, itemName, amount, metadata, slot)
        end
    else
        if action == 'add' then
            return player.Functions.AddItem(itemName, amount, slot, metadata)
        elseif action == 'remove' then
            return player.Functions.RemoveItem(itemName, amount, slot)
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
