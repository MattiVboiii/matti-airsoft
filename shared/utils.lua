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

function SharedUtils.IsLmsEnabled(lobby)
    return type(lobby) == 'table' and lobby.lmsEnabled == true
end

function SharedUtils.IsGunGameMode(mode)
    return SharedUtils.NormalizeModeId(mode) == 'gungame'
end

function SharedUtils.GetGunGameStages()
    local stages = {}
    local seen = {}

    for _, loadout in ipairs(Config.Loadouts or {}) do
        for _, weapon in ipairs(loadout.weapons or {}) do
            local normalizedName = SharedUtils.NormalizeItemName(weapon.name)
            if normalizedName and not seen[normalizedName] then
                seen[normalizedName] = true
                local ammoEntry = nil
                for _, ammo in ipairs(loadout.ammo or {}) do
                    ammoEntry = ammo
                    break
                end
                stages[#stages + 1] = {
                    weapon = weapon.name,
                    ammo = ammoEntry,
                }
            end
        end
    end

    return stages
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

function SharedUtils.GetLoadoutWeaponNames()
    local weaponNames = {}
    local seen = {}

    for _, loadout in ipairs(Config.Loadouts or {}) do
        for _, weapon in ipairs(loadout.weapons or {}) do
            local normalizedName = SharedUtils.NormalizeItemName(weapon.name)
            if normalizedName and not seen[normalizedName] then
                seen[normalizedName] = true
                weaponNames[#weaponNames + 1] = weapon.name
            end
        end
    end

    return weaponNames
end

local function IsPointInsidePolygon(coords, points)
    local inside = false
    local previousIndex = #points

    for index = 1, #points do
        local currentPoint = points[index]
        local previousPoint = points[previousIndex]

        local intersects = ((currentPoint.y > coords.y) ~= (previousPoint.y > coords.y))
            and (coords.x < (previousPoint.x - currentPoint.x) * (coords.y - currentPoint.y) / (previousPoint.y - currentPoint.y) + currentPoint.x)

        if intersects then
            inside = not inside
        end

        previousIndex = index
    end

    return inside
end

function SharedUtils.IsCoordsInArena(coords)
    if not coords then
        return false
    end

    if Config.ZoneType == 'circle' then
        return #(coords - Config.AirsoftZone.coordinates) <= Config.AirsoftZone.radius
    end

    if Config.ZoneType == 'poly' then
        local points = Config.AirsoftZone.points or {}
        if #points < 3 then
            return false
        end

        local halfThickness = (Config.AirsoftZone.thickness or 20) / 2
        local minZ = points[1].z - halfThickness
        local maxZ = points[1].z + halfThickness

        for index = 2, #points do
            local pointZ = points[index].z
            minZ = math.min(minZ, pointZ - halfThickness)
            maxZ = math.max(maxZ, pointZ + halfThickness)
        end

        local zTolerance = 0.1
        return coords.z >= (minZ - zTolerance)
            and coords.z <= (maxZ + zTolerance)
            and IsPointInsidePolygon(coords, points)
    end

    return false
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