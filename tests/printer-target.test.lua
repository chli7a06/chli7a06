local threads,handlers,zones,removed,contexts={},{},{},{},{}
local exportsFns={}
exports=setmetatable({ox_target={addSphereZone=function(_,zone)zones[#zones+1]=zone;return #zones end,removeZone=function(_,id)removed[#removed+1]=id end}},{__call=function(_,name,fn)exportsFns[name]=fn end})
local state='started'
Config={Command='dojmdt',Key='F12',Printing={enabled=true},Printers={{label='DOJ printer',coords={x=1,y=2,z=3},radius=2,jobs={doj=true}},{label='Second printer',coords={x=4,y=5,z=6},radius=2,jobs={police=true}}}}
RegisterCommand=function()end
RegisterKeyMapping=function()end
RegisterNUICallback=function()end
RegisterNetEvent=function()end
AddEventHandler=function(name,fn)handlers[name]=fn end
CreateThread=function(fn)threads[#threads+1]=fn end
GetResourceState=function()return state end
GetCurrentResourceName=function()return 'crimson_doj'end
vector3=function(x,y,z)return {x=x,y=y,z=z}end
local lastPayload
lib={callback={await=function(_,_,action,payload)
 lastPayload=payload
 if action=='list' then return {ok=true,data={rows={{id=9,title='Court document'}}}}end
 return {ok=true}
end},notify=function()end,registerContext=function(c)contexts[#contexts+1]=c end,showContext=function()end}
dofile('crimson_doj/client.lua')
threads[1]()
assert(#zones==2 and not zones[1].debug and not zones[1].drawSprite)
assert(zones[1].options[1].groups.doj==0 and zones[2].options[1].groups.police==0)
assert(zones[2].options[1].canInteract())
zones[2].options[1].onSelect()
assert(#contexts==1 and contexts[1].title=='Second printer')
contexts[1].options[1].onSelect()
assert(lastPayload.id==9 and lastPayload.printer==2,'target keeps correct printer index')
handlers.onClientResourceStart('ox_target');assert(#removed==2 and #zones==4,'target restart replaces zones without duplicates')
handlers.onClientResourceStop('crimson_doj');assert(#removed==4,'resource shutdown removes target zones')
state='stopped';handlers.onClientResourceStop('ox_target');threads[1]();assert(#zones==4,'no zones registered when target stopped')
print('PASS printer target zones, job visibility, selection and lifecycle checks')
