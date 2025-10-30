lib.versionCheck('MattiVboiii/matti-airsoft')
-- Framework detection
local framework = GetResourceState('qb-core') == 'started' and 'qb' or GetResourceState('ox_core') == 'started' and 'ox' or 'qb'
if Config.Framework == 'ox' then
    lib = exports.ox_core:GetCoreObject()
else
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Update GetPlayer function to handle both frameworks
local function GetPlayer(playerId)
    if Config.Framework == 'ox' then
        return lib.GetPlayer(playerId)
    else
        return QBCore.Functions.GetPlayer(playerId)
    end
end

-- Kill tracking system
local arenaStats = {} -- Table to store player stats: {[playerId] = {name = "", kills = 0, deaths = 0}}

-- Multi-player Lobby system
local lobbies = {} -- Table to store all lobbies: {[lobbyId] = {host, players, gameMode, loadout, name}}
local playerLobbies = {} -- Track which lobby each player is in: {[playerId] = lobbyId}
local playerTeams = {} -- Track which team each player is in: {[playerId] = 'team1' or 'team2'}
local activeLobbyInArena = nil -- Track which lobby is currently playing in the arena
local nextLobbyId = 1

-- Utility function to get player name
local function GetPlayerNameForLobby(playerId)
    local player = GetPlayer(playerId)
    if player then
        if Config.Framework == 'ox' then
            return player.get('firstName') .. ' ' .. player.get('lastName')
        else
            if player.PlayerData and player.PlayerData.charinfo then
                return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            end
        end
    end
    return 'Player ' .. playerId
end

-- Create a new lobby
RegisterNetEvent('matti-airsoft:createLobby')
AddEventHandler('matti-airsoft:createLobby', function(lobbyName)
    local src = source
    local playerName = GetPlayerNameForLobby(src)
    
    -- Check if player is already in a lobby
    if playerLobbies[src] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.already_in_lobby'), 'error')
        return
    end
    
    local lobbyId = nextLobbyId
    nextLobbyId = nextLobbyId + 1
    
    lobbies[lobbyId] = {
        id = lobbyId,
        name = lobbyName or (playerName .. "'s Lobby"),
        host = src,
        players = {
            [src] = {id = src, name = playerName}
        },
        gameMode = 'ffa',
        selectedLoadout = nil,
        maxPlayers = 16
    }
    
    playerLobbies[src] = lobbyId
    
    if Config.Debug then
        print('[AIRSOFT] Lobby created: ' .. lobbyId .. ' by ' .. playerName)
    end
    
    TriggerClientEvent('matti-airsoft:lobbyCreated', src, lobbies[lobbyId])
    TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.lobby_created'), 'success')
end)

-- Join a lobby
RegisterNetEvent('matti-airsoft:joinLobby')
AddEventHandler('matti-airsoft:joinLobby', function(lobbyId)
    local src = source
    local playerName = GetPlayerNameForLobby(src)
    
    -- Check if player is already in a lobby
    if playerLobbies[src] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.already_in_lobby'), 'error')
        return
    end
    
    -- Check if lobby exists
    if not lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.lobby_not_found'), 'error')
        return
    end
    
    local lobby = lobbies[lobbyId]
    
    -- Check if lobby is full
    local playerCount = 0
    for _ in pairs(lobby.players) do
        playerCount = playerCount + 1
    end
    
    if playerCount >= lobby.maxPlayers then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.lobby_full'), 'error')
        return
    end
    
    -- Add player to lobby
    lobby.players[src] = {id = src, name = playerName}
    playerLobbies[src] = lobbyId
    
    if Config.Debug then
        print('[AIRSOFT] ' .. playerName .. ' joined lobby: ' .. lobbyId)
    end
    
    -- Notify all players in the lobby
    for playerId, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', playerId, lobby)
    end
    
    TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.lobby_joined'), 'success')
end)

