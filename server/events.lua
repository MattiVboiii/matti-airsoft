local MAX_ITEM_EVENT_AMOUNT = Utils.GetMaxItemEventAmount()

local function ValidateItemRequest(itemName, amount)
    if type(itemName) ~= 'string' or itemName == '' then
        return false, nil, nil
    end

    local isValidAmount, normalizedAmount = SharedUtils.ValidatePositiveWholeNumber(amount, MAX_ITEM_EVENT_AMOUNT)
    if not isValidAmount then
        return false, nil, nil
    end

    local normalizedItemName = SharedUtils.NormalizeItemName(itemName)
    if not normalizedItemName then
        return false, nil, nil
    end

    return true, normalizedItemName, normalizedAmount
end

local function GetPlayerArenaLobby(playerId)
    local lobbyId = Data.playerLobbies[playerId]
    if not lobbyId or not Data.lobbies[lobbyId] then
        return nil
    end

    if Data.activeLobbyInArena ~= lobbyId then
        return nil
    end

    local lobby = Data.lobbies[lobbyId]
    if not lobby.players or not lobby.players[playerId] then
        return nil
    end

    return lobby
end

local function BuildLoadoutGrants(loadout)
    local grants = {
        weapons = {},
        ammo = {}
    }

    if not loadout then
        return grants
    end

    for _, weapon in ipairs(loadout.weapons or {}) do
        local normalizedName = SharedUtils.NormalizeItemName(weapon.name)
        if normalizedName then
            grants.weapons[normalizedName] = (grants.weapons[normalizedName] or 0) + 1
        end
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        local normalizedName = SharedUtils.NormalizeItemName(ammo.name)
        local ammoAmount = tonumber(ammo.amount) or 0
        if normalizedName and ammoAmount > 0 then
            grants.ammo[normalizedName] = (grants.ammo[normalizedName] or 0) + ammoAmount
        end
    end

    return grants
end

local function RefillMissingLoadoutAmmo(playerId, loadout)
    if not loadout then
        return
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        local itemName = ammo.name
        local loadoutAmount = math.floor(tonumber(ammo.amount) or 0)

        if type(itemName) == 'string' and itemName ~= '' and loadoutAmount > 0 then
            local currentAmount = Utils.GetPlayerItemCount(playerId, itemName)
            local missingAmount = loadoutAmount - currentAmount

            if missingAmount > 0 then
                Utils.HandlePlayerItem(playerId, itemName, missingAmount, 'add')
            end
        end
    end
end

local function GetAllowedArenaItemSet(loadout)
    local allowed = Utils.GetArenaWhitelistSet()

    local function addName(itemName)
        local normalized = SharedUtils.NormalizeItemName(itemName)
        if normalized then
            allowed[normalized] = true
        end
    end

    if loadout then
        for _, weapon in ipairs(loadout.weapons or {}) do
            addName(weapon.name)
        end
        for _, ammo in ipairs(loadout.ammo or {}) do
            addName(ammo.name)
        end
        return allowed
    end

    for _, weaponName in ipairs(SharedUtils.GetLoadoutWeaponNames()) do
        addName(weaponName)
    end

    for _, cfg in ipairs(Config.Loadouts or {}) do
        for _, ammo in ipairs(cfg.ammo or {}) do
            addName(ammo.name)
        end
    end

    return allowed
end

local function IsLoadoutItem(loadout, itemName)
    local normalizedName = SharedUtils.NormalizeItemName(itemName)
    if not loadout or not normalizedName then
        return false
    end

    for _, weapon in ipairs(loadout.weapons or {}) do
        if SharedUtils.NormalizeItemName(weapon.name) == normalizedName then
            return true
        end
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        if SharedUtils.NormalizeItemName(ammo.name) == normalizedName then
            return true
        end
    end

    return false
end

local function EnsureSecurityState()
    Data.loadoutGrantState = Data.loadoutGrantState or {}
    Data.savedInventories = Data.savedInventories or {}
end

local function EnsureLoadoutGrantState(playerId, lobby)
    EnsureSecurityState()

    local lobbyId = lobby.id
    local state = Data.loadoutGrantState[playerId]
    if state and state.lobbyId == lobbyId and state.loadoutName == (lobby.selectedLoadout and lobby.selectedLoadout.name or nil) then
        return state
    end

    state = {
        lobbyId = lobbyId,
        loadoutName = lobby.selectedLoadout and lobby.selectedLoadout.name or nil,
        grants = BuildLoadoutGrants(lobby.selectedLoadout)
    }

    Data.loadoutGrantState[playerId] = state
    return state
