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
        includes = 'Includes:',
    },
    inarena = {
        shot = 'You have been hit and are out of the game!',
    },
    command = {
        description_exitarena = 'Forcefully exit a player from the airsoft arena (Admin Only)',
        help_exitarena = 'Player ID',
        invalid_player_id = 'Invalid player ID.',
        player_removed = 'Player has been forcefully removed from the arena.',
        player_not_in_arena = 'Player is not inside the airsoft arena.'
    },
    notifications = {
        entered = 'You are now in the Airsoft Arena.',
        exited = 'You have left the Airsoft Arena.',
        force_exit = 'You have been forcefully removed from the airsoft arena.',
        cannot_afford = 'You do not have enough money for this loadout!',
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})