local handlers,callbacks,threads={},{},{}
local sent,messages,commands={},{},{}
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
ExecuteCommand=function(c)commands[#commands+1]=c end
TriggerServerEvent=function(n,t)sent[#sent+1]={name=n,token=t}end
SendNUIMessage=function(data)messages[#messages+1]=data end
Config={Sounds={}}
dofile('crimson_doj/client_badge.lua')
handlers['crimson_doj:badge']({presentation='one',isOwner=true})
assert(commands[1]=='e idcard','uses requested emote command exactly')
local loop=coroutine.create(threads[1]);assert(coroutine.resume(loop));back=true;assert(coroutine.resume(loop));back=false
assert(commands[2]=='e c' and sent[1].token=='one' and messages[#messages].action=='badgeHide','Backspace cancels emote and shared display')
handlers['crimson_doj:badge']({presentation='viewer',isOwner=false})
callbacks.badgeDismiss({},function()end);assert(#sent==1 and #commands==2,'viewer does not animate or cancel local emotes')
handlers['crimson_doj:badge']({presentation='old',isOwner=true})
handlers['crimson_doj:badge']({presentation='new',isOwner=true})
local count=#commands;handlers['crimson_doj:badgeHide']('old');assert(#commands==count,'stale hide does not cancel a newer ID emote')
handlers['onResourceStop']('crimson_doj');assert(commands[#commands]=='e c','resource stop cancels owned ID emote')
print('PASS badge animation, exact e idcard, Backspace and presentation cleanup')
