Loadout = {}

function Loadout.Handle(loadout)
    if not loadout then
        return
    end

    local result = Framework.AwaitCallback('matti-airsoft:prepareArenaLoadout', loadout.price)
    if result ~= true then
        if result == 'cannot_afford' then
            Utils.SendNotification(Lang:t('notifications.cannot_afford'), 'error')
        end
        return
    end

    SetCurrentPedWeapon(PlayerPedId(), GetHashKey('WEAPON_UNARMED'), true)
    State.currentLoadout = loadout
    State.suppressZoneExitUntil = GetGameTimer() + 3000

    Utils.SendNotification(Lang:t('notifications.loadout_selected', { loadout = loadout.name }), 'success')
    Player.TeleportToRandomPosition()
end

function Loadout.Remove()
    if State.currentLoadout == nil then
        return
    end

    TriggerServerEvent('matti-airsoft:stripLoadout')
    State.currentLoadout = nil
end
