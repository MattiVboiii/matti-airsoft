if not lib then
    error('❌ ox_lib is required but not installed! Make sure you have ox_lib in your resources folder.')
end

local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version') or '0.0.0'

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

local function PrintStartupVersion(remoteVersion)
    if remoteVersion and compareVersions(currentVersion, remoteVersion) then
        print('^3[matti-airsoft]^7 Warning: Local version ' .. currentVersion .. ' is newer than remote version ' .. remoteVersion)
        return
    end

    print('^2[matti-airsoft]^7 Script loaded v' .. currentVersion .. ' - Version check passed')
end

-- Fetch remote version from GitHub
PerformHttpRequest('https://raw.githubusercontent.com/MattiVboiii/matti-airsoft/main/fxmanifest.lua', function(code, result, headers)
    if code == 200 then
        local remoteVersion = result:match("version%(%'([%d%.]+)%'%)")
        PrintStartupVersion(remoteVersion)
    else
        PrintStartupVersion(nil)
    end
end, 'GET')

QBCore = nil

if Config.Framework == 'ox' then
    OxCore = exports.ox_core:GetCoreObject()
elseif Config.Framework == 'qb' or Config.Framework == 'qbx' then
    QBCore = exports['qb-core']:GetCoreObject()
else
    print('^1[matti-airsoft]^7 ERROR: Unsupported framework: ' .. tostring(Config.Framework))
end

Data = {
    arenaStats = {},
    arenaPresence = {},
    arenaStatLobbies = {},
    lobbies = {},
    playerLobbies = {},
    playerTeams = {},
    teamScores = {},
    recentAttackers = {},
    activeLobbyInArena = nil,
    nextLobbyId = 1,
    savedInventories = {},
    loadoutGrantState = {},
    eventRateLimits = {},
    suspiciousActivity = {},
}

Utils = {}

local SCOREBOARD_HIT_GRACE_MS = 5000
local KILLER_FALLBACK_DISTANCE = 60.0
local MAX_ITEM_EVENT_AMOUNT = 2000000000
local ARENA_RECONCILE_INTERVAL_MS = 5000

local EVENT_RATE_LIMITS = {
    playerEnteredArena = 500,
    playerLeftArena = 500,
    playerWasHit = 2000,
    registerRecentAttacker = 200,
    removeItem = 100,
    giveItem = 100,
    giveWeapon = 100,
}

function Utils.GetScoreboardHitGraceMs()
    return SCOREBOARD_HIT_GRACE_MS
end

function Utils.GetKillerFallbackDistance()
    return KILLER_FALLBACK_DISTANCE
end

function Utils.GetMaxItemEventAmount()
    return MAX_ITEM_EVENT_AMOUNT
end

function Utils.GetArenaReconcileIntervalMs()
    return ARENA_RECONCILE_INTERVAL_MS
end

function Utils.GetPlayerCoords(playerId)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

function Utils.IsPlayerInArena(playerId)
    local coords = Utils.GetPlayerCoords(playerId)
    if not coords then
        return false
    end

    return SharedUtils.IsCoordsInArena(coords)
end

function Utils.CheckRateLimit(playerId, eventName, cooldownMs)
    cooldownMs = cooldownMs or EVENT_RATE_LIMITS[eventName] or 500
    Data.eventRateLimits[playerId] = Data.eventRateLimits[playerId] or {}

    local now = GetGameTimer()
    local lastTriggered = Data.eventRateLimits[playerId][eventName] or 0
    if (now - lastTriggered) < cooldownMs then
        Utils.LogSuspiciousActivity(playerId, eventName, 'rate_limited')
        return false
    end

    Data.eventRateLimits[playerId][eventName] = now
    return true
end

function Utils.LogSuspiciousActivity(playerId, eventName, reason)
    Data.suspiciousActivity[playerId] = Data.suspiciousActivity[playerId] or {}
    table.insert(Data.suspiciousActivity[playerId], {
        event = eventName,
        reason = reason,
        timestamp = os.time(),
    })

    if Config.Debug then
        print('[matti-airsoft] Suspicious activity from ' .. tostring(playerId) .. ' on ' .. eventName .. ': ' .. reason)
    end
end

function Utils.GetClosestArenaPlayer(victimId, maxDistance)
    local victimCoords = Utils.GetPlayerCoords(victimId)
    if not victimCoords then
        return nil
    end

    local closestDistance = maxDistance or Utils.GetKillerFallbackDistance()
    local closestPlayerId = nil

    for playerId, _ in pairs(Data.arenaStats) do
        if playerId ~= victimId then
            local targetCoords = Utils.GetPlayerCoords(playerId)
            if targetCoords then
                local distance = #(victimCoords - targetCoords)
                if distance <= closestDistance then
                    closestDistance = distance
                    closestPlayerId = playerId
                end
            end
        end
    end

    return closestPlayerId
end

function Utils.GetRecentAttacker(victimId)
    local entry = Data.recentAttackers[victimId]
    if not entry then
        return nil
    end

    local grace = Utils.GetScoreboardHitGraceMs()
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

function Utils.GetPlayerItemCount(playerId, itemName)
    if not playerId or type(itemName) ~= 'string' or itemName == '' then
        return 0
    end

    if Config.InventorySystem == 'ox_inventory' then
        local count = exports.ox_inventory:GetItemCount(playerId, itemName)
        return tonumber(count) or 0
    end

    local player = Utils.GetPlayer(playerId)
    if not player or not player.PlayerData or type(player.PlayerData.items) ~= 'table' then
        return 0
    end

    local total = 0
    for _, item in pairs(player.PlayerData.items) do
        if item and item.name == itemName and tonumber(item.amount) and tonumber(item.amount) > 0 then
            total = total + tonumber(item.amount)
        end
    end

    return total
end

function Utils.RemoveWeaponFromPed(playerId, weaponName)
    if not playerId or not weaponName then
        return false
    end
    TriggerClientEvent('matti-airsoft:client:removeWeaponFromPed', playerId, weaponName)
    return true
end
