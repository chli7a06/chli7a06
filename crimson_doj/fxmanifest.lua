fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'crimson_doj'
author 'Crimson'
description 'Crimson multi-department MDT — independent Qbox implementation'
version '2.0.0-preview'
ui_page 'web/index.html'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
files { 'web/index.html', 'web/app.js', 'web/style.css', 'web/crimson-logo.png' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }
