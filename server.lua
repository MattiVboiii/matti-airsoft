-- ============================================
-- Matti Airsoft - Server Script (Refactored)
-- ============================================

lib.versionCheck('MattiVboiii/matti-airsoft')

-- ============================================
-- Framework Detection
-- ============================================
local framework = GetResourceState('qb-core') == 'started' and 'qb' or GetResourceState('ox_core') == 'started' and 'ox' or 'qb'
local QBCore

if Config.Framework == 'ox' then
    lib = exports.ox_core:GetCoreObject()
else
    QBCore = exports['qb-core']:GetCoreObject()
end

-- ============================================
-- Data Structures
-- ============================================
local Data = {
    arenaStats = {}, -- {[playerId] = {name, kills, deaths}}
    lobbies = {}, -- {[lobbyId] = {host, players, gameMode, loadout, name}}
    playerLobbies = {}, -- {[playerId] = lobbyId}
    playerTeams = {}, -- {[playerId] = 'team1' or 'team2'}
    activeLobbyInArena = nil,
    nextLobbyId = 1
}

-- ============================================
-- Utility Functions
-- ============================================
local Utils = {}

function Utils.GetPlayer(playerId)
    if Config.Framework == 'ox' then
        return lib.GetPlayer(playerId)
    else
        return QBCore.Functions.GetPlayer(playerId)
    end
end

function Utils.GetPlayerName(playerId)
    local player = Utils.GetPlayer(playerId)
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

function Utils.HandlePlayerItem(playerId, itemName, amount, action)
    local player = Utils.GetPlayer(playerId)
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

function Utils.RemoveWeaponFromPed(playerId, weaponName)
    if not playerId or not weaponName then
        return false
    end
    TriggerClientEvent('matti-airsoft:client:removeWeaponFromPed', playerId, weaponName)
    return true
end


-- ============================================
-- Lobby Management
-- ============================================
local Lobby = {}

function Lobby.GetPlayerCount(lobby)
    local count = 0
    for _ in pairs(lobby.players) do
        count = count + 1
    end
    return count
end

function Lobby.Create(playerId, lobbyName)
    local playerName = Utils.GetPlayerName(playerId)
    
    if Data.playerLobbies[playerId] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.already_in_lobby'), 'error')
        return nil
    end
    
    local lobbyId = Data.nextLobbyId
    Data.nextLobbyId = Data.nextLobbyId + 1
    
    Data.lobbies[lobbyId] = {
        id = lobbyId,
        name = lobbyName or (playerName .. "'s Lobby"),
        host = playerId,
        players = {
            [playerId] = {id = playerId, name = playerName}
        },
        gameMode = 'ffa',
        selectedLoadout = nil,
        maxPlayers = 16
    }
    
    Data.playerLobbies[playerId] = lobbyId
    
    if Config.Debug then
        print(' Lobby created: ' .. lobbyId .. ' by ' .. playerName)
    end
    
    return Data.lobbies[lobbyId]
end

function Lobby.Join(playerId, lobbyId)
    local playerName = Utils.GetPlayerName(playerId)
    
    if Data.playerLobbies[playerId] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.already_in_lobby'), 'error')
        return false
    end
    
    if not Data.lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.lobby_not_found'), 'error')
        return false
    end
    
    local lobby = Data.lobbies[lobbyId]
    
    if Lobby.GetPlayerCount(lobby) >= lobby.maxPlayers then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.lobby_full'), 'error')
        return false
    end
    
    lobby.players[playerId] = {id = playerId, name = playerName}
    Data.playerLobbies[playerId] = lobbyId
    
    if Config.Debug then
        print(' ' .. playerName .. ' joined lobby: ' .. lobbyId)
    end
    
    for pid, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', pid, lobby)
    end
    
    return true
end

