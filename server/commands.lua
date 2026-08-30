local function ClearArenaForPlayer(playerId)
    TriggerClientEvent('matti-airsoft:forceExitArena', playerId)
    Data.arenaStats[playerId] = nil
    Data.arenaPresence[playerId] = nil
    Data.arenaStatLobbies[playerId] = nil
    Data.recentAttackers[playerId] = nil
    MatchState.ClearPlayer(playerId)
end

local function HandleExitArenaCommand(source, targetArg)
    if targetArg == 'all' then
        local removedCount = 0
        local activeLobbyId = Data.activeLobbyInArena

        for playerId, _ in pairs(Data.arenaStats) do
            ClearArenaForPlayer(playerId)
            removedCount = removedCount + 1
        end

        if activeLobbyId then
            ModesShared.EndMatch(activeLobbyId, 'admin')
        else
            Data.activeLobbyInArena = nil
        end

        Leaderboard.Broadcast()
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.all_players_removed'), 'success')
        if Config.Debug then
            print(' Admin ' .. source .. ' removed all players from arena (' .. removedCount .. ' players)')
        end
        return
    end

    local playerId = tonumber(targetArg) or source
    if not playerId then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
        return
    end

    local targetPlayer = Utils.GetPlayer(playerId)
    if not targetPlayer then
        TriggerClientEvent('matti-airsoft:sendNotification', source, Lang:t('command.invalid_player_id'), 'error')
        return
    end

    Data.pendingArenaStatusChecks = Data.pendingArenaStatusChecks or {}
    Data.pendingArenaStatusChecks[playerId] = source
    TriggerClientEvent('matti-airsoft:checkIfInArena', playerId, source)
end

if Config.Framework == 'qb' and QBCore and QBCore.Commands then
    QBCore.Commands.Add(
        'exitarena',
        Lang:t('command.description_exitarena'),
        { { name = 'id', help = Lang:t('command.help_exitarena') } },
        false,
        function(source, args)
            HandleExitArenaCommand(source, args[1])
        end,
        'admin'
    )
else
    lib.addCommand('exitarena', {
        help = Lang:t('command.description_exitarena'),
        restricted = 'group.admin',
        params = {
            {
                name = 'id',
                help = Lang:t('command.help_exitarena'),
                type = 'longString',
                optional = true,
            },
        },
    }, function(source, args)
        HandleExitArenaCommand(source, args.id)
    end)
end