-- Leave a lobby
RegisterNetEvent('matti-airsoft:leaveLobby')
AddEventHandler('matti-airsoft:leaveLobby', function()
    local src = source
    local lobbyId = playerLobbies[src]
    
    if not lobbyId or not lobbies[lobbyId] then
        return
    end
    
    local lobby = lobbies[lobbyId]
    local playerName = GetPlayerNameForLobby(src)
    
    -- Remove player from lobby
    lobby.players[src] = nil
    playerLobbies[src] = nil
    
    if Config.Debug then
        print('[AIRSOFT] ' .. playerName .. ' left lobby: ' .. lobbyId)
    end
    
    -- Check if lobby is now empty
    local playerCount = 0
    for _ in pairs(lobby.players) do
        playerCount = playerCount + 1
    end
    
    if playerCount == 0 then
        -- Delete empty lobby
        lobbies[lobbyId] = nil
        if Config.Debug then
            print('[AIRSOFT] Lobby ' .. lobbyId .. ' deleted (empty)')
        end
    else
        -- If host left, assign new host
        if lobby.host == src then
            for playerId, _ in pairs(lobby.players) do
                lobby.host = playerId
                TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.you_are_host'), 'info')
                break
            end
        end
        
        -- Notify remaining players
        for playerId, _ in pairs(lobby.players) do
            TriggerClientEvent('matti-airsoft:lobbyUpdated', playerId, lobby)
        end
    end
    
    TriggerClientEvent('matti-airsoft:lobbyClosed', src)
end)

-- Set game mode (host only)
RegisterNetEvent('matti-airsoft:setGameMode')
AddEventHandler('matti-airsoft:setGameMode', function(mode)
    local src = source
    local lobbyId = playerLobbies[src]
    
    if not lobbyId or not lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_in_lobby'), 'error')
        return
    end
    
    local lobby = lobbies[lobbyId]
    
    -- Check if player is host
    if lobby.host ~= src then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_host'), 'error')
        return
    end
    
    lobby.gameMode = mode
    
    if Config.Debug then
        print('[AIRSOFT] Lobby ' .. lobbyId .. ' game mode set to: ' .. mode)
    end
    
    -- Notify all players in the lobby
    for playerId, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', playerId, lobby)
    end
end)

-- Set loadout (host only)
RegisterNetEvent('matti-airsoft:setLobbyLoadout')
AddEventHandler('matti-airsoft:setLobbyLoadout', function(loadout)
    local src = source
    local lobbyId = playerLobbies[src]
    
    if not lobbyId or not lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_in_lobby'), 'error')
        return
    end
    
    local lobby = lobbies[lobbyId]
    
    -- Check if player is host
    if lobby.host ~= src then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_host'), 'error')
        return
    end
    
    lobby.selectedLoadout = loadout
    
    if Config.Debug then
        print('[AIRSOFT] Lobby ' .. lobbyId .. ' loadout set to: ' .. (loadout and loadout.name or 'None'))
    end
    
    -- Notify all players in the lobby
    for playerId, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', playerId, lobby)
    end
end)

