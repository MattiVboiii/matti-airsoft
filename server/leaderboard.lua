Leaderboard = {}

function Leaderboard.EnsureLobbyTeamScores(lobbyId)
    if not lobbyId then
        return
    end

    if not Data.teamScores[lobbyId] then
        Data.teamScores[lobbyId] = {
            team1 = 0,
            team2 = 0
        }
    end
end

function Leaderboard.GetTeamScoreForPlayer(playerId)
    local lobbyId = Data.playerLobbies[playerId]
    local team = Data.playerTeams[playerId]

    if not lobbyId or not team then
        return nil
    end

    Leaderboard.EnsureLobbyTeamScores(lobbyId)
    local lobbyScores = Data.teamScores[lobbyId]
    return lobbyScores and lobbyScores[team] or 0
end

function Leaderboard.GetOpposingTeam(team)
    if team == 'team1' then
        return 'team2'
    end

    if team == 'team2' then
        return 'team1'
    end

    return nil
end

function Leaderboard.BuildRows()
    local leaderboard = {}

    for playerId, stats in pairs(Data.arenaStats) do
        local lobbyId = Data.playerLobbies[playerId]
        local lobby = lobbyId and Data.lobbies[lobbyId] or nil
        local isTeamsMode = lobby and lobby.gameMode == 'teams'
        local playerTeam = isTeamsMode and Data.playerTeams[playerId] or nil
        local lobbyTeamScores = (isTeamsMode and lobbyId and Data.teamScores[lobbyId]) or nil

        table.insert(leaderboard, {
            name = stats.name,
            kills = stats.kills,
            deaths = stats.deaths,
            kd = stats.deaths > 0 and (stats.kills / stats.deaths) or stats.kills,
            team = playerTeam,
            teamKills = playerTeam and Leaderboard.GetTeamScoreForPlayer(playerId) or nil,
            team1Kills = lobbyTeamScores and (lobbyTeamScores.team1 or 0) or nil,
            team2Kills = lobbyTeamScores and (lobbyTeamScores.team2 or 0) or nil
        })
    end

    return leaderboard
end

function Leaderboard.AddPlayer(playerId)
    if not Data.arenaStats[playerId] then
        Data.arenaStats[playerId] = {
            name = Utils.GetPlayerName(playerId),
            kills = 0,
            deaths = 0
        }
    end
    Leaderboard.Broadcast()
end

function Leaderboard.RemovePlayer(playerId)
    Data.arenaStats[playerId] = nil

    local lobbyId = Data.playerLobbies[playerId]
    if lobbyId and Data.activeLobbyInArena == lobbyId then
        local lobby = Data.lobbies[lobbyId]
        if lobby then
            local anyPlayerInArena = false
            for pid, _ in pairs(lobby.players) do
                if Data.arenaStats[pid] then
                    anyPlayerInArena = true
                    break
                end
            end

            if not anyPlayerInArena then
                Data.activeLobbyInArena = nil
                if Config.Debug then
                    print(' Arena cleared - lobby ' .. lobbyId .. ' has no more players in arena')
                end
            end
        end
    end

    Leaderboard.Broadcast()
end

function Leaderboard.RecordHit(victimId, killerId)
    local victimName = Data.arenaStats[victimId] and Data.arenaStats[victimId].name or 'Unknown'
    local killerName = 'Unknown'
    local victimLobbyId = Data.playerLobbies[victimId]

    if Data.arenaStats[victimId] then
        Data.arenaStats[victimId].deaths = Data.arenaStats[victimId].deaths + 1
    end

    if killerId and killerId ~= victimId and Data.arenaStats[killerId] then
        local killerLobbyId = Data.playerLobbies[killerId]
        local sharedLobbyId = (victimLobbyId and victimLobbyId == killerLobbyId) and killerLobbyId or nil
        local lobby = sharedLobbyId and Data.lobbies[sharedLobbyId] or nil
        local isTeamsMode = lobby and lobby.gameMode == 'teams'
        local killerTeam = Data.playerTeams[killerId]
        local victimTeam = Data.playerTeams[victimId]

        if isTeamsMode and killerTeam and victimTeam and killerTeam == victimTeam then
            local opposingTeam = Leaderboard.GetOpposingTeam(killerTeam)
            if opposingTeam then
                Leaderboard.EnsureLobbyTeamScores(sharedLobbyId)
                Data.teamScores[sharedLobbyId][opposingTeam] = (Data.teamScores[sharedLobbyId][opposingTeam] or 0) + 1
            end
        else
            Data.arenaStats[killerId].kills = Data.arenaStats[killerId].kills + 1
            killerName = Data.arenaStats[killerId].name

            if isTeamsMode and killerTeam then
                Leaderboard.EnsureLobbyTeamScores(sharedLobbyId)
                Data.teamScores[sharedLobbyId][killerTeam] = (Data.teamScores[sharedLobbyId][killerTeam] or 0) + 1
            end
        end
    end

    if killerName ~= 'Unknown' and victimLobbyId and Data.lobbies[victimLobbyId] then
        Lobby.BroadcastToLobby(victimLobbyId, 'matti-airsoft:showKillFeed', killerName, victimName)
    end

    if Config.Debug then
        if killerId and killerId ~= victimId then
            print(' ' .. victimName .. ' was hit by ' .. killerName)
        else
            print(' ' .. victimName .. ' was hit')
        end
    end

    Leaderboard.Broadcast()
end

function Leaderboard.Broadcast()
    TriggerClientEvent('matti-airsoft:updateLeaderboard', -1, Leaderboard.BuildRows())
end

function Leaderboard.Get()
    return Leaderboard.BuildRows()
end
