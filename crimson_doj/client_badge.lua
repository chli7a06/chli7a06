local token,owned,expires,prop,ped
local dict='paper_1_rcm_alt1-9'
local clip='player_one_dual-9'
local function stopPose()
 if ped and DoesEntityExist(ped) then StopAnimTask(ped,dict,clip,1.0) end
 if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
 prop,ped=nil,nil
end
local function dismiss()
 local previous=token
 if owned and previous then TriggerServerEvent('crimson_doj:hideBadge',previous) end
 token,owned=nil,nil
 stopPose()
 SendNUIMessage({action='badgeHide',presentation=previous})
end
RegisterNetEvent('crimson_doj:badge',function(data)
 stopPose()
 token,owned,expires=data.presentation,data.isOwner,GetGameTimer()+8000
 SendNUIMessage({action='dojBadge',data=data,sounds=Config.Sounds})
 if owned then
  local current=token
  CreateThread(function()
   local model=joaat('prop_fib_badge')
   pcall(function()
    lib.requestAnimDict(dict,5000);lib.requestModel(model,5000)
    if token~=current then return end
    ped=PlayerPedId()
    if IsEntityDead(ped) then return end
    local c=GetEntityCoords(ped)
    prop=CreateObject(model,c.x,c.y,c.z,false,false,false)
    if prop==0 then prop=nil return end
    AttachEntityToEntity(prop,ped,GetPedBoneIndex(ped,28422),0.06,0.021,-0.04,90.0,-180.0,78.0,true,true,false,true,1,true)
    TaskPlayAnim(ped,dict,clip,3.0,3.0,-1,49,0.0,false,false,false)
   end)
   SetModelAsNoLongerNeeded(model)
  end)
 end
end)
RegisterNetEvent('crimson_doj:badgeHide',function(presentation)
 if token==presentation then
  token,owned=nil,nil;stopPose()
  SendNUIMessage({action='badgeHide',presentation=presentation})
 end
end)
RegisterNUICallback('badgeDismiss',function(_,cb)dismiss();cb({ok=true})end)
RegisterNetEvent('QBCore:Client:OnJobUpdate',dismiss)
RegisterNetEvent('QBCore:Client:OnPlayerUnload',dismiss)
RegisterNetEvent('QBCore:Client:SetDuty',function(onDuty)if not onDuty then dismiss() end end)
AddEventHandler('onResourceStop',function(name)if name==GetCurrentResourceName() then dismiss() end end)
CreateThread(function()
 while true do
  if token then
   if GetGameTimer()>=expires or IsControlJustReleased(0,177) or IsDisabledControlJustReleased(0,177) then dismiss() end
   Wait(0)
  else Wait(200) end
 end
end)
