function CrimsonTracking(h)
 local previous={}
 CreateThread(function()
  while true do
   Wait(5000)
   if h.ready()then
    local current,targets={},{}
    if Config.Tracking.enabled then
     local rows=MySQL.query.await('SELECT citizenid,scope FROM crimson_mdt_tracking WHERE active=1 LIMIT 100')
     for _,row in ipairs(rows)do
      local player=exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
      local src=player and player.PlayerData.source
      local ped=src and GetPlayerPed(src)
      if ped and ped~=0 then local p=GetEntityCoords(ped);targets[#targets+1]={citizenid=row.citizenid,scope=row.scope,bucket=GetPlayerRoutingBucket(src),x=p.x,y=p.y,z=p.z}end
     end
     for _,id in ipairs(GetPlayers())do
      local src=tonumber(id);local actor=h.identity(src)
      if actor and actor.p.job.onduty and actor.scope=='justice'and actor.grade>=(Config.Tracking.grade or 5)then
       current[src]=true;local data={}
       for _,row in ipairs(targets)do if row.scope==actor.scope and row.bucket==GetPlayerRoutingBucket(src)and row.citizenid~=actor.p.citizenid then data[#data+1]={citizenid=row.citizenid,x=row.x,y=row.y,z=row.z}end end
       TriggerClientEvent('crimson_doj:trackingBlips',src,data)
      end
     end
    end
    for src in pairs(previous)do if not current[src]then TriggerClientEvent('crimson_doj:trackingBlips',src,{})end end
    previous=current
   end
  end
 end)
end
