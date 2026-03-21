-- ============================================
-- Matti Airsoft - Client Script (Refactored)
-- ============================================

-- Core Initialization
local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- State Variables
-- ============================================
local State = {
    isHit = false,
    isInArena = false,
    leaderboardVisible = false,
    airsoftZone = nil,
    currentLoadout = nil,
    currentLobby = nil,
    lastAttacker = nil,
	lastTrackedHit = nil,
    originalInventory = {},
    enterPed = nil,
    exitPed = nil,
    debugPeds = {}
}

-- ============================================
-- Utility Functions
-- ============================================
local Utils = {}

-- Count entries in a table
function Utils.TableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Get player's full name
function Utils.GetPlayerName()
    local player = QBCore.Functions.GetPlayerData()
    return player.charinfo.firstname .. ' ' .. player.charinfo.lastname
end


-- Send notification based on configured system
function Utils.SendNotification(message, type)
    if Config.NotifySystem == 'qb-core' then
        QBCore.Functions.Notify(message, type)
    elseif Config.NotifySystem == 'ox_lib' then
        local iconColors = {
            success = '#28A745',
            error = '#DC3545',
            info = '#F08080'
        }
        local icons = {
            success = 'check-circle',
            error = 'times-circle',
            info = 'info-circle'
        }
        
        lib.notify({
            title = message,
            style = {
                color = iconColors[type] or iconColors.info,
                ['.description'] = { color = type == 'success' and '#E9ECEF' or '#909296' }
            },
            icon = icons[type] or icons.info,
            iconColor = iconColors[type] or iconColors.info,
        })
    else
        print('No supported notification system found: ' .. Config.NotifySystem)
    end
end

RegisterNetEvent('matti-airsoft:sendNotification', function(message, type)
    Utils.SendNotification(message, type)
end)

-- ============================================
-- Inventory Management
-- ============================================
local Inventory = {}

function Inventory.SaveAndClear()
    local playerData = QBCore.Functions.GetPlayerData()
    local playerItems = playerData.items or {}

    if Config.InventorySystem == 'qb-inventory' then
        for _, item in pairs(playerItems) do
            TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
        end
    elseif Config.InventorySystem == 'ox_inventory' then
        for _, item in pairs(exports.ox_inventory:GetPlayerItems()) do
            TriggerServerEvent('matti-airsoft:removeItem', item.name, item.count)
        end
    else
        print('No supported inventory found: ' .. Config.InventorySystem)
    end

    State.originalInventory = table.clone(playerItems)
end

function Inventory.Restore()
    for _, item in pairs(State.originalInventory) do
        local itemAmount = item.amount or item.count
        TriggerServerEvent('matti-airsoft:giveItem', item.name, itemAmount)
    end
    State.originalInventory = {}
end

-- ============================================
-- Player Management
-- ============================================
local Player = {}

function Player.TeleportToRandomPosition()
    local randomCoord = Config.SpawnLocations[math.random(1, #Config.SpawnLocations)]
    SetEntityCoords(PlayerPedId(), randomCoord)
end

-- ============================================
-- Ped Management
-- ============================================
local Peds = {}

function Peds.Spawn(modelHash, coords, event, icon, label)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if Config.TargetSystem == 'qb-target' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    event = event,
                    icon = icon,
                    label = label,
                },
            },
            distance = 2.5,
        })
    elseif Config.TargetSystem == 'ox_target' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'airsoft_menu',
                label = label,
                onSelect = function()
                    TriggerEvent(event)
                end,
                icon = icon,
                distance = 2.5,
            },
        })
    else
        print('No supported target system found: ' .. Config.TargetSystem)
    end

    return ped
end

-- ============================================
-- Blip Management
-- ============================================
local Blip = {}

function Blip.Create()
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

-- ============================================
-- Loadout Management
-- ============================================
local Loadout = {}

function Loadout.Handle(loadout)
    QBCore.Functions.TriggerCallback('matti-airsoft:canAffordLoadout', function(canAfford)
        if canAfford then
            Inventory.SaveAndClear()

            for _, weapon in ipairs(loadout.weapons) do
                TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
            end

            for _, ammo in ipairs(loadout.ammo) do
                TriggerServerEvent('matti-airsoft:giveItem', ammo.name, ammo.amount)
            end

            SetCurrentPedWeapon(PlayerPedId(), GetHashKey('WEAPON_UNARMED'), true)
            State.currentLoadout = loadout

            Utils.SendNotification('You have selected the "' .. loadout.name .. '" loadout!', 'success')
            Player.TeleportToRandomPosition()
        else
            Utils.SendNotification(Lang:t('notifications.cannot_afford'), 'error')
        end
    end, loadout.price)
