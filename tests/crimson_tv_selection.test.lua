local vector={}
vector.__sub=function(a,b) return setmetatable({x=a.x-b.x},vector) end
vector.__len=function(a) return math.abs(a.x) end
local function v(x) return setmetatable({x=x},vector) end
Config={Locations={},Models={[1]={Range=20}},ScreenSwitchDistance=2}
Citizen={CreateThread=function() end}
GetCurrentResourceName=function() return 'crimson_tv' end
RegisterNetEvent=function() end
RegisterNUICallback=function() end
AddEventHandler=function() end
local player=4
local objects={10,11}
local positions={[10]=0,[11]=6}
PlayerPedId=function() return 99 end
GetEntityCoords=function(e) return v(e==99 and player or positions[e]) end
GetGamePool=function() return objects end
GetEntityModel=function() return 1 end
DoesEntityExist=function(e) return positions[e]~=nil end
dofile('crimson_tv/client/main.lua')
CURRENT_SCREEN={entity=10,model=1,coords=v(0)}
assert(GetStableScreen().entity==10,'small nearest-distance changes must retain active TV')
player=4.5
assert(GetStableScreen().entity==11,'meaningfully closer TV must still be selectable')
objects={};player=3
assert(GetStableScreen().entity==10,'transient pool omission must not destroy an existing TV')
player=21
assert(GetStableScreen().entity==10,'range boundary margin must prevent flicker')
player=23
assert(GetStableScreen()==nil,'leaving range must release TV')
objects={11};player=5;positions[10]=nil
assert(GetStableScreen().entity==11,'streamed-out active entity must select a valid replacement')
print('PASS: stable selection, deliberate switching, transient pool omission, range margin and entity removal')
