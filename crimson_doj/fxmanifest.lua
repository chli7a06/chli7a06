fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'crimson_doj'
author 'Crimson'
description 'Crimson multi-department MDT — independent Qbox implementation'
version '3.0.2-beta'
ui_page 'web/index.html'
shared_scripts { '@ox_lib/init.lua', 'config.lua', 'defaults.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server_media.js', 'server_extras.lua', 'server.lua' }
files { 'web/index.html', 'web/app.js', 'web/style.css', 'web/crimson-logo.png' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }

node_version '22'
