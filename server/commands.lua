local function ClearArenaForPlayer(playerId)
    TriggerClientEvent('matti-airsoft:forceExitArena', playerId)
    Data.arenaStats[playerId] = nil
    Data.arenaPresence[playerId] = nil
    Data.arenaStatLobbies[playerId] = nil
    Data.recentAttackers[playerId] = nil
    MatchState.ClearPlayer(playerId)
end

QBCore.Commands.Add(
    'exitarena',
    Lang:t('command.description_exitarena'),
    { { name = 'id', help = Lang:t('command.help_exitarena') } },
    false,
    function(source, args)
        if args[1] == 'all' then
            local removedCount = 0
            local activeLobbyId = Data.activeLobbyInArena

            for playerId, _ in pairs(Data.arenaStats) do
                ClearArenaForPlayer(playerId)
                removedCount = removedCount + 1
            end

            if activeLobbyId then
                Leaderboard.FinalizeMatch(activeLobbyId)
            else
                Data.activeLobbyInArena = nil
            end

            Leaderboard.Broadcast()
            TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.all_players_removed'), 'success')
            if Config.Debug then
                print(' Admin ' .. source .. ' removed all players from arena (' .. removedCount .. ' players)')
            end
        else
            local playerId = tonumber(args[1]) or source
            if playerId then
                local targetPlayer = Utils.GetPlayer(playerId)
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
