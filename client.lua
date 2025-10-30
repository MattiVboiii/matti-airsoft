local QBCore = exports['qb-core']:GetCoreObject()
local isHit = false
local airsoftZone, currentLoadout = nil, nil
local enterPed, exitPed -- Variables for interaction peds
local debugPeds = {} -- Table to store debug peds
local originalInventory = {} -- Store the player's original inventory
local leaderboardVisible = false -- Track leaderboard visibility
local isInArena = false -- Track if player is in the arena

-- Function to get the player's full name
local function GetPlayerName()
	local player = QBCore.Functions.GetPlayerData()
	return player.charinfo.firstname .. ' ' .. player.charinfo.lastname
end

-- Client-side function to remove weapon from player ped
RegisterNetEvent('matti-airsoft:client:removeWeaponFromPed')
AddEventHandler('matti-airsoft:client:removeWeaponFromPed', function(weaponName)
	local weaponHash = GetHashKey(weaponName)
	if weaponHash and weaponHash ~= 0 and HasPedGotWeapon(PlayerPedId(), weaponHash, false) then
		RemoveWeaponFromPed(PlayerPedId(), weaponHash)
	end
end)

-- Function to handle notifications
local function SendNotification(message, type)
	-- Check if the notification system is qb-core
	if Config.NotifySystem == 'qb-core' then
		-- If using qb-core, simply call the notify function
		QBCore.Functions.Notify(message, type)
	-- Check if the notification system is ox_lib
	elseif Config.NotifySystem == 'ox_lib' then
		-- If using ox_lib, create a notification style table
		local notificationStyle = {}
		local icon = 'info-circle'
		local iconColor = '#FFFFFF'

		-- Set different notification styles based on the type
		if type == 'success' then
			-- Green notification style
			notificationStyle = { color = '#28A745', ['.description'] = { color = '#E9ECEF' } }
			icon = 'check-circle'
			textColor = '#28A745'
		elseif type == 'error' then
			-- Red notification style
			notificationStyle = { color = '#DC3545', ['.description'] = { color = '#E9ECEF' } }
			icon = 'times-circle'
			textColor = '#DC3545'
		else
			-- Yellow notification style
			notificationStyle = { color = '#F08080', ['.description'] = { color = '#909296' } }
			icon = 'info-circle'
			textColor = '#F08080'
		end

		-- Call ox_lib's notify function with the notification style and message
		lib.notify({
			title = message,
			style = notificationStyle,
			icon = icon,
			iconColor = textColor,
		})
	else
		-- If no supported notification system is found, print a warning message
		print('No supported notification system found: ' .. Config.NotifySystem)
	end
end

RegisterNetEvent('matti-airsoft:sendNotification')
AddEventHandler('matti-airsoft:sendNotification', function(message, type)
	SendNotification(message, type)
end)

-- Function to save the player's inventory and clear it
local function SaveAndClearInventory()
	local playerData = QBCore.Functions.GetPlayerData()
	local playerItems = playerData.items or {}

	if Config.InventorySystem == 'qb-inventory' then
		-- Use qb-inventory functions to manage inventory
		for _, item in pairs(playerItems) do
			TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
		end
	elseif Config.InventorySystem == 'ox_inventory' then
		-- Use ox_inventory functions to manage inventory
		for _, item in pairs(exports.ox_inventory:GetPlayerItems()) do
			TriggerServerEvent('matti-airsoft:removeItem', item.name, item.count)
		end
	else
		print('No supported inventory found: ' .. Config.InventorySystem)
	end

	-- Save the player's inventory
	originalInventory = table.clone(playerItems)
end

-- Function to restore the player's inventory
local function RestoreInventory()
	for _, item in pairs(originalInventory) do
		local itemAmount = item.amount or item.count
		TriggerServerEvent('matti-airsoft:giveItem', item.name, itemAmount)
	end
	originalInventory = {}
end

