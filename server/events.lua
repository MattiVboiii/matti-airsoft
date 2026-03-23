local function NormalizeItemName(itemName)
    if not itemName then
        return nil
    end

    return string.lower(tostring(itemName))
end

local function IsPositiveWholeNumber(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local MAX_ITEM_EVENT_AMOUNT = 2000000000

local function GetPlayerArenaLobby(playerId)
    local lobbyId = Data.playerLobbies[playerId]
    if not lobbyId or not Data.lobbies[lobbyId] then
        return nil
    end

    if Data.activeLobbyInArena ~= lobbyId then
        return nil
    end

    local lobby = Data.lobbies[lobbyId]
    if not lobby.players or not lobby.players[playerId] then
        return nil
    end

    return lobby
end

local function BuildLoadoutGrants(loadout)
    local grants = {
        weapons = {},
        ammo = {}
    }

    if not loadout then
        return grants
    end

    for _, weapon in ipairs(loadout.weapons or {}) do
        local normalizedName = NormalizeItemName(weapon.name)
        if normalizedName then
            grants.weapons[normalizedName] = (grants.weapons[normalizedName] or 0) + 1
        end
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        local normalizedName = NormalizeItemName(ammo.name)
        local ammoAmount = tonumber(ammo.amount) or 0
        if normalizedName and ammoAmount > 0 then
            grants.ammo[normalizedName] = (grants.ammo[normalizedName] or 0) + ammoAmount
        end
    end

    return grants
end

local function IsLoadoutItem(loadout, itemName)
    local normalizedName = NormalizeItemName(itemName)
    if not loadout or not normalizedName then
        return false
    end

    for _, weapon in ipairs(loadout.weapons or {}) do
        if NormalizeItemName(weapon.name) == normalizedName then
            return true
        end
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        if NormalizeItemName(ammo.name) == normalizedName then
            return true
        end
    end

    return false
end

local function EnsureSecurityState()
    Data.loadoutGrantState = Data.loadoutGrantState or {}
    Data.restoreCredits = Data.restoreCredits or {}
end

local function EnsureLoadoutGrantState(playerId, lobby)
    EnsureSecurityState()

    local lobbyId = lobby.id
    local state = Data.loadoutGrantState[playerId]
    if state and state.lobbyId == lobbyId and state.loadoutName == (lobby.selectedLoadout and lobby.selectedLoadout.name or nil) then
        return state
    end

    state = {
        lobbyId = lobbyId,
        loadoutName = lobby.selectedLoadout and lobby.selectedLoadout.name or nil,
        grants = BuildLoadoutGrants(lobby.selectedLoadout)
    }

    Data.loadoutGrantState[playerId] = state
    return state
end

local function ConsumeLoadoutGrant(playerId, lobby, grantType, itemName, amount)
    local state = EnsureLoadoutGrantState(playerId, lobby)
    local bucket = state.grants[grantType]
    if not bucket then
        return false
    end

    local remaining = bucket[itemName] or 0
    if remaining < amount then
        return false
    end

    bucket[itemName] = remaining - amount
    state.issuedAny = true
    return true
end

local function AddRestoreCredits(playerId, itemName, amount)
    EnsureSecurityState()

    local normalizedName = NormalizeItemName(itemName)
    if not normalizedName or not IsPositiveWholeNumber(amount) then
        return
    end

    Data.restoreCredits[playerId] = Data.restoreCredits[playerId] or {}
    Data.restoreCredits[playerId][normalizedName] = (Data.restoreCredits[playerId][normalizedName] or 0) + amount
end

local function ConsumeRestoreCredits(playerId, itemName, amount)
    EnsureSecurityState()

    local normalizedName = NormalizeItemName(itemName)
    if not normalizedName or not IsPositiveWholeNumber(amount) then
        return false
    end

    local credits = Data.restoreCredits[playerId]
    if not credits then
        return false
    end

    local available = credits[normalizedName] or 0
    if available < amount then
        return false
    end

    credits[normalizedName] = available - amount
    if credits[normalizedName] <= 0 then
        credits[normalizedName] = nil
    end

    if next(credits) == nil then
        Data.restoreCredits[playerId] = nil
    end

    return true
end

local function ResetPlayerSecurityState(playerId)
    if Data.loadoutGrantState then
        Data.loadoutGrantState[playerId] = nil
    end
end

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
    ResetPlayerSecurityState(source)
    Lobby.Leave(source)
end)

RegisterNetEvent('matti-airsoft:setGameMode', function(mode)
    Lobby.SetGameMode(source, mode)
end)

RegisterNetEvent('matti-airsoft:setLobbyLoadout', function(loadout)
    Lobby.SetLoadout(source, loadout)
end)

RegisterNetEvent('matti-airsoft:setMatchTimer', function(minutes)
    if Lobby.SetMatchTimer(source, minutes) then
        local timerText = minutes == 0 and Lang:t('notifications.timer_disabled') or (minutes .. ' ' .. Lang:t('menu.minutes'))
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.match_timer_set') .. ' ' .. timerText, 'success')
    end
end)

