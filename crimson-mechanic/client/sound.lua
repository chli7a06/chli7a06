-- Engine sound swaps are not part of ox_lib vehicle properties. The server shares a
-- plate -> sound map ('crimsonSound' global state); the audio override is client
-- side, so every client forces it on streamed vehicles whose model has swaps.
Sound = {}

local sounds = GlobalState.crimsonSound or {} -- plate -> sound
local preview = {} -- entity -> sound while the tuner is open
local applied = {} -- entity -> sound currently forced by us

local function stock(veh)
    local list = Items.soundOptions(GetEntityModel(veh))
    return list and list[1].v
end

local function saved(veh)
    local sound = sounds[Items.plate(GetVehicleNumberPlateText(veh))]
    if sound and Items.soundAllowed(GetEntityModel(veh), sound) then return sound end
end

-- What the vehicle should sound like right now; nil = leave it alone.
local function wanted(veh)
    local sound = preview[veh] or saved(veh)
    if sound then return sound end
    if applied[veh] then return stock(veh) end -- a swap was removed, go back to stock
end

local function force(veh)
    local sound = wanted(veh)
    if not sound or applied[veh] == sound then return end
    ForceUseAudioGameObject(veh, sound)
    applied[veh] = sound
end

--- Sound currently on the vehicle, in the tuner's option format.
function Sound.get(veh)
    return preview[veh] or saved(veh) or stock(veh)
end

--- Local-only sound while previewing; nil goes back to the saved one.
function Sound.preview(veh, sound)
    preview[veh] = sound
    if DoesEntityExist(veh) then force(veh) end
end

AddStateBagChangeHandler('crimsonSound', 'global', function(_, _, value)
    sounds = value or {}
end)

-- Cheap scan: only models that have swaps configured are looked at.
CreateThread(function()
    while true do
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if Items.soundOptions(GetEntityModel(veh)) then force(veh) end
        end
        for veh in pairs(applied) do
            if not DoesEntityExist(veh) then applied[veh], preview[veh] = nil, nil end
        end
        Wait(1500)
    end
end)
