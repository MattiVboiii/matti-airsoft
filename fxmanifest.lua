fx_version 'cerulean'
game 'gta5'

author 'MattiVboiii'
description 'Simple & basic airsoft script'
version '0.0.0'

client_scripts {
    'client/client.lua',
    '@PolyZone/client.lua',
}

server_scripts {
    'server/server.lua',
}

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/*.lua'
}
