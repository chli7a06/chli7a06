local opened, opening = false, false
local uiEpoch, cameraEpoch = 0, 0
local camera = nil
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
    uiEpoch = uiEpoch + 1
    opened, opening = false, false
    stopCamera()
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
