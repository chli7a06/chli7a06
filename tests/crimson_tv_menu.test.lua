local vector = {}; vector.__index = vector
vector.__sub = function(a,b) return setmetatable({x=a.x-b.x},vector) end
vector.__len = function(a) return math.abs(a.x) end
local function coords(x) return setmetatable({x=x},vector) end
Config={Menu={OpenDistance=5}}
PlayerPedId=function() return 1 end
GetEntityCoords=function() return coords(0) end
v3=function(v) return v end
RegisterNetEvent=function() end
RegisterNUICallback=function() end
RegisterCommand=function() end
SendNUIMessage=function() end
SetNuiFocus=function() end
SetNuiFocusKeepInput=function() end
local notice, hidden, shown
lib={notify=function(v) notice=v end, hideMenu=function() end}
HideScreen=function() hidden=true; CURRENT_SCREEN=nil end
ShowScreen=function(s) shown=s; CURRENT_SCREEN=s end
local nearest
GetClosestScreen=function() return nearest end
dofile('crimson_tv/client/tv.lua')
CURRENT_SCREEN={entity=9,coords=coords(40)}
nearest={entity=2,coords=coords(1)}
OpenTVMenu()
assert(hidden and shown==nearest and CURRENT_SCREEN==nearest,'must replace stale far TV with nearby TV')
nearest={entity=3,coords=coords(8)}; notice=nil; shown=nil
OpenTVMenu()
assert(notice and notice.description:find('Move closer') and not shown,'must retain distance limit')
nearest=nil; notice=nil
OpenTVMenu()
assert(notice and notice.description:find('No supported TV'),'must explain missing model')
print('PASS: stale selection, distance limit, unsupported TV feedback')
