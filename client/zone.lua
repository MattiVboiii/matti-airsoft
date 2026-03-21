Zone = {}

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
