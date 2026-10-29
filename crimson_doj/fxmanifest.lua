fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'crimson_doj'
author 'Crimson'
description 'Crimson multi-department MDT — independent Qbox implementation'
version '3.2.0-beta'
ui_page 'web/index.html'
shared_scripts { '@ox_lib/init.lua', 'config.lua', 'permissions.lua', 'defaults.lua' }
client_scripts { 'client.lua', 'client_blips.lua', 'client_badge.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server_media.js', 'server_banking.lua', 'bank_adapters.lua', 'server_extras.lua', 'server.lua', 'server_badge.lua', 'server_blips.lua' }
files { 'web/index.html', 'web/app.js', 'web/style.css', 'web/crimson-logo.png', 'web/sounds/*' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql', 'ox_target' }

node_version '22'
