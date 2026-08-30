ArenaBoard = {}

local BOARD_RADIUS = 30.0
local enterCoords = vector3(Config.EnterLocation.coords.x, Config.EnterLocation.coords.y, Config.EnterLocation.coords.z)

local function GetModeLabel(modeId)
	local modeConfig = SharedUtils.GetConfiguredGameModes()[SharedUtils.NormalizeModeId(modeId) or ""]
	if modeConfig and modeConfig.label then
		return Lang:t(modeConfig.label)
	end
	return modeId or Lang:t("leaderboard.ffa")
end

function ArenaBoard.IsNearEnter()
	local playerCoords = GetEntityCoords(PlayerPedId())
	return #(playerCoords - enterCoords) <= BOARD_RADIUS
end

function ArenaBoard.Update(payload)
	if State.isInArena or State.isSpectating then
		SendNUIMessage({ action = "hideArenaBoard" })
		return
	end

	if not payload or not ArenaBoard.IsNearEnter() then
		SendNUIMessage({ action = "hideArenaBoard" })
		return
	end

	SendNUIMessage({
		action = "showArenaBoard",
		mode = GetModeLabel(payload.mode),
		timer = payload.timer,
		scoreLimit = payload.scoreLimit,
		leaderboard = payload.rows or {},
	})
end

function ArenaBoard.StartProximityLoop()
	CreateThread(function()
		while true do
			Wait(750)

			if State.isInArena or State.isSpectating then
				SendNUIMessage({ action = "hideArenaBoard" })
			elseif State.arenaBoardPayload and ArenaBoard.IsNearEnter() then
				ArenaBoard.Update(State.arenaBoardPayload)
			else
				SendNUIMessage({ action = "hideArenaBoard" })
			end
		end
	end)
end

RegisterNetEvent("matti-airsoft:updateArenaBoard", function(payload)
	State.arenaBoardPayload = payload

	if State.isInArena or State.isSpectating then
		SendNUIMessage({ action = "hideArenaBoard" })
		return
	end

	ArenaBoard.Update(payload)
end)
