-- Use GTA's native first-person view while recording the rendered game frame.
local session=nil
local function stop()
 local previous=session
 if not previous then return end
 session=nil
 SetFollowPedCamViewMode(previous.pedMode)
 SetFollowVehicleCamViewMode(previous.vehicleMode)
end
local function start()
 if session then return true end
 if Config.Bodycam and Config.Bodycam.view=='gameplay'then return true end
 local ped=PlayerPedId()
 if not DoesEntityExist(ped)or IsEntityDead(ped)then return false,'Character unavailable for bodycam'end
 local rendering=GetRenderingCam()
 if rendering and rendering>0 then return false,'Exit the security/other scripted camera before recording'end
 local current={ped=ped,pedMode=GetFollowPedCamViewMode(),vehicleMode=GetFollowVehicleCamViewMode()}
 session=current
 SetFollowPedCamViewMode(4)
 SetFollowVehicleCamViewMode(4)
 CreateThread(function()
  while session==current do
   if PlayerPedId()~=current.ped or not DoesEntityExist(current.ped)or IsEntityDead(current.ped)then
    stop()
    pcall(lib.callback.await,'crimson_doj:stopOwnBodycam',false)
   else
    SetFollowPedCamViewMode(4)
    SetFollowVehicleCamViewMode(4)
   end
   Wait(0)
  end
 end)
 return true
end
CrimsonBodycamView={isActive=function()return session~=nil end}
lib.callback.register('crimson_doj:prepareBodycamView',function()
 local ok,ready,reason=pcall(start)
 if not ok then stop();return {ok=false,error='First-person view initialization failed'}end
 if not ready then return {ok=false,error=reason}end
 Wait(0)
 return {ok=true}
end)
RegisterNetEvent('crimson_doj:bodycamStatus',function(data)
 if type(data)~='table'or data.active~=true then stop();return end
 if session then return end
 local ok=pcall(start);if not ok then stop()end
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload',stop)
AddEventHandler('onResourceStop',function(name)if name==GetCurrentResourceName()then stop()end end)
