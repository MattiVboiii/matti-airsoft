Menu = {}

function Menu.IsQbMenu()
    return Config.MenuSystem == 'qb-menu'
end

function Menu.AddOption(menu, option)
    if Menu.IsQbMenu() then
        local entry = {
            header = option.title,
            txt = option.description or '',
            icon = option.icon,
        }

        if option.isHeader or option.disabled then
            entry.isMenuHeader = true
            entry.icon = nil
        elseif option.event then
            entry.params = {
                event = option.event,
                args = option.args,
            }
        end

        table.insert(menu, entry)
        return
    end

    local entry = {
        title = option.title,
        description = option.description or '',
        icon = option.icon,
        iconColor = option.iconColor,
        disabled = option.disabled or false,
    }

    if option.event then
        entry.event = option.event
        entry.args = option.args
    end

    if option.isHeader then
        entry.disabled = true
    end

    table.insert(menu, entry)
end

function Menu.Open(id, title, options, parentMenu)
    if Menu.IsQbMenu() then
        exports['qb-menu']:openMenu(options)
        return
    end

    if Config.MenuSystem == 'ox_lib' then
        local context = {
            id = id,
            title = title,
            options = options,
        }

        if parentMenu then
            context.menu = parentMenu
        end

        lib.registerContext(context)
        lib.showContext(id)
    else
        print('No supported menu system found: ' .. Config.MenuSystem)
    end
end

function Menu.BuildLoadoutDescription(loadout)
    local weaponsList, ammoList = '', ''

    for _, weapon in ipairs(loadout.weapons) do
        weaponsList = weaponsList .. weapon.label .. '\n'
    end

    for _, ammo in ipairs(loadout.ammo) do
        ammoList = ammoList .. ' (' .. ammo.amount .. ' ' .. Lang:t('menu.clips') .. ')\n'
    end

    return Lang:t('menu.includes') .. '\n' .. weaponsList .. ammoList
end

function Menu.AppendLoadoutOptions(targetMenu, selectEvent)
    for _, loadout in ipairs(Config.Loadouts) do
        Menu.AddOption(targetMenu, {
            title = loadout.name .. ' - $' .. loadout.price,
            description = Menu.BuildLoadoutDescription(loadout),
            event = selectEvent,
            args = { loadout = loadout },
            icon = 'fas fa-crosshairs',
            iconColor = '#EC213A',
        })
    end
end

function Menu.BuildTeamMemberDescription(baseDescription, members)
    local memberNames = members or {}
    local membersLabel = Lang:t('menu.players')

    if #memberNames == 0 then
        return baseDescription .. '\n' .. membersLabel .. ': ' .. Lang:t('menu.no_players')
    end

    return baseDescription .. '\n' .. membersLabel .. ': ' .. table.concat(memberNames, ', ')
end

function Menu.BuildTeamSelectionMenu(confirmEvent, teamState)
    local menu = {}
    local teamData = teamState or {
        team1 = {},
        team2 = {},
    }

    Menu.AddOption(menu, {
        title = Lang:t('menu.team1'),
        description = Menu.BuildTeamMemberDescription(Lang:t('menu.team1_desc'), teamData.team1),
        event = confirmEvent,
        args = { team = 'team1' },
        icon = 'fas fa-users',
        iconColor = '#3498db',
    })

    Menu.AddOption(menu, {
        title = Lang:t('menu.team2'),
        description = Menu.BuildTeamMemberDescription(Lang:t('menu.team2_desc'), teamData.team2),
        event = confirmEvent,
        args = { team = 'team2' },
        icon = 'fas fa-users',
        iconColor = '#e74c3c',
    })

    return menu
end

function Menu.BuildLoadoutMenu()
    local loadoutMenu = {}

    Menu.AppendLoadoutOptions(loadoutMenu, 'matti-airsoft:selectLoadout')

    Menu.AddOption(loadoutMenu, {
        title = Lang:t('menu.random_loadout'),
        description = Lang:t('menu.random_loadout_txt'),
        event = 'matti-airsoft:giveRandomGun',
        icon = 'fas fa-random',
        iconColor = '#EC213A',
    })

    return loadoutMenu
end

function Menu.ShowLoadout()
    Menu.Open('matti_airsoft_loadout_menu', Lang:t('menu.choose_loadout'), Menu.BuildLoadoutMenu())
end
