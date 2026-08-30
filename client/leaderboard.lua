Leaderboard = {}

local function SendLeaderboardVisibility(show, rows)
    SendNUIMessage({
        action = 'showLeaderboard',
        show = show,
        leaderboard = rows,
        accentColor = Config.LeaderboardAccentColor
    })
end

function Leaderboard.SetCachedRows(rows)
    State.cachedLeaderboardRows = rows or {}
end

function Leaderboard.GetCachedRows()
    return State.cachedLeaderboardRows or {}
end

function Leaderboard.ApplyUiTheme()
    SendNUIMessage({
        action = 'setUiTheme',
        accentColor = Config.LeaderboardAccentColor,
    })
end

function Leaderboard.Show()
    if not Config.LeaderboardEnabled then
        return
    end

    State.leaderboardVisible = true

    QBCore.Functions.TriggerCallback('matti-airsoft:getLeaderboard', function(leaderboard)
        Leaderboard.SetCachedRows(leaderboard)
        Leaderboard.ApplyUiTheme()
        SendLeaderboardVisibility(true, leaderboard)
        SetNuiFocus(false, false)
    end)
end

function Leaderboard.Hide()
    State.leaderboardVisible = false
    SendLeaderboardVisibility(false)
end

function Leaderboard.HideFinalOnExit()
    State.finalScoreboardVisible = false
    SendNUIMessage({
        action = 'showFinalScoreboard',
        show = false
    })
    SetNuiFocus(false, false)
end

function Leaderboard.ShowFinalOnExit()
    if not Config.LeaderboardEnabled or not Config.ShowFinalScoreboardOnExit then
        Leaderboard.Hide()
        Leaderboard.HideFinalOnExit()
        return
    end

    local cachedRows = Leaderboard.GetCachedRows()
    if not cachedRows or #cachedRows == 0 then
        Leaderboard.Hide()
        Leaderboard.HideFinalOnExit()
        return
    end

    Leaderboard.Hide()
    State.finalScoreboardVisible = true
    Leaderboard.ApplyUiTheme()
    SendNUIMessage({
        action = 'showFinalScoreboard',
        show = true,
        leaderboard = cachedRows,
        accentColor = Config.LeaderboardAccentColor
    })
    SetNuiFocus(true, true)
end

function Leaderboard.Toggle()
    if not Config.LeaderboardEnabled or not State.isInArena then
        return
    end

    if State.leaderboardVisible then
        Leaderboard.Hide()
    else
        Leaderboard.Show()
    end
end

function Leaderboard.HandleKeybind()
    if not Config.LeaderboardEnabled then
        return
    end

    lib.addKeybind({
        name = 'matti_airsoft_leaderboard',
        description = 'Toggle airsoft leaderboard',
        defaultKey = 'F5',
        onPressed = function()
            Leaderboard.Toggle()
        end,
    })
end
