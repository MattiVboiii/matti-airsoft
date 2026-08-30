AddEventHandler('playerDropped', function()
    local src = source

    Utils.StripArenaLoadout(src)
    Utils.RestorePlayerInventory(src)

    Data.recentAttackers[src] = nil
    if Data.loadoutGrantState then
        Data.loadoutGrantState[src] = nil
    end
    if Data.savedInventories then
        Data.savedInventories[src] = nil
    end
    if Data.inventoryStashed then
        Data.inventoryStashed[src] = nil
    end
    if Data.loadoutReadyUntil then
        Data.loadoutReadyUntil[src] = nil
    end
    if Data.eventRateLimits then
        Data.eventRateLimits[src] = nil
    end
    if Data.pendingArenaStatusChecks then
        Data.pendingArenaStatusChecks[src] = nil
        for targetId, adminId in pairs(Data.pendingArenaStatusChecks) do
            if adminId == src then
                Data.pendingArenaStatusChecks[targetId] = nil
            end
        end
    end

    Leaderboard.RemovePlayer(src, { keepCachedIfActive = false })
    MatchState.ClearPlayer(src)

    local lobbyId = Data.playerLobbies[src]
    if lobbyId and Data.lobbies[lobbyId] then
        Lobby.Leave(src)
    end
end)

local function TickActiveLobbyTimer(activeLobbyId)
    local lobby = Data.lobbies[activeLobbyId]
    if not lobby then
        return
    end

    if not lobby.matchTimer or lobby.matchTimer <= 0 then
        return
    end

    lobby.matchTimer = lobby.matchTimer - 1
    Lobby.BroadcastToLobby(activeLobbyId, 'matti-airsoft:updateTimer', lobby.matchTimer)

    if lobby.matchTimer > 0 then
        return
    end

    lobby.matchTimer = 0
    Lobby.BroadcastToLobby(activeLobbyId, 'matti-airsoft:matchTimeExpired')

    if Config.Debug then
        print(' Match time expired in lobby: ' .. activeLobbyId)
    end

    ModesShared.EndMatch(activeLobbyId, 'timer')
end

local function ReconcileArenaPresence()
    for playerId, isPresent in pairs(Data.arenaPresence) do
        if isPresent and not Utils.IsPlayerInArena(playerId) then
            Data.arenaPresence[playerId] = nil
            if Config.Debug then
                print('[matti-airsoft] Reconciled arena presence for player ' .. playerId)
            end
        end
    end
end

exports('IsPlayerInArena', function(playerId)
    playerId = tonumber(playerId)
    if not playerId then
        return false
    end

    return Data.arenaPresence[playerId] == true and Utils.IsPlayerInArena(playerId)
end)

exports('GetActiveLobby', function()
    local lobbyId = Data.activeLobbyInArena
    if not lobbyId then
        return nil
    end

    return Data.lobbies[lobbyId]
end)

exports('GetActiveLobbyId', function()
    return Data.activeLobbyInArena
end)

CreateThread(function()
    Stats.Initialize()
end)

if Config.MatchTimerEnabled then
    CreateThread(function()
        while true do
            Wait(1000)

            local activeLobbyId = Data.activeLobbyInArena
            if activeLobbyId and Data.lobbies[activeLobbyId] then
                TickActiveLobbyTimer(activeLobbyId)
            end
        end
    end)
end

CreateThread(function()
    local interval = Utils.GetArenaReconcileIntervalMs()
    if interval < 1000 then
        interval = 1000
    end

    while true do
        Wait(interval)
        ReconcileArenaPresence()
    end
end)
