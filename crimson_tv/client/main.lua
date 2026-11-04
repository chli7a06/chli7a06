DEFAULT_URL = ("https://cfx-nui-%s/html/index.html"):format(GetCurrentResourceName())
duiUrl = DEFAULT_URL
duiObj = nil
tvObj = nil
volume = 0.5
CURRENT_SCREEN = nil

local Locations = Config.Locations

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

function setDuiURL(url)
	duiUrl = url
	SetDuiUrl(duiObj, duiUrl)
end

local sfName = 'generic_texture_renderer'

local width = 1280
local height = 720

local sfHandle = nil
local txdHasBeenSet = false


function loadScaleform(scaleform)
    local scaleformHandle = RequestScaleformMovie(scaleform)

    while not HasScaleformMovieLoaded(scaleformHandle) do 
        scaleformHandle = RequestScaleformMovie(scaleform)
        Citizen.Wait(0) 
    end
    return scaleformHandle
end

function ShowScreen(data)
    CURRENT_SCREEN = data
    sfHandle = loadScaleform(sfName)
    runtimeTxd = 'crimson_tv_b_dict'

    local txd = CreateRuntimeTxd('crimson_tv_b_dict')
    duiObj = CreateDui(duiUrl, width, height)
    local dui = GetDuiHandle(duiObj)
    local tx = CreateRuntimeTextureFromDuiHandle(txd, 'crimson_tv_b_txd', dui)
    
    Citizen.Wait(10)

    PushScaleformMovieFunction(sfHandle, 'SET_TEXTURE')

    PushScaleformMovieMethodParameterString('crimson_tv_b_dict')
    PushScaleformMovieMethodParameterString('crimson_tv_b_txd')

    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(width)
    PushScaleformMovieFunctionParameterInt(height)

    PopScaleformMovieFunctionVoid()
    Citizen.CreateThread(function()
        TriggerServerEvent("crimson_tv:requestSync", data.coords)
        local tvObj = data.entity
        local screenModel = Config.Models[data.model]
        while duiObj do
            if (tvObj and sfHandle ~= nil and HasScaleformMovieLoaded(sfHandle)) then
                local pos = GetEntityCoords(tvObj)
                local scale = screenModel.Scale
                local offset = GetOffsetFromEntityInWorldCoords(tvObj, screenModel.Offset.x, screenModel.Offset.y, screenModel.Offset.z)
                if (screenModel.Target) then 
                    local id = CreateNamedRenderTargetForModel(screenModel.Target, data.model)
                    if (id ~= -1) then
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
        local screen = CURRENT_SCREEN
        local modelData = Config.Models[screen.model]
        local coords = screen.coords
        local _, lstatus = GetTelevisionLocal(coords)
        if (lstatus and lstatus.volume) then 
            SetVolume(coords, lstatus.volume)
        else
            SetVolume(coords, modelData.DefaultVolume)
        end
        while duiObj do 
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
    CURRENT_SCREEN = nil
    if CloseTVMenu then
        CloseTVMenu()
    end
    if (duiObj) then 
        DestroyDui(duiObj)
        SetScaleformMovieAsNoLongerNeeded(sfHandle)
        duiObj = nil
        sfHandle = nil 
    end
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

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    TriggerServerEvent("crimson_tv:requestUpdate")
    while true do 
        local wait = 2500
        local data = GetClosestScreen()
        if (data and not duiObj) then 
            ShowScreen(data)
        elseif ((not data or #(v3(CURRENT_SCREEN.coords) - v3(data.coords)) > 0.01 ) and duiObj) then
            HideScreen()
        end
        Citizen.Wait(wait)
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
                DeleteEntity(Locations[i].obj)
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
    local tvObj = data.entity
        
    local _, status = GetTelevision(coords)
    local screenModel = Config.Models[data.model]
    if status and status["ptv_status"] then
        local update_time = status.update_time 
        local status = status["ptv_status"]
        Citizen.Wait(1000)
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
    waitForLoad = false
    if cb then cb(1) end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then
        HideScreen()
        for i=1, #Locations do 
            DeleteEntity(Locations[i].obj)
        end
    end
end)
