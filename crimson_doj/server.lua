local ready, rates, locks, unitStatus, kitCooldown, unitGPS = false, {}, {}, {}, {}, {}
local printCooldown = {}
local definition = {
 case={police=true,doj=true,subject=true},
 warrant={police=true,doj=true,subject=true,management=true},
 incident={police=true,doj=true,subject=true},
 medical={ems=true,subject=true},
 document={police=true,doj=true,ems=true,business=true},
 note={police=true,doj=true,ems=true,business=true,private=true},
 vehicle_flag={police=true,doj=true},
 weapon={police=true,doj=true},
 business_license={doj=true,management=true},
 business_note={doj=true},
 product={business=true,management=true},
 invoice={business=true},
 dispatch={police=true,ems=true},
 recording={police=true,doj=true,ems=true},
}
local function reject(message) error('CRIMSON_VALIDATION:'..message,0) end
local function fail(message) return {ok=false,error=message} end
local function clean(value, limit, required)
 if type(value)~='string' or #value>limit or value:find('%z') then return end
 value=value:match('^%s*(.-)%s*$')
 if required and value=='' then return end
 return value
end
local function integer(value,lo,hi)
 if type(value)~='number' or value~=value or value%1~=0 or value<lo or value>hi then return end
 return value
end
local function decode(value)
 local ok,data=pcall(json.decode,value or '{}')
 return ok and type(data)=='table' and data or {}
end
local function identity(source, allowOffDuty)
 local player=exports.qbx_core:GetPlayer(source)
 local p=player and player.PlayerData
 local policy=p and p.job and Config.Jobs[p.job.name]
 if not policy or type(p.citizenid)~='string' then return end
 if Config.MDTJobs and not Config.MDTJobs[p.job.name] then return end
 if Config.RequireDuty and not p.job.onduty and not allowOffDuty then return end
 local grade=type(p.job.grade)=='table' and tonumber(p.job.grade.level) or tonumber(p.job.grade)
 if not grade or grade<policy.read then return end
 local department=policy.department
 local scope=(department=='police' or department=='doj') and 'justice' or department=='ems' and 'medical' or 'business:'..p.job.name
 local rank=department=='doj' and Config.DojGrades and Config.DojGrades[tostring(grade)]
 if department=='doj' and Config.DojGrades and not rank then return end
 local perms=rank and rank.permissions
 return {p=p,policy=policy,grade=grade,scope=scope,department=department,
  permissions=perms,gradeLabel=rank and rank.label,
  write=perms and (perms.reports_create or perms.profiles_edit or perms.warrants_create or perms.vehicles_edit or perms.business_manage)==true or (not perms and grade>=policy.write),
  manage=perms and (perms.code_change or perms.business_manage)==true or (not perms and grade>=policy.manage),source=source}
end
local function person(cid)
 return MySQL.single.await('SELECT citizenid,charinfo FROM players WHERE citizenid=? LIMIT 1',{cid})
end
local function publicPerson(row)
 local c=decode(row.charinfo)
 return {citizenid=row.citizenid,firstname=c.firstname or '',lastname=c.lastname or '',birthdate=c.birthdate or '',nationality=c.nationality or ''}
end
local function citizenBank(a,cid)
 if not CrimsonPermission(a,'profiles_view',a.manage) or (a.department~='doj' and a.department~='police') then return nil end
 local online=exports.qbx_core:GetPlayerByCitizenId(cid)
 local value,source
 if online then
  value=online.PlayerData.money and online.PlayerData.money.bank
  source='live'
 else
  local saved=MySQL.single.await('SELECT money FROM players WHERE citizenid=? LIMIT 1',{cid})
  local money=saved and (type(saved.money)=='table' and saved.money or decode(saved.money))
  value=money and money.bank
  source='saved'
 end
 local balance=tonumber(value)
 local available=balance~=nil and balance==balance and balance~=math.huge and balance~=-math.huge
 return {available=available,balance=available and balance or nil,source=source}
end
local function actorName(p)
 return ((p.charinfo and p.charinfo.firstname or '')..' '..(p.charinfo and p.charinfo.lastname or ''))
end
local function log(a,action,id)
 MySQL.insert.await('INSERT INTO crimson_mdt_audit(scope,actor,action,record_id) VALUES(?,?,?,?)',{a.scope,a.p.citizenid,action,id})
end
local function visible(a,kind)
 return definition[kind] and definition[kind][a.department] == true and CrimsonModulePermission(a,kind,1,true)
