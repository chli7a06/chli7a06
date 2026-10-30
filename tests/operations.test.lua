dofile('crimson_doj/config.lua');dofile('crimson_doj/permissions.lua');dofile('crimson_doj/defaults.lua')
local count=0
local function check(value,label)assert(value,label);count=count+1 end
local function denied(fn,label)check(not pcall(fn),label)end
local actors={[1]={source=1,scope='justice',department='doj',grade=14,write=true,p={citizenid='CHIEF',job={name='doj'}}}}
local entity,state,vehicles={}, {},{}
local coords={x=449.2901,y=-981.1782,z=43.6913}
local time,keys,deleted,logged=100000,0,0,0
local bucket,occupied,keyFailure,swap=false,false,false,false
local events={};local observed
AddEventHandler=function(name,fn)events[name]=fn end
GetCurrentResourceName=function()return 'crimson_doj'end
GetResourceState=function()return 'started'end
GetGameTimer=function()return time end
GetPlayerPed=function(src)return src end
GetEntityCoords=function(id)return coords end
GetPlayerRoutingBucket=function()return bucket and 1 or 0 end
GetEntityRoutingBucket=function(id)return entity[id]and entity[id].bucket or 0 end
SetEntityRoutingBucket=function(id,b)entity[id].bucket=b end
GetAllVehicles=function()return occupied and {99}or vehicles end
GetEntityModel=function(id)return entity[id]and entity[id].model end
NetworkGetNetworkIdFromEntity=function(id)return id+100 end
DoesEntityExist=function(id)return entity[id]~=nil end
joaat=function()return 123 end
CreateVehicleServerSetter=function(hash,kind,x,y,z,heading)
 check(kind=='heli'and x==coords.x,'spawn type and coordinates server configured')
 entity[10]={model=hash,bucket=0};vehicles={10};state[10]={set=function(self,k,v)self[k]=v end};return 10
end
Entity=function(id)return {state=state[id]}end
DeleteEntity=function(id)entity[id]=nil;vehicles={};deleted=deleted+1 end
GetPedInVehicleSeat=function()return 0 end
Wait=function()end
GetPlayers=function()return {'1'}end
exports={qbx_vehiclekeys={GiveKeys=function()keys=keys+1;if keyFailure then error('keys provider failed')end;if swap then actors[1]=nil end;return true end,RemoveKeys=function()return true end},qbx_core={GetPlayer=function()return {PlayerData={citizenid='CHIEF'}}end},ox_inventory={GetInventoryItems=function()return {{name='WEAPON_PISTOL',metadata={serial='SER001',registered='Legal label'}},{name='water',metadata={serial='NOT_A_WEAPON'}},{name='WEAPON_KNIFE',metadata={}}}end}}
json={encode=function(v)return v end}
MySQL={update={await=function(sql,p)observed=p;return 1 end},query={await=function(sql,p)observed=p;return {}end}}
local h={identity=function(src)return actors[src]end,reject=function(e)error(e,0)end,clean=function(v,max,required)if type(v)=='string'and #v<=max and(not required or #v>0)and not v:find('%c')then return v end end,decode=function(v)return v end,log=function()logged=logged+1 end}
dofile('crimson_doj/server_operations.lua');local api=CrimsonOperations(h);local a=actors[1]
check(#api.actions.airUnits(a)==1,'eligible helipad listed')
a.grade=0;check(#api.actions.airUnits(a)==0,'low rank no helipad')
denied(function()api.actions.airSpawn(a,{pad='mission_row'})end,'low rank cannot spawn');a.grade=14
a.scope='medical';denied(function()api.actions.airUnits(a)end,'medical cannot access legal fleet');a.scope='justice'
denied(function()api.actions.airSpawn(a,{pad='unknown',model='rhino'})end,'unknown pad/client model denied')
coords={x=0,y=0,z=0};denied(function()api.actions.airSpawn(a,{pad='mission_row'})end,'remote spawn denied');coords=Config.AirUnits.mission_row.coords
occupied=true;denied(function()api.actions.airSpawn(a,{pad='mission_row'})end,'occupied pad denied');occupied=false
local issued=api.actions.airSpawn(a,{pad='mission_row',model='rhino'})
check(issued.netId==110 and keys==1 and entity[10].model==123,'server-authorized aircraft and keys issued')
denied(function()api.actions.airSpawn(a,{pad='mission_row'})end,'duplicate fleet issue denied')
GetPedInVehicleSeat=function(_,seat)return seat==0 and 2 or 0 end
denied(function()api.actions.airReturn(a,{pad='mission_row'})end,'passenger prevents deletion')
GetPedInVehicleSeat=function()return 0 end
bucket=true;denied(function()api.actions.airReturn(a,{pad='mission_row'})end,'cross-bucket return denied');bucket=false
check(api.actions.airReturn(a,{pad='mission_row'})and deleted==1,'matching empty aircraft returned')
denied(function()api.actions.airSpawn(a,{pad='mission_row'})end,'spawn cooldown persists after return')
time=time+61000;keyFailure=true;denied(function()api.actions.airSpawn(a,{pad='mission_row'})end,'key failure rejected')
check(entity[10]==nil and deleted==2,'failed key grant cleans spawned aircraft');keyFailure=false
api.scanWeapons();check(observed[1]=='SER001'and observed[2].holder=='CHIEF'and observed[2].legalOwnerVerified==false,'only weapon serial is recorded without legal ownership inference')
api.actions.weaponSerials(a,{serial='SER%_!'});check(observed[1]=='%SER!%!_!!%','serial query escapes wildcards literally')
denied(function()api.actions.weaponSerials(a,{serial='a'})end,'short serial search rejected')
api.actions.airSpawn(a,{pad='mission_row'});events.onResourceStop('unrelated');check(entity[10]~=nil,'other resource stop leaves fleet')
events.onResourceStop('crimson_doj');check(entity[10]==nil,'own resource stop cleans tracked fleet')
local cameraState={version=0,data={}}
h.entities={get=function(scope,kind,key)check(scope=='justice'and kind=='camera','camera lookup scope fixed');return cameraState end,put=function(actor,scope,kind,key,data,version)cameraState={version=version+1,data=data};return cameraState end}
MySQL.scalar={await=function()return 'CAM1'end}
a.manage=false;denied(function()api.actions.cameraSave(a,{label='Test',rx=0,rz=0,fov=60})end,'non-manager cannot install cameras')
a.manage=true
check(api.actions.cameraSave(a,{label='Camera',rx=-20,rz=90,fov=60}).data.x==coords.x,'camera uses server-captured location')
check(cameraState.data.z==coords.z+1,'camera height is bounded server offset')
denied(function()api.actions.cameraSave(a,{label='Test',rx=0,rz=0,fov=999})end,'unbounded field of view denied')
local savedX=cameraState.data.x;coords={x=0,y=0,z=0}
api.actions.cameraSave(a,{id='CAM1',version=1,label='Updated',rx=0,rz=0,fov=60});check(cameraState.data.x==savedX,'angle edit preserves old camera location')
bucket=true;denied(function()api.actions.cameraDefinition(a,{id='CAM1'})end,'camera view denied across routing buckets');bucket=false
check(api.actions.cameraDefinition(a,{id='CAM1'}).label=='Updated','authorized camera feed returned')
print('PASS '..count..' air fleet authority, keys, returns, failure and weapon-observation checks')
