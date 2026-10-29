-- Only DOJ chiefs issue owner-bound, database-backed credentials.
local issued, shown, presentations, busy = {}, {}, {}, {}
local function owner(source)
 local player=exports.qbx_core:GetPlayer(source)
 local p=player and player.PlayerData
 local policy=p and p.job and Config.Jobs[p.job.name]
 if not policy or policy.department~='doj' or not p.job.onduty then return end
 local grade=tonumber(type(p.job.grade)=='table' and p.job.grade.level or p.job.grade)
 if not grade or grade<policy.read or (Config.DojGrades and not Config.DojGrades[tostring(grade)]) then return end
 return p,grade
end
local function nearby(a,b)
 if GetPlayerRoutingBucket(a)~=GetPlayerRoutingBucket(b) then return false end
 local p,q=GetPlayerPed(a),GetPlayerPed(b)
 if not p or not q or p==0 or q==0 then return false end
 local x,y=GetEntityCoords(p),GetEntityCoords(q)
 return (x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2<=9
end
local function hide(source,token)
 local item=presentations[source]
 if not item or (token and item.token~=token) then return end
 presentations[source]=nil
 for _,id in ipairs(item.viewers) do TriggerClientEvent('crimson_doj:badgeHide',id,item.token) end
end
lib.callback.register('crimson_doj:issueBadge',function(source,payload)
 local p,grade=owner(source)
 if not p or grade<(Config.BadgeChiefMinGrade or 13) then return {ok=false,error='DOJ chief permission required'} end
 if GetResourceState('ox_inventory')~='started' then return {ok=false,error='Inventory unavailable'} end
 local cid=type(payload)=='table' and payload.citizenid
 local name=type(payload)=='table' and payload.name
 if type(cid)~='string' or #cid>64 or type(name)~='string' then return {ok=false,error='Enter citizen ID and badge name'} end
 name=name:match('^%s*(.-)%s*$')
 if #name<2 or #name>80 or name:find('%c') then return {ok=false,error='Badge name must contain 2–80 characters'} end
 cid=cid:match('^%s*(.-)%s*$')
 local targetId
 if cid:lower()==p.citizenid:lower() then targetId=source
 else
  local target=exports.qbx_core:GetPlayerByCitizenId(cid)
  if not target and cid~=cid:upper() then target=exports.qbx_core:GetPlayerByCitizenId(cid:upper()) end
  targetId=target and tonumber(target.PlayerData.source)
 end
 if not targetId then return {ok=false,error='Citizen ID not found online. Copy the exact ID from Citizens, or use My citizen ID.'} end
 local holder=owner(targetId)
 if not holder then return {ok=false,error='Recipient must have DOJ as primary job and be on duty'} end
 cid=holder.citizenid
 if targetId~=source and not nearby(source,targetId) then return {ok=false,error='Recipient must be within 3 metres and in the same routing bucket'} end
 local now=GetGameTimer()
 if busy[cid] or (issued[p.citizenid] and now-issued[p.citizenid]<5000) then return {ok=false,error='Please wait before issuing again'} end
 busy[cid]=true;issued[p.citizenid]=now
 local ok,result=pcall(function()
  local ticket=MySQL.scalar.await('SELECT UUID()')
  if type(ticket)~='string' then error('Could not allocate badge') end
  local inserted=MySQL.insert.await('INSERT INTO crimson_mdt_badges(ticket,owner,display_name,issuer) VALUES(?,?,?,?)',{ticket,cid,name,p.citizenid})
  if inserted==nil or inserted==false then error('Badge registry write failed') end
  local chief,chiefGrade=owner(source)
  local current=owner(targetId)
  if not chief or chief.citizenid~=p.citizenid or chiefGrade<(Config.BadgeChiefMinGrade or 13) or not current or current.citizenid~=cid or (targetId~=source and not nearby(source,targetId)) then
   MySQL.update.await('DELETE FROM crimson_mdt_badges WHERE ticket=?',{ticket})
   error('Chief or recipient changed character, duty or location')
  end
  local added=exports.ox_inventory:AddItem(targetId,'crimson_doj_badge',1,{owner=cid,badge_ticket=ticket,label='DOJ · '..name,description='Official DOJ badge · '..name})
  if not added then MySQL.update.await('DELETE FROM crimson_mdt_badges WHERE ticket=?',{ticket});error('Recipient inventory rejected badge') end
  return true
 end)
 busy[cid]=nil
 if not ok then print('[crimson_doj badge] '..tostring(result));return {ok=false,error='Badge issuance failed; check inventory space and server console'} end
 return {ok=true}
end)
lib.callback.register('crimson_doj:showBadge',function(source,slot)
 if GetResourceState('ox_inventory')~='started' then return {ok=false,error='Inventory unavailable'} end
 if type(slot)~='number' or slot%1~=0 or slot<1 or slot>1000 then return {ok=false,error='Invalid slot'} end
 local p,grade=owner(source)
 if not p then return {ok=false,error='On-duty DOJ staff only'} end
 local item=exports.ox_inventory:GetSlot(source,slot)
 if not item or item.name~='crimson_doj_badge' or type(item.metadata)~='table' or item.metadata.owner~=p.citizenid then return {ok=false,error='This badge does not belong to your character'} end
 local ticket=item.metadata.badge_ticket
 if type(ticket)~='string' or #ticket>64 then return {ok=false,error='Ask your DOJ chief to issue a new badge'} end
 local now=GetGameTimer()
 if shown[source] and now-shown[source]<3000 then return {ok=false,error='Please wait before showing again'} end
 shown[source]=now
 local entry=MySQL.single.await('SELECT display_name FROM crimson_mdt_badges WHERE ticket=? AND owner=?',{ticket,p.citizenid})
 if not entry then return {ok=false,error='Badge is not registered; ask your DOJ chief'} end
 local live,liveGrade=owner(source)
 local held=exports.ox_inventory:GetSlot(source,slot)
 if not live or live.citizenid~=p.citizenid or not held or held.name~='crimson_doj_badge' or not held.metadata or held.metadata.badge_ticket~=ticket or held.metadata.owner~=p.citizenid then return {ok=false,error='Badge holder or inventory changed'} end
 hide(source)
 local token=ticket..':'..now
 local viewers={source}
 for _,id in ipairs(GetPlayers()) do local target=tonumber(id);if target and target~=source and nearby(source,target) then viewers[#viewers+1]=target end end
 presentations[source]={token=token,viewers=viewers}
 local rank=Config.DojGrades and Config.DojGrades[tostring(liveGrade)]
 for _,target in ipairs(viewers) do
  TriggerClientEvent('crimson_doj:badge',target,{name=entry.display_name,rank=rank and rank.label or (type(p.job.grade)=='table' and p.job.grade.name or tostring(grade)),number='DOJ-'..p.citizenid,presentation=token,isOwner=target==source})
 end
 SetTimeout(8000,function()hide(source,token)end)
 return {ok=true}
end)
RegisterNetEvent('crimson_doj:hideBadge',function(token)if type(token)=='string' then hide(source,token)end end)
AddEventHandler('playerDropped',function()hide(source);shown[source]=nil end)
