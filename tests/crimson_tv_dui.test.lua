Config={Locations={},Menu={}}
Citizen={CreateThread=function() end}
GetCurrentResourceName=function() return 'crimson_tv' end
RegisterNetEvent=function() end
RegisterNUICallback=function() end
RegisterCommand=function() end
AddEventHandler=function() end
GetGameTimer=function() return 0 end
local nativeCalls=0
IsDuiAvailable=function(handle) assert(handle~=nil and handle~=0);nativeCalls=nativeCalls+1;return true end
dofile('crimson_tv/client/main.lua')
dofile('crimson_tv/client/tv.lua')
assert(WaitForTVDui(nil)==nil and WaitForTVDui(0)==nil and nativeCalls==0)
duiObj=10;assert(WaitForTVDui(9)==nil and nativeCalls==0)
assert(WaitForTVDui(10)==10 and nativeCalls==1)
IsDuiAvailable=function() return false end
Wait=function() duiObj=11 end
assert(WaitForTVDui(10)==nil,'retired handle must cancel wait')
IsDuiAvailable=function() error('invalid handle') end
assert(WaitForTVDui(11)==nil,'invalid native handle must not crash callback')
duiObj=nil
SendDuiMessage=function() error('must not send to absent DUI') end
PlayVideo({url='test'});ResetDisplay();PlayBrowser({url='test'})
-- A retired handle must be detached before its destroy native runs.
duiObj=42
DestroyDui=function(handle) assert(handle==42 and duiObj==nil) end
HideScreen();assert(duiObj==nil and CURRENT_SCREEN==nil)
for _,path in ipairs({'crimson_tv/client/main.lua','crimson_tv/client/tv.lua','crimson_tv/client/cursor.lua','crimson_tv/client/dui.lua'}) do assert(loadfile(path)) end
print('PASS: nil/zero, retired, ready, cancelled and invalid DUI handles; absent playback; teardown ordering; Lua syntax')
