Inventory = {}

local removalNotifiedItems = {}
local whitelistedArenaItems = {}

local function NormalizeItemName(itemName)
    if not itemName then
        return nil
    end

    return string.lower(tostring(itemName))
end

local function IsWhitelistedArenaItem(itemName)
    local normalizedItemName = NormalizeItemName(itemName)
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

    for _, itemName in ipairs(Config.ArenaItemWhitelist or {}) do
        local normalizedItemName = NormalizeItemName(itemName)
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
            local normalizedItemName = NormalizeItemName(item.name)
            if normalizedItemName and item.amount and item.amount > 0 and not allowedArenaItems[normalizedItemName] then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, item.amount)
                if not removalNotifiedItems[normalizedItemName] then
                    removalNotifiedItems[normalizedItemName] = true
                    Utils.SendNotification(Lang:t('notifications.item_removed_in_arena', {
                        item = item.name,
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
            local normalizedItemName = NormalizeItemName(item.name)
            if normalizedItemName and item.count and item.count > 0 and not allowedArenaItems[normalizedItemName] then
                TriggerServerEvent('matti-airsoft:removeItem', item.name, item.count)
                if not removalNotifiedItems[normalizedItemName] then
                    removalNotifiedItems[normalizedItemName] = true
                    Utils.SendNotification(Lang:t('notifications.item_removed_in_arena', {
                        item = item.name,
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
    State.originalInventory = {}

    if Config.InventorySystem == 'qb-inventory' then
        local playerData = QBCore.Functions.GetPlayerData()
        local playerItems = playerData.items or {}

        for _, item in pairs(playerItems) do
            local amount = item.amount or item.count or 0
            if item.name and amount > 0 and not IsWhitelistedArenaItem(item.name) then
                local slot = item.slot
                local metadata = item.info

                State.originalInventory[#State.originalInventory + 1] = {
                    name = item.name,
                    amount = amount,
                    slot = slot,
                    metadata = metadata,
                }

                TriggerServerEvent('matti-airsoft:removeItem', item.name, amount, slot, metadata)
            end
        end
    elseif Config.InventorySystem == 'ox_inventory' then
        local items = exports.ox_inventory:GetPlayerItems() or {}

        for _, item in pairs(items) do
            local amount = item.count or item.amount or 0
            if item.name and amount > 0 and not IsWhitelistedArenaItem(item.name) then
                State.originalInventory[#State.originalInventory + 1] = {
                    name = item.name,
                    amount = amount,
                    slot = item.slot,
                    metadata = item.metadata,
                }

                TriggerServerEvent('matti-airsoft:removeItem', item.name, amount, item.slot, item.metadata)
            end
        end
    else
        print('No supported inventory found: ' .. Config.InventorySystem)
    end
end

function Inventory.Restore()
    for _, item in pairs(State.originalInventory) do
        local itemAmount = item.amount or item.count
        if item.name and itemAmount and itemAmount > 0 then
            TriggerServerEvent('matti-airsoft:giveItem', item.name, itemAmount, item.metadata, item.slot)
        end
    end
    State.originalInventory = {}
    removalNotifiedItems = {}
end
