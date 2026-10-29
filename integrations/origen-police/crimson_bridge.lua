-- Install as origen_police/custom/server/menu/crimson_bridge.lua.
-- The supplied manifest already loads custom/server/menu/*.lua.
local rates={}
AddEventHandler('SendAlert:police',function(payload)
 if GetResourceState('crimson_doj')~='started'or type(payload)~='table'then return end
 local src=tonumber(source)
 if not src or src<1 then return end
 local now=GetGameTimer();if rates[src]and now-rates[src]<6000 then return end;rates[src]=now
 local ped=GetPlayerPed(src);if not ped or ped==0 then return end
 local c=GetEntityCoords(ped)
 local title=type(payload.title)=='string'and payload.title:sub(1,160)or 'Origen police alert'
 local body=type(payload.message)=='string'and payload.message:sub(1,2000)or ''
 -- Keeps the original Origen alert untouched; imports a bounded Crimson call.
 pcall(function()exports.crimson_doj:CreateDispatch({title=title,body=body,coords={x=c.x,y=c.y,z=c.z},priority='high',scope='justice'})end)
end)
AddEventHandler('crimson_doj:licenseChanged',function(cid)
 if type(cachedLicenses)=='table'then cachedLicenses[cid]=nil end
end)
AddEventHandler('playerDropped',function()rates[source]=nil end)
