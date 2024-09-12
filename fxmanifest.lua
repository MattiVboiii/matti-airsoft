fx_version 'cerulean'
game 'gta5'

author 'MattiVboiii'
description 'Simple & basic airsoft script'
version '1.0.2'

lua54 'yes'

client_scripts {
    'client/client.lua',
    '@PolyZone/client.lua',
    '@PolyZone/CircleZone.lua',
}

server_scripts {
    'server/server.lua',
}

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/*.lua',
}

dependencies {
    'qb-core',
    'qb-target',
}
