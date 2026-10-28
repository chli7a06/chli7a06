local opened, opening = false, false
local uiEpoch, cameraEpoch = 0, 0
local camera = nil
local videoTicket = nil
local bodycamActive = false
-- tablet2 pose and prop, independent of any emote-menu resource.
local tabletProp, tabletPed
local tabletDict = 'amb@world_human_seat_wall_tablet@female@base'
local function stopTablet()
    if tabletPed and DoesEntityExist(tabletPed) then
        StopAnimTask(tabletPed, tabletDict, 'base', 1.0)
    end
    if tabletProp and DoesEntityExist(tabletProp) then DeleteEntity(tabletProp) end
    tabletProp, tabletPed = nil, nil
end
local function startTablet(epoch)
    local model = joaat('prop_cs_tablet')
    local ok = pcall(function()
        lib.requestAnimDict(tabletDict, 5000)
        lib.requestModel(model, 5000)
        if not opened or uiEpoch ~= epoch then return end
        local ped = PlayerPedId()
        if IsEntityDead(ped) then return end
        local pos = GetEntityCoords(ped)
        local prop = CreateObject(model, pos.x, pos.y, pos.z, false, false, false)
        if prop == 0 then return end
        tabletProp, tabletPed = prop, ped
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309),
            0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
        TaskPlayAnim(ped, tabletDict, 'base', 3.0, 3.0, -1, 49, 0.0, false, false, false)
    end)
    SetModelAsNoLongerNeeded(model)
    if not ok then stopTablet() end
end
local function stopCamera()
    cameraEpoch = cameraEpoch + 1
    if camera then
        lib.hideTextUI()
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(camera, false)
        camera = nil
    end
end
local function close()
    if videoTicket then TriggerServerEvent('crimson_doj:cancelVideo',videoTicket) videoTicket=nil end
    uiEpoch = uiEpoch + 1
    opened, opening = false, false
    stopCamera()
    stopTablet()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end
local function requestWhileOpen(action, payload)
    if not opened then return {ok=false,error='Tablet closed'} end
    local epoch = uiEpoch
    local ok, result = pcall(lib.callback.await, 'crimson_doj:request', false, action, payload)
    if not opened or epoch ~= uiEpoch then return {ok=false,error='Tablet closed'} end
    if not ok or type(result) ~= 'table' then return {ok=false,error='Server unavailable'} end
    return result
end
RegisterCommand(Config.Command, function()
    if opened or opening then close() return end
    opening = true
    local epoch = uiEpoch
    local ok, result = pcall(lib.callback.await, 'crimson_doj:request', false, 'bootstrap', {})
    if epoch ~= uiEpoch then return end
    opening = false
    if not ok or type(result) ~= 'table' or not result.ok then
        lib.notify({ title = 'Crimson MDT', description = type(result)=='table' and result.error or 'Server unavailable', type = 'error' })
        return
    end
    opened = true
    SetNuiFocusKeepInput(false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = result.data })
    CreateThread(function() startTablet(epoch) end)
end, false)
RegisterKeyMapping(Config.Command, 'Open Crimson MDT', 'keyboard', Config.Key)
RegisterCommand('mdtclose', function() close() end, false)
RegisterNUICallback('close', function(_, cb) close() cb({ok=true}) end)
RegisterNUICallback('request', function(data, cb)
    cb(requestWhileOpen(data.action, data.payload or {}))
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then close() end
end)
RegisterNUICallback('waypoint', function(data, cb)
    local result = requestWhileOpen(data.unit and 'unitWaypoint' or 'waypoint', data.unit and {source=data.id} or {id=data.id})
    if result.ok then
        SetNewWaypoint(result.data.x+0.0, result.data.y+0.0)
        cb({ok=true})
    else cb(result) end
end)
RegisterNUICallback('camera', function(data, cb)
    cameraEpoch = cameraEpoch + 1
    local ticket = cameraEpoch
    local result = requestWhileOpen('camera', {id=data.id})
    if not result.ok then cb(result) return end
    if ticket ~= cameraEpoch then cb({ok=false,error='Camera request cancelled'}) return end
    stopCamera()
    local c = result.data
    camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',c.x+0.0,c.y+0.0,c.z+0.0,c.rx+0.0,c.ry+0.0,c.rz+0.0,c.fov+0.0,false,0)
    local handle = camera
    SetCamActive(camera,true)
    lib.showTextUI('Security camera · [Esc] return to MDT')
    RenderScriptCams(true,true,250,true,true)
    SetNuiFocus(false,false)
    SendNUIMessage({action='camera'})
    cb({ok=true})
    CreateThread(function()
        while camera == handle do
            Wait(0)
            if camera == handle then
                DisableControlAction(0,200,true)
                if IsDisabledControlJustPressed(0,200) or IsControlJustPressed(0,177) then
                    stopCamera()
                    if opened then SetNuiFocus(true,true) SendNUIMessage({action='cameraEnd'}) end
                end
            end
        end
    end)
end)