end

function Loadout.Remove()
    local playerPed = PlayerPedId()

    if State.currentLoadout == nil then
        return
    end

    for _, loadout in ipairs(Config.Loadouts) do
        for _, weapon in ipairs(loadout.weapons) do
            TriggerServerEvent('matti-airsoft:removeWeapon', weapon.name)
        end

        for _, ammo in ipairs(loadout.ammo) do
            local currentAmmo = 0
            if Config.InventorySystem == 'qb-inventory' then
                local items = QBCore.Functions.GetPlayerData().items
                for _, item in pairs(items) do
                    if item.name == ammo.name and item.amount > 0 then
                        currentAmmo = item.amount
                        break
                    end
                end
            elseif Config.InventorySystem == 'ox_inventory' then
                currentAmmo = exports.ox_inventory:Search('count', ammo.name)
            end

            if currentAmmo > 0 then
                TriggerServerEvent('matti-airsoft:removeItem', ammo.name, currentAmmo)
            end
        end
    end

    State.currentLoadout = nil
end

-- ============================================
-- Combat Tracking
-- ============================================
local Combat = {}

local trackedWeaponHashes = {}

for _, weaponName in ipairs(Config.ScoreboardTrackedWeapons or {}) do
	trackedWeaponHashes[GetHashKey(weaponName)] = true
end

function Combat.GetAttributionGraceMs()
	return Config.ScoreboardHitGracePeriod or 5000
end

function Combat.IsTrackedWeapon(weaponHash)
	return weaponHash and trackedWeaponHashes[weaponHash] == true
end

function Combat.ResolveTrackedWeapon(attackerPed, eventWeaponHash, victimPed)
	if Combat.IsTrackedWeapon(eventWeaponHash) then
		return eventWeaponHash
	end

	if attackerPed and attackerPed ~= 0 then
		local selectedWeapon = GetSelectedPedWeapon(attackerPed)
		if Combat.IsTrackedWeapon(selectedWeapon) then
			return selectedWeapon
		end
	end

	if victimPed and victimPed ~= 0 then
		for trackedWeaponHash in pairs(trackedWeaponHashes) do
			if HasEntityBeenDamagedByWeapon(victimPed, trackedWeaponHash, 0) then
				return trackedWeaponHash
			end
		end
	end

	return nil
end

function Combat.GetRecentTrackedHit()
	if not State.lastTrackedHit then
		return nil
	end

	if (GetGameTimer() - State.lastTrackedHit.timestamp) > Combat.GetAttributionGraceMs() then
		State.lastTrackedHit = nil
		return nil
	end

	return State.lastTrackedHit
end

function Combat.GetRecentAttacker()
	if not State.lastAttacker then
		return nil
	end

	if (GetGameTimer() - State.lastAttacker.timestamp) > Combat.GetAttributionGraceMs() then
		State.lastAttacker = nil
		return nil
	end

	return State.lastAttacker
end

function Combat.GetClosestPlayerServerId(maxDistance)
	local playerPed = PlayerPedId()
	local myCoords = GetEntityCoords(playerPed)
	local closestDistance = maxDistance or 25.0
	local closestServerId = nil

	for _, playerId in ipairs(GetActivePlayers()) do
		if playerId ~= PlayerId() then
			local targetPed = GetPlayerPed(playerId)
			if targetPed and targetPed ~= 0 then
				local targetCoords = GetEntityCoords(targetPed)
				local distance = #(myCoords - targetCoords)
				if distance <= closestDistance then
					closestDistance = distance
					closestServerId = GetPlayerServerId(playerId)
				end
			end
		end
	end

	return closestServerId
end

