Zone = {}

local function IsPointInsidePolygon(coords, points)
    local inside = false
    local previousIndex = #points

    for index = 1, #points do
        local currentPoint = points[index]
        local previousPoint = points[previousIndex]

        local intersects = ((currentPoint.y > coords.y) ~= (previousPoint.y > coords.y))
            and (coords.x < (previousPoint.x - currentPoint.x) * (coords.y - currentPoint.y) / (previousPoint.y - currentPoint.y) + currentPoint.x)

        if intersects then
            inside = not inside
        end

        previousIndex = index
    end

    return inside
end

function Zone.IsPlayerInsideArena()
    local playerPed = PlayerPedId()
    if not playerPed or playerPed == 0 then
        return false
    end

    local coords = GetEntityCoords(playerPed)

    if Config.ZoneType == 'circle' then
        return #(coords - Config.AirsoftZone.coordinates) <= Config.AirsoftZone.radius
    end

    if Config.ZoneType == 'poly' then
        local points = Config.AirsoftZone.points or {}
        if #points < 3 then
            return false
        end

        local halfThickness = (Config.AirsoftZone.thickness or 20) / 2
        local minZ = points[1].z - halfThickness
        local maxZ = points[1].z + halfThickness

        for index = 2, #points do
            local pointZ = points[index].z
            minZ = math.min(minZ, pointZ - halfThickness)
            maxZ = math.max(maxZ, pointZ + halfThickness)
        end

        return coords.z >= minZ and coords.z <= maxZ and IsPointInsidePolygon(coords, points)
    end

    return false
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
        State.isInArena = false
        TriggerEvent('matti-airsoft:arenaStateChanged', false)

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

    CreateThread(function()
        Wait(0)
        Zone.SyncPlayerState()
    end)
end
