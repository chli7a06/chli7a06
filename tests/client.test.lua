local exported={}
local emitted={}
local serverCalls=0
local lastServerCallback
exports=setmetatable({ox_inventory={useItem=function()end}},{__call=function(_,name,fn)exported[name]=fn end})
Config={Command='dojmdt',Key='F12'}
local commands,callbacks,handlers,messages={},{},{},{}
local focus,keepInput,render,created,destroyed,hiddenText=false,false,false,0,0,0
local timers={}
SetTimeout=function(_,fn)timers[#timers+1]=fn end
local delayed=false
local response={ok=true,data={x=10,y=20,z=30,rx=0,ry=0,rz=0,fov=60}}
lib={callback={await=function(name)serverCalls=serverCalls+1 lastServerCallback=name if delayed then coroutine.yield() end return response end},notify=function()end,hideTextUI=function()hiddenText=hiddenText+1 end,showTextUI=function()end}
RegisterNetEvent=function(name,fn)handlers[name]=fn end
TriggerServerEvent=function(name,ticket)emitted[#emitted+1]={name=name,ticket=ticket}end
RegisterCommand=function(name,fn)commands[name]=fn end
RegisterKeyMapping=function()end
RegisterNUICallback=function(name,fn)callbacks[name]=fn end
AddEventHandler=function(name,fn)handlers[name]=fn end
SendNUIMessage=function(data)messages[#messages+1]=data end
SetNuiFocus=function(a)focus=a end
SetNuiFocusKeepInput=function(a)keepInput=a end
GetCurrentResourceName=function()return 'crimson_doj'end
CreateCamWithParams=function()created=created+1 return created end
SetCamActive=function()end
RenderScriptCams=function(enabled)render=enabled end
DestroyCam=function()destroyed=destroyed+1 end
CreateThread=function()end
SetNewWaypoint=function()end
local n=0
local function check(value,label)assert(value,label)n=n+1 end
dofile('crimson_doj/client.lua')
check(type(commands.mdtclose)=='function','recovery command registered')
local result
callbacks.request({action='bootstrap'},function(r)result=r end);check(not result.ok,'closed tablet denies NUI request')
commands.dojmdt();check(focus,'open grants NUI focus');check(messages[#messages].action=='open','open message sent')
callbacks.camera({id=1},function(r)result=r end);check(result.ok and created==1 and render,'camera activated');check(not focus,'camera releases NUI focus');check(messages[#messages].action=='camera','camera hides browser tablet')
keepInput=true;commands.mdtclose();check(not focus and not keepInput,'recovery releases focus and input');check(not render and destroyed==1,'recovery destroys owned camera');check(hiddenText==1,'camera hint cleared');check(messages[#messages].action=='close','browser close message sent')
callbacks.camera({id=1},function(r)result=r end);check(not result.ok,'closed camera request rejected')
commands.dojmdt();callbacks.camera({id=1},function(r)result=r end);handlers.onResourceStop('crimson_doj');check(not focus and not render and destroyed==2,'resource stop cleans camera and focus')
response={ok=false,error='Access denied'};commands.dojmdt();check(not focus,'denied opening leaves game controls available')
response={ok=true,data={x=10,y=20,z=30,rx=0,ry=0,rz=0,fov=60}}
delayed=true
local pendingOpen=coroutine.create(commands.dojmdt)
check(coroutine.resume(pendingOpen),'opening request starts')
commands.mdtclose()
check(coroutine.resume(pendingOpen),'late opening response completes')
check(not focus and messages[#messages].action=='close','late opening cannot reopen a closed tablet')
delayed=false;commands.dojmdt();delayed=true
local previousCreated=created
local pendingCamera=coroutine.create(function()callbacks.camera({id=1},function(r)result=r end)end)
check(coroutine.resume(pendingCamera),'camera request starts')
commands.mdtclose()
check(coroutine.resume(pendingCamera),'late camera response completes')
check(not result.ok and created==previousCreated and not focus,'late camera response cannot activate after close')
delayed=false
Config.Printing={enabled=true}
exports.ox_inventory.useItem=function(_,data,cb)cb({slot=1})end
response={ok=true,data={title='Printed copy',body='Contents'}}
exported.useDocument({},1)
check(focus and messages[#messages].action=='document','inventory use opens physical reader')
commands.mdtclose();check(not focus and messages[#messages].action=='close','physical reader recovery closes focus')
delayed=true
local reading=coroutine.create(function()exported.useDocument({},1)end)
check(coroutine.resume(reading),'delayed item read starts')
commands.mdtclose();check(coroutine.resume(reading),'delayed item read completes')
check(not focus and messages[#messages].action=='close','late item response cannot reopen reader')
delayed=false
local before=#messages
handlers['crimson_doj:videoStart']({ticket='closed',total=1,bytes=4})
check(#messages==before and emitted[#emitted].ticket=='closed','closed tablet cancels a late video stream')
commands.dojmdt()
handlers['crimson_doj:videoStart']({ticket='valid',total=1,bytes=4})
check(messages[#messages].action=='videoStart','open tablet accepts authenticated stream header')
before=#messages
handlers['crimson_doj:videoChunk']({ticket='wrong',index=1,total=1,data='AQIDBA=='})
check(#messages==before,'unmatched stream chunks ignored')
handlers['crimson_doj:videoChunk']({ticket='valid',index=1,total=1,data='AQIDBA=='})
check(messages[#messages].action=='videoChunk','matching chunk forwarded to NUI')
commands.mdtclose();check(emitted[#emitted].ticket=='valid','closing cancels active stream')
before=#messages;handlers['crimson_doj:videoChunk']({ticket='valid',index=1,total=1,data='AQIDBA=='})
check(#messages==before,'closed tablet rejects late chunks')
lib.alertDialog=function()return 'cancel'end
before=serverCalls;handlers['crimson_doj:invoiceOffer']({business='Garage',title='Repair',amount=100,id=1,version=1})
check(serverCalls==before,'cancelled invoice offer never requests payment')
lib.alertDialog=function()return 'confirm'end
handlers['crimson_doj:invoiceOffer']({business='Garage',title='Repair',amount=100,id=1,version=1})
check(lastServerCallback=='crimson_doj:payInvoice','confirmed invoice uses dedicated payment callback')
-- Exercise the tablet thread separately from the perpetual marker/HUD threads.
commands.mdtclose()
local pendingTablet,props,animations,deletions=nil,0,0,0
CreateThread=function(fn)pendingTablet=fn end
joaat=function()return 123 end
lib.requestAnimDict=function()end
lib.requestModel=function()end
SetModelAsNoLongerNeeded=function()end
PlayerPedId=function()return 7 end
DoesEntityExist=function()return true end
IsEntityDead=function()return false end
GetEntityCoords=function()return {x=1,y=2,z=3}end
CreateObject=function()props=props+1 return 99 end
GetPedBoneIndex=function()return 10 end
AttachEntityToEntity=function()end
TaskPlayAnim=function()animations=animations+1 end
StopAnimTask=function()end
DeleteEntity=function()deletions=deletions+1 end
commands.dojmdt();pendingTablet()
check(props==1 and animations==1,'tablet2 pose attaches prop after authorized opening')
commands.mdtclose()
check(deletions==1,'closing deletes owned tablet prop')
commands.dojmdt();local late=pendingTablet;commands.mdtclose();late()
check(props==1,'late animation loading cannot create tablet after closing')
commands.dojmdt();pendingTablet();handlers.onResourceStop('crimson_doj')
check(deletions==2,'resource stop deletes tablet prop')
local before=serverCalls
for _,data in ipairs({false,'bad',{},{action=3},{action='list',payload='invalid'}})do
 local reply;callbacks.request(data,function(r)reply=r end)
 check(reply and reply.ok==false,'malformed NUI request fails without throwing')
end
local nilReply;callbacks.request(nil,function(r)nilReply=r end)
check(nilReply and not nilReply.ok and serverCalls==before,'empty request returns an error without invoking server')
commands.dojmdt();local openToken=messages[#messages].openToken;local timeout=timers[#timers]
check(type(openToken)=='number','open message carries UI session token')
timeout();check(not focus and messages[#messages].action=='close','unresponsive UI releases cursor automatically')
commands.dojmdt();openToken=messages[#messages].openToken;timeout=timers[#timers]
callbacks.uiReady({token=openToken},function(r)result=r end);timeout()
check(result.ok and focus,'acknowledged UI stays open')
callbacks.uiFailed({token=openToken-1,error='stale'},function(r)result=r end)
check(not result.ok and focus,'stale UI failure cannot close new session')
callbacks.uiFailed({token=openToken,error='test init failure'},function(r)result=r end)
check(result.ok and not focus,'current initialization failure releases cursor')
print('PASS '..n..' client focus, camera lifecycle and recovery checks')
