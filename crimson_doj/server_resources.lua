function CrimsonResources(h,e)
 local r={actions={}};local a=r.actions
 local reject,integer,decode=h.reject,h.integer,h.decode
 local allow,legal,text=e.allow,e.legal,e.text
 local locks={};local removal={}
 local function uuid()return MySQL.scalar.await('SELECT UUID()')or reject('Could not allocate operation')end
 local function inv()if Config.Integrations.inventory~='ox_inventory'or GetResourceState('ox_inventory')~='started'then reject('ox_inventory unavailable')end end
 local function near(src,coords,radius)
  local ped=GetPlayerPed(src);if not ped or ped==0 then return false end
  local p=GetEntityCoords(ped)
  return (p.x-coords.x)^2+(p.y-coords.y)^2+(p.z-coords.z)^2<=radius^2
 end
 local function locked(key,fn)
  if locks[key]then reject('Operation already processing')end;locks[key]=true
  local ok,result=pcall(fn);locks[key]=nil;if not ok then error(result,0)end;return result
 end
 local function sameActor(actor)
  local current=h.identity(actor.source)
  if not current or not current.write or current.scope~=actor.scope or current.p.citizenid~=actor.p.citizenid or current.p.job.name~=actor.p.job.name then reject('Character, department or duty changed')end
 end
 local function station(actor)
  inv()
  if not actor.write then reject('Write permission required')end
  for _,p in ipairs(Config.Printers or {})do if p.jobs and p.jobs[actor.p.job.name]and near(actor.source,p.coords,p.radius or 2)then return end end
  reject('Go to your department printer/archive station')
 end
 local function heldCopy(src,slot)
  inv();slot=integer(slot,1,1000)
  local item=slot and exports.ox_inventory:GetSlot(src,slot)
  if not item or item.name~=Config.Printing.item or not item.metadata then reject('Printed document not held')end
  local id=tonumber(item.metadata.print_id);local ticket=item.metadata.print_ticket
  if not id or type(ticket)~='string'then reject('Invalid printed copy')end
  local copy=MySQL.single.await('SELECT snapshot,record_id FROM crimson_mdt_prints WHERE id=? AND ticket=?',{id,ticket})
  if not copy then reject('Printed copy missing')end
  return item,id,ticket,decode(copy.snapshot),copy.record_id
 end
 function a.archiveInventory(actor)
  station(actor)
  local rows={}
  for _,item in pairs(exports.ox_inventory:Search(actor.source,'slots',Config.Printing.item)or {})do
   rows[#rows+1]={slot=item.slot,label=item.metadata and item.metadata.label or 'Document'}
  end
  return rows
 end
 function a.archiveDocuments(actor)
  if not CrimsonManagement(actor)then reject('Management permission required')end
  return MySQL.query.await([[SELECT p.print_id,p.title,p.deposited_by,p.created_at FROM crimson_mdt_archived_prints p WHERE p.scope=? AND p.state='archived' ORDER BY p.print_id DESC LIMIT 200]],{actor.scope})
 end
 function a.archiveDeposit(actor,p)
  station(actor)
  return locked('archive:'..actor.scope,function()
   local item,id,ticket,snapshot,recordId=heldCopy(actor.source,p.slot)
   local base=MySQL.single.await('SELECT scope FROM crimson_mdt_entries WHERE id=?',{recordId})
   if not base or base.scope~=actor.scope then reject('Copy belongs to another department')end
   local changed=MySQL.update.await("INSERT IGNORE INTO crimson_mdt_archived_prints(print_id,scope,ticket,title,deposited_by,state) VALUES(?,?,?,?,?,'depositing')",{id,actor.scope,ticket,snapshot.title or 'Document',actor.p.citizenid})
   if changed~=1 then reject('Copy already archived or pending review')end
   sameActor(actor)
   local removed=exports.ox_inventory:RemoveItem(actor.source,Config.Printing.item,1,item.metadata,p.slot)
   if not removed then MySQL.update.await('DELETE FROM crimson_mdt_archived_prints WHERE print_id=? AND state=?',{id,'depositing'});reject('Inventory rejected deposit')end
   MySQL.update.await("UPDATE crimson_mdt_archived_prints SET state='archived' WHERE print_id=?",{id})
   h.log(actor,'archive_deposit',recordId);return true
  end)
 end
 function a.archiveRetrieve(actor,p)
  station(actor);if not CrimsonManagement(actor)then reject('Management permission required')end
  return locked('archive:'..actor.scope,function()
   local id=integer(p.id,1,2147483647)
   local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_archived_prints WHERE print_id=? AND scope=? AND state='archived'",{id,actor.scope})
   if not row then reject('Archived copy not available')end
   local claimed=MySQL.update.await("UPDATE crimson_mdt_archived_prints SET state='retrieving' WHERE print_id=? AND state='archived'",{id})
   if claimed~=1 then reject('Copy already being retrieved')end
   sameActor(actor)
   local added=exports.ox_inventory:AddItem(actor.source,Config.Printing.item,1,{print_id=id,print_ticket=row.ticket,label=row.title})
   if not added then MySQL.update.await("UPDATE crimson_mdt_archived_prints SET state='archived' WHERE print_id=?",{id});reject('Inventory rejected retrieval')end
   MySQL.update.await('DELETE FROM crimson_mdt_archived_prints WHERE print_id=?',{id})
   h.log(actor,'archive_retrieve',nil);return true
  end)
 end
 lib.callback.register('crimson_doj:signPrinted',function(src,slot)
  local ok,result=pcall(function()
   local player=exports.qbx_core:GetPlayer(src);if not player then reject('Character unavailable')end
   local cid=player.PlayerData.citizenid
   local _,id,_,snapshot=heldCopy(src,slot)
   local allowed=false;for _,signer in ipairs(snapshot.signers or {})do if signer==cid then allowed=true end end
   if not allowed then reject('Your character is not a designated signer')end
   local current=exports.qbx_core:GetPlayer(src)
   if not current or current.PlayerData.citizenid~=cid then reject('Character changed')end
   local _,stillId=heldCopy(src,slot)
   if stillId~=id then reject('Held document changed')end
   local c=current.PlayerData.charinfo or {}
   local changed=MySQL.update.await('INSERT IGNORE INTO crimson_mdt_signatures(print_id,signer,signer_name) VALUES(?,?,?)',{id,cid,(c.firstname or '')..' '..(c.lastname or '')})
   if changed~=1 then reject('This character already signed this copy')end
   return true
  end)
  return ok and {ok=true,data=result}or {ok=false,error=tostring(result):match('CRIMSON_VALIDATION:(.*)')or 'Signature unavailable'}
 end)
 local function armory(actor)
  legal(actor);inv()
  if not CrimsonManagement(actor)or not actor.write then reject('Armory permission required')end
  local cfg=Config.Armory[actor.p.job.name]
  if not cfg or not cfg.coords or not near(actor.source,cfg.coords,cfg.radius or 3)then reject('Go to your armory')end
  return cfg
 end
 local function catalog(name)
  for _,item in ipairs(Config.ArmoryCatalog or {})do if item.name==name then return item end end
  reject('Item is not in the armory catalog')
 end
 function a.armoryCatalog(actor)
  armory(actor)
  return {items=Config.ArmoryCatalog,stock=MySQL.query.await('SELECT item,amount FROM crimson_mdt_armory_stock WHERE job=?',{actor.p.job.name}),kits=MySQL.query.await("SELECT entity_id,data,version FROM crimson_mdt_entities WHERE scope=? AND kind='kit' ORDER BY updated_at DESC LIMIT 50",{'kits:'..actor.p.job.name..':'..actor.p.citizenid})}
 end
 function a.armoryStockAdjust(actor,p)
  armory(actor);if not actor.manage then reject('Armory management permission required')end
  catalog(p.item);local n=integer(p.amount,1,10000);if not n then reject('Enter bounded replenishment quantity')end
  MySQL.update.await('INSERT INTO crimson_mdt_armory_stock(job,item,amount) VALUES(?,?,?) ON DUPLICATE KEY UPDATE amount=amount+VALUES(amount)',{actor.p.job.name,p.item,n})
  h.log(actor,'armory_stock_add',nil);return true
 end
 function a.saveArmoryKit(actor,p)
  armory(actor)
  if type(p.items)~='table'or #p.items<1 or #p.items>20 then reject('Select 1–20 catalog items')end
  local items={};local seen={}
  for _,it in ipairs(p.items)do
   local c=catalog(it.name);local n=integer(it.count,1,50)
   if not n or actor.grade<(c.grade or 0)or seen[it.name]then reject('Invalid kit items')end
   seen[it.name]=true;items[#items+1]={name=it.name,count=n}
  end
  local label=text(p.label,100);if label==''then reject('Kit name required')end
  local key=p.id and text(p.id,80)or uuid()
  return e.put(actor,'kits:'..actor.p.job.name..':'..actor.p.citizenid,'kit',key,{label=label,items=items},p.id and p.version or 0)
 end
 function a.deleteArmoryKit(actor,p)
  armory(actor)
  local key=text(p.id,80);local version=integer(p.version,1,2147483647)
  if not version then reject('Reload kit before deletion')end
  local changed=MySQL.update.await("DELETE FROM crimson_mdt_entities WHERE scope=? AND kind='kit' AND entity_id=? AND version=?",{'kits:'..actor.p.job.name..':'..actor.p.citizenid,key,version})
  if changed~=1 then reject('Kit changed or is not yours')end
  h.log(actor,'armory_kit_delete',nil);return true
 end
 function a.armoryOrder(actor,p)
  armory(actor)
  if type(p.items)~='table'or #p.items<1 or #p.items>20 then reject('Select 1–20 catalog items')end
  return locked('stock:'..actor.p.job.name,function()
   local items={};local seen={}
   for _,it in ipairs(p.items)do
    local c=catalog(it.name);local n=integer(it.count,1,50)
    if not n or actor.grade<(c.grade or 0)or seen[it.name]then reject('Invalid catalog quantity or grade')end
    seen[it.name]=true;items[#items+1]={name=it.name,count=n}
   end
   local pending=tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM crimson_mdt_armory_loans WHERE job=? AND state IN ('reserving','reserved','issuing','returning')",{actor.p.job.name}))or 0
   if pending>0 then reject('Armory has interrupted operations; administrator reconciliation required')end
   local ticket=uuid()
   local reserved={}
   for _,it in ipairs(items)do
    MySQL.insert.await("INSERT INTO crimson_mdt_armory_loans(ticket,item,citizenid,job,remaining,state) VALUES(?,?,?,?,?,'reserving')",{ticket,it.name,actor.p.citizenid,actor.p.job.name,it.count})
    local changed=MySQL.update.await('UPDATE crimson_mdt_armory_stock SET amount=amount-? WHERE job=? AND item=? AND amount>=?',{it.count,actor.p.job.name,it.name,it.count})
    if changed~=1 then
     MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='rejected',remaining=0 WHERE ticket=? AND item=?",{ticket,it.name})
     for _,old in ipairs(reserved)do
      MySQL.update.await('UPDATE crimson_mdt_armory_stock SET amount=amount+? WHERE job=? AND item=?',{old.count,actor.p.job.name,old.name})
      MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='rejected',remaining=0 WHERE ticket=? AND item=?",{ticket,old.name})
     end
     reject('Insufficient armory stock: '..it.name)
    end
    MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='reserved' WHERE ticket=? AND item=?",{ticket,it.name})
    reserved[#reserved+1]=it
   end
   local issued,rejected=0,0
   -- A journal row precedes each inventory effect. Interrupted states are not replayed.
   for _,it in ipairs(items)do
    MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='issuing' WHERE ticket=? AND item=?",{ticket,it.name})
    sameActor(actor)
    local meta={crimson_issue=ticket,crimson_owner=actor.p.citizenid,crimson_job=actor.p.job.name}
    local added=exports.ox_inventory:AddItem(actor.source,it.name,it.count,meta)
    if not added then
     rejected=rejected+1
     MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='rejected',remaining=0 WHERE ticket=? AND item=?",{ticket,it.name})
     MySQL.update.await('UPDATE crimson_mdt_armory_stock SET amount=amount+? WHERE job=? AND item=?',{it.count,actor.p.job.name,it.name})
     -- Other confirmed issued lines remain real loans; no duplicate refund is guessed.
    else
     issued=issued+1
     MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='active' WHERE ticket=? AND item=?",{ticket,it.name})
    end
   end
   h.log(actor,'armory_order',nil)
   if issued==0 then reject('Inventory rejected equipment; confirmed reservations refunded')end
   return {issued=issued,rejected=rejected}
  end)
 end
 function a.armoryReturns(actor)
  armory(actor)
  local rows={}
  for _,item in pairs(exports.ox_inventory:GetInventoryItems(actor.source)or {})do
   local m=item.metadata
   if m and m.crimson_owner==actor.p.citizenid and m.crimson_job==actor.p.job.name and m.crimson_issue then rows[#rows+1]={slot=item.slot,name=item.name,count=item.count}end
  end
  return rows
 end
 function a.armoryReturn(actor,p)
  armory(actor)
  return locked('stock:'..actor.p.job.name,function()
   local slot=integer(p.slot,1,1000);local item=slot and exports.ox_inventory:GetSlot(actor.source,slot)
   local m=item and item.metadata
   if not m or m.crimson_owner~=actor.p.citizenid or m.crimson_job~=actor.p.job.name then reject('Not your issued department equipment')end
   local loan=MySQL.single.await("SELECT * FROM crimson_mdt_armory_loans WHERE ticket=? AND item=? AND citizenid=? AND job=? AND state='active'",{m.crimson_issue,item.name,actor.p.citizenid,actor.p.job.name})
   if not loan then reject('Issuance not registered')end
   local n=math.min(item.count,tonumber(loan.remaining)or 0);if n<1 then reject('No returnable quantity')end
   MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='returning' WHERE ticket=? AND item=?",{m.crimson_issue,item.name})
   sameActor(actor)
   if not exports.ox_inventory:RemoveItem(actor.source,item.name,n,m,slot)then
    MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state='active' WHERE ticket=? AND item=?",{m.crimson_issue,item.name});reject('Inventory rejected return')
   end
   local ok=MySQL.transaction.await({
    {query='UPDATE crimson_mdt_armory_stock SET amount=amount+? WHERE job=? AND item=?',values={n,actor.p.job.name,item.name}},
    {query="UPDATE crimson_mdt_armory_loans SET state=IF(remaining-?>0,'active','returned'),remaining=remaining-? WHERE ticket=? AND item=?",values={n,n,m.crimson_issue,item.name}}
   })
   if not ok then reject('Return accounting needs administrator review; do not retry')end
   h.log(actor,'armory_return',nil);return true
  end)
 end
 local function tracker(actor)
  legal(actor)
  if not Config.Tracking.enabled or actor.grade<(Config.Tracking.grade or 5)then reject('Tracking permission required')end
 end
 local function target(actor,source)
  source=integer(source,1,65535)
  local p=source and exports.qbx_core:GetPlayer(source)
  if not p or source==actor.source or GetPlayerRoutingBucket(source)~=GetPlayerRoutingBucket(actor.source)then reject('Select another nearby player')end
  local ped=GetPlayerPed(source);if not ped or ped==0 then reject('Target unavailable')end
  if not near(actor.source,GetEntityCoords(ped),3)then reject('Target must be within 3 metres')end
  return p
 end
 function a.trackingApply(actor,p)
  tracker(actor);inv()
  local other=target(actor,p.source);local cid=other.PlayerData.citizenid
  local record=e.row(actor,{id=p.caseId},{case=true,incident=true})
  if record.subject~=cid then reject('Case subject must match target')end
  return locked('tracking:'..cid,function()
   local existing=MySQL.single.await('SELECT active FROM crimson_mdt_tracking WHERE citizenid=?',{cid})
   if existing and (tonumber(existing.active)or 0)>0 then reject('Band already active or pending review')end
   sameActor(actor)
   local currentTarget=target(actor,p.source)
   if currentTarget.PlayerData.citizenid~=cid then reject('Target character changed')end
   local changed=MySQL.update.await([[INSERT INTO crimson_mdt_tracking(citizenid,scope,applied_by,case_id,active) VALUES(?,?,?,?,2) ON DUPLICATE KEY UPDATE scope=VALUES(scope),applied_by=VALUES(applied_by),case_id=VALUES(case_id),active=2]],{cid,actor.scope,actor.p.citizenid,record.id})
   if type(changed)~='number'or changed<1 then reject('Tracking registration failed')end
   if not exports.ox_inventory:RemoveItem(actor.source,Config.Tracking.item,1)then
    MySQL.update.await('UPDATE crimson_mdt_tracking SET active=0 WHERE citizenid=? AND active=2',{cid});reject('Tracking band item required')
   end
   MySQL.update.await('UPDATE crimson_mdt_tracking SET active=1 WHERE citizenid=? AND active=2',{cid})
   TriggerClientEvent('ox_lib:notify',other.PlayerData.source,{description='A justice tracking band was attached',type='inform'})
   h.log(actor,'tracking_apply',record.id);return true
  end)
 end
 function a.trackingTargets(actor)
  tracker(actor)
  local rows=MySQL.query.await('SELECT citizenid,case_id,created_at FROM crimson_mdt_tracking WHERE scope=? AND active=1 LIMIT 100',{actor.scope})
  for _,row in ipairs(rows)do row.online=exports.qbx_core:GetPlayerByCitizenId(row.citizenid)~=nil end
  return rows
 end
 function a.trackingLocate(actor,p)
  tracker(actor)
  local cid=text(p.citizenid,64)
  local row=MySQL.single.await('SELECT citizenid FROM crimson_mdt_tracking WHERE citizenid=? AND scope=? AND active=1',{cid,actor.scope})
  local other=row and exports.qbx_core:GetPlayerByCitizenId(cid)
  if not other or GetPlayerRoutingBucket(actor.source)~=GetPlayerRoutingBucket(other.PlayerData.source)then reject('Tracked target is not available in this routing bucket')end
  local ped=GetPlayerPed(other.PlayerData.source);if not ped or ped==0 then reject('Tracked player entity unavailable')end
  local c=GetEntityCoords(ped);return {x=c.x,y=c.y,z=c.z}
 end
 function a.trackingRemove(actor,p)
  tracker(actor);local other=target(actor,p.source)
  MySQL.update.await('UPDATE crimson_mdt_tracking SET active=0 WHERE citizenid=? AND scope=?',{other.PlayerData.citizenid,actor.scope})
  h.log(actor,'tracking_remove',nil);return true
 end
 lib.callback.register('crimson_doj:beginBandRemoval',function(src)
  local p=exports.qbx_core:GetPlayer(src)
  if not p or not Config.Tracking.enabled then return {ok=false,error='Unavailable'}end
  local cid=p.PlayerData.citizenid
  local row=MySQL.single.await('SELECT citizenid FROM crimson_mdt_tracking WHERE citizenid=? AND active=1',{cid})
  if not row then return {ok=false,error='No active tracking band'}end
  if (exports.ox_inventory:GetItemCount(src,Config.Tracking.tool)or 0)<1 then return {ok=false,error='Electronic kit required'}end
  local actor=h.identity(src)
  if actor and actor.scope=='justice'and actor.grade>=(Config.Tracking.bypassGrade or 10)then
   MySQL.update.await('UPDATE crimson_mdt_tracking SET active=0 WHERE citizenid=?',{cid})
   return {ok=true,data={removed=true}}
  end
  local nonce=uuid();removal[cid]={nonce=nonce,start=GetGameTimer(),source=src}
  return {ok=true,data={nonce=nonce}}
 end)
 lib.callback.register('crimson_doj:finishBandRemoval',function(src,nonce,success)
  local p=exports.qbx_core:GetPlayer(src);local cid=p and p.PlayerData.citizenid;local pending=cid and removal[cid]
  if not pending or pending.source~=src or pending.nonce~=nonce then return {ok=false,error='Removal challenge expired'}end
  removal[cid]=nil
  local elapsed=GetGameTimer()-pending.start
  if success~=true or elapsed<3000 or elapsed>60000 then return {ok=false,error='Tracking removal failed'}end
  if not exports.ox_inventory:RemoveItem(src,Config.Tracking.tool,1)then return {ok=false,error='Electronic kit required'}end
  MySQL.update.await('UPDATE crimson_mdt_tracking SET active=0 WHERE citizenid=?',{cid})
  return {ok=true}
 end)
 function a.dispatchRespond(actor,p)
  if actor.department=='business' then reject('Department required')end
  local row=e.row(actor,p,{dispatch=true});if row.status~='open'then reject('Dispatch call closed')end
  if not ({responding=true,arrived=true,clear=true})[p.status]then reject('Invalid response status')end
  local key=tostring(row.id)..':'..actor.p.citizenid
  local old=e.get(actor.scope,'response',key)
  return e.put(actor,actor.scope,'response',key,{call=row.id,citizenid=actor.p.citizenid,name=(actor.p.charinfo and actor.p.charinfo.firstname or '')..' '..(actor.p.charinfo and actor.p.charinfo.lastname or ''),status=p.status},old.version)
 end
 function a.dispatchUnits(actor,p)
  e.row(actor,p,{dispatch=true})
  local rows=MySQL.query.await("SELECT data FROM crimson_mdt_entities WHERE scope=? AND kind='response' AND JSON_EXTRACT(data,'$.call')=? ORDER BY updated_at DESC LIMIT 100",{actor.scope,p.id})
  for _,row in ipairs(rows)do row.data=decode(row.data)end;return rows
 end
 local function createDispatch(resource,data)
  if h.ready and not h.ready()then return false,'Database not ready'end
  if not Config.DispatchSources[resource] then return false,'Resource not allowlisted'end
  if type(data)~='table'or type(data.coords)~='table'then return false,'Invalid payload'end
  local scope=data.scope=='medical' and 'medical'or 'justice'
  local c={}
  for _,k in ipairs({'x','y','z'})do local n=tonumber(data.coords[k]);if not n or n~=n or math.abs(n)>20000 then return false,'Invalid coordinates'end;c[k]=n end
  local id=MySQL.insert.await("INSERT INTO crimson_mdt_entries(scope,kind,subject,title,body,details,owner,updated_by) VALUES(?,'dispatch','',?,?,?,?,?)",{scope,text(data.title,160),text(data.body,2000),json.encode({coords=c,priority=({normal=true,high=true,critical=true})[data.priority]and data.priority or 'normal',origin=resource}),'integration','integration'})
  return id
 end
 exports('CreateDispatch',function(data)return createDispatch(GetInvokingResource(),data)end)
 local shots={}
 RegisterNetEvent('crimson_doj:gunshots',function()
  if not Config.AutomaticGunshots or(h.ready and not h.ready())then return end
  local src=source;local now=GetGameTimer()
  if shots[src] and now-shots[src]<30000 then return end;shots[src]=now
  local player=exports.qbx_core:GetPlayer(src);if not player then return end
  if player.PlayerData.job and player.PlayerData.job.onduty and ({police=true,sheriff=true,doj=true})[player.PlayerData.job.name]then return end
  local ped=GetPlayerPed(src);if not ped or ped==0 then return end
  local c=GetEntityCoords(ped)
  MySQL.insert.await("INSERT INTO crimson_mdt_entries(scope,kind,subject,title,body,details,owner,updated_by) VALUES('justice','dispatch','','Gunshots reported','Automatic client shooting sensor; location captured server-side',?,'sensor','sensor')",{json.encode({coords={x=c.x,y=c.y,z=c.z},priority='high',origin='gunshot-sensor'})})
 end)
 RegisterCommand('crimsonreview',function(source)
  if source~=0 then return end
  print('[Crimson pending armory] '..json.encode(MySQL.query.await("SELECT ticket,item,citizenid,job,remaining,state FROM crimson_mdt_armory_loans WHERE state IN ('reserving','reserved','issuing','returning') LIMIT 100")))
  print('[Crimson pending archive] '..json.encode(MySQL.query.await("SELECT print_id,scope,state FROM crimson_mdt_archived_prints WHERE state IN ('depositing','retrieving') LIMIT 100")))
  print('[Crimson pending tracking] '..json.encode(MySQL.query.await('SELECT citizenid,case_id FROM crimson_mdt_tracking WHERE active=2 LIMIT 100')))
 end,true)
 RegisterCommand('crimsonresolveitem',function(source,args)
  if source~=0 then return end
  local kind,key,state=args[1],args[2],args[3]
  if not kind or not key or not state then print('Use only after reconciliation: crimsonresolveitem <armory|archive|tracking> <key> <state> [item] [remaining]');return end
  if kind=='armory'and ({active=true,returned=true,rejected=true})[state]then
   local remaining=tonumber(args[5]);if not integer(remaining,0,1000)or not args[4]then return end
   MySQL.update.await("UPDATE crimson_mdt_armory_loans SET state=?,remaining=? WHERE ticket=? AND item=? AND state IN ('reserving','reserved','issuing','returning')",{state,remaining,key,args[4]})
  elseif kind=='archive'and state=='archived'then
   MySQL.update.await("UPDATE crimson_mdt_archived_prints SET state='archived' WHERE print_id=? AND state IN ('depositing','retrieving')",{tonumber(key)})
  elseif kind=='archive'and state=='retrieved'then
   MySQL.update.await("DELETE FROM crimson_mdt_archived_prints WHERE print_id=? AND state IN ('depositing','retrieving')",{tonumber(key)})
  elseif kind=='tracking'and ({active=true,removed=true})[state]then
   MySQL.update.await('UPDATE crimson_mdt_tracking SET active=? WHERE citizenid=? AND active=2',{state=='active'and 1 or 0,key})
  else return end
  print('[Crimson] Pending item metadata resolved by console; no items or money moved')
 end,true)
 return r
end
