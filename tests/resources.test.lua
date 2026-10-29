dofile('crimson_doj/config.lua');dofile('crimson_doj/permissions.lua');dofile('crimson_doj/defaults.lua')
local n=0
local function check(v,label)assert(v,label);n=n+1 end
local function denied(fn,label)local ok=pcall(fn);check(not ok,label)end
local actor={source=1,scope='justice',department='doj',grade=14,write=true,manage=true,p={citizenid='STAFF',source=1,charinfo={firstname='Test',lastname='Chief'},job={name='doj',onduty=true}}}
local civilian={citizenid='CIT',source=2,job={name='unemployed',onduty=false}}
local invs={[1]={[1]={name='crimson_document',slot=1,count=1,metadata={print_id=5,print_ticket='T5',label='Contract'}},[2]={name='crimson_tracking_band',slot=2,count=1,metadata={}}},[2]={[1]={name='electronickit',slot=1,count=2,metadata={}}}}
local stock,loans,archive,signatures,tracking=5,{},{},{},{}
local callbacks,exported={},{}
local printrow={record_id=1,snapshot={title='Contract',body='Text',signers={'STAFF'}}}
local rejectItem=false
local nextSlot=10
local function add(src,name,count,meta)
 if rejectItem then return false end;nextSlot=nextSlot+1;invs[src][nextSlot]={slot=nextSlot,name=name,count=count,metadata=meta};return true
end
local function remove(src,name,count,meta,slot)
 for id,item in pairs(invs[src])do if item.name==name and item.count>=count and(not slot or slot==id)then item.count=item.count-count;if item.count==0 then invs[src][id]=nil end;return true end end;return false
