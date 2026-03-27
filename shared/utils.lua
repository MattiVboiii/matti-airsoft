SharedUtils = SharedUtils or {}

function SharedUtils.NormalizeLowerString(value)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = string.lower(value)
    if normalized == '' then
        return nil
    end

    return normalized
end

function SharedUtils.NormalizeModeId(mode)
    return SharedUtils.NormalizeLowerString(mode)
end

function SharedUtils.NormalizeItemName(itemName)
    return SharedUtils.NormalizeLowerString(itemName)
end

function SharedUtils.GetConfiguredGameModes()
    local modes = {}

    for _, mode in ipairs(Config.GameModes or {}) do
        if type(mode) == 'table' then
            local modeId = SharedUtils.NormalizeModeId(mode.id)
            if modeId and not modes[modeId] then
                modes[modeId] = {
                    id = modeId,
                    label = mode.label or ('menu.' .. modeId),
                    description = mode.description or ('menu.' .. modeId .. '_desc'),
                    icon = mode.icon or (modeId == 'teams' and 'fas fa-users' or 'fas fa-user'),
                    iconColor = mode.iconColor or (modeId == 'teams' and '#9b59b6' or '#f39c12'),
                    teamBased = mode.teamBased == true,
                }
            end
        elseif type(mode) == 'string' then
            local modeId = SharedUtils.NormalizeModeId(mode)
            if modeId and not modes[modeId] then
                modes[modeId] = {
                    id = modeId,
                    label = 'menu.' .. modeId,
                    description = 'menu.' .. modeId .. '_desc',
                    icon = modeId == 'teams' and 'fas fa-users' or 'fas fa-user',
                    iconColor = modeId == 'teams' and '#9b59b6' or '#f39c12',
                    teamBased = modeId == 'teams',
                }
            end
        end
    end

    if next(modes) == nil then
        modes.ffa = {
            id = 'ffa',
            label = 'menu.ffa',
            description = 'menu.ffa_desc',
            icon = 'fas fa-user',
            iconColor = '#f39c12',
            teamBased = false,
        }
        modes.teams = {
            id = 'teams',
            label = 'menu.teams',
            description = 'menu.teams_desc',
            icon = 'fas fa-users',
            iconColor = '#9b59b6',
            teamBased = true,
        }
    end

    return modes
end

function SharedUtils.GetOrderedModeIds()
    local orderedIds = {}

    for _, mode in ipairs(Config.GameModes or {}) do
        if type(mode) == 'table' then
            local modeId = SharedUtils.NormalizeModeId(mode.id)
            if modeId then
                table.insert(orderedIds, modeId)
            end
        elseif type(mode) == 'string' then
            local modeId = SharedUtils.NormalizeModeId(mode)
            if modeId then
                table.insert(orderedIds, modeId)
            end
        end
    end

    if #orderedIds == 0 then
        return { 'ffa', 'teams' }
    end

    return orderedIds
end

function SharedUtils.IsTeamBasedMode(mode)
    local modeId = SharedUtils.NormalizeModeId(mode)
    if not modeId then
        return false
    end

    local modeConfig = SharedUtils.GetConfiguredGameModes()[modeId]
    return modeConfig and modeConfig.teamBased == true or false
end

function SharedUtils.GetDefaultGameMode()
    local configuredDefault = SharedUtils.NormalizeModeId(Config.DefaultGameMode)
    if configuredDefault and SharedUtils.GetConfiguredGameModes()[configuredDefault] then
        return configuredDefault
    end

    if SharedUtils.GetConfiguredGameModes().ffa then
        return 'ffa'
    end

    for modeId, _ in pairs(SharedUtils.GetConfiguredGameModes()) do
        return modeId
    end

    return 'ffa'
end

function SharedUtils.IsPositiveWholeNumber(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

function SharedUtils.ValidatePositiveWholeNumber(value, maxValue)
    local numericValue = tonumber(value)
    if not SharedUtils.IsPositiveWholeNumber(numericValue) then
        return false, nil
    end

    if maxValue and numericValue > maxValue then
        return false, nil
    end

    return true, numericValue
end

function SharedUtils.TrimDisplayText(value, maxLength)
    local text = tostring(value or '')
    local limit = tonumber(maxLength) or 64
    if limit < 1 then
        limit = 1
    end

    if #text > limit then
        return text:sub(1, limit)
    end

    return text
end