TelevisionsLocal = {}
local tvMenuOpen = false
local tvMenuSelected = 1

local function SendTVMenuMessage(action, data)
    SendNUIMessage({
        action = action,
        data = data
    })
end

local function IsCloseEnoughForTVMenu(screen)
    if not screen or not screen.coords then return false end

    local maxDistance = (Config.Menu and Config.Menu.OpenDistance) or 3.0
    local screenCoords = v3(screen.coords)
    local playerCoords = GetEntityCoords(PlayerPedId())

    return #(playerCoords - screenCoords) <= maxDistance
end

function CloseTVMenu()
    if not tvMenuOpen then return end
    tvMenuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendTVMenuMessage("ptv:closeMenu", {})
end

local function RefreshTVMenu()
    if not CURRENT_SCREEN or not IsCloseEnoughForTVMenu(CURRENT_SCREEN) then
        CloseTVMenu()
        return
    end

    tvMenuSelected = math.min(math.max(tvMenuSelected, 1), 5)

    SendTVMenuMessage(tvMenuOpen and "ptv:updateMenu" or "ptv:openMenu", {
        title = (Config.Menu and Config.Menu.Title) or "Television",
        branding = Config.Menu,
        selected = tvMenuSelected,
        items = {
            {label = 'Videos', description = 'Play a video or stream on the screen.'},
            {label = 'Set Volume', description = 'Sets your TV\'s volume (For yourself).'},
            {label = 'Set Range', description = 'Sets how far this TV can be seen and heard by you.'},
            {label = 'Turn Off TV', description = 'Return the display to the Crimson standby screen.'},
            {label = 'Close Menu', description = 'Close the television controls.'},
        }
    })

    tvMenuOpen = true
end

function BroadcastMenu() 
    local _source = GetPlayerServerId(PlayerId())
    for k,v in pairs(Channels or {}) do 
        if (v.source == _source) then 
            TriggerServerEvent("crimson_tv:broadcast", nil)
            return
        end
    end 
    local input = lib.inputDialog('Live Broadcast', {'Channel Name:', 'Broadcast URL:'})
    if input and input[1] and input[2] then 
        TriggerServerEvent("crimson_tv:broadcast", {name = input[1], url = input[2]})
    end
end 

function WebBrowserMenu()
    CloseTVMenu()
    local input = lib.inputDialog('Web Browser', {'URL:'})

    if input and CURRENT_SCREEN then 
        TriggerServerEvent("crimson_tv:event", CURRENT_SCREEN, "ptv_status", {
            type = "browser",
            url = input[1]
        })
    end
    Citizen.Wait(300) 
    if CURRENT_SCREEN then
        OpenTVMenu()
    end
end

function VideoMenu()
    CloseTVMenu()
    local input = lib.inputDialog('Video Player', {'URL:'})
    if input and CURRENT_SCREEN then 
        TriggerServerEvent("crimson_tv:event", CURRENT_SCREEN, "ptv_status", {
            type = "play",
            url = input[1]
        })
    end
    Citizen.Wait(300) 
    if CURRENT_SCREEN then
        OpenTVMenu()
    end
end

function VolumeMenu()
    CloseTVMenu()
    local input = lib.inputDialog('Volume', {'Set Volume (0-100):'})
    if input and CURRENT_SCREEN and tonumber(input[1]) then 
        local coords = CURRENT_SCREEN.coords
        SetVolume(coords, tonumber(input[1])/100)
    end
    Citizen.Wait(300) 
    if CURRENT_SCREEN then
        OpenTVMenu()
    end
end

function SetTVRange(coords, num)
    local minRange = (Config.Menu and Config.Menu.MinRange) or 1.0
    local maxRange = (Config.Menu and Config.Menu.MaxRange) or 100.0
    local range = tonumber(num)

    if not range then return end
    range = math.max(minRange, math.min(maxRange, range))
    SetTelevisionLocal(coords, "range", range)

    lib.notify({
        title = 'Television',
        description = ('TV range set to %.1f meters.'):format(range),
        type = 'success'
    })
end

