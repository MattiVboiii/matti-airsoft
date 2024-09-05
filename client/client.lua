-- client.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isStunned = false
local airsoftZone
local currentLoadout = nil

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
                TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'entered')
            end
            CheckStunStatus()
        else
            -- Notify the player
            QBCore.Functions.Notify(Lang:t('zone.exited'), "error")
            if Config.Debug then
                -- Send data to server for debugging
                TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'exited')
            end
            RemoveLoadout()
            RemoveGunFromHand()
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
                    TriggerServerEvent('matti-airsoft:stunNotify', GetPlayerName())
                    TriggerEvent('matti-airsoft:showStunNotification')
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
RegisterNetEvent('matti-airsoft:showStunNotification')
AddEventHandler('matti-airsoft:showStunNotification', function()
    QBCore.Functions.Notify(Lang:t('inarena.shot'))
end)

-- Function to teleport player to a random spawn location within the airsoft zone
function TeleportToRandomPosition()
    local randomIndex = math.random(1, #Config.SpawnLocations)
    local randomCoord = Config.SpawnLocations[randomIndex]
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, randomCoord.x, randomCoord.y, randomCoord.z, false, false, false, true)
end

-- Define qb-target interaction
Citizen.CreateThread(function()
    exports['qb-target']:AddBoxZone("AirsoftTeleport", Config.TargetLocation.coords, Config.TargetLocation.size.x, Config.TargetLocation.size.y, {
        name = "AirsoftTeleport",
        heading = 0,
        debugPoly = Config.Debug,
        minZ = Config.TargetLocation.minZ,
        maxZ = Config.TargetLocation.maxZ
    }, {
        options = {
            {
                type = "client",
                event = "matti-airsoft:openLoadoutMenu",
                icon = "fas fa-crosshairs",
                label = Lang:t('menu.choose_loadout')
            },
        },
        distance = 2.5
    })
end)

-- Event to handle qb-target loadout selection
RegisterNetEvent('matti-airsoft:openLoadoutMenu')
AddEventHandler('matti-airsoft:openLoadoutMenu', function()
    local loadoutMenu = {}

    -- Create menu options based on the loadouts in the config
    for i, loadout in ipairs(Config.Loadouts) do
        local weaponsList = ""
        for _, weapon in ipairs(loadout.weapons) do
            weaponsList = weaponsList .. weapon.label .. "\n"
        end

        local ammoList = ""
        for _, ammo in ipairs(loadout.ammo) do
            ammoList = ammoList .. " (" .. ammo.amount .. " rounds)\n"
        end

        table.insert(loadoutMenu, {
            header = loadout.name,
            txt = "Includes:\n" .. weaponsList .. ammoList,
            params = {
                event = "matti-airsoft:selectLoadout",
                args = { loadout = loadout }
            }
        })
    end

    -- Show the qb-menu to the player
    exports['qb-menu']:openMenu(loadoutMenu)
end)

-- Event to handle loadout selection
RegisterNetEvent('matti-airsoft:selectLoadout')
AddEventHandler('matti-airsoft:selectLoadout', function(data)
    local selectedLoadout = data.loadout
    local playerPed = PlayerPedId()

    -- Give the player the selected loadout
    for _, weapon in ipairs(selectedLoadout.weapons) do
        TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
    end
    for _, ammo in ipairs(selectedLoadout.ammo) do
        TriggerServerEvent('matti-airsoft:giveItem', ammo.name, ammo.amount)
    end

    -- Set current loadout
    currentLoadout = selectedLoadout

    -- Teleport the player to a random position within the airsoft zone
    TeleportToRandomPosition()
end)

-- Function to remove loadout from the player's inventory
function RemoveLoadout()
    if currentLoadout then
        local playerPed = PlayerPedId()

        -- Remove all weapons from the player's inventory
        for _, weapon in ipairs(currentLoadout.weapons) do
            TriggerServerEvent('matti-airsoft:removeWeapon', weapon.name)
        end
        -- Remove all ammo from the player's inventory
        for _, ammo in ipairs(currentLoadout.ammo) do
            TriggerServerEvent('matti-airsoft:removeItem', ammo.name, ammo.amount)
        end

        -- Clear current loadout
        currentLoadout = nil
    end
end

-- Function to remove gun from the player's hand
function RemoveGunFromHand()
    local playerPed = PlayerPedId()
    if IsPedArmed(playerPed, 6) then
        RemoveWeaponFromPed(playerPed, GetSelectedPedWeapon(playerPed))
    end
end
