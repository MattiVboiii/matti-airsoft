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
        State.airsoftZone = lib.zones.sphere({
            coords = Config.AirsoftZone.coordinates,
            radius = Config.AirsoftZone.radius,
            debug = Config.Debug,
            onEnter = function()
                Zone.HandleEntry(true)
            end,
            onExit = function()
                Zone.HandleEntry(false)
            end,
        })
    elseif Config.ZoneType == 'poly' then
        State.airsoftZone = lib.zones.poly({
            points = Config.AirsoftZone.points,
            thickness = Config.AirsoftZone.thickness or 20,
            debug = Config.Debug,
            onEnter = function()
                Zone.HandleEntry(true)
            end,
            onExit = function()
                Zone.HandleEntry(false)
            end,
        })
    else
        print('No supported zone type found.')
        return
    end
end
