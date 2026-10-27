local opened = false
local camera = nil
local function stopCamera()
    if camera then lib.hideTextUI() RenderScriptCams(false, true, 250, true, true) DestroyCam(camera, false) camera = nil end
end
local function close()
    stopCamera()
    opened = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end
RegisterCommand(Config.Command, function()
    if opened then close() return end
    local ok, result = pcall(lib.callback.await, 'crimson_doj:request', false, 'bootstrap', {})
    if not ok or not result or not result.ok then
        lib.notify({ title = 'Crimson DOJ', description = result and result.error or 'Server unavailable', type = 'error' })
        return
    end
    opened = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = result.data })
end, false)
RegisterKeyMapping(Config.Command, 'Open Crimson DOJ', 'keyboard', Config.Key)
-- Always available recovery, even when the browser UI cannot respond.
RegisterCommand('mdtclose', function() close() end, false)
RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('request', function(data, cb)
    if not opened then cb({ ok = false, error = 'Tablet closed' }) return end
    local ok, result = pcall(lib.callback.await, 'crimson_doj:request', false, data.action, data.payload or {})
    cb(ok and result or { ok = false, error = 'Server unavailable' })
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then close() end
end)

RegisterNUICallback('waypoint', function(data, cb)
    if not opened then cb({ok=false,error='Tablet closed'}) return end
    local ok, result=pcall(lib.callback.await,'crimson_doj:request',false,data.unit and 'unitWaypoint' or 'waypoint',data.unit and {source=data.id} or {id=data.id})
    if ok and result and result.ok then
        SetNewWaypoint(result.data.x+0.0,result.data.y+0.0)
        cb({ok=true})
    else cb(ok and result or {ok=false,error='Waypoint unavailable'}) end
end)
RegisterNUICallback('camera', function(data, cb)
    if not opened then cb({ok=false,error='Tablet closed'}) return end
    local ok,result=pcall(lib.callback.await,'crimson_doj:request',false,'camera',{id=data.id})
    if not ok or not result or not result.ok then cb(ok and result or {ok=false,error='Camera unavailable'}) return end
    stopCamera()
    local c=result.data
    camera=CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',c.x+0.0,c.y+0.0,c.z+0.0,c.rx+0.0,c.ry+0.0,c.rz+0.0,c.fov+0.0,false,0)
    SetCamActive(camera,true)
    lib.showTextUI('Security camera · [Esc] return to MDT')
    RenderScriptCams(true,true,250,true,true)
    SetNuiFocus(false,false)
    SendNUIMessage({action='camera'})
    cb({ok=true})
    CreateThread(function()
        while camera do
            Wait(0)
            DisableControlAction(0,200,true)
            if IsDisabledControlJustPressed(0,200) or IsControlJustPressed(0,177) then
                stopCamera()
                if opened then SetNuiFocus(true,true) SendNUIMessage({action='cameraEnd'}) end
            end
        end
    end)
end)
