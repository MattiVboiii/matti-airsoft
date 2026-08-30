Leaderboard = {}

function Leaderboard.FinalizeMatch(lobbyId)
	if not lobbyId then
		return
	end

	Data.finalizedLobbies = Data.finalizedLobbies or {}
	if Data.finalizedLobbies[lobbyId] then
		return
	end

	Data.finalizedLobbies[lobbyId] = true

	Stats.PersistMatchResults(lobbyId)
	TriggerEvent("matti-airsoft:matchEnded", lobbyId)
	MatchState.SetLobby(lobbyId, false)
	Data.activeLobbyInArena = nil
	Data.gunGameLevel = Data.gunGameLevel or {}
	Data.gunGameLevel[lobbyId] = nil
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
			team2 = 0,
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
	if team == "team1" then
		return "team2"
	end

	if team == "team2" then
		return "team1"
	end

	return nil
end

function Leaderboard.BuildRows()
	local leaderboard = {}
	local lobbyId = Data.activeLobbyInArena
	local lobby = lobbyId and Data.lobbies[lobbyId] or nil
	local gunGameStages = SharedUtils.IsGunGameMode(lobby and lobby.gameMode) and #SharedUtils.GetGunGameStages() or nil

	for playerId, stats in pairs(Data.arenaStats) do
		local playerLobbyId = Data.playerLobbies[playerId] or Data.arenaStatLobbies[playerId]
		local playerLobby = playerLobbyId and Data.lobbies[playerLobbyId] or nil
		local isTeamsMode = playerLobby and Lobby.IsTeamBasedMode(playerLobby.gameMode)
		local playerTeam = isTeamsMode and Data.playerTeams[playerId] or nil
		local lobbyTeamScores = (isTeamsMode and playerLobbyId and Data.teamScores[playerLobbyId]) or nil
		local gunGameLevel = nil

		if gunGameStages and playerLobbyId == lobbyId then
			gunGameLevel = GunGame.GetPlayerLevel(lobbyId, playerId)
		end

		table.insert(leaderboard, {
			name = stats.name,
			kills = stats.kills,
			deaths = stats.deaths,
			kd = stats.deaths > 0 and (stats.kills / stats.deaths) or stats.kills,
			team = playerTeam,
			teamKills = playerTeam and Leaderboard.GetTeamScoreForPlayer(playerId) or nil,
			team1Kills = lobbyTeamScores and (lobbyTeamScores.team1 or 0) or nil,
			team2Kills = lobbyTeamScores and (lobbyTeamScores.team2 or 0) or nil,
			gunGameLevel = gunGameLevel,
			gunGameTotal = gunGameStages,
			streak = stats.streak or 0,
		})
	end

	return leaderboard
end

function Leaderboard.BuildMatchRecap(lobbyId, reason)
	local lobby = lobbyId and Data.lobbies[lobbyId] or nil
	local rows = Leaderboard.BuildRows()
	local mvp = nil
	local bestStreak = nil

	for _, row in ipairs(rows) do
		if not mvp or row.kills > mvp.kills then
			mvp = row
		end
		if not bestStreak or (row.streak or 0) > (bestStreak.streak or 0) then
			bestStreak = row
		end
	end

	for playerId, stats in pairs(Data.arenaStats) do
		if Data.arenaStatLobbies[playerId] == lobbyId and (not mvp or stats.kills > mvp.kills) then
			mvp = {
				name = stats.name,
				kills = stats.kills,
				deaths = stats.deaths,
				streak = stats.bestStreak or 0,
			}
		end
		if Data.arenaStatLobbies[playerId] == lobbyId and stats.bestStreak and (not bestStreak or stats.bestStreak > (bestStreak.streak or 0)) then
			bestStreak = {
				name = stats.name,
				streak = stats.bestStreak,
			}
		end
	end

	return {
		reason = reason,
		mode = lobby and lobby.gameMode or "ffa",
		mvp = mvp,
		bestStreak = bestStreak,
		rows = rows,
		teamScores = lobbyId and Data.teamScores[lobbyId] or nil,
	}
end

function Leaderboard.BuildMatchHud(lobbyId)
	local lobby = lobbyId and Data.lobbies[lobbyId] or nil
	if not lobby then
		return nil
	end

	return {
		mode = lobby.gameMode,
		timer = lobby.matchTimer,
		scoreLimit = lobby.scoreLimit or 0,
		rows = Leaderboard.BuildRows(),
	}
end

function Leaderboard.AddPlayer(playerId)
	local lobbyId = Data.playerLobbies[playerId]

	if lobbyId then
		Data.arenaStatLobbies[playerId] = lobbyId
	end

	Data.arenaPresence[playerId] = true
	ModesShared.EnsurePlayerStats(playerId)

	if SharedUtils.IsGunGameMode(Data.lobbies[lobbyId] and Data.lobbies[lobbyId].gameMode) then
		GunGame.InitializePlayer(lobbyId, playerId)
	end

	Leaderboard.Broadcast()
	Leaderboard.BroadcastArenaBoard()
	Utils.ApplySpawnProtection(playerId)
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
			Modes.OnPlayerEliminated(lobbyId, lobby, playerId)
		end
	end

	Leaderboard.Broadcast()
	Leaderboard.BroadcastArenaBoard()
end

function Leaderboard.RecordHit(victimId, killerId, creditKiller)
	local victimLobbyId = Data.playerLobbies[victimId] or Data.arenaStatLobbies[victimId]
	local lobby = victimLobbyId and Data.lobbies[victimLobbyId] or nil
	if not lobby or Data.activeLobbyInArena ~= victimLobbyId then
		return
	end

	ModesShared.EnsurePlayerStats(victimId)
	local killerName = Modes.ApplyHitScoring(victimLobbyId, lobby, victimId, killerId, creditKiller) or "Unknown"
	local victimName = Data.arenaStats[victimId].name or "Unknown"

	if killerName ~= "Unknown" then
		Lobby.BroadcastToLobby(victimLobbyId, "matti-airsoft:showKillFeed", killerName, victimName)
	end

	if Config.Debug then
		if killerId and killerId ~= victimId then
			print(" " .. victimName .. " was hit by " .. killerName)
		else
			print(" " .. victimName .. " was hit")
		end
	end

	Modes.OnPlayerHit(victimLobbyId, lobby, victimId, killerId, creditKiller)
	Leaderboard.Broadcast()
	Leaderboard.BroadcastArenaBoard()
end

function Leaderboard.Broadcast()
	local lobbyId = Data.activeLobbyInArena
	if not lobbyId or not Data.lobbies[lobbyId] then
		return
	end

	local payload = Leaderboard.BuildMatchHud(lobbyId)
	Lobby.BroadcastToLobby(lobbyId, "matti-airsoft:updateLeaderboard", payload.rows)
	Lobby.BroadcastToLobby(lobbyId, "matti-airsoft:updateMatchHud", payload)
end

function Leaderboard.BroadcastArenaBoard()
	local lobbyId = Data.activeLobbyInArena
	if not lobbyId or not Data.lobbies[lobbyId] then
		TriggerClientEvent("matti-airsoft:updateArenaBoard", -1, nil)
		return
	end

	local payload = Leaderboard.BuildMatchHud(lobbyId)
	TriggerClientEvent("matti-airsoft:updateArenaBoard", -1, payload)
end

function Leaderboard.Get()
	return Leaderboard.BuildRows()
end

function Leaderboard.GetRecap(lobbyId)
	return Data.matchRecap and Data.matchRecap[lobbyId] or nil
end
