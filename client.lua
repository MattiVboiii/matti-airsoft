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

function Combat.TrackDamage()
    AddEventHandler('gameEventTriggered', function(event, data)
        if event == 'CEventNetworkEntityDamage' then
            local victim = data[1]
            local attacker = data[2]
            local playerPed = PlayerPedId()
            
            if victim == playerPed and State.isInArena then
                if attacker and attacker ~= 0 and attacker ~= playerPed then
                    if IsPedAPlayer(attacker) then
                        local attackerPlayerId = NetworkGetPlayerIndexFromPed(attacker)
                        if attackerPlayerId and attackerPlayerId ~= -1 then
                            State.lastAttacker = GetPlayerServerId(attackerPlayerId)
                            if Config.Debug then
                                print(' Damage detected from player server ID: ' .. tostring(State.lastAttacker))
                            end
                        end
                    end
                end
            end
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
                    
                    local killerId = nil
                    local killerPed = GetPedSourceOfDeath(playerPed)
                    
                    if killerPed and killerPed ~= 0 and killerPed ~= playerPed then
                        if IsPedAPlayer(killerPed) then
                            local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
                            if killerPlayerId and killerPlayerId ~= -1 then
                                killerId = GetPlayerServerId(killerPlayerId)
                            end
                        end
                    end
                    
                    if not killerId and State.lastAttacker then
                        killerId = State.lastAttacker
                        if Config.Debug then
                            print(' Using lastAttacker for killer ID: ' .. tostring(killerId))
                        end
                    end
                    
                    if Config.Debug then
                        local stunStatus = IsPedBeingStunned(playerPed, 0) and "STUNNED" or "DEAD"
                        print(' Player was hit (' .. stunStatus .. '). Killer Ped: ' .. tostring(killerPed) .. ', Killer server ID: ' .. tostring(killerId))
                    end
                    
                    TriggerServerEvent('matti-airsoft:playerWasHit', killerId)
                    State.lastAttacker = nil
                    
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

function Menu.BuildLoadoutMenu()
    local loadoutMenu = {}

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
                    event = 'matti-airsoft:selectLoadout',
                    args = { loadout = loadout },
                },
            })
        elseif Config.MenuSystem == 'ox_lib' then
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

    return loadoutMenu
end

function Menu.ShowLoadout()
    local loadoutMenu = Menu.BuildLoadoutMenu()
    
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

	-- Lobby info header
	if Config.MenuSystem == 'qb-menu' then
		table.insert(managementMenu, {
			header = State.currentLobby.name,
			txt = Lang:t('menu.players') .. ': ' .. Utils.TableCount(State.currentLobby.players),
			isMenuHeader = true
		})
	end

	-- Player list
	local playerListText = ''
	for playerId, playerData in pairs(State.currentLobby.players) do
		local hostMarker = (playerId == State.currentLobby.host) and ' 👑' or ''
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

	if isHost then
		local currentModeText = State.currentLobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')
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
		local currentLoadoutText = State.currentLobby.selectedLoadout and State.currentLobby.selectedLoadout.name or Lang:t('menu.no_loadout')
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
		local currentModeText = State.currentLobby.gameMode == 'ffa' and Lang:t('menu.ffa') or Lang:t('menu.teams')
		local currentLoadoutText = State.currentLobby.selectedLoadout and State.currentLobby.selectedLoadout.name or Lang:t('menu.no_loadout')
		
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
	if State.currentLobby.gameMode == 'teams' then
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
			title = State.currentLobby.name,
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
