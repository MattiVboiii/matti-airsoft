Leaderboard = {}

local function CountAlivePlayersInLobby(lobbyId)
    if not lobbyId then
        return 0
    end

    local aliveCount = 0
    for playerId, isAlive in pairs(Data.arenaPresence) do
        if isAlive and Data.arenaStatLobbies[playerId] == lobbyId then
            aliveCount = aliveCount + 1
        end
    end

    return aliveCount
end

local function CountTrackedPlayersForLobby(lobbyId)
    if not lobbyId then
        return 0
    end

    local trackedCount = 0
    for playerId, trackedLobbyId in pairs(Data.arenaStatLobbies) do
        if trackedLobbyId == lobbyId and Data.arenaStats[playerId] then
            trackedCount = trackedCount + 1
        end
    end

    return trackedCount
end

function Leaderboard.ClearLobbyStats(lobbyId)
    if not lobbyId then
        return
    end

    for playerId, trackedLobbyId in pairs(Data.arenaStatLobbies) do
        if trackedLobbyId == lobbyId then
            Data.arenaStats[playerId] = nil
            Data.arenaPresence[playerId] = nil
            Data.arenaStatLobbies[playerId] = nil
        end
    end
end

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
        local lobbyId = Data.playerLobbies[playerId] or Data.arenaStatLobbies[playerId]
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
    local lobbyId = Data.playerLobbies[playerId]

    if lobbyId then
        Data.arenaStatLobbies[playerId] = lobbyId
    end

    Data.arenaPresence[playerId] = true

    if not Data.arenaStats[playerId] then
        Data.arenaStats[playerId] = {
            name = Utils.GetPlayerName(playerId),
            kills = 0,
            deaths = 0
        }
    end

    Data.arenaStats[playerId].name = Utils.GetPlayerName(playerId)

    Leaderboard.Broadcast()
end

function Leaderboard.RemovePlayer(playerId, options)
    options = options or {}
    local keepCachedIfActive = options.keepCachedIfActive ~= false

    local lobbyId = Data.playerLobbies[playerId] or Data.arenaStatLobbies[playerId]
    Data.arenaPresence[playerId] = nil

    local shouldKeepCachedStats = false
    if keepCachedIfActive and lobbyId and Data.activeLobbyInArena == lobbyId and Data.lobbies[lobbyId] then
        shouldKeepCachedStats = true
    end

    if not shouldKeepCachedStats then
        Data.arenaStats[playerId] = nil
        Data.arenaStatLobbies[playerId] = nil
    end

    if lobbyId and Data.activeLobbyInArena == lobbyId then
        local lobby = Data.lobbies[lobbyId]
        if lobby then
            local alivePlayers = CountAlivePlayersInLobby(lobbyId)
            local trackedPlayers = CountTrackedPlayersForLobby(lobbyId)
            local isDeathmatch = lobby.deathmatchEnabled == true

            -- In non-deathmatch, end early when only one (or zero) players are still alive.
            if not isDeathmatch and trackedPlayers > 1 and alivePlayers <= 1 then
                for pid, isAlive in pairs(Data.arenaPresence) do
                    if isAlive and Data.arenaStatLobbies[pid] == lobbyId then
                        TriggerClientEvent('matti-airsoft:matchEndedElimination', pid)
                    end
                end

                Data.activeLobbyInArena = nil

                if Config.Debug then
                    print(' Match ended early in lobby ' .. lobbyId .. ' (non-deathmatch elimination). Alive=' .. alivePlayers .. ', tracked=' .. trackedPlayers)
                end
            elseif alivePlayers == 0 then
                if Config.Debug then
                    print(' Arena cleared - lobby ' .. lobbyId .. ' has no more players in arena')
                end

                Data.activeLobbyInArena = nil
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
