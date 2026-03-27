QBCore = nil
if Config.Framework == 'qb' or Config.Framework == 'qbx' then
    QBCore = exports['qb-core']:GetCoreObject()
end

State = {
    isHit = false,
    isInArena = false,
    leaderboardVisible = false,
    finalScoreboardVisible = false,
    cachedLeaderboardRows = {},
    airsoftZone = nil,
    currentLoadout = nil,
    currentLobby = nil,
    lastAttacker = nil,
    lastTrackedHit = nil,
    enterPed = nil,
    exitPed = nil,
    debugPeds = {}
}

allowedArenaItems = allowedArenaItems or {}

Utils = {}

function Utils.TableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function Utils.GetPlayerName()
    if not QBCore or not QBCore.Functions then
        return 'Unknown Player'
    end

    local player = QBCore.Functions.GetPlayerData()
    if player and player.charinfo then
        return player.charinfo.firstname .. ' ' .. player.charinfo.lastname
    end

    return 'Unknown Player'
end

function Utils.SendNotification(message, type)
    if Config.NotifySystem == 'qb-core' and QBCore and QBCore.Functions then
        QBCore.Functions.Notify(message, type)
    elseif Config.NotifySystem == 'ox_lib' then
        local iconColors = {
            success = '#28A745',
            error = '#DC3545',
            info = '#F08080'
        }
        local icons = {
            success = 'check-circle',
            error = 'times-circle',
            info = 'info-circle'
        }

        lib.notify({
            title = message,
            style = {
                color = iconColors[type] or iconColors.info,
                ['.description'] = { color = type == 'success' and '#E9ECEF' or '#909296' }
            },
            icon = icons[type] or icons.info,
            iconColor = iconColors[type] or iconColors.info,
        })
    else
        print('^1[matti-airsoft]^7 ERROR: Unsupported notification system: ' .. tostring(Config.NotifySystem))
    end
end

RegisterNetEvent('matti-airsoft:sendNotification', function(message, type)
    Utils.SendNotification(message, type)
end)
