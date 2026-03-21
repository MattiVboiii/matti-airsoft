fx_version('cerulean')
game('gta5')

author('MattiVboiii')
description('Simple & basic airsoft script')
version('2.0.0')

lua54('yes')

-- NUI files
ui_page('html/index.html')

files({
	'html/index.html',
	'html/style.css',
	'html/script.js',
})

client_scripts({
	'@PolyZone/client.lua',
	'@PolyZone/CircleZone.lua',
	'client/shared.lua',
	'client/inventory.lua',
	'client/player_entities.lua',
	'client/loadout.lua',
	'client/combat.lua',
	'client/leaderboard.lua',
	'client/zone.lua',
	'client/menu.lua',
	'client/events.lua',
	'client/init.lua',
})

server_scripts({
	'server/shared.lua',
	'server/lobby.lua',
	'server/leaderboard.lua',
	'server/events.lua',
	'server/callbacks.lua',
	'server/commands.lua',
	'server/init.lua',
})

shared_scripts({
	'config.lua',
	'@qb-core/shared/locale.lua',
	'locales/*.lua',
	'@ox_lib/init.lua',
})
