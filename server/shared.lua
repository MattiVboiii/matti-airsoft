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

local function ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

if Config.Framework == 'qb' then
    if ResourceStarted('qb-core') then
        QBCore = exports['qb-core']:GetCoreObject()
    else
        print('^1[matti-airsoft]^7 ERROR: qb-core is not started')
    end
elseif Config.Framework == 'qbx' then
    if not ResourceStarted('qbx_core') then
        print('^1[matti-airsoft]^7 ERROR: qbx_core is not started')
    end
    if ResourceStarted('qb-core') then
        QBCore = exports['qb-core']:GetCoreObject()
    end
elseif Config.Framework == 'ox' then
    if not ResourceStarted('ox_core') then
        print('^1[matti-airsoft]^7 ERROR: ox_core is not started')
    end
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
    inventoryStashed = {},
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

function Utils.ApplySpawnProtection(playerId)
    local seconds = Config.SpawnProtectionSeconds or 0
    if not playerId or seconds <= 0 then
        return
    end

    Data.spawnProtectionUntil = Data.spawnProtectionUntil or {}
    Data.spawnProtectionUntil[playerId] = GetGameTimer() + (seconds * 1000)
    TriggerClientEvent('matti-airsoft:spawnProtection', playerId, seconds)
end

function Utils.IsSpawnProtected(playerId)
    if not playerId or not Data.spawnProtectionUntil then
        return false
    end

    local expiresAt = Data.spawnProtectionUntil[playerId]
    return expiresAt and GetGameTimer() < expiresAt or false
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

function Utils.Throttle(playerId, key, cooldownMs)
    cooldownMs = cooldownMs or 500
    Data.eventRateLimits[playerId] = Data.eventRateLimits[playerId] or {}

    local now = GetGameTimer()
    local lastTriggered = Data.eventRateLimits[playerId][key] or 0
    if (now - lastTriggered) < cooldownMs then
        return false
    end

    Data.eventRateLimits[playerId][key] = now
    return true
end

function Utils.CheckRateLimit(playerId, eventName, cooldownMs)
    cooldownMs = cooldownMs or EVENT_RATE_LIMITS[eventName] or 500
    if not Utils.Throttle(playerId, eventName, cooldownMs) then
        Utils.LogSuspiciousActivity(playerId, eventName, 'rate_limited')
        return false
    end

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
    if not playerId then
        return nil
    end

    if Config.Framework == 'ox' then
        if Ox and Ox.GetPlayer then
            return Ox.GetPlayer(playerId)
        end

        if ResourceStarted('ox_core') then
            local ok, player = pcall(function()
                return exports.ox_core:GetPlayer(playerId)
            end)
            if ok and player then
                return player
            end
        end

        return nil
    end

    if Config.Framework == 'qbx' and ResourceStarted('qbx_core') then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(playerId)
        end)
        if ok and player then
            return player
        end
    end

    if QBCore and QBCore.Functions then
        return QBCore.Functions.GetPlayer(playerId)
    end

    return nil
end

function Utils.GetPlayerName(playerId)
    local player = Utils.GetPlayer(playerId)
    if player then
        if Config.Framework == 'ox' then
            local firstName = (player.get and player.get('firstName')) or player.firstName
            local lastName = (player.get and player.get('lastName')) or player.lastName
            if firstName or lastName then
                return (firstName or '') .. ' ' .. (lastName or '')
            end
        elseif player.PlayerData and player.PlayerData.charinfo then
            return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        end
    end
    return GetPlayerName(playerId) or ('Player ' .. tostring(playerId))
end

function Utils.RemoveMoney(playerId, amount, reason)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return true
    end

    if Config.Framework == 'ox' then
        if Config.InventorySystem == 'ox_inventory' and ResourceStarted('ox_inventory') then
            local cash = tonumber(exports.ox_inventory:GetItemCount(playerId, 'money')) or 0
            if cash >= amount then
                return exports.ox_inventory:RemoveItem(playerId, 'money', amount) and true or false
            end
        end

        local player = Utils.GetPlayer(playerId)
        local account = player and player.getAccount and player.getAccount() or nil
        if not account then
            return false
        end

        local balance = tonumber(account.get and account.get('balance')) or 0
        if balance < amount then
            return false
        end

        local result = account.removeBalance({
            amount = amount,
            message = reason or 'Airsoft Loadout',
        })
        return result and result.success == true
    end

    local player = Utils.GetPlayer(playerId)
    if not player or not player.Functions or not player.Functions.RemoveMoney then
        return false
    end

    return player.Functions.RemoveMoney('cash', amount, reason or 'airsoft') and true or false
end

