Inventory = {}

local inventoryNotifyCooldownUntil = 0

local function NotifyArenaInventoryBlocked()
    local currentTime = GetGameTimer()
    if currentTime < inventoryNotifyCooldownUntil then
        return
    end

    lib.notify({
        title = 'Airsoft Arena',
        description = 'You cannot open your full inventory inside the arena.',
        type = 'error',
        duration = 4000
    })
    inventoryNotifyCooldownUntil = currentTime + 1500
end

local function OpenArenaAwarePrimaryInventory()
    if State.isInArena then
        NotifyArenaInventoryBlocked()
        return
    end

    if cache.vehicle then
        return exports.ox_inventory:openInventory('glovebox', { netid = NetworkGetNetworkIdFromEntity(cache.vehicle) })
    end

    local closest = lib.points.getClosestPoint()
    local currentInstance = LocalPlayer.state.instance

    if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
        if closest.inv == 'crafting' then
            return exports.ox_inventory:openInventory('crafting', { id = closest.id, index = closest.index })
        elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
            return exports.ox_inventory:openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
        end
    end

    return exports.ox_inventory:openInventory()
end

local function RegisterArenaInventoryOverride()
    if Config.InventorySystem == 'ox_inventory' then
        RegisterCommand('+inv', function()
            OpenArenaAwarePrimaryInventory()
        end, false)

        RegisterCommand('-inv', function()
        end, false)
        return
    end

    if Config.InventorySystem ~= 'qb-inventory' then
        return
    end

    -- qb-inventory checks inv_busy server-side before opening the inventory command.
    -- Force-close one tick later so this always wins even if qb-inventory opens first.
    RegisterNetEvent('qb-inventory:client:openInventory', function()
        if not State.isInArena then
            return
        end

        NotifyArenaInventoryBlocked()

        CreateThread(function()
            Wait(0)
            TriggerEvent('qb-inventory:client:closeInv')
            SetNuiFocus(false, false)
        end)
    end)
end

function Inventory.BuildAllowedArenaItems()
    allowedArenaItems = {}

    for _, loadout in ipairs(Config.Loadouts or {}) do
        for _, weapon in ipairs(loadout.weapons or {}) do
            if weapon.name then
                local normalizedWeaponName = SharedUtils.NormalizeItemName(weapon.name)
                if normalizedWeaponName then
                    allowedArenaItems[normalizedWeaponName] = true
                end
            end
        end

        for _, ammo in ipairs(loadout.ammo or {}) do
            if ammo.name then
                local normalizedAmmoName = SharedUtils.NormalizeItemName(ammo.name)
                if normalizedAmmoName then
                    allowedArenaItems[normalizedAmmoName] = true
                end
            end
        end
    end

    for _, itemName in ipairs(Config.ArenaItemWhitelist or {}) do
        local normalizedItemName = SharedUtils.NormalizeItemName(itemName)
        if normalizedItemName then
            allowedArenaItems[normalizedItemName] = true
        end
    end
end

function Inventory.RemoveDisallowedArenaItems()
    if not Config.EnforceArenaLoadoutItemsOnly or not State.isInArena then
        return
    end

    TriggerServerEvent('matti-airsoft:enforceArenaInventory')
end

function Inventory.StartArenaItemLock()
    if Config.InventorySystem == 'ox_inventory' then
        RegisterNetEvent('ox_inventory:updateSlots', function()
            if State.isInArena then
                Inventory.RemoveDisallowedArenaItems()
            end
        end)
    end

    CreateThread(function()
        while true do
            local interval = Config.ArenaItemLockIntervalMs or 1500
            if interval < 250 then
                interval = 250
            end

            Wait(interval)

            if State.isInArena then
                Inventory.RemoveDisallowedArenaItems()
            end
        end
    end)
end

function Inventory.SaveAndClear()
    return Framework.AwaitCallback('matti-airsoft:stashPlayerInventory') == true
end

function Inventory.Restore()
    TriggerServerEvent('matti-airsoft:restoreItems')
end

RegisterArenaInventoryOverride()

RegisterNetEvent('matti-airsoft:arenaStateChanged', function(isInArena)
    if Config.Debug and isInArena then
        print('Player is inside arena, enforcing inventory restrictions.')
    end
end)