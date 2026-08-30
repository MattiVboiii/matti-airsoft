Inventory = {}

local removalNotifiedItems = {}
local whitelistedArenaItems = {}
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

local function IsWhitelistedArenaItem(itemName)
    local normalizedItemName = SharedUtils.NormalizeItemName(itemName)
    if not normalizedItemName then
        return false
    end

    return whitelistedArenaItems[normalizedItemName] == true
end

function Inventory.BuildAllowedArenaItems()
    allowedArenaItems = {}
    whitelistedArenaItems = {}

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
            whitelistedArenaItems[normalizedItemName] = true
            allowedArenaItems[normalizedItemName] = true
        end
    end
end

function Inventory.RemoveDisallowedArenaItems()
    if not Config.EnforceArenaLoadoutItemsOnly then
        return
    end

    if not State.isInArena or not State.currentLoadout then
        removalNotifiedItems = {}
        return
    end

    if Config.InventorySystem == 'qb-inventory' then
        local items = QBCore.Functions.GetPlayerData().items or {}

        for _, item in pairs(items) do
            local normalizedItemName = SharedUtils.NormalizeItemName(item.name)
            if normalizedItemName and item.amount and item.amount > 0 and not allowedArenaItems[normalizedItemName] then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
                if not removalNotifiedItems[normalizedItemName] then
                    removalNotifiedItems[normalizedItemName] = true
                    Utils.SendNotification(Lang:t('notifications.item_removed_in_arena', {
                        item = SharedUtils.TrimDisplayText(item.name, 50),
                        amount = item.amount,
                    }), 'error')
                end

                if Config.Debug then
                    print(' Removed non-airsoft item while in arena: ' .. item.name .. ' x' .. item.amount)
                end
            end
        end
    elseif Config.InventorySystem == 'ox_inventory' then
        local items = exports.ox_inventory:GetPlayerItems() or {}

        for _, item in pairs(items) do
            local normalizedItemName = SharedUtils.NormalizeItemName(item.name)
            if normalizedItemName and item.count and item.count > 0 and not allowedArenaItems[normalizedItemName] then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, item.count)
                if not removalNotifiedItems[normalizedItemName] then
                    removalNotifiedItems[normalizedItemName] = true
                    Utils.SendNotification(Lang:t('notifications.item_removed_in_arena', {
                        item = SharedUtils.TrimDisplayText(item.name, 50),
                        amount = item.count,
                    }), 'error')
                end

                if Config.Debug then
                    print(' Removed non-airsoft item while in arena: ' .. item.name .. ' x' .. item.count)
                end
            end
        end
    else
        print('No supported inventory found: ' .. Config.InventorySystem)
    end
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
            if not State.isInArena then
                interval = 3000
            elseif interval < 250 then
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
    if Config.InventorySystem == 'qb-inventory' then
        local playerData = QBCore.Functions.GetPlayerData()
        local playerItems = playerData.items or {}

        for _, item in pairs(playerItems) do
            local amount = item.amount or item.count or 0
            if item.name and amount > 0 and not IsWhitelistedArenaItem(item.name) then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, amount, item.slot, item.info)
            end
        end
    elseif Config.InventorySystem == 'ox_inventory' then
        local items = exports.ox_inventory:GetPlayerItems() or {}

        for _, item in pairs(items) do
            local amount = item.count or item.amount or 0
            if item.name and amount > 0 and not IsWhitelistedArenaItem(item.name) then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, amount, item.slot, item.metadata)
            end
        end
    else
        print('No supported inventory found: ' .. Config.InventorySystem)
    end
end

function Inventory.Restore()
    TriggerServerEvent('matti-airsoft:restoreItems')
    removalNotifiedItems = {}
end

RegisterArenaInventoryOverride()

RegisterNetEvent('matti-airsoft:arenaStateChanged', function(isInArena)
    if Config.Debug and isInArena then
        print('Player is inside arena, enforcing inventory restrictions.')
    end
end)