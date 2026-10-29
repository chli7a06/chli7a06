dofile('crimson_doj/config.lua')
local checks=0
local function check(value,label)assert(value,label)checks=checks+1 end
local function deny(fn,label)local ok=pcall(fn)check(not ok,label)end
local callbacks,events,logEvents={}, {},{}
lib={callback={register=function(name,fn)callbacks[name]=fn end}}
RegisterNetEvent=function(name,fn)events[name]=fn end
AddEventHandler=function()end
TriggerClientEvent=function(name,src,data)events.last={name=name,source=src,data=data}end
SetTimeout=function()end
GetGameTimer=function()return 100000 end
GetPlayerRoutingBucket=function()return 0 end
GetCurrentResourceName=function()return 'crimson_doj'end
GetResourceState=function()return 'started'end
local distance=0
GetPlayerPed=function(id)return id end
GetEntityCoords=function(ped)return {x=ped==2 and distance or 0,y=0,z=0}end
local staff={PlayerData={citizenid='STAFF',source=1,money={bank=1000},metadata={injail=0}}}
local payer={PlayerData={citizenid='CIV',source=2,money={bank=1000},metadata={injail=0}}}
local accounts={mechanic=1000,doj=1000}
local journal,custody,entries={}, {},{}
local debitMode,creditMode,finishSQL='ok','ok',true
local debitCalls,creditCalls,refundCalls=0,0,0
local captureComplete,captureStopped,storedCount,streamCount
local invoice={id=1,kind='invoice',scope='business:mechanic',subject='CIV',version=1,status='open',title='Repair',details={total=100,payment='unpaid'}}
local legalRecord={id=10,kind='case',scope='justice',subject='CIV',version=1,details={}}
entries[1]=invoice;entries[10]=legalRecord
local activeRow=legalRecord
local exportsTable={}
exportsTable.qbx_core={GetPlayer=function(_,src)return src==1 and staff or src==2 and payer end,GetPlayerByCitizenId=function(_,cid)return cid=='CIV' and payer or nil end,
 RemoveMoney=function(_,src,kind,amount)
  debitCalls=debitCalls+1
  if debitMode=='reject' then return false end
  payer.PlayerData.money.bank=payer.PlayerData.money.bank-amount
  if debitMode=='throw' then error('provider debit uncertainty')end
  return true
 end,
 AddMoney=function(_,src,kind,amount)refundCalls=refundCalls+1;payer.PlayerData.money.bank=payer.PlayerData.money.bank+amount;return true end}
exportsTable['Renewed-Banking']={getAccountMoney=function(_,name)return accounts[name] or false end,addAccountMoney=function(_,name,amount)
 creditCalls=creditCalls+1;if creditMode=='reject' then return false end
 accounts[name]=accounts[name]+amount;if creditMode=='throw' then error('provider credit uncertainty')end return true end,getAccountTransactions=function()return {}end}
exportsTable.qbx_prison={JailPlayer=function(_,src,minutes)payer.PlayerData.metadata.injail=minutes end,ReleasePlayer=function()payer.PlayerData.metadata.injail=0 end}
exportsTable.screencapture={startVideoCapture=function(_,src,opts,cb)captureComplete=cb;return 'capture-123'end,stopVideoCapture=function(_,id)captureStopped=id end}
exportsTable.crimson_doj={storeCapture=function(_,file,maxBytes,cb)storedCount=(storedCount or 0)+1;cb({ok=true,filename='00000000-0000-0000-0000-000000000000.webm',bytes=20})end,
streamStored=function(_,src,file,maxBytes,cb)streamCount=(streamCount or 0)+1;cb({ok=true,ticket='stream-123'})end,
deleteStored=function(_,name,cb)cb({ok=true})end,cancelStream=function()end}
exports=exportsTable
promise={new=function()return {resolve=function(self,value)self.value=value end}end}
Citizen={Await=function(p)return p.value end}
json={encode=function(value)return value end,decode=function(value)return type(value)=='table' and value or {}end}
MySQL={single={await=function(sql,args)
 if sql:find('FROM crimson_mdt_payments')then return journal[args[1]]end
 if sql:find('FROM crimson_mdt_entries')then
  local row=entries[args[1]]
  if not row then return end
  if sql:find('subject=?')and row.subject~=args[2]then return end
  if sql:find('scope=?')and row.scope~=args[2]then return end
  return row
 end
end},scalar={await=function()return 0 end},query={await=function()return {}end},update={await=function(sql,args)
 if sql:find('INSERT IGNORE INTO crimson_mdt_payments')then
  if journal[args[1]]then return 0 end
  journal[args[1]]={entry_id=args[1],kind=args[2],payer=args[3],account=args[4],amount=args[5],state='debiting'}return 1
 elseif sql:find('UPDATE crimson_mdt_payments SET state=?')then journal[args[3]].state=args[1]return 1
 elseif sql:find('INSERT IGNORE INTO crimson_mdt_custody')then
  if custody[args[1]]then return 0 end
  custody[args[1]]={state='processing',cid=args[2]}return 1
 elseif sql:find("crimson_mdt_custody SET state='jailed'")then custody[args[1]].state='jailed';return 1
 elseif sql:find("crimson_mdt_custody SET state='released'")then custody[args[1]].state='released';return 1
 end
 return 1
end},insert={await=function(sql,args)
 if sql:find("'recording'")then entries[88]={id=88,scope=args[1],kind='recording',subject=args[2],details=args[5]}end return 88 end},transaction={await=function(q)
 if not finishSQL then return false end
 local resolution=q[1].query:find('SET state=?',1,true);local id=resolution and q[1].values[3] or q[1].values[1];journal[id].state=resolution and q[1].values[1] or 'paid';return true
end}}
local function reject(msg)error('CRIMSON_VALIDATION:'..msg,0)end
local function clean(v,max,required)if type(v)~='string' or #v>max or required and v==''then return end return v end
local function integer(v,lo,hi)if type(v)=='number'and v==v and v%1==0 and v>=lo and v<=hi then return v end end
local function actor(department,manage)return {department=department,manage=manage,write=true,scope=department=='business'and'business:mechanic'or department=='ems'and'medical'or'justice',p={citizenid='STAFF',job={name=department=='business'and'mechanic'or'doj'}},source=1,policy={label='Crimson'}}end
local business,legalActor=actor('business',true),actor('doj',true)
dofile('crimson_doj/permissions.lua')
Config.DojGrades=nil;Config.MDTJobs=nil;Config.ManagementMinGrade=0
Config.Banking={provider='Renewed-Banking',accounts={}}
dofile('crimson_doj/server_banking.lua')
dofile('crimson_doj/server_extras.lua')
local api=CrimsonServices({reject=reject,clean=clean,integer=integer,decode=function(v)return type(v)=='table'and v or {}end,person=function()return true end,log=function(a,name,id)logEvents[#logEvents+1]=name end,ready=function()return true end})
local function pay(version,src)return callbacks['crimson_doj:payInvoice'](src or 2,{id=1,version=version or 1})end
check(api.offerInvoice(business,{id=1})==true,'business can offer invoice')
check(events.last.source==2 and events.last.data.amount==100,'offer addressed to debtor with server total')
check(not pay(1,1).ok,'other player cannot pay debtor invoice')
check(not pay(2).ok,'stale invoice version rejected')
payer.PlayerData.money.bank=10;check(not pay().ok and debitCalls==0,'insufficient funds rejected before debit');payer.PlayerData.money.bank=1000
accounts.mechanic=nil;check(not pay().ok and debitCalls==0,'missing destination rejected before debit');accounts.mechanic=1000
check(pay().ok,'invoice payment accepted');check(payer.PlayerData.money.bank==900 and accounts.mechanic==1100,'exact bank-to-job transfer');check(journal[1].state=='paid','paid journal committed')
check(pay().ok and debitCalls==1 and creditCalls==1,'duplicate settlement does not charge again')
local function resetPayment()
 journal={};payer.PlayerData.money.bank=1000;accounts.mechanic=1000;debitMode='ok';creditMode='ok';finishSQL=true;debitCalls=0;creditCalls=0;refundCalls=0
end
resetPayment();creditMode='reject';check(not pay().ok,'credit refusal reported');check(payer.PlayerData.money.bank==1000 and refundCalls==1 and journal[1].state=='refunded','known failed credit refunds debit')
resetPayment();creditMode='throw';check(not pay().ok and journal[1].state=='needs_review','uncertain credit locked for review');check(refundCalls==0,'unknown credit is not automatically refunded');local charged=debitCalls;check(not pay().ok and debitCalls==charged,'uncertain payment cannot replay')
resetPayment();debitMode='throw';check(not pay().ok and journal[1].state=='needs_review','uncertain debit locked');check(creditCalls==0,'unknown debit never credits destination')
resetPayment();finishSQL=false;check(not pay().ok and journal[1].state=='needs_review','post-transfer SQL failure locked');check(payer.PlayerData.money.bank==900 and accounts.mechanic==1100,'SQL failure does not repeat or undo provider operations')
resetPayment();debitMode='reject';check(not pay().ok and journal[1].state=='failed'and creditCalls==0,'known debit refusal never credits')
resetPayment();deny(function()api.fine(business,{id=10,amount=50,reason='Test'})end,'business cannot fine')
deny(function()api.fine(actor('doj',false),{id=10,amount=50,reason='Test'})end,'nonmanager cannot fine')
distance=20;deny(function()api.fine(legalActor,{id=10,amount=50,reason='Test'})end,'fine requires proximity');distance=0
deny(function()api.fine(legalActor,{id=10,amount=-1,reason='Test'})end,'negative fine rejected')
check(api.fine(legalActor,{id=10,amount=50,reason='Test'}).paid,'manager fine uses actual provider');check(accounts.doj==1050,'fine credited to configured account')
check(api.jail(legalActor,{id=10,minutes=10,reason='Test sentence'})==true,'native qbx_prison sentence');check(payer.PlayerData.metadata.injail==10 and custody[10].state=='jailed','custody recorded')
deny(function()api.jail(legalActor,{id=10,minutes=10,reason='Test'})end,'already imprisoned denied')
check(api.release(legalActor,{id=10})==true and payer.PlayerData.metadata.injail==0,'native release')
deny(function()api.jail(legalActor,{id=10,minutes=999,reason='Test'})end,'sentence limit enforced')
deny(function()api.jail(legalActor,{id=10,minutes=10,reason='Test'})end,'same case sentence not replayed')
deny(function()api.bodycamStart(business)end,'business cannot bodycam')
check(api.bodycamStart(legalActor).captureId=='capture-123','screencapture timed capture starts')
deny(function()api.bodycamStart(legalActor)end,'duplicate capture denied')
check(api.bodycamStop(legalActor)==true and captureStopped=='capture-123','capture stop uses owned ID')
captureComplete({status='success',filePath='/provider/tmp/test.webm',duration=12})
check(storedCount==1 and entries[88].scope=='justice','capture privately stored in department scope')
check(api.playRecording(legalActor,{id=88}).ticket=='stream-123'and streamCount==1,'recording playback authorized')
deny(function()api.playRecording(actor('ems',true),{id=88})end,'other department cannot stream recording')
check(api.deleteRecording(legalActor,{id=88})==true,'manager may remove stored video')
resetPayment();creditMode='throw';pay();check(journal[1].state=='needs_review','review fixture created')
local beforeDebit,beforeCredit=debitCalls,creditCalls
check(api.resolvePayment(1,'paid','Verified both external accounts')==true,'console metadata reconciliation')
check(debitCalls==beforeDebit and creditCalls==beforeCredit,'reconciliation never moves money')
deny(function()api.resolvePayment(1,'refunded','Repeat')end,'resolved payment cannot be overwritten')

accounts.mechanic=1234
exportsTable['Renewed-Banking'].getAccountTransactions=function()return {{trans_id='TX1',title='Service',amount=200,trans_type='deposit',message='Payment',issuer='CIV',receiver='mechanic',time=12345,auth='PRIVATE'}}end
local company=api.businessFinance(legalActor,{job='mechanic'})
check(company.available and company.balance==1234 and company.account=='mechanic','DOJ manager sees configured business bank balance')
check(company.transactions[1].amount==200 and company.transactions[1].auth==nil,'company transactions expose only selected public fields')
accounts.mechanic=0;check(api.businessFinance(legalActor,{job='mechanic'}).balance==0,'zero company balance is valid')
accounts.mechanic=nil;company=api.businessFinance(legalActor,{job='mechanic'});check(not company.available and company.balance==nil,'missing company account is not shown as zero')
deny(function()api.businessFinance(actor('doj',false),{job='mechanic'})end,'ordinary DOJ cannot inspect company money')
deny(function()api.businessFinance(actor('police',true),{job='mechanic'})end,'police cannot use DOJ company financial inspection')
deny(function()api.businessFinance(business,{job='mechanic'})end,'business cannot inspect other accounts through registry endpoint')
deny(function()api.businessFinance(legalActor,{job='unlisted-account'})end,'arbitrary account enumeration denied')
exportsTable['Renewed-Banking'].getAccountTransactions=function()local t={}for i=1,105 do t[i]={amount=i}end return t end
accounts.mechanic=1;check(#api.businessFinance(legalActor,{job='mechanic'}).transactions==100,'company transaction history bounded to 100')

SavedBankProvider=CrimsonBankProvider
CrimsonBankProvider=nil
local originalLoad=LoadResourceFile
LoadResourceFile=function(_,filename)
 if filename=='server_banking.lua' then return 'CrimsonBankProvider=SavedBankProvider' end
 if filename=='bank_adapters.lua' then return '-- server adapters' end
end
check(api.bankAccount(legalActor).balance==accounts.doj,'retained old manifest lazily loads verified local bank modules')
CrimsonBankProvider=nil
LoadResourceFile=function()return nil end
local missingOk,missingError=pcall(api.bankAccount,legalActor)
check(not missingOk and tostring(missingError):find('Missing server_banking.lua',1,true),'missing banking file yields actionable diagnostic')
LoadResourceFile=originalLoad
dofile('crimson_doj/server_banking.lua')
Config.ManagementMinGrade=10
legalActor.grade=0;legalActor.permissions={business_view=true};legalActor.manage=false
check(api.businessFinance(legalActor,{job='mechanic'}).balance==accounts.mechanic,'student can inspect company finance outside Management')
deny(function()api.bankAccount(legalActor)end,'own Management treasury remains blocked below ten')
print('PASS '..checks..' service checks for consent payments, failures, prison and recordings')