end
exports=setmetatable({ox_inventory={GetSlot=function(_,src,slot)return invs[src][slot]end,AddItem=function(_,...)return add(...)end,RemoveItem=function(_,...)return remove(...)end,GetItemCount=function(_,src,name)local c=0;for _,i in pairs(invs[src])do if i.name==name then c=c+i.count end end;return c end,GetInventoryItems=function(_,src)return invs[src]end,Search=function(_,src)return invs[src]end},qbx_core={GetPlayer=function(_,src)if src==1 then return {PlayerData=actor.p}elseif src==2 then return {PlayerData=civilian}end end,GetPlayerByCitizenId=function(_,cid)if cid=='CIT'then return {PlayerData=civilian}end end}},{__call=function(_,name,fn)exported[name]=fn end})
lib={callback={register=function(k,f)callbacks[k]=f end}}
RegisterNetEvent=function()end
RegisterCommand=function()end
GetResourceState=function()return 'started'end
GetPlayerRoutingBucket=function()return 0 end
GetPlayerPed=function(id)return id end
GetEntityCoords=function()return {x=10,y=20,z=30}end
TriggerClientEvent=function()end
GetInvokingResource=function()return 'untrusted'end
local time,uuid=10000,0
GetGameTimer=function()return time end
json={encode=function(v)return v end}
local function decode(v)return type(v)=='table'and v or {}end
local function reject(v)error(v,0)end
local function integer(v,lo,hi)if type(v)=='number'and v%1==0 and v>=lo and v<=hi then return v end end
local function text(v,max)assert(type(v or '')=='string'and #(v or '')<=max);return v or ''end
MySQL={single={await=function(sql,args)
 if sql:find('SELECT snapshot,record_id',1,true)then if args[1]==5 and args[2]=='T5'then return printrow end end
 if sql:find('SELECT scope FROM crimson_mdt_entries',1,true)then return {scope='justice'}end
 if sql:find('FROM crimson_mdt_archived_prints',1,true)then local row=archive[args[1]];if row and row.scope==args[2]and row.state=='archived'then return row end end
 if sql:find('FROM crimson_mdt_armory_loans',1,true)then local row=loans[args[1]..':'..args[2]];if row and row.state=='active'and row.citizenid==args[3]then return row end end
 if sql:find('FROM crimson_mdt_tracking',1,true)then local row=tracking[args[1]];if row and (not sql:find('active=1',1,true)or row.active==1)then return row end end
end},scalar={await=function(sql)
 if sql:find('UUID',1,true)then uuid=uuid+1;return 'U'..uuid end
 local c=0;for _,row in pairs(loans)do if ({reserving=true,reserved=true,issuing=true,returning=true})[row.state]then c=c+1 end end;return c
end},query={await=function()return {}end},insert={await=function(sql,args)
 if sql:find('crimson_mdt_armory_loans',1,true)then loans[args[1]..':'..args[2]]={ticket=args[1],item=args[2],citizenid=args[3],job=args[4],remaining=args[5],state='reserving'}end;return 1
end}}
MySQL.update={await=function(sql,p)
 if sql:find('INSERT IGNORE INTO crimson_mdt_archived_prints',1,true)then if archive[p[1]]then return 0 end;archive[p[1]]={print_id=p[1],scope=p[2],ticket=p[3],title=p[4],state='depositing'};return 1 end
 if sql:find('DELETE FROM crimson_mdt_archived_prints',1,true)then archive[p[1]]=nil;return 1 end
 if sql:find('UPDATE crimson_mdt_archived_prints',1,true)then local row=archive[p[1]];if not row then return 0 end;row.state=sql:match("state='(%w+)'");return 1 end
 if sql:find('INSERT IGNORE INTO crimson_mdt_signatures',1,true)then local k=p[1]..':'..p[2];if signatures[k]then return 0 end;signatures[k]=true;return 1 end
 if sql:find('SET amount=amount-',1,true)then if stock<p[1]then return 0 end;stock=stock-p[1];return 1 end
 if sql:find('SET amount=amount+',1,true)then stock=stock+p[1];return 1 end
 if sql:find('UPDATE crimson_mdt_armory_loans',1,true)then
  if sql:find('state=IF',1,true)then local row=loans[p[3]..':'..p[4]];row.remaining=row.remaining-p[2];row.state=row.remaining>0 and 'active'or 'returned'
  else local row=loans[p[1]..':'..p[2]];row.state=sql:match("state='(%w+)'");if sql:find('remaining=0',1,true)then row.remaining=0 end end;return 1
 end
 if sql:find('INSERT INTO crimson_mdt_tracking',1,true)then tracking[p[1]]={citizenid=p[1],scope=p[2],active=2};return 1 end
 if sql:find('UPDATE crimson_mdt_tracking',1,true)then if tracking[p[1]]then tracking[p[1]].active=sql:find('active=1',1,true)and 1 or 0 end;return 1 end
 return 1
end}
MySQL.transaction={await=function(list)for _,q in ipairs(list)do MySQL.update.await(q.query,q.values)end;return true end}
Config.Printers={{coords={x=10,y=20,z=30},radius=2,jobs={doj=true}}}
Config.Armory.doj.coords={x=10,y=20,z=30}
local e={legal=function(a)if a.scope~='justice'then reject('legal')end end,allow=function()end,text=text,row=function(a,p)if p.id==1 then return {id=1,subject='CIT',scope='justice'}end;reject('case')end,get=function()return {version=0,data={}}end,put=function()return true end}
dofile('crimson_doj/server_resources.lua')
local api=CrimsonResources({reject=reject,integer=integer,decode=decode,log=function()end,identity=function(src)if src==1 then return actor end end},e).actions
check(callbacks['crimson_doj:signPrinted'](1,1).ok,'designated holder can sign')
check(not callbacks['crimson_doj:signPrinted'](1,1).ok,'duplicate signature rejected')
check(api.archiveDeposit(actor,{slot=1}),'physical copy deposited')
check(not invs[1][1]and archive[5].state=='archived','deposit moves inventory to archive')
check(api.archiveRetrieve(actor,{id=5}),'archived physical copy retrieved')
check(archive[5]==nil,'retrieval removes archive entry')
check(api.armoryOrder(actor,{items={{name='radio',count=2}}}),'stock order succeeds')
check(stock==3,'stock decremented once')
local slot
for id,item in pairs(invs[1])do if item.name=='radio'then slot=id end end
check(slot and invs[1][slot].metadata.crimson_owner=='STAFF','issued item contains owner/ticket')
check(api.armoryReturn(actor,{slot=slot}),'issued gear returned')
check(stock==5 and not invs[1][slot],'return restores stock and removes held items')
denied(function()api.armoryReturn(actor,{slot=slot})end,'duplicate return denied')
denied(function()api.armoryOrder(actor,{items={{name='radio',count=6}}})end,'out-of-stock order rejected')
check(stock==5,'rejected reserve leaves stock unchanged')
denied(function()api.armoryOrder(actor,{items={{name='WEAPON_FAKE',count=1}}})end,'arbitrary item rejected')
rejectItem=true
denied(function()api.armoryOrder(actor,{items={{name='radio',count=2}}})end,'inventory rejection surfaces to caller')
check(stock==5,'confirmed inventory rejection refunds reserved stock')
rejectItem=false
local beforeSign=printrow.snapshot.signers;printrow.snapshot.signers={'OTHER'}
local documentSlot;for id,item in pairs(invs[1])do if item.name=='crimson_document'then documentSlot=id end end
check(not callbacks['crimson_doj:signPrinted'](1,documentSlot).ok,'holder cannot sign when another character is designated')
printrow.snapshot.signers=beforeSign
local originalTicket=invs[1][documentSlot].metadata.print_ticket;invs[1][documentSlot].metadata.print_ticket='FORGED'
denied(function()api.archiveDeposit(actor,{slot=documentSlot})end,'forged printed ticket denied')
invs[1][documentSlot].metadata.print_ticket=originalTicket
check(api.trackingApply(actor,{source=2,caseId=1}),'case-linked band attached')
check(tracking.CIT.active==1,'tracking persisted')
denied(function()api.trackingApply(actor,{source=2,caseId=1})end,'duplicate band denied')
local first=callbacks['crimson_doj:beginBandRemoval'](2);check(first.ok,'held tool starts removal')
check(not callbacks['crimson_doj:finishBandRemoval'](2,first.data.nonce,true).ok,'impossible fast completion rejected')
local second=callbacks['crimson_doj:beginBandRemoval'](2);time=time+4000
check(callbacks['crimson_doj:finishBandRemoval'](2,second.data.nonce,true).ok and tracking.CIT.active==0,'timed successful minigame consumes tool and removes band')
check(not callbacks['crimson_doj:finishBandRemoval'](2,second.data.nonce,true).ok,'removal nonce cannot replay')
local ok=exported.CreateDispatch({coords={x=1,y=2,z=3}});check(ok==false,'untrusted dispatch resource denied')
print('PASS '..n..' extended inventory archive, signatures, stock, returns, tracking and dispatch checks')
