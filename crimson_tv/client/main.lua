DEFAULT_URL = ("https://cfx-nui-%s/html/index.html"):format(GetCurrentResourceName())
duiUrl = DEFAULT_URL
duiObj = nil
tvObj = nil
volume = 0.5
CURRENT_SCREEN = nil

local Locations = Config.Locations
local screenGeneration = 0
local readyDui = nil
CRIMSON_TV_BUILD = "2026-11-04-pinned-screen-5"

local function DebugLog(message)
    if Config.Debug then print(message) end
end

local function Clamp(num, min, max)
    num = tonumber(num) or min
    if num < min then return min end
    if num > max then return max end
    return num
end

local function GetTVRange(modelData, coords)
    if coords and GetTelevisionLocal then
        local _, localData = GetTelevisionLocal(coords)
        if localData and localData.range then
            return localData.range
        end
    end

    if Config.TVRange ~= nil then
        return Config.TVRange
    end

    return (modelData and modelData.Range) or 20.0
end

local function GetLocationSpawnRange(coords)
    local spawnRange = Config.LocationSpawnRange or Config.TVRange or 20.0

    if coords and GetTelevisionLocal then
        local _, localData = GetTelevisionLocal(coords)
        if localData and localData.range then
            spawnRange = math.max(spawnRange, localData.range)
        end
    end

    return spawnRange
end

function getDuiURL()
	return duiUrl
end

function SetVolume(coords, num)
    volume = Clamp(num, 0.0, 1.0)
    SetTelevisionLocal(coords, "volume", volume)
end

function GetVolume(dist, range) 
    if not volume then return 0 end
    if not range or range <= 0 then return math.floor(Clamp(volume, 0.0, 1.0) * 100) end

    local distancePercent = Clamp(dist / range, 0.0, 1.0)
    local volumePercent = volume * (1.0 - distancePercent)
    return math.floor(Clamp(volumePercent, 0.0, 1.0) * 100)
end

-- Never poll a missing or retired DUI handle after a screen switch.
function WaitForTVDui(handle)
    if not handle or handle == 0 then return nil end
    local deadline = GetGameTimer() + 10000
    while duiObj == handle and GetGameTimer() < deadline do
        -- The local player page confirms readiness via pageLoaded. Do not call
        -- IS_DUI_AVAILABLE: the user's runtime reports invalid handle there.
        if readyDui == handle then return handle end
        Wait(10)
    end
    if duiObj == handle then
        DebugLog('[crimson_tv] TV page did not acknowledge loading within 10 seconds. Check NUI console and html/index.html dependencies.')
    end
    return nil
end

function setDuiURL(url)
    if not duiObj then return false end
    duiUrl = url
    SetDuiUrl(duiObj, duiUrl)
    return true
end

local sfName = 'generic_texture_renderer'

local width = 1280
local height = 720

local sfHandle = nil
local txdHasBeenSet = false


function loadScaleform(scaleform)
    local scaleformHandle = RequestScaleformMovie(scaleform)

    local deadline = GetGameTimer() + 10000
    while not HasScaleformMovieLoaded(scaleformHandle) do
        if GetGameTimer() >= deadline then
            SetScaleformMovieAsNoLongerNeeded(scaleformHandle)
            DebugLog('[crimson_tv] Missing scaleform: ' .. scaleform .. '. This is required only by models without a named render target.')
            return nil
        end
        Citizen.Wait(0)
    end
    return scaleformHandle
end

