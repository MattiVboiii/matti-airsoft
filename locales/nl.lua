local Translations = {
    error = {
        unknown_player = 'Onbekende Speler',
    },
    menu = {
        choose_loadout = 'Kies Loadout',
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