local Translations = {
    error = {
        unknown_player = 'Onbekende Speler',
    },
    menu = {
        choose_loadout = 'Kies Loadout',
        own_loadout = 'Eigen Loadout',
        own_loadout_txt = 'Ga in de arena met je eigen gear',
        random_loadout = 'Random Loadout',
        random_loadout_txt = 'Ga in de arena met een random loadout',
        exit_arena = 'Verlaat Arena'
    },
    zone = {
        entered = 'Je bent nu in de Airsoft Arena.',
        exited = 'Je hebt de Airsoft Arena verlaten.',
    },
    inarena = {
        shot = 'Je bent geraakt en ligt uit het spel!',
    }
}

if GetConvar('qb_locale', 'en') == 'nl' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end