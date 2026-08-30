GunGame = {}

function GunGame.GetStages()
	return SharedUtils.GetGunGameStages()
end

function GunGame.EnsureState(lobbyId)
	Data.gunGameLevel = Data.gunGameLevel or {}
	Data.gunGameLevel[lobbyId] = Data.gunGameLevel[lobbyId] or {}
	return Data.gunGameLevel[lobbyId]
end

function GunGame.GetPlayerLevel(lobbyId, playerId)
	local state = GunGame.EnsureState(lobbyId)
	return state[playerId] or 1
end

function GunGame.SetPlayerLevel(lobbyId, playerId, level)
	local state = GunGame.EnsureState(lobbyId)
	state[playerId] = level
end

function GunGame.GrantStageWeapon(playerId, stageIndex)
	local stages = GunGame.GetStages()
	local stage = stages[stageIndex]
	if not stage then
		return false
	end

	for _, stageWeapon in ipairs(stages) do
		Utils.HandlePlayerItem(playerId, stageWeapon.weapon, 1, "remove")
	end

	Utils.HandlePlayerItem(playerId, stage.weapon, 1, "add")
	if stage.ammo and stage.ammo.name and stage.ammo.amount then
		Utils.HandlePlayerItem(playerId, stage.ammo.name, stage.ammo.amount, "add")
	end

	TriggerClientEvent("matti-airsoft:client:removeWeaponFromPed", playerId, stage.weapon)
	TriggerClientEvent("matti-airsoft:gunGameStageChanged", playerId, stageIndex, #stages, stage.weapon)
	return true
end

function GunGame.InitializePlayer(lobbyId, playerId)
	GunGame.SetPlayerLevel(lobbyId, playerId, 1)
	GunGame.GrantStageWeapon(playerId, 1)
end

Modes.Register("gungame", {
	onMatchStart = function(lobbyId, lobby)
		local state = GunGame.EnsureState(lobbyId)
		for playerId, _ in pairs(lobby.players) do
			state[playerId] = 1
		end
	end,
	applyHitScoring = function(lobbyId, lobby, victimId, killerId, creditKiller)
		local victimStats = ModesShared.EnsurePlayerStats(victimId)
		victimStats.deaths = victimStats.deaths + 1
		ModesShared.UpdateKillStreak(victimId, false)

		if not creditKiller or not killerId or killerId == victimId then
			return nil
		end

		local killerStats = ModesShared.EnsurePlayerStats(killerId)
		killerStats.kills = killerStats.kills + 1
		ModesShared.UpdateKillStreak(killerId, true)

		local stages = GunGame.GetStages()
		local currentLevel = GunGame.GetPlayerLevel(lobbyId, killerId)
		local nextLevel = currentLevel + 1

		if nextLevel > #stages then
			ModesShared.EndMatch(lobbyId, "gungame")
			return killerStats.name
		end

		GunGame.SetPlayerLevel(lobbyId, killerId, nextLevel)
		GunGame.GrantStageWeapon(killerId, nextLevel)

		return killerStats.name
	end,
	onPlayerEliminated = function(_lobbyId, _lobby, _playerId)
	end,
	shouldRespawn = function(lobby)
		return not SharedUtils.IsLmsEnabled(lobby)
	end,
	shouldEnterSpectator = function(lobby)
		return SharedUtils.IsLmsEnabled(lobby)
	end,
})
