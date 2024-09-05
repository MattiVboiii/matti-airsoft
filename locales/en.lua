local Translations = {
    error = {
        unknown_player = 'Unknown Player',
    },
    menu = {
        choose_loadout = 'Choose Loadout',
        own_loadout = 'Own Loadout',
        own_loadout_txt = 'Go in the arena with your own gear',
        random_loadout = 'Random Loadout',
        random_loadout_txt = 'Go in the arena with a random loadout',
        exit_arena = 'Exit Arena',
    },
    zone = {
        entered = 'You are now in the Airsoft Arena.',
        exited = 'You have left the Airsoft Arena.',
    },
    inarena = {
        shot = 'You have been hit and are out of the game!',
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})