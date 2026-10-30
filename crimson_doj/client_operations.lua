RegisterNUICallback('airSpawn',function(data,cb)
 local ok,result=pcall(lib.callback.await,'crimson_doj:request',false,'airSpawn',{pad=type(data)=='table'and data.pad})
 if not ok then cb({ok=false,error='Server unavailable'});return end
 if result and result.ok then
  local deadline=GetGameTimer()+5000
  local vehicle=0
  repeat vehicle=NetToVeh(result.data.netId);if vehicle==0 then Wait(50)end until vehicle~=0 or GetGameTimer()>deadline
  if vehicle~=0 then SetVehicleLivery(vehicle,result.data.livery or 0)end
 end
 cb(result or {ok=false,error='Air unit unavailable'})
end)
