local token,owned,expires
local emoteActive=false
local function stopPose()
 if emoteActive then
  emoteActive=false
  ExecuteCommand((Config.BadgeEmote and Config.BadgeEmote.cancel) or 'e c')
 end
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
 SendNUIMessage({action='dojBadge',locale=Config.Locale,data=data,sounds=Config.Sounds})
 if owned then
  emoteActive=true
  ExecuteCommand((Config.BadgeEmote and Config.BadgeEmote.command) or 'e idcard')
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
