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
    if Config.Framework == 'ox' then
        if OxCore then
            local player = OxCore.GetPlayer(source)
            if player then
                player.revive()
            end
        end
    else
        exports.qbx_medical:Revive(source)
    end

    if Config.Debug then
        print(' Player ' .. source .. ' revived in arena')
    end
end)

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