function ShowScreen(data)
    HideScreen()
    local generation = screenGeneration
    CURRENT_SCREEN = data
    local screenModel = Config.Models[data.model]
    DebugLog(('[crimson_tv] Opening TV model=%s renderer=%s'):format(data.model, screenModel.Target or sfName))
    local movie
    -- Named targets draw the DUI texture directly and do not use a scaleform.
    if not screenModel.Target then
        movie = loadScaleform(sfName)
        if not movie then
            if generation == screenGeneration then HideScreen() end
            return
        end
    end
    if generation ~= screenGeneration then
        if movie then SetScaleformMovieAsNoLongerNeeded(movie) end
        return
    end
    sfHandle = movie
    runtimeTxd = 'crimson_tv_b_dict'

    local txd = CreateRuntimeTxd('crimson_tv_b_dict')
    duiUrl = DEFAULT_URL
    local handle = CreateDui(duiUrl, width, height)
    if not handle or handle == 0 then
        DebugLog('[crimson_tv] Could not create the TV browser.')
        HideScreen()
        return
    end
    duiObj = handle
    if not WaitForTVDui(handle) then
        if generation == screenGeneration then HideScreen() end
        return
    end
    local dui = GetDuiHandle(handle)
    local tx = CreateRuntimeTextureFromDuiHandle(txd, 'crimson_tv_b_txd', dui)
    
    if generation ~= screenGeneration then return end

    if movie then
    PushScaleformMovieFunction(movie, 'SET_TEXTURE')

    PushScaleformMovieMethodParameterString('crimson_tv_b_dict')
    PushScaleformMovieMethodParameterString('crimson_tv_b_txd')

    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(width)
    PushScaleformMovieFunctionParameterInt(height)

    PopScaleformMovieFunctionVoid()
    end
    Citizen.CreateThread(function()
        TriggerServerEvent("crimson_tv:requestSync", data.coords)
        local screenModel = Config.Models[data.model]
        local targetId
        if screenModel.Target then
            targetId = CreateNamedRenderTargetForModel(screenModel.Target, data.model)
            DebugLog(('[crimson_tv] Render target %s model=%s linked=%s id=%s'):format(screenModel.Target, data.model, tostring(IsNamedRendertargetLinked(data.model)), tostring(targetId)))
        end
        while generation == screenGeneration and duiObj == handle do
            local tvObj = data.entity -- A streamed map prop can get a new handle.
            if tvObj and DoesEntityExist(tvObj) and (screenModel.Target or (movie and HasScaleformMovieLoaded(movie))) then
                local pos = GetEntityCoords(tvObj)
                local scale = screenModel.Scale
                local offset = GetOffsetFromEntityInWorldCoords(tvObj, screenModel.Offset.x, screenModel.Offset.y, screenModel.Offset.z)
                if (screenModel.Target) then 
                    local id = targetId
                    if id and id ~= 0 and id ~= -1 then
                        RenderScaleformTV(id, sfHandle, tvObj)
                    end
                else
                    local hz = GetEntityHeading(tvObj)
                    DrawScaleformMovie_3dSolid(sfHandle, offset, 0.0, 0.0, -hz, 2.0, 2.0, 2.0, scale * 1, scale * (9/16), 2)
                end
            end
            Citizen.Wait(0)
        end
    end)
    Citizen.CreateThread(function()
        local screen = data
        local modelData = Config.Models[screen.model]
        local coords = screen.coords
        local _, lstatus = GetTelevisionLocal(coords)
        if (lstatus and lstatus.volume) then 
            SetVolume(coords, lstatus.volume)
        else
            SetVolume(coords, modelData.DefaultVolume)
        end
        while generation == screenGeneration and duiObj == handle do
            local range = GetTVRange(modelData, coords)
            local pcoords = GetEntityCoords(PlayerPedId())
            local dist = #(coords - pcoords)
            SendDuiMessage(duiObj, json.encode({
                setVolume = true,
                data = GetVolume(dist, range, volume)
            }))
            Citizen.Wait(100)
        end
    end)
end

function HideScreen()
    screenGeneration = screenGeneration + 1
    CURRENT_SCREEN = nil
    shouldDraw = false
    readyDui = nil
    waitForLoad = false
    if CloseTVMenu then CloseTVMenu() end
    local oldDui, oldMovie = duiObj, sfHandle
    duiObj, sfHandle = nil, nil
    if oldDui and oldDui ~= 0 then DestroyDui(oldDui) end
    if oldMovie then SetScaleformMovieAsNoLongerNeeded(oldMovie) end
end

function GetClosestScreen()
    local objPool = GetGamePool('CObject')
    local closest = {dist = -1}
    local pcoords = GetEntityCoords(PlayerPedId())
    for i=1, #objPool do
        local entity = objPool[i]
        local model = GetEntityModel(entity)
        local data = Config.Models[model]
        if (data) then 
            local coords = GetEntityCoords(entity)
            local dist = #(pcoords-coords)
            if (dist < closest.dist or closest.dist < 0) and dist < GetTVRange(data, coords) then 
                closest = {dist = dist, coords = coords, model = model, entity = entity}
            end
        end
    end
    return (closest.entity and closest or nil)
end

