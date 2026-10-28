-- Badge identity is resolved from the current Qbox character, never item text.
local issued, shown = {}, {}
local function owner(source)
 local player=exports.qbx_core:GetPlayer(source)
 local p=player and player.PlayerData
 local policy=p and p.job and Config.Jobs[p.job.name]
 if not policy or policy.department~='doj' or not p.job.onduty then return end
 local grade=tonumber(type(p.job.grade)=='table' and p.job.grade.level or p.job.grade)
 if not grade or grade<policy.read then return end
 return p,grade
end
RegisterCommand('dojbadge',function(source)
 if source==0 or GetResourceState('ox_inventory')~='started' then return end
 local p=owner(source)
 if not p then TriggerClientEvent('ox_lib:notify',source,{description='On-duty DOJ staff only',type='error'}) return end
 local now=GetGameTimer()
 if issued[p.citizenid] and now-issued[p.citizenid]<60000 then return end
 issued[p.citizenid]=now
 local count=exports.ox_inventory:GetItemCount(source,'crimson_doj_badge',{owner=p.citizenid},false)
 if count and count>0 then TriggerClientEvent('ox_lib:notify',source,{description='Your badge is already in your inventory',type='inform'}) return end
 local ok=exports.ox_inventory:AddItem(source,'crimson_doj_badge',1,{owner=p.citizenid,description='DOJ credential · '..p.citizenid})
 TriggerClientEvent('ox_lib:notify',source,{description=ok and 'DOJ badge added to your inventory' or 'Could not issue badge. Check item registration and inventory space.',type=ok and 'success' or 'error'})
end,false)
lib.callback.register('crimson_doj:showBadge',function(source,slot)
 if GetResourceState('ox_inventory')~='started' then return {ok=false,error='Inventory unavailable'} end
 if type(slot)~='number' or slot%1~=0 or slot<1 or slot>1000 then return {ok=false,error='Invalid slot'} end
 local p,grade=owner(source)
 if not p then return {ok=false,error='On-duty DOJ staff only'} end
 local item=exports.ox_inventory:GetSlot(source,slot)
 if not item or item.name~='crimson_doj_badge' or type(item.metadata)~='table' or item.metadata.owner~=p.citizenid then return {ok=false,error='This badge does not belong to your character'} end
 local now=GetGameTimer()
 if shown[source] and now-shown[source]<3000 then return {ok=false,error='Please wait before showing again'} end
 shown[source]=now
 local ped=GetPlayerPed(source)
 if not ped or ped==0 then return {ok=false,error='Character unavailable'} end
 local pos=GetEntityCoords(ped)
 local info=p.charinfo or {}
 local rank=type(p.job.grade)=='table' and p.job.grade.name or tostring(grade)
 local data={name=tostring(info.firstname or '')..' '..tostring(info.lastname or ''),rank=tostring(rank or grade),number='DOJ-'..p.citizenid,department='Crimson Department of Justice'}
 TriggerClientEvent('crimson_doj:badge',source,data)
 for _,id in ipairs(GetPlayers()) do
  local target=tonumber(id)
  if target and target~=source and GetPlayerRoutingBucket(target)==GetPlayerRoutingBucket(source) then
   local tp=GetPlayerPed(target)
   if tp and tp~=0 then
    local c=GetEntityCoords(tp)
    if (pos.x-c.x)^2+(pos.y-c.y)^2+(pos.z-c.z)^2<=9 then TriggerClientEvent('crimson_doj:badge',target,data) end
   end
  end
 end
 return {ok=true}
end)
AddEventHandler('playerDropped',function() shown[source]=nil end)
