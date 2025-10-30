local QBCore = exports['qb-core']:GetCoreObject()
local isHit = false
local airsoftZone, currentLoadout = nil, nil
local enterPed, exitPed -- Variables for interaction peds
local debugPeds = {} -- Table to store debug peds
local originalInventory = {} -- Store the player's original inventory
local leaderboardVisible = false -- Track leaderboard visibility
local isInArena = false -- Track if player is in the arena
local lastAttacker = nil -- Track the last player who damaged us

-- Variable to store current lobby data
local currentLobby = nil

-- Helper function to count table entries
local function TableCount(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

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

-- Event hook to track damage when in arena
AddEventHandler('gameEventTriggered', function(event, data)
	if event == 'CEventNetworkEntityDamage' then
		local victim = data[1]
		local attacker = data[2]
		local playerPed = PlayerPedId()
		
		-- Check if we are the victim and we're in the arena
		if victim == playerPed and isInArena then
			-- Check if attacker is a valid ped and not ourselves
			if attacker and attacker ~= 0 and attacker ~= playerPed then
				if IsPedAPlayer(attacker) then
					local attackerPlayerId = NetworkGetPlayerIndexFromPed(attacker)
					if attackerPlayerId and attackerPlayerId ~= -1 then
						lastAttacker = GetPlayerServerId(attackerPlayerId)
						if Config.Debug then
							print('[AIRSOFT DEBUG] Damage detected from player server ID: ' .. tostring(lastAttacker))
						end
					end
				end
			end
		end
	end
end)

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
					
					-- Detect who killed/stunned the player
					local killerId = nil
					local killerPed = nil
					
					-- Method 1: GetPedSourceOfDeath (works for bullets/death)
					killerPed = GetPedSourceOfDeath(playerPed)
					
					if killerPed and killerPed ~= 0 and killerPed ~= playerPed then
						-- Check if killer is a player
						if IsPedAPlayer(killerPed) then
							local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
							if killerPlayerId and killerPlayerId ~= -1 then
								killerId = GetPlayerServerId(killerPlayerId)
							end
						end
					end
					
					-- Method 2: Use lastAttacker if we couldn't find killer (for taser/stun)
					if not killerId and lastAttacker then
						killerId = lastAttacker
						if Config.Debug then
							print('[AIRSOFT DEBUG] Using lastAttacker for killer ID: ' .. tostring(killerId))
						end
					end
					
					-- Debug logging
					if Config.Debug then
						local stunStatus = IsPedBeingStunned(playerPed, 0) and "STUNNED" or "DEAD"
						print('[AIRSOFT DEBUG] Player was hit (' .. stunStatus .. '). Killer Ped: ' .. tostring(killerPed) .. ', Killer server ID: ' .. tostring(killerId))
					end
					
					-- Notify server about the hit immediately (counts kill and death once)
					TriggerServerEvent('matti-airsoft:playerWasHit', killerId)
					
					-- Clear last attacker after using it
					lastAttacker = nil
					
					-- Handle respawn/revive in a separate thread to avoid blocking
					Citizen.CreateThread(function()
						local wasStunned = IsPedBeingStunned(playerPed, 0) and not IsEntityDead(playerPed)
						
						if Config.Debug then
							print('[AIRSOFT DEBUG] Starting revive logic. Was stunned: ' .. tostring(wasStunned))
						end
						
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
						
						-- If player was only stunned (tased), revive immediately
						if wasStunned then
							if Config.Debug then
								print('[AIRSOFT DEBUG] Player was stunned, reviving immediately')
							end
							Wait(500)
							TriggerServerEvent('matti-airsoft:revivePlayer')
						else
							-- For bullets/laststand, don't wait - revive immediately
							if Config.Debug then
								print('[AIRSOFT DEBUG] Player in laststand/death, reviving from laststand')
							end
							
							-- Short wait then trigger revive (works for both laststand and death)
							Wait(1000)
							
							if Config.Debug then
								print('[AIRSOFT DEBUG] Triggering revive for player')
							end
							TriggerServerEvent('matti-airsoft:revivePlayer')
							
						end
					end)
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

	-- Spawn a ped to handle lobby menu
	enterPed = SpawnPed(
		GetHashKey(Config.EnterLocation.model),
		Config.EnterLocation.coords,
		'matti-airsoft:openLobbyMenu',
		'fas fa-users',
		Lang:t('menu.open_lobby')
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

-- Variable to store current lobby data
local currentLobby = nil

-- Register event to open the main lobby menu (create or browse)
RegisterNetEvent('matti-airsoft:openLobbyMenu')
AddEventHandler('matti-airsoft:openLobbyMenu', function()
	-- Check if player is already in a lobby
	QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerLobby', function(lobby)
		if lobby then
			-- Player is in a lobby, open lobby management
			currentLobby = lobby
			TriggerEvent('matti-airsoft:openLobbyManagement')
		else
			-- Player is not in a lobby, show create/browse menu
			TriggerEvent('matti-airsoft:openLobbyBrowser')
		end
	end)
end)

-- Open lobby browser (create or join lobbies)
RegisterNetEvent('matti-airsoft:openLobbyBrowser')
AddEventHandler('matti-airsoft:openLobbyBrowser', function()
	local browserMenu = {}

	-- Create lobby option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(browserMenu, {
			header = Lang:t('menu.create_lobby'),
			txt = Lang:t('menu.create_lobby_desc'),
			icon = 'fas fa-plus',
			params = {
				event = 'matti-airsoft:createLobbyPrompt',
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(browserMenu, {
			title = Lang:t('menu.create_lobby'),
			description = Lang:t('menu.create_lobby_desc'),
			event = 'matti-airsoft:createLobbyPrompt',
			icon = 'fas fa-plus',
			iconColor = '#2ecc71',
		})
	end

	-- Get available lobbies
	QBCore.Functions.TriggerCallback('matti-airsoft:getLobbies', function(data)
		local lobbies = data.lobbies or {}
		local arenaOccupied = data.arenaOccupied or false
		
		-- Show arena status if occupied
		if arenaOccupied then
			if Config.MenuSystem == 'qb-menu' then
				table.insert(browserMenu, {
					header = '🔴 ' .. Lang:t('menu.arena_status'),
					txt = Lang:t('menu.arena_occupied_warning'),
					isMenuHeader = true
				})
			elseif Config.MenuSystem == 'ox_lib' then
				table.insert(browserMenu, {
					title = '🔴 ' .. Lang:t('menu.arena_status'),
					description = Lang:t('menu.arena_occupied_warning'),
					icon = 'fas fa-exclamation-triangle',
					iconColor = '#e74c3c',
					disabled = true
				})
			end
		end
		
		if #lobbies > 0 then
			-- Add header for available lobbies
			if Config.MenuSystem == 'qb-menu' then
				table.insert(browserMenu, {
					header = Lang:t('menu.available_lobbies'),
					txt = '',
					isMenuHeader = true
				})
			end

			-- Add each lobby
			for _, lobby in ipairs(lobbies) do
				local inArenaMarker = lobby.isInArena and ' 🎮' or ''
				local lobbyInfo = lobby.name .. inArenaMarker .. ' (' .. lobby.playerCount .. '/' .. lobby.maxPlayers .. ')'
				local lobbyDesc = Lang:t('menu.host') .. ': ' .. lobby.host .. ' | ' .. (lobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams'))
				
				if lobby.isInArena then
					lobbyDesc = lobbyDesc .. '\n🎮 ' .. Lang:t('menu.playing_in_arena')
				end
				
				if Config.MenuSystem == 'qb-menu' then
					table.insert(browserMenu, {
						header = lobbyInfo,
						txt = lobbyDesc,
						icon = 'fas fa-users',
						params = {
							event = 'matti-airsoft:joinLobbyConfirm',
							args = { lobbyId = lobby.id },
						},
					})
				elseif Config.MenuSystem == 'ox_lib' then
					table.insert(browserMenu, {
						title = lobbyInfo,
						description = lobbyDesc,
						event = 'matti-airsoft:joinLobbyConfirm',
						args = { lobbyId = lobby.id },
						icon = 'fas fa-users',
						iconColor = lobby.isInArena and '#e74c3c' or '#3498db',
					})
				end
			end
		else
			-- No lobbies available
			if Config.MenuSystem == 'qb-menu' then
				table.insert(browserMenu, {
					header = Lang:t('menu.no_lobbies'),
					txt = Lang:t('menu.no_lobbies_desc'),
					isMenuHeader = true
				})
			elseif Config.MenuSystem == 'ox_lib' then
				table.insert(browserMenu, {
					title = Lang:t('menu.no_lobbies'),
					description = Lang:t('menu.no_lobbies_desc'),
					icon = 'fas fa-info-circle',
					iconColor = '#95a5a6',
					disabled = true
				})
			end
		end

		-- Refresh button
		if Config.MenuSystem == 'qb-menu' then
			table.insert(browserMenu, {
				header = Lang:t('menu.refresh'),
				txt = Lang:t('menu.refresh_desc'),
				icon = 'fas fa-sync',
				params = {
					event = 'matti-airsoft:openLobbyBrowser',
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(browserMenu, {
				title = Lang:t('menu.refresh'),
				description = Lang:t('menu.refresh_desc'),
				event = 'matti-airsoft:openLobbyBrowser',
				icon = 'fas fa-sync',
				iconColor = '#95a5a6',
			})
		end

		-- Open the browser menu
		if Config.MenuSystem == 'qb-menu' then
			exports['qb-menu']:openMenu(browserMenu)
		elseif Config.MenuSystem == 'ox_lib' then
			lib.registerContext({
				id = 'matti_airsoft_lobby_browser',
				title = Lang:t('menu.lobby_browser'),
				options = browserMenu,
			})
			lib.showContext('matti_airsoft_lobby_browser')
		else
			print('No supported menu system found: ' .. Config.MenuSystem)
		end
	end)
end)

-- Create lobby prompt
RegisterNetEvent('matti-airsoft:createLobbyPrompt')
AddEventHandler('matti-airsoft:createLobbyPrompt', function()
	if Config.MenuSystem == 'ox_lib' then
		local input = lib.inputDialog(Lang:t('menu.create_lobby'), {
			{type = 'input', label = Lang:t('menu.lobby_name'), placeholder = Lang:t('menu.lobby_name_placeholder'), required = true}
		})
		
		if input then
			TriggerServerEvent('matti-airsoft:createLobby', input[1])
		end
	else
		-- For qb-menu, use qb-input if available
		local dialog = exports['qb-input']:ShowInput({
			header = Lang:t('menu.create_lobby'),
			submitText = Lang:t('menu.create'),
			inputs = {
				{
					text = Lang:t('menu.lobby_name'),
					name = 'lobbyname',
					type = 'text',
					isRequired = true
				}
			}
		})
		
		if dialog then
			TriggerServerEvent('matti-airsoft:createLobby', dialog.lobbyname)
		end
	end
end)

-- Join lobby confirmation
RegisterNetEvent('matti-airsoft:joinLobbyConfirm')
AddEventHandler('matti-airsoft:joinLobbyConfirm', function(data)
	TriggerServerEvent('matti-airsoft:joinLobby', data.lobbyId)
end)

-- Lobby created - open management
RegisterNetEvent('matti-airsoft:lobbyCreated')
AddEventHandler('matti-airsoft:lobbyCreated', function(lobby)
	currentLobby = lobby
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Lobby updated - refresh if viewing
RegisterNetEvent('matti-airsoft:lobbyUpdated')
AddEventHandler('matti-airsoft:lobbyUpdated', function(lobby)
	currentLobby = lobby
	-- If management menu is open, refresh it
	if Config.MenuSystem == 'ox_lib' then
		local currentMenu = lib.getOpenContextMenu()
		if currentMenu == 'matti_airsoft_lobby_management' then
			TriggerEvent('matti-airsoft:openLobbyManagement')
		end
	end
end)

-- Lobby closed - return to browser
RegisterNetEvent('matti-airsoft:lobbyClosed')
AddEventHandler('matti-airsoft:lobbyClosed', function()
	currentLobby = nil
	SendNotification(Lang:t('notifications.lobby_left'), 'info')
end)

-- Open lobby management (for players in a lobby)
RegisterNetEvent('matti-airsoft:openLobbyManagement')
AddEventHandler('matti-airsoft:openLobbyManagement', function()
	if not currentLobby then return end
	
	local managementMenu = {}
	local isHost = currentLobby.host == GetPlayerServerId(PlayerId())

	-- Lobby info header
	if Config.MenuSystem == 'qb-menu' then
		table.insert(managementMenu, {
			header = currentLobby.name,
			txt = Lang:t('menu.players') .. ': ' .. TableCount(currentLobby.players),
			isMenuHeader = true
		})
	end

	-- Player list
	local playerListText = ''
	for playerId, playerData in pairs(currentLobby.players) do
		local hostMarker = (playerId == currentLobby.host) and ' 👑' or ''
		playerListText = playerListText .. playerData.name .. hostMarker .. '\n'
	end

	if Config.MenuSystem == 'qb-menu' then
		table.insert(managementMenu, {
			header = Lang:t('menu.players_list'),
			txt = playerListText,
			icon = 'fas fa-users',
			isMenuHeader = true
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(managementMenu, {
			title = Lang:t('menu.players_list'),
			description = playerListText,
			icon = 'fas fa-users',
			iconColor = '#3498db',
			disabled = true
		})
	end

	-- Game mode (host only)
	if isHost then
		local currentModeText = currentLobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')
		if Config.MenuSystem == 'qb-menu' then
			table.insert(managementMenu, {
				header = Lang:t('menu.game_mode'),
				txt = Lang:t('menu.current_mode') .. ': ' .. currentModeText,
				icon = 'fas fa-gamepad',
				params = {
					event = 'matti-airsoft:selectGameMode',
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(managementMenu, {
				title = Lang:t('menu.game_mode'),
				description = Lang:t('menu.current_mode') .. ': ' .. currentModeText,
				event = 'matti-airsoft:selectGameMode',
				icon = 'fas fa-gamepad',
				iconColor = '#3498db',
			})
		end

		-- Loadout selection
		local currentLoadoutText = currentLobby.selectedLoadout and currentLobby.selectedLoadout.name or Lang:t('menu.no_loadout')
		if Config.MenuSystem == 'qb-menu' then
			table.insert(managementMenu, {
				header = Lang:t('menu.select_lobby_loadout'),
				txt = Lang:t('menu.current_loadout') .. ': ' .. currentLoadoutText,
				icon = 'fas fa-crosshairs',
				params = {
					event = 'matti-airsoft:selectLobbyLoadout',
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(managementMenu, {
				title = Lang:t('menu.select_lobby_loadout'),
				description = Lang:t('menu.current_loadout') .. ': ' .. currentLoadoutText,
				event = 'matti-airsoft:selectLobbyLoadout',
				icon = 'fas fa-crosshairs',
				iconColor = '#e74c3c',
			})
		end

		-- Start game button (host only)
		if Config.MenuSystem == 'qb-menu' then
			table.insert(managementMenu, {
				header = Lang:t('menu.start_game'),
				txt = Lang:t('menu.start_game_desc'),
				icon = 'fas fa-play',
				params = {
					event = 'matti-airsoft:startLobbyGame',
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(managementMenu, {
				title = Lang:t('menu.start_game'),
				description = Lang:t('menu.start_game_desc'),
				event = 'matti-airsoft:startLobbyGame',
				icon = 'fas fa-play',
				iconColor = '#2ecc71',
			})
		end
	else
		-- Non-host view - show current settings
		local currentModeText = currentLobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')
		local currentLoadoutText = currentLobby.selectedLoadout and currentLobby.selectedLoadout.name or Lang:t('menu.no_loadout')
		
		if Config.MenuSystem == 'qb-menu' then
			table.insert(managementMenu, {
				header = Lang:t('menu.lobby_settings'),
				txt = Lang:t('menu.game_mode') .. ': ' .. currentModeText .. '\n' .. Lang:t('menu.loadout') .. ': ' .. currentLoadoutText,
				icon = 'fas fa-info-circle',
				isMenuHeader = true
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(managementMenu, {
				title = Lang:t('menu.lobby_settings'),
				description = Lang:t('menu.game_mode') .. ': ' .. currentModeText .. '\n' .. Lang:t('menu.loadout') .. ': ' .. currentLoadoutText,
				icon = 'fas fa-info-circle',
				iconColor = '#95a5a6',
				disabled = true
			})
		end
	end

	-- Team selection (for everyone in teams mode)
	if currentLobby.gameMode == 'teams' then
		if Config.MenuSystem == 'qb-menu' then
			table.insert(managementMenu, {
				header = Lang:t('menu.select_team'),
				txt = Lang:t('menu.select_team_desc'),
				icon = 'fas fa-users',
				params = {
					event = 'matti-airsoft:selectTeam',
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(managementMenu, {
				title = Lang:t('menu.select_team'),
				description = Lang:t('menu.select_team_desc'),
				event = 'matti-airsoft:selectTeam',
				icon = 'fas fa-users',
				iconColor = '#9b59b6',
			})
		end
	end

	-- Leave lobby button
	if Config.MenuSystem == 'qb-menu' then
		table.insert(managementMenu, {
			header = Lang:t('menu.leave_lobby'),
			txt = Lang:t('menu.leave_lobby_desc'),
			icon = 'fas fa-door-open',
			params = {
				event = 'matti-airsoft:confirmLeaveLobby',
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(managementMenu, {
			title = Lang:t('menu.leave_lobby'),
			description = Lang:t('menu.leave_lobby_desc'),
			event = 'matti-airsoft:confirmLeaveLobby',
			icon = 'fas fa-door-open',
			iconColor = '#e74c3c',
		})
	end

	-- Open the management menu
	if Config.MenuSystem == 'qb-menu' then
		exports['qb-menu']:openMenu(managementMenu)
	elseif Config.MenuSystem == 'ox_lib' then
		lib.registerContext({
			id = 'matti_airsoft_lobby_management',
			title = currentLobby.name,
			options = managementMenu,
		})
		lib.showContext('matti_airsoft_lobby_management')
	else
		print('No supported menu system found: ' .. Config.MenuSystem)
	end
end)

-- Leave lobby confirmation
RegisterNetEvent('matti-airsoft:confirmLeaveLobby')
AddEventHandler('matti-airsoft:confirmLeaveLobby', function()
	TriggerServerEvent('matti-airsoft:leaveLobby')
end)

-- Event to select game mode
RegisterNetEvent('matti-airsoft:selectGameMode')
AddEventHandler('matti-airsoft:selectGameMode', function()
	local gameModeMenu = {}

	-- FFA option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(gameModeMenu, {
			header = Lang:t('menu.ffa'),
			txt = Lang:t('menu.ffa_desc'),
			icon = 'fas fa-user',
			params = {
				event = 'matti-airsoft:setGameMode',
				args = { mode = 'ffa' },
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(gameModeMenu, {
			title = Lang:t('menu.ffa'),
			description = Lang:t('menu.ffa_desc'),
			event = 'matti-airsoft:setGameMode',
			args = { mode = 'ffa' },
			icon = 'fas fa-user',
			iconColor = '#f39c12',
		})
	end

	-- Teams option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(gameModeMenu, {
			header = Lang:t('menu.teams'),
			txt = Lang:t('menu.teams_desc'),
			icon = 'fas fa-users',
			params = {
				event = 'matti-airsoft:setGameMode',
				args = { mode = 'teams' },
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(gameModeMenu, {
			title = Lang:t('menu.teams'),
			description = Lang:t('menu.teams_desc'),
			event = 'matti-airsoft:setGameMode',
			args = { mode = 'teams' },
			icon = 'fas fa-users',
			iconColor = '#9b59b6',
		})
	end

	-- Back button
	if Config.MenuSystem == 'qb-menu' then
		table.insert(gameModeMenu, {
			header = Lang:t('menu.back'),
			icon = 'fas fa-arrow-left',
			params = {
				event = 'matti-airsoft:openLobbyManagement',
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(gameModeMenu, {
			title = Lang:t('menu.back'),
			event = 'matti-airsoft:openLobbyManagement',
			icon = 'fas fa-arrow-left',
			iconColor = '#95a5a6',
		})
	end

	-- Open game mode menu
	if Config.MenuSystem == 'qb-menu' then
		exports['qb-menu']:openMenu(gameModeMenu)
	elseif Config.MenuSystem == 'ox_lib' then
		lib.registerContext({
			id = 'matti_airsoft_gamemode_menu',
			title = Lang:t('menu.select_game_mode'),
			menu = 'matti_airsoft_lobby_management',
			options = gameModeMenu,
		})
		lib.showContext('matti_airsoft_gamemode_menu')
	end
end)

-- Event to set game mode
RegisterNetEvent('matti-airsoft:setGameMode')
AddEventHandler('matti-airsoft:setGameMode', function(data)
	TriggerServerEvent('matti-airsoft:setGameMode', data.mode)
	SendNotification(Lang:t('notifications.game_mode_set') .. ' ' .. (data.mode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')), 'success')
	Wait(500)
	-- Return to lobby management
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Event to select loadout for lobby
RegisterNetEvent('matti-airsoft:selectLobbyLoadout')
AddEventHandler('matti-airsoft:selectLobbyLoadout', function()
	local loadoutMenu = {}

	-- Loop through each loadout and add it to the menu
	for i, loadout in ipairs(Config.Loadouts) do
		local weaponsList, ammoList = '', ''
		for _, weapon in ipairs(loadout.weapons) do
			weaponsList = weaponsList .. weapon.label .. '\n'
		end
		for _, ammo in ipairs(loadout.ammo) do
			ammoList = ammoList .. ' (' .. ammo.amount .. ' clips)\n'
		end

		if Config.MenuSystem == 'qb-menu' then
			table.insert(loadoutMenu, {
				header = loadout.name .. ' - $' .. loadout.price,
				txt = Lang:t('menu.includes') .. '\n' .. weaponsList .. ammoList,
				icon = 'fas fa-crosshairs',
				params = {
					event = 'matti-airsoft:setLobbyLoadout',
					args = { loadout = loadout },
				},
			})
		elseif Config.MenuSystem == 'ox_lib' then
			table.insert(loadoutMenu, {
				title = loadout.name .. ' - $' .. loadout.price,
				description = Lang:t('menu.includes') .. '\n' .. weaponsList .. ammoList,
				event = 'matti-airsoft:setLobbyLoadout',
				args = { loadout = loadout },
				icon = 'fas fa-crosshairs',
				iconColor = '#EC213A',
			})
		end
	end

	-- Random loadout option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(loadoutMenu, {
			header = Lang:t('menu.random_loadout'),
			txt = Lang:t('menu.random_loadout_txt'),
			icon = 'fas fa-random',
			params = { event = 'matti-airsoft:setRandomLobbyLoadout' },
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(loadoutMenu, {
			title = Lang:t('menu.random_loadout'),
			description = Lang:t('menu.random_loadout_txt'),
			event = 'matti-airsoft:setRandomLobbyLoadout',
			icon = 'fas fa-random',
			iconColor = '#EC213A',
		})
	end

	-- Back button
	if Config.MenuSystem == 'qb-menu' then
		table.insert(loadoutMenu, {
			header = Lang:t('menu.back'),
			icon = 'fas fa-arrow-left',
			params = {
				event = 'matti-airsoft:openLobbyManagement',
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(loadoutMenu, {
			title = Lang:t('menu.back'),
			event = 'matti-airsoft:openLobbyManagement',
			icon = 'fas fa-arrow-left',
			iconColor = '#95a5a6',
		})
	end

	-- Open loadout menu
	if Config.MenuSystem == 'qb-menu' then
		exports['qb-menu']:openMenu(loadoutMenu)
	elseif Config.MenuSystem == 'ox_lib' then
		lib.registerContext({
			id = 'matti_airsoft_lobby_loadout_menu',
			title = Lang:t('menu.select_lobby_loadout'),
			menu = 'matti_airsoft_lobby_management',
			options = loadoutMenu,
		})
		lib.showContext('matti_airsoft_lobby_loadout_menu')
	end
end)

-- Event to set loadout for lobby
RegisterNetEvent('matti-airsoft:setLobbyLoadout')
AddEventHandler('matti-airsoft:setLobbyLoadout', function(data)
	TriggerServerEvent('matti-airsoft:setLobbyLoadout', data.loadout)
	SendNotification(Lang:t('notifications.lobby_loadout_set') .. ' ' .. data.loadout.name, 'success')
	Wait(500)
	-- Return to lobby management
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Event to set random loadout for lobby
RegisterNetEvent('matti-airsoft:setRandomLobbyLoadout')
AddEventHandler('matti-airsoft:setRandomLobbyLoadout', function()
	local randomIndex = math.random(1, #Config.Loadouts)
	local randomLoadout = Config.Loadouts[randomIndex]
	TriggerServerEvent('matti-airsoft:setLobbyLoadout', randomLoadout)
	SendNotification(Lang:t('notifications.lobby_loadout_set') .. ' ' .. randomLoadout.name, 'success')
	Wait(500)
	-- Return to lobby management
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Host starts the game
RegisterNetEvent('matti-airsoft:startLobbyGame')
AddEventHandler('matti-airsoft:startLobbyGame', function()
	-- Check if in teams mode and if player has selected a team
	if currentLobby and currentLobby.gameMode == 'teams' then
		QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerTeam', function(team)
			if not team then
				-- Player hasn't selected a team, show team selection
				TriggerEvent('matti-airsoft:selectTeam')
			else
				-- Player has a team, start game
				TriggerServerEvent('matti-airsoft:startLobbyGame')
			end
		end)
	else
		-- FFA mode, just start
		TriggerServerEvent('matti-airsoft:startLobbyGame')
	end
end)

-- Team selection menu
RegisterNetEvent('matti-airsoft:selectTeam')
AddEventHandler('matti-airsoft:selectTeam', function()
	local teamMenu = {}

	-- Team 1 option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(teamMenu, {
			header = Lang:t('menu.team1'),
			txt = Lang:t('menu.team1_desc'),
			icon = 'fas fa-users',
			params = {
				event = 'matti-airsoft:confirmTeamSelection',
				args = { team = 'team1' },
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(teamMenu, {
			title = Lang:t('menu.team1'),
			description = Lang:t('menu.team1_desc'),
			event = 'matti-airsoft:confirmTeamSelection',
			args = { team = 'team1' },
			icon = 'fas fa-users',
			iconColor = '#3498db',
		})
	end

	-- Team 2 option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(teamMenu, {
			header = Lang:t('menu.team2'),
			txt = Lang:t('menu.team2_desc'),
			icon = 'fas fa-users',
			params = {
				event = 'matti-airsoft:confirmTeamSelection',
				args = { team = 'team2' },
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(teamMenu, {
			title = Lang:t('menu.team2'),
			description = Lang:t('menu.team2_desc'),
			event = 'matti-airsoft:confirmTeamSelection',
			args = { team = 'team2' },
			icon = 'fas fa-users',
			iconColor = '#e74c3c',
		})
	end

	-- Open team menu
	if Config.MenuSystem == 'qb-menu' then
		exports['qb-menu']:openMenu(teamMenu)
	elseif Config.MenuSystem == 'ox_lib' then
		lib.registerContext({
			id = 'matti_airsoft_team_menu',
			title = Lang:t('menu.select_team'),
			options = teamMenu,
		})
		lib.showContext('matti_airsoft_team_menu')
	end
end)

-- Confirm team selection
RegisterNetEvent('matti-airsoft:confirmTeamSelection')
AddEventHandler('matti-airsoft:confirmTeamSelection', function(data)
	TriggerServerEvent('matti-airsoft:setPlayerTeam', data.team)
	-- Don't auto-start game - wait for host to start
	SendNotification(Lang:t('notifications.team_selected') .. ' ' .. (data.team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

-- Game is starting (triggered by server for all lobby players)
RegisterNetEvent('matti-airsoft:gameStarting')
AddEventHandler('matti-airsoft:gameStarting', function(loadout, gameMode)
	if not loadout then
		SendNotification(Lang:t('notifications.select_loadout_first'), 'error')
		return
	end
	
	-- If teams mode, check if player has selected a team
	if gameMode == 'teams' then
		QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerTeam', function(team)
			if not team then
				-- Show team selection
				TriggerEvent('matti-airsoft:selectTeamBeforePlay')
			else
				-- Player has a team, apply loadout
				HandleLoadoutSelection(loadout)
			end
		end)
	else
		-- FFA mode, just apply loadout
		HandleLoadoutSelection(loadout)
	end
end)

-- Team selection before play (for non-host players)
RegisterNetEvent('matti-airsoft:selectTeamBeforePlay')
AddEventHandler('matti-airsoft:selectTeamBeforePlay', function()
	local teamMenu = {}

	-- Team 1 option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(teamMenu, {
			header = Lang:t('menu.team1'),
			txt = Lang:t('menu.team1_desc'),
			icon = 'fas fa-users',
			params = {
				event = 'matti-airsoft:confirmTeamBeforePlay',
				args = { team = 'team1' },
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(teamMenu, {
			title = Lang:t('menu.team1'),
			description = Lang:t('menu.team1_desc'),
			event = 'matti-airsoft:confirmTeamBeforePlay',
			args = { team = 'team1' },
			icon = 'fas fa-users',
			iconColor = '#3498db',
		})
	end

	-- Team 2 option
	if Config.MenuSystem == 'qb-menu' then
		table.insert(teamMenu, {
			header = Lang:t('menu.team2'),
			txt = Lang:t('menu.team2_desc'),
			icon = 'fas fa-users',
			params = {
				event = 'matti-airsoft:confirmTeamBeforePlay',
				args = { team = 'team2' },
			},
		})
	elseif Config.MenuSystem == 'ox_lib' then
		table.insert(teamMenu, {
			title = Lang:t('menu.team2'),
			description = Lang:t('menu.team2_desc'),
			event = 'matti-airsoft:confirmTeamBeforePlay',
			args = { team = 'team2' },
			icon = 'fas fa-users',
			iconColor = '#e74c3c',
		})
	end

	-- Open team menu
	if Config.MenuSystem == 'qb-menu' then
		exports['qb-menu']:openMenu(teamMenu)
	elseif Config.MenuSystem == 'ox_lib' then
		lib.registerContext({
			id = 'matti_airsoft_team_select_play',
			title = Lang:t('menu.select_team'),
			options = teamMenu,
		})
		lib.showContext('matti_airsoft_team_select_play')
	end
end)

-- Confirm team selection and start playing
RegisterNetEvent('matti-airsoft:confirmTeamBeforePlay')
AddEventHandler('matti-airsoft:confirmTeamBeforePlay', function(data)
	TriggerServerEvent('matti-airsoft:setPlayerTeam', data.team)
	-- Don't auto-apply loadout - just confirm team selection
	SendNotification(Lang:t('notifications.team_selected') .. ' ' .. (data.team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
	-- Now apply the loadout after team is set
	Wait(500)
	if currentLobby and currentLobby.selectedLoadout then
		HandleLoadoutSelection(currentLobby.selectedLoadout)
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