function Utils.AddMoney(playerId, amount, reason)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return true
    end

    if Config.Framework == 'ox' then
        if Config.InventorySystem == 'ox_inventory' and ResourceStarted('ox_inventory') then
            return exports.ox_inventory:AddItem(playerId, 'money', amount) and true or false
        end

        local player = Utils.GetPlayer(playerId)
        local account = player and player.getAccount and player.getAccount() or nil
        if not account or not account.addBalance then
            return false
        end

        local result = account.addBalance({
            amount = amount,
            message = reason or 'Airsoft Loadout Refund',
        })
        return result and result.success == true
    end

    local player = Utils.GetPlayer(playerId)
    if not player or not player.Functions or not player.Functions.AddMoney then
        return false
    end

    return player.Functions.AddMoney('cash', amount, reason or 'airsoft') and true or false
end

function Utils.RevivePlayer(playerId)
    if not playerId then
        return
    end

    if Config.Framework == 'ox' then
        Player(playerId).state:set('isDead', false, true)
        TriggerClientEvent('ox:playerRevived', playerId)
    elseif Config.Framework == 'qbx' then
        if ResourceStarted('qbx_medical') then
            exports.qbx_medical:Revive(playerId)
        else
            TriggerClientEvent('hospital:client:Revive', playerId)
        end
    else
        TriggerClientEvent('hospital:client:Revive', playerId)
    end

    TriggerClientEvent('matti-airsoft:client:revive', playerId)
end

function Utils.HandlePlayerItem(playerId, itemName, amount, action, options)
    options = options or {}
    local metadata = options.metadata
    local slot = options.slot
    local ok, result

    if Config.InventorySystem == 'ox_inventory' then
        if action == 'add' then
            ok, result = pcall(function()
                return exports.ox_inventory:AddItem(playerId, itemName, amount, metadata, slot)
            end)
        elseif action == 'remove' then
            ok, result = pcall(function()
                return exports.ox_inventory:RemoveItem(playerId, itemName, amount, metadata, slot)
            end)
        else
            return false
        end

        if not ok then
            if Config.Debug then
                print('[matti-airsoft] Inventory ' .. action .. ' failed for ' .. tostring(itemName) .. ': ' .. tostring(result))
            end
            return false
        end

        return result and true or false
    end

    local player = Utils.GetPlayer(playerId)
    if not player then
        return false
    end

    if action == 'add' then
        return player.Functions.AddItem(itemName, amount, slot, metadata)
    elseif action == 'remove' then
        return player.Functions.RemoveItem(itemName, amount, slot)
    end

    return false
end

function Utils.GetArenaWhitelistSet()
    local whitelist = {}
    for _, itemName in ipairs(Config.ArenaItemWhitelist or {}) do
        local normalized = SharedUtils.NormalizeItemName(itemName)
        if normalized then
            whitelist[normalized] = true
        end
    end
    return whitelist
end

function Utils.AppendSavedInventoryItem(playerId, itemName, amount, metadata, slot)
    if not playerId or type(itemName) ~= 'string' or (tonumber(amount) or 0) <= 0 then
        return
    end

    Data.savedInventories = Data.savedInventories or {}
    Data.savedInventories[playerId] = Data.savedInventories[playerId] or {}
    table.insert(Data.savedInventories[playerId], {
        name = itemName,
        amount = tonumber(amount),
        metadata = metadata,
        slot = slot,
    })
end

local function CollectPlayerInventoryItems(playerId)
    local collected = {}

    if Config.InventorySystem == 'ox_inventory' then
        local items = exports.ox_inventory:GetInventoryItems(playerId)
        if not items then
            local inventory = exports.ox_inventory:GetInventory(playerId)
            items = inventory and inventory.items or {}
        end

        for _, item in pairs(items) do
            if item and item.name then
                collected[#collected + 1] = {
                    name = item.name,
                    amount = item.count or item.amount or 0,
                    metadata = item.metadata,
                    slot = item.slot,
                }
            end
        end
        return collected
    end

    local player = Utils.GetPlayer(playerId)
    local items = player and player.PlayerData and player.PlayerData.items or {}
    for _, item in pairs(items) do
        if item and item.name then
            collected[#collected + 1] = {
                name = item.name,
                amount = item.amount or item.count or 0,
                metadata = item.info or item.metadata,
                slot = item.slot,
            }
        end
    end

    return collected
end

local function RemoveInventoryItem(playerId, item)
    local removed = Utils.HandlePlayerItem(playerId, item.name, item.amount, 'remove', {
        metadata = item.metadata,
        slot = item.slot,
    })
    if removed then
        return true
    end

    return Utils.HandlePlayerItem(playerId, item.name, item.amount, 'remove', {
        metadata = item.metadata,
    }) == true
end

function Utils.StashAndClearInventory(playerId)
    if not playerId then
        return false
    end

    local whitelist = Utils.GetArenaWhitelistSet()
    local items = CollectPlayerInventoryItems(playerId)

    for _, item in ipairs(items) do
        local normalized = SharedUtils.NormalizeItemName(item.name)
        local amount = tonumber(item.amount) or 0
        if normalized and amount > 0 and not whitelist[normalized] then
            if RemoveInventoryItem(playerId, item) then
                Utils.AppendSavedInventoryItem(playerId, item.name, amount, item.metadata, item.slot)
            end
        end
    end

    Data.inventoryStashed = Data.inventoryStashed or {}
    Data.inventoryStashed[playerId] = true
    return true
