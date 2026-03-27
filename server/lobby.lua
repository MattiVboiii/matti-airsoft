Lobby = {}

local function NormalizeModeId(mode)
    if type(mode) ~= 'string' then
        return nil
    end

    local normalized = string.lower(mode)
    if normalized == '' then
        return nil
    end

    return normalized
end

local function GetConfiguredGameModes()
    local modes = {}

    for _, mode in ipairs(Config.GameModes or {}) do
        if type(mode) == 'table' then
            local modeId = NormalizeModeId(mode.id)
            if modeId and not modes[modeId] then
                modes[modeId] = {
                    teamBased = mode.teamBased == true
                }
            end
        elseif type(mode) == 'string' then
            local modeId = NormalizeModeId(mode)
            if modeId and not modes[modeId] then
                modes[modeId] = {
                    teamBased = modeId == 'teams'
                }
            end
        end
    end

    if next(modes) == nil then
        modes.ffa = { teamBased = false }
        modes.teams = { teamBased = true }
    end

    return modes
end

function Lobby.IsAllowedGameMode(mode)
    local modeId = NormalizeModeId(mode)
    if not modeId then
        return false
    end

    return GetConfiguredGameModes()[modeId] ~= nil
end

function Lobby.IsTeamBasedMode(mode)
    local modeId = NormalizeModeId(mode)
    if not modeId then
        return false
    end

    local modeConfig = GetConfiguredGameModes()[modeId]
    return modeConfig and modeConfig.teamBased == true or false
end

function Lobby.GetDefaultGameMode()
    local configuredDefault = NormalizeModeId(Config.DefaultGameMode)
    if configuredDefault and Lobby.IsAllowedGameMode(configuredDefault) then
        return configuredDefault
    end

    if Lobby.IsAllowedGameMode('ffa') then
        return 'ffa'
    end

    local fallbackModes = GetConfiguredGameModes()
    for modeId, _ in pairs(fallbackModes) do
        return modeId
    end

    return 'ffa'
end

function Lobby.GetPlayerCount(lobby)
    local count = 0
    for _ in pairs(lobby.players) do
        count = count + 1
    end
    return count
end

function Lobby.BroadcastToLobby(lobbyId, eventName, ...)
    if not lobbyId or not Data.lobbies[lobbyId] then
        return
    end

    for pid, _ in pairs(Data.lobbies[lobbyId].players) do
        TriggerClientEvent(eventName, pid, ...)
    end
end

function Lobby.GetTeamMembers(lobbyId)
    local teamState = {
        team1 = {},
        team2 = {},
        unassigned = {}
    }

    local lobby = lobbyId and Data.lobbies[lobbyId] or nil
    if not lobby then
        return teamState
    end

    for pid, playerData in pairs(lobby.players) do
        local playerName = (playerData and playerData.name) or Utils.GetPlayerName(pid)
        local selectedTeam = Data.playerTeams[pid]

        if selectedTeam == 'team1' then
            table.insert(teamState.team1, playerName)
        elseif selectedTeam == 'team2' then
            table.insert(teamState.team2, playerName)
        else
            table.insert(teamState.unassigned, playerName)
        end
    end

    table.sort(teamState.team1)
    table.sort(teamState.team2)
    table.sort(teamState.unassigned)

    return teamState
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
            [playerId] = { id = playerId, name = playerName }
        },
        gameMode = Lobby.GetDefaultGameMode(),
        deathmatchEnabled = Config.DeathmatchEnabledByDefault ~= false,
        selectedLoadout = nil,
        matchTimer = 5 * 60, -- Default: 5 minutes
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

    lobby.players[playerId] = { id = playerId, name = playerName }
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
    Data.playerTeams[playerId] = nil

    if Config.Debug then
        print(' ' .. playerName .. ' left lobby: ' .. lobbyId)
    end

    if Lobby.GetPlayerCount(lobby) == 0 then
        Data.teamScores[lobbyId] = nil
        Leaderboard.ClearLobbyStats(lobbyId)
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

    local normalizedMode = NormalizeModeId(mode)
    if not normalizedMode or not Lobby.IsAllowedGameMode(normalizedMode) then
        return false
    end

    lobby.gameMode = normalizedMode

    if not Lobby.IsTeamBasedMode(normalizedMode) then
        Data.teamScores[lobbyId] = nil
        for pid, _ in pairs(lobby.players) do
            Data.playerTeams[pid] = nil
        end
    else
        Data.teamScores[lobbyId] = Data.teamScores[lobbyId] or {
            team1 = 0,
            team2 = 0
        }
    end

    if Config.Debug then
        print(' Lobby ' .. lobbyId .. ' game mode set to: ' .. normalizedMode)
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

function Lobby.SetDeathmatchEnabled(playerId, enabled)
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

    lobby.deathmatchEnabled = enabled == true

    if Config.Debug then
        print(' Lobby ' .. lobbyId .. ' deathmatch set to: ' .. tostring(lobby.deathmatchEnabled))
    end

    for pid, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:lobbyUpdated', pid, lobby)
    end

    return true
end

function Lobby.SetMatchTimer(playerId, minutes)
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

    -- Validate timer (must be between 1 and max minutes)
    if minutes < 1 or minutes > Config.MaxMatchDurationMinutes then
        TriggerClientEvent('matti-airsoft:sendNotification', playerId, Lang:t('notifications.invalid_timer'), 'error')
        return false
    end

    lobby.matchTimer = minutes * 60 -- Convert to seconds

    if Config.Debug then
        print(' Lobby ' .. lobbyId .. ' timer set to: ' .. minutes .. ' minutes (' .. lobby.matchTimer .. ' seconds)')
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

    if Lobby.IsTeamBasedMode(lobby.gameMode) then
        Data.teamScores[lobbyId] = {
            team1 = 0,
            team2 = 0
        }
    else
        Data.teamScores[lobbyId] = nil
    end

    for pid, _ in pairs(lobby.players) do
        TriggerClientEvent('matti-airsoft:gameStarting', pid, lobby.selectedLoadout, lobby.gameMode, lobby.deathmatchEnabled == true)
    end

    if Config.Debug then
        print(' Game started in lobby: ' .. lobbyId)
        print(' Arena occupied by lobby: ' .. lobbyId)
        print(' Game mode: ' .. lobby.gameMode)
    end

    return true
end