local function GetCurrentTVRangeForMenu(screen)
    if not screen then return Config.TVRange or 20.0 end

    local _, localData = GetTelevisionLocal(screen.coords)
    if localData and localData.range then
        return localData.range
    end

    if Config.TVRange ~= nil then
        return Config.TVRange
    end

    local modelData = Config.Models and Config.Models[screen.model]
    return (modelData and modelData.Range) or 20.0
end

function RangeMenu()
    CloseTVMenu()
    local currentRange = GetCurrentTVRangeForMenu(CURRENT_SCREEN)
    local input = lib.inputDialog('TV Range', {('Set Range (meters, current %.1f):'):format(currentRange)})
    if input and CURRENT_SCREEN and tonumber(input[1]) then
        SetTVRange(CURRENT_SCREEN.coords, tonumber(input[1]))
    end
    Citizen.Wait(300)
    if CURRENT_SCREEN then
        OpenTVMenu()
    end
end

function TurnOffTV()
    CloseTVMenu()
    if CURRENT_SCREEN then
        TriggerServerEvent("crimson_tv:event", CURRENT_SCREEN, "ptv_status", {
            type = "off"
        })
    end
end

function OpenTVMenu() 
    -- Resolve again on command: the background renderer polls less frequently.
    local screen = GetClosestScreen()
    if not screen then
        lib.notify({title = 'Crimson TV', description = 'No supported TV detected nearby. Use /tvdebug to inspect the TV model.', type = 'error'})
        return
    end
    if not IsCloseEnoughForTVMenu(screen) then
        CloseTVMenu()
        lib.notify({
            title = 'Television',
            description = 'Move closer to the TV to use the controls.',
            type = 'error'
        })
        return
    end

    if not CURRENT_SCREEN or CURRENT_SCREEN.entity ~= screen.entity then
        HideScreen()
        ShowScreen(screen)
    end

    lib.hideMenu()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    RefreshTVMenu()
end

local function PrepareTVBrowser(resetURL)
    local handle = duiObj
    if not WaitForTVDui(handle) then return nil end
    if resetURL and getDuiURL() ~= DEFAULT_URL then
        waitForLoad = true
        setDuiURL(DEFAULT_URL)
        local deadline = GetGameTimer() + 10000
        while waitForLoad do
            if duiObj ~= handle or GetGameTimer() >= deadline then return nil end
            Wait(10)
        end
    end
    if duiObj ~= handle then return nil end
    return handle
end

function PlayBrowser(data)
    if not PrepareTVBrowser(false) then return end
    setDuiURL(data.url)
end

function PlayVideo(data)
    local handle = PrepareTVBrowser(true)
    if not handle then return end
    SendDuiMessage(handle, json.encode({setVideo = true, data = data}))
end

function ResetDisplay()
    local handle = PrepareTVBrowser(true)
    if not handle then return end
    SendDuiMessage(handle, json.encode({turnOff = true}))
end

function GetTelevisionLocal(coords)
    for k,v in pairs(TelevisionsLocal) do 
        if #(v3(v.coords) - v3(coords)) < 0.01 then
            return k, v
        end
    end
end

function SetTelevisionLocal(coords, key, value)
    local index, data = GetTelevisionLocal(coords)
    if (index ~= nil) then 
        if (TelevisionsLocal[index] == nil) then 
            TelevisionsLocal[index] = {}
        end
        TelevisionsLocal[index][key] = value
    else
        index = GetGameTimer()
        while TelevisionsLocal[index] do 
            index = index + 1
            Citizen.Wait(0)
        end
        if (TelevisionsLocal[index] == nil) then 
            TelevisionsLocal[index] = {}
        end
        TelevisionsLocal[index][key] = value
    end
    TelevisionsLocal[index].coords = coords
    return index
end

