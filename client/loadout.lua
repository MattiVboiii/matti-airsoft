Loadout = {}

function Loadout.Handle(loadout)
    QBCore.Functions.TriggerCallback('matti-airsoft:canAffordLoadout', function(canAfford)
        if canAfford then
            Inventory.SaveAndClear()

            for _, weapon in ipairs(loadout.weapons) do
                TriggerServerEvent('matti-airsoft:giveWeapon', weapon.name)
            end

            for _, ammo in ipairs(loadout.ammo) do
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
    if State.currentLoadout == nil then
        return
    end

    for _, loadout in ipairs(Config.Loadouts) do
        for _, weapon in ipairs(loadout.weapons) do
            TriggerServerEvent('matti-airsoft:removeWeapon', weapon.name)
        end

        for _, ammo in ipairs(loadout.ammo) do
            local currentAmmo = 0
            if Config.InventorySystem == 'qb-inventory' then
                local items = QBCore.Functions.GetPlayerData().items
                for _, item in pairs(items) do
                    if item.name == ammo.name and item.amount > 0 then
                        currentAmmo = item.amount
                        break
                    end
                end
            elseif Config.InventorySystem == 'ox_inventory' then
                currentAmmo = exports.ox_inventory:Search('count', ammo.name)
            end

            if currentAmmo > 0 then
                TriggerServerEvent('matti-airsoft:removeItem', ammo.name, currentAmmo)
            end
        end
    end

    State.currentLoadout = nil
end