-- Function to teleport player to a random spawn location
local function TeleportToRandomPosition()
	local randomCoord = Config.SpawnLocations[math.random(1, #Config.SpawnLocations)]
	SetEntityCoords(PlayerPedId(), randomCoord)
end

-- Function to spawn a ped with given parameters
local function SpawnPed(modelHash, coords, event, icon, label)
	-- Request the model and wait until it's loaded
	RequestModel(modelHash)
	while not HasModelLoaded(modelHash) do
		Wait(100)
	end

	-- Create the ped at the specified coordinates and set its properties
	local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
	FreezeEntityPosition(ped, true) -- Make the ped immovable
	SetEntityInvincible(ped, true) -- Make the ped invincible
	SetBlockingOfNonTemporaryEvents(ped, true) -- Prevent the ped from reacting to events

	-- Configure interaction with the ped based on the target system
	if Config.TargetSystem == 'qb-target' then
		-- Use qb-target system to add interaction options
		exports['qb-target']:AddTargetEntity(ped, {
			options = {
				{
					type = 'client',
					event = event,
					icon = icon,
					label = label,
				},
			},
			distance = 2.5, -- Interaction distance
		})
	elseif Config.TargetSystem == 'ox_target' then
		-- Use ox_target system to add interaction options
		exports.ox_target:addLocalEntity(ped, {
			{
				name = 'airsoft_menu',
				label = label,
				onSelect = function()
					TriggerEvent(event) -- Trigger the event when selected
				end,
				icon = icon,
				distance = 2.5, -- Interaction distance
			},
		})
	else
		print('No supported target system found: ' .. Config.TargetSystem)
	end

	return ped -- Return the created ped
end

-- Function to create airsoft blip
local function CreateAirsoftBlip()
	if Config.AirsoftBlip.enabled then
		local blip = AddBlipForCoord(Config.AirsoftBlip.coords)
		SetBlipSprite(blip, Config.AirsoftBlip.sprite)
		SetBlipDisplay(blip, 4)
		SetBlipScale(blip, Config.AirsoftBlip.scale)
		SetBlipColour(blip, Config.AirsoftBlip.color)
		SetBlipAsShortRange(blip, false)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentString(Config.AirsoftBlip.name)
		EndTextCommandSetBlipName(blip)
	end
end

-- Function to handle loadout selection
local function HandleLoadoutSelection(loadout)
	-- Check if player can afford the loadout
	QBCore.Functions.TriggerCallback('matti-airsoft:canAffordLoadout', function(canAfford)
		if canAfford then
			-- If player can afford the loadout, clear their current inventory and set the new loadout
			SaveAndClearInventory()

			-- Loop through the weapons in the loadout and give them to the player
			for _, weapon in ipairs(loadout.weapons) do
				TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
			end

			-- Loop through the ammo in the loadout and give it to the player
			for _, ammo in ipairs(loadout.ammo) do
				TriggerServerEvent('matti-airsoft:giveItem', ammo.name, ammo.amount)
			end

			-- Set the player's current weapon to unarmed
			SetCurrentPedWeapon(PlayerPedId(), GetHashKey('WEAPON_UNARMED'), true)

			-- Set the player's current loadout
			currentLoadout = loadout

			-- Send the player a notification that they have selected the loadout
			SendNotification('You have selected the "' .. loadout.name .. '" loadout!', 'success')

			-- Teleport the player to a random spawn location
			TeleportToRandomPosition()
		else
			-- If the player can't afford the loadout, send them a notification
			SendNotification(Lang:t('notifications.cannot_afford'), 'error')
		end
	end, loadout.price)
end

-- Function to check hit status
local function CheckHitStatus()
	Citizen.CreateThread(function()
		while airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) do
			Wait(100)
			local playerPed = PlayerPedId()

			if IsPedBeingStunned(playerPed, 0) or IsEntityDead(playerPed) then
				-- Player was hit or killed, set isHit to true
				if not isHit then
					isHit = true
					
					-- Detect who killed the player
					local killerId = nil
					local killerPed = GetPedSourceOfDeath(playerPed)
					
					if killerPed and killerPed ~= 0 and killerPed ~= playerPed then
						-- Check if killer is a player
						if IsPedAPlayer(killerPed) then
							local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
							if killerPlayerId and killerPlayerId ~= -1 then
								killerId = GetPlayerServerId(killerPlayerId)
							end
						end
					end
					
					-- Debug logging
					if Config.Debug then
						print('[AIRSOFT DEBUG] Player was hit. Killer server ID: ' .. tostring(killerId))
					end
					
					-- Notify server about the hit
					TriggerServerEvent('matti-airsoft:playerWasHit', killerId)
					
					if Config.TeleportOnHit then
						if Config.ContinuePlayingAfterDeath then
							-- Respawn in arena at random location
							SendNotification(Lang:t('inarena.shot'))
							Wait(2000)
							TeleportToRandomPosition()
						else
							-- Teleport to the return location (exit arena)
							SendNotification(Lang:t('inarena.shotandout'))
							SetEntityCoords(playerPed, Config.ReturnLocation)
						end
					else
						-- Send the player a notification that they were hit
						SendNotification(Lang:t('inarena.shot'))
					end

					-- If the player is dead, wait for a short delay then revive them
					if IsEntityDead(playerPed) then
						Wait(3000) -- Small delay to ensure the player is "isDead" before reviving
						TriggerServerEvent('matti-airsoft:revivePlayer', PlayerId())
					end
				end
			else
				-- Player is no longer hit or dead, set isHit to false
				isHit = false
			end
		end
	end)
end

-- Function to handle entering or exiting airsoft zone
local function HandleZoneEntry(isPointInside)
	-- Check if the player is inside the zone
	if isPointInside then
		isInArena = true
		-- Notify the player about zone entry
		SendNotification(Lang:t('notifications.entered'), 'success')
		-- Trigger debug event if debugging is enabled
		if Config.Debug then
			TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'entered')
		end
		-- Notify server that player entered arena
		TriggerServerEvent('matti-airsoft:playerEnteredArena')
		-- Show leaderboard automatically
		if Config.LeaderboardEnabled then
			ShowLeaderboard()
		end
		-- Start checking the hit status
		CheckHitStatus()
	else
		isInArena = false
		-- Hide leaderboard when exiting
		if Config.LeaderboardEnabled then
			HideLeaderboard()
		end
		-- Notify the player about zone exit
		SendNotification(Lang:t('notifications.exited'), 'error')
		-- Trigger debug event if debugging is enabled
		if Config.Debug then
			TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'exited')
		end
		-- Notify server that player left arena
		TriggerServerEvent('matti-airsoft:playerLeftArena')
		-- Remove loadout and restore inventory on exit
		RemoveLoadout()
		RestoreInventory()
		-- Reset hit status
		isHit = false
	end
