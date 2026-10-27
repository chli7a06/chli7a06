local saved={}
local callback,player,sourceNumber,passed= nil,nil,0,0
local queries,inserts,updates,groupChanges={},0,0,0
local selectedRow,selectedProduct,groupGrade,oldVersionChanged,legacy,migrated,migrationArgs
local employeeRows,searchRows={},{ }
local cfg=assert(loadfile('crimson_doj/config.lua'));cfg()
Config.Jobs.police.manage=3
local function user(job,grade,duty,cid)
 player={PlayerData={citizenid=cid or 'STAFF',charinfo={firstname='Test',lastname='Staff'},job={name=job,grade={level=grade},onduty=duty}}}
end
local jobs={doj={grades={[0]={name='Assistant'},[1]={name='Lawyer'},[2]={name='Prosecutor'},[3]={name='Judge'}}},police={grades={[0]={name='Cadet'},[1]={name='Officer'},[2]={name='Sergeant'},[3]={name='Chief'}}}}
exports={qbx_core={GetPlayer=function(_,id)return saved[id] or player end,GetJobs=function()return jobs end,GetPlayerByCitizenId=function()return nil end,
SetJobDuty=function(_,_,enabled)player.PlayerData.job.onduty=enabled end,
AddPlayerToJob=function()groupChanges=groupChanges+1 return true end,RemovePlayerFromJob=function()groupChanges=groupChanges+1 return true end}}
GetGameTimer=function()return 100000 end
GetCurrentResourceName=function()return 'crimson_doj' end
LoadResourceFile=function()return 'CREATE TABLE example (id INT);' end
GetPlayers=function()return {} end
GetPlayerPed=function()return 5 end
GetEntityCoords=function()return {x=10,y=20,z=30}end
GetResourceState=function()return 'missing'end
AddEventHandler=function()end
json={decode=function(s)if s=='PRODUCT' then return {price=50}end if s=='PRIVATE' then return {url='https://test'}end return {}end,encode=function(t)return t end}
lib={callback={register=function(_,fn)callback=fn end}}
local initializer
MySQL={query={await=function(sql,args)
 queries[#queries+1]={sql=sql,args=args}
 if sql:find('player_groups g')then return employeeRows end
 if sql:find('FROM players WHERE LOCATE')then return searchRows end
 return {}
end},scalar={await=function(sql,args)
 queries[#queries+1]={sql=sql,args=args}
 if sql:find('information_schema.tables')then return legacy or 0 end
 if sql:find('crimson_mdt_migrations')then return migrated or 0 end
 if sql:find('SELECT grade FROM player_groups')then return groupGrade end
 if sql:find('SELECT threat')then return 'green'end
 return 0
end},single={await=function(sql,args)
 queries[#queries+1]={sql=sql,args=args}
 if sql:find('FROM players')then return {citizenid='CITIZEN',charinfo='{}'}end
 if sql:find("kind='product'")then return selectedProduct end
 return selectedRow
end},insert={await=function()inserts=inserts+1 return 42 end},update={await=function()updates=updates+1 return oldVersionChanged and 0 or 1 end},transaction={await=function(args)migrationArgs=args return true end},ready=function(fn)initializer=fn;fn()end}
dofile('crimson_doj/server.lua')
local function request(action,data,id)sourceNumber=sourceNumber+1 saved[id or sourceNumber]=player return callback(id or sourceNumber,action,data or {})end
local function check(value,label)assert(value,label)passed=passed+1 end
local function denied(action,data,label)local r=request(action,data)check(not r.ok,label)return r end
user('unemployed',4,true);denied('bootstrap',nil,'nonjob denied')
user('doj',0,false);local b=request('bootstrap');check(b.ok and #b.data.recent==0,'off duty bootstrap has no sensitive data');denied('search',{query='Test'},'off duty search denied')
check(request('duty',{enabled=true}).ok and player.PlayerData.job.onduty,'can clock in')
user('doj',0,true);b=request('bootstrap');check(b.ok and b.data.department=='doj','doj bootstrap');check(b.data.modules.case and not b.data.modules.medical,'doj has no medical module');check(not b.data.modules.warrant.write,'warrant creation management only')
denied('list',{kind='medical'},'medical read denied to doj');denied('list',{kind='product'},'business read denied to doj')
user('ambulance',2,true);b=request('bootstrap');check(b.ok and b.data.modules.medical and not b.data.modules.case,'ems isolated');request('list',{kind='medical'});local last=queries[#queries];check(last.args[1]=='medical','medical scope sent to DB')
denied('list',{kind='case'},'ems cannot list legal records');denied('vehicles',{query='AA'},'ems cannot search vehicles')
user('mechanic',1,true);b=request('bootstrap');check(b.data.modules.invoice and not b.data.modules.case,'business modules isolated');request('list',{kind='invoice'});check(queries[#queries].args[1]=='business:mechanic','business partitioned by job');denied('roster',nil,'business cannot see units')
user('police',0,true);denied('create',{kind='case',subject='CITIZEN',title='t',body='b'},'read-only police cannot write')
user('police',1,true);check(request('create',{kind='case',subject='CITIZEN',title='t',body='b'}).ok,'writer can create report');denied('create',{kind='warrant',subject='CITIZEN',title='t',body='b'},'writer cannot issue warrant')
denied('create',{kind='case',subject='CITIZEN',title='',body='b'},'blank title rejected');denied('create',{kind='case',subject='CITIZEN',title='t',body=string.rep('x',20001)},'long body rejected')
selectedRow={id=1,kind='case',scope='justice',owner='OTHER',subject='CITIZEN',status='open',details='{}'}
local edit={id=1,version=1,title='t',body='b',status='open'}
denied('update',edit,'cannot update another author report');check(updates==0,'denied update does not write')
selectedRow.owner='STAFF';check(request('update',edit).ok,'own report may be updated')
edit.status='closed';denied('update',edit,'writer cannot close report');user('police',3,true);check(request('update',edit).ok,'manager closes report');oldVersionChanged=true;denied('update',edit,'stale version rejected');oldVersionChanged=false
selectedRow.kind='note';selectedRow.owner='OTHER';denied('update',edit,'manager cannot read/edit another private note')
request('list',{kind='note'});last=queries[#queries];check(last.sql:find('owner=?') and last.args[3]=='STAFF','notes owner filter')
request('list',{kind='document',archived=true});check(queries[#queries].sql:find("status IN"),'archive filtered by server')
user('doj',3,true);denied('employee',{citizenid='STAFF',operation='remove'},'self firing denied');groupGrade=3;denied('employee',{citizenid='CITIZEN',operation='remove'},'equal grade removal denied');groupGrade=1;denied('employee',{citizenid='CITIZEN',operation='grade',grade=3},'cannot appoint equal grade');check(request('employee',{citizenid='CITIZEN',operation='grade',grade=2}).ok and groupChanges==1,'lower grade update allowed')
user('doj',0,true);denied('employee',{citizenid='CITIZEN',operation='remove'},'writer cannot manage staff');denied('audit',nil,'writer cannot read audit');denied('threat',{value='red'},'writer cannot change threat');user('doj',3,true);check(request('audit').ok,'manager audit');check(request('threat',{value='red'}).ok,'manager threat control')
user('mechanic',1,true);selectedProduct={id=9,title='Repair',details='PRODUCT'};check(request('create',{kind='invoice',subject='CITIZEN',title='Repair bill',body='',details={productId=9,quantity=2,total=1}}).ok,'invoice uses catalog item');last=queries[#queries];check(last.args[2]=='business:mechanic','invoice scope catalog lookup');selectedProduct=nil;denied('create',{kind='invoice',subject='CITIZEN',title='t',details={productId=999,quantity=1}},'invalid catalog product rejected')
user('police',3,true);denied('camera',{id=1},'unconfigured camera disabled');denied('armory',{id=1},'unconfigured inventory disabled');denied('create',{kind='recording',subject='',title='t',details={url='javascript:alert(1)'}},'unsafe recording URL denied')

user('police',3,true)
check(request('shareGPS',{enabled=true},39000).ok,'GPS opt in')
check(request('unitWaypoint',{source=39000}).ok,'same scope GPS locate')
user('ambulance',3,true);denied('unitWaypoint',{source=39000},'medical cannot locate justice GPS')
user('police',3,true);check(request('shareGPS',{enabled=false},39000).ok,'GPS opt out');denied('unitWaypoint',{source=39000},'GPS unavailable after opt out')
Config.Integrations.cameras=true
Config.Cameras={{label='Medical camera',jobs={ambulance=true},x=1,y=2,z=3},{label='Police camera',jobs={police=true},x=10,y=20,z=30}}
local equipment=request('equipment');check(equipment.ok and #equipment.data.cameras==1 and equipment.data.cameras[1].id==2,'camera list uses authorized server IDs')
denied('camera',{id=1},'camera job restriction');check(request('camera',{id=2}).ok,'authorized native camera')
Config.Integrations.inventory='ox_inventory'
Config.Armory.police={coords={x=10,y=20,z=30},radius=3,kits={{label='Patrol',grade=1,items={{name='radio',count=1}}}}}
GetResourceState=function()return 'started'end
local granted=0
exports.ox_inventory={AddItem=function(_,src,item,count,metadata)granted=granted+count return true end,RemoveItem=function()return true end}
check(request('armory',{id=1}).ok and granted==1,'armory grants server whitelist kit')
denied('armory',{id=1},'kit cooldown across connections')
GetEntityCoords=function()return {x=1000,y=20,z=30}end
denied('armory',{id=1},'armory server distance enforced')

local initial=inserts;request('create',{kind='dispatch',subject='',title='Officer assistance',details={coords={x=999}}});check(inserts>initial,'dispatch created');
local r;for i=1,51 do r=request('bootstrap',{},9000)end check(not r.ok,'rate limit enforced')
local oldQuery=MySQL.query.await;MySQL.query.await=function()error('SENSITIVE SQL DETAILS')end;r=request('search',{query='Test'});check(not r.ok and not r.error:find('SENSITIVE'),'internal database errors not leaked');MySQL.query.await=oldQuery
legacy=1;migrated=0;initializer();check(migrationArgs and #migrationArgs==2,'migration is transactional');check(migrationArgs[1].query:find('SELECT id,')~=nil,'migration preserves record IDs');check(not migrationArgs[1].query:find('DELETE'),'migration does not delete old table')
print('PASS '..passed..' authorization, isolation, privacy, validation, migration and concurrency checks')
