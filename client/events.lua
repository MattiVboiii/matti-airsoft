local function GetModeLabel(mode)
	local modeId = SharedUtils.NormalizeModeId(mode)
	local modeConfig = modeId and SharedUtils.GetConfiguredGameModes()[modeId] or nil
	local labelKey = modeConfig and modeConfig.label or nil

	if labelKey then
		return Lang:t(labelKey)
	end

	if modeId == "teams" then
		return Lang:t("menu.teams")
	end

	return Lang:t("menu.ffa")
end

local function IsTeamBasedMode(mode)
	return SharedUtils.IsTeamBasedMode(mode)
end

local function IsLmsEnabled(lobby)
	return SharedUtils.IsLmsEnabled(lobby)
end

RegisterNetEvent("matti-airsoft:openLobbyMenu", function()
	Framework.TriggerCallback("matti-airsoft:getPlayerLobby", function(lobby)
		if lobby then
			State.currentLobby = lobby
			TriggerEvent("matti-airsoft:openLobbyManagement")
		else
			TriggerEvent("matti-airsoft:openLobbyBrowser")
		end
	end)
end)

RegisterNetEvent("matti-airsoft:openLobbyBrowser")
AddEventHandler("matti-airsoft:openLobbyBrowser", function()
	local browserMenu = {}

	Menu.AddOption(browserMenu, {
		title = Lang:t("menu.create_lobby"),
		description = Lang:t("menu.create_lobby_desc"),
		event = "matti-airsoft:createLobbyPrompt",
		icon = "fas fa-plus",
		iconColor = "#2ecc71",
	})

	Framework.TriggerCallback("matti-airsoft:getLobbies", function(data)
		local lobbies = data.lobbies or {}
		local arenaOccupied = data.arenaOccupied or false

		if arenaOccupied then
			Menu.AddOption(browserMenu, {
				title = "🔴 " .. Lang:t("menu.arena_status"),
				description = Lang:t("menu.arena_occupied_warning"),
				icon = "fas fa-exclamation-triangle",
				iconColor = "#e74c3c",
				disabled = true,
			})
		end

		if #lobbies > 0 then
			if Menu.IsQbMenu() then
				Menu.AddOption(browserMenu, {
					title = Lang:t("menu.available_lobbies"),
					isHeader = true,
				})
			end

			for _, lobby in ipairs(lobbies) do
				local inArenaMarker = lobby.isInArena and " 🎮" or ""
				local lobbyInfo = lobby.name
					.. inArenaMarker
					.. " ("
					.. lobby.playerCount
					.. "/"
					.. lobby.maxPlayers
					.. ")"
				local lobbyDesc = Lang:t("menu.host") .. ": " .. lobby.host .. " | " .. GetModeLabel(lobby.gameMode)

				if lobby.isInArena then
					lobbyDesc = lobbyDesc .. "\n🎮 " .. Lang:t("menu.playing_in_arena")
				end

				Menu.AddOption(browserMenu, {
					title = lobbyInfo,
					description = lobbyDesc,
					event = "matti-airsoft:joinLobbyConfirm",
					args = { lobbyId = lobby.id },
					icon = "fas fa-users",
					iconColor = lobby.isInArena and "#e74c3c" or "#3498db",
				})
			end
		else
			Menu.AddOption(browserMenu, {
				title = Lang:t("menu.no_lobbies"),
				description = Lang:t("menu.no_lobbies_desc"),
				icon = "fas fa-info-circle",
				iconColor = "#95a5a6",
				disabled = true,
			})
		end

		Menu.AddOption(browserMenu, {
			title = Lang:t("menu.refresh"),
			description = Lang:t("menu.refresh_desc"),
			event = "matti-airsoft:openLobbyBrowser",
			icon = "fas fa-sync",
			iconColor = "#95a5a6",
		})

		Menu.AddOption(browserMenu, {
			title = Lang:t("menu.my_stats"),
			description = Lang:t("menu.my_stats_desc"),
			event = "matti-airsoft:openCareerStats",
			icon = "fas fa-chart-line",
			iconColor = "#3498db",
		})

		Menu.Open("matti_airsoft_lobby_browser", Lang:t("menu.lobby_browser"), browserMenu)
	end)
end)

