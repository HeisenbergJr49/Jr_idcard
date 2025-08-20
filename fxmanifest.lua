fx_version 'cerulean'
game 'gta5'

author 'HeisenbergJr49'
description 'Comprehensive ID Card Management System for FiveM'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'locales/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/audit.lua',
    'server/cards.lua',
    'server/admin.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/nui.lua',
    'client/interactions.lua',
    'client/inventory.lua'
}

server_exports {
    'Database',
    'Audit',
    'Cards',
    'Admin'
}

client_exports {
    'GetPlayerCards',
    'RefreshCards',
    'OpenCardUI',
    'CloseCardUI'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
    'nui/assets/**/*',
    'locales/*.json'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_inventory'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'