-- Crimson livery locks (crm-auto). Shared so the tuner, the bill and the
-- enforcement always agree. Unlocks live in the 'crimsonLiveries' global state
-- (plate -> { [key] = true }), which only the server writes.
-- Keys: 'livery:<index>' (texture livery or mod 48) and 'mod:<slot>:<index>'.
Liveries = {}

local cfg = Config.CrimsonLiveries
local enabled = cfg ~= nil and cfg.enabled == true
local byModel = {}

local function h32(hash) return hash & 0xFFFFFFFF end

if enabled then
    for name, entry in pairs(cfg.models) do
        byModel[h32(joaat(name))] = { name = name, livery = entry.livery or {}, mods = entry.mods or {} }
    end
end

Liveries.enabled = enabled
Liveries.price = enabled and cfg.price or 0
Liveries.map = GlobalState.crimsonLiveries or {}

AddStateBagChangeHandler('crimsonLiveries', 'global', function(_, _, value)
    Liveries.map = value or {}
end)

--- Lock entry of a model (hash or name), nil when the model is not locked.
function Liveries.entry(model)
    if not enabled or not model then return end
    if type(model) == 'string' then model = joaat(model) end
    return byModel[h32(model)]
end

function Liveries.unlocks(plate)
    return Liveries.map[plate] or {}
end

function Liveries.key(slot, index)
    if slot == 'livery' then return ('livery:%d'):format(index) end
    return ('mod:%d:%d'):format(slot, index)
end

-- Tuner change key -> lock slot. Mod 48 is the mod-kit version of a livery.
local function slotOf(changeKey)
    if changeKey == 'livery' then return 'livery' end
    local mod = type(changeKey) == 'string' and tonumber(changeKey:match('^mod:(%d+)$'))
    if mod == 48 then return 'livery' end
    return mod
end

local function lockLabel(entry, slot, index)
    if slot == 'livery' then return entry.livery[index] end
    local list = entry.mods[slot]
    return list and list[index]
end

--- Unlock key a change needs, or nil when it is free or already owned.
function Liveries.needed(entry, unlocks, changeKey, value)
    if not entry or type(value) ~= 'number' then return end
    local slot = slotOf(changeKey)
    if not slot or not lockLabel(entry, slot, value) then return end
    local key = Liveries.key(slot, value)
    if not (unlocks and unlocks[key]) then return key end
end

--- Every unlock a change set needs, sorted.
function Liveries.neededAll(entry, unlocks, changes)
    local list = {}
    if not entry or type(changes) ~= 'table' then return list end
    for changeKey, value in pairs(changes) do
        local key = Liveries.needed(entry, unlocks, changeKey, value)
        if key then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

--- Every lockable key of a model with its label, sorted.
function Liveries.keys(entry)
    local list = {}
    for index, label in pairs(entry.livery) do list[#list + 1] = { key = Liveries.key('livery', index), label = label } end
    for slot, indexes in pairs(entry.mods) do
        for index, label in pairs(indexes) do list[#list + 1] = { key = Liveries.key(slot, index), label = label } end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

function Liveries.label(entry, key)
    for _, k in ipairs(Liveries.keys(entry)) do
        if k.key == key then return k.label end
    end
    return key
end

--- { entry, plate, unlocks } for a vehicle entity, nil when its model is not locked.
function Liveries.context(vehicle)
    local entry = Liveries.entry(GetEntityModel(vehicle))
    if not entry then return end
    local plate = Items.plate(GetVehicleNumberPlateText(vehicle))
    return { entry = entry, plate = plate, unlocks = Liveries.unlocks(plate) }
end

-- ox_lib property names of the mod slots that can be locked.
local propOf = { [5] = 'modFrame', [48] = 'modLivery' }

--- Puts locked, not owned liveries in an ox_lib props table back to stock.
--- Returns true when something was changed.
function Liveries.sanitizeProps(entry, unlocks, props)
    if not entry or type(props) ~= 'table' then return false end
    local changed = false
    local function check(prop, changeKey, stock)
        local value = tonumber(props[prop])
        if value and Liveries.needed(entry, unlocks, changeKey, value) then
            props[prop] = stock
            changed = true
        end
    end
    check('livery', 'livery', 0)
    check('modLivery', 'mod:48', -1)
    for slot in pairs(entry.mods) do
        if propOf[slot] then check(propOf[slot], 'mod:' .. slot, -1) end
    end
    return changed
end