end

-- Create the airsoft zone based on configuration
Citizen.CreateThread(function()
	if Config.ZoneType == 'circle' then
		-- Create a circular zone with the configured radius and coordinates
		airsoftZone = CircleZone:Create(Config.AirsoftZone.coordinates, Config.AirsoftZone.radius, {
			debugPoly = Config.Debug,
		})
	elseif Config.ZoneType == 'poly' then
		-- Create a polygonal zone with the configured points
		airsoftZone = PolyZone:Create(Config.AirsoftZone.points, {
			debugPoly = Config.Debug,
		})
	else
		print('No supported zone type found.')
	end
	-- Call the HandleZoneEntry function when the player enters or exits the zone
	airsoftZone:onPlayerInOut(HandleZoneEntry)

	-- Spawn a ped to handle loadout selection
	enterPed = SpawnPed(
		GetHashKey(Config.EnterLocation.model),
		Config.EnterLocation.coords,
		'matti-airsoft:openLoadoutMenu',
		'fas fa-crosshairs',
		Lang:t('menu.choose_loadout')
	)

	-- Spawn a ped to handle exiting the arena
	exitPed = SpawnPed(
		GetHashKey(Config.ExitLocation.model),
		Config.ExitLocation.coords,
		'matti-airsoft:exitArena',
		'fas fa-door-open',
		Lang:t('menu.exit_arena')
	)

	-- Add a blip to the map to mark the location of the airsoft zone
	CreateAirsoftBlip()

	-- Spawn some debug peds if debugging is enabled
	if Config.Debug then
		for _, loc in ipairs(Config.SpawnLocations) do
			-- Create a ped at each spawn location
			local ped =
				CreatePed(4, GetHashKey(Config.EnterLocation.model), loc.x, loc.y, loc.z - 1.0, 0.0, false, true)
			-- Make the ped invisible and immovable
			SetEntityAlpha(ped, 100, false)
			FreezeEntityPosition(ped, true)
			SetEntityInvincible(ped, true)
			SetBlockingOfNonTemporaryEvents(ped, true)
			-- Add the ped to the list of debug peds
			table.insert(debugPeds, ped)
		end
	end
end)

