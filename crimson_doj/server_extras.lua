function CrimsonServices(h)
 local reject,clean,integer,decode=h.reject,h.clean,h.integer,h.decode
 local paymentLocks,offerTimes,custodyLocks,paymentRates,resolutionLocks={},{ },{},{},{}
 local api={}
 local captures={}

 local function requireBank()
  -- Recover upgrades that retained an older manifest without the new adapter files.
  if type(CrimsonBankProvider)~='function' then
   for _,filename in ipairs({'server_banking.lua','bank_adapters.lua'}) do
    local source=LoadResourceFile(GetCurrentResourceName(),filename)
    if not source then reject('Missing '..filename..'. Install the complete Crimson resource ZIP.') end
    local chunk,parseError=load(source,'@crimson_doj/'..filename,'t',_ENV)
    if not chunk then reject('Bank adapter file could not load: '..tostring(parseError)) end
    local loaded,loadError=pcall(chunk)
    if not loaded then reject('Bank adapter initialization failed: '..tostring(loadError)) end
   end
  end
  if type(CrimsonBankProvider)~='function' then reject('Bank adapter did not initialize') end
  local ok,bank=xpcall(CrimsonBankProvider,debug.traceback)
  if not ok then
   print('[crimson_doj banking] '..tostring(bank))
   reject(tostring(bank):match('^[^\n]+') or 'Bank provider initialization failed')
  end
  return bank
 end
 local function legal(a)
  if (a.department~='doj' and a.department~='police') or not CrimsonPermission(a,'convictions_create',a.manage) then reject('Legal management permission required') end
 end
 local function caseRow(a,id)
  id=integer(id,1,2147483647)
  local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind IN ('case','incident')",{id,a.scope})
  if not row then reject('Select a case or incident first') end
  return row
 end
 local function nearbyTarget(a,cid)
  if cid==a.p.citizenid then reject('Cannot apply legal actions to yourself') end
  local p=exports.qbx_core:GetPlayerByCitizenId(cid)
  if not p then reject('The citizen must be online') end
  local source=p.PlayerData.source
  if GetPlayerRoutingBucket(a.source)~=GetPlayerRoutingBucket(source) then reject('The citizen is in another routing bucket') end
  local ped,other=GetPlayerPed(a.source),GetPlayerPed(source)
  if not ped or ped==0 or not other or other==0 then reject('Citizen position unavailable') end
  local c,d=GetEntityCoords(ped),GetEntityCoords(other)
  if ((c.x-d.x)^2+(c.y-d.y)^2+(c.z-d.z)^2)^0.5>(Config.Law.distance or 10) then reject('The citizen must be nearby') end
  return p
 end
 local function journal(id,state,note)
  MySQL.update.await('UPDATE crimson_mdt_payments SET state=?,error_note=? WHERE entry_id=?',{state,note or '',id})
 end
 local function settle(row,payer,amount,account,kind,scope,actor,reason)
  local bank=requireBank()
  if not bank.credit then reject('This banking adapter is read-only; payments are disabled') end
  if not integer(amount,1,Config.Payments.maxAmount) then reject('Invalid payment amount') end
  if type(account)~='string' then reject('Invalid destination account') end
  local accountBalance=bank.balance(account)
  if accountBalance==false or accountBalance==nil then reject('Company bank account unavailable: '..account) end
  local cid=payer.PlayerData.citizenid
  local current=exports.qbx_core:GetPlayer(payer.PlayerData.source)
  if not current or current.PlayerData.citizenid~=cid then reject('Payer disconnected or changed character') end
  if paymentLocks[cid] then reject('Another payment is processing') end
  paymentLocks[cid]=true
  local ok,result=pcall(function()
   local existing=MySQL.single.await('SELECT * FROM crimson_mdt_payments WHERE entry_id=?',{row.id})
   if existing then
    if existing.state=='paid' then return {paid=true,alreadyPaid=true} end
    reject('Payment already recorded as '..existing.state..'. A manager must reconcile it; no automatic retry.')
   end
   if (tonumber(payer.PlayerData.money.bank) or 0)<amount then reject('Insufficient bank balance') end
   local claimed=MySQL.update.await("INSERT IGNORE INTO crimson_mdt_payments(entry_id,kind,payer,account,amount,reason,state) VALUES(?,?,?,?,?,?,'debiting')",{row.id,kind,cid,account,amount,reason or ''})
   if claimed~=1 then reject('Payment already processing') end
   local live=exports.qbx_core:GetPlayer(payer.PlayerData.source)
   if not live or live.PlayerData.citizenid~=cid or (tonumber(live.PlayerData.money.bank) or 0)<amount then journal(row.id,'failed','Payer session or balance changed') reject('Payer session or balance changed') end
   local removedOk,removed=pcall(function()return exports.qbx_core:RemoveMoney(cid,'bank',amount,'crimson-mdt-'..kind..'-'..row.id)end)
   if not removedOk then journal(row.id,'needs_review','Debit outcome unknown') reject('Bank outcome uncertain; payment locked for review') end
   if not removed then journal(row.id,'failed','Debit rejected; no credit attempted') reject('Qbox rejected the bank debit') end
   journal(row.id,'crediting')
   local creditedOk,credited=pcall(function()return bank.credit(account,amount,reason or '')end)
   if not creditedOk then journal(row.id,'needs_review','Credit outcome unknown') reject('Credit outcome uncertain; do not retry; ask a manager to reconcile') end
   if not credited then
    local refundedOk,refunded=pcall(function()return exports.qbx_core:AddMoney(cid,'bank',amount,'crimson-mdt-refund-'..row.id)end)
    journal(row.id,refundedOk and refunded and 'refunded' or 'needs_review','Destination rejected credit')
    reject(refundedOk and refunded and 'Destination rejected payment. Bank debit refunded.' or 'Refund uncertain; manager review required')
   end
   local path=kind=='invoice' and '$.payment' or '$.finePayment'
   local saved=MySQL.transaction.await({
    {query="UPDATE crimson_mdt_payments SET state='paid',error_note='' WHERE entry_id=?",values={row.id}},
    {query="UPDATE crimson_mdt_entries SET details=JSON_SET(details, ?, 'paid', '$.paidAmount', ?, '$.paymentReason', ?),updated_by=?,version=version+1 WHERE id=?",values={path,amount,reason or '',actor,row.id}},
    {query='INSERT INTO crimson_mdt_audit(scope,actor,action,record_id) VALUES(?,?,?,?)',values={scope,actor,kind..'_paid',row.id}}
   })
   if not saved then journal(row.id,'needs_review','Funds moved; final SQL transaction failed') reject('Funds moved, but accounting needs manager review. Do not pay again.') end
   pcall(function()
    local reference='crimson-'..kind..'-'..row.id
    if bank.history then bank.history(account,cid,kind,amount,reason or '',reference) end
   end)
   return {paid=true,amount=amount}
  end)
  paymentLocks[cid]=nil
  if not ok then error(result,0) end
  return result
 end
 function api.initialize()
  -- Never replay uncertain money/prison operations after restart.
  MySQL.update.await("UPDATE crimson_mdt_payments SET state='needs_review',error_note='Interrupted operation; reconcile providers' WHERE state IN ('debiting','crediting')")
  MySQL.update.await("UPDATE crimson_mdt_custody SET state='needs_review' WHERE state='processing'")
 end
 function api.integrationStatus()
  return {
   inventory=Config.Integrations.inventory=='ox_inventory' and GetResourceState('ox_inventory')=='started',
   cameras=Config.Integrations.cameras==true,
   banking=pcall(requireBank),
   jail=Config.Integrations.jail=='qbx_prison' and GetResourceState('qbx_prison')=='started',
   bodycam=Config.Integrations.bodycam=='screencapture' and GetResourceState('screencapture')=='started',
  }
 end
 function api.paymentStatus(a,payload)
  if not a.manage then reject('Management permission required') end
  return MySQL.query.await('SELECT p.* FROM crimson_mdt_payments p JOIN crimson_mdt_entries e ON e.id=p.entry_id WHERE e.scope=? ORDER BY p.updated_at DESC LIMIT 100',{a.scope})
 end
 -- Console-only administrative metadata resolution. This never moves money.
 function api.resolvePayment(id,outcome,note)
  id=integer(id,1,2147483647)
  note=clean(note,130,true)
  if not id or not note or not ({paid=true,refunded=true,failed=true})[outcome] then reject('Usage: crimsonresolve <record-id> <paid|refunded|failed> <verified reason>') end
  if resolutionLocks[id] then reject('This payment is being reviewed already') end
  resolutionLocks[id]=true
  local ok,result=pcall(function()
  local row=MySQL.single.await('SELECT * FROM crimson_mdt_payments WHERE entry_id=?',{id})
  if not row or row.state~='needs_review' then reject('Only a needs_review payment can be resolved') end
  local entry=MySQL.single.await('SELECT * FROM crimson_mdt_entries WHERE id=?',{id})
  if not entry then reject('Payment source record missing') end
  local path=row.kind=='invoice' and '$.payment' or '$.finePayment'
  local saved=MySQL.transaction.await({
   {query='UPDATE crimson_mdt_payments SET state=?,error_note=? WHERE entry_id=?',values={outcome,'Verified in console: '..note,id}},
   {query='UPDATE crimson_mdt_entries SET details=JSON_SET(details, ?, ?),version=version+1 WHERE id=?',values={path,outcome,id}},
   {query='INSERT INTO crimson_mdt_audit(scope,actor,action,record_id) VALUES(?,?,?,?)',values={entry.scope,'server-console','payment_resolved_'..outcome,id}}
  })
  if not saved then reject('Resolution transaction failed') end
  return true
  end)
  resolutionLocks[id]=nil
  if not ok then error(result,0) end
  return result
 end
 function api.businessFinance(a,payload)
  if a.department~='doj' or not CrimsonPermission(a,'business_view',a.manage) then reject('DOJ business view permission required') end
  local job=clean(payload.job,80,true)
  local configured=false
  for _,name in ipairs(Config.BusinessJobs)do if name==job then configured=true break end end
  if not configured then reject('Business is not in the configured registry') end
  local bank=requireBank()
  local value=bank.balance(job)
  local balance=value~=false and tonumber(value) or nil
  local available=balance~=nil and balance==balance and balance~=math.huge and balance~=-math.huge
  local transactions={}
  if available then
   local rows=bank.transactions(job)
   if type(rows)=='table' then
    for _,row in ipairs(rows)do
     if #transactions>=100 then break end
     if type(row)=='table' then
      local amount=tonumber(row.amount)
      if not amount or amount~=amount or amount==math.huge or amount==-math.huge then amount=nil end
      transactions[#transactions+1]={id=clean(row.trans_id or '',160,false) or '',title=clean(row.title or '',300,false) or '',amount=amount,type=clean(row.trans_type or '',40,false) or '',message=clean(row.message or '',1000,false) or '',issuer=clean(row.issuer or '',160,false) or '',receiver=clean(row.receiver or '',160,false) or '',time=tonumber(row.time)}
     end
    end
   end
  end
  h.log(a,'business_bank_read',nil)
  return {provider=bank.name,account=job,available=available,balance=available and balance or nil,transactions=transactions}
 end
 function api.bankAccount(a)
  if not a.manage then reject('Management permission required') end
  local bank=requireBank()
  local account=a.p.job.name
  local balance=bank.balance(account)
  if balance==false or balance==nil then reject('Company bank account unavailable') end
  return {provider=bank.name,account=account,balance=balance,transactions=bank.transactions(account)}
 end
 function api.offerInvoice(a,payload)
  if a.department~='business' or not a.write then reject('Business invoice permission required') end
  requireBank()
  local id=integer(payload.id,1,2147483647)
  local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind='invoice' AND status='open'",{id,a.scope})
  if not row then reject('Open invoice not found') end
  local details=decode(row.details)
  if details.payment=='paid' then reject('Invoice already paid') end
  if not integer(details.total,1,Config.Payments.maxAmount) then reject('Invoice amount invalid') end
  local target=exports.qbx_core:GetPlayerByCitizenId(row.subject)
  if not target then reject('Invoice recipient must be online') end
  local key=row.subject
  if offerTimes[key] and os.time()-offerTimes[key]<Config.Payments.offerCooldown then reject('Wait before resending this invoice') end
  offerTimes[key]=os.time()
  TriggerClientEvent('crimson_doj:invoiceOffer',target.PlayerData.source,{id=id,version=row.version,amount=details.total,title=row.title,business=a.policy.label})
  h.log(a,'invoice_offer',id)
  return true
 end
 lib.callback.register('crimson_doj:payInvoice',function(source,payload)
  if not h.ready() or type(payload)~='table' then return {ok=false,error='Payments unavailable'} end
  local now=GetGameTimer()
  local bucket=paymentRates[source]
  if not bucket or now-bucket.time>10000 then bucket={time=now,count=0} paymentRates[source]=bucket end
  bucket.count=bucket.count+1
  if bucket.count>30 then return {ok=false,error='Too many payment requests'} end
  local ok,result=pcall(function()
   local payer=exports.qbx_core:GetPlayer(source)
   if not payer then reject('Player unavailable') end
   local id=integer(payload.id,1,2147483647)
   local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND kind='invoice' AND subject=? AND status='open'",{id,payer.PlayerData.citizenid})
   if not row then reject('Invoice not found or not addressed to you') end
   if row.version~=payload.version then reject('Invoice changed. Request a fresh payment offer.') end
   local details=decode(row.details)
   if not row.scope:match('^business:') then reject('Invalid invoice scope') end
   return settle(row,payer,details.total,row.scope:sub(10),'invoice',row.scope,payer.PlayerData.citizenid,row.title)
  end)
  return ok and {ok=true,data=result} or {ok=false,error=tostring(result):match('CRIMSON_VALIDATION:(.*)') or 'Payment interrupted. Ask staff to check the journal; do not retry blindly.'}
 end)
 function api.fine(a,payload)
  legal(a)
  local amount=integer(payload.amount,1,Config.Law.maxFine)
  local reason=clean(payload.reason,1000,true)
  if not amount or not reason then reject('Enter a bounded fine amount and reason') end
  local row=caseRow(a,payload.id)
  local target=nearbyTarget(a,row.subject)
  h.log(a,'fine_requested',row.id)
  return settle(row,target,amount,Config.Law.fineAccount,'fine',a.scope,a.p.citizenid,reason)
 end
 function api.jail(a,payload)
  legal(a)
  if Config.Integrations.jail~='qbx_prison' or GetResourceState('qbx_prison')~='started' then reject('Install and start qbx_prison first') end
  local minutes=integer(payload.minutes,1,Config.Law.maxJailMinutes)
  local reason=clean(payload.reason,1000,true)
  if not minutes or not reason then reject('Enter a bounded sentence and reason') end
  local row=caseRow(a,payload.id)
  local target=nearbyTarget(a,row.subject)
  if custodyLocks[row.subject] then reject('Another custody operation is processing for this citizen') end
  custodyLocks[row.subject]=true
  local ok,result=pcall(function()
   if (tonumber(target.PlayerData.metadata.injail) or 0)>0 then reject('Citizen is already in prison') end
   local claimed=MySQL.update.await("INSERT IGNORE INTO crimson_mdt_custody(entry_id,citizenid,minutes,actor,reason,state) VALUES(?,?,?,?,?,'processing')",{row.id,row.subject,minutes,a.p.citizenid,reason})
   if claimed~=1 then reject('A custody action already exists for this case; review it before retrying') end
   target=nearbyTarget(a,row.subject)
   exports.qbx_prison:JailPlayer(target.PlayerData.source,minutes)
   MySQL.update.await("UPDATE crimson_mdt_custody SET state='jailed' WHERE entry_id=?",{row.id})
   h.log(a,'jail_'..minutes..'m',row.id)
   return true
  end)
  custodyLocks[row.subject]=nil
  if not ok then error(result,0) end
  return result
 end
 function api.release(a,payload)
  legal(a)
  if Config.Integrations.jail~='qbx_prison' or GetResourceState('qbx_prison')~='started' then reject('Install and start qbx_prison first') end
  local row=caseRow(a,payload.id)
  local target=nearbyTarget(a,row.subject)
  if custodyLocks[row.subject] then reject('Another custody operation is processing for this citizen') end
  custodyLocks[row.subject]=true
  local ok,result=pcall(function()
   if (tonumber(target.PlayerData.metadata.injail) or 0)<=0 then reject('Citizen is not in prison') end
   target=nearbyTarget(a,row.subject)
   exports.qbx_prison:ReleasePlayer(target.PlayerData.source)
   MySQL.update.await("UPDATE crimson_mdt_custody SET state='released' WHERE entry_id=?",{row.id})
   h.log(a,'prison_release',row.id)
   return true
  end)
  custodyLocks[row.subject]=nil
  if not ok then error(result,0) end
  return result
 end
 local function mediaCall(method,...)
  local p=promise.new()
  local finished=false
  local args={...}
  args[#args+1]=function(result)if not finished then finished=true p:resolve(result) end end
  SetTimeout(15000,function()if not finished then finished=true p:resolve({ok=false,error='Media operation timed out'}) end end)
  local resource=exports[GetCurrentResourceName()]
  local ok,err=pcall(function()resource[method](resource,table.unpack(args))end)
  if not ok and not finished then finished=true p:resolve({ok=false,error='Media provider failed'}) end
  return Citizen.Await(p)
 end
 local function recordingAllowed(a)
  if a.department=='business' or not a.write then reject('Bodycam permission required') end
  if Config.Integrations.bodycam~='screencapture' or GetResourceState('screencapture')~='started' then reject('Install the screencapture release with video support first') end
 end
 function api.bodycamStart(a)
  recordingAllowed(a)
  if captures[a.p.citizenid] then reject('Your bodycam is already recording') end
  local count=MySQL.scalar.await("SELECT COUNT(*) FROM crimson_mdt_entries WHERE kind='recording' AND JSON_UNQUOTE(JSON_EXTRACT(details,'$.storage'))='local'")
  local running=0 for _ in pairs(captures)do running=running+1 end
  if tonumber(count)+running>=Config.Bodycam.maxClips then reject('Recording storage limit reached; ask a manager to remove old clips') end
  local current=exports.qbx_core:GetPlayer(a.source)
  if not current or current.PlayerData.citizenid~=a.p.citizenid then reject('Recording player disconnected or changed character') end
  local capture={source=a.source,cid=a.p.citizenid}
  captures[a.p.citizenid]=capture
  local ok,id=pcall(function()
   return exports.screencapture:startVideoCapture(a.source,{duration=Config.Bodycam.duration,maxWidth=Config.Bodycam.width,maxHeight=Config.Bodycam.height},function(result)
    local stored
    local saved,err=pcall(function()
     if result.status~='success' or type(result.filePath)~='string' then reject('Capture failed') end
     stored=mediaCall('storeCapture',result.filePath,Config.Bodycam.maxBytes)
     if not stored.ok then reject(stored.error) end
     local details={storage='local',filename=stored.filename,bytes=stored.bytes,duration=result.duration or Config.Bodycam.duration}
     MySQL.insert.await("INSERT INTO crimson_mdt_entries(scope,kind,subject,title,body,details,owner,updated_by) VALUES(?,'recording',?,?,?,?,?,?)",{a.scope,a.p.citizenid,'Bodycam · '..os.date('%Y-%m-%d %H:%M:%S'),'Self-started gameplay recording',json.encode(details),a.p.citizenid,a.p.citizenid})
     h.log(a,'bodycam_saved',nil)
    end)
    if not saved then
     if stored and stored.ok then mediaCall('deleteStored',stored.filename) end
     print('[crimson bodycam] '..tostring(err))
    end
    captures[a.p.citizenid]=nil
    local current=exports.qbx_core:GetPlayer(a.source)
    if current and current.PlayerData.citizenid==a.p.citizenid then
     TriggerClientEvent('crimson_doj:bodycamStatus',a.source,{active=false,saved=saved,error=saved and nil or 'Capture could not be saved'})
    end
   end)
  end)
  if not ok or not id then captures[a.p.citizenid]=nil reject('Could not start screencapture; check provider version and console') end
  capture.id=id
  TriggerClientEvent('crimson_doj:bodycamStatus',a.source,{active=true,duration=Config.Bodycam.duration})
  return {captureId=id}
 end
 function api.bodycamStop(a)
  local capture=captures[a.p.citizenid]
  if not capture or not capture.id then reject('No active bodycam capture') end
  exports.screencapture:stopVideoCapture(capture.id)
  return true
 end
 lib.callback.register('crimson_doj:stopOwnBodycam',function(source)
  local player=exports.qbx_core:GetPlayer(source)
  local capture=player and captures[player.PlayerData.citizenid]
  if not capture or not capture.id then return {ok=false,error='No active bodycam capture'} end
  local ok=pcall(function()exports.screencapture:stopVideoCapture(capture.id)end)
  return ok and {ok=true} or {ok=false,error='Capture provider unavailable'}
 end)
 function api.playRecording(a,payload)
  if a.department=='business' then reject('Recording permission required') end
  local id=integer(payload.id,1,2147483647)
  local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind='recording'",{id,a.scope})
  if not row then reject('Recording not found') end
  local details=decode(row.details)
  if details.storage~='local' then reject('This entry is a URL reference, not a stored bodycam clip') end
  local result=mediaCall('streamStored',a.source,details.filename,Config.Bodycam.maxBytes)
  if not result.ok then reject(result.error) end
  h.log(a,'recording_play',id)
  return {ticket=result.ticket}
 end
 function api.deleteRecording(a,payload)
  if not CrimsonModulePermission(a,'recording',3,a.manage) or a.department=='business' then reject('Recording delete permission required') end
  local id=integer(payload.id,1,2147483647)
  local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind='recording'",{id,a.scope})
  if not row then reject('Recording not found') end
  local details=decode(row.details)
  if details.storage~='local' then reject('No stored clip to remove') end
  local result=mediaCall('deleteStored',details.filename)
  if not result.ok then reject(result.error) end
  details.storage='deleted' details.filename=nil
  MySQL.update.await("UPDATE crimson_mdt_entries SET details=?,status='archived',updated_by=?,version=version+1 WHERE id=?",{json.encode(details),a.p.citizenid,id})
  h.log(a,'recording_delete',id)
  return true
 end
 RegisterNetEvent('crimson_doj:cancelVideo',function(ticket)
  if type(ticket)=='string' and #ticket<=64 then exports[GetCurrentResourceName()]:cancelStream(source,ticket) end
 end)
 AddEventHandler('playerDropped',function()
  paymentRates[source]=nil
  for _,capture in pairs(captures)do if capture.source==source and capture.id then pcall(function()exports.screencapture:stopVideoCapture(capture.id)end) end end
 end)
 AddEventHandler('onResourceStop',function(resource)
  if resource==GetCurrentResourceName() then for _,capture in pairs(captures)do if capture.id then pcall(function()exports.screencapture:stopVideoCapture(capture.id)end) end end end
 end)
 return api
end
