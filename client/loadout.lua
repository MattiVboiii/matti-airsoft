Loadout = {}

local function GetCurrentAmmoCount(itemName)
    if Config.InventorySystem == 'qb-inventory' then
        local items = (QBCore.Functions.GetPlayerData() or {}).items or {}
        for _, item in pairs(items) do
            if item.name == itemName and item.amount and item.amount > 0 then
                return item.amount
            end
        end

        return 0
    end

    if Config.InventorySystem == 'ox_inventory' then
        return exports.ox_inventory:Search('count', itemName) or 0
    end

    return 0
end

function Loadout.Handle(loadout)
    if not loadout then
        return
    end

    QBCore.Functions.TriggerCallback('matti-airsoft:canAffordLoadout', function(canAfford)
        if canAfford then
            Inventory.SaveAndClear()

            for _, weapon in ipairs(loadout.weapons or {}) do
                TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
            end

            for _, ammo in ipairs(loadout.ammo or {}) do
                TriggerServerEvent('matti-airsoft:giveItem', ammo.name, ammo.amount)
            end

            SetCurrentPedWeapon(PlayerPedId(), GetHashKey('WEAPON_UNARMED'), true)
            State.currentLoadout = loadout

            Utils.SendNotification(Lang:t('notifications.loadout_selected', { loadout = loadout.name }), 'success')
            Player.TeleportToRandomPosition()
        else
            Utils.SendNotification(Lang:t('notifications.cannot_afford'), 'error')
        end
    end, loadout.price)
end

function Loadout.Remove()
    local loadout = State.currentLoadout
    if loadout == nil then
        return
    end

    for _, weapon in ipairs(loadout.weapons or {}) do
        TriggerServerEvent('matti-airsoft:removeWeapon', weapon.name)
    end

    for _, ammo in ipairs(loadout.ammo or {}) do
        local currentAmmo = GetCurrentAmmoCount(ammo.name)

        if currentAmmo > 0 then
            TriggerServerEvent('matti-airsoft:removeItem', ammo.name, currentAmmo)
        end
    end

    State.currentLoadout = nil
end
