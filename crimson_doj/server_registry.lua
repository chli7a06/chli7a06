-- Stable 4.0 extension: serial observations and scoped camera records only.
function CrimsonRegistry(h)
 local api={actions={}};local a=api.actions
 local function permission(actor)
  if actor.scope~='justice' or not CrimsonPermission(actor,'vehicles_view',true)then h.reject('Legal vehicle permission required')end
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
        local info=type(current.PlayerData.charinfo)=='table'and current.PlayerData.charinfo or {}
        local name=(type(info.firstname)=='string'and info.firstname or '')..' '..(type(info.lastname)=='string'and info.lastname or '')
        local data={serial=serial,model=item.name,holder=cid,holderName=name:sub(1,120),registeredName=type(meta.registered)=='string'and meta.registered:sub(1,120)or '',source='online_inventory_observation',legalOwnerVerified=false}
        MySQL.update.await([[INSERT INTO crimson_mdt_entities(scope,kind,entity_id,data,updated_by) VALUES('justice','weapon_seen',?,?,'inventory_sensor') ON DUPLICATE KEY UPDATE data=VALUES(data),version=version+1,updated_at=CURRENT_TIMESTAMP]],{serial,json.encode(data)})
       end
      end
     end
    end
   end
  end
 end
 return api
end