function Combat.ResolveKillerId(playerPed)
	local killerId = nil
	local shouldCreditKiller = false
	local killerPed = GetPedSourceOfDeath(playerPed)
	local causeOfDeath = GetPedCauseOfDeath(playerPed)
	local recentTrackedHit = Combat.GetRecentTrackedHit()
	local recentAttacker = Combat.GetRecentAttacker()

	if killerPed and killerPed ~= 0 and killerPed ~= playerPed and IsPedAPlayer(killerPed) then
		local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
		if killerPlayerId and killerPlayerId ~= -1 then
			killerId = GetPlayerServerId(killerPlayerId)
			shouldCreditKiller = Combat.ResolveTrackedWeapon(killerPed, causeOfDeath, playerPed) ~= nil
		end
	end

	if not shouldCreditKiller and recentTrackedHit then
		killerId = recentTrackedHit.serverId
		shouldCreditKiller = true
		if Config.Debug then
			print(' Using recent tracked hit for killer ID: ' .. tostring(killerId))
		end
	end

	if not shouldCreditKiller and recentAttacker then
		killerId = recentAttacker.serverId
		shouldCreditKiller = true
		if Config.Debug then
			print(' Using recent attacker fallback for killer ID: ' .. tostring(killerId))
		end
	end

	if not killerId then
		killerId = Combat.GetClosestPlayerServerId(25.0)
		if killerId and Config.Debug then
			print(' Using closest player fallback for killer ID: ' .. tostring(killerId))
		end
	end

	return killerId, shouldCreditKiller, killerPed, causeOfDeath
end

function Combat.TrackDamage()
    AddEventHandler('gameEventTriggered', function(event, data)
		if event ~= 'CEventNetworkEntityDamage' then
			return
		end

		local victim = data[1]
		local attacker = data[2]
		local eventWeaponHash = data[7]
		local playerPed = PlayerPedId()

		if victim ~= playerPed or not State.isInArena then
			return
		end

		if not attacker or attacker == 0 or attacker == playerPed or not IsPedAPlayer(attacker) then
			return
		end

		local attackerPlayerId = NetworkGetPlayerIndexFromPed(attacker)
		if not attackerPlayerId or attackerPlayerId == -1 then
			return
		end

		local attackerServerId = GetPlayerServerId(attackerPlayerId)
		State.lastAttacker = {
			serverId = attackerServerId,
			timestamp = GetGameTimer()
		}

		TriggerServerEvent('matti-airsoft:registerRecentAttacker', attackerServerId)

		if Config.Debug then
			print(' Damage detected from player server ID: ' .. tostring(attackerServerId) .. ' with event weapon hash: ' .. tostring(eventWeaponHash))
		end

		local trackedWeaponHash = Combat.ResolveTrackedWeapon(attacker, eventWeaponHash, playerPed)
		if trackedWeaponHash then
			State.lastTrackedHit = {
				serverId = attackerServerId,
				weaponHash = trackedWeaponHash,
				timestamp = GetGameTimer()
			}

			if Config.Debug then
				print(' Tracked airsoft hit from player server ID: ' .. tostring(attackerServerId) .. ' with weapon hash: ' .. tostring(trackedWeaponHash))
			end
		elseif Config.Debug then
			print(' Damage ignored for scoreboard (non-airsoft or unresolved weapon). Event weapon hash: ' .. tostring(eventWeaponHash))
        end
    end)
end


function Combat.CheckHitStatus()
    Citizen.CreateThread(function()
        while State.airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) do
            Wait(100)
            local playerPed = PlayerPedId()

            if IsPedBeingStunned(playerPed, 0) or IsEntityDead(playerPed) then
                if not State.isHit then
                    State.isHit = true

                    local killerId, shouldCreditKiller, killerPed, causeOfDeath = Combat.ResolveKillerId(playerPed)
                    
                    if Config.Debug then
                        local stunStatus = IsPedBeingStunned(playerPed, 0) and "STUNNED" or "DEAD"
                        print(' Player was hit (' .. stunStatus .. '). Cause hash: ' .. tostring(causeOfDeath) .. ', Killer Ped: ' .. tostring(killerPed) .. ', Killer server ID: ' .. tostring(killerId) .. ', Counted on scoreboard: true, Credited killer: ' .. tostring(shouldCreditKiller))
                    end

                    TriggerServerEvent('matti-airsoft:playerWasHit', killerId)

                    State.lastAttacker = nil
                    State.lastTrackedHit = nil
                    
                    Citizen.CreateThread(function()
                        local wasStunned = IsPedBeingStunned(playerPed, 0) and not IsEntityDead(playerPed)
                        
                        if Config.Debug then
                            print(' Starting revive logic. Was stunned: ' .. tostring(wasStunned))
                        end
                        
                        if Config.TeleportOnHit then
                            if Config.ContinuePlayingAfterDeath then
                                Utils.SendNotification(Lang:t('inarena.shot'))
                                Wait(2000)
                                Player.TeleportToRandomPosition()
                            else
                                Utils.SendNotification(Lang:t('inarena.shotandout'))
                                SetEntityCoords(playerPed, Config.ReturnLocation)
                            end
                        else
                            Utils.SendNotification(Lang:t('inarena.shot'))
                        end
                        
                        if wasStunned then
                            if Config.Debug then
                                print(' Player was stunned, reviving immediately')
                            end
                            Wait(500)
                            TriggerServerEvent('matti-airsoft:revivePlayer')
                        else
                            if Config.Debug then
                                print(' Player in laststand/death, reviving from laststand')
                            end
                            Wait(1000)
                            TriggerServerEvent('matti-airsoft:revivePlayer')
                        end
                    end)
                end
            else
                State.isHit = false
            end
        end
    end)