-- Set player team (for teams mode)
RegisterNetEvent('matti-airsoft:setPlayerTeam')
AddEventHandler('matti-airsoft:setPlayerTeam', function(team)
    local src = source
    local lobbyId = playerLobbies[src]
    
    if not lobbyId or not lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_in_lobby'), 'error')
        return
    end
    
    local lobby = lobbies[lobbyId]
    
    -- Check if lobby is in teams mode
    if lobby.gameMode ~= 'teams' then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_teams_mode'), 'error')
        return
    end
    
    -- Set player's team
    playerTeams[src] = team
    
    if Config.Debug then
        print('[AIRSOFT] Player ' .. src .. ' set to ' .. team)
    end
    
    TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.team_selected') .. ' ' .. (team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

-- Get player's team
QBCore.Functions.CreateCallback('matti-airsoft:getPlayerTeam', function(source, cb)
    cb(playerTeams[source] or nil)
end)

-- Get all available lobbies
QBCore.Functions.CreateCallback('matti-airsoft:getLobbies', function(source, cb)
    local availableLobbies = {}
    for lobbyId, lobby in pairs(lobbies) do
        local playerCount = 0
        for _ in pairs(lobby.players) do
            playerCount = playerCount + 1
        end
        table.insert(availableLobbies, {
            id = lobby.id,
            name = lobby.name,
            host = GetPlayerNameForLobby(lobby.host),
            playerCount = playerCount,
            maxPlayers = lobby.maxPlayers,
            gameMode = lobby.gameMode,
            isInArena = (activeLobbyInArena == lobbyId) -- Mark if this lobby is currently in arena
        })
    end
    -- Include info about arena status
    cb({
        lobbies = availableLobbies,
        arenaOccupied = activeLobbyInArena ~= nil
    })
end)

-- Get player's current lobby
QBCore.Functions.CreateCallback('matti-airsoft:getPlayerLobby', function(source, cb)
    local lobbyId = playerLobbies[source]
    if lobbyId and lobbies[lobbyId] then
        cb(lobbies[lobbyId])
    else
        cb(nil)
    end
end)

-- Start game (host only)
RegisterNetEvent('matti-airsoft:startLobbyGame')
AddEventHandler('matti-airsoft:startLobbyGame', function()
    local src = source
    local lobbyId = playerLobbies[src]
    
    if not lobbyId or not lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_in_lobby'), 'error')
        return
    end
    
    local lobby = lobbies[lobbyId]
    
    -- Check if player is host
    if lobby.host ~= src then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.not_host'), 'error')
        return
    end
    
    -- Check if loadout is selected
    if not lobby.selectedLoadout then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.select_loadout_first'), 'error')
        return
    end
    
    -- Check if arena is already occupied by another lobby
    if activeLobbyInArena and activeLobbyInArena ~= lobbyId and lobbies[activeLobbyInArena] then
        TriggerClientEvent('matti-airsoft:sendNotification', src, Lang:t('notifications.arena_occupied'), 'error')
        return
    end
    
    -- Set this lobby as the active one in the arena
    activeLobbyInArena = lobbyId
    
    -- Start game for all players in lobby
    for playerId, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:gameStarting', playerId, lobby.selectedLoadout, lobby.gameMode)
    end
    
    if Config.Debug then
        print('[AIRSOFT] Game started in lobby: ' .. lobbyId)
        print('[AIRSOFT] Arena occupied by lobby: ' .. lobbyId)
        print('[AIRSOFT] Game mode: ' .. lobby.gameMode)
    end
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    local lobbyId = playerLobbies[src]
    
    if lobbyId and lobbies[lobbyId] then
        TriggerEvent('matti-airsoft:leaveLobby')
    end
end)

-- Utility function to get player name
local function GetPlayerNameById(playerId)
	local player = QBCore.Functions.GetPlayer(playerId)
	if player and player.PlayerData.charinfo then
		return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
	else
		return 'Unknown Player'
	end
end

-- Handle a player's item addition or removal with server-side validation
local function HandlePlayerItem(playerId, itemName, amount, action)
    local player = GetPlayer(playerId)
    if not player then return false end

    if Config.InventorySystem == 'ox_inventory' then
        if action == 'add' then
            return exports.ox_inventory:AddItem(playerId, itemName, amount)
        elseif action == 'remove' then
            return exports.ox_inventory:RemoveItem(playerId, itemName, amount)
        end
    else
        if action == 'add' then
            return player.Functions.AddItem(itemName, amount)
        elseif action == 'remove' then
            return player.Functions.RemoveItem(itemName, amount)
        end
    end
    return false
end

-- Utility function to handle weapon removal from player ped with safety checks
local function RemoveWeaponFromPlayerPed(playerId, weaponName)
	if not playerId or not weaponName then
		return false
	end

	-- Trigger client-side check and removal
	TriggerClientEvent('matti-airsoft:client:removeWeaponFromPed', playerId, weaponName)
	return true
end

-- Event to revive a player after they are killed in the airsoft zone
RegisterServerEvent('matti-airsoft:revivePlayer')
AddEventHandler('matti-airsoft:revivePlayer', function()
	local src = source
	
	if Config.Framework == 'ox' then
		-- OX Framework revive
		local player = exports.ox_core:GetPlayer(src)
		if player then
			player.revive()
		end
	else
		-- QBX revive using qbx_medical export
		exports.qbx_medical:Revive(src)
	end
	
	if Config.Debug then
		print('[AIRSOFT] Player ' .. src .. ' revived in arena')
	end
end)

-- Check if a player can afford a given loadout
QBCore.Functions.CreateCallback('matti-airsoft:canAffordLoadout', function(source, cb, price)
    local player = GetPlayer(source)
    if not player then cb(false) return end

    if Config.Framework == 'ox' then
        local money = player.getAccount('money').money
        if money >= price then
            player.removeMoney(price, 'Airsoft Loadout')
            cb(true)
        else
            cb(false)
        end
    else
        if player.Functions.RemoveMoney('cash', price, 'airsoft') then
            cb(true)
        else
            cb(false)
        end
    end
end)

-- Debugging entry point
-- Event to debug zone entry
-- This is useful for testing the zone trigger
RegisterServerEvent('matti-airsoft:debugZoneEntry')
AddEventHandler('matti-airsoft:debugZoneEntry', function(playerName, action)
	if Config.Debug then
		print(playerName .. ' has ' .. action .. ' the airsoft zone.')
	end
end)

--[[
Events for handling items and weapons
]]

-- Event to give a player a weapon
RegisterServerEvent('matti-airsoft:giveWeapon')
AddEventHandler('matti-airsoft:giveWeapon', function(weaponName)
	-- Handle the weapon addition
	HandlePlayerItem(source, weaponName, 1, 'add')
end)

-- Event to give a player an item
RegisterServerEvent('matti-airsoft:giveItem')
AddEventHandler('matti-airsoft:giveItem', function(itemName, amount)
	-- Handle the item addition
	HandlePlayerItem(source, itemName, amount, 'add')
end)

-- Event to remove a weapon from a player
RegisterServerEvent('matti-airsoft:removeWeapon')
AddEventHandler('matti-airsoft:removeWeapon', function(weaponName)
	-- Handle the weapon removal
	HandlePlayerItem(source, weaponName, 1, 'remove')
	-- Remove the weapon from the player's ped
	RemoveWeaponFromPlayerPed(source, weaponName)
end)

-- Event to remove an item from a player
RegisterServerEvent('matti-airsoft:removeItem')
AddEventHandler('matti-airsoft:removeItem', function(itemName, amount)
	-- Handle the item removal
	HandlePlayerItem(source, itemName, amount, 'remove')
end)

QBCore.Commands.Add(
	'exitarena',
	Lang:t('command.description_exitarena'),
	{ { name = 'id', help = Lang:t('command.help_exitarena') } },
	false,
	function(source, args)
		-- Parse the player ID from the arguments or default to the source
		local playerId = tonumber(args[1]) or source
		if playerId then
			-- Attempt to retrieve the target player object
			local targetPlayer = QBCore.Functions.GetPlayer(playerId)
			if targetPlayer then
				-- Trigger client event to check if the player is in the arena
				TriggerClientEvent('matti-airsoft:checkIfInArena', playerId, source)
			else
				-- Notify the source that the player ID is invalid
				TriggerClientEvent(
					'matti-airsoft:sendNotification',
					source,
					Lang:t('command.invalid_player_id'),
					'error'
				)
			end
		else
			-- Notify the source that the provided player ID is invalid
			TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
		end
	end,
	'admin'
)

-- Handle reporting of arena status to the server
RegisterNetEvent('matti-airsoft:reportArenaStatus')
AddEventHandler('matti-airsoft:reportArenaStatus', function(adminId, isInArena)
	if isInArena then
		-- Force the player to exit the arena
		TriggerClientEvent('matti-airsoft:forceExitArena', source)
		-- Send a success notification to the admin
		TriggerClientEvent('matti-airsoft:sendNotification', adminId, Lang:t('command.player_removed'), 'success')
	else
		-- Send an error notification to the admin
		TriggerClientEvent('matti-airsoft:sendNotification', adminId, Lang:t('command.player_not_in_arena'), 'error')
	end
end)

-- Kill tracking events
-- Event when player enters arena
RegisterNetEvent('matti-airsoft:playerEnteredArena')
AddEventHandler('matti-airsoft:playerEnteredArena', function()
	local src = source
	local playerName = GetPlayerNameById(src)
	
	if not arenaStats[src] then
		arenaStats[src] = {
			name = playerName,
			kills = 0,
			deaths = 0
		}
	end
	
	-- Broadcast updated leaderboard to all players in arena
	BroadcastLeaderboard()
end)

-- Event when player exits arena
RegisterNetEvent('matti-airsoft:playerLeftArena')
AddEventHandler('matti-airsoft:playerLeftArena', function()
	local src = source
	
	-- Remove player from stats
	arenaStats[src] = nil
	
	-- Check if this player's lobby was in the arena and if all players left
	local lobbyId = playerLobbies[src]
	if lobbyId and activeLobbyInArena == lobbyId then
		local lobby = lobbies[lobbyId]
		if lobby then
			-- Check if any players from this lobby are still in the arena
			local anyPlayerInArena = false
			for playerId, _ in pairs(lobby.players) do
				if arenaStats[playerId] then
					anyPlayerInArena = true
					break
				end
			end
			
			-- If no players from this lobby are in arena, clear the arena
			if not anyPlayerInArena then
				activeLobbyInArena = nil
				if Config.Debug then
					print('[AIRSOFT] Arena cleared - lobby ' .. lobbyId .. ' has no more players in arena')
				end
			end
		end
	end
	
	-- Broadcast updated leaderboard to all players in arena
	BroadcastLeaderboard()
end)

-- Event when a player is hit/killed
RegisterNetEvent('matti-airsoft:playerWasHit')
AddEventHandler('matti-airsoft:playerWasHit', function(killerId)
	local victimId = source
	local victimName = arenaStats[victimId] and arenaStats[victimId].name or 'Unknown'
	local killerName = 'Unknown'
	
	-- Update victim's deaths
	if arenaStats[victimId] then
		arenaStats[victimId].deaths = arenaStats[victimId].deaths + 1
	end
	
	-- Update killer's kills
	if killerId and killerId ~= victimId and arenaStats[killerId] then
		arenaStats[killerId].kills = arenaStats[killerId].kills + 1
		killerName = arenaStats[killerId].name
	end
	
	-- Debug logging with names
	if Config.Debug then
		if killerId and killerId ~= victimId then
			print('[AIRSOFT] ' .. victimName .. ' was hit by ' .. killerName)
		else
			print('[AIRSOFT] ' .. victimName .. ' was hit')
		end
	end
	
	-- Broadcast updated leaderboard to all players in arena
	BroadcastLeaderboard()
end)

-- Function to broadcast leaderboard to all players in arena
function BroadcastLeaderboard()
	local leaderboard = {}
	
	for playerId, stats in pairs(arenaStats) do
		table.insert(leaderboard, {
			name = stats.name,
			kills = stats.kills,
			deaths = stats.deaths,
			kd = stats.deaths > 0 and (stats.kills / stats.deaths) or stats.kills,
			team = playerTeams[playerId] or nil -- Include team if in teams mode
		})
	end
	
	-- Send to all players
	TriggerClientEvent('matti-airsoft:updateLeaderboard', -1, leaderboard)
end

-- Callback to get current leaderboard
QBCore.Functions.CreateCallback('matti-airsoft:getLeaderboard', function(source, cb)
	local leaderboard = {}
	
	for playerId, stats in pairs(arenaStats) do
		table.insert(leaderboard, {
			name = stats.name,
			kills = stats.kills,
			deaths = stats.deaths,
			kd = stats.deaths > 0 and (stats.kills / stats.deaths) or stats.kills,
			team = playerTeams[playerId] or nil -- Include team if in teams mode
		})
	end
	
	cb(leaderboard)
end)

-- Clean up stats when player disconnects
AddEventHandler('playerDropped', function()
	local src = source
	if arenaStats[src] then
		arenaStats[src] = nil
		BroadcastLeaderboard()
	end
end)

