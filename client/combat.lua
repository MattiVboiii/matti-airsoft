Combat = {}

local trackedWeaponHashes = {}
for _, weaponName in ipairs(Config.ScoreboardTrackedWeapons or {}) do
    trackedWeaponHashes[GetHashKey(weaponName)] = true
end

function Combat.GetAttributionGraceMs()
    return Config.ScoreboardHitGracePeriod or 5000
end

function Combat.GetKillerFallbackDistance()
    return Config.KillerFallbackDistance or 60.0
end

function Combat.IsTrackedWeapon(weaponHash)
    return weaponHash and trackedWeaponHashes[weaponHash] == true
end

function Combat.ResolveTrackedWeapon(attackerPed, eventWeaponHash, victimPed)
    if Combat.IsTrackedWeapon(eventWeaponHash) then
        return eventWeaponHash
    end

    if attackerPed and attackerPed ~= 0 then
        local selectedWeapon = GetSelectedPedWeapon(attackerPed)
        if Combat.IsTrackedWeapon(selectedWeapon) then
            return selectedWeapon
        end
    end

    if victimPed and victimPed ~= 0 then
        for trackedWeaponHash in pairs(trackedWeaponHashes) do
            if HasEntityBeenDamagedByWeapon(victimPed, trackedWeaponHash, 0) then
                return trackedWeaponHash
            end
        end
    end

    return nil
end

function Combat.GetRecentTrackedHit()
    if not State.lastTrackedHit then
        return nil
    end

    if (GetGameTimer() - State.lastTrackedHit.timestamp) > Combat.GetAttributionGraceMs() then
        State.lastTrackedHit = nil
        return nil
    end

    return State.lastTrackedHit
end

function Combat.GetRecentAttacker()
    if not State.lastAttacker then
        return nil
    end

    if (GetGameTimer() - State.lastAttacker.timestamp) > Combat.GetAttributionGraceMs() then
        State.lastAttacker = nil
        return nil
    end

    return State.lastAttacker
end

function Combat.GetClosestPlayerServerId(maxDistance)
    local playerPed = PlayerPedId()
    local myCoords = GetEntityCoords(playerPed)
    local closestDistance = maxDistance or 25.0
    local closestServerId = nil

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and targetPed ~= 0 then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(myCoords - targetCoords)
                if distance <= closestDistance then
                    closestDistance = distance
                    closestServerId = GetPlayerServerId(playerId)
                end
            end
        end
    end

    return closestServerId
end

function Combat.ResolveKillerId(playerPed)
    local killerId = nil
    local shouldCreditKiller = false
    local killerPed = GetPedSourceOfDeath(playerPed)
    local causeOfDeath = GetPedCauseOfDeath(playerPed)
    local recentTrackedHit = Combat.GetRecentTrackedHit()
    local recentAttacker = Combat.GetRecentAttacker()

    if killerPed and killerPed ~= 0 and killerPed ~= playerPed and IsPedAPlayer(killerPed) then
        local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
        if killerPlayerId and killerPlayerId ~= -1 then
            killerId = GetPlayerServerId(killerPlayerId)
            shouldCreditKiller = Combat.ResolveTrackedWeapon(killerPed, causeOfDeath, playerPed) ~= nil
        end
    end

    if not shouldCreditKiller and recentTrackedHit then
        killerId = recentTrackedHit.serverId
        shouldCreditKiller = true
        if Config.Debug then
            print(' Using recent tracked hit for killer ID: ' .. tostring(killerId))
        end
    end

    if not shouldCreditKiller and recentAttacker then
        killerId = recentAttacker.serverId
        shouldCreditKiller = true
        if Config.Debug then
            print(' Using recent attacker fallback for killer ID: ' .. tostring(killerId))
        end
    end

    if not killerId then
        killerId = Combat.GetClosestPlayerServerId(Combat.GetKillerFallbackDistance())
        if killerId and Config.Debug then
            print(' Using closest player fallback for killer ID: ' .. tostring(killerId))
        end
    end

    return killerId, shouldCreditKiller, killerPed, causeOfDeath
end