end
local function moduleList(a)
 local out={}
 for kind,d in pairs(definition) do
  if visible(a,kind) then out[kind]={write=CrimsonModulePermission(a,kind,2,a.write and (not d.management or a.manage)),status=CrimsonModulePermission(a,kind,3,a.manage),subject=d.subject or false,private=d.private or false} end
 end
 return out
end
local function unpackRow(row)
 row.details=decode(row.details)
 return row
end
local function listing(a,kind,q,page,subject,archived)
 local d=definition[kind]
 if not d or not visible(a,kind) then reject('Module access denied') end
 local params={a.scope,kind}
 local where='scope=? AND kind=?'
 if archived then where=where.." AND status IN ('closed','revoked','archived')" end
 if d.private then where=where..' AND owner=?' params[#params+1]=a.p.citizenid end
 if subject then where=where..' AND subject=?' params[#params+1]=subject end
 if q~='' then where=where..' AND (LOCATE(LOWER(?),LOWER(title))>0 OR LOCATE(LOWER(?),LOWER(subject))>0)' params[#params+1]=q params[#params+1]=q end
 local total=MySQL.scalar.await('SELECT COUNT(*) FROM crimson_mdt_entries WHERE '..where,params)
 params[#params+1]=(page-1)*30
 local rows=MySQL.query.await('SELECT * FROM crimson_mdt_entries WHERE '..where..' ORDER BY id DESC LIMIT 30 OFFSET ?',params)
 for _,row in ipairs(rows) do unpackRow(row) end
 return {rows=rows,total=total,page=page}
end
local function allowedDetails(a,kind,payload,old)
 local details={}
 if old then
  local previous=decode(old.details)
  for _,key in ipairs({'payment','finePayment','paidAmount','paymentReason'})do details[key]=previous[key] end
 end
 local fields={
 case={'evidence','charges'}, warrant={'reason','expires'},incident={'charges','evidence'},medical={'diagnosis','treatment','allergies'},
 document={'category','imageUrl'},vehicle_flag={'reason'},weapon={'serial','model'},business_license={'licenseType','expires'},business_note={},
 product={'category'},invoice={},note={},dispatch={'priority','location'},recording={'url'},
 }
 local input=payload.details
 if type(input)~='table' then input={} end
 for _,key in ipairs(fields[kind] or {}) do
  if input[key]~=nil then
   details[key]=clean(input[key],key=='evidence' and 4000 or 1000,false)
   if not details[key] then reject('Invalid '..key) end
  end
 end
 if kind=='document' and details.imageUrl and details.imageUrl~='' and not CrimsonDocumentImage(details.imageUrl) then reject('Document image must be an allowed HTTPS JPG/PNG/WebP URL') end
 if details.expires and details.expires~='' and not details.expires:match('^%d%d%d%d%-%d%d%-%d%d$') then reject('Expiry must use YYYY-MM-DD') end
 if kind=='recording' and old and decode(old.details).storage=='local' then return decode(old.details) end
 if kind=='recording' and details.url and details.url~='' and not details.url:match('^https://') then reject('Recording URL must use HTTPS') end
 if kind=='product' then
  details.price=integer(input.price,0,1000000)
  if not details.price then reject('Price must be an integer between 0 and 1000000') end
 end
 if kind=='invoice' then
  if old then return decode(old.details) end
  local productId=integer(input.productId,1,2147483647)
  local quantity=integer(input.quantity,1,100)
  if not productId or not quantity then reject('Select a catalog item and quantity') end
  local product=MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind='product' AND status='open'",{productId,a.scope})
  if not product then reject('Catalog item unavailable') end
  local price=decode(product.details).price
  if not integer(price,0,1000000) then reject('Invalid catalog price') end
  if Config.Payments and price*quantity>Config.Payments.maxAmount then reject('Invoice total exceeds the configured payment limit') end
  details={productId=productId,product=product.title,quantity=quantity,price=price,total=price*quantity,payment='unpaid'}
 end
 if kind=='dispatch' then
  if old then
   local previous=decode(old.details)
   details.coords=previous.coords
  else
   local ped=GetPlayerPed(a.source)
   if not ped or ped==0 then reject('Player coordinates unavailable') end
   local c=GetEntityCoords(ped)
   details.coords={x=c.x,y=c.y,z=c.z}
  end
 end
 return details
end
local function employeeRows(a)
 local rows=MySQL.query.await([[SELECT p.citizenid,p.charinfo,g.grade FROM player_groups g JOIN players p ON p.citizenid=g.citizenid WHERE g.type='job' AND g.`group`=? ORDER BY g.grade DESC,p.citizenid LIMIT 200]],{a.p.job.name})
 for _,row in ipairs(rows) do
  local p=publicPerson(row) row.firstname=p.firstname row.lastname=p.lastname row.charinfo=nil
  local online=exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
  row.online=online~=nil
  row.duty=online and online.PlayerData.job.name==a.p.job.name and online.PlayerData.job.onduty or false
 end
 return rows
end
local services=assert(CrimsonServices,'server_extras.lua must load before server.lua')({
 identity=identity,reject=reject,clean=clean,integer=integer,decode=decode,person=person,log=log,
 ready=function()return ready end,
})
local function run(a,action,payload)
 if ({paymentStatus=true,businessFinance=true,bankAccount=true,offerInvoice=true,fine=true,jail=true,release=true,bodycamStart=true,bodycamStop=true,playRecording=true,deleteRecording=true})[action] then return services[action](a,payload) end
 local managementActions={employees=true,employee=true,roster=true,shareGPS=true,unitWaypoint=true,unitStatus=true,penalcode=true,audit=true,equipment=true,camera=true,armory=true}
 if managementActions[action] and not CrimsonManagement(a) then reject('Management requires DOJ grade 10 or higher') end
 local actionPermissions={bootstrap='dashboard_view',search='profiles_view',profile='profiles_view',employees='employees_view',employee='employees_manage',vehicles='vehicles_view',businesses='business_view',threat='code_change'}
 local needed=actionPermissions[action]
 if needed and not CrimsonPermission(a,needed,true) then reject('Permission required: '..needed) end
 if action=='bootstrap' then
  if Config.RequireDuty and not a.p.job.onduty then
   return {citizenid=a.p.citizenid,name=actorName(a.p),job=a.p.job.name,label=a.policy.label,department=a.department,grade=a.grade,canWrite=a.write,canManage=a.manage,management=CrimsonManagement(a),canIssueBadge=a.department=='doj' and a.grade>=(Config.BadgeChiefMinGrade or 13),permissions=a.permissions,gradeLabel=a.gradeLabel,onduty=false,modules=moduleList(a),counts={},recent={},threat='green',integrations=Config.Integrations}
  end
  local counts=MySQL.query.await("SELECT kind,status,COUNT(*) AS total FROM crimson_mdt_entries WHERE scope=? AND (kind<>'note' OR owner=?) GROUP BY kind,status",{a.scope,a.p.citizenid})
  local state=MySQL.scalar.await('SELECT threat FROM crimson_mdt_state WHERE scope=?',{a.scope}) or 'green'
  local recent=MySQL.query.await("SELECT id,kind,title,status,created_at FROM crimson_mdt_entries WHERE scope=? AND (kind<>'note' OR owner=?) ORDER BY id DESC LIMIT 8",{a.scope,a.p.citizenid})
  -- Filter even counts/activity by allowed module so EMS/business records cannot be inferred.
  local safeCounts,safeRecent={},{}
  for _,row in ipairs(counts) do if visible(a,row.kind) then safeCounts[#safeCounts+1]=row end end
  for _,row in ipairs(recent) do if visible(a,row.kind) then safeRecent[#safeRecent+1]=row end end
  return {citizenid=a.p.citizenid,name=actorName(a.p),job=a.p.job.name,label=a.policy.label,department=a.department,grade=a.grade,canWrite=a.write,canManage=a.manage,management=CrimsonManagement(a),canIssueBadge=a.department=='doj' and a.grade>=(Config.BadgeChiefMinGrade or 13),permissions=a.permissions,gradeLabel=a.gradeLabel,onduty=a.p.job.onduty,modules=moduleList(a),counts=safeCounts,recent=safeRecent,threat=state,integrations=Config.Integrations}
 elseif action=='duty' then
  if type(payload.enabled)~='boolean' then reject('Invalid duty state') end
  exports.qbx_core:SetJobDuty(a.source,payload.enabled)
  return {enabled=payload.enabled}
 elseif action=='threat' then
  if not CrimsonPermission(a,'code_change',a.manage) then reject('Management permission required') end
  if not ({green=true,yellow=true,red=true,black=true})[payload.value] then reject('Invalid security code') end
  MySQL.query.await('INSERT INTO crimson_mdt_state(scope,threat) VALUES(?,?) ON DUPLICATE KEY UPDATE threat=VALUES(threat)',{a.scope,payload.value})
  log(a,'threat_'..payload.value,nil) return true
 elseif action=='search' then
  local q=clean(payload.query,80,true)
  if not q or #q<2 then reject('Enter at least two characters') end
  local rows=MySQL.query.await([[SELECT citizenid,charinfo FROM players WHERE LOCATE(LOWER(?),LOWER(citizenid))>0 OR LOCATE(LOWER(?),LOWER(CONCAT(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo,'$.firstname')),''),' ',COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo,'$.lastname')),''))))>0 ORDER BY citizenid LIMIT 40]],{q,q})
  local out={} for _,row in ipairs(rows) do out[#out+1]=publicPerson(row) end
  log(a,'citizen_search',nil) return out
 elseif action=='profile' then
  local cid=clean(payload.citizenid,64,true)
  local row=cid and person(cid)
  if not row then reject('Citizen not found') end
  log(a,'profile_read',nil)
  local rows=MySQL.query.await("SELECT * FROM crimson_mdt_entries WHERE scope=? AND subject=? AND kind<>'note' ORDER BY id DESC LIMIT 200",{a.scope,cid})
  local out={} for _,item in ipairs(rows) do if visible(a,item.kind) then out[#out+1]=unpackRow(item) end end
  local financial=citizenBank(a,cid)
  if financial then log(a,'citizen_bank_read',nil) end
  return {person=publicPerson(row),records=out,financial=financial}
 elseif action=='list' then
  return listing(a,payload.kind,clean(payload.query or '',80,false) or '',integer(payload.page or 1,1,100000) or 1,nil,payload.archived==true)
 elseif action=='create' or action=='update' then
  if not a.write then reject('Write permission required') end
  local old,kind
  if action=='update' then
   local id=integer(payload.id,1,2147483647)
   old=id and MySQL.single.await('SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=?',{id,a.scope})
   if not old then reject('Record not found') end
   kind=old.kind
  else kind=payload.kind end
  local d=definition[kind]
  if not d or not visible(a,kind) then reject('Module access denied') end
  if not CrimsonModulePermission(a,kind,2,a.write and (not d.management or a.manage)) then reject('Record write permission required') end
  if d.private and old and old.owner~=a.p.citizenid then reject('Private note access denied') end
  local statusOnly=old and not a.manage and old.owner~=a.p.citizenid
  if statusOnly and not (payload.status~=old.status and CrimsonModulePermission(a,kind,3,false)) then reject('You can edit only your own records') end
  local title,body=clean(payload.title,160,true),clean(payload.body or '',Config.MaxText,false)
  local subject=old and old.subject or clean(payload.subject or '',80,false)
  if not title or not body or not subject then reject('Invalid fields or text too long') end
  if (d.subject or kind=='invoice') and not person(subject) then reject('Select an existing citizen ID') end
  if (kind=='business_license' or kind=='business_note') then
   local found=false for _,job in ipairs(Config.BusinessJobs) do if job==subject then found=true end end
   if not found then reject('Select a configured business job') end
  end
  local status=old and payload.status or 'open'
  if not ({open=true,closed=true,revoked=true,archived=true})[status] then reject('Invalid status') end
  if old and status~=old.status and not CrimsonModulePermission(a,kind,3,a.manage) then reject('Record status permission required') end
  local details
  if statusOnly then title=old.title body=old.body details=decode(old.details)
  else details=allowedDetails(a,kind,payload,old) end
  local id
  if old then
   local version=integer(payload.version,1,2147483647)
   if not version then reject('Reload the record before editing') end
   local changed=MySQL.update.await('UPDATE crimson_mdt_entries SET title=?,body=?,details=?,status=?,updated_by=?,version=version+1 WHERE id=? AND scope=? AND version=?',{title,body,json.encode(details),status,a.p.citizenid,old.id,a.scope,version})
   if changed~=1 then reject('Record changed. Reload before editing.') end
   id=old.id
  else
   id=MySQL.insert.await('INSERT INTO crimson_mdt_entries(scope,kind,subject,title,body,details,owner,updated_by) VALUES(?,?,?,?,?,?,?,?)',{a.scope,kind,subject,title,body,json.encode(details),a.p.citizenid,a.p.citizenid})
  end
  log(a,action..'_'..kind,id) return {id=id}
 elseif action=='audit' then
  if not a.manage then reject('Management permission required') end
  local page=integer(payload.page or 1,1,100000) or 1
  return {rows=MySQL.query.await('SELECT * FROM crimson_mdt_audit WHERE scope=? ORDER BY id DESC LIMIT 30 OFFSET ?',{a.scope,(page-1)*30}),page=page,total=MySQL.scalar.await('SELECT COUNT(*) FROM crimson_mdt_audit WHERE scope=?',{a.scope})}
 elseif action=='employees' then
  local grades=exports.qbx_core:GetJobs()[a.p.job.name].grades
  local safe={} for grade,g in pairs(grades) do safe[#safe+1]={level=grade,name=g.name} end
  return {rows=employeeRows(a),grades=safe}
 elseif action=='employee' then
  if not CrimsonPermission(a,'employees_manage',a.manage) then reject('Management permission required') end
  local cid=clean(payload.citizenid,64,true)
  if not cid or cid==a.p.citizenid then reject('Cannot manage yourself') end
  local jobs=exports.qbx_core:GetJobs()
  local old=MySQL.scalar.await("SELECT grade FROM player_groups WHERE citizenid=? AND type='job' AND `group`=?",{cid,a.p.job.name})
  if old and tonumber(old)>=a.grade then reject('Cannot manage an equal or higher grade') end
  if not person(cid) then reject('Citizen not found') end
  local ok,err
  if payload.operation=='remove' then
   if old==nil then reject('Not a member of your job') end
   ok,err=exports.qbx_core:RemovePlayerFromJob(cid,a.p.job.name)
  elseif payload.operation=='grade' then
   local grade=integer(payload.grade,0,999)
   if not grade or grade>=a.grade or not jobs[a.p.job.name].grades[grade] then reject('Select an existing grade below yours') end
   ok,err=exports.qbx_core:AddPlayerToJob(cid,a.p.job.name,grade)
  else reject('Invalid personnel action') end
  if not ok then reject('Qbox rejected personnel change: '..(type(err)=='table' and err.code or 'unknown')) end
  log(a,'employee_'..payload.operation,nil) return true
 elseif action=='roster' then
  if a.department=='business' then reject('Dispatch access denied') end
  local rows={}
  for _,id in ipairs(GetPlayers()) do
   local b=identity(tonumber(id))
   if b and b.scope==a.scope then
    rows[#rows+1]={id=tonumber(id),citizenid=b.p.citizenid,name=actorName(b.p),job=b.p.job.name,grade=b.grade,status=unitStatus[tonumber(id)] or 'available',gps=unitGPS[tonumber(id)]==true}
   end
  end
  return rows
 elseif action=='shareGPS' then
  if a.department=='business' then reject('GPS access denied') end
  if type(payload.enabled)~='boolean' then reject('Invalid GPS state') end
  unitGPS[a.source]=payload.enabled
  return true
 elseif action=='unitWaypoint' then
  if a.department=='business' then reject('GPS access denied') end
  local target=integer(payload.source,1,65535)
  local other=target and identity(target)
  if not other or other.scope~=a.scope or not unitGPS[target] then reject('Unit GPS unavailable or not shared') end
  local ped=GetPlayerPed(target)
  if not ped or ped==0 then reject('Unit position unavailable') end
  local c=GetEntityCoords(ped)
  return {x=c.x,y=c.y,z=c.z}
 elseif action=='unitStatus' then
  if a.department=='business' then reject('Unit access denied') end
  if not ({available=true,busy=true,responding=true,unavailable=true})[payload.value] then reject('Invalid status') end
  unitStatus[a.source]=payload.value return true
 elseif action=='vehicles' then
  if a.department~='police' and a.department~='doj' then reject('Vehicle access denied') end
  local q=clean(payload.query,24,true)
  if not q or #q<2 then reject('Enter at least two plate characters') end
  local rows=MySQL.query.await('SELECT plate,citizenid,vehicle FROM player_vehicles WHERE LOCATE(UPPER(?),UPPER(plate))>0 ORDER BY plate LIMIT 40',{q})
  return rows
 elseif action=='businesses' then
  if a.department~='doj' then reject('Business registry requires DOJ') end
  local out={}
  local jobs=exports.qbx_core:GetJobs()
  for _,job in ipairs(Config.BusinessJobs) do
   out[#out+1]={job=job,label=jobs[job] and jobs[job].label or job,
    licenses=MySQL.query.await("SELECT id,title,details,status FROM crimson_mdt_entries WHERE scope='justice' AND kind='business_license' AND subject=? ORDER BY id DESC",{job})}
  end
  for _,b in ipairs(out) do for _,l in ipairs(b.licenses) do unpackRow(l) end end
  return out
 elseif action=='penalcode' then
  if a.department~='police' and a.department~='doj' then reject('Legal module required') end
  return Config.PenalCode
 elseif action=='printDocument' then
  local settings=Config.Printing
  if not settings or not settings.enabled or GetResourceState('ox_inventory')~='started' then reject('Document printing requires ox_inventory and the document item') end
  if not a.write or not visible(a,'document') then reject('Document printing permission required') end
  local id=integer(payload.id,1,2147483647)
  local printerId=integer(payload.printer,1,#Config.Printers)
  local printer=printerId and Config.Printers[printerId]
  if not printer or not printer.jobs or not printer.jobs[a.p.job.name] then reject('Printer access denied') end
  local ped=GetPlayerPed(a.source)
  if not ped or ped==0 then reject('Player position unavailable') end
  local pos=GetEntityCoords(ped)
  local c=printer.coords
  if ((pos.x-c.x)^2+(pos.y-c.y)^2+(pos.z-c.z)^2)^0.5>(printer.radius or 2) then reject('You must be next to your department printer') end
  if printCooldown[a.p.citizenid] and os.time()-printCooldown[a.p.citizenid]<(settings.cooldown or 5) then reject('Wait before printing another copy') end
  local row=id and MySQL.single.await("SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind='document'",{id,a.scope})
  if not row then reject('Document not found') end
  local ticket=MySQL.scalar.await('SELECT UUID()')
  if type(ticket)~='string' then reject('Could not issue document copy') end
  local snapshot={title=row.title,body=row.body,category=decode(row.details).category or '',imageUrl=CrimsonDocumentImage(decode(row.details).imageUrl),recordId=row.id,version=row.version,author=row.owner,issuedBy=a.p.citizenid,issuerName=actorName(a.p),department=a.policy.label}
  local printId=MySQL.insert.await('INSERT INTO crimson_mdt_prints(ticket,record_id,snapshot,issued_by) VALUES(?,?,?,?)',{ticket,row.id,json.encode(snapshot),a.p.citizenid})
  local holder=exports.qbx_core:GetPlayer(a.source)
  if not holder or holder.PlayerData.citizenid~=a.p.citizenid then
   MySQL.query.await('DELETE FROM crimson_mdt_prints WHERE id=? AND ticket=?',{printId,ticket})
   reject('Printing player disconnected or changed character')
  end
  local ok=exports.ox_inventory:AddItem(a.source,settings.item,1,{print_id=printId,print_ticket=ticket,label=row.title,description='Official Crimson document · '..a.policy.label})
  if not ok then
   MySQL.query.await('DELETE FROM crimson_mdt_prints WHERE id=? AND ticket=?',{printId,ticket})
   reject('Inventory rejected the document. Check capacity and register crimson_document first.')
  end
  printCooldown[a.p.citizenid]=os.time()
  log(a,'document_print',row.id)
  return {id=printId}
 elseif action=='equipment' then
  if a.department=='business' then reject('Equipment access denied') end
  local cameras={}
  if Config.Integrations.cameras then
   for index,c in ipairs(Config.Cameras) do
    if c.jobs and c.jobs[a.p.job.name] then cameras[#cameras+1]={label=c.label,id=index} end
   end
  end
  local kits={}
  local armory=Config.Armory[a.p.job.name]
  if Config.Integrations.inventory=='ox_inventory' and armory then
   for index,k in ipairs(armory.kits or {}) do
    if a.grade>=(k.grade or 0) then kits[#kits+1]={label=k.label,grade=k.grade or 0,id=index} end
   end
  end
  return {integrations=services.integrationStatus(),cameras=cameras,kits=kits}
 elseif action=='camera' then
  if a.department=='business' or not Config.Integrations.cameras then reject('Camera provider disabled') end
  local id=integer(payload.id,1,#Config.Cameras)
  local camera=id and Config.Cameras[id]
  if not camera or not camera.jobs or not camera.jobs[a.p.job.name] then reject('Camera access denied') end
  log(a,'camera_view',nil)
  return {x=camera.x,y=camera.y,z=camera.z,rx=camera.rx or 0,ry=camera.ry or 0,rz=camera.rz or 0,fov=camera.fov or 60,label=camera.label}
 elseif action=='armory' then
  if a.department=='business' or not a.write then reject('Equipment access denied') end
  if Config.Integrations.inventory~='ox_inventory' or GetResourceState('ox_inventory')~='started' then reject('ox_inventory armory integration is not enabled') end
  local armory=Config.Armory[a.p.job.name]
  local id=armory and integer(payload.id,1,#(armory.kits or {}))
  local kit=id and armory.kits[id]
  if not kit or not armory.coords or a.grade<(kit.grade or 0) then reject('Kit access denied') end
  local ped=GetPlayerPed(a.source)
  if not ped or ped==0 then reject('Player position unavailable') end
  local pos=GetEntityCoords(ped)
  local c=armory.coords
  local distance=((pos.x-c.x)^2+(pos.y-c.y)^2+(pos.z-c.z)^2)^0.5
  if distance>(armory.radius or 3.0) then reject('You must be at your department armory') end
  local key=a.p.citizenid..':'..a.p.job.name..':'..id
  local last=kitCooldown[key]
  if last and os.time()-last<(kit.cooldown or 1800) then reject('Kit cooldown has not elapsed') end
  local issue='crimson:'..a.p.citizenid..':'..GetGameTimer()
  local issued={}
  for _,item in ipairs(kit.items or {}) do
   if type(item.name)~='string' or not integer(item.count,1,50) then reject('Armory kit configuration invalid') end
  end
  for _,item in ipairs(kit.items or {}) do
   local success=exports.ox_inventory:AddItem(a.source,item.name,item.count,{crimson_issue=issue})
   if not success then
    for _,previous in ipairs(issued) do
     exports.ox_inventory:RemoveItem(a.source,previous.name,previous.count,{crimson_issue=issue},nil,false,true)
    end
    reject('Inventory rejected the kit. Check capacity and item definitions.')
   end
   issued[#issued+1]=item
  end
  if #issued==0 then reject('Kit contains no items') end
  kitCooldown[key]=os.time()
  log(a,'armory_collect',nil)
  return true
 elseif action=='waypoint' then
  if not visible(a,'dispatch') then reject('Dispatch access denied') end
  local id=integer(payload.id,1,2147483647)
  local row=id and MySQL.single.await("SELECT details FROM crimson_mdt_entries WHERE id=? AND scope=? AND kind='dispatch'",{id,a.scope})
  local coords=row and decode(row.details).coords
  if not coords then reject('Dispatch coordinates unavailable') end
  return coords
 end
 reject('Unknown action')
end
MySQL.ready(function()
 local ok,err=pcall(function()
  local schema=assert(LoadResourceFile(GetCurrentResourceName(),'schema.sql'),'schema.sql missing')
  for s in schema:gmatch('([^;]+);') do MySQL.query.await(s) end
  MySQL.query.await('SELECT citizenid,charinfo FROM players LIMIT 0')
  -- One-time migration preserves IDs and existing v1 records without altering the old table.
  local legacy=MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='crimson_doj_records'")
  local migrated=MySQL.scalar.await("SELECT COUNT(*) FROM crimson_mdt_migrations WHERE name='v1_records'")
  if tonumber(legacy)>0 and tonumber(migrated)==0 then
   assert(MySQL.transaction.await({
    {query="INSERT INTO crimson_mdt_entries(id,scope,kind,subject,title,body,details,status,owner,updated_by,version,created_at,updated_at) SELECT id,'justice',kind,citizenid,title,body,'{}',status,created_by,updated_by,version,created_at,updated_at FROM crimson_doj_records",values={}},
    {query="INSERT INTO crimson_mdt_migrations(name) VALUES('v1_records')",values={}}
   }),'Legacy migration failed. Restore backup; do not delete the source table.')
  end
 end)
 if ok and services.initialize then
  ok,err=pcall(services.initialize)
 end
 ready=ok
 if not ok then print('[crimson_doj] Initialization failed: '..tostring(err)) end
end)
AddEventHandler('playerDropped',function() rates[source]=nil rates['read:'..source]=nil locks[source]=nil unitStatus[source]=nil unitGPS[source]=nil end)
lib.callback.register('crimson_doj:request',function(source,action,payload)
 local a=identity(source,action=='duty' or action=='bootstrap')
 if not a then return fail('Access denied. Check job, grade and duty.') end
 if not ready then return fail('Database not ready. Check server console.') end
 if Config.RequireDuty and not a.p.job.onduty and action~='duty' and action~='bootstrap' then return fail('Go on duty first.') end
 if type(action)~='string' or type(payload)~='table' then return fail('Invalid request') end
 local now=GetGameTimer()
 local rate=rates[source]
 if not rate or now-rate.time>10000 then rate={time=now,count=0} rates[source]=rate end
 rate.count=rate.count+1
 if rate.count>50 then return fail('Too many requests. Wait a moment.') end
 if locks[source] then return fail('Previous request is still processing') end
 locks[source]=true
 local ok,result=pcall(run,a,action,payload)
 locks[source]=nil
 if not ok then
  local message=tostring(result)
  print('[crimson_doj] '..tostring(action)..' failed: '..message)
  return fail(message:match('CRIMSON_VALIDATION:(.*)') or 'Server error. Check server console.')
 end
 return {ok=true,data=result}
end)

-- Printed copies are transferable. Reading requires current server-verified possession;
-- it does not grant access to the source record or department MDT.
lib.callback.register('crimson_doj:readPrinted',function(source,slot)
 if not ready or not Config.Printing or not Config.Printing.enabled or GetResourceState('ox_inventory')~='started' then return fail('Document reader unavailable') end
 slot=integer(slot,1,1000)
 if not slot then return fail('Invalid inventory slot') end
 local key='read:'..source
 local now=GetGameTimer()
 if rates[key] and now-rates[key]<750 then return fail('Please wait before reading again') end
 rates[key]=now
 local ok,result=pcall(function()
  local item=exports.ox_inventory:GetSlot(source,slot)
  if not item or item.name~=Config.Printing.item or type(item.metadata)~='table' then reject('Document is not in your inventory') end
  local id=integer(item.metadata.print_id,1,9007199254740991)
  local ticket=clean(item.metadata.print_ticket,64,true)
  if not id or not ticket then reject('Invalid document copy') end
  local copy=MySQL.single.await('SELECT snapshot,created_at FROM crimson_mdt_prints WHERE id=? AND ticket=?',{id,ticket})
  if not copy then reject('Document copy not found') end
  local data=decode(copy.snapshot)
  data.imageUrl=CrimsonDocumentImage(data.imageUrl)
  data.printId=id data.printedAt=copy.created_at
  return data
 end)
 if not ok then return fail(tostring(result):match('CRIMSON_VALIDATION:(.*)') or 'Could not read the document') end
 return {ok=true,data=result}
end)

-- Console-only installation report; prints no credentials or citizen data.
RegisterCommand('crimsoncheck',function(source)
 if source~=0 then return end
 print('[Crimson check] banking factory='..type(CrimsonBankProvider)..'; server_banking.lua='..(LoadResourceFile(GetCurrentResourceName(),'server_banking.lua') and 'present' or 'MISSING'))
 print('[Crimson check] database='..(ready and 'ready' or 'not ready'))
 for _,resource in ipairs({'qbx_core','ox_lib','oxmysql','ox_inventory','ox_target','Renewed-Banking','qbx_prison','screencapture'})do
  print('[Crimson check] '..resource..'='..GetResourceState(resource))
 end
 if GetResourceState('ox_inventory')=='started' then
  local ok,item=pcall(function()return exports.ox_inventory:Items(Config.Printing.item)end)
  print('[Crimson check] '..Config.Printing.item..' item='..(ok and item and 'registered' or 'MISSING'))
 end
 local jobs=exports.qbx_core:GetJobs()
 for name,policy in pairs(Config.Jobs)do
  local job=jobs[name]
  local management=false
  if job then for grade in pairs(job.grades)do if tonumber(grade) and tonumber(grade)>=policy.manage then management=true end end end
  print('[Crimson check] job '..name..'='..(not job and 'MISSING' or management and 'configured' or 'no management grade; adjust config'))
 end
end,true)

-- Use only after checking the external account balances/transactions.
RegisterCommand('crimsonresolve',function(source,args)
 if source~=0 then return end
 if not ready then print('[Crimson] Database not ready') return end
 local id=tonumber(args[1])
 local outcome=args[2]
 local note=table.concat(args,' ',3)
 local ok,result=pcall(services.resolvePayment,id,outcome,note)
 print(ok and '[Crimson] Payment metadata resolved; no money was moved' or '[Crimson] '..tostring(result))
end,true)
