-- Stance is not part of ox_lib vehicle properties. The server shares a
-- plate -> stance map ('crimsonStance' global state); nearby vehicles are
-- matched by plate every 2s and re-applied every frame while in range.
Stance = {}

local stances = GlobalState.crimsonStance or {} -- plate -> stance
local preview = {}  -- entity -> local stance while the tuner is open
local inRange = {}  -- entity -> stance, rebuilt by the scan thread
local base = {}     -- entity -> stock wheel X offsets

local function captureBase(veh)
    local wheels = {}
    for i = 0, GetVehicleNumberOfWheels(veh) - 1 do
        wheels[i] = GetVehicleWheelXOffset(veh, i)
    end
    base[veh] = wheels
    return wheels
end

local function apply(veh, data)
    local stock = base[veh] or captureBase(veh)
    for i, x in pairs(stock) do
        local front, left = i < 2, i % 2 == 0
        local track = front and data.tf or data.tr
        local camber = front and data.cf or data.cr
        SetVehicleWheelXOffset(veh, i, left and (x - track) or (x + track))
        SetVehicleWheelYRotation(veh, i, left and camber or -camber)
    end
    SetVehicleSuspensionHeight(veh, data.h or 0.0)
    if data.w then SetVehicleWheelWidth(veh, data.w) end
end

local function reset(veh)
    local stock = base[veh]
    base[veh] = nil
    if not stock or not DoesEntityExist(veh) then return end
    for i, x in pairs(stock) do
        SetVehicleWheelXOffset(veh, i, x)
        SetVehicleWheelYRotation(veh, i, 0.0)
    end
    SetVehicleSuspensionHeight(veh, 0.0)
end

local function saved(veh)
    return stances[Items.plate(GetVehicleNumberPlateText(veh))]
end

--- Stance currently shown on a vehicle, in the tuner's slider format.
function Stance.get(veh)
    local data = preview[veh] or saved(veh)
    local out = {}
    for _, field in ipairs(Config.Stance) do out[field.id] = data and data[field.id] or field.default end
    out.w = data and data.w or GetVehicleWheelWidth(veh)
    return out
end

--- Local-only stance while previewing; nil goes back to the saved one.
function Stance.preview(veh, data)
    preview[veh] = data
    local shown = data or saved(veh)
    inRange[veh] = shown
    if not shown then reset(veh) end
end

AddStateBagChangeHandler('crimsonStance', 'global', function(_, _, value)
    stances = value or {}
end)

-- Distance first, plate second: only close vehicles cost a plate read.
CreateThread(function()
    while true do
        local coords = GetEntityCoords(cache.ped)
        local nextRange = {}
        local any = next(stances) or next(preview)
        if any then
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if #(GetEntityCoords(veh) - coords) <= Config.StanceRange then
                    local data = preview[veh] or saved(veh)
                    if data then nextRange[veh] = data end
                end
            end
        end
        for veh in pairs(base) do
            if not nextRange[veh] then
                if DoesEntityExist(veh) then reset(veh) else base[veh] = nil end
            end
        end
        for veh in pairs(preview) do
            if not DoesEntityExist(veh) then preview[veh] = nil end
        end
        inRange = nextRange
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        if next(inRange) then
            for veh, data in pairs(inRange) do
                if DoesEntityExist(veh) then apply(veh, data) else inRange[veh] = nil end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for veh in pairs(base) do reset(veh) end
end)
