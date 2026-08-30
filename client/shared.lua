QBCore = nil
Framework = {}

if Config.Framework == 'qb' then
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
elseif Config.Framework == 'qbx' then
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end

function Framework.TriggerCallback(name, cb, ...)
    lib.callback(name, false, cb, ...)
end

function Framework.AwaitCallback(name, ...)
    return lib.callback.await(name, false, ...)
end

function Framework.GetPlayerData()
    if Config.Framework == 'ox' then
        local ok, player = pcall(function()
            if Ox and Ox.GetPlayer then
                return Ox.GetPlayer()
            end
            return exports.ox_core:GetPlayer()
        end)
        if ok and player then
            return {
                charinfo = {
                    firstname = (player.get and player.get('firstName')) or player.firstName,
                    lastname = (player.get and player.get('lastName')) or player.lastName,
                },
                items = {},
            }
        end
        return {}
    end

    if Config.Framework == 'qbx' then
        local ok, data = pcall(function()
            return exports.qbx_core:GetPlayerData()
        end)
        if ok and data then
            return data
        end
        if QBX and QBX.PlayerData then
            return QBX.PlayerData
        end
    end

    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayerData then
        return QBCore.Functions.GetPlayerData() or {}
    end

    return {}
end

State = {
    isHit = false,
    isInArena = false,
    isSpectating = false,
    shouldRespawn = nil,
    shouldEnterSpectator = nil,
    scoreLimit = 0,
    spawnProtectedUntil = nil,
    arenaBoardPayload = nil,
    leaderboardVisible = false,
    finalScoreboardVisible = false,
    cachedLeaderboardRows = {},
    cachedMatchRecap = nil,
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
    local player = Framework.GetPlayerData()
    if player and player.charinfo then
        return (player.charinfo.firstname or '') .. ' ' .. (player.charinfo.lastname or '')
    end

    return GetPlayerName(PlayerId()) or 'Unknown Player'
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

RegisterNetEvent('matti-airsoft:client:revive', function()
    Player.Revive()
end)
