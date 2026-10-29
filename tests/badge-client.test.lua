local handlers,callbacks,threads={},{},{}
local sent,messages={},{}
local created,deleted,played=0,0,0
local now,back=100,false
RegisterNetEvent=function(n,f)handlers[n]=f end
RegisterNUICallback=function(n,f)callbacks[n]=f end
AddEventHandler=function(n,f)handlers[n]=f end
CreateThread=function(fn)threads[#threads+1]=fn end
GetGameTimer=function()return now end
GetCurrentResourceName=function()return 'crimson_doj'end
Wait=function()coroutine.yield()end
IsControlJustReleased=function()return back end
IsDisabledControlJustReleased=function()return false end
DoesEntityExist=function()return true end
PlayerPedId=function()return 1 end
GetEntityCoords=function()return {x=0,y=0,z=0}end
IsEntityDead=function()return false end
joaat=function()return 1 end
CreateObject=function()created=created+1;return 1 end
GetPedBoneIndex=function()return 1 end
AttachEntityToEntity=function()end
TaskPlayAnim=function()played=played+1 end
StopAnimTask=function()end
DeleteEntity=function()deleted=deleted+1 end
SetModelAsNoLongerNeeded=function()end
TriggerServerEvent=function(n,t)sent[#sent+1]={name=n,token=t}end
SendNUIMessage=function(data)messages[#messages+1]=data end
Config={Sounds={}}
lib={requestAnimDict=function()end,requestModel=function()end}
dofile('crimson_doj/client_badge.lua')
handlers['crimson_doj:badge']({presentation='one',isOwner=true})
threads[2]();assert(created==1 and played==1,'holder animates badge prop')
local loop=coroutine.create(threads[1]);assert(coroutine.resume(loop));back=true;assert(coroutine.resume(loop));back=false
assert(deleted==1 and sent[1].token=='one' and messages[#messages].action=='badgeHide','Backspace ends animation and shared display')
handlers['crimson_doj:badge']({presentation='viewer',isOwner=false})
callbacks.badgeDismiss({},function()end);assert(#sent==1,'viewer dismiss does not hide everyone')
handlers['crimson_doj:badge']({presentation='late',isOwner=true});local late=threads[#threads]
callbacks.badgeDismiss({},function()end);late();assert(created==1,'cancelled asynchronous pose never spawns prop')
print('PASS badge animation, Backspace, viewer dismissal and delayed-load cancellation')
