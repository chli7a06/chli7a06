shared_script '@WaveShield/resource/include.lua'

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'crimson-mechanic'
author 'mm3'
description 'Mechanic job: placeable benches, job-locked tuning, customer request tickets, stance'
version '1.3.6'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/lang.lua',
    'shared/items.lua',
    'shared/liveries.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/stance.lua',
    'client/sound.lua',
    'client/tuner.lua',
    'client/main.lua',
    'client/admin.lua',
    'client/liveries.lua',
    'client/wash.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/liveries.lua',
}

ui_page 'web/index.html'

data_file 'DLC_ITYP_REQUEST' 'stream/crimson_lavage.ytyp'

files {
    'stream/crimson_lavage.ytyp',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/icons.js',
    'web/wash.css',
    'web/wash.js',
    'web/hud-medium.ttf',
    'web/hud-semibold.ttf',
}

-- qbx_vehicles is server_only: listing it here makes clients refuse to start this resource.
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

escrow_ignore {
    'config.lua',
}
