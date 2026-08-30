local function applyTeamScoring(lobbyId, lobby, victimId, killerId, creditKiller)
	local victimStats = ModesShared.EnsurePlayerStats(victimId)
	victimStats.deaths = victimStats.deaths + 1
	ModesShared.UpdateKillStreak(victimId, false)

	if not creditKiller or not killerId or killerId == victimId then
		return nil
	end

	local killerStats = ModesShared.EnsurePlayerStats(killerId)
	local killerTeam = Data.playerTeams[killerId]
	local victimTeam = Data.playerTeams[victimId]

	if killerTeam and victimTeam and killerTeam == victimTeam then
		local opposingTeam = Leaderboard.GetOpposingTeam(killerTeam)
		if opposingTeam then
			Leaderboard.EnsureLobbyTeamScores(lobbyId)
			Data.teamScores[lobbyId][opposingTeam] = (Data.teamScores[lobbyId][opposingTeam] or 0) + 1
		end
		return nil
	end

	killerStats.kills = killerStats.kills + 1
	ModesShared.UpdateKillStreak(killerId, true)

	if killerTeam then
		Leaderboard.EnsureLobbyTeamScores(lobbyId)
		Data.teamScores[lobbyId][killerTeam] = (Data.teamScores[lobbyId][killerTeam] or 0) + 1
	end

	return killerStats.name
end

Modes.Register("teams", {
	applyHitScoring = applyTeamScoring,
	onPlayerHit = function(lobbyId, lobby, victimId, killerId, creditKiller)
		if ModesShared.ScoreLimitReached(lobby) then
			ModesShared.EndMatch(lobbyId, "score_limit")
		end
	end,
	onPlayerEliminated = function(lobbyId, lobby, playerId)
		if not SharedUtils.IsLmsEnabled(lobby) then
			return
		end

		local alivePlayers = ModesShared.CountAlivePlayersInLobby(lobbyId)
		local trackedPlayers = ModesShared.CountTrackedPlayersForLobby(lobbyId)
		if trackedPlayers > 1 and alivePlayers <= 1 then
			ModesShared.EndMatch(lobbyId, "elimination")
		elseif alivePlayers == 0 then
			ModesShared.EndMatch(lobbyId, "empty")
		end
	end,
	shouldRespawn = function(lobby)
		return not SharedUtils.IsLmsEnabled(lobby)
	end,
	shouldEnterSpectator = function(lobby)
		return SharedUtils.IsLmsEnabled(lobby)
	end,
})
