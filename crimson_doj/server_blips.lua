-- Coordinates originate on the server and go only to on-duty legal jobs.
local previous={}
local function player(id)
 local q=exports.qbx_core:GetPlayer(id)
 local p=q and q.PlayerData
 local c=Config.JobBlips
 if not c or not c.enabled or not p or not p.job or not p.job.onduty or not c.jobs[p.job.name] then return end
 return p
end
function CrimsonBlipTick()
 local current,units={},{ }
 for _,sid in ipairs(GetPlayers()) do
  local id=tonumber(sid)
  local p=id and player(id)
  if p then
   current[id]=p
   local ped=GetPlayerPed(id)
   if ped and ped~=0 then
    local c=GetEntityCoords(ped)
    units[#units+1]={source=id,job=p.job.name,name=(p.charinfo and p.charinfo.firstname or '')..' '..(p.charinfo and p.charinfo.lastname or ''),x=c.x,y=c.y,z=c.z,heading=GetEntityHeading(ped),bucket=GetPlayerRoutingBucket(id)}
   end
  end
 end
 for id,p in pairs(current) do
  local rows={}
  for _,unit in ipairs(units) do
   -- Origen already owns police-to-police/sheriff markers.
   if unit.source~=id and (p.job.name=='doj' or unit.job=='doj') and unit.bucket==GetPlayerRoutingBucket(id) then
    rows[#rows+1]={source=unit.source,job=unit.job,name=unit.name,x=unit.x,y=unit.y,z=unit.z,heading=unit.heading}
   end
  end
  TriggerClientEvent('crimson_doj:jobBlips',id,rows)
 end
 for id in pairs(previous) do if not current[id] then TriggerClientEvent('crimson_doj:jobBlips',id,{}) end end
 previous=current
end
CreateThread(function()
 while true do
  CrimsonBlipTick()
  Wait(math.max(1000,tonumber(Config.JobBlips and Config.JobBlips.interval) or 3000))
 end
end)
AddEventHandler('playerDropped',function()previous[source]=nil end)
