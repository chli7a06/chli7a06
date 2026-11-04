fx_version "cerulean"
game "gta5"
name "crimson_tv"
description "Crimson TV — television and broadcast controls for FiveM."
version "1.3.1"
ui_page "html/blank.html"

files {
	"html/blank.html",
	"html/crimson-logo-inline.js",
	"html/index.html",
	"html/style.css",
	"html/main.js",
	"html/VCR_OSD_MONO_1.001.ttf",
}

shared_scripts {
    "@ox_lib/init.lua",
	"config.lua",
	"shared/*.lua"
}

client_scripts {
	"client/cursor.lua",
	"client/tv.lua",
	"client/dui.lua",
	"client/main.lua",
}

server_scripts {
	"server/*.lua"
}

lua54 'yes'

dependency "ox_lib"
