-- A named TV target must start the browser without generic_texture_renderer.
Config={Locations={},Models={[777010715]={Target='tvscreen',Scale=0.085,Offset={x=0,y=0,z=0}}}}
local threads, callbacks={},{}
Citizen={CreateThread=function(fn) threads[#threads+1]=fn end,Wait=function() error('unexpected scaleform wait') end}
GetCurrentResourceName=function() return 'crimson_tv' end
GetGameTimer=function() return 0 end
RegisterNetEvent=function() end
RegisterNUICallback=function(name,fn) callbacks[name]=fn end
AddEventHandler=function() end
RequestScaleformMovie=function() error('named targets must not request scaleforms') end
CreateRuntimeTxd=function() return 1 end
CreateDui=function() return 99 end
GetDuiHandle=function(handle) assert(handle==99);return 'browser-handle' end
CreateRuntimeTextureFromDuiHandle=function(_,_,handle) assert(handle=='browser-handle');return 1 end
Wait=function() callbacks.pageLoaded({},function() end) end
dofile('crimson_tv/client/main.lua')
ShowScreen({model=777010715,entity=7})
assert(duiObj==99 and CURRENT_SCREEN.entity==7)
assert(#threads==4,'render/audio workers must have been created')
-- Render IDs can be signed 32-bit values; the user's actual ID is valid.
TriggerServerEvent=function() end
DoesEntityExist=function() return true end
GetEntityCoords=function() return {} end
GetOffsetFromEntityInWorldCoords=function() return {} end
CreateNamedRenderTargetForModel=function() return -1994970322 end
IsNamedRendertargetLinked=function() return true end
local draws=0
RenderScaleformTV=function(id) assert(id==-1994970322);draws=draws+1 end
Citizen.Wait=function() coroutine.yield() end
local worker=coroutine.create(threads[3])
assert(coroutine.resume(worker))
assert(draws==1,'negative signed render ID must reach DrawSprite path')

-- Models that do require a scaleform must time out if it is missing.
local clock=0
GetGameTimer=function() return clock end
RequestScaleformMovie=function() return 3 end
HasScaleformMovieLoaded=function() return false end
SetScaleformMovieAsNoLongerNeeded=function() end
Citizen.Wait=function() clock=clock+1000 end
assert(loadScaleform('missing')==nil and clock==10000)
print('PASS: named target starts DUI without scaleform; negative render ID draws; missing scaleform times out')