function Lobby.Leave(playerId)
    local lobbyId = Data.playerLobbies[playerId]
    
    if not lobbyId or not Data.lobbies[lobbyId] then
        return false
    end
    
    local lobby = Data.lobbies[lobbyId]
    local playerName = Utils.GetPlayerName(playerId)
    
    lobby.players[playerId] = nil
    Data.playerLobbies[playerId] = nil
    
    if Config.Debug then
        print(' ' .. playerName .. ' left lobby: ' .. lobbyId)
    end
    
    if Lobby.GetPlayerCount(lobby) == 0 then
        Data.lobbies[lobbyId] = nil
        if Config.Debug then
            print(' Lobby ' .. lobbyId .. ' deleted (empty)')
        end
    else
        if lobby.host == playerId then
            for pid, _ in pairs(lobby.players) do
                lobby.host = pid
                TriggerClientEvent('matti-airsoft:sendNotification', pid, Lang:t('notifications.you_are_host'), 'info')
                break
            end
        end
        
        for pid, _ in pairs(lobby.players) do
            TriggerClientEvent('matti-airsoft:lobbyUpdated', pid, lobby)
        end
    end
    
    TriggerClientEvent('matti-airsoft:lobbyClosed', playerId)
    return true
end

function Lobby.SetGameMode(playerId, mode)
    local lobbyId = Data.playerLobbies[playerId]
    
    if not lobbyId or not Data.lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.not_in_lobby'), 'error')
        return false
    end
    
    local lobby = Data.lobbies[lobbyId]
    
    if lobby.host ~= playerId then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.not_host'), 'error')
        return false
    end
    
    lobby.gameMode = mode
    
    if Config.Debug then
        print(' Lobby ' .. lobbyId .. ' game mode set to: ' .. mode)
    end
    
    for pid, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', pid, lobby)
    end
    
    return true
end

function Lobby.SetLoadout(playerId, loadout)
    local lobbyId = Data.playerLobbies[playerId]
    
    if not lobbyId or not Data.lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.not_in_lobby'), 'error')
        return false
    end
    
    local lobby = Data.lobbies[lobbyId]
    
    if lobby.host ~= playerId then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.not_host'), 'error')
        return false
    end
    
    lobby.selectedLoadout = loadout
    
    if Config.Debug then
        print(' Lobby ' .. lobbyId .. ' loadout set to: ' .. (loadout and loadout.name or 'None'))
    end
    
    for pid, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', pid, lobby)
    end
    
    return true
end

function Lobby.StartGame(playerId)
    local lobbyId = Data.playerLobbies[playerId]
    
    if not lobbyId or not Data.lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.not_in_lobby'), 'error')
        return false
    end
    
    local lobby = Data.lobbies[lobbyId]
    
    if lobby.host ~= playerId then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.not_host'), 'error')
        return false
    end
    
    if not lobby.selectedLoadout then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.select_loadout_first'), 'error')
        return false
    end
    
    if Data.activeLobbyInArena and Data.activeLobbyInArena ~= lobbyId and Data.lobbies[Data.activeLobbyInArena] then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.arena_occupied'), 'error')
        return false
    end
    
    Data.activeLobbyInArena = lobbyId
    
    for pid, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:gameStarting', pid, lobby.selectedLoadout, lobby.gameMode)
    end
    
    if Config.Debug then
        print(' Game started in lobby: ' .. lobbyId)
        print(' Arena occupied by lobby: ' .. lobbyId)
        print(' Game mode: ' .. lobby.gameMode)
    end
    
    return true
end


-- ============================================
-- Leaderboard Management
-- ============================================
local Leaderboard = {}

function Leaderboard.AddPlayer(playerId)
    if not Data.arenaStats[playerId] then
        Data.arenaStats[playerId] = {
            name = Utils.GetPlayerName(playerId),
            kills = 0,
            deaths = 0
        }
    end
    Leaderboard.Broadcast()
end

function Leaderboard.RemovePlayer(playerId)
    Data.arenaStats[playerId] = nil
    
    local lobbyId = Data.playerLobbies[playerId]
    if lobbyId and Data.activeLobbyInArena == lobbyId then
        local lobby = Data.lobbies[lobbyId]
        if lobby then
            local anyPlayerInArena = false
            for pid, _ in pairs(lobby.players) do
                if Data.arenaStats[pid] then
                    anyPlayerInArena = true
                    break
                end
            end
            
            if not anyPlayerInArena then
                Data.activeLobbyInArena = nil
                if Config.Debug then
                    print(' Arena cleared - lobby ' .. lobbyId .. ' has no more players in arena')
                end
            end
        end
    end
    
    Leaderboard.Broadcast()
end

