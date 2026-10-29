dofile('crimson_doj/config.lua');dofile('crimson_doj/permissions.lua');dofile('crimson_doj/defaults.lua')
local count=0
local function check(v,label)assert(v,label);count=count+1 end
local function denied(fn,label)local ok=pcall(fn);check(not ok,label)end
local people={CIT=true,STAFF=true}
local entities,logs,queries={},0,{}
local function key(scope,kind,id)return scope..'/'..kind..'/'..id end
json={encode=function(v)return v end}
local function decode(v)return type(v)=='table'and v or {}end
local records={[1]={id=1,scope='justice',kind='case',subject='CIT',title='Case'}}
local online={PlayerData={citizenid='CIT',source=2,job={name='doj',onduty=true},metadata={licences={driver=true,weapon=false}}},Functions={}}
online.Functions.SetMetaData=function(k,v)online.PlayerData.metadata[k]=v end
local isOnline=true
exports={qbx_core={GetPlayerByCitizenId=function(_,cid)if cid=='CIT'and isOnline then return online end end,GetJobs=function()return {mechanic={},police={},unemployed={}}end,SetJobDuty=function()end}}
GetPlayers=function()return {}end
RegisterCommand=function()end
TriggerClientEvent=function()end
MySQL={single={await=function(sql,args)
 queries[#queries+1]={sql=sql,args=args}
 if sql:find('SELECT data,version',1,true)then return entities[key(args[1],args[2],args[3])]end
 if sql:find('FROM crimson_mdt_entries',1,true)then local row=records[args[1]];if row and row.scope==args[2]then return row end end
 if sql:find('FROM player_vehicles',1,true)and args[1]=='ABC123'then return {plate='ABC123',citizenid='CIT',vehicle='sultan'}end
 if sql:find('SELECT metadata',1,true)then return {metadata={licences={driver=true}}}end
end},query={await=function(sql,args)queries[#queries+1]={sql=sql,args=args};return {}end},scalar={await=function(sql)if sql:find('UUID',1,true)then return 'UUID'end;if sql:find('player_groups',1,true)then return 1 end;return 0 end},update={await=function(sql,args)
 queries[#queries+1]={sql=sql,args=args}
 if sql:find('INSERT IGNORE INTO crimson_mdt_entities',1,true)then
  local k=key(args[1],args[2],args[3]);if entities[k]then return 0 end
  entities[k]={data=args[4],version=1};return 1
 elseif sql:find('UPDATE crimson_mdt_entities SET',1,true)then
  local k=key(args[3],args[4],args[5]);local old=entities[k]
  if not old or old.version~=args[6]then return 0 end
  entities[k]={data=args[1],version=old.version+1};return 1
 end
 return 1
end}}
local function reject(v)error(v,0)end
local function clean(v,max,required)if type(v)~='string'or #v>max then return end;if required and v==''then return end;return v end
local function integer(v,lo,hi)if type(v)=='number'and v%1==0 and v>=lo and v<=hi then return v end end
local function person(cid)if people[cid]then return {citizenid=cid,charinfo={phone='555'}}end end
local actor={source=1,scope='justice',department='doj',grade=14,manage=true,write=true,p={citizenid='STAFF',job={name='doj',onduty=true}}}
dofile('crimson_doj/server_extensions.lua')
local ext=CrimsonExtensions({reject=reject,clean=clean,integer=integer,decode=decode,person=person,log=function()logs=logs+1 end,identity=function()return actor end})
local a=ext.actions
local view=a.citizenExtra(actor,{citizenid='CIT'});check(view.phone=='555'and view.version==0,'Qbox phone and empty version')
check(a.saveCitizenExtra(actor,{citizenid='CIT',version=0,photo='https://r2.fivemanage.com/a.jpg',notes='Legal note',wanted=true,wantedReason='Court order'}).version==1,'citizen file saved')
check(a.citizenExtra(actor,{citizenid='CIT'}).data.wanted==true,'wanted flag persisted')
denied(function()a.saveCitizenExtra(actor,{citizenid='CIT',version=0,notes='overwrite'})end,'stale profile update denied')
denied(function()a.saveCitizenExtra(actor,{citizenid='CIT',version=1,photo='https://r2.fivemanage.com/a.svg'})end,'unsafe image denied')
actor.permissions={profiles_edit=false};denied(function()a.saveCitizenExtra(actor,{citizenid='CIT',version=1})end,'explicit profile edit denial beats manage flag');actor.permissions=nil
check(a.setCitizenLicense(actor,{citizenid='CIT',license='weapon',enabled=true}),'native license grant')
check(online.PlayerData.metadata.licences.driver and online.PlayerData.metadata.licences.weapon,'other native licenses preserved')
denied(function()a.setCitizenLicense(actor,{citizenid='CIT',license='bank',enabled=true})end,'license whitelist enforced')
check(a.saveVehicleExtra(actor,{plate='abc123',version=0,photo='',notes='Vehicle note',wanted=true,reason='Case 1'}).version==1,'registered plate file')
denied(function()a.vehicleExtra(actor,{plate='UNKNOWN'})end,'unregistered plate rejected')
check(a.saveCaseBundle(actor,{id=1,version=0,participants={{citizenid='CIT',role='suspect'},{citizenid='STAFF',role='officer'}},vehicles={'ABC123'},photos={'https://r2.fivemanage.com/evidence.png'},notes='Evidence'}).version==1,'structured case persisted')
denied(function()a.saveCaseBundle(actor,{id=1,version=1,participants={{citizenid='CIT',role='admin'}},vehicles={},photos={}})end,'participant role whitelist')
denied(function()a.saveCaseBundle(actor,{id=1,version=1,participants={{citizenid='NOPE',role='suspect'}},vehicles={},photos={}})end,'unknown participant denied')
actor.scope='medical';denied(function()a.caseBundle(actor,{id=1})end,'medical cannot read justice cases');actor.scope='justice'
Config.PenalCode={{code='T1',title='Test offense',fine=100,months=5}}
check(a.recordConviction(actor,{citizenid='CIT',codes={'T1'},caseId=1,reason='Judgment'}).version==1,'structured conviction persisted')
local conviction=entities[key('justice','conviction','UUID')].data
check(conviction.fine==100 and conviction.months==5,'sentence totals server-calculated')
denied(function()a.recordConviction(actor,{citizenid='CIT',codes={'FAKE'}})end,'unconfigured offense denied')
denied(function()a.recordConviction(actor,{citizenid='CIT',codes={'T1','T1'}})end,'duplicate charge denied')
Config.DiscoverBusinesses=true
local jobs=CrimsonBusinessJobs();check(#jobs==3,'all configured and discovered jobs except unemployed')
actor.grade=9;denied(function()a.staffExtra(actor,{citizenid='CIT'})end,'staff profile management grade enforced');actor.grade=14
check(a.saveStaffExtra(actor,{citizenid='CIT',version=0,notes='Review',suspended=true,reason='Duty breach'}).version==1,'staff notes and suspension')
check(CrimsonSuspended('CIT','doj'),'suspension cache activated')
denied(function()a.saveStaffExtra(actor,{citizenid='STAFF',version=0,notes='Self'})end,'self management blocked')
check(logs>=5,'extended changes audited')
print('PASS '..count..' extended profile, license, case, conviction, staff and discovery checks')
