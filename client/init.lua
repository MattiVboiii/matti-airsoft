Citizen.CreateThread(function()
    Inventory.BuildAllowedArenaItems()
    Inventory.StartArenaItemLock()

    SendNUIMessage({
        action = 'setLeaderboardTranslations',
        translations = {
            title = Lang:t('leaderboard.title'),
            subtitle = Lang:t('leaderboard.subtitle'),
            columnPlayer = Lang:t('leaderboard.column_player'),
            columnTeam = Lang:t('leaderboard.column_team'),
            teamTotals = Lang:t('leaderboard.team_totals'),
            totalKills = Lang:t('leaderboard.total_kills'),
            noPlayers = Lang:t('leaderboard.no_players'),
            team1 = Lang:t('leaderboard.team1'),
            team2 = Lang:t('leaderboard.team2'),
            noTeam = Lang:t('leaderboard.no_team'),
            ffa = Lang:t('leaderboard.ffa'),
        },
    })

    Leaderboard.ApplyUiTheme()

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
    Leaderboard.HandleKeybind()
end)
