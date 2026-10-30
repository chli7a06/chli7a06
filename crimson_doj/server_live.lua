function CrimsonLive(h)
 local active,viewers={},{}
 local api={}
 local function permitted(a)
  if not a or not a.write or a.department=='business'then h.reject('Bodycam permission required')end
 end
 local function canWatch(a)
  return a and a.write and a.department=='doj' and tonumber(a.grade)==12
 end
 local function endpoint()
  local url=GetConvar('screencapture_live_endpoint','')
  if not Config.EnableLiveBodycam or not url:match('^https://')or GetResourceState('screencapture')~='started'then
   h.reject('Live video requires EnableLiveBodycam=true and the screencapture Cloudflare Worker endpoint')
  end
  return url
 end
 local function stop(cid)
  local item=active[cid];if not item then return end
  active[cid]=nil;viewers[item.id]=nil
  pcall(function()exports.screencapture:stopLiveStream(item.id)end)
 end
 function api.liveSources(a)
  permitted(a)
  local ok=pcall(endpoint);local rows={}
  for cid,entry in pairs(active)do
   local host=h.identity(entry.source)
   if host and host.p.citizenid==cid and host.scope==a.scope and entry.ready and canWatch(a) then rows[#rows+1]={citizenid=cid,source=entry.source,name=entry.name}end
  end
  return {configured=ok,rows=rows,audio=false,canWatch=canWatch(a)}
 end
 function api.liveStart(a)
  permitted(a);endpoint()
  if Config.RequireBodycamItem and (exports.ox_inventory:GetItemCount(a.source,Config.BodycamItem)or 0)<1 then h.reject('Bodycam inventory item required')end
  if active[a.p.citizenid]then h.reject('Your live bodycam is already active')end
  local entry={source=a.source,scope=a.scope,name=(a.p.charinfo and a.p.charinfo.firstname or '')..' '..(a.p.charinfo and a.p.charinfo.lastname or '')}
  local id=exports.screencapture:startLiveStream(a.source,{duration=900,maxWidth=1280,maxHeight=720,frameRate=24,maxViewers=10},function(result)
   if result.status=='error'then entry.failed=true;active[a.p.citizenid]=nil;TriggerClientEvent('ox_lib:notify',a.source,{description='Live bodycam failed to start',type='error'})
   else entry.ready=true end
  end)
  if not id or entry.failed then h.reject('Live provider rejected capture')end
  entry.id=id;active[a.p.citizenid]=entry
  return {started=true,audio=false}
 end
 function api.liveStop(a)permitted(a);stop(a.p.citizenid);return true end
 function api.liveWatch(a,p)
  permitted(a);if not canWatch(a)then h.reject('Only Senior Judge may watch live bodycams')end;local url=endpoint()
  local item=active[p.citizenid];local host=item and h.identity(item.source)
  if not item or not item.ready or not host or host.scope~=a.scope or host.p.citizenid~=p.citizenid then h.reject('Live bodycam not available in your department')end
  local pending=promise.new();local resolved=false
  SetTimeout(10000,function()if not resolved then resolved=true;pending:resolve({error='Viewer token timed out'})end end)
  exports.screencapture:createLiveStreamViewerToken(item.id,function(grant)if not resolved then resolved=true;pending:resolve(grant)end end)
  local grant=Citizen.Await(pending)
  local current=h.identity(a.source)
  if not canWatch(current) or current.p.citizenid~=a.p.citizenid or current.scope~=a.scope then h.reject('Viewer access changed')end
  host=h.identity(item.source)
  if active[p.citizenid]~=item or not host or not host.write or host.scope~=current.scope or host.p.citizenid~=p.citizenid then h.reject('Live bodycam access changed')end
  if type(grant)~='table' or grant.error or grant.streamId~=item.id or type(grant.viewerToken)~='string'then h.reject('Live viewer token unavailable')end
  viewers[item.id]=viewers[item.id]or {};viewers[item.id][a.source]=a.p.citizenid
  h.log(a,'bodycam_live_view',nil)
  return {endpoint=url,streamId=grant.streamId,viewerToken=grant.viewerToken}
 end
 CreateThread(function()
  while true do
   Wait(2000)
   for cid,item in pairs(active)do
    local host=h.identity(item.source)
    local valid=host and host.write and host.department~='business' and host.p.citizenid==cid and host.scope==item.scope
    for src,viewer in pairs(viewers[item.id]or {})do
     local actor=h.identity(src)
     if not canWatch(actor) or actor.p.citizenid~=viewer or actor.scope~=item.scope then valid=false end
    end
    if not valid then stop(cid)end
   end
  end
 end)
 AddEventHandler('screencapture:liveStreamEnded',function(id)
  for cid,item in pairs(active)do if item.id==id then active[cid]=nil;viewers[id]=nil end end
 end)
 AddEventHandler('onResourceStop',function(name)if name==GetCurrentResourceName()then for cid in pairs(active)do stop(cid)end end end)
 return api
end
