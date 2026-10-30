dofile('crimson_doj/config.lua');dofile('crimson_doj/permissions.lua');dofile('crimson_doj/defaults.lua')
local n=0
local function check(value,label)assert(value,label);n=n+1 end
local function denied(fn,label)check(not pcall(fn),label)end
local actor={source=1,scope='justice',department='doj',grade=14,manage=true,write=true,p={citizenid='CHIEF',job={name='doj'}}}
local coords,bucket={x=100,y=200,z=30},0
local saved={};local writes=0;local lastArgs;local versionDelete=1
GetPlayerRoutingBucket=function()return bucket end
GetPlayerPed=function()return 1 end
GetEntityCoords=function()return coords end
GetResourceState=function()return 'started'end
GetPlayers=function()return {'1'}end
exports={qbx_core={GetPlayer=function()return {PlayerData={citizenid='HOLDER',charinfo={firstname='Test',lastname='Holder'}}}end},ox_inventory={GetInventoryItems=function()return {{name='WEAPON_PISTOL',metadata={serial='SER001',registered='Registration text'}},{name='water',metadata={serial='NOT_WEAPON'}},{name='WEAPON_KNIFE',metadata={}}}end}}
json={encode=function(v)return v end}
MySQL={scalar={await=function()return 'CAM1'end},query={await=function(sql,args)lastArgs=args;if sql:find("kind='camera'",1,true)then return {{entity_id='CAM1',data=saved.data,version=saved.version},{entity_id='OTHER',data={bucket=99},version=1}}end;return {}end},update={await=function(sql,args)lastArgs=args;writes=writes+1;if sql:find('DELETE',1,true)then return versionDelete end;return 1 end}}
local entities={get=function(scope,kind,key)check(scope=='justice'and kind=='camera','camera keys are scoped');return saved[key]or {version=0,data={}}end,put=function(a,scope,kind,key,data,version)
 if saved[key]and version~=saved[key].version then error('stale')end
 saved[key]={data=data,version=version+1};saved.data=data;saved.version=version+1;return saved[key]
end}
local h={reject=function(e)error(e,0)end,clean=function(v,max,required)if type(v)=='string'and #v<=max and(not required or #v>0)and not v:find('%c')then return v end end,decode=function(v)return v end,log=function()end,entities=entities}
dofile('crimson_doj/server_registry.lua');local api=CrimsonRegistry(h)
actor.manage=false;denied(function()api.actions.cameraSave(actor,{label='Camera',rx=0,rz=0,fov=60})end,'non-manager cannot create camera');actor.manage=true
actor.grade=0;denied(function()api.actions.cameraCatalog(actor)end,'DOJ grade zero cannot manage/view administrative cameras');actor.grade=14
actor.scope='medical';denied(function()api.actions.weaponSerials(actor,{serial='SER'})end,'medical serial search denied');actor.scope='justice'
api.actions.cameraSave(actor,{label='Camera',rx=-20,rz=90,fov=60,x=9999})
check(saved.CAM1.data.x==100 and saved.CAM1.data.z==31,'camera position captured server-side, ignores supplied coordinates')
denied(function()api.actions.cameraSave(actor,{label='Bad',rx=0,rz=0,fov=999})end,'invalid field of view denied')
denied(function()api.actions.cameraSave(actor,{label='Bad',rx=0/0,rz=0,fov=60})end,'NaN angles denied')
coords={x=500,y=600,z=50};api.actions.cameraSave(actor,{id='CAM1',version=1,label='Updated',rx=-30,rz=180,fov=50})
check(saved.CAM1.data.x==100,'edit preserves location unless relocation requested')
denied(function()api.actions.cameraSave(actor,{id='CAM1',version=1,label='Stale',rx=0,rz=0,fov=60})end,'stale camera revision rejected')
api.actions.cameraSave(actor,{id='CAM1',version=2,label='Moved',rx=0,rz=0,fov=60,relocate=true})
check(saved.CAM1.data.x==500 and saved.CAM1.data.z==51,'explicit relocation uses current server position')
bucket=1;denied(function()api.actions.cameraDefinition(actor,{id='CAM1'})end,'other routing bucket cannot view camera');bucket=0
check(api.actions.cameraDefinition(actor,{id='CAM1'}).label=='Moved','authorized camera definition returned')
check(#api.actions.cameraCatalog(actor).rows==1,'camera catalog hides other bucket entries')
versionDelete=0;denied(function()api.actions.cameraDelete(actor,{id='CAM1',version=2})end,'stale deletion rejected');versionDelete=1
check(api.actions.cameraDelete(actor,{id='CAM1',version=3}),'authorized versioned deletion succeeds')
api.scanWeapons();check(lastArgs[1]=='SER001'and lastArgs[2].holder=='HOLDER'and lastArgs[2].holderName=='Test Holder','inventory observation records real holder CID and name')
check(lastArgs[2].legalOwnerVerified==false,'possession does not become legal ownership')
local before=writes;Config.WeaponObservation=false;api.scanWeapons();check(writes==before,'observation can be disabled')
api.actions.weaponSerials(actor,{serial='SER%_!'});check(lastArgs[1]=='%SER!%!_!!%','wildcards are escaped literally')
denied(function()api.actions.weaponSerials(actor,{serial='A'})end,'short serial search rejected')
print('PASS '..n..' stable registry permissions, cameras, concurrency and weapon observation checks')
