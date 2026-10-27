local opened = false
local function close()
    opened = false
    SetNuiFocus(false, false)
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
RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('request', function(data, cb)
    if not opened then cb({ ok = false, error = 'Tablet closed' }) return end
    local ok, result = pcall(lib.callback.await, 'crimson_doj:request', false, data.action, data.payload or {})
    cb(ok and result or { ok = false, error = 'Server unavailable' })
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