function Leaderboard.RecordHit(victimId, killerId)
    local victimName = Data.arenaStats[victimId] and Data.arenaStats[victimId].name or 'Unknown'
    local killerName = 'Unknown'
    
    if Data.arenaStats[victimId] then
        Data.arenaStats[victimId].deaths = Data.arenaStats[victimId].deaths + 1
    end
    
    if killerId and killerId ~= victimId and Data.arenaStats[killerId] then
        Data.arenaStats[killerId].kills = Data.arenaStats[killerId].kills + 1
        killerName = Data.arenaStats[killerId].name
    end
    
    if Config.Debug then
        if killerId and killerId ~= victimId then
            print(' ' .. victimName .. ' was hit by ' .. killerName)
        else
            print(' ' .. victimName .. ' was hit')
        end
    end
    
    Leaderboard.Broadcast()
end

function Leaderboard.Broadcast()
    local leaderboard = {}
    
    for playerId, stats in pairs(Data.arenaStats) do
        table.insert(leaderboard, {
            name = stats.name,
            kills = stats.kills,
            deaths = stats.deaths,
            kd = stats.deaths > 0 and (stats.kills / stats.deaths) or stats.kills,
            team = Data.playerTeams[playerId] or nil
        })
    end
    
    TriggerClientEvent('matti-airsoft:updateLeaderboard', -1, leaderboard)
end

function Leaderboard.Get()
    local leaderboard = {}
    
    for playerId, stats in pairs(Data.arenaStats) do
        table.insert(leaderboard, {
            name = stats.name,
            kills = stats.kills,
            deaths = stats.deaths,
            kd = stats.deaths > 0 and (stats.kills / stats.deaths) or stats.kills,
            team = Data.playerTeams[playerId] or nil
        })
    end
    
    return leaderboard
end

-- ============================================
-- Event Handlers
-- ============================================

-- Lobby Events
RegisterNetEvent('matti-airsoft:createLobby', function(lobbyName)
    local lobby = Lobby.Create(source, lobbyName)
    if lobby then
        TriggerClientEvent('matti-airsoft:lobbyCreated', source, lobby)
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.lobby_created'), 'success')
    end
end)

RegisterNetEvent('matti-airsoft:joinLobby', function(lobbyId)
    if Lobby.Join(source, lobbyId) then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.lobby_joined'), 'success')
    end
end)

RegisterNetEvent('matti-airsoft:leaveLobby', function()
    Lobby.Leave(source)
end)

RegisterNetEvent('matti-airsoft:setGameMode', function(mode)
    Lobby.SetGameMode(source, mode)
end)

RegisterNetEvent('matti-airsoft:setLobbyLoadout', function(loadout)
    Lobby.SetLoadout(source, loadout)
end)

RegisterNetEvent('matti-airsoft:startLobbyGame', function()
    Lobby.StartGame(source)
end)