RegisterNetEvent("matti-airsoft:openCareerStats")
AddEventHandler("matti-airsoft:openCareerStats", function()
	Framework.TriggerCallback("matti-airsoft:getPlayerStats", function(stats)
		if not stats then
			Utils.SendNotification(Lang:t("notifications.no_career_stats"), "info")
			return
		end

		local kills = stats.kills or 0
		local deaths = stats.deaths or 0
		local kd = deaths > 0 and string.format("%.2f", kills / deaths) or tostring(kills)
		local matches = stats.matches_played or 0

		lib.alertDialog({
			header = Lang:t("menu.my_stats"),
			content = Lang:t("menu.career_stats_body", {
				kills = kills,
				deaths = deaths,
				kd = kd,
				matches = matches,
			}),
			centered = true,
		})
	end)
end)

RegisterNetEvent("matti-airsoft:createLobbyPrompt")
AddEventHandler("matti-airsoft:createLobbyPrompt", function()
	local lobbyName = Menu.ShowSingleInput({
		title = Lang:t("menu.create_lobby"),
		submitText = Lang:t("menu.create"),
		label = Lang:t("menu.lobby_name"),
		placeholder = Lang:t("menu.lobby_name_placeholder"),
		type = "input",
		required = true,
	})

	if lobbyName then
		TriggerServerEvent("matti-airsoft:createLobby", lobbyName)
	end
end)

RegisterNetEvent("matti-airsoft:joinLobbyConfirm")
AddEventHandler("matti-airsoft:joinLobbyConfirm", function(data)
	TriggerServerEvent("matti-airsoft:joinLobby", data.lobbyId)
end)

RegisterNetEvent("matti-airsoft:lobbyCreated", function(lobby)
	State.currentLobby = lobby
	TriggerEvent("matti-airsoft:openLobbyManagement")
end)

RegisterNetEvent("matti-airsoft:lobbyUpdated", function(lobby)
	State.currentLobby = lobby
	if Config.MenuSystem == "ox_lib" then
		local currentMenu = lib.getOpenContextMenu()
		if currentMenu == "matti_airsoft_lobby_management" then
			TriggerEvent("matti-airsoft:openLobbyManagement")
		end
	end
end)

RegisterNetEvent("matti-airsoft:lobbyClosed", function()
	State.currentLobby = nil
	Utils.SendNotification(Lang:t("notifications.lobby_left"), "info")
end)

