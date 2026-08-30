Spectator = {}

local SPECTATOR_MOVE_SPEED = 0.35
local SPECTATOR_VERTICAL_SPEED = 0.25
local LEAVE_CONTROL = 38

function Spectator.IsActive()
	return State.isSpectating == true
end

function Spectator.Enter()
	if State.isSpectating then
		return
	end

	State.isSpectating = true
	State.isHit = false

	local playerPed = PlayerPedId()
	SetEntityInvincible(playerPed, true)
	SetEntityAlpha(playerPed, 170, false)
	SetPedCanRagdoll(playerPed, false)
	RemoveAllPedWeapons(playerPed, true)
	SetCurrentPedWeapon(playerPed, joaat("WEAPON_UNARMED"), true)

	Utils.SendNotification(Lang:t("spectator.entered"), "info")

	CreateThread(function()
		while State.isSpectating do
			Wait(0)

			DisablePlayerFiring(PlayerId(), true)
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 47, true)
			DisableControlAction(0, 58, true)
			DisableControlAction(0, 140, true)
			DisableControlAction(0, 141, true)
			DisableControlAction(0, 142, true)
			DisableControlAction(0, 143, true)
			DisableControlAction(0, 257, true)
			DisableControlAction(0, 263, true)
			DisableControlAction(0, 264, true)

			if IsControlJustReleased(0, LEAVE_CONTROL) then
				Spectator.Leave()
				break
			end

			local ped = PlayerPedId()
			local coords = GetEntityCoords(ped)
			local heading = GetGameplayCamRot(2).z
			local forward = vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0)
			local right = vector3(forward.y, -forward.x, 0.0)
			local movement = vector3(0.0, 0.0, 0.0)

			if IsControlPressed(0, 32) then
				movement = movement + forward
			end
			if IsControlPressed(0, 33) then
				movement = movement - forward
			end
			if IsControlPressed(0, 34) then
				movement = movement - right
			end
			if IsControlPressed(0, 35) then
				movement = movement + right
			end
			if IsControlPressed(0, 22) then
				movement = movement + vector3(0.0, 0.0, SPECTATOR_VERTICAL_SPEED)
			end
			if IsControlPressed(0, 36) then
				movement = movement - vector3(0.0, 0.0, SPECTATOR_VERTICAL_SPEED)
			end

			if movement.x ~= 0.0 or movement.y ~= 0.0 or movement.z ~= 0.0 then
				local nextCoords = coords + (movement * SPECTATOR_MOVE_SPEED)
				if SharedUtils.IsCoordsInArena(nextCoords) then
					SetEntityCoordsNoOffset(ped, nextCoords.x, nextCoords.y, nextCoords.z, false, false, false)
				end
			end
		end
	end)
end

function Spectator.Leave()
	if not State.isSpectating then
		return
	end

	State.isSpectating = false

	local playerPed = PlayerPedId()
	ResetEntityAlpha(playerPed)
	SetEntityInvincible(playerPed, false)
	SetPedCanRagdoll(playerPed, true)

	TriggerEvent("matti-airsoft:exitArena")
end

RegisterNetEvent("matti-airsoft:spectatorStateChanged", function(spectating)
	if spectating then
		Spectator.Enter()
	else
		State.isSpectating = false
		local playerPed = PlayerPedId()
		ResetEntityAlpha(playerPed)
		SetEntityInvincible(playerPed, false)
		SetPedCanRagdoll(playerPed, true)
	end
end)

RegisterNetEvent("matti-airsoft:spawnProtection", function(seconds)
	local durationMs = (tonumber(seconds) or 0) * 1000
	if durationMs <= 0 then
		return
	end

	State.spawnProtectedUntil = GetGameTimer() + durationMs

	CreateThread(function()
		local playerPed = PlayerPedId()
		local endTime = State.spawnProtectedUntil

		while GetGameTimer() < endTime and State.isInArena and not State.isSpectating do
			SetEntityAlpha(playerPed, 120, false)
			Wait(120)
			if GetGameTimer() < endTime then
				SetEntityAlpha(playerPed, 255, false)
				Wait(120)
			end
		end

		if not State.isSpectating then
			ResetEntityAlpha(playerPed)
		end

		if State.spawnProtectedUntil and GetGameTimer() >= State.spawnProtectedUntil then
			State.spawnProtectedUntil = nil
		end
	end)
end)