-- Team Events
RegisterNetEvent('matti-airsoft:setPlayerTeam', function(team)
    local lobbyId = Data.playerLobbies[source]
    
    if not lobbyId or not Data.lobbies[lobbyId] then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.not_in_lobby'), 'error')
        return
    end
    
    local lobby = Data.lobbies[lobbyId]
    
    if lobby.gameMode ~= 'teams' then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.not_teams_mode'), 'error')
        return
    end
    
    Data.playerTeams[source] = team
    
    if Config.Debug then
        print(' Player ' .. source .. ' set to ' .. team)
    end
    
    TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.team_selected') .. ' ' .. (team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

-- Arena Events
RegisterNetEvent('matti-airsoft:playerEnteredArena', function()
    Leaderboard.AddPlayer(source)
end)

RegisterNetEvent('matti-airsoft:playerLeftArena', function()
    Leaderboard.RemovePlayer(source)
end)

RegisterNetEvent('matti-airsoft:playerWasHit', function(killerId)
    Leaderboard.RecordHit(source, killerId)
end)

-- Revive Event
RegisterServerEvent('matti-airsoft:revivePlayer', function()
    if Config.Framework == 'ox' then
        local player = exports.ox_core:GetPlayer(source)
        if player then
            player.revive()
        end
    else
        exports.qbx_medical:Revive(source)
    end
    
    if Config.Debug then
        print(' Player ' .. source .. ' revived in arena')
    end
end)

-- Item/Weapon Events
RegisterServerEvent('matti-airsoft:giveWeapon', function(weaponName)
    Utils.HandlePlayerItem(source, weaponName, 1, 'add')
end)

RegisterServerEvent('matti-airsoft:giveItem', function(itemName, amount)
    Utils.HandlePlayerItem(source, itemName, amount, 'add')
end)

RegisterServerEvent('matti-airsoft:removeWeapon', function(weaponName)
    Utils.HandlePlayerItem(source, weaponName, 1, 'remove')
    Utils.RemoveWeaponFromPed(source, weaponName)
end)

RegisterServerEvent('matti-airsoft:removeItem', function(itemName, amount)
    Utils.HandlePlayerItem(source, itemName, amount, 'remove')
end)

-- Debug Events
RegisterServerEvent('matti-airsoft:debugZoneEntry', function(playerName, action)
    if Config.Debug then
        print(playerName .. ' has ' .. action .. ' the airsoft zone.')
    end
end)

RegisterNetEvent('matti-airsoft:reportArenaStatus', function(adminId, isInArena)
    if isInArena then
        TriggerClientEvent('matti-airsoft:forceExitArena', source)
        TriggerClientEvent('matti-airsoft:sendNotification', adminId, Lang:t('command.player_removed'), 'success')
    else
        TriggerClientEvent('matti-airsoft:sendNotification', adminId, Lang:t('command.player_not_in_arena'), 'error')
    end
end)

-- ============================================
-- Callbacks
-- ============================================

QBCore.Functions.CreateCallback('matti-airsoft:canAffordLoadout', function(source, cb, price)
    local player = Utils.GetPlayer(source)
    if not player then 
        cb(false)
        return
    end

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

QBCore.Functions.CreateCallback('matti-airsoft:getPlayerTeam', function(source, cb)
    cb(Data.playerTeams[source] or nil)
end)

QBCore.Functions.CreateCallback('matti-airsoft:getLobbies', function(source, cb)
    local availableLobbies = {}
    for lobbyId, lobby in pairs(Data.lobbies) do
        table.insert(availableLobbies, {
            id = lobby.id,
            name = lobby.name,
            host = Utils.GetPlayerName(lobby.host),
            playerCount = Lobby.GetPlayerCount(lobby),
            maxPlayers = lobby.maxPlayers,
            gameMode = lobby.gameMode,
            isInArena = (Data.activeLobbyInArena == lobbyId)
        })
    end
    cb({
        lobbies = availableLobbies,
        arenaOccupied = Data.activeLobbyInArena ~= nil
    })
end)

QBCore.Functions.CreateCallback('matti-airsoft:getPlayerLobby', function(source, cb)
    local lobbyId = Data.playerLobbies[source]
    if lobbyId and Data.lobbies[lobbyId] then
        cb(Data.lobbies[lobbyId])
    else
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('matti-airsoft:getLeaderboard', function(source, cb)
    cb(Leaderboard.Get())
end)

-- ============================================
-- Commands
-- ============================================

QBCore.Commands.Add(
    'exitarena',
    Lang:t('command.description_exitarena'),
    { { name = 'id', help = Lang:t('command.help_exitarena') } },
    false,
    function(source, args)
        if args[1] == 'all' then
            local removedCount = 0
            for playerId, _ in pairs(Data.arenaStats) do
                TriggerClientEvent('matti-airsoft:forceExitArena', playerId)
                Data.arenaStats[playerId] = nil
                removedCount = removedCount + 1
            end
            Leaderboard.Broadcast()
            TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.all_players_removed'), 'success')
            if Config.Debug then
                print(' Admin ' .. source .. ' removed all players from arena (' .. removedCount .. ' players)')
            end
        else
            local playerId = tonumber(args[1]) or source
            if playerId then
                local targetPlayer = QBCore.Functions.GetPlayer(playerId)
                if targetPlayer then
                    TriggerClientEvent('matti-airsoft:checkIfInArena', playerId, source)
                else
                    TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
                end
            else
                TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
            end
        end
    end,
    'admin'
)

-- ============================================
-- Cleanup
-- ============================================

AddEventHandler('playerDropped', function()
    local src = source
    
    if Data.arenaStats[src] then
        Data.arenaStats[src] = nil
        Leaderboard.Broadcast()
    end
    
    local lobbyId = Data.playerLobbies[src]
    if lobbyId and Data.lobbies[lobbyId] then
        Lobby.Leave(src)
    end
end)