end

function Utils.MarkLoadoutReady(playerId, ready)
    Data.loadoutReadyUntil = Data.loadoutReadyUntil or {}
    if ready then
        Data.loadoutReadyUntil[playerId] = GetGameTimer() + 4000
    else
        Data.loadoutReadyUntil[playerId] = nil
    end
end

function Utils.IsLoadoutGrantGrace(playerId)
    local expiresAt = Data.loadoutReadyUntil and Data.loadoutReadyUntil[playerId]
    return expiresAt and GetGameTimer() < expiresAt or false
end

function Utils.StashDisallowedArenaItems(playerId, allowedItems)
    if not playerId or Utils.IsLoadoutGrantGrace(playerId) then
        return
    end

    local whitelist = Utils.GetArenaWhitelistSet()
    local items = CollectPlayerInventoryItems(playerId)

    for _, item in ipairs(items) do
        local normalized = SharedUtils.NormalizeItemName(item.name)
        local amount = tonumber(item.amount) or 0
        if normalized and amount > 0 and not whitelist[normalized] and not (allowedItems and allowedItems[normalized]) then
            if RemoveInventoryItem(playerId, item) then
                Utils.AppendSavedInventoryItem(playerId, item.name, amount, item.metadata, item.slot)
            end
        end
    end
end

function Utils.GivePlayerLoadout(playerId, loadout)
    if not playerId or not loadout then
        return false
    end

    local granted = 0

    for _, weapon in ipairs(loadout.weapons or {}) do
        if weapon.name then
            if Utils.HandlePlayerItem(playerId, weapon.name, 1, 'add') then
                granted = granted + 1
            else
                print(('[matti-airsoft] Failed to give weapon "%s" to player %s (is it registered in ox_inventory/qb-inventory?)'):format(
                    tostring(weapon.name),
                    tostring(playerId)
                ))
            end
        end
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        local amount = math.floor(tonumber(ammo.amount) or 0)
        if ammo.name and amount > 0 then
            if Utils.HandlePlayerItem(playerId, ammo.name, amount, 'add') then
                granted = granted + 1
            else
                print(('[matti-airsoft] Failed to give ammo "%s" x%s to player %s (is it registered in ox_inventory/qb-inventory?)'):format(
                    tostring(ammo.name),
                    tostring(amount),
                    tostring(playerId)
                ))
            end
        end
    end

    return granted > 0
end

function Utils.StripPlayerLoadout(playerId, loadout)
    if not playerId or not loadout then
        return false
    end

    for _, weapon in ipairs(loadout.weapons or {}) do
        if weapon.name then
            local removed = Utils.HandlePlayerItem(playerId, weapon.name, 1, 'remove')
            if removed then
                Utils.RemoveWeaponFromPed(playerId, weapon.name)
            end
        end
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        if ammo.name then
            local currentAmount = Utils.GetPlayerItemCount(playerId, ammo.name)
            if currentAmount > 0 then
                Utils.HandlePlayerItem(playerId, ammo.name, currentAmount, 'remove')
            end
        end
    end

    return true
end

function Utils.GetConfiguredLoadoutByName(loadoutName)
    if type(loadoutName) ~= 'string' or loadoutName == '' then
        return nil
    end

    for _, cfg in ipairs(Config.Loadouts or {}) do
        if cfg.name == loadoutName then
            return cfg
        end
    end

    return nil
end

function Utils.StripArenaLoadout(playerId)
    if not playerId then
        return false
    end

    local loadout
    local lobbyId = Data.playerLobbies[playerId]
    local lobby = lobbyId and Data.lobbies[lobbyId]
    if lobby then
        loadout = lobby.selectedLoadout
    end

    if not loadout then
        local grantState = Data.loadoutGrantState and Data.loadoutGrantState[playerId]
        loadout = Utils.GetConfiguredLoadoutByName(grantState and grantState.loadoutName)
    end

    if not loadout then
        return false
    end

    return Utils.StripPlayerLoadout(playerId, loadout)
end

function Utils.RestorePlayerInventory(playerId)
    if not playerId then
        return false
    end

    if Data.inventoryStashed then
        Data.inventoryStashed[playerId] = nil
    end
    Utils.MarkLoadoutReady(playerId, false)

    local savedInventory = Data.savedInventories and Data.savedInventories[playerId]
    if not savedInventory then
        return true
    end

    Data.savedInventories[playerId] = nil

    for _, item in ipairs(savedInventory) do
        Utils.HandlePlayerItem(playerId, item.name, item.amount, 'add', {
            metadata = item.metadata,
        })
    end

    return true
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
