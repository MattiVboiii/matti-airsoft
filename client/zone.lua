Zone = {}

function Zone.IsPlayerInsideArena()
    local playerPed = PlayerPedId()
    if not playerPed or playerPed == 0 then
        return false
    end

    return SharedUtils.IsCoordsInArena(GetEntityCoords(playerPed))
end

function Zone.SyncPlayerState()
    Zone.HandleEntry(Zone.IsPlayerInsideArena())
end

function Zone.HandleEntry(isPointInside)
    local wasInArena = State.isInArena == true

    if wasInArena == (isPointInside == true) then
        return
    end

    if isPointInside then
        State.isInArena = true
        TriggerEvent('matti-airsoft:arenaStateChanged', true)
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
        if GetGameTimer() < (State.suppressZoneExitUntil or 0) then
            return
        end

        State.isInArena = false
        TriggerEvent('matti-airsoft:arenaStateChanged', false)

        if Config.LeaderboardEnabled then
            Leaderboard.ShowFinalOnExit()
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

    CreateThread(function()
        Wait(0)
        Zone.SyncPlayerState()
    end)
end
