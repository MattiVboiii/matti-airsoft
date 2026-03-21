RegisterNetEvent('matti-airsoft:openLobbyMenu', function()
    QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerLobby', function(lobby)
        if lobby then
            State.currentLobby = lobby
            TriggerEvent('matti-airsoft:openLobbyManagement')
        else
            TriggerEvent('matti-airsoft:openLobbyBrowser')
        end
    end)
end)

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

    QBCore.Functions.TriggerCallback('matti-airsoft:getLobbies', function(data)
        local lobbies = data.lobbies or {}
        local arenaOccupied = data.arenaOccupied or false

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

RegisterNetEvent('matti-airsoft:createLobbyPrompt')
AddEventHandler('matti-airsoft:createLobbyPrompt', function()
    if Config.MenuSystem == 'ox_lib' then
        local input = lib.inputDialog(Lang:t('menu.create_lobby'), {
            { type = 'input', label = Lang:t('menu.lobby_name'), placeholder = Lang:t('menu.lobby_name_placeholder'), required = true }
        })

        if input then
            TriggerServerEvent('matti-airsoft:createLobby', input[1])
        end
    else
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

RegisterNetEvent('matti-airsoft:joinLobbyConfirm')
AddEventHandler('matti-airsoft:joinLobbyConfirm', function(data)
    TriggerServerEvent('matti-airsoft:joinLobby', data.lobbyId)
end)

RegisterNetEvent('matti-airsoft:lobbyCreated', function(lobby)
    State.currentLobby = lobby
    TriggerEvent('matti-airsoft:openLobbyManagement')
end)

RegisterNetEvent('matti-airsoft:lobbyUpdated', function(lobby)
    State.currentLobby = lobby
    if Config.MenuSystem == 'ox_lib' then
        local currentMenu = lib.getOpenContextMenu()
        if currentMenu == 'matti_airsoft_lobby_management' then
            TriggerEvent('matti-airsoft:openLobbyManagement')
        end
    end
end)

RegisterNetEvent('matti-airsoft:lobbyClosed', function()
    State.currentLobby = nil
    Utils.SendNotification(Lang:t('notifications.lobby_left'), 'info')
end)

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

        if Config.MatchTimerEnabled then
            local timerText = math.floor(State.currentLobby.matchTimer / 60) .. ' ' .. Lang:t('menu.minutes')
            Menu.AddOption(managementMenu, {
                title = Lang:t('menu.match_timer'),
                description = Lang:t('menu.current_timer') .. ': ' .. timerText,
                event = 'matti-airsoft:openMatchTimerInput',
                icon = 'fas fa-clock',
                iconColor = '#f39c12',
            })
        end

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

RegisterNetEvent('matti-airsoft:confirmLeaveLobby')
AddEventHandler('matti-airsoft:confirmLeaveLobby', function()
    TriggerServerEvent('matti-airsoft:leaveLobby')
end)

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
    TriggerEvent('matti-airsoft:openLobbyManagement')
end)

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
    TriggerEvent('matti-airsoft:openLobbyManagement')
end)

RegisterNetEvent('matti-airsoft:setRandomLobbyLoadout', function()
    local randomIndex = math.random(1, #Config.Loadouts)
    local randomLoadout = Config.Loadouts[randomIndex]
    TriggerServerEvent('matti-airsoft:setLobbyLoadout', randomLoadout)
    Utils.SendNotification(Lang:t('notifications.lobby_loadout_set') .. ' ' .. randomLoadout.name, 'success')
    Wait(500)
    TriggerEvent('matti-airsoft:openLobbyManagement')
end)

RegisterNetEvent('matti-airsoft:openMatchTimerInput')
AddEventHandler('matti-airsoft:openMatchTimerInput', function()
    if Config.MenuSystem == 'ox_lib' then
        local input = lib.inputDialog(Lang:t('menu.select_match_timer'), {
            { 
                type = 'number',
                label = Lang:t('menu.timer_input_label'),
                placeholder = '5',
                min = 1,
                max = Config.MaxMatchDurationMinutes,
                required = true
            }
        })

        if input and input[1] then
            local minutes = tonumber(input[1])
            if minutes and minutes >= 1 and minutes <= Config.MaxMatchDurationMinutes then
                TriggerServerEvent('matti-airsoft:setMatchTimer', minutes)
                Utils.SendNotification(Lang:t('notifications.match_timer_set') .. ' ' .. minutes .. ' ' .. Lang:t('menu.minutes'), 'success')
                Wait(500)
                TriggerEvent('matti-airsoft:openLobbyManagement')
            else
                Utils.SendNotification(Lang:t('notifications.invalid_timer') .. ' (1-' .. Config.MaxMatchDurationMinutes .. ')', 'error')
            end
        end
    else
        -- Fallback for qb-menu system
        local dialog = exports['qb-input']:ShowInput({
            header = Lang:t('menu.select_match_timer'),
            submitText = Lang:t('menu.set'),
            inputs = {
                {
                    text = Lang:t('menu.timer_input_label'),
                    name = 'minutes',
                    type = 'number',
                    isRequired = true
                }
            }
        })

        if dialog and dialog.minutes then
            local minutes = tonumber(dialog.minutes)
            if minutes and minutes >= 1 and minutes <= Config.MaxMatchDurationMinutes then
                TriggerServerEvent('matti-airsoft:setMatchTimer', minutes)
                Utils.SendNotification(Lang:t('notifications.match_timer_set') .. ' ' .. minutes .. ' ' .. Lang:t('menu.minutes'), 'success')
                Wait(500)
                TriggerEvent('matti-airsoft:openLobbyManagement')
            else
                Utils.SendNotification(Lang:t('notifications.invalid_timer') .. ' (1-' .. Config.MaxMatchDurationMinutes .. ')', 'error')
            end
        end
    end
end)

RegisterNetEvent('matti-airsoft:startLobbyGame', function()
    if State.currentLobby and State.currentLobby.gameMode == 'teams' then
        QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerTeam', function(team)
            if not team then
                TriggerEvent('matti-airsoft:selectTeam')
            else
                TriggerServerEvent('matti-airsoft:startLobbyGame')
            end
        end)
    else
        TriggerServerEvent('matti-airsoft:startLobbyGame')
    end
end)

