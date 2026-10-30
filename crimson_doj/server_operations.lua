-- Air fleet and observed inventory serials. Never infer legal ownership from possession.
function CrimsonOperations(h)
 local api={actions={}};local a=api.actions
 local fleet,cooldown,locks,padLocks={},{},{},{}
 local function permission(actor)
  if actor.scope~='justice' or not CrimsonPermission(actor,'vehicles_view',true)then h.reject('Legal vehicle permission required')end
 end
 local function pad(actor,key,nearby)
  permission(actor)
  local p=type(key)=='string'and Config.AirUnits and Config.AirUnits[key]
  if not p or not p.jobs[actor.p.job.name] or actor.grade<(p.grade or 10) or not actor.write then h.reject('Air unit permission required')end
  if nearby then
   local ped=GetPlayerPed(actor.source);if not ped or ped==0 then h.reject('Player unavailable')end
   local c=GetEntityCoords(ped);local q=p.coords
   if (c.x-q.x)^2+(c.y-q.y)^2+(c.z-q.z)^2>(p.radius or 12)^2 then h.reject('Go to the configured helipad')end
  end
  return p
 end
 local function present(entry)
  return entry and DoesEntityExist(entry.entity) and GetEntityModel(entry.entity)==entry.model and NetworkGetNetworkIdFromEntity(entry.entity)==entry.net and Entity(entry.entity).state.crimson_air_owner==entry.cid
 end
 local function valid(actor)
  local current=h.identity(actor.source)
  if not current or current.p.citizenid~=actor.p.citizenid or current.p.job.name~=actor.p.job.name or not current.write or current.grade~=actor.grade then h.reject('Air unit access changed')end
 end
 function a.airUnits(actor)
  permission(actor);local rows={}
  for id,p in pairs(Config.AirUnits or {})do
   if p.jobs[actor.p.job.name]and actor.grade>=(p.grade or 10)then
    local entry=fleet[actor.p.citizenid];rows[#rows+1]={id=id,label=p.label,model=p.model,coords=p.coords,active=present(entry)and entry.pad==id or false}
   end
  end
  return rows
 end
 function a.airSpawn(actor,payload)
  local p=pad(actor,payload.pad,true);local cid=actor.p.citizenid
  local bucket=GetPlayerRoutingBucket(actor.source);local padKey=payload.pad..':'..bucket
  if locks[cid]or padLocks[padKey]then h.reject('Air unit request processing')end
  locks[cid]=true;padLocks[padKey]=true
  local ok,result=pcall(function()
   if present(fleet[cid])then h.reject('Return your existing air unit first')end
   local now=GetGameTimer();if cooldown[cid]and now-cooldown[cid]<60000 then h.reject('Wait before requesting another air unit')end
   if GetResourceState('qbx_vehiclekeys')~='started'then h.reject('qbx_vehiclekeys must be started for this air fleet')end
   for _,entity in ipairs(GetAllVehicles())do
    local c=GetEntityCoords(entity);local q=p.coords
    if GetEntityRoutingBucket(entity)==GetPlayerRoutingBucket(actor.source)and (c.x-q.x)^2+(c.y-q.y)^2+(c.z-q.z)^2<64 then h.reject('Helipad occupied')end
   end
   local model=joaat(p.model);local q=p.coords
   local entity=CreateVehicleServerSetter(model,'heli',q.x,q.y,q.z,q.w or 0)
   if not entity or entity==0 then h.reject('Helicopter spawn failed')end
   -- Track immediately so failures cannot create unowned fleet entities.
   local entry={entity=entity,model=model,pad=payload.pad,source=actor.source,cid=cid,job=actor.p.job.name}
   fleet[cid]=entry
   local configured,err=pcall(function()
    SetEntityRoutingBucket(entity,GetPlayerRoutingBucket(actor.source))
    local deadline=GetGameTimer()+5000
    while not DoesEntityExist(entity)and GetGameTimer()<deadline do Wait(50)end
    if not DoesEntityExist(entity)then h.reject('Helicopter replication timed out')end
    valid(actor);pad(actor,payload.pad,true)
    if GetPlayerRoutingBucket(actor.source)~=bucket then h.reject('Routing bucket changed')end
    entry.net=NetworkGetNetworkIdFromEntity(entity)
    if not entry.net or entry.net==0 then h.reject('Helicopter networking unavailable')end
    Entity(entity).state:set('crimson_air_owner',cid,true)
    if not exports.qbx_vehiclekeys:GiveKeys(actor.source,entity,true)then h.reject('Vehicle key grant failed')end
   end)
   if not configured then if DoesEntityExist(entity)then DeleteEntity(entity)end;fleet[cid]=nil;error(err,0)end
   cooldown[cid]=now;h.log(actor,'air_unit_spawn',nil)
   return {netId=entry.net,livery=p.livery or 0}
  end)
  locks[cid]=nil;padLocks[padKey]=nil;if not ok then error(result,0)end;return result
 end
 function a.airReturn(actor,payload)
  pad(actor,payload.pad,true);local cid=actor.p.citizenid;local entry=fleet[cid]
  if not present(entry)or entry.pad~=payload.pad or Entity(entry.entity).state.crimson_air_owner~=cid then h.reject('No matching issued air unit')end
  if GetEntityRoutingBucket(entry.entity)~=GetPlayerRoutingBucket(actor.source)then h.reject('Air unit is in another routing bucket')end
  local p=Config.AirUnits[entry.pad].coords;local c=GetEntityCoords(entry.entity)
  if (c.x-p.x)^2+(c.y-p.y)^2+(c.z-p.z)^2>144 then h.reject('Return the helicopter to its helipad')end
  if GetPedInVehicleSeat(entry.entity,-1)~=0 then h.reject('Pilot must exit before return')end
  for seat=0,7 do if GetPedInVehicleSeat(entry.entity,seat)~=0 then h.reject('All passengers must exit before return')end end
  valid(actor)
  if GetResourceState('qbx_vehiclekeys')=='started'then pcall(function()exports.qbx_vehiclekeys:RemoveKeys(actor.source,entry.entity,true)end)end
  DeleteEntity(entry.entity);fleet[cid]=nil;h.log(actor,'air_unit_return',nil);return true
 end
 function a.weaponSerials(actor,payload)
  permission(actor)
  local serial=h.clean(payload.serial,80,true)
  if not serial or #serial<3 then h.reject('Enter at least three serial characters')end
  -- Literal LIKE: a user-supplied percent is never a wildcard.
  local escaped=serial:gsub('!','!!'):gsub('%%','!%%'):gsub('_','!_')
  local rows=MySQL.query.await([[SELECT entity_id,data,updated_at FROM crimson_mdt_entities WHERE scope='justice' AND kind='weapon_seen' AND entity_id LIKE ? ESCAPE '!' ORDER BY updated_at DESC LIMIT 50]],{'%'..escaped..'%'})
  for _,row in ipairs(rows)do row.data=h.decode(row.data)end
  h.log(actor,'weapon_serial_search',nil);return rows
 end
 local function cameraAccess(actor,write)
  permission(actor)
  if not CrimsonManagement(actor)or not Config.Integrations.cameras then h.reject('Camera access denied')end
  if write and(not actor.manage or not actor.write)then h.reject('Camera management permission required')end
 end
 local function cameraId(value)
  return h.clean(value,80,true)or h.reject('Invalid camera ID')
 end
 local function cameraRow(actor,id)
  local result=h.entities.get(actor.scope,'camera',cameraId(id))
  if result.version==0 then h.reject('Camera not found')end
  if result.data.bucket~=GetPlayerRoutingBucket(actor.source)then h.reject('Camera is in another routing bucket')end
  return result
 end
 function a.cameraCatalog(actor)
  cameraAccess(actor,false)
  local rows=MySQL.query.await("SELECT entity_id,data,version FROM crimson_mdt_entities WHERE scope=? AND kind='camera' ORDER BY updated_at DESC LIMIT 100",{actor.scope})
  local result={rows={},canEdit=actor.manage and actor.write}
  for _,row in ipairs(rows)do row.data=h.decode(row.data);if row.data.bucket==GetPlayerRoutingBucket(actor.source)then result.rows[#result.rows+1]=row end end
  return result
 end
 function a.cameraSave(actor,p)
  cameraAccess(actor,true)
  local label=h.clean(p.label,100,true);if not label then h.reject('Camera label required')end
  for _,key in ipairs({'rx','rz','fov'})do
   local v=p[key];if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then h.reject('Invalid camera angle')end
  end
  if p.rx< -90 or p.rx>90 or p.rz< -360 or p.rz>360 or p.fov<20 or p.fov>90 then h.reject('Camera angle or field of view out of range')end
  local key=p.id and cameraId(p.id)or MySQL.scalar.await('SELECT UUID()')
  if not key then h.reject('Camera ID unavailable')end
  local data=p.id and cameraRow(actor,key).data or {}
  if not p.id or p.relocate==true then
   local ped=GetPlayerPed(actor.source);if not ped or ped==0 then h.reject('Player unavailable')end
   local coords=GetEntityCoords(ped)
   data.x=coords.x;data.y=coords.y;data.z=coords.z+1.0;data.bucket=GetPlayerRoutingBucket(actor.source)
  end
  data.label=label;data.rx=p.rx;data.ry=0;data.rz=p.rz;data.fov=p.fov
  return h.entities.put(actor,actor.scope,'camera',key,data,p.id and p.version or 0)
 end
 function a.cameraDefinition(actor,p)
  cameraAccess(actor,false);local row=cameraRow(actor,p.id)
  h.log(actor,'custom_camera_view',nil);return row.data
 end
 function a.cameraDelete(actor,p)
  cameraAccess(actor,true);cameraRow(actor,p.id)
  if type(p.version)~='number'or p.version%1~=0 or p.version<1 then h.reject('Reload camera before deleting')end
  local changed=MySQL.update.await("DELETE FROM crimson_mdt_entities WHERE scope=? AND kind='camera' AND entity_id=? AND version=?",{actor.scope,p.id,p.version})
  if changed~=1 then h.reject('Camera changed; reload before deleting')end
  h.log(actor,'custom_camera_delete',nil);return true
 end
 function api.scanWeapons()
  if not Config.WeaponObservation or GetResourceState('ox_inventory')~='started'then return end
  for _,sourceId in ipairs(GetPlayers())do
   local src=tonumber(sourceId);local player=exports.qbx_core:GetPlayer(src)
   if player then
    local cid=player.PlayerData.citizenid
    local ok,items=pcall(function()return exports.ox_inventory:GetInventoryItems(src)end)
    if ok and type(items)=='table'then
     for _,item in pairs(items)do
      local meta=item.metadata
      local serial=type(meta)=='table'and h.clean(meta.serial,80,true)
      if type(item.name)=='string'and item.name:upper():match('^WEAPON_')and serial and #serial>=3 then
       local current=exports.qbx_core:GetPlayer(src)
       if current and current.PlayerData.citizenid==cid then
        local data={serial=serial,model=item.name,holder=cid,registeredName=type(meta.registered)=='string'and meta.registered:sub(1,120)or '',source='online_inventory_observation',legalOwnerVerified=false}
        MySQL.update.await([[INSERT INTO crimson_mdt_entities(scope,kind,entity_id,data,updated_by) VALUES('justice','weapon_seen',?,?,'inventory_sensor') ON DUPLICATE KEY UPDATE data=VALUES(data),version=version+1,updated_at=CURRENT_TIMESTAMP]],{serial,json.encode(data)})
       end
      end
     end
    end
   end
  end
 end
 AddEventHandler('onResourceStop',function(name)
  if name~=GetCurrentResourceName()then return end
  for _,entry in pairs(fleet)do if present(entry)and Entity(entry.entity).state.crimson_air_owner==entry.cid then DeleteEntity(entry.entity)end end
 end)
 return api
end
