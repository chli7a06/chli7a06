-- Independent extended records. No external police database is modified.
function CrimsonExtensions(h)
 local reject,clean,integer,decode=h.reject,h.clean,h.integer,h.decode
 local api={actions={}}
 local actions=api.actions
 local suspensions={}
 CrimsonSuspended=function(cid,job)return suspensions[cid..':'..job]==true end
 local function legal(a)if a.scope~='justice' then reject('Legal department required')end end
 local function allow(a,permission,fallback)
  if not CrimsonPermission(a,permission,fallback) then reject('Permission required: '..permission)end
 end
 local function management(a)if not CrimsonManagement(a)then reject('Management requires DOJ grade 10+')end end
 local function id(value)
  return clean(value,64,true) or reject('Valid citizen ID required')
 end
 local function citizen(cid)
  local row=h.person(cid)
  if not row then reject('Citizen not found')end
  return row
 end
 local function get(scope,kind,key)
  local row=MySQL.single.await('SELECT data,version FROM crimson_mdt_entities WHERE scope=? AND kind=? AND entity_id=?',{scope,kind,key})
  return row and {data=decode(row.data),version=row.version} or {data={},version=0}
 end
 local function put(a,scope,kind,key,data,version)
  version=integer(version,0,2147483646)
  if not version then reject('Reload before saving')end
  local changed
  if version==0 then
   changed=MySQL.update.await('INSERT IGNORE INTO crimson_mdt_entities(scope,kind,entity_id,data,updated_by) VALUES(?,?,?,?,?)',{scope,kind,key,json.encode(data),a.p.citizenid})
  else
   changed=MySQL.update.await('UPDATE crimson_mdt_entities SET data=?,version=version+1,updated_by=? WHERE scope=? AND kind=? AND entity_id=? AND version=?',{json.encode(data),a.p.citizenid,scope,kind,key,version})
  end
  if changed~=1 then reject('Record changed; refresh before saving')end
  h.log(a,'extended_'..kind,nil)
  return {version=version+1}
 end
 local function image(value)
  if value==nil or value=='' then return ''end
  return CrimsonDocumentImage(value) or reject('Image must be an approved HTTPS JPG/PNG/WebP URL')
 end
 local function text(value,max)return clean(value or '',max or 1000,false)or reject('Invalid text')end
 local function row(a,p,kind)
  local n=integer(p.id,1,2147483647)
  local record=n and MySQL.single.await('SELECT * FROM crimson_mdt_entries WHERE id=? AND scope=?',{n,a.scope})
  if not record or (kind and not kind[record.kind])then reject('Scoped record not found')end
  return record
 end
 local function business(a,job,write)
  legal(a);allow(a,write and 'business_manage' or 'business_view',write and a.manage or true)
  job=text(job,64)
  local found=false
  for _,name in ipairs(CrimsonBusinessJobs())do if name==job then found=true break end end
  if not found then reject('Business not configured')end
  return job
 end
 function actions.citizenExtra(a,p)
  allow(a,'profiles_view',true)
  local cid=id(p.citizenid);local base=citizen(cid)
  local data=get(a.scope,'citizen',cid)
  local info=decode(base.charinfo)
  data.phone=info.phone or ''
  if a.scope=='justice' then
   local native=MySQL.single.await('SELECT metadata FROM players WHERE citizenid=?',{cid})
   local online=exports.qbx_core:GetPlayerByCitizenId(cid)
   data.licenses=online and online.PlayerData.metadata and online.PlayerData.metadata.licences or decode(native and native.metadata).licences or {}
   data.warrants=MySQL.query.await("SELECT id,title,status,details FROM crimson_mdt_entries WHERE scope=? AND kind='warrant' AND subject=? AND status='open' ORDER BY id DESC LIMIT 50",{a.scope,cid})
   data.convictions=MySQL.query.await("SELECT entity_id,data,updated_at FROM crimson_mdt_entities WHERE scope=? AND kind='conviction' AND JSON_UNQUOTE(JSON_EXTRACT(data,'$.citizenid'))=? ORDER BY updated_at DESC LIMIT 100",{a.scope,cid})
   for _,r in ipairs(data.convictions)do r.data=decode(r.data)end
  end
  data.notesHistory=MySQL.query.await("SELECT entity_id,data,updated_at FROM crimson_mdt_entities WHERE scope=? AND kind='citizen_note' AND JSON_UNQUOTE(JSON_EXTRACT(data,'$.subject'))=? ORDER BY updated_at DESC LIMIT 100",{a.scope,cid})
  for _,note in ipairs(data.notesHistory)do note.data=decode(note.data)end
  data.canEdit=CrimsonPermission(a,'profiles_edit',a.write)
  data.licenseTypes={}
  for key,label in pairs(Config.LicenseTypes or {})do data.licenseTypes[#data.licenseTypes+1]={value=key,label=label}end
  data.canLicense=a.scope=='justice' and CrimsonPermission(a,'convictions_create',a.manage)
  return data
 end
 function actions.saveCitizenExtra(a,p)
  allow(a,'profiles_edit',a.write)
  local cid=id(p.citizenid);citizen(cid)
  local data={photo=image(p.photo),notes=text(p.notes,8000)}
  if a.scope=='justice' then
   data.wanted=p.wanted==true;data.wantedReason=text(p.wantedReason,1000)
   if data.wanted and data.wantedReason=='' then reject('Wanted status requires a reason')end
  end
  return put(a,a.scope,'citizen',cid,data,p.version)
 end
 function actions.setCitizenLicense(a,p)
  legal(a);allow(a,'convictions_create',a.manage)
  local cid=id(p.citizenid);citizen(cid)
  if not Config.LicenseTypes[p.license] or type(p.enabled)~='boolean' then reject('Select a configured license')end
  local online=exports.qbx_core:GetPlayerByCitizenId(cid)
  if online then
   local current=online.PlayerData.metadata and online.PlayerData.metadata.licences or {}
   local updated={}for k,v in pairs(current)do updated[k]=v end;updated[p.license]=p.enabled
   online.Functions.SetMetaData('licences',updated)
  else
   local path='$.licences.'..p.license
   MySQL.update.await("UPDATE players SET metadata=JSON_SET(COALESCE(metadata,'{}'),?,JSON_EXTRACT(?,'$')) WHERE citizenid=?",{path,json.encode(p.enabled),cid})
  end
  if type(TriggerEvent)=='function'then TriggerEvent('crimson_doj:licenseChanged',cid)end
  h.log(a,'citizen_license_'..(p.enabled and 'grant' or 'revoke'),nil)
  return true
 end
 function actions.recordConviction(a,p)
  legal(a);allow(a,'convictions_create',a.manage)
  local cid=id(p.citizenid);citizen(cid)
  local offenses={};local fine,months=0,0
  if type(p.codes)~='table' or #p.codes<1 or #p.codes>30 then reject('Select penal-code offenses')end
  local seen={}
  for _,code in ipairs(p.codes)do
   if seen[code]then reject('Duplicate offense')end;seen[code]=true
   local found
   for _,law in ipairs(Config.PenalCode)do if law.code==code then found=law break end end
   if not found then reject('Unknown penal-code offense')end
   local f=integer(found.fine or 0,0,1000000);local m=integer(found.months or 0,0,1000000)
   if not f or not m then reject('Invalid law configuration')end
   fine=fine+f;months=months+m;offenses[#offenses+1]={code=found.code,title=found.title,fine=f,months=m}
  end
  local caseId=integer(p.caseId,1,2147483647)
  if caseId then
   local linked=row(a,{id=caseId},{case=true,incident=true})
   if linked.subject~=cid then reject('Case subject must match conviction')end
  end
  local uuid=MySQL.scalar.await('SELECT UUID()')
  return put(a,a.scope,'conviction',uuid,{citizenid=cid,offenses=offenses,fine=fine,months=months,caseId=caseId,reason=text(p.reason,2000),author=a.p.citizenid},0)
 end
 local function vehicle(a,plate)
  legal(a);allow(a,'vehicles_view',true)
  plate=text(plate,24):upper()
  local base=MySQL.single.await('SELECT plate,citizenid,vehicle FROM player_vehicles WHERE plate=? LIMIT 1',{plate})
  if not base then reject('Registered vehicle not found')end
  return base
 end
 function actions.vehicleExtra(a,p)
  local base=vehicle(a,p.plate);local extra=get(a.scope,'vehicle',base.plate)
  extra.notesHistory=MySQL.query.await("SELECT entity_id,data,updated_at FROM crimson_mdt_entities WHERE scope=? AND kind='vehicle_note' AND JSON_UNQUOTE(JSON_EXTRACT(data,'$.subject'))=? ORDER BY updated_at DESC LIMIT 100",{a.scope,base.plate})
  for _,note in ipairs(extra.notesHistory)do note.data=decode(note.data)end
  extra.vehicle=base;extra.canEdit=CrimsonPermission(a,'vehicles_edit',a.write)
  return extra
 end
 function actions.saveVehicleExtra(a,p)
  allow(a,'vehicles_edit',a.write)
  local base=vehicle(a,p.plate)
  local data={photo=image(p.photo),notes=text(p.notes,8000),wanted=p.wanted==true,reason=text(p.reason,1000)}
  if data.wanted and data.reason==''then reject('Wanted vehicle requires a reason')end
  return put(a,a.scope,'vehicle',base.plate,data,p.version)
 end
 function actions.caseBundle(a,p)
  legal(a);allow(a,'reports_view',true)
  local record=row(a,p,{case=true,incident=true})
  local value=get(a.scope,'case',tostring(record.id));value.record=record
  value.notesHistory=MySQL.query.await("SELECT entity_id,data,updated_at FROM crimson_mdt_entities WHERE scope=? AND kind='case_note' AND JSON_UNQUOTE(JSON_EXTRACT(data,'$.subject'))=? ORDER BY updated_at DESC LIMIT 100",{a.scope,tostring(record.id)})
  for _,note in ipairs(value.notesHistory)do note.data=decode(note.data)end
  value.canEdit=CrimsonPermission(a,'reports_create',a.write)
  return value
 end
 function actions.saveCaseBundle(a,p)
  legal(a);allow(a,'reports_create',a.write)
  local record=row(a,p,{case=true,incident=true})
  local data={participants={},vehicles={},photos={},notes=text(p.notes,12000)}
  for _,key in ipairs({'participants','vehicles','photos'})do if type(p[key])~='table' or #p[key]>30 then reject('Case lists must contain at most 30 entries')end end
  local seen={}
  for _,part in ipairs(p.participants)do
   if type(part)~='table' or not ({suspect=true,officer=true,witness=true,victim=true})[part.role]then reject('Invalid participant role')end
   local cid=id(part.citizenid);citizen(cid)
   local key=cid..':'..part.role;if seen[key]then reject('Duplicate participant')end;seen[key]=true
   data.participants[#data.participants+1]={citizenid=cid,role=part.role}
  end
  for _,plate in ipairs(p.vehicles)do local v=vehicle(a,plate);data.vehicles[#data.vehicles+1]=v.plate end
  for _,url in ipairs(p.photos)do data.photos[#data.photos+1]=image(url)end
  return put(a,a.scope,'case',tostring(record.id),data,p.version)
 end
 local function addNote(actor,kind,subject,p)
  local content=text(p.content,4000)
  if content==''then reject('Note content required')end
  return put(actor,actor.scope,kind,MySQL.scalar.await('SELECT UUID()'),{subject=subject,title=text(p.title,160),content=content,author=actor.p.citizenid},0)
 end
 function actions.addCitizenNote(actor,p)
  allow(actor,'profiles_edit',actor.write);local cid=id(p.citizenid);citizen(cid)
  return addNote(actor,'citizen_note',cid,p)
 end
 function actions.addVehicleNote(actor,p)
  allow(actor,'vehicles_edit',actor.write);local base=vehicle(actor,p.plate)
  return addNote(actor,'vehicle_note',base.plate,p)
 end
 function actions.addCaseNote(actor,p)
  legal(actor);allow(actor,'reports_create',actor.write);local record=row(actor,p,{case=true,incident=true})
  return addNote(actor,'case_note',tostring(record.id),p)
 end
 function actions.businessExtra(a,p)
  local job=business(a,p.job,false)
  local extra=get('justice','business',job)
  extra.employees=MySQL.query.await([[SELECT g.citizenid,g.grade,p.charinfo FROM player_groups g JOIN players p ON p.citizenid=g.citizenid WHERE g.type='job' AND g.`group`=? ORDER BY g.grade DESC LIMIT 200]],{job})
  for _,r in ipairs(extra.employees)do local c=decode(r.charinfo);r.name=(c.firstname or '')..' '..(c.lastname or '');r.charinfo=nil end
  extra.canEdit=CrimsonPermission(a,'business_manage',a.manage)
  return extra
 end
 function actions.saveBusinessExtra(a,p)
  local job=business(a,p.job,true)
  if not ({legal=true,suspicious=true,closed=true})[p.status]then reject('Select company status')end
  local owner=text(p.owner,64);if owner~=''then citizen(owner)end
  return put(a,'justice','business',job,{label=text(p.label,100),logo=image(p.logo),owner=owner,status=p.status,notes=text(p.notes,8000)},p.version)
 end
 local function staff(a,p,write)
  management(a);allow(a,write and 'employees_manage' or 'employees_view',write and a.manage or true)
  local cid=id(p.citizenid)
  local grade=MySQL.scalar.await("SELECT grade FROM player_groups WHERE citizenid=? AND type='job' AND `group`=?",{cid,a.p.job.name})
  if grade==nil then reject('Employee is not in your department')end
  if write and (cid==a.p.citizenid or tonumber(grade)>=a.grade)then reject('Cannot manage yourself or an equal/higher rank')end
  return cid
 end
 function actions.staffExtra(a,p)
  local cid=staff(a,p,false)
  local extra=get('staff:'..a.p.job.name,'staff',cid)
  extra.suspended=CrimsonSuspended(cid,a.p.job.name)
  local person=exports.qbx_core:GetPlayerByCitizenId(cid)
  local meta=person and person.PlayerData.metadata or decode((MySQL.single.await('SELECT metadata FROM players WHERE citizenid=?',{cid})or {}).metadata)
  extra.badgeNumber=meta and meta.police_badge or ''
  extra.seconds=tonumber(MySQL.scalar.await('SELECT seconds FROM crimson_mdt_duty_time WHERE citizenid=? AND job=?',{cid,a.p.job.name}))or 0
  return extra
 end
 function actions.saveStaffExtra(a,p)
  local cid=staff(a,p,true)
  local note=text(p.notes,10000)
  local badge=text(p.badgeNumber,16)
  if badge~=''and not badge:match('^[%w%-]+$')then reject('Badge number must contain letters, digits or hyphens')end
  if p.suspended==true and text(p.reason,1000)==''then reject('Suspension requires a reason')end
  local result=put(a,'staff:'..a.p.job.name,'staff',cid,{notes=note},p.version)
  if type(p.suspended)=='boolean' then
   local reason=text(p.reason,1000)
   if p.suspended and reason==''then reject('Suspension requires a reason')end
   MySQL.update.await([[INSERT INTO crimson_mdt_suspensions(citizenid,job,reason,actor,active) VALUES(?,?,?,?,?) ON DUPLICATE KEY UPDATE reason=VALUES(reason),actor=VALUES(actor),active=VALUES(active)]],{cid,a.p.job.name,reason,a.p.citizenid,p.suspended and 1 or 0})
   suspensions[cid..':'..a.p.job.name]=p.suspended
   local online=exports.qbx_core:GetPlayerByCitizenId(cid)
   if p.suspended and online and online.PlayerData.job.name==a.p.job.name then
    exports.qbx_core:SetJobDuty(online.PlayerData.source,false)
    TriggerClientEvent('crimson_doj:accessChanged',online.PlayerData.source)
   end
  end
  if p.badgeNumber~=nil then
   local person=exports.qbx_core:GetPlayerByCitizenId(cid)
   if person then person.Functions.SetMetaData('police_badge',badge)
   else MySQL.update.await("UPDATE players SET metadata=JSON_SET(COALESCE(metadata,'{}'),'$.police_badge',?) WHERE citizenid=?",{badge,cid})end
  end
  return result
 end
 function actions.statistics(a)
  allow(a,'dashboard_view',true)
  local counts={}
  for _,row in ipairs(MySQL.query.await("SELECT kind,status,COUNT(*) AS total FROM crimson_mdt_entries WHERE scope=? AND kind<>'note' GROUP BY kind,status",{a.scope}))do if not h.visible or h.visible(a,row.kind)then counts[#counts+1]=row end end
  local reports=CrimsonPermission(a,'reports_view',true)
  return {
   counts=counts,
   authors=reports and MySQL.query.await("SELECT owner,COUNT(*) AS total FROM crimson_mdt_entries WHERE scope=? AND kind IN ('case','incident') GROUP BY owner ORDER BY total DESC LIMIT 20",{a.scope})or {},
   arrests=a.scope=='justice'and reports and MySQL.query.await("SELECT c.actor,COUNT(*) AS total FROM crimson_mdt_custody c JOIN crimson_mdt_entries e ON e.id=c.entry_id WHERE e.scope=? AND c.state IN ('jailed','released') GROUP BY c.actor ORDER BY total DESC LIMIT 20",{a.scope})or {},
   duty=CrimsonPermission(a,'employees_view',true)and MySQL.query.await('SELECT citizenid,seconds FROM crimson_mdt_duty_time WHERE job=? ORDER BY seconds DESC LIMIT 20',{a.p.job.name})or {}
  }
 end
 RegisterCommand('crimsonunsuspend',function(source,args)
  if source~=0 then return end
  local cid,job=args[1],args[2]
  if not cid or not job then print('Usage: crimsonunsuspend <citizenid> <job>');return end
  MySQL.update.await('UPDATE crimson_mdt_suspensions SET active=0 WHERE citizenid=? AND job=?',{cid,job})
  suspensions[cid..':'..job]=nil
  print('[Crimson] MDT suspension cleared by server console')
 end,true)
 function api.initialize()
  for _,r in ipairs(MySQL.query.await('SELECT citizenid,job FROM crimson_mdt_suspensions WHERE active=1')or {})do suspensions[r.citizenid..':'..r.job]=true end
 end
 local lastDuty={}
 function api.tick()
  local seen={};local now=os.time()
  for _,sid in ipairs(GetPlayers())do
   local src=tonumber(sid);local a=h.identity(src)
   if a and a.p.job.onduty then
    local key=a.p.citizenid..':'..a.p.job.name;seen[key]=true
    if lastDuty[key]then
     local delta=math.min(60,math.max(0,now-lastDuty[key]))
     MySQL.update.await('INSERT INTO crimson_mdt_duty_time(citizenid,job,seconds) VALUES(?,?,?) ON DUPLICATE KEY UPDATE seconds=seconds+VALUES(seconds)',{a.p.citizenid,a.p.job.name,delta})
    end
    lastDuty[key]=now
   end
  end
  for k in pairs(lastDuty)do if not seen[k]then lastDuty[k]=nil end end
  MySQL.update.await([[UPDATE crimson_mdt_entries SET status='closed',version=version+1 WHERE kind IN ('warrant','business_license') AND status='open' AND JSON_UNQUOTE(JSON_EXTRACT(details,'$.expires')) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND JSON_UNQUOTE(JSON_EXTRACT(details,'$.expires'))<DATE_FORMAT(CURDATE(),'%Y-%m-%d')]])
 end
 api.get=get;api.put=put;api.row=row;api.allow=allow;api.legal=legal;api.text=text
 return api
end
function CrimsonBusinessJobs()
 local found={}
 for _,name in ipairs(Config.BusinessJobs or {})do found[name]=true end
 if Config.DiscoverBusinesses then
  for name in pairs(exports.qbx_core:GetJobs())do if name~='unemployed' and not (Config.BusinessExcludedJobs or {})[name]then found[name]=true end end
 end
 local result={}for name in pairs(found)do result[#result+1]=name end;table.sort(result)
 return result
end
