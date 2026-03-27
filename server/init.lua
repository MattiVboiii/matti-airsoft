AddEventHandler('playerDropped', function()
    local src = source

    Data.recentAttackers[src] = nil
    if Data.loadoutGrantState then
        Data.loadoutGrantState[src] = nil
    end
    if Data.savedInventories then
        Data.savedInventories[src] = nil
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

    Data.activeLobbyInArena = nil
end

-- Match Timer Thread
if Config.MatchTimerEnabled then
    Citizen.CreateThread(function()
        while true do
            Wait(1000) -- Update every second

            local activeLobbyId = Data.activeLobbyInArena
            if activeLobbyId and Data.lobbies[activeLobbyId] then
                TickActiveLobbyTimer(activeLobbyId)
            end
        end
    end)
end
