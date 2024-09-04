-- client.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isStunned = false
local airsoftZone

-- Function to get the player's name
function GetPlayerName()
    local player = QBCore.Functions.GetPlayerData()
    return player.charinfo.firstname .. " " .. player.charinfo.lastname
end

-- Create the airsoft zone using PolyZone with debug mode from the config
Citizen.CreateThread(function()
    airsoftZone = PolyZone:Create(Config.AirsoftZone.coordinates, {
        minZ = Config.AirsoftZone.minZ, -- Minimum Z level for the zone
        maxZ = Config.AirsoftZone.maxZ, -- Maximum Z level for the zone
        debugPoly = Config.Debug -- Enable or disable debug mode based on config
    })

    -- Enter and exit events for the airsoft zone
    airsoftZone:onPlayerInOut(function(isPointInside)
        local playerPed = PlayerPedId()
        if isPointInside then
            -- Notify the player
            QBCore.Functions.Notify(Lang:t('zone.entered'), "success")
            if Config.Debug then
                -- Send data to server for debugging
                TriggerServerEvent('qbcore:debugZoneEntry', GetPlayerName(), 'entered')
            end
            CheckStunStatus()
        else
            -- Notify the player
            QBCore.Functions.Notify(Lang:t('zone.exited'), "error")
            if Config.Debug then
                -- Send data to server for debugging
                TriggerServerEvent('qbcore:debugZoneEntry', GetPlayerName(), 'exited')
            end
            isStunned = false -- Reset the stun state when the player leaves the zone
        end
    end)
end)

-- Function to check stun status
function CheckStunStatus()
    Citizen.CreateThread(function()
        while airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) do
            Citizen.Wait(100)

            local playerPed = PlayerPedId()

            -- Check if the player is being stunned or is dead
            if IsPedBeingStunned(playerPed, 0) or IsEntityDead(playerPed) then
                if not isStunned then
                    isStunned = true
                    TriggerServerEvent('qbcore:stunNotify', GetPlayerName())
                    TriggerEvent('qbcore:showStunNotification')
                    -- Teleport the player to the configured location
                    SetEntityCoords(playerPed, Config.TeleportLocation)
                end
            else
                isStunned = false
            end
        end
    end)
end

-- Event to show stun notification to the player
RegisterNetEvent('qbcore:showStunNotification')
AddEventHandler('qbcore:showStunNotification', function()
    QBCore.Functions.Notify(Lang:t('inarena.shot'))
end)
