-- Chest-mounted gameplay view. Recording uses this player's rendered game frame.
local ownedCam=nil
local ownerPed=nil
local function stop()
 if not ownedCam then return end
 local handle=ownedCam;ownedCam=nil;ownerPed=nil
 if GetRenderingCam()==handle then RenderScriptCams(false,false,0,true,true)end
 if DoesCamExist(handle)then DestroyCam(handle,false)end
end
local function pose(ped)
 local chest=GetPedBoneCoords(ped,24818,0.0,0.0,0.0)
 local forward=GetEntityForwardVector(ped)
 local look=GetGameplayCamRot(2)
 local heading=GetEntityHeading(ped)
 local delta=(look.z-heading+180.0)%360.0-180.0
 local yaw=heading+math.max(-75.0,math.min(75.0,delta))
 local pitch=math.max(-35.0,math.min(45.0,look.x))
 return chest.x+forward.x*0.28,chest.y+forward.y*0.28,chest.z+0.06,pitch,yaw
end
local function start()
 if Config.Bodycam and Config.Bodycam.view=='gameplay'then return true end
 if ownedCam and DoesCamExist(ownedCam)then return true end
 local ped=PlayerPedId()
 if not DoesEntityExist(ped)or IsEntityDead(ped)then return false,'Character unavailable for bodycam'end
 local rendering=GetRenderingCam()
 if rendering and rendering>0 then return false,'Exit the security/other scripted camera before recording'end
 local x,y,z,pitch,yaw=pose(ped)
 local fov=math.max(45,math.min(100,tonumber(Config.Bodycam and Config.Bodycam.fov)or 80))
 local handle=CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',x,y,z,pitch,0.0,yaw,fov,false,2)
 if not handle or handle==0 then return false,'Could not create chest camera'end
 ownedCam=handle;ownerPed=ped
 SetCamActive(handle,true)
 RenderScriptCams(true,false,0,true,true)
 CreateThread(function()
  while ownedCam==handle do
   if PlayerPedId()~=ownerPed or not DoesEntityExist(ownerPed)or IsEntityDead(ownerPed)then
    stop()
    pcall(lib.callback.await,'crimson_doj:stopOwnBodycam',false)
   else
    local px,py,pz,rx,rz=pose(ownerPed)
    SetCamCoord(handle,px,py,pz)
    SetCamRot(handle,rx,0.0,rz,2)
   end
   Wait(0)
  end
 end)
 return true
end
CrimsonBodycamView={isActive=function()return ownedCam~=nil end}
lib.callback.register('crimson_doj:prepareBodycamView',function()
 local ok,ready,reason=pcall(start)
 if not ok then stop();return {ok=false,error='Chest camera initialization failed'}end
 if not ready then return {ok=false,error=reason}end
 Wait(0) -- Let the new perspective render before provider capture begins.
 return {ok=true}
end)
RegisterNetEvent('crimson_doj:bodycamStatus',function(data)
 if type(data)~='table'or data.active~=true then stop();return end
 if ownedCam then return end
 -- Compatibility for an already running capture when the resource's client reloads.
 local ok=pcall(start);if not ok then stop()end
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload',stop)
AddEventHandler('onResourceStop',function(name)if name==GetCurrentResourceName()then stop()end end)
