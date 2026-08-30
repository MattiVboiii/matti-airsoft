fx_version('cerulean')
game('gta5')

author('MattiVboiii')
description('Simple & basic airsoft script')
version('2.0.3')

lua54('yes')

-- NUI files
ui_page('html/index.html')

files({
	'html/index.html',
	'html/style.css',
	'html/script.js',
})

client_scripts({
	'client/shared.lua',
	'client/inventory.lua',
	'client/player_entities.lua',
	'client/loadout.lua',
	'client/interaction.lua',
	'client/combat.lua',
	'client/spectator.lua',
	'client/arena_board.lua',
	'client/leaderboard.lua',
	'client/zone.lua',
	'client/menu.lua',
	'client/events.lua',
	'client/init.lua',
})

server_scripts({
	'@oxmysql/lib/MySQL.lua',
	'server/shared.lua',
	'server/match.lua',
	'server/modes/shared.lua',
	'server/modes/init.lua',
	'server/modes/ffa.lua',
	'server/modes/teams.lua',
	'server/modes/gungame.lua',
	'server/stats.lua',
	'server/lobby.lua',
	'server/leaderboard.lua',
	'server/events.lua',
	'server/callbacks.lua',
	'server/commands.lua',
	'server/init.lua',
})

shared_scripts({
	'@ox_lib/init.lua',
	'config.lua',
	'shared/locale.lua',
	'shared/utils.lua',
	'locales/*.lua',
})

dependencies {
  'oxmysql',
  'ox_lib',
}