RegisterNetEvent('matti-airsoft:startLobbyGame', function()
    Lobby.StartGame(source)
end)

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

    Lobby.BroadcastToLobby(lobbyId, 'matti-airsoft:lobbyUpdated', lobby)

    TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('notifications.team_selected') .. ' ' .. (team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

RegisterNetEvent('matti-airsoft:playerEnteredArena', function()
    Leaderboard.AddPlayer(source)
end)

RegisterNetEvent('matti-airsoft:playerLeftArena', function()
    Data.recentAttackers[source] = nil
    ResetPlayerSecurityState(source)
    Leaderboard.RemovePlayer(source)
    Lobby.Leave(source)
end)

RegisterNetEvent('matti-airsoft:registerRecentAttacker', function(attackerId)
    local victimId = source
    local attacker = tonumber(attackerId)

    if not attacker or attacker == victimId then
        return
    end

    Data.recentAttackers[victimId] = {
        attackerId = attacker,
        timestamp = GetGameTimer()
    }

    if Config.Debug then
        print(' Cached recent attacker for victim ' .. victimId .. ': ' .. attacker)
    end
end)

RegisterNetEvent('matti-airsoft:playerWasHit', function(killerId)
    local victimId = source
    local normalizedKillerId = tonumber(killerId)

    if not normalizedKillerId or normalizedKillerId == victimId or not Data.arenaStats[normalizedKillerId] then
        normalizedKillerId = Utils.GetRecentAttacker(victimId)
    end

    if Config.Debug then
        print(' Processing hit victim=' .. victimId .. ' killer=' .. tostring(normalizedKillerId) .. ' raw=' .. tostring(killerId))
    end

    Leaderboard.RecordHit(victimId, normalizedKillerId)
    Data.recentAttackers[victimId] = nil
end)

RegisterServerEvent('matti-airsoft:revivePlayer', function()
    if not Data.arenaStats[source] then
        return
    end

    if Config.Framework == 'ox' then
        if OxCore then
            local player = OxCore.GetPlayer(source)
            if player then
                player.revive()
            end
        end
    elseif Config.Framework == 'qb' then
        TriggerClientEvent('hospital:client:Revive', source)
    elseif Config.Framework == 'qbx' then
        exports.qbx_medical:Revive(source)
    end

    if Config.Debug then
        print(' Player ' .. source .. ' revived in arena')
    end
end)

RegisterServerEvent('matti-airsoft:giveWeapon', function(weaponName)
    if type(weaponName) ~= 'string' or weaponName == '' then
        return
    end

    local normalizedWeaponName = NormalizeItemName(weaponName)
    local lobby = GetPlayerArenaLobby(source)
    if not lobby or not lobby.selectedLoadout then
        return
    end

    if not ConsumeLoadoutGrant(source, lobby, 'weapons', normalizedWeaponName, 1) then
        return
    end

    Utils.HandlePlayerItem(source, weaponName, 1, 'add')
end)

RegisterServerEvent('matti-airsoft:giveItem', function(itemName, amount, metadata, slot)
    if type(itemName) ~= 'string' or itemName == '' then
        return
    end

    local normalizedItemName = NormalizeItemName(itemName)
    local normalizedAmount = tonumber(amount)
    if not IsPositiveWholeNumber(normalizedAmount) then
        return
    end

    if normalizedAmount > MAX_ITEM_EVENT_AMOUNT then
        return
    end

    local lobby = GetPlayerArenaLobby(source)
    local canIssueFromLoadout = false

    if lobby and lobby.selectedLoadout then
        canIssueFromLoadout = ConsumeLoadoutGrant(source, lobby, 'ammo', normalizedItemName, normalizedAmount)
    end

    if not canIssueFromLoadout and not ConsumeRestoreCredits(source, normalizedItemName, normalizedAmount) then
        return
    end

    Utils.HandlePlayerItem(source, itemName, normalizedAmount, 'add', {
        metadata = metadata,
        slot = slot,
    })
end)

RegisterServerEvent('matti-airsoft:removeWeapon', function(weaponName)
    if type(weaponName) ~= 'string' or weaponName == '' then
        return
    end

    local removed = Utils.HandlePlayerItem(source, weaponName, 1, 'remove')
    if removed then
        Utils.RemoveWeaponFromPed(source, weaponName)
    end
end)

RegisterServerEvent('matti-airsoft:removeItem', function(itemName, amount, slot, metadata)
    if type(itemName) ~= 'string' or itemName == '' then
        return
    end

    local normalizedAmount = tonumber(amount)
    if not IsPositiveWholeNumber(normalizedAmount) then
        return
    end

    if normalizedAmount > MAX_ITEM_EVENT_AMOUNT then
        return
    end

    local removed = Utils.HandlePlayerItem(source, itemName, normalizedAmount, 'remove', {
        metadata = metadata,
        slot = slot,
    })

    if removed then
        local shouldAddRestoreCredits = true
        local lobby = GetPlayerArenaLobby(source)
        if lobby and lobby.selectedLoadout and Data.loadoutGrantState and Data.loadoutGrantState[source] and Data.loadoutGrantState[source].issuedAny then
            if IsLoadoutItem(lobby.selectedLoadout, itemName) then
                shouldAddRestoreCredits = false
            end
        end

        if shouldAddRestoreCredits then
            AddRestoreCredits(source, itemName, normalizedAmount)
        end
    end
end)

RegisterServerEvent('matti-airsoft:debugZoneEntry', function(playerName, action)
    if Config.Debug then
        print(playerName .. ' has ' .. action .. ' the airsoft zone.')
    end
end)

RegisterNetEvent('matti-airsoft:reportArenaStatus', function(adminId, isInArena)
    local normalizedAdminId = tonumber(adminId)
    if not normalizedAdminId or type(isInArena) ~= 'boolean' then
        return
    end

    Data.pendingArenaStatusChecks = Data.pendingArenaStatusChecks or {}
    if Data.pendingArenaStatusChecks[source] ~= normalizedAdminId then
        return
    end

    Data.pendingArenaStatusChecks[source] = nil

    if isInArena then
        TriggerClientEvent('matti-airsoft:forceExitArena', source)
        TriggerClientEvent('matti-airsoft:sendNotification', normalizedAdminId, Lang:t('command.player_removed'), 'success')
    else
        TriggerClientEvent('matti-airsoft:sendNotification', normalizedAdminId, Lang:t('command.player_not_in_arena'), 'error')
    end
end)
