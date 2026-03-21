Leaderboard = {}

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
        Leaderboard.ApplyUiTheme()
        SendNUIMessage({
            action = 'showLeaderboard',
            show = true,
            leaderboard = leaderboard,
            accentColor = Config.LeaderboardAccentColor
        })
        SetNuiFocus(false, false)
    end)
end

function Leaderboard.Hide()
    State.leaderboardVisible = false
    SendNUIMessage({
        action = 'showLeaderboard',
        show = false
    })
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
    Citizen.CreateThread(function()
        while true do
            local waitTime = 500

            if Config.LeaderboardEnabled and State.isInArena then
                waitTime = 0
                if IsControlJustPressed(0, Config.LeaderboardKey) then
                    Leaderboard.Toggle()
                end
            end

            Wait(waitTime)
        end
    end)
end
