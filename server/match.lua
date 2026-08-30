MatchState = {}

function MatchState.SetPlayer(playerId, inMatch)
    if not playerId then
        return
    end

    local active = inMatch == true
    Player(playerId).state:set('airsoftInMatch', active, true)
    TriggerClientEvent('matti-airsoft:matchStateChanged', playerId, active)
end

function MatchState.SetLobby(lobbyId, inMatch)
    local lobby = lobbyId and Data.lobbies[lobbyId] or nil
    if not lobby or not lobby.players then
        return
    end

    for playerId, _ in pairs(lobby.players) do
        MatchState.SetPlayer(playerId, inMatch)
    end
end

function MatchState.ClearPlayer(playerId)
    MatchState.SetPlayer(playerId, false)
end
