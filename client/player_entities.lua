Player = {}
Peds = {}
Blip = {}

function Player.TeleportToRandomPosition()
    if not Config.SpawnLocations or #Config.SpawnLocations == 0 then
        return
    end

    local randomCoord = Config.SpawnLocations[math.random(1, #Config.SpawnLocations)]
    SetEntityCoords(PlayerPedId(), randomCoord)
end

function Peds.Spawn(modelHash, coords, event, icon, label)
    RequestModel(modelHash)
    local loadDeadline = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > loadDeadline then
            print('[matti-airsoft] Failed to load ped model within timeout')
            return nil
        end
        Wait(100)
    end

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if Config.TargetSystem == 'qb-target' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    event = event,
                    icon = icon,
                    label = label,
                },
            },
            distance = 2.5,
        })
    elseif Config.TargetSystem == 'ox_target' then
        local targetName = 'airsoft_menu_' .. tostring(event or 'default')
        exports.ox_target:addLocalEntity(ped, {
            {
                name = targetName,
                label = label,
                onSelect = function()
                    TriggerEvent(event)
                end,
                icon = icon,
                distance = 2.5,
            },
        })
    else
        print('No supported target system found: ' .. Config.TargetSystem)
    end

    return ped
end

function Blip.Create()
    if Config.AirsoftBlip.enabled then
        local blip = AddBlipForCoord(Config.AirsoftBlip.coords)
        SetBlipSprite(blip, Config.AirsoftBlip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.AirsoftBlip.scale)
        SetBlipColour(blip, Config.AirsoftBlip.color)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.AirsoftBlip.name)
        EndTextCommandSetBlipName(blip)
    end
end
