lib.callback.register("matti-airsoft:canAffordLoadout", function(source, price)
	local player = Utils.GetPlayer(source)
	if not player then
		return false
	end

	local normalizedPrice = tonumber(price) or 0
	if normalizedPrice <= 0 then
		return true
	end

	return Utils.RemoveMoney(source, normalizedPrice, "Airsoft Loadout")
end)

lib.callback.register("matti-airsoft:getPlayerTeam", function(source)
	return Data.playerTeams[source] or nil
end)

lib.callback.register("matti-airsoft:getLobbyTeams", function(source)
	local lobbyId = Data.playerLobbies[source]
	if not lobbyId or not Data.lobbies[lobbyId] then
		return {
			team1 = {},
			team2 = {},
			unassigned = {},
		}
	end

	return Lobby.GetTeamMembers(lobbyId)
end)

lib.callback.register("matti-airsoft:getLobbies", function()
	local availableLobbies = {}
	for lobbyId, lobby in pairs(Data.lobbies) do
		table.insert(availableLobbies, {
			id = lobby.id,
			name = lobby.name,
			host = Utils.GetPlayerName(lobby.host),
			playerCount = Lobby.GetPlayerCount(lobby),
			maxPlayers = lobby.maxPlayers,
			gameMode = lobby.gameMode,
			isInArena = (Data.activeLobbyInArena == lobbyId),
		})
	end

	return {
		lobbies = availableLobbies,
		arenaOccupied = Data.activeLobbyInArena ~= nil,
	}
end)

lib.callback.register("matti-airsoft:getPlayerLobby", function(source)
	local lobbyId = Data.playerLobbies[source]
	if lobbyId and Data.lobbies[lobbyId] then
		return Data.lobbies[lobbyId]
	end

	return nil
end)

lib.callback.register("matti-airsoft:getLeaderboard", function()
	return Leaderboard.Get()
end)

lib.callback.register("matti-airsoft:getPlayerStats", function(source)
	return Stats.GetPlayerStats(source)
end)