end

-- ============================================
-- Leaderboard Management
-- ============================================
local Leaderboard = {}

function Leaderboard.Show()
    if not Config.LeaderboardEnabled then
        return
    end
    
    State.leaderboardVisible = true
    
    QBCore.Functions.TriggerCallback('matti-airsoft:getLeaderboard', function(leaderboard)
        SendNUIMessage({
            action = 'showLeaderboard',
            show = true,
            leaderboard = leaderboard
        })
        SetNuiFocus(false, false)
    end)
end

function Leaderboard.Hide()
    State.leaderboardVisible = false
    SendNUIMessage({
        action = 'showLeaderboard',
        show = false
    })
end

-- ============================================
-- Zone Management
-- ============================================
local Zone = {}

function Zone.HandleEntry(isPointInside)
    if isPointInside then
        State.isInArena = true
        Utils.SendNotification(Lang:t('notifications.entered'), 'success')
        
        if Config.Debug then
            TriggerServerEvent('matti-airsoft:debugZoneEntry', Utils.GetPlayerName(), 'entered')
        end
        
        TriggerServerEvent('matti-airsoft:playerEnteredArena')
        
        if Config.LeaderboardEnabled then
            Leaderboard.Show()
        end
        
        Combat.CheckHitStatus()
    else
        State.isInArena = false
        
        if Config.LeaderboardEnabled then
            Leaderboard.Hide()
        end
        
        Utils.SendNotification(Lang:t('notifications.exited'), 'error')
        
        if Config.Debug then
            TriggerServerEvent('matti-airsoft:debugZoneEntry', Utils.GetPlayerName(), 'exited')
        end
        
        TriggerServerEvent('matti-airsoft:playerLeftArena')
        Loadout.Remove()
        Inventory.Restore()
        State.isHit = false
    end
end

function Zone.Create()
    if Config.ZoneType == 'circle' then
        State.airsoftZone = CircleZone:Create(Config.AirsoftZone.coordinates, Config.AirsoftZone.radius, {
            debugPoly = Config.Debug,
        })
    elseif Config.ZoneType == 'poly' then
        State.airsoftZone = PolyZone:Create(Config.AirsoftZone.points, {
            debugPoly = Config.Debug,
        })
    else
        print('No supported zone type found.')
        return
    end
    
    State.airsoftZone:onPlayerInOut(Zone.HandleEntry)
end

-- ============================================
-- Menu System
-- ============================================
local Menu = {}

function Menu.IsQbMenu()
	return Config.MenuSystem == 'qb-menu'
end

function Menu.AddOption(menu, option)
	if Menu.IsQbMenu() then
		local entry = {
			header = option.title,
			txt = option.description or '',
			icon = option.icon,
		}

		if option.isHeader or option.disabled then
			entry.isMenuHeader = true
			entry.icon = nil
		elseif option.event then
			entry.params = {
				event = option.event,
				args = option.args,
			}
		end

		table.insert(menu, entry)
		return
	end

	local entry = {
		title = option.title,
		description = option.description or '',
		icon = option.icon,
		iconColor = option.iconColor,
		disabled = option.disabled or false,
	}

	if option.event then
		entry.event = option.event
		entry.args = option.args
	end

	if option.isHeader then
		entry.disabled = true
	end

	table.insert(menu, entry)
end

function Menu.Open(id, title, options, parentMenu)
	if Menu.IsQbMenu() then
		exports['qb-menu']:openMenu(options)
		return
	end

	if Config.MenuSystem == 'ox_lib' then
		local context = {
			id = id,
			title = title,
			options = options,
		}

		if parentMenu then
			context.menu = parentMenu
		end

		lib.registerContext(context)
		lib.showContext(id)
	else
		print('No supported menu system found: ' .. Config.MenuSystem)
	end