RegisterNetEvent("matti-airsoft:openLobbyManagement", function()
	if not State.currentLobby then
		return
	end

	local managementMenu = {}
	local isHost = State.currentLobby.host == GetPlayerServerId(PlayerId())

	if Menu.IsQbMenu() then
		Menu.AddOption(managementMenu, {
			title = State.currentLobby.name,
			description = Lang:t("menu.players") .. ": " .. Utils.TableCount(State.currentLobby.players),
			isHeader = true,
		})
	end

	local playerListText = ""
	for playerId, playerData in pairs(State.currentLobby.players) do
		local hostMarker = (playerId == State.currentLobby.host) and " 👑" or ""
		playerListText = playerListText .. playerData.name .. hostMarker .. "\n"
	end

	Menu.AddOption(managementMenu, {
		title = Lang:t("menu.players_list"),
		description = playerListText,
		icon = "fas fa-users",
		iconColor = "#3498db",
		disabled = true,
	})

	if isHost then
		local currentModeText = GetModeLabel(State.currentLobby.gameMode)
		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.game_mode"),
			description = Lang:t("menu.current_mode") .. ": " .. currentModeText,
			event = "matti-airsoft:selectGameMode",
			icon = "fas fa-gamepad",
			iconColor = "#3498db",
		})

		local lmsEnabled = IsLmsEnabled(State.currentLobby)
		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.lms_toggle"),
			description = Lang:t("menu.lms_toggle_desc")
				.. " "
				.. (lmsEnabled and Lang:t("menu.enabled") or Lang:t("menu.disabled")),
			event = "matti-airsoft:toggleLms",
			args = { enabled = not lmsEnabled },
			icon = "fas fa-skull",
			iconColor = lmsEnabled and "#e74c3c" or "#95a5a6",
		})

		local currentLoadoutText = State.currentLobby.selectedLoadout and State.currentLobby.selectedLoadout.name
			or Lang:t("menu.no_loadout")
		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.select_lobby_loadout"),
			description = Lang:t("menu.current_loadout") .. ": " .. currentLoadoutText,
			event = "matti-airsoft:selectLobbyLoadout",
			icon = "fas fa-crosshairs",
			iconColor = "#e74c3c",
		})

		if Config.MatchTimerEnabled then
			local timerText = math.floor(State.currentLobby.matchTimer / 60) .. " " .. Lang:t("menu.minutes")
			Menu.AddOption(managementMenu, {
				title = Lang:t("menu.match_timer"),
				description = Lang:t("menu.current_timer") .. ": " .. timerText,
				event = "matti-airsoft:openMatchTimerInput",
				icon = "fas fa-clock",
				iconColor = "#f39c12",
			})
		end

		local scoreLimit = State.currentLobby.scoreLimit or Config.DefaultScoreLimit or 0
		local scoreLimitText = scoreLimit > 0 and (scoreLimit .. " " .. Lang:t("menu.kills")) or Lang:t("notifications.score_limit_disabled")
		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.score_limit"),
			description = Lang:t("menu.current_score_limit") .. ": " .. scoreLimitText,
			event = "matti-airsoft:openScoreLimitInput",
			icon = "fas fa-bullseye",
			iconColor = "#e74c3c",
		})

		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.start_game"),
			description = Lang:t("menu.start_game_desc"),
			event = "matti-airsoft:startLobbyGame",
			icon = "fas fa-play",
			iconColor = "#2ecc71",
		})
	else
		local currentModeText = GetModeLabel(State.currentLobby.gameMode)
		local currentLoadoutText = State.currentLobby.selectedLoadout and State.currentLobby.selectedLoadout.name
			or Lang:t("menu.no_loadout")

		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.lobby_settings"),
			description = Lang:t("menu.game_mode")
				.. ": "
				.. currentModeText
				.. "\n"
				.. Lang:t("menu.loadout")
				.. ": "
				.. currentLoadoutText,
			icon = "fas fa-info-circle",
			iconColor = "#95a5a6",
			disabled = true,
		})
	end

	if IsTeamBasedMode(State.currentLobby.gameMode) then
		Menu.AddOption(managementMenu, {
			title = Lang:t("menu.select_team"),
			description = Lang:t("menu.select_team_desc"),
			event = "matti-airsoft:selectTeam",
			icon = "fas fa-users",
			iconColor = "#9b59b6",
		})
	end

	Menu.AddOption(managementMenu, {
		title = Lang:t("menu.leave_lobby"),
		description = Lang:t("menu.leave_lobby_desc"),
		event = "matti-airsoft:confirmLeaveLobby",
		icon = "fas fa-door-open",
		iconColor = "#e74c3c",
	})

	Menu.Open("matti_airsoft_lobby_management", State.currentLobby.name, managementMenu)
end)

RegisterNetEvent("matti-airsoft:confirmLeaveLobby")
AddEventHandler("matti-airsoft:confirmLeaveLobby", function()
	TriggerServerEvent("matti-airsoft:leaveLobby")
end)

RegisterNetEvent("matti-airsoft:selectGameMode")
AddEventHandler("matti-airsoft:selectGameMode", function()
	local gameModeMenu = {}
	local modes = SharedUtils.GetConfiguredGameModes()

	for _, modeId in ipairs(SharedUtils.GetOrderedModeIds()) do
		local modeConfig = modes[modeId]
		if modeConfig then
			Menu.AddOption(gameModeMenu, {
				title = Lang:t(modeConfig.label),
				description = Lang:t(modeConfig.description),
				event = "matti-airsoft:setGameMode",
				args = { mode = modeId },
				icon = modeConfig.icon,
				iconColor = modeConfig.iconColor,
			})
		end
	end

	Menu.AddOption(gameModeMenu, {
		title = Lang:t("menu.back"),
		event = "matti-airsoft:openLobbyManagement",
		icon = "fas fa-arrow-left",
		iconColor = "#95a5a6",
	})

	Menu.Open(
		"matti_airsoft_gamemode_menu",
		Lang:t("menu.select_game_mode"),
		gameModeMenu,
		"matti_airsoft_lobby_management"
	)
end)

RegisterNetEvent("matti-airsoft:setGameMode", function(data)
	TriggerServerEvent("matti-airsoft:setGameMode", data.mode)
	Utils.SendNotification(Lang:t("notifications.game_mode_set") .. " " .. GetModeLabel(data.mode), "success")
	Wait(500)
	TriggerEvent("matti-airsoft:openLobbyManagement")
end)