function Combat.TrackDamage()
    AddEventHandler('gameEventTriggered', function(event, data)
        if event ~= 'CEventNetworkEntityDamage' then
            return
        end

        local victim = data[1]
        local attacker = data[2]
        local eventWeaponHash = data[7]
        local playerPed = PlayerPedId()

        if victim ~= playerPed or not State.isInArena then
            return
        end

        if not attacker or attacker == 0 or attacker == playerPed or not IsPedAPlayer(attacker) then
            return
        end

        local attackerPlayerId = NetworkGetPlayerIndexFromPed(attacker)
        if not attackerPlayerId or attackerPlayerId == -1 then
            return
        end

        local attackerServerId = GetPlayerServerId(attackerPlayerId)
        State.lastAttacker = {
            serverId = attackerServerId,
            timestamp = GetGameTimer()
        }

        TriggerServerEvent('matti-airsoft:registerRecentAttacker', attackerServerId)

        if Config.Debug then
            print(' Damage detected from player server ID: ' .. tostring(attackerServerId) .. ' with event weapon hash: ' .. tostring(eventWeaponHash))
        end

        local trackedWeaponHash = Combat.ResolveTrackedWeapon(attacker, eventWeaponHash, playerPed)
        if trackedWeaponHash then
            State.lastTrackedHit = {
                serverId = attackerServerId,
                weaponHash = trackedWeaponHash,
                timestamp = GetGameTimer()
            }

            if Config.Debug then
                print(' Tracked airsoft hit from player server ID: ' .. tostring(attackerServerId) .. ' with weapon hash: ' .. tostring(trackedWeaponHash))
            end
        elseif Config.Debug then
            print(' Damage ignored for scoreboard (non-airsoft or unresolved weapon). Event weapon hash: ' .. tostring(eventWeaponHash))
        end
    end)
end

function Combat.CheckHitStatus()
    Citizen.CreateThread(function()
        while State.isInArena do
            Wait(100)
            local playerPed = PlayerPedId()

            if IsPedBeingStunned(playerPed, 0) or IsEntityDead(playerPed) then
                if not State.isHit then
                    State.isHit = true

                    local killerId, shouldCreditKiller, killerPed, causeOfDeath = Combat.ResolveKillerId(playerPed)

                    if Config.Debug then
                        local stunStatus = IsPedBeingStunned(playerPed, 0) and 'STUNNED' or 'DEAD'
                        print(' Player was hit (' .. stunStatus .. '). Cause hash: ' .. tostring(causeOfDeath) .. ', Killer Ped: ' .. tostring(killerPed) .. ', Killer server ID: ' .. tostring(killerId) .. ', Counted on scoreboard: true, Credited killer: ' .. tostring(shouldCreditKiller))
                    end

                    TriggerServerEvent('matti-airsoft:playerWasHit', killerId)

                    State.lastAttacker = nil
                    State.lastTrackedHit = nil

                    Citizen.CreateThread(function()
                        local wasStunned = IsPedBeingStunned(playerPed, 0) and not IsEntityDead(playerPed)

                        if Config.Debug then
                            print(' Starting revive logic. Was stunned: ' .. tostring(wasStunned))
                        end

                        local deathmatchEnabled = Config.ContinuePlayingAfterDeath
                        if type(Config.DeathmatchEnabledByDefault) == 'boolean' then
                            deathmatchEnabled = Config.DeathmatchEnabledByDefault
                        end
                        if State.currentLobby then
                            deathmatchEnabled = State.currentLobby.deathmatchEnabled == true
                        end

                        if Config.TeleportOnHit then
                            if deathmatchEnabled then
                                Utils.SendNotification(Lang:t('inarena.shot'))
                                Wait(2000)
                                Player.TeleportToRandomPosition()
                            else
                                Utils.SendNotification(Lang:t('inarena.shotandout'))
                                -- Run full exit flow so HUD/NUI always gets cleaned when eliminated.
                                TriggerEvent('matti-airsoft:exitArena')
                            end
                        else
                            Utils.SendNotification(Lang:t('inarena.shot'))
                        end

                        if wasStunned then
                            if Config.Debug then
                                print(' Player was stunned, reviving immediately')
                            end
                            Wait(500)
                            TriggerServerEvent('matti-airsoft:revivePlayer')
                        else
                            if Config.Debug then
                                print(' Player in laststand/death, reviving from laststand')
                            end
                            Wait(1000)
                            TriggerServerEvent('matti-airsoft:revivePlayer')
                        end
                    end)
                end
            else
                State.isHit = false
            end
        end
    end)
end