end

function Menu.BuildLoadoutDescription(loadout)
	local weaponsList, ammoList = '', ''

	for _, weapon in ipairs(loadout.weapons) do
		weaponsList = weaponsList .. weapon.label .. '\n'
	end

	for _, ammo in ipairs(loadout.ammo) do
		ammoList = ammoList .. ' (' .. ammo.amount .. ' clips)\n'
	end

	return Lang:t('menu.includes') .. '\n' .. weaponsList .. ammoList
end

function Menu.AppendLoadoutOptions(targetMenu, selectEvent)
	for _, loadout in ipairs(Config.Loadouts) do
		Menu.AddOption(targetMenu, {
			title = loadout.name .. ' - $' .. loadout.price,
			description = Menu.BuildLoadoutDescription(loadout),
			event = selectEvent,
			args = { loadout = loadout },
			icon = 'fas fa-crosshairs',
			iconColor = '#EC213A',
		})
	end
end

function Menu.BuildTeamSelectionMenu(confirmEvent)
	local menu = {}

	Menu.AddOption(menu, {
		title = Lang:t('menu.team1'),
		description = Lang:t('menu.team1_desc'),
		event = confirmEvent,
		args = { team = 'team1' },
		icon = 'fas fa-users',
		iconColor = '#3498db',
	})

	Menu.AddOption(menu, {
		title = Lang:t('menu.team2'),
		description = Lang:t('menu.team2_desc'),
		event = confirmEvent,
		args = { team = 'team2' },
		icon = 'fas fa-users',
		iconColor = '#e74c3c',
	})

	return menu
end

function Menu.BuildLoadoutMenu()
    local loadoutMenu = {}

	Menu.AppendLoadoutOptions(loadoutMenu, 'matti-airsoft:selectLoadout')

	Menu.AddOption(loadoutMenu, {
		title = Lang:t('menu.random_loadout'),
		description = Lang:t('menu.random_loadout_txt'),
		event = 'matti-airsoft:giveRandomGun',
		icon = 'fas fa-random',
		iconColor = '#EC213A',
	})

    return loadoutMenu
end

function Menu.ShowLoadout()
	Menu.Open('matti_airsoft_loadout_menu', Lang:t('menu.choose_loadout'), Menu.BuildLoadoutMenu())
end

-- ============================================
-- Event Handlers - Lobby System
-- ============================================

