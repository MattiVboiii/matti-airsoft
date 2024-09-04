local Translations = {
    error = {
        unknown_player = "Unknown Player"
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