Inventory = {}

local function NormalizeItemName(itemName)
    if not itemName then
        return nil
    end

    return string.lower(tostring(itemName))
end

function Inventory.BuildAllowedArenaItems()
    allowedArenaItems = {}

    for _, loadout in ipairs(Config.Loadouts or {}) do
        for _, weapon in ipairs(loadout.weapons or {}) do
            if weapon.name then
                local normalizedWeaponName = NormalizeItemName(weapon.name)
                if normalizedWeaponName then
                    allowedArenaItems[normalizedWeaponName] = true
                end
            end
        end

        for _, ammo in ipairs(loadout.ammo or {}) do
            if ammo.name then
                local normalizedAmmoName = NormalizeItemName(ammo.name)
                if normalizedAmmoName then
                    allowedArenaItems[normalizedAmmoName] = true
                end
            end
        end
    end
end

function Inventory.RemoveDisallowedArenaItems()
    if not Config.EnforceArenaLoadoutItemsOnly then
        return
    end

    if not State.isInArena or not State.currentLoadout then
        return
    end

    if Config.InventorySystem == 'qb-inventory' then
        local items = QBCore.Functions.GetPlayerData().items or {}

        for _, item in pairs(items) do
            local normalizedItemName = NormalizeItemName(item.name)
            if normalizedItemName and item.amount and item.amount > 0 and not allowedArenaItems[normalizedItemName] then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
                Utils.SendNotification(Lang:t('notifications.item_removed_in_arena', {
                    item = item.name,
                    amount = item.amount,
                }), 'error')

                if Config.Debug then
                    print(' Removed non-airsoft item while in arena: ' .. item.name .. ' x' .. item.amount)
                end
            end
        end
    elseif Config.InventorySystem == 'ox_inventory' then
        local items = exports.ox_inventory:GetPlayerItems() or {}

        for _, item in pairs(items) do
            local normalizedItemName = NormalizeItemName(item.name)
            if normalizedItemName and item.count and item.count > 0 and not allowedArenaItems[normalizedItemName] then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, item.count)
                Utils.SendNotification(Lang:t('notifications.item_removed_in_arena', {
                    item = item.name,
                    amount = item.count,
                }), 'error')

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
    Citizen.CreateThread(function()
        while true do
            local interval = Config.ArenaItemLockIntervalMs or 1500
            if interval < 250 then
                interval = 250
            end

            Wait(interval)
            Inventory.RemoveDisallowedArenaItems()
        end
    end)
end

function Inventory.SaveAndClear()
    local playerData = QBCore.Functions.GetPlayerData()
    local playerItems = playerData.items or {}

    if Config.InventorySystem == 'qb-inventory' then
        for _, item in pairs(playerItems) do
            TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
        end
    elseif Config.InventorySystem == 'ox_inventory' then
        for _, item in pairs(exports.ox_inventory:GetPlayerItems()) do
            TriggerServerEvent('matti-airsoft:removeItem', item.name, item.count)
        end
    else
        print('No supported inventory found: ' .. Config.InventorySystem)
    end

    State.originalInventory = table.clone(playerItems)
end

function Inventory.Restore()
    for _, item in pairs(State.originalInventory) do
        local itemAmount = item.amount or item.count
        TriggerServerEvent('matti-airsoft:giveItem', item.name, itemAmount)
    end
    State.originalInventory = {}
end