RegisterNetEvent("matti-airsoft:toggleLms", function(data)
	local enabled = data and data.enabled == true
	TriggerServerEvent("matti-airsoft:setLmsEnabled", enabled)
	Utils.SendNotification(
		enabled and Lang:t("notifications.lms_enabled") or Lang:t("notifications.lms_disabled"),
		"success"
	)
	Wait(500)
	TriggerEvent("matti-airsoft:openLobbyManagement")
end)

RegisterNetEvent("matti-airsoft:selectLobbyLoadout")
AddEventHandler("matti-airsoft:selectLobbyLoadout", function()
	local loadoutMenu = {}

	Menu.AppendLoadoutOptions(loadoutMenu, "matti-airsoft:setLobbyLoadout")

	Menu.AddOption(loadoutMenu, {
		title = Lang:t("menu.random_loadout"),
		description = Lang:t("menu.random_loadout_txt"),
		event = "matti-airsoft:setRandomLobbyLoadout",
		icon = "fas fa-random",
		iconColor = "#EC213A",
	})

	Menu.AddOption(loadoutMenu, {
		title = Lang:t("menu.back"),
		event = "matti-airsoft:openLobbyManagement",
		icon = "fas fa-arrow-left",
		iconColor = "#95a5a6",
	})

	Menu.Open(
		"matti_airsoft_lobby_loadout_menu",
		Lang:t("menu.select_lobby_loadout"),
		loadoutMenu,
		"matti_airsoft_lobby_management"
	)
end)

RegisterNetEvent("matti-airsoft:setLobbyLoadout", function(data)
	TriggerServerEvent("matti-airsoft:setLobbyLoadout", data.loadout)
	Utils.SendNotification(Lang:t("notifications.lobby_loadout_set") .. " " .. data.loadout.name, "success")
	Wait(500)
	TriggerEvent("matti-airsoft:openLobbyManagement")
end)

