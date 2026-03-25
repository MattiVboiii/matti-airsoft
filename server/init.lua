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

    if Data.arenaStats[src] then
        Data.arenaStats[src] = nil
        Leaderboard.Broadcast()
    end

    local lobbyId = Data.playerLobbies[src]
    if lobbyId and Data.lobbies[lobbyId] then
        Lobby.Leave(src)
    end
end)

-- Match Timer Thread
if Config.MatchTimerEnabled then
    Citizen.CreateThread(function()
        while true do
            Wait(1000) -- Update every second
            
            local activeLobbyId = Data.activeLobbyInArena
            if activeLobbyId and Data.lobbies[activeLobbyId] then
                local lobby = Data.lobbies[activeLobbyId]
                
                -- Only count down if timer is enabled (> 0)
                if lobby.matchTimer and lobby.matchTimer > 0 then
                    lobby.matchTimer = lobby.matchTimer - 1
                    
                    -- Broadcast timer update to all players in the lobby
                    Lobby.BroadcastToLobby(activeLobbyId, 'matti-airsoft:updateTimer', lobby.matchTimer)
                    
                    -- End match when timer reaches 0
                    if lobby.matchTimer <= 0 then
                        lobby.matchTimer = 0
                        Lobby.BroadcastToLobby(activeLobbyId, 'matti-airsoft:matchTimeExpired')
                        
                        if Config.Debug then
                            print(' Match time expired in lobby: ' .. activeLobbyId)
                        end
                        
                        -- Reset arena state
                        Data.activeLobbyInArena = nil
                    end
                end
            end
        end
    end)
end