-- Keep the active TV unless another is meaningfully closer. Small movements
-- between adjacent props must not repeatedly destroy the playing browser.
function GetStableScreen()
    local nearest = GetClosestScreen()
    local current = CURRENT_SCREEN
    if not current then return nearest end
    local modelData = Config.Models[current.model]
    if not modelData then return nearest end
    local coords = current.coords
    local distance = #(GetEntityCoords(PlayerPedId()) - coords)
    local margin = math.max(0, tonumber(Config.ScreenSwitchDistance) or 2.0)
    if distance > GetTVRange(modelData, coords) + margin then return nearest end

    local valid = DoesEntityExist(current.entity)
        and GetEntityModel(current.entity) == current.model
        and #(GetEntityCoords(current.entity) - coords) < 0.25
    if not valid then
        -- Rebind the same physical TV instead of destroying its playing DUI.
        for _, entity in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(entity) == current.model and #(GetEntityCoords(entity) - coords) < 0.25 then
                current.entity = entity
                current.missingSince = nil
                return current
            end
        end
        current.missingSince = current.missingSince or GetGameTimer()
        local grace = math.max(0, tonumber(Config.ScreenStreamGraceMs) or 5000)
        if GetGameTimer() - current.missingSince < grace then return current end
        return nearest
    end
    current.missingSince = nil
    if Config.PinActiveScreen ~= false then return current end
    if nearest and nearest.entity ~= current.entity and nearest.dist + margin < distance then
        return nearest
    end
    return current
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    TriggerServerEvent("crimson_tv:requestUpdate")
    while true do
        local data = GetStableScreen()
        if data then
            if not duiObj or not CURRENT_SCREEN or CURRENT_SCREEN.entity ~= data.entity then
                -- ShowScreen releases the old session and starts the replacement
                -- in this iteration, avoiding the former blank polling interval.
                ShowScreen(data)
            end
        elseif CURRENT_SCREEN then
            HideScreen()
        end
        Citizen.Wait(500)
    end
end)

Citizen.CreateThread(function()
    while true do 
        local wait = 2500
        for i=1, #Locations do 
            local data = Locations[i]
            local locationCoords = v3(data.Position)
            local spawnRange = GetLocationSpawnRange(locationCoords)
            local dist = #(GetEntityCoords(PlayerPedId()) - locationCoords) 
            if not Locations[i].obj and dist < spawnRange then 
                LoadModel(data.Model)
                Locations[i].obj = CreateObject(data.Model, data.Position.x, data.Position.y, data.Position.z)
                SetEntityHeading(Locations[i].obj, data.Position.w)
                FreezeEntityPosition(Locations[i].obj, true)
            elseif Locations[i].obj and dist > spawnRange then
                if Locations[i].obj then DeleteEntity(Locations[i].obj) end
                Locations[i].obj = nil
            end
        end
        Citizen.Wait(wait)
    end
end)

RegisterNetEvent("crimson_tv:requestUpdate", function(data)
    Televisions = data.Televisions
    Channels = data.Channels
end)

RegisterNetEvent("crimson_tv:requestSync", function(coords, data)
    local screen = CURRENT_SCREEN
    if not screen or not duiObj or #(v3(screen.coords) - v3(coords)) > 0.01 then return end
    local generation = screenGeneration
    local _, status = GetTelevision(coords)
    if status and status["ptv_status"] then
        local update_time = status.update_time 
        local status = status["ptv_status"]
        Citizen.Wait(1000)
        if generation ~= screenGeneration then return end
        if status.type == "play" then
            if (status.channel and Channels[status.channel]) then 
                PlayVideo({url = Channels[status.channel].url, channel = status.channel})
            elseif (status.url) then
                local time = math.floor(data.current_time - update_time)
                PlayVideo({url = status.url, time = time})
            end
        elseif (status.type == "browser") then 
            PlayBrowser({ url = status.url })
        elseif (status.type == "off") then
            ResetDisplay()
        end
    end
end)



RegisterNUICallback("pageLoaded", function(_, cb)
    readyDui = duiObj
    DebugLog("[crimson_tv] TV page ready (" .. CRIMSON_TV_BUILD .. ")")
    waitForLoad = false
    if cb then cb(1) end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then
        HideScreen()
        for i=1, #Locations do 
            if Locations[i].obj then DeleteEntity(Locations[i].obj) end
        end
    end
end)
