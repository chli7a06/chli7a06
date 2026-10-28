local commands,callbacks,events={},{},{}
local p={citizenid='ABC',charinfo={firstname='Test',lastname='Judge'},job={name='doj',onduty=true,grade={level=3,name='Judge'}}}
local item={name='crimson_doj_badge',metadata={owner='ABC'}}
local now=10000
Config={Jobs={doj={department='doj',read=0}}}
exports={qbx_core={GetPlayer=function()return {PlayerData=p}end},ox_inventory={GetSlot=function()return item end,GetItemCount=function()return 0 end,AddItem=function()return true end}}
lib={callback={register=function(k,v)callbacks[k]=v end}}
RegisterCommand=function(k,v)commands[k]=v end
AddEventHandler=function()end
GetResourceState=function()return 'started'end
GetGameTimer=function()return now end
GetPlayerPed=function(id)return id end
GetEntityCoords=function(id)return {x=id==3 and 20 or 0,y=0,z=0}end
GetPlayers=function()return {'1','2','3','4'}end
GetPlayerRoutingBucket=function(id)return id==4 and 10 or 0 end
TriggerClientEvent=function(name,target,data)events[#events+1]={name=name,target=target,data=data}end
dofile('crimson_doj/server_badge.lua')
local show=callbacks['crimson_doj:showBadge']
assert(not show(1,'1').ok)
assert(show(1,1).ok)
assert(#events==2 and events[1].target==1 and events[2].target==2,'only holder and nearby same-bucket player')
assert(events[1].data.name=='Test Judge' and events[1].data.number=='DOJ-ABC')
assert(not show(1,1).ok,'rate limited')
now=20000;item.metadata.owner='OTHER';assert(not show(1,1).ok,'transferred badge denied')
item.metadata.owner='ABC';p.job.onduty=false;assert(not show(1,1).ok,'off duty denied')
p.job.onduty=true;p.job.name='police';assert(not show(1,1).ok,'non DOJ denied')
print('PASS badge authorization, identity, rate limit, distance and routing isolation')
