ModesShared = {}

function ModesShared.GetLobby(lobbyId)
	return lobbyId and Data.lobbies[lobbyId] or nil
end

function ModesShared.GetActiveLobbyId()
	return Data.activeLobbyInArena
end

function ModesShared.CountAlivePlayersInLobby(lobbyId)
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

function ModesShared.CountTrackedPlayersForLobby(lobbyId)
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

function ModesShared.EnsurePlayerStats(playerId)
	if not Data.arenaStats[playerId] then
		Data.arenaStats[playerId] = {
			name = Utils.GetPlayerName(playerId),
			kills = 0,
			deaths = 0,
			streak = 0,
			bestStreak = 0,
		}
	end

	Data.arenaStats[playerId].name = Utils.GetPlayerName(playerId)
	return Data.arenaStats[playerId]
end

function ModesShared.GetScoreLimit(lobby)
	local limit = tonumber(lobby and lobby.scoreLimit) or 0
	if limit < 0 then
		limit = 0
	end
	return limit
end

function ModesShared.GetLeadingPlayerKills(lobbyId)
	local topKills = 0
	for playerId, stats in pairs(Data.arenaStats) do
		if Data.arenaStatLobbies[playerId] == lobbyId and stats.kills > topKills then
			topKills = stats.kills
		end
	end
	return topKills
end

function ModesShared.GetLeadingTeamScore(lobbyId)
	local scores = Data.teamScores[lobbyId]
	if not scores then
		return 0
	end
	return math.max(scores.team1 or 0, scores.team2 or 0)
end

function ModesShared.ScoreLimitReached(lobby)
	local limit = ModesShared.GetScoreLimit(lobby)
	if limit <= 0 then
		return false
	end

	if SharedUtils.IsTeamBasedMode(lobby.gameMode) then
		return ModesShared.GetLeadingTeamScore(lobby.id) >= limit
	end

	return ModesShared.GetLeadingPlayerKills(lobby.id) >= limit
end

function ModesShared.EndMatch(lobbyId, reason)
	if not lobbyId then
		return
	end

	local lobby = ModesShared.GetLobby(lobbyId)
	if lobby then
		Data.matchRecap = Data.matchRecap or {}
		Data.matchRecap[lobbyId] = Leaderboard.BuildMatchRecap(lobbyId, reason)
	end

	for pid, isAlive in pairs(Data.arenaPresence) do
		if isAlive and Data.arenaStatLobbies[pid] == lobbyId then
			TriggerClientEvent("matti-airsoft:matchEndedElimination", pid)
		end
	end

	local playersToRevive = {}
	for pid, _ in pairs((lobby and lobby.players) or {}) do
		playersToRevive[pid] = true
	end
	for pid, trackedLobbyId in pairs(Data.arenaStatLobbies or {}) do
		if trackedLobbyId == lobbyId then
			playersToRevive[pid] = true
		end
	end

	for pid, _ in pairs(playersToRevive) do
		Utils.RevivePlayer(pid)
	end

	for pid, _ in pairs((lobby and lobby.players) or {}) do
		TriggerClientEvent("matti-airsoft:matchEnded", pid, Data.matchRecap and Data.matchRecap[lobbyId] or nil)
	end

	Leaderboard.BroadcastArenaBoard()
	Leaderboard.FinalizeMatch(lobbyId)
end

function ModesShared.UpdateKillStreak(killerId, didKill)
	if not killerId or not Data.arenaStats[killerId] then
		return
	end

	local stats = Data.arenaStats[killerId]
	if didKill then
		stats.streak = (stats.streak or 0) + 1
		if stats.streak > (stats.bestStreak or 0) then
			stats.bestStreak = stats.streak
		end
	else
		stats.streak = 0
	end
end
