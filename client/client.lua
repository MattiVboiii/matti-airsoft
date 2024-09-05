-- client.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isHit = false
local airsoftZone
local currentLoadout = nil
local enterPed -- Variable to store the main interaction ped
local exitPed
local debugPeds = {} -- Table to store debug peds

-- Function to get the player's name
function GetPlayerName()
    local player = QBCore.Functions.GetPlayerData()
    return player.charinfo.firstname .. " " .. player.charinfo.lastname
end

-- Create the airsoft zone using CircleZone with debug mode from the config
Citizen.CreateThread(function()
    airsoftZone = CircleZone:Create(Config.AirsoftZone.coordinates, Config.AirsoftZone.radius, {
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
            CheckHitStatus()
        else
            -- Notify the player
            QBCore.Functions.Notify(Lang:t('zone.exited'), "error")
            if Config.Debug then
                -- Send data to server for debugging
                TriggerServerEvent('matti-airsoft:debugZoneEntry', GetPlayerName(), 'exited')
            end
            RemoveLoadout()
            RemoveGunFromHand()
            isHit = false -- Reset the hit state when the player leaves the zone
        end
    end)
    
    -- Spawn the ped for interaction
    SpawnEnterPed()

    -- Create the blip for the airsoft arena
    CreateAirsoftBlip()

    -- Spawn the exit ped
    SpawnExitPed()

    -- Spawn transparent peds at spawn locations if debug mode is enabled
    if Config.Debug then
        SpawnDebugPeds()
    end
end)

-- Function to create the airsoft blip
function CreateAirsoftBlip()
    if Config.AirsoftBlip.enabled then
        airsoftBlip = AddBlipForCoord(Config.AirsoftBlip.coords)
        SetBlipSprite(airsoftBlip, Config.AirsoftBlip.sprite)
        SetBlipDisplay(airsoftBlip, 4) -- Display on the main map
        SetBlipScale(airsoftBlip, Config.AirsoftBlip.scale)
        SetBlipColour(airsoftBlip, Config.AirsoftBlip.color)
        SetBlipAsShortRange(airsoftBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.AirsoftBlip.name)
        EndTextCommandSetBlipName(airsoftBlip)
    end
end

-- Function to spawn the airsoft ped
function SpawnEnterPed()
    local model = GetHashKey(Config.EnterLocation.model)
    
    -- Request the ped model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end

    -- Spawn the ped at the configured location
    airsoftPed = CreatePed(4, model, Config.EnterLocation.coords.x, Config.EnterLocation.coords.y, Config.EnterLocation.coords.z - 1.0, Config.EnterLocation.coords.w)
    FreezeEntityPosition(airsoftPed, true)
    SetEntityInvincible(airsoftPed, true)
    SetBlockingOfNonTemporaryEvents(airsoftPed, true)

    -- Add the ped as a target for qb-target interaction
    exports['qb-target']:AddTargetEntity(airsoftPed, {
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
end

-- Function to spawn transparent debug peds at the spawn locations
function SpawnDebugPeds()
    local model = GetHashKey(Config.EnterLocation.model)

    -- Request the ped model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end

    -- Spawn transparent peds at each spawn location
    for _, spawnLocation in ipairs(Config.SpawnLocations) do
        local ped = CreatePed(4, model, spawnLocation.x, spawnLocation.y, spawnLocation.z - 1.0, 0.0, false, true)
        SetEntityAlpha(ped, 100, false) -- Make the ped semi-transparent
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        table.insert(debugPeds, ped)
    end
end

-- Function to spawn the exit ped
function SpawnExitPed()
    local model = GetHashKey(Config.ExitLocation.model)
    
    -- Request the ped model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end

    -- Spawn the exit ped at the configured location
    exitPed = CreatePed(4, model, Config.ExitLocation.coords.x, Config.ExitLocation.coords.y, Config.ExitLocation.coords.z -1.0, Config.ExitLocation.coords.w)
    FreezeEntityPosition(exitPed, true)
    SetEntityInvincible(exitPed, true)
    SetBlockingOfNonTemporaryEvents(exitPed, true)

    -- Add the exit ped as a target for qb-target interaction
    exports['qb-target']:AddTargetEntity(exitPed, {
        options = {
            {
                type = "client",
                event = "matti-airsoft:exitArena",
                icon = "fas fa-door-open",
                label = Lang:t('menu.exit_arena')
            },
        },
        distance = 2.5
    })
end

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

    -- Add the teleport-only option
    table.insert(loadoutMenu, {
        header = Lang:t('menu.own_loadout'),
        txt = Lang:t('menu.own_loadout_txt'),
        params = {
            event = "matti-airsoft:teleportOnly"
        }
    })

    -- Add the random gun option
    table.insert(loadoutMenu, {
        header = Lang:t('menu.random_loadout'),
        txt = Lang:t('menu.random_loadout_txt'),
        params = {
            event = "matti-airsoft:giveRandomGun"
        }
    })

    -- Show the qb-menu to the player
    exports['qb-menu']:openMenu(loadoutMenu)
end)

-- Event to handle teleport-only selection
RegisterNetEvent('matti-airsoft:teleportOnly')
AddEventHandler('matti-airsoft:teleportOnly', function()
    -- Teleport the player to a random position within the airsoft zone
    TeleportToRandomPosition()
end)

-- Event to handle giving a random gun with ammo
RegisterNetEvent('matti-airsoft:giveRandomGun')
AddEventHandler('matti-airsoft:giveRandomGun', function()
    -- Randomly select a loadout
    local randomIndex = math.random(1, #Config.Loadouts)
    local selectedLoadout = Config.Loadouts[randomIndex]

    -- Give the player the selected loadout
    local playerPed = PlayerPedId()
    for _, weapon in ipairs(selectedLoadout.weapons) do
        TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
    end
    for _, ammo in ipairs(selectedLoadout.ammo) do
        TriggerServerEvent('matti-airsoft:giveItem', ammo.name, ammo.amount)
    end

    -- Set current loadout to the one given
    currentLoadout = selectedLoadout

    -- Teleport the player to a random position within the airsoft zone
    TeleportToRandomPosition()
end)

-- Function to teleport player to a random spawn location within the airsoft zone
function TeleportToRandomPosition()
    local randomIndex = math.random(1, #Config.SpawnLocations)
    local randomCoord = Config.SpawnLocations[randomIndex]
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, randomCoord)
end

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


-- Function to check hit status
function CheckHitStatus()
    Citizen.CreateThread(function()
        while airsoftZone:isPointInside(GetEntityCoords(PlayerPedId())) do
            Citizen.Wait(100)

            local playerPed = PlayerPedId()

            -- Check if the player is being hit or is dead
            if IsPedBeingStunned(playerPed, 0) or IsEntityDead(playerPed) then
                if not isHit then
                    isHit = true
                    TriggerServerEvent('matti-airsoft:hitNotify', GetPlayerName())
                    TriggerEvent('matti-airsoft:showHitNotification')
                    -- Teleport the player to the configured location
                    SetEntityCoords(playerPed, Config.TeleportLocation)
                end
            else
                isHit = false
            end
        end
    end)
end

-- Event to show hit notification to the player
RegisterNetEvent('matti-airsoft:showHitNotification')
AddEventHandler('matti-airsoft:showHitNotification', function()
    QBCore.Functions.Notify(Lang:t('inarena.shot'))
end)

-- Event to handle exiting the arena
RegisterNetEvent('matti-airsoft:exitArena')
AddEventHandler('matti-airsoft:exitArena', function()
    -- Remove the current loadout if there is one
    RemoveLoadout()

    -- Teleport the player to the configured exit location
    SetEntityCoords(PlayerPedId(), Config.TeleportLocation)
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