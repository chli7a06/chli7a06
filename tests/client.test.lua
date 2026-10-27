Config={Command='dojmdt',Key='F12'}
local commands,callbacks,handlers,messages={},{},{},{}
local focus,keepInput,render,created,destroyed,hiddenText=false,false,false,0,0,0
local response={ok=true,data={x=10,y=20,z=30,rx=0,ry=0,rz=0,fov=60}}
lib={callback={await=function()return response end},notify=function()end,hideTextUI=function()hiddenText=hiddenText+1 end,showTextUI=function()end}
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
print('PASS '..n..' client focus, camera lifecycle and recovery checks')