local function nearestPrinter()
 local pos=GetEntityCoords(PlayerPedId())
 local nearest,distance=nil,math.huge
 for index,p in ipairs(Config.Printers or {}) do
  local c=p.coords
  local d=((pos.x-c.x)^2+(pos.y-c.y)^2+(pos.z-c.z)^2)^0.5
  if d<=(p.radius or 2) and d<distance then nearest,distance=index,d end
 end
 return nearest
end
RegisterNUICallback('printDocument',function(data,cb)
 local printer=nearestPrinter()
 if not printer then cb({ok=false,error='Go to your department printer first'}) return end
 cb(requestWhileOpen('printDocument',{id=data.id,printer=printer}))
end)
exports('useDocument',function(data,slot)
 if not Config.Printing or not Config.Printing.enabled then return end
 close()
 local epoch=uiEpoch
 exports.ox_inventory:useItem(data,function(used)
  if not used or uiEpoch~=epoch then return end
  local ok,result=pcall(lib.callback.await,'crimson_doj:readPrinted',false,used.slot)
  if uiEpoch~=epoch then return end
  if not ok or type(result)~='table' or not result.ok then
   lib.notify({title='Crimson document',description=type(result)=='table' and result.error or 'Could not read document',type='error'})
   return
  end
  SetNuiFocusKeepInput(false)
  SetNuiFocus(true,true)
  SendNUIMessage({action='document',data=result.data})
 end)
end)
CreateThread(function()
 while true do
  local wait=1000
  if Config.Printing and Config.Printing.enabled and not opened and not opening and not camera then
   local index=nearestPrinter()
   if index then
    wait=0
    local printer=Config.Printers[index]
    local c=printer.coords
    DrawMarker(2,c.x,c.y,c.z+0.15,0.0,0.0,0.0,0.0,180.0,0.0,0.2,0.2,0.2,239,52,75,150,false,true,2,false,nil,nil,false)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to use the Crimson printer')
    EndTextCommandDisplayHelp(0,false,false,-1)
    if IsControlJustReleased(0,38) then
     local ok,result=pcall(lib.callback.await,'crimson_doj:request',false,'list',{kind='document',page=1,query=''})
     if ok and result and result.ok then
      local options={}
      for _,record in ipairs(result.data.rows) do
       local recordId=record.id
       options[#options+1]={title=record.title,description='Document #'..recordId,onSelect=function()
        local printed=lib.callback.await('crimson_doj:request',false,'printDocument',{id=recordId,printer=index})
        lib.notify({title='Crimson printer',description=printed.ok and 'Document added to your inventory' or printed.error,type=printed.ok and 'success' or 'error'})
       end}
      end
      if #options==0 then lib.notify({description='No saved documents. Create one in the MDT first.',type='inform'})
      else lib.registerContext({id='crimson_printer',title=printer.label,options=options}) lib.showContext('crimson_printer') end
     else lib.notify({description=type(result)=='table' and result.error or 'Printer unavailable',type='error'}) end
    end
   end
  end
  Wait(wait)
 end
end)

RegisterNetEvent('crimson_doj:invoiceOffer',function(offer)
 local answer=lib.alertDialog({header='Invoice · '..offer.business,content=offer.title..'\nAmount: $'..offer.amount..'\nPay from your bank account?',centered=true,cancel=true})
 if answer~='confirm' then return end
 local result=lib.callback.await('crimson_doj:payInvoice',false,{id=offer.id,version=offer.version})
 lib.notify({title='Crimson payment',description=result.ok and 'Payment completed' or result.error,type=result.ok and 'success' or 'error'})
end)

RegisterNetEvent('crimson_doj:videoStart',function(data)
 if not opened or type(data.ticket)~='string' then
  if type(data.ticket)=='string' then TriggerServerEvent('crimson_doj:cancelVideo',data.ticket) end
  return
 end
 videoTicket=data.ticket
 SendNUIMessage({action='videoStart',data=data})
end)
RegisterNetEvent('crimson_doj:videoChunk',function(data)
 if opened and data.ticket==videoTicket then SendNUIMessage({action='videoChunk',data=data}) end
end)
RegisterNUICallback('cancelVideo',function(_,cb)
 if videoTicket then TriggerServerEvent('crimson_doj:cancelVideo',videoTicket) videoTicket=nil end
 cb({ok=true})
end)
RegisterNetEvent('crimson_doj:bodycamStatus',function(data)
 bodycamActive=data.active==true
 if not bodycamActive then lib.notify({title='Crimson bodycam',description=data.saved and 'Recording saved in the library' or data.error or 'Recording stopped',type=data.saved and 'success' or 'inform'}) end
end)
RegisterCommand('bodycamstop',function()
 local result=lib.callback.await('crimson_doj:stopOwnBodycam',false)
 lib.notify({description=result.ok and 'Finalizing bodycam capture' or result.error,type=result.ok and 'success' or 'error'})
end,false)
CreateThread(function()
 while true do
  if bodycamActive then
   DrawRect(0.87,0.08,0.2,0.04,110,10,25,190)
   SetTextFont(0) SetTextScale(0.0,0.32) SetTextColour(255,235,235,255)
   SetTextCentre(true) BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName('REC · CRIMSON BODYCAM · /bodycamstop') EndTextCommandDisplayText(0.87,0.069)
   Wait(0)
  else Wait(300) end
 end
end)
