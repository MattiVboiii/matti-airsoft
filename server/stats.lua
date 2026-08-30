Stats = {}

local function GetPlayerIdentifier(playerId)
    local player = Utils.GetPlayer(playerId)
    if not player then
        return nil
    end

    if Config.Framework == 'ox' then
        return player.charId or (player.get and player.get('charId')) or nil
    end

    if player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end

    return nil
end

function Stats.Initialize()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `matti_airsoft_stats` (
            `citizenid` VARCHAR(50) NOT NULL,
            `kills` INT NOT NULL DEFAULT 0,
            `deaths` INT NOT NULL DEFAULT 0,
            `matches_played` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        )
    ]])
end

function Stats.PersistMatchResults(lobbyId)
    if not lobbyId then
        return
    end

    for playerId, trackedLobbyId in pairs(Data.arenaStatLobbies) do
        if trackedLobbyId == lobbyId then
            local stats = Data.arenaStats[playerId]
            local citizenid = GetPlayerIdentifier(playerId)
            if stats and citizenid then
                MySQL.insert.await([[
                    INSERT INTO matti_airsoft_stats (citizenid, kills, deaths, matches_played)
                    VALUES (?, ?, ?, 1)
                    ON DUPLICATE KEY UPDATE
                        kills = kills + VALUES(kills),
                        deaths = deaths + VALUES(deaths),
                        matches_played = matches_played + 1
                ]], {
                    citizenid,
                    stats.kills or 0,
                    stats.deaths or 0,
                })
            end
        end
    end
end

function Stats.GetPlayerStats(playerId)
    local citizenid = GetPlayerIdentifier(playerId)
    if not citizenid then
        return nil
    end

    return MySQL.single.await(
        'SELECT kills, deaths, matches_played FROM matti_airsoft_stats WHERE citizenid = ?',
        { citizenid }
    )
end