end

local function ConsumeLoadoutGrant(playerId, lobby, grantType, itemName, amount)
    local state = EnsureLoadoutGrantState(playerId, lobby)
    local bucket = state.grants[grantType]
    if not bucket then
        return false
    end

    local remaining = bucket[itemName] or 0
    if remaining < amount then
        return false
    end

    bucket[itemName] = remaining - amount
    state.issuedAny = true
    return true
end

local function ResetPlayerSecurityState(playerId)
    if Data.loadoutGrantState then
        Data.loadoutGrantState[playerId] = nil
    end
end

RegisterNetEvent('matti-airsoft:createLobby', function(lobbyName)
    if lobbyName ~= nil and (type(lobbyName) ~= 'string' or #lobbyName > 50) then
        return
    end
    local lobby = Lobby.Create(source, lobbyName)
    if lobby then
        TriggerClientEvent('matti-airsoft:lobbyCreated', source, lobby)
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.lobby_created'), 'success')
    end
end)

RegisterNetEvent('matti-airsoft:joinLobby', function(lobbyId)
    local normalizedLobbyId = tonumber(lobbyId)
    if not normalizedLobbyId then
        return
    end
    if Lobby.Join(source, normalizedLobbyId) then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.lobby_joined'), 'success')
    end
end)

RegisterNetEvent('matti-airsoft:leaveLobby', function()
    Utils.StripArenaLoadout(source)
    MatchState.ClearPlayer(source)
    Lobby.Leave(source)
    Utils.RestorePlayerInventory(source)
    ResetPlayerSecurityState(source)
end)

RegisterNetEvent('matti-airsoft:setGameMode', function(mode)
    if type(mode) ~= 'string' then
        return
    end
    Lobby.SetGameMode(source, mode)
end)

RegisterNetEvent('matti-airsoft:setLmsEnabled', function(enabled)
    if type(enabled) ~= 'boolean' then
        return
    end

    Lobby.SetLmsEnabled(source, enabled)
end)

RegisterNetEvent('matti-airsoft:setLobbyLoadout', function(loadout)
    -- Resolve loadout from server-side Config by name; never trust the client-supplied object
    local loadoutName = type(loadout) == 'table' and type(loadout.name) == 'string' and loadout.name or nil
    if not loadoutName then
        return
    end

    local resolvedLoadout = nil
    for _, cfg in ipairs(Config.Loadouts or {}) do
        if cfg.name == loadoutName then
            resolvedLoadout = cfg
            break
        end
    end

    if not resolvedLoadout then
        return
    end

    Lobby.SetLoadout(source, resolvedLoadout)
end)

RegisterNetEvent('matti-airsoft:setMatchTimer', function(minutes)
    if Lobby.SetMatchTimer(source, minutes) then
        local normalizedMinutes = tonumber(minutes) or 0
        local timerText = normalizedMinutes == 0 and Lang:t('notifications.timer_disabled') or (normalizedMinutes .. ' ' .. Lang:t('menu.minutes'))
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.match_timer_set') .. ' ' .. timerText, 'success')
    end
end)

RegisterNetEvent('matti-airsoft:setScoreLimit', function(limit)
    if Lobby.SetScoreLimit(source, limit) then
        local normalizedLimit = tonumber(limit) or 0
        local limitText = normalizedLimit == 0 and Lang:t('notifications.score_limit_disabled') or (normalizedLimit .. ' ' .. Lang:t('menu.kills'))
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.score_limit_set') .. ' ' .. limitText, 'success')
    end
end)

RegisterNetEvent('matti-airsoft:enterSpectator', function()
    local playerId = source
    local lobbyId = Data.playerLobbies[playerId] or Data.arenaStatLobbies[playerId]

    if not lobbyId or Data.activeLobbyInArena ~= lobbyId then
        return
    end

    if not Data.arenaStats[playerId] then
        return
    end

    MatchState.SetSpectating(playerId, true)
    Data.arenaPresence[playerId] = nil
    Data.recentAttackers[playerId] = nil

    local lobby = Data.lobbies[lobbyId]
    if lobby then
        Modes.OnPlayerEliminated(lobbyId, lobby, playerId)
    end

    Leaderboard.Broadcast(lobbyId)
    Leaderboard.BroadcastArenaBoard()
end)

RegisterNetEvent('matti-airsoft:startLobbyGame', function()
    Lobby.StartGame(source)
end)

RegisterNetEvent('matti-airsoft:setPlayerTeam', function(team)
    if team ~= 'team1' and team ~= 'team2' then
        return
    end

    local lobbyId = Data.playerLobbies[source]

    if not lobbyId or not Data.lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.not_in_lobby'), 'error')
        return
    end

    local lobby = Data.lobbies[lobbyId]

    if not Lobby.IsTeamBasedMode(lobby.gameMode) then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.not_teams_mode'), 'error')
        return
    end

    Data.playerTeams[source] = team

    if Config.Debug then
        print(' Player ' .. source .. ' set to ' .. team)
    end

    Lobby.BroadcastToLobby(lobbyId, 'matti-airsoft:lobbyUpdated', lobby)

    TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.team_selected') .. ' ' .. (team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

local function CanPlayerModifyInventory(playerId)
    if Data.loadoutGrantState and Data.loadoutGrantState[playerId] then
        return true
    end

    if GetPlayerArenaLobby(playerId) then
        return true
    end

    local lobbyId = Data.playerLobbies[playerId]
    if lobbyId and Data.lobbies[lobbyId] and Data.activeLobbyInArena == lobbyId then
        return true
    end

    if Data.arenaStats[playerId] and Utils.IsPlayerInArena(playerId) then
        return true
    end

    return false
end

RegisterNetEvent('matti-airsoft:playerEnteredArena', function()
    if not Utils.CheckRateLimit(source, 'playerEnteredArena') then
        return
    end

    if not Utils.IsPlayerInArena(source) then
        Utils.LogSuspiciousActivity(source, 'playerEnteredArena', 'outside_arena')
        return
    end

    local lobbyId = Data.playerLobbies[source]
    if not lobbyId or Data.activeLobbyInArena ~= lobbyId then
        return
    end
    Leaderboard.AddPlayer(source)
end)

RegisterNetEvent('matti-airsoft:playerLeftArena', function()
    if not Utils.CheckRateLimit(source, 'playerLeftArena') then
        return
    end

    Data.recentAttackers[source] = nil
    Leaderboard.RemovePlayer(source)
end)

RegisterNetEvent('matti-airsoft:exitMatch', function()
    MatchState.ClearPlayer(source)
end)

RegisterNetEvent('matti-airsoft:registerRecentAttacker', function(attackerId)
    local victimId = source

    if not Utils.CheckRateLimit(victimId, 'registerRecentAttacker') then
        return
    end

    local attacker = tonumber(attackerId)

    if not attacker or attacker == victimId then
        return
    end

    if not Data.arenaStats[attacker] or not Data.arenaStats[victimId] then
        return
    end

    if not Player(attacker).state.airsoftInMatch then
        return
    end

    if not Utils.IsPlayerInArena(victimId) or not Utils.IsPlayerInArena(attacker) then
        Utils.LogSuspiciousActivity(victimId, 'registerRecentAttacker', 'outside_arena')
        return
    end

    local victimCoords = Utils.GetPlayerCoords(victimId)
    local attackerCoords = Utils.GetPlayerCoords(attacker)
    if not victimCoords or not attackerCoords then
        return
    end

    local maxDistance = Utils.GetKillerFallbackDistance()
    if #(victimCoords - attackerCoords) > maxDistance then
        Utils.LogSuspiciousActivity(victimId, 'registerRecentAttacker', 'attacker_too_far')
        return
    end

    Data.recentAttackers[victimId] = {
        attackerId = attacker,
        timestamp = GetGameTimer()
    }

    if Config.Debug then
        print(' Cached recent attacker for victim ' .. victimId .. ': ' .. attacker)
    end
end)

RegisterNetEvent('matti-airsoft:playerWasHit', function(shouldCreditKiller)
    local victimId = source

    if not Utils.CheckRateLimit(victimId, 'playerWasHit') then
        return
    end

    if not Data.arenaStats[victimId] then
        return
    end

    if not Utils.IsPlayerInArena(victimId) then
        Utils.LogSuspiciousActivity(victimId, 'playerWasHit', 'outside_arena')
        return
    end

    if Utils.IsSpawnProtected(victimId) then
        return
    end

    local killerId = Utils.GetRecentAttacker(victimId)
    local creditKiller = shouldCreditKiller == true

    if not killerId and creditKiller then
        killerId = Utils.GetClosestArenaPlayer(victimId, Utils.GetKillerFallbackDistance())
    end

    if killerId and (killerId == victimId or not Data.arenaStats[killerId]) then
        killerId = nil
        creditKiller = false
    end

    if not killerId then
        creditKiller = false
    end

    if Config.Debug then
        print(' Processing hit victim=' .. victimId .. ' killer=' .. tostring(killerId) .. ' credited=' .. tostring(creditKiller))
    end

    Leaderboard.RecordHit(victimId, killerId, creditKiller)

    if Config.RefillLoadoutAmmoOnRespawn then
        local lobby = GetPlayerArenaLobby(victimId)
        if lobby and lobby.selectedLoadout then
            RefillMissingLoadoutAmmo(victimId, lobby.selectedLoadout)
        end
    end

    Data.recentAttackers[victimId] = nil
end)

RegisterServerEvent('matti-airsoft:revivePlayer', function()
    if not Data.arenaStats[source] then
        return
    end

    if not Utils.IsPlayerInArena(source) then
        Utils.LogSuspiciousActivity(source, 'revivePlayer', 'outside_arena')
        return
    end

    Utils.RevivePlayer(source)

    if Config.Debug then
        print(' Player ' .. source .. ' revived in arena')
    end

    Utils.ApplySpawnProtection(source)
end)

RegisterServerEvent('matti-airsoft:giveWeapon', function(weaponName)
    if not Utils.CheckRateLimit(source, 'giveWeapon') then
        return
    end

    if type(weaponName) ~= 'string' or weaponName == '' then
        return
    end

    local normalizedWeaponName = SharedUtils.NormalizeItemName(weaponName)
    local lobby = GetPlayerArenaLobby(source)
    if not lobby or not lobby.selectedLoadout then
        return
    end

    if not ConsumeLoadoutGrant(source, lobby, 'weapons', normalizedWeaponName, 1) then
        return
    end

    Utils.HandlePlayerItem(source, weaponName, 1, 'add')
end)

RegisterServerEvent('matti-airsoft:giveItem', function(itemName, amount, metadata, slot)
    if not Utils.CheckRateLimit(source, 'giveItem') then
        return
    end

    local isValidRequest, normalizedItemName, normalizedAmount = ValidateItemRequest(itemName, amount)
    if not isValidRequest then
        return
    end

    local lobby = GetPlayerArenaLobby(source)
    if not lobby or not lobby.selectedLoadout then
        return
    end

    if not ConsumeLoadoutGrant(source, lobby, 'ammo', normalizedItemName, normalizedAmount) then
        return
    end

    Utils.HandlePlayerItem(source, itemName, normalizedAmount, 'add', {
        metadata = metadata,
        slot = slot,
    })
end)

RegisterNetEvent('matti-airsoft:restoreItems', function()
    Utils.RestorePlayerInventory(source)
    ResetPlayerSecurityState(source)
end)

RegisterNetEvent('matti-airsoft:enforceArenaInventory', function()
    local playerId = source
    if not Utils.Throttle(playerId, 'enforceArenaInventory', 400) then
        return
    end

    if not Config.EnforceArenaLoadoutItemsOnly then
        return
    end

    if not CanPlayerModifyInventory(playerId) then
        return
    end

    local lobby = GetPlayerArenaLobby(playerId)
    if not lobby then
        return
    end

    Utils.StashDisallowedArenaItems(playerId, GetAllowedArenaItemSet(lobby.selectedLoadout))
end)

local function GrantSelectedLoadout(playerId)
    local lobbyId = Data.playerLobbies[playerId]
    local lobby = lobbyId and Data.lobbies[lobbyId]
    if not lobby or not lobby.selectedLoadout or Data.activeLobbyInArena ~= lobbyId then
        return false
    end

    local state = EnsureLoadoutGrantState(playerId, lobby)
    if state.issuedAny then
        Utils.MarkLoadoutReady(playerId, true)
        return true
    end

    if not Utils.GivePlayerLoadout(playerId, lobby.selectedLoadout) then
        return false
    end

    for _, bucket in pairs(state.grants) do
        for itemName in pairs(bucket) do
            bucket[itemName] = 0
        end
    end
    state.issuedAny = true
    Utils.MarkLoadoutReady(playerId, true)
    return true
end

lib.callback.register('matti-airsoft:stashPlayerInventory', function(source)
    if not CanPlayerModifyInventory(source) then
        return false
    end

    return Utils.StashAndClearInventory(source)
end)

lib.callback.register('matti-airsoft:prepareArenaLoadout', function(playerId, price)
    local lobbyId = Data.playerLobbies[playerId]
    local lobby = lobbyId and Data.lobbies[lobbyId]
    if not lobby or not lobby.selectedLoadout or Data.activeLobbyInArena ~= lobbyId then
        return false
    end

    local normalizedPrice = tonumber(price) or 0
    if normalizedPrice > 0 and not Utils.RemoveMoney(playerId, normalizedPrice, 'Airsoft Loadout') then
        return 'cannot_afford'
    end

    if not Data.inventoryStashed or not Data.inventoryStashed[playerId] then
        Utils.StashAndClearInventory(playerId)
    end

    if not GrantSelectedLoadout(playerId) then
        Utils.RestorePlayerInventory(playerId)
        ResetPlayerSecurityState(playerId)
        if normalizedPrice > 0 then
            Utils.AddMoney(playerId, normalizedPrice, 'Airsoft Loadout Refund')
        end
        return false
    end

    return true
end)

RegisterNetEvent('matti-airsoft:stripLoadout', function()
    if not CanPlayerModifyInventory(source) then
        return
    end

    Utils.StripArenaLoadout(source)
end)

RegisterServerEvent('matti-airsoft:removeWeapon', function(weaponName)
    if not CanPlayerModifyInventory(source) then
        Utils.LogSuspiciousActivity(source, 'removeWeapon', 'invalid_context')
        return
    end

    if type(weaponName) ~= 'string' or weaponName == '' then
        return
    end

    local removed = Utils.HandlePlayerItem(source, weaponName, 1, 'remove')
    if removed then
        Utils.RemoveWeaponFromPed(source, weaponName)
    end
end)

RegisterServerEvent('matti-airsoft:removeItem', function(itemName, amount, slot, metadata)
    if not Utils.CheckRateLimit(source, 'removeItem') then
        return
    end

    if not CanPlayerModifyInventory(source) then
        Utils.LogSuspiciousActivity(source, 'removeItem', 'invalid_context')
        return
    end

    local isValidRequest, _, normalizedAmount = ValidateItemRequest(itemName, amount)
    if not isValidRequest then
        return
    end

    local removed = Utils.HandlePlayerItem(source, itemName, normalizedAmount, 'remove', {
        metadata = metadata,
        slot = slot,
    })

    if removed then
        local shouldSaveItem = true
        local grantState = Data.loadoutGrantState and Data.loadoutGrantState[source]

        if grantState and grantState.issuedAny then
            -- First, try to get the active loadout from the lobby
            local selectedLoadout = nil
            local lobby = GetPlayerArenaLobby(source)
            if lobby then
                selectedLoadout = lobby.selectedLoadout
            end

            -- Fallback: player already left the lobby (e.g. during exit cleanup),
            -- look up loadout by name from server config so we still detect loadout items
            if not selectedLoadout and grantState.loadoutName then
                for _, cfg in ipairs(Config.Loadouts or {}) do
                    if cfg.name == grantState.loadoutName then
                        selectedLoadout = cfg
                        break
                    end
                end
            end

            if selectedLoadout and IsLoadoutItem(selectedLoadout, itemName) then
                shouldSaveItem = false
            end
        end

        if shouldSaveItem then
            Data.savedInventories = Data.savedInventories or {}
            Data.savedInventories[source] = Data.savedInventories[source] or {}
            table.insert(Data.savedInventories[source], {
                name = itemName,
                amount = normalizedAmount,
                metadata = metadata,
                slot = slot,
            })
        end
    end
end)

RegisterServerEvent('matti-airsoft:debugZoneEntry', function(playerName, action)
    if Config.Debug then
        print(playerName .. ' has ' .. action .. ' the airsoft zone.')
    end
end)

RegisterNetEvent('matti-airsoft:reportArenaStatus', function(adminId, isInArena)
    local normalizedAdminId = tonumber(adminId)
    if not normalizedAdminId or type(isInArena) ~= 'boolean' then
        return
    end

    Data.pendingArenaStatusChecks = Data.pendingArenaStatusChecks or {}
    if Data.pendingArenaStatusChecks[source] ~= normalizedAdminId then
        return
    end

    Data.pendingArenaStatusChecks[source] = nil

    if isInArena then
        TriggerClientEvent('matti-airsoft:forceExitArena', source)
        TriggerClientEvent('matti-airsoft:sendNotification', normalizedAdminId, Lang:t('command.player_removed'), 'success')
    else
        TriggerClientEvent('matti-airsoft:sendNotification', normalizedAdminId, Lang:t('command.player_not_in_arena'), 'error')
    end
end)
