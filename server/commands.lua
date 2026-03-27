QBCore.Commands.Add(
    'exitarena',
    Lang:t('command.description_exitarena'),
    { { name = 'id', help = Lang:t('command.help_exitarena') } },
    false,
    function(source, args)
        if args[1] == 'all' then
            local removedCount = 0
            for playerId, _ in pairs(Data.arenaStats) do
                TriggerClientEvent('matti-airsoft:forceExitArena', playerId)
                Data.arenaStats[playerId] = nil
                Data.arenaPresence[playerId] = nil
                Data.arenaStatLobbies[playerId] = nil
                removedCount = removedCount + 1
            end
            Leaderboard.Broadcast()
            TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.all_players_removed'), 'success')
            if Config.Debug then
                print(' Admin ' .. source .. ' removed all players from arena (' .. removedCount .. ' players)')
            end
        else
            local playerId = tonumber(args[1]) or source
            if playerId then
                local targetPlayer = QBCore.Functions.GetPlayer(playerId)
                if targetPlayer then
                    Data.pendingArenaStatusChecks = Data.pendingArenaStatusChecks or {}
                    Data.pendingArenaStatusChecks[playerId] = source
                    TriggerClientEvent('matti-airsoft:checkIfInArena', playerId, source)
                else
                    TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
                end
            else
                TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
            end
        end
    end,
    'admin'
)