-- Register event to open the loadout menu
RegisterNetEvent('matti-airsoft:openLoadoutMenu')
AddEventHandler('matti-airsoft:openLoadoutMenu', function()
	-- Create a table to store the loadout menu items
	local loadoutMenu = {}

	-- Loop through each loadout and add it to the menu
	for i, loadout in ipairs(Config.Loadouts) do
		local weaponsList, ammoList = '', ''
		for _, weapon in ipairs(loadout.weapons) do
			-- Add each weapon to the list of weapons
			weaponsList = weaponsList .. weapon.label .. '\n'
		end
		for _, ammo in ipairs(loadout.ammo) do
			-- Add each ammo item to the list of ammo
			ammoList = ammoList .. ' (' .. ammo.amount .. ' clips)\n'
		end

		-- Add the loadout to the menu
		if Config.MenuSystem == 'qb-menu' then
			-- Add the loadout to the QBCore menu system
			table.insert(loadoutMenu, {
				header = loadout.name .. ' - $' .. loadout.price,
				txt = Lang:t('menu.includes') .. '\n' .. weaponsList .. ammoList,
				icon = 'fas fa-crosshairs',
				params = {
					event = 'matti-airsoft:selectLoadout',
					args = { loadout = loadout },
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			-- Add the loadout to the ox_lib menu system
			table.insert(loadoutMenu, {
				title = loadout.name .. ' - $' .. loadout.price,
				description = Lang:t('menu.includes') .. '\n' .. weaponsList .. ammoList,
				event = 'matti-airsoft:selectLoadout',
				args = { loadout = loadout },
				icon = 'fas fa-crosshairs',
				iconColor = '#EC213A',
			})
		end
	end

	-- Own loadout option (use at your own risk, can be exploited, did not find a fix yet)
	--[[ if Config.MenuSystem == "ox_lib" then
		table.insert(loadoutMenu, {
			title = Lang:t("menu.own_loadout"),
			description = Lang:t("menu.own_loadout_txt"),
			event = "matti-airsoft:teleportOnly",
			icon = "fas fa-box",
			iconColor = "#33A532",
		})
	else
		table.insert(loadoutMenu, {
			header = Lang:t("menu.own_loadout"),
			txt = Lang:t("menu.own_loadout_txt"),
			icon = "fas fa-box",
			params = { event = "matti-airsoft:teleportOnly" },
		})
	end ]]

	-- Random loadout option
	-- Add random loadout option to the menu
	if Config.MenuSystem == 'qb-menu' then
		table.insert(loadoutMenu, {
			header = Lang:t('menu.random_loadout'),
			txt = Lang:t('menu.random_loadout_txt'),
			icon = 'fas fa-random',
			params = { event = 'matti-airsoft:giveRandomGun' },
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(loadoutMenu, {
			title = Lang:t('menu.random_loadout'),
			description = Lang:t('menu.random_loadout_txt'),
			event = 'matti-airsoft:giveRandomGun',
			icon = 'fas fa-random',
			iconColor = '#EC213A',
		})
	end

	-- Open the loadout menu based on the configured menu system
	if Config.MenuSystem == 'qb-menu' then
		exports['qb-menu']:openMenu(loadoutMenu)
	elseif Config.MenuSystem == 'ox_lib' then
		lib.registerContext({
			id = 'matti_airsoft_loadout_menu',
			title = Lang:t('menu.choose_loadout'),
			options = loadoutMenu,
		})
		lib.showContext('matti_airsoft_loadout_menu')
	else
		print('No supported menu system found: ' .. Config.MenuSystem)
	end
end)

-- Event to teleport player to a random position without a loadout
RegisterNetEvent('matti-airsoft:teleportOnly')
AddEventHandler('matti-airsoft:teleportOnly', function()
	-- Teleport player to a random spawn location
	TeleportToRandomPosition()
	-- Set current loadout to noLoadout
	currentLoadout = noLoadout
end)

-- Event to give player a random loadout
RegisterNetEvent('matti-airsoft:giveRandomGun')
AddEventHandler('matti-airsoft:giveRandomGun', function()
	-- Select a random loadout from the configuration
	local randomIndex = math.random(1, #Config.Loadouts)
	-- Handle the loadout selection
	HandleLoadoutSelection(Config.Loadouts[randomIndex])
end)

-- Event to select a specific loadout
RegisterNetEvent('matti-airsoft:selectLoadout')
AddEventHandler('matti-airsoft:selectLoadout', function(data)
	-- Handle the loadout selection with provided data
	HandleLoadoutSelection(data.loadout)
end)

-- Event to exit the airsoft arena
RegisterNetEvent('matti-airsoft:exitArena')
AddEventHandler('matti-airsoft:exitArena', function()
	-- Remove the player's current loadout and restore their original inventory
	RemoveLoadout()
	RestoreInventory()
	-- Teleport player to the return location
	SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
end)

-- Event to check if player is in the arena
RegisterNetEvent('matti-airsoft:checkIfInArena')
AddEventHandler('matti-airsoft:checkIfInArena', function(adminId)
	-- Determine if player is inside the airsoft zone
	local isInArena = airsoftZone:isPointInside(GetEntityCoords(PlayerPedId()))
	-- Report the arena status back to the server
	TriggerServerEvent('matti-airsoft:reportArenaStatus', adminId, isInArena)
end)

-- Event to forcefully exit player from the arena
RegisterNetEvent('matti-airsoft:forceExitArena')
AddEventHandler('matti-airsoft:forceExitArena', function()
	-- Check if player is inside the airsoft zone
	if airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) then
		-- Remove loadout, restore inventory, and teleport to return location
		RemoveLoadout()
		RestoreInventory()
		SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
		-- Notify player of forceful exit
		SendNotification(Lang:t('notifications.force_exit'), 'error')
	end
end)

-- Remove the player's current loadout and restore their original inventory
function RemoveLoadout()
	local playerPed = PlayerPedId()

	-- Check if the player has a loadout
	if currentLoadout == noLoadout then
		return
	end

	-- Loop through each loadout
	for _, loadout in ipairs(Config.Loadouts) do
		-- Remove each weapon in the loadout
		for _, weapon in ipairs(loadout.weapons) do
			TriggerServerEvent('matti-airsoft:removeWeapon', weapon.name)
		end

		-- Remove each ammo item in the loadout
		for _, ammo in ipairs(loadout.ammo) do
			-- Check which inventory system is in use
			if Config.InventorySystem == 'qb-inventory' then
				-- Loop through the player's items and find the ammo
				local items = QBCore.Functions.GetPlayerData().items
				for _, item in pairs(items) do
					if item.name == ammo.name and item.amount > 0 then
						-- Remove the ammo from the player's inventory
						TriggerServerEvent('matti-airsoft:removeItem', ammo.name, item.amount)
					end
				end
			elseif Config.InventorySystem == 'ox_inventory' then
				-- Find the current amount of ammo the player has
				local currentAmmo = exports.ox_inventory:Search('count', ammo.name)
				if currentAmmo > 0 then
					-- Remove the ammo from the player's inventory
					TriggerServerEvent('matti-airsoft:removeItem', ammo.name, currentAmmo)
				end
			else
				print('No supported inventory found.')
			end
		end
	end

	-- Set the player's current loadout to nil
	currentLoadout = nil
end

-- Leaderboard Functions
-- Function to show leaderboard
function ShowLeaderboard()
	if not Config.LeaderboardEnabled then
		return
	end
	
	leaderboardVisible = true
	
	-- Request leaderboard data from server
	QBCore.Functions.TriggerCallback('matti-airsoft:getLeaderboard', function(leaderboard)
		SendNUIMessage({
			action = 'showLeaderboard',
			show = true,
			leaderboard = leaderboard
		})
		SetNuiFocus(false, false) -- Don't capture mouse
	end)
end

-- Function to hide leaderboard
function HideLeaderboard()
	leaderboardVisible = false
	SendNUIMessage({
		action = 'showLeaderboard',
		show = false
	})
end

-- Function to toggle leaderboard visibility (kept for compatibility)
function ToggleLeaderboard()
	if leaderboardVisible then
		HideLeaderboard()
	else
		ShowLeaderboard()
	end
end

-- Event to update leaderboard from server
RegisterNetEvent('matti-airsoft:updateLeaderboard')
AddEventHandler('matti-airsoft:updateLeaderboard', function(leaderboard)
	if leaderboardVisible and isInArena then
		SendNUIMessage({
			action = 'updateLeaderboard',
			leaderboard = leaderboard
		})
	end
end)

-- NUI Callback for closing leaderboard (removed as it's always visible)
RegisterNUICallback('closeLeaderboard', function(data, cb)
	cb('ok')
end)

-- Keybind removed as leaderboard is always visible
-- Players can still see real-time updates automatically

