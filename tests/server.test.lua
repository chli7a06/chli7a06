Config={Jobs={doj={read=0,write=1,manage=3}},RequireDuty=true,MaxText=12000}
local player,callback
exports={qbx_core={GetPlayer=function() return player end}}
GetGameTimer=function() return 100000 end
GetCurrentResourceName=function() return 'crimson_doj' end
LoadResourceFile=function() return 'CREATE TABLE example (id INT);' end
AddEventHandler=function() end
json={decode=function() return {} end}
lib={callback={register=function(_,fn) callback=fn end}}
local row={id=1,kind='case',created_by='OTHER',status='open',version=1}
local writes=0
MySQL={query={await=function() return {} end},single={await=function(sql)
if sql:find('FROM players') then return {citizenid='CITIZEN',charinfo='{}'} end return row end},insert={await=function() return 9 end},update={await=function() writes=writes+1 return 1 end},ready=function(fn) fn() end}
dofile('crimson_doj/server.lua')
local source,n=0,0
local function user(job,grade,duty) player={PlayerData={citizenid='STAFF',job={name=job,grade={level=grade},onduty=duty}}} end
local function req(action,data) source=source+1 return callback(source,action,data or {}) end
local function check(v,label) assert(v,label) n=n+1 end
local new={kind='case',citizenid='CITIZEN',title='t',body='b'}
user('unemployed',4,true);check(not req('bootstrap').ok,'other job denied')
user('doj',4,false);check(not req('bootstrap').ok,'off duty denied')
user('doj',0,true);check(req('bootstrap').ok,'reader allowed');check(not req('create',new).ok,'reader cannot write')
user('doj',1,true);check(req('create',new).ok,'writer creates case')
new.kind='warrant';check(not req('create',new).ok,'writer cannot issue warrant')
new.kind='case';new.title='';check(not req('create',new).ok,'empty title denied')
new.title='t';new.body=string.rep('x',12001);check(not req('create',new).ok,'large text denied');new.body='b'
local edit={id=1,version=1,title='new',body='b',status='open'}
check(not req('update',edit).ok,'other author denied');check(writes==0,'denied update does not write')
row.created_by='STAFF';check(req('update',edit).ok,'own edit allowed')
edit.status='closed';check(not req('update',edit).ok,'writer cannot close')
user('doj',3,true);check(req('update',edit).ok,'manager closes');new.kind='warrant';check(req('create',new).ok,'manager issues warrant')
MySQL.update.await=function() return 0 end;check(not req('update',edit).ok,'stale revision denied')
check(not req('list',{kind='bad'}).ok,'bad kind denied');check(not req('search',{query='a'}).ok,'short search denied')
check(req('audit').ok,'manager audit');user('doj',1,true);check(not req('audit').ok,'writer audit denied')
print('PASS: '..n..' authorization, input and concurrency checks')