RegisterNetEvent('matti-airsoft:selectTeam')
AddEventHandler('matti-airsoft:selectTeam', function()
    QBCore.Functions.TriggerCallback('matti-airsoft:getLobbyTeams', function(teamState)
        Menu.Open('matti_airsoft_team_menu', Lang:t('menu.select_team'), Menu.BuildTeamSelectionMenu('matti-airsoft:confirmTeamSelection', teamState))
    end)
end)

RegisterNetEvent('matti-airsoft:confirmTeamSelection', function(data)
    TriggerServerEvent('matti-airsoft:setPlayerTeam', data.team)
    Utils.SendNotification(Lang:t('notifications.team_selected') .. ' ' .. (data.team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
end)

RegisterNetEvent('matti-airsoft:gameStarting', function(loadout, gameMode)
    if not loadout then
        Utils.SendNotification(Lang:t('notifications.select_loadout_first'), 'error')
        return
    end

    if gameMode == 'teams' then
        QBCore.Functions.TriggerCallback('matti-airsoft:getPlayerTeam', function(team)
            if not team then
                TriggerEvent('matti-airsoft:selectTeamBeforePlay')
            else
                Loadout.Handle(loadout)
            end
        end)
    else
        Loadout.Handle(loadout)
    end
end)

RegisterNetEvent('matti-airsoft:selectTeamBeforePlay')
AddEventHandler('matti-airsoft:selectTeamBeforePlay', function()
    QBCore.Functions.TriggerCallback('matti-airsoft:getLobbyTeams', function(teamState)
        Menu.Open('matti_airsoft_team_select_play', Lang:t('menu.select_team'), Menu.BuildTeamSelectionMenu('matti-airsoft:confirmTeamBeforePlay', teamState))
    end)
end)

RegisterNetEvent('matti-airsoft:confirmTeamBeforePlay', function(data)
    TriggerServerEvent('matti-airsoft:setPlayerTeam', data.team)
    Utils.SendNotification(Lang:t('notifications.team_selected') .. ' ' .. (data.team == 'team1' and Lang:t('menu.team1') or Lang:t('menu.team2')), 'success')
    Wait(500)
    if State.currentLobby and State.currentLobby.selectedLoadout then
        Loadout.Handle(State.currentLobby.selectedLoadout)
    end
end)

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

local function HandleArenaExitCleanup()
    if State.isInArena then
        TriggerServerEvent('matti-airsoft:playerLeftArena')
        State.isInArena = false
    end

    if Config.LeaderboardEnabled then
        Leaderboard.Hide()
    end

    if Config.MatchTimerEnabled then
        SendNUIMessage({
            action = 'hideTimer'
        })
    end

    State.isHit = false
end

RegisterNetEvent('matti-airsoft:exitArena', function()
    HandleArenaExitCleanup()
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
        HandleArenaExitCleanup()
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

RegisterNetEvent('matti-airsoft:showKillFeed', function(killerName, victimName)
    Leaderboard.ApplyUiTheme()
    SendNUIMessage({
        action = 'showKillFeed',
        killer = killerName,
        victim = victimName,
    })
end)

RegisterNUICallback('closeLeaderboard', function(_, cb)
    cb('ok')
end)

-- Match Timer Events
RegisterNetEvent('matti-airsoft:updateTimer', function(secondsRemaining)
    if State.isInArena and Config.LeaderboardEnabled then
        SendNUIMessage({
            action = 'updateTimer',
            secondsRemaining = secondsRemaining
        })
    end
end)

RegisterNetEvent('matti-airsoft:matchTimeExpired', function()
    Utils.SendNotification(Lang:t('notifications.match_time_expired'), 'info')
    if Config.LeaderboardEnabled then
        SendNUIMessage({
            action = 'timerExpired'
        })
    end
    Wait(5000)
    TriggerEvent('matti-airsoft:exitArena')
end)