RegisterNetEvent('matti-airsoft:openLobbyMenu', function()
	-- Check if player is already in a lobby
	QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerLobby', function(lobby)
		if lobby then
			-- Player is in a lobby, open lobby management
			State.currentLobby = lobby
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

	Menu.AddOption(browserMenu, {
		title = Lang:t('menu.create_lobby'),
		description = Lang:t('menu.create_lobby_desc'),
		event = 'matti-airsoft:createLobbyPrompt',
		icon = 'fas fa-plus',
		iconColor = '#2ecc71',
	})

	-- Get available lobbies
	QBCore.Functions.TriggerCallback('matti-airsoft:getLobbies', function(data)
		local lobbies = data.lobbies or {}
		local arenaOccupied = data.arenaOccupied or false
		
		-- Show arena status if occupied
		if arenaOccupied then
			Menu.AddOption(browserMenu, {
				title = '🔴 ' .. Lang:t('menu.arena_status'),
				description = Lang:t('menu.arena_occupied_warning'),
				icon = 'fas fa-exclamation-triangle',
				iconColor = '#e74c3c',
				disabled = true,
			})
		end
		
		if #lobbies > 0 then
			if Menu.IsQbMenu() then
				Menu.AddOption(browserMenu, {
					title = Lang:t('menu.available_lobbies'),
					isHeader = true,
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
				
				Menu.AddOption(browserMenu, {
					title = lobbyInfo,
					description = lobbyDesc,
					event = 'matti-airsoft:joinLobbyConfirm',
					args = { lobbyId = lobby.id },
					icon = 'fas fa-users',
					iconColor = lobby.isInArena and '#e74c3c' or '#3498db',
				})
			end
		else
			Menu.AddOption(browserMenu, {
				title = Lang:t('menu.no_lobbies'),
				description = Lang:t('menu.no_lobbies_desc'),
				icon = 'fas fa-info-circle',
				iconColor = '#95a5a6',
				disabled = true,
			})
		end

		Menu.AddOption(browserMenu, {
			title = Lang:t('menu.refresh'),
			description = Lang:t('menu.refresh_desc'),
			event = 'matti-airsoft:openLobbyBrowser',
			icon = 'fas fa-sync',
			iconColor = '#95a5a6',
		})

		Menu.Open('matti_airsoft_lobby_browser', Lang:t('menu.lobby_browser'), browserMenu)
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


RegisterNetEvent('matti-airsoft:lobbyCreated', function(lobby)
	State.currentLobby = lobby
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Lobby updated - refresh if viewing
RegisterNetEvent('matti-airsoft:lobbyUpdated', function(lobby)
	State.currentLobby = lobby
	-- If management menu is open, refresh it
	if Config.MenuSystem == 'ox_lib' then
		local currentMenu = lib.getOpenContextMenu()
		if currentMenu == 'matti_airsoft_lobby_management' then
			TriggerEvent('matti-airsoft:openLobbyManagement')
		end
	end
end)

-- Lobby closed - return to browser
RegisterNetEvent('matti-airsoft:lobbyClosed', function()
	State.currentLobby = nil
	Utils.SendNotification(Lang:t('notifications.lobby_left'), 'info')
end)


-- Open lobby management (for players in a lobby)
RegisterNetEvent('matti-airsoft:openLobbyManagement', function()
	if not State.currentLobby then return end
	
	local managementMenu = {}
	local isHost = State.currentLobby.host == GetPlayerServerId(PlayerId())

	if Menu.IsQbMenu() then
		Menu.AddOption(managementMenu, {
			title = State.currentLobby.name,
			description = Lang:t('menu.players') .. ': ' .. Utils.TableCount(State.currentLobby.players),
			isHeader = true,
		})
	end

	-- Player list
	local playerListText = ''
	for playerId, playerData in pairs(State.currentLobby.players) do
		local hostMarker = (playerId == State.currentLobby.host) and ' 👑' or ''
		playerListText = playerListText .. playerData.name .. hostMarker .. '\n'
	end

	Menu.AddOption(managementMenu, {
		title = Lang:t('menu.players_list'),
		description = playerListText,
		icon = 'fas fa-users',
		iconColor = '#3498db',
		disabled = true,
	})

	if isHost then
		local currentModeText = State.currentLobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')
		Menu.AddOption(managementMenu, {
			title = Lang:t('menu.game_mode'),
			description = Lang:t('menu.current_mode') .. ': ' .. currentModeText,
			event = 'matti-airsoft:selectGameMode',
			icon = 'fas fa-gamepad',
			iconColor = '#3498db',
		})

		local currentLoadoutText = State.currentLobby.selectedLoadout and State.currentLobby.selectedLoadout.name or Lang:t('menu.no_loadout')
		Menu.AddOption(managementMenu, {
			title = Lang:t('menu.select_lobby_loadout'),
			description = Lang:t('menu.current_loadout') .. ': ' .. currentLoadoutText,
			event = 'matti-airsoft:selectLobbyLoadout',
			icon = 'fas fa-crosshairs',
			iconColor = '#e74c3c',
		})

		Menu.AddOption(managementMenu, {
			title = Lang:t('menu.start_game'),
			description = Lang:t('menu.start_game_desc'),
			event = 'matti-airsoft:startLobbyGame',
			icon = 'fas fa-play',
			iconColor = '#2ecc71',
		})
	else
		local currentModeText = State.currentLobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')
		local currentLoadoutText = State.currentLobby.selectedLoadout and State.currentLobby.selectedLoadout.name or Lang:t('menu.no_loadout')

		Menu.AddOption(managementMenu, {
			title = Lang:t('menu.lobby_settings'),
			description = Lang:t('menu.game_mode') .. ': ' .. currentModeText .. '\n' .. Lang:t('menu.loadout') .. ': ' .. currentLoadoutText,
			icon = 'fas fa-info-circle',
			iconColor = '#95a5a6',
			disabled = true,
		})
	end

	if State.currentLobby.gameMode == 'teams' then
		Menu.AddOption(managementMenu, {
			title = Lang:t('menu.select_team'),
			description = Lang:t('menu.select_team_desc'),
			event = 'matti-airsoft:selectTeam',
			icon = 'fas fa-users',
			iconColor = '#9b59b6',
		})
	end

	Menu.AddOption(managementMenu, {
		title = Lang:t('menu.leave_lobby'),
		description = Lang:t('menu.leave_lobby_desc'),
		event = 'matti-airsoft:confirmLeaveLobby',
		icon = 'fas fa-door-open',
		iconColor = '#e74c3c',
	})

	Menu.Open('matti_airsoft_lobby_management', State.currentLobby.name, managementMenu)
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

	Menu.AddOption(gameModeMenu, {
		title = Lang:t('menu.ffa'),
		description = Lang:t('menu.ffa_desc'),
		event = 'matti-airsoft:setGameMode',
		args = { mode = 'ffa' },
		icon = 'fas fa-user',
		iconColor = '#f39c12',
	})

	Menu.AddOption(gameModeMenu, {
		title = Lang:t('menu.teams'),
		description = Lang:t('menu.teams_desc'),
		event = 'matti-airsoft:setGameMode',
		args = { mode = 'teams' },
		icon = 'fas fa-users',
		iconColor = '#9b59b6',
	})

	Menu.AddOption(gameModeMenu, {
		title = Lang:t('menu.back'),
		event = 'matti-airsoft:openLobbyManagement',
		icon = 'fas fa-arrow-left',
		iconColor = '#95a5a6',
	})

	Menu.Open('matti_airsoft_gamemode_menu', Lang:t('menu.select_game_mode'), gameModeMenu, 'matti_airsoft_lobby_management')
end)


RegisterNetEvent('matti-airsoft:setGameMode', function(data)
	TriggerServerEvent('matti-airsoft:setGameMode', data.mode)
	Utils.SendNotification(Lang:t('notifications.game_mode_set') .. ' ' .. (data.mode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')), 'success')
	Wait(500)
	-- Return to lobby management
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Event to select loadout for lobby
RegisterNetEvent('matti-airsoft:selectLobbyLoadout')
AddEventHandler('matti-airsoft:selectLobbyLoadout', function()
	local loadoutMenu = {}

	Menu.AppendLoadoutOptions(loadoutMenu, 'matti-airsoft:setLobbyLoadout')

	Menu.AddOption(loadoutMenu, {
		title = Lang:t('menu.random_loadout'),
		description = Lang:t('menu.random_loadout_txt'),
		event = 'matti-airsoft:setRandomLobbyLoadout',
		icon = 'fas fa-random',
		iconColor = '#EC213A',
	})

	Menu.AddOption(loadoutMenu, {
		title = Lang:t('menu.back'),
		event = 'matti-airsoft:openLobbyManagement',
		icon = 'fas fa-arrow-left',
		iconColor = '#95a5a6',
	})

	Menu.Open('matti_airsoft_lobby_loadout_menu', Lang:t('menu.select_lobby_loadout'), loadoutMenu, 'matti_airsoft_lobby_management')
end)


RegisterNetEvent('matti-airsoft:setLobbyLoadout', function(data)
	TriggerServerEvent('matti-airsoft:setLobbyLoadout', data.loadout)
	Utils.SendNotification(Lang:t('notifications.lobby_loadout_set') .. ' ' .. data.loadout.name, 'success')
	Wait(500)
	-- Return to lobby management
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Event to set random loadout for lobby
RegisterNetEvent('matti-airsoft:setRandomLobbyLoadout', function()
	local randomIndex = math.random(1, #Config.Loadouts)
	local randomLoadout = Config.Loadouts[randomIndex]
	TriggerServerEvent('matti-airsoft:setLobbyLoadout', randomLoadout)
	Utils.SendNotification(Lang:t('notifications.lobby_loadout_set') .. ' ' .. randomLoadout.name, 'success')
	Wait(500)
	-- Return to lobby management
	TriggerEvent('matti-airsoft:openLobbyManagement')
end)

-- Host starts the game
RegisterNetEvent('matti-airsoft:startLobbyGame', function()
	-- Check if in teams mode and if player has selected a team
	if State.currentLobby and State.currentLobby.gameMode == 'teams' then
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
	Menu.Open('matti_airsoft_team_menu', Lang:t('menu.select_team'), Menu.BuildTeamSelectionMenu('matti-airsoft:confirmTeamSelection'))
end)


-- Confirm team selection
RegisterNetEvent('matti-airsoft:confirmTeamSelection', function(data)
	TriggerServerEvent('matti-airsoft:setPlayerTeam', data.team)
	-- Don't auto-start game - wait for host to start
	Utils.SendNotification(Lang:t('notifications.team_selected') .. ' ' .. (data.team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

-- Game is starting (triggered by server for all lobby players)
RegisterNetEvent('matti-airsoft:gameStarting', function(loadout, gameMode)
	if not loadout then
		Utils.SendNotification(Lang:t('notifications.select_loadout_first'), 'error')
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
				Loadout.Handle(loadout)
			end
		end)
	else
		-- FFA mode, just apply loadout
		Loadout.Handle(loadout)
	end
end)

-- Team selection before play (for non-host players)
RegisterNetEvent('matti-airsoft:selectTeamBeforePlay')
AddEventHandler('matti-airsoft:selectTeamBeforePlay', function()
	Menu.Open('matti_airsoft_team_select_play', Lang:t('menu.select_team'), Menu.BuildTeamSelectionMenu('matti-airsoft:confirmTeamBeforePlay'))
end)


-- Confirm team selection and start playing
RegisterNetEvent('matti-airsoft:confirmTeamBeforePlay', function(data)
	TriggerServerEvent('matti-airsoft:setPlayerTeam', data.team)
	-- Don't auto-apply loadout - just confirm team selection
	Utils.SendNotification(Lang:t('notifications.team_selected') .. ' ' .. (data.team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
	-- Now apply the loadout after team is set
	Wait(500)
	if State.currentLobby and State.currentLobby.selectedLoadout then
		Loadout.Handle(State.currentLobby.selectedLoadout)
	end
end)

-- ============================================
-- Event Handlers - Standard Events
-- ============================================

RegisterNetEvent('matti-airsoft:client:removeWeaponFromPed', function(weaponName)
    local weaponHash = GetHashKey(weaponName)
    if weaponHash and weaponHash ~= 0 and HasPedGotWeapon(PlayerPedId(), weaponHash, false) then
        RemoveWeaponFromPed(PlayerPedId(), weaponHash)
    end
end)

RegisterNetEvent('matti-airsoft:openLoadoutMenu', function()
    Menu.ShowLoadout()
end)

RegisterNetEvent('matti-airsoft:teleportOnly', function()
    Player.TeleportToRandomPosition()
end)

RegisterNetEvent('matti-airsoft:giveRandomGun', function()
    local randomIndex = math.random(1, #Config.Loadouts)
    Loadout.Handle(Config.Loadouts[randomIndex])
end)

RegisterNetEvent('matti-airsoft:selectLoadout', function(data)
    Loadout.Handle(data.loadout)
end)

RegisterNetEvent('matti-airsoft:exitArena', function()
    Loadout.Remove()
    Inventory.Restore()
    SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
end)

RegisterNetEvent('matti-airsoft:checkIfInArena', function(adminId)
    local isInArena = State.airsoftZone:isPointInside(GetEntityCoords(PlayerPedId()))
    TriggerServerEvent('matti-airsoft:reportArenaStatus', adminId, isInArena)
end)

RegisterNetEvent('matti-airsoft:forceExitArena', function()
    if State.airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) then
        Loadout.Remove()
        Inventory.Restore()
        SetEntityCoords(PlayerPedId(), Config.ReturnLocation)
        Utils.SendNotification(Lang:t('notifications.force_exit'), 'error')
    end
end)

RegisterNetEvent('matti-airsoft:updateLeaderboard', function(leaderboard)
    if State.leaderboardVisible and State.isInArena then
        SendNUIMessage({
            action = 'updateLeaderboard',
            leaderboard = leaderboard
        })
    end
end)

RegisterNUICallback('closeLeaderboard', function(data, cb)
    cb('ok')
end)

-- ============================================
-- Initialization
-- ============================================
Citizen.CreateThread(function()
    Zone.Create()
    
    State.enterPed = Peds.Spawn(
        GetHashKey(Config.EnterLocation.model),
        Config.EnterLocation.coords,
        'matti-airsoft:openLobbyMenu',
        'fas fa-users',
        Lang:t('menu.open_lobby')
    )

    State.exitPed = Peds.Spawn(
        GetHashKey(Config.ExitLocation.model),
        Config.ExitLocation.coords,
        'matti-airsoft:exitArena',
        'fas fa-door-open',
        Lang:t('menu.exit_arena')
    )

    Blip.Create()

    if Config.Debug then
        for _, loc in ipairs(Config.SpawnLocations) do
            local ped = CreatePed(4, GetHashKey(Config.EnterLocation.model), loc.x, loc.y, loc.z - 1.0, 0.0, false, true)
            SetEntityAlpha(ped, 100, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            table.insert(State.debugPeds, ped)
        end
    end
    
    Combat.TrackDamage()
end)
