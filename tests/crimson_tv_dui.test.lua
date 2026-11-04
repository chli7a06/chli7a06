Config={Locations={},Menu={}}
Citizen={CreateThread=function() end}
GetCurrentResourceName=function() return 'crimson_tv' end
RegisterNetEvent=function() end
local callbacks={}
RegisterNUICallback=function(name,callback) callbacks[name]=callback end
RegisterCommand=function() end
AddEventHandler=function() end
local clock=0
GetGameTimer=function() return clock end
IsDuiAvailable=function() error('legacy native must never be polled') end
dofile('crimson_tv/client/main.lua')
dofile('crimson_tv/client/tv.lua')
assert(WaitForTVDui(nil)==nil and WaitForTVDui(0)==nil)
duiObj=10;assert(WaitForTVDui(9)==nil)
Wait=function() clock=clock+10; callbacks.pageLoaded({},function() end) end
assert(WaitForTVDui(10)==10,'must wait for actual page acknowledgement')
HideScreen=function() end -- restore real teardown below via a fresh load
-- Another handle cannot inherit a prior page acknowledgement.
duiObj=11
Wait=function() clock=clock+10;duiObj=12 end
assert(WaitForTVDui(11)==nil,'screen switch must cancel pending work')
duiObj=13
Wait=function() clock=clock+1000 end
assert(WaitForTVDui(13)==nil,'missing page must time out')
duiObj=nil
SendDuiMessage=function() error('must not send to absent DUI') end
PlayVideo({url='test'});ResetDisplay();PlayBrowser({url='test'})
dofile('crimson_tv/client/main.lua')
duiObj=42
DestroyDui=function(handle) assert(handle==42 and duiObj==nil) end
HideScreen();assert(duiObj==nil and CURRENT_SCREEN==nil)
for _,path in ipairs({'crimson_tv/client/main.lua','crimson_tv/client/tv.lua','crimson_tv/client/cursor.lua','crimson_tv/client/dui.lua'}) do assert(loadfile(path)) end
print('PASS: missing/retired handles, page handshake, cancellation, timeout, absent playback, teardown and syntax')
