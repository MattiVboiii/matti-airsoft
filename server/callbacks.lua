QBCore.Functions.CreateCallback("matti-airsoft:canAffordLoadout", function(source, cb, price)
	local player = Utils.GetPlayer(source)
	if not player then
		cb(false)
		return
	end

	local normalizedPrice = tonumber(price) or 0
	if normalizedPrice <= 0 then
		cb(true)
		return
	end

	if Config.Framework == "ox" then
		local money = player.getAccount("money").money
		if money >= normalizedPrice then
			player.removeMoney(normalizedPrice, "Airsoft Loadout")
			cb(true)
		else
			cb(false)
		end
	else
		if player.Functions.RemoveMoney("cash", normalizedPrice, "airsoft") then
			cb(true)
		else
			cb(false)
		end
	end
end)

QBCore.Functions.CreateCallback("matti-airsoft:getPlayerTeam", function(source, cb)
	cb(Data.playerTeams[source] or nil)
end)

QBCore.Functions.CreateCallback("matti-airsoft:getLobbyTeams", function(source, cb)
	local lobbyId = Data.playerLobbies[source]
	if not lobbyId or not Data.lobbies[lobbyId] then
		cb({
			team1 = {},
			team2 = {},
			unassigned = {},
		})
		return
	end

	cb(Lobby.GetTeamMembers(lobbyId))
end)

QBCore.Functions.CreateCallback("matti-airsoft:getLobbies", function(_, cb)
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

	cb({
		lobbies = availableLobbies,
		arenaOccupied = Data.activeLobbyInArena ~= nil,
	})
end)

QBCore.Functions.CreateCallback("matti-airsoft:getPlayerLobby", function(source, cb)
	local lobbyId = Data.playerLobbies[source]
	if lobbyId and Data.lobbies[lobbyId] then
		cb(Data.lobbies[lobbyId])
	else
		cb(nil)
	end
end)

QBCore.Functions.CreateCallback("matti-airsoft:getLeaderboard", function(_, cb)
	cb(Leaderboard.Get())
end)

QBCore.Functions.CreateCallback("matti-airsoft:getPlayerStats", function(source, cb)
	cb(Stats.GetPlayerStats(source))
end)