RegisterNetEvent("crimson_tv:event", function(data, index, key, value) 
    Televisions = data
    local data = Televisions[index]
    local screen = CURRENT_SCREEN
    if (screen and #(v3(screen.coords) - v3(data.coords)) < 0.001) then 
        local index, data = GetTelevision(screen.coords)
        if (index) then 
            local event = value
            if (event.type == "play") then 
                local data = { url = event.url }
                if (event.channel) then
                    data = Channels[event.channel]
                    data.channel = event.channel
                end
                PlayVideo(data)
            elseif (event.type == "browser") then 
                PlayBrowser({ url = event.url })
            elseif (event.type == "off") then
                ResetDisplay()
            end 
        end
    end
    if tvMenuOpen then
        RefreshTVMenu()
    end
    SetTelevisionLocal(Televisions[index].coords, "start_time", GetGameTimer())
end)

RegisterNetEvent("crimson_tv:broadcast", function(data, index)
    Channels = data
    if CURRENT_SCREEN and duiObj and getDuiURL() == DEFAULT_URL then 
        local screen = CURRENT_SCREEN
        local _, status = GetTelevision(screen.coords)
        if (status and status.channel == index and data[index] == nil) then 
            ResetDisplay()
            Citizen.Wait(10)
        end
        SendDuiMessage(duiObj, json.encode({
            showNotification = true,
            channel = index,
            data = data[index]
        }))
    end

    if tvMenuOpen then
        RefreshTVMenu()
    end
end)

RegisterNUICallback("tvMenuAction", function(data, cb)
    cb(1)

    if not CURRENT_SCREEN then
        CloseTVMenu()
        return
    end

    local action = data.action

    if action == "navigate" then
        tvMenuSelected = tonumber(data.index) or tvMenuSelected
        return
    end

    if action == "select" then
        tvMenuSelected = tonumber(data.index) or tvMenuSelected

        if tvMenuSelected == 1 then
            VideoMenu()
        elseif tvMenuSelected == 2 then
            VolumeMenu()
        elseif tvMenuSelected == 3 then
            RangeMenu()
        elseif tvMenuSelected == 4 then
            TurnOffTV()
        elseif tvMenuSelected == 5 then
            CloseTVMenu()
        end
    end
end)

RegisterNUICallback("tvMenuClose", function(_, cb)
    cb(1)
    CloseTVMenu()
end)

RegisterCommand('tv', function()
    OpenTVMenu() 
end)

RegisterCommand("broadcast", function(source, args, raw)
    BroadcastMenu()
end)

-- Inspect map props without adding unknown models with unverified render settings.
RegisterCommand('tvdebug', function()
    -- Read the actual object under the camera crosshair rather than guessing
    -- which of the nearby furniture props is a television.
    local origin = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local destination = origin + direction * 20.0
    local probe = StartShapeTestRay(origin.x, origin.y, origin.z, destination.x, destination.y, destination.z, 16, PlayerPedId(), 7)
    local state, hit, entity
    for attempt = 1, 50 do
        local hitCoords, normal
        state, hit, hitCoords, normal, entity = GetShapeTestResult(probe)
        if state ~= 1 then break end
        Wait(0)
    end
    if state == 2 and (hit == 1 or hit == true) and entity and entity ~= 0 and IsEntityAnObject(entity) then
        local model = GetEntityModel(entity)
        print(('[crimson_tv] AIMED OBJECT model=%s supported=%s'):format(model, tostring(Config.Models[model] ~= nil)))
    else
        print('[crimson_tv] AIMED OBJECT not detected. Aim the camera centre at the TV screen and retry /tvdebug.')
    end
    local playerCoords = GetEntityCoords(PlayerPedId())
    local objects = GetGamePool('CObject')
    local nearby = {}
    for _, entity in ipairs(objects) do
        local distance = #(playerCoords - GetEntityCoords(entity))
        if distance <= 10.0 then
            local model = GetEntityModel(entity)
            nearby[#nearby + 1] = {distance = distance, model = model, supported = Config.Models[model] ~= nil}
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    print('[crimson_tv] Nearby objects (closest first):')
    for i = 1, math.min(#nearby, 15) do
        local object = nearby[i]
        print(('[crimson_tv] model=%s distance=%.2fm supported=%s'):format(object.model, object.distance, tostring(object.supported)))
    end
    local screen = GetClosestScreen()
    print(('[crimson_tv] Selected supported TV: %s; menu distance limit: %s m'):format(screen and tostring(screen.model) or 'none', (Config.Menu and Config.Menu.OpenDistance) or 3.0))
    lib.notify({title = 'Crimson TV', description = 'TV diagnostics printed in F8. Send the [crimson_tv] lines for model setup.', type = 'inform'})
end, false)
