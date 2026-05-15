fx_version 'cerulean'
game 'gta5'

name 'qb-advanced-drugs'
author 'OpenAI Codex'
description 'Configurable advanced drug creator and gameplay loop for QBCore servers.'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'shared/config.lua',
    'shared/drugs.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-input',
    'qb-progressbar'
}