RegisterNetEvent("matti-airsoft:setRandomLobbyLoadout", function()
	local randomIndex = math.random(1, #Config.Loadouts)
	local randomLoadout = Config.Loadouts[randomIndex]
	TriggerServerEvent("matti-airsoft:setLobbyLoadout", randomLoadout)
	Utils.SendNotification(Lang:t("notifications.lobby_loadout_set") .. " " .. randomLoadout.name, "success")
	Wait(500)
	TriggerEvent("matti-airsoft:openLobbyManagement")
end)

RegisterNetEvent("matti-airsoft:openMatchTimerInput")
AddEventHandler("matti-airsoft:openMatchTimerInput", function()
	local inputValue = Menu.ShowSingleInput({
		title = Lang:t("menu.select_match_timer"),
		submitText = Lang:t("menu.set"),
		label = Lang:t("menu.timer_input_label"),
		placeholder = "5",
		type = "number",
		min = 1,
		max = Config.MaxMatchDurationMinutes,
		required = true,
	})

	if not inputValue then
		return
	end

	local minutes = tonumber(inputValue)
	if minutes and minutes >= 1 and minutes <= Config.MaxMatchDurationMinutes then
		TriggerServerEvent("matti-airsoft:setMatchTimer", minutes)
		Utils.SendNotification(
			Lang:t("notifications.match_timer_set") .. " " .. minutes .. " " .. Lang:t("menu.minutes"),
			"success"
		)
		Wait(500)
		TriggerEvent("matti-airsoft:openLobbyManagement")
	else
		Utils.SendNotification(
			Lang:t("notifications.invalid_timer") .. " (1-" .. Config.MaxMatchDurationMinutes .. ")",
			"error"
		)
	end
end)

RegisterNetEvent("matti-airsoft:openScoreLimitInput")
AddEventHandler("matti-airsoft:openScoreLimitInput", function()
	local inputValue = Menu.ShowSingleInput({
		title = Lang:t("menu.select_score_limit"),
		submitText = Lang:t("menu.set"),
		label = Lang:t("menu.score_limit_input_label"),
		placeholder = tostring(Config.DefaultScoreLimit or 15),
		type = "number",
		min = 0,
		max = 100,
		required = true,
	})

	if inputValue == nil then
		return
	end

	local limit = tonumber(inputValue)
	if limit == nil or limit < 0 or limit > 100 then
		Utils.SendNotification(Lang:t("notifications.invalid_score_limit"), "error")
		return
	end

	TriggerServerEvent("matti-airsoft:setScoreLimit", limit)
	Wait(500)
	TriggerEvent("matti-airsoft:openLobbyManagement")
end)

RegisterNetEvent("matti-airsoft:startLobbyGame", function()
	if State.currentLobby and IsTeamBasedMode(State.currentLobby.gameMode) then
		Framework.TriggerCallback("matti-airsoft:getPlayerTeam", function(team)
			if not team then
				TriggerEvent("matti-airsoft:selectTeam")
			else
				TriggerServerEvent("matti-airsoft:startLobbyGame")
			end
		end)
	else
		TriggerServerEvent("matti-airsoft:startLobbyGame")
	end
end)

RegisterNetEvent("matti-airsoft:selectTeam")
AddEventHandler("matti-airsoft:selectTeam", function()
	Framework.TriggerCallback("matti-airsoft:getLobbyTeams", function(teamState)
		Menu.Open(
			"matti_airsoft_team_menu",
			Lang:t("menu.select_team"),
			Menu.BuildTeamSelectionMenu("matti-airsoft:confirmTeamSelection", teamState)
		)
	end)
end)

RegisterNetEvent("matti-airsoft:confirmTeamSelection", function(data)
	TriggerServerEvent("matti-airsoft:setPlayerTeam", data.team)
	Utils.SendNotification(
		Lang:t("notifications.team_selected")
			.. " "
			.. (data.team == "team1" and Lang:t("menu.team1") or Lang:t("menu.team2")),
		"success"
	)
end)

RegisterNetEvent("matti-airsoft:gameStarting", function(loadout, gameMode, shouldRespawn, scoreLimit)
	if not loadout then
		Utils.SendNotification(Lang:t("notifications.select_loadout_first"), "error")
		return
	end

	State.shouldRespawn = shouldRespawn == true
	State.shouldEnterSpectator = not State.shouldRespawn
	State.scoreLimit = tonumber(scoreLimit) or 0

	if State.currentLobby then
		State.currentLobby.gameMode = gameMode
		State.currentLobby.lmsEnabled = not State.shouldRespawn
		State.currentLobby.scoreLimit = State.scoreLimit
	end

	CreateThread(function()
		if IsTeamBasedMode(gameMode) then
			local team = Framework.AwaitCallback("matti-airsoft:getPlayerTeam")
			if not team then
				TriggerEvent("matti-airsoft:selectTeamBeforePlay")
				return
			end
		end

		Loadout.Handle(loadout)
	end)
end)

RegisterNetEvent("matti-airsoft:selectTeamBeforePlay")
AddEventHandler("matti-airsoft:selectTeamBeforePlay", function()
	Framework.TriggerCallback("matti-airsoft:getLobbyTeams", function(teamState)
		Menu.Open(
			"matti_airsoft_team_select_play",
			Lang:t("menu.select_team"),
			Menu.BuildTeamSelectionMenu("matti-airsoft:confirmTeamBeforePlay", teamState)
		)
	end)
end)

RegisterNetEvent("matti-airsoft:confirmTeamBeforePlay", function(data)
	TriggerServerEvent("matti-airsoft:setPlayerTeam", data.team)
	Utils.SendNotification(
		Lang:t("notifications.team_selected")
			.. " "
			.. (data.team == "team1" and Lang:t("menu.team1") or Lang:t("menu.team2")),
		"success"
	)
	Wait(500)
	if State.currentLobby and State.currentLobby.selectedLoadout then
		local selectedLoadout = State.currentLobby.selectedLoadout
		CreateThread(function()
			Loadout.Handle(selectedLoadout)
		end)
	end
end)

RegisterNetEvent("matti-airsoft:client:removeWeaponFromPed", function(weaponName)
	local weaponHash = GetHashKey(weaponName)
	if weaponHash and weaponHash ~= 0 and HasPedGotWeapon(PlayerPedId(), weaponHash, false) then
		RemoveWeaponFromPed(PlayerPedId(), weaponHash)
	end
end)

local function HandleArenaExitCleanup()
	Player.Revive()

	if State.isSpectating then
		State.isSpectating = false
		local playerPed = PlayerPedId()
		ResetEntityAlpha(playerPed)
		SetEntityInvincible(playerPed, false)
		SetPedCanRagdoll(playerPed, true)
	end

	if State.isInArena then
		TriggerServerEvent("matti-airsoft:playerLeftArena")
		State.isInArena = false
	end

	TriggerServerEvent("matti-airsoft:exitMatch")

	State.leaderboardVisible = false
	State.shouldRespawn = nil
	State.shouldEnterSpectator = nil
	State.spawnProtectedUntil = nil

	SendNUIMessage({
		action = "clearArenaHud",
	})

	if Config.LeaderboardEnabled then
		Leaderboard.ShowFinalOnExit(State.cachedMatchRecap)
	end

	State.isHit = false
end

RegisterNetEvent("matti-airsoft:exitArena", function()
	HandleArenaExitCleanup()
	Loadout.Remove()
	Inventory.Restore()
	SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
end)

RegisterNetEvent("matti-airsoft:checkIfInArena", function(adminId)
	local isInArena = State.isInArena
	TriggerServerEvent("matti-airsoft:reportArenaStatus", adminId, isInArena)
end)

RegisterNetEvent("matti-airsoft:forceExitArena", function()
	HandleArenaExitCleanup()
	Loadout.Remove()
	Inventory.Restore()
	SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
	Utils.SendNotification(Lang:t("notifications.force_exit"), "error")
end)

RegisterNetEvent("matti-airsoft:updateMatchHud", function(payload)
	if not payload or not State.isInArena or not Config.LeaderboardEnabled then
		return
	end

	if payload.rows then
		Leaderboard.SetCachedRows(payload.rows)
		if State.leaderboardVisible then
			SendNUIMessage({
				action = "updateLeaderboard",
				leaderboard = payload.rows,
			})
		end
	end

	SendNUIMessage({
		action = "updateMatchHud",
		mode = payload.mode,
		timer = payload.timer,
		scoreLimit = payload.scoreLimit,
	})
end)

RegisterNetEvent("matti-airsoft:updateLeaderboard", function(leaderboard)
	Leaderboard.SetCachedRows(leaderboard)

	if State.leaderboardVisible and State.isInArena then
		SendNUIMessage({
			action = "updateLeaderboard",
			leaderboard = leaderboard,
		})
	end
end)

RegisterNetEvent("matti-airsoft:showKillFeed", function(killerName, victimName)
	Leaderboard.ApplyUiTheme()
	SendNUIMessage({
		action = "showKillFeed",
		killer = killerName,
		victim = victimName,
	})
end)

RegisterNUICallback("closeLeaderboard", function(_, cb)
	cb("ok")
end)

RegisterNUICallback("closeFinalScoreboard", function(_, cb)
	Leaderboard.HideFinalOnExit()
	cb("ok")
end)

-- Match Timer Events
RegisterNetEvent("matti-airsoft:updateTimer", function(secondsRemaining)
	if State.isInArena and Config.LeaderboardEnabled then
		SendNUIMessage({
			action = "updateTimer",
			secondsRemaining = secondsRemaining,
		})
	end
end)

RegisterNetEvent("matti-airsoft:matchTimeExpired", function()
	Utils.SendNotification(Lang:t("notifications.match_time_expired"), "info")
	if Config.LeaderboardEnabled then
		SendNUIMessage({
			action = "timerExpired",
		})
	end
end)

RegisterNetEvent("matti-airsoft:matchEndedElimination", function()
	Utils.SendNotification(Lang:t("notifications.match_ended_elimination"), "info")
end)

RegisterNetEvent("matti-airsoft:matchEnded", function(recap)
	State.cachedMatchRecap = recap

	if recap and recap.rows then
		Leaderboard.SetCachedRows(recap.rows)
	end

	if Config.LeaderboardEnabled then
		SendNUIMessage({
			action = "timerExpired",
		})
	end

	local shouldExit = State.isInArena or State.isSpectating

	Player.Revive()
	Wait(2500)
	Player.Revive()

	if shouldExit then
		HandleArenaExitCleanup()
		Loadout.Remove()
		Inventory.Restore()
		SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
		Player.Revive()
	elseif recap and Config.ShowFinalScoreboardOnExit then
		Leaderboard.ShowFinalOnExit(recap)
	end
end)
