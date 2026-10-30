local opened, opening = false, false
local uiEpoch, cameraEpoch = 0, 0
local camera = nil
local videoTicket = nil
local bodycamActive = false
local printedSlot=nil
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
    printedSlot=nil
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
    SendNUIMessage({ action = 'open', data = result.data, sounds = Config.Sounds })
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
    if CrimsonBodycamView and CrimsonBodycamView.isActive()then cb({ok=false,error='Stop bodycam recording before viewing security cameras'});return end
    cameraEpoch = cameraEpoch + 1
    local ticket = cameraEpoch
    local result = requestWhileOpen(data.custom and 'cameraDefinition' or 'camera', {id=data.id})
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
  printedSlot=used.slot
  SendNUIMessage({action='document',data=result.data})
 end)
end)
local printerZones = {}
local printerBusy = false
local function clearPrinterTargets()
 if GetResourceState('ox_target')=='started' then
  for _,zone in ipairs(printerZones) do exports.ox_target:removeZone(zone) end
 end
 printerZones={}
end
local function openPrinter(index)
 if printerBusy or opened or opening or camera then return end
 local printer=Config.Printers[index]
 if not printer then return end
 printerBusy=true
 local ok,result=pcall(lib.callback.await,'crimson_doj:request',false,'printerDocuments',{printer=index})
 printerBusy=false
 if not ok or type(result)~='table' or not result.ok then
  lib.notify({description=type(result)=='table' and result.error or 'Printer unavailable',type='error'})
  return
 end
 local options={}
 for _,record in ipairs(result.data.rows) do
  local recordId=record.id
  options[#options+1]={title=record.title,description='Document #'..recordId,onSelect=function()
   local success,printed=pcall(lib.callback.await,'crimson_doj:request',false,'printDocument',{id=recordId,printer=index})
   local done=success and type(printed)=='table' and printed.ok
   if done then SendNUIMessage({action='printerSound',sounds=Config.Sounds})end
   lib.notify({title='Crimson printer',description=done and 'Document added to your inventory' or (type(printed)=='table' and printed.error or 'Printer unavailable'),type=done and 'success' or 'error'})
  end}
 end
 if #options==0 then lib.notify({description='No documents waiting to print. Printed documents remain in the MDT.',type='inform'})
 else lib.registerContext({id='crimson_printer',title=printer.label,options=options}) lib.showContext('crimson_printer') end
end
local function registerPrinterTargets()
 clearPrinterTargets()
 if not Config.Printing or not Config.Printing.enabled or GetResourceState('ox_target')~='started' then return end
 for index,printer in ipairs(Config.Printers or {}) do
  local id=index
  local groups={}
  for job,allowed in pairs(printer.jobs or {}) do if allowed then groups[job]=0 end end
  if next(groups) then
   local c=printer.coords
   printerZones[#printerZones+1]=exports.ox_target:addSphereZone({
    coords=vector3(c.x,c.y,c.z),radius=printer.radius or 2.0,debug=false,drawSprite=false,
    options={{name='crimson_printer_'..id,label='Use Crimson printer',icon='fa-solid fa-print',
     groups=groups,distance=printer.radius or 2.0,
     canInteract=function()return not opened and not opening and not camera and not printerBusy end,
     onSelect=function()openPrinter(id)end}}
   })
  end
 end
end
CreateThread(registerPrinterTargets)
AddEventHandler('onClientResourceStart',function(resource)
 if resource=='ox_target' then registerPrinterTargets() end
end)
AddEventHandler('onClientResourceStop',function(resource)
 if resource==GetCurrentResourceName() then clearPrinterTargets()
 elseif resource=='ox_target' then printerZones={} end
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

exports('useBadge',function(data)
 exports.ox_inventory:useItem(data,function(used)
  if not used then return end
  local result=lib.callback.await('crimson_doj:showBadge',false,used.slot)
  if not result or not result.ok then lib.notify({title='DOJ badge',description=result and result.error or 'Badge unavailable',type='error'}) end
 end)
end)

-- Close stale department information immediately when the job or duty changes.
RegisterNetEvent('QBCore:Client:OnJobUpdate',function()close()end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload',function()close()end)
RegisterNetEvent('QBCore:Client:SetDuty',function(onDuty)if not onDuty and Config.RequireDuty then close() end end)

RegisterNUICallback('issueBadge',function(data,cb)
 local ok,result=pcall(lib.callback.await,'crimson_doj:issueBadge',false,data)
 cb(ok and result or {ok=false,error='Badge issuer unavailable'})
end)

RegisterNetEvent('crimson_doj:accessChanged',function()close()end)
RegisterNUICallback('signPrinted',function(_,cb)
 if not printedSlot then cb({ok=false,error='Open a held printed copy first'})return end
 local ok,result=pcall(lib.callback.await,'crimson_doj:signPrinted',false,printedSlot)
 cb(ok and result or {ok=false,error='Signature unavailable'})
end)
RegisterNUICallback('extendedWaypoint',function(data,cb)
 -- The source coordinates were authorized by the server tracking RPC.
 if type(data.x)=='number'and type(data.y)=='number'then SetNewWaypoint(data.x+0.0,data.y+0.0);cb({ok=true})else cb({ok=false})end
end)
RegisterCommand('removeband',function()
 local begin=lib.callback.await('crimson_doj:beginBandRemoval',false)
 if not begin or not begin.ok then lib.notify({description=begin and begin.error or 'Unavailable',type='error'})return end
 if begin.data.removed then lib.notify({description='Tracking band removed',type='success'});return end
 local start=GetGameTimer()
 local success=lib.skillCheck({'easy','medium','medium'},{'w','a','s','d'})
 while GetGameTimer()-start<3000 do Wait(50)end
 local result=lib.callback.await('crimson_doj:finishBandRemoval',false,begin.data.nonce,success)
 lib.notify({description=result.ok and 'Tracking band removed' or result.error,type=result.ok and 'success'or 'error'})
end,false)
CreateThread(function()
 while true do
  Wait(250)
  if Config.AutomaticGunshots and IsPedShooting(PlayerPedId())then TriggerServerEvent('crimson_doj:gunshots');Wait(30000)end
 end
end)
exports('useBodycam',function(data)
 exports.ox_inventory:useItem(data,function(used)
  if not used then return end
  local result
  local wasActive=bodycamActive
  if wasActive then result=lib.callback.await('crimson_doj:stopOwnBodycam',false)
  else result=lib.callback.await('crimson_doj:request',false,'bodycamStart',{})end
  lib.notify({description=result and result.ok and (wasActive and 'Finalizing recording' or 'Bodycam started')or (result and result.error or 'Bodycam unavailable'),type=result and result.ok and 'success'or 'error'})
 end)
end)
exports('useTrackingBand',function(data)
 exports.ox_inventory:useItem(data,function(used)
  if not used then return end
  local input=lib.inputDialog('Attach tracking band',{{type='number',label='Nearby player server ID',required=true},{type='number',label='Linked case ID',required=true}})
  if not input then return end
  local result=lib.callback.await('crimson_doj:request',false,'trackingApply',{source=input[1],caseId=input[2]})
  lib.notify({description=result.ok and 'Tracking band attached' or result.error,type=result.ok and 'success'or 'error'})
 end)
end)
