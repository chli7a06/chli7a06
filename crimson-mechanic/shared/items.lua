-- Change keys, validation and pricing. Loaded on both sides so the client
-- estimate and the server bill always agree; the server never trusts a price.
Items = {}

local partsByMod, allowedMods = {}, { [23] = true, [24] = true }
for _, part in ipairs(Config.Parts) do
    partsByMod[part.mod] = part
    allowedMods[part.mod] = true
end
for mod in pairs(Config.Performance) do allowedMods[mod] = true end

local stanceById = {}
for _, field in ipairs(Config.Stance) do stanceById[field.id] = field end

-- model hash -> allowed engine sounds (first = stock)
local soundsByModel, knownSounds = {}, {}
for model, list in pairs(Config.EngineSounds or {}) do
    soundsByModel[joaat(model) & 0xFFFFFFFF] = list
    for _, s in ipairs(list) do knownSounds[s.v] = true end
end
Items.soundsByModel = soundsByModel

--- Sound options for a model hash, or nil when the model has no swaps.
function Items.soundOptions(modelHash)
    return modelHash and soundsByModel[modelHash & 0xFFFFFFFF]
end

--- True when the sound is one of the options for that model.
function Items.soundAllowed(modelHash, sound)
    for _, s in ipairs(Items.soundOptions(modelHash) or {}) do
        if s.v == sound then return true end
    end
    return false
end

-- plate -> { [sound] = true }: exhaust systems a plate has paid the unlock for.
-- Only the server writes it ('crimsonSoundUnlocks' global state).
Items.soundUnlocks = GlobalState.crimsonSoundUnlocks or {}
AddStateBagChangeHandler('crimsonSoundUnlocks', 'global', function(_, _, value)
    Items.soundUnlocks = value or {}
end)

--- True when fitting this sound on the vehicle still needs the one-time unlock.
--- The stock sound and sounds the plate already owns are free of it.
function Items.soundNeedsUnlock(vehicle, sound)
    if not vehicle or type(sound) ~= 'string' then return false end
    local options = Items.soundOptions(GetEntityModel(vehicle))
    if not options or options[1].v == sound then return false end
    local owned = Items.soundUnlocks[Items.plate(GetVehicleNumberPlateText(vehicle))]
    return not (owned and owned[sound])
end

Items.partsByMod = partsByMod

function Items.plate(text)
    return (tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function int(value, min, max)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < min or value > max then return end
    return math.floor(value)
end

local function rgb(value)
    if type(value) ~= 'table' then return end
    local r, g, b = int(value[1], 0, 255), int(value[2], 0, 255), int(value[3], 0, 255)
    if r and g and b then return { r, g, b } end
end

local function bool(value)
    if value == true or value == false then return value end
end

local simple = {
    livery = function(v) return int(v, -1, 100) end,
    wheelType = function(v) return int(v, -1, 12) end,
    customTyres = bool,
    turbo = bool,
    repair = bool,
    pearl = function(v) return int(v, 0, 255) end,
    wheelColor = function(v) return int(v, 0, 255) end,
    interior = function(v) return int(v, 0, 255) end,
    dashboard = function(v) return int(v, 0, 255) end,
    windowTint = function(v) return int(v, 0, 6) end,
    plateIndex = function(v) return int(v, 0, 12) end,
    xenon = function(v)
        v = int(v, -1, 255)
        if v and (v <= 12 or v == 255) then return v end
    end,
    neonColor = rgb,
    engineSound = function(v)
        if type(v) == 'string' and knownSounds[v] then return v end
    end,
    smoke = function(v)
        if v == false then return false end
        return rgb(v)
    end,
    neon = function(v)
        if type(v) ~= 'table' then return end
        local out = {}
        for i = 1, 4 do
            if type(v[i]) ~= 'boolean' then return end
            out[i] = v[i]
        end
        return out
    end,
    stance = function(v)
        if type(v) ~= 'table' then return end
        local out = {}
        for id, field in pairs(stanceById) do
            local n = tonumber(v[id]) or field.default
            out[id] = math.floor(math.max(field.min, math.min(field.max, n)) * 1000 + 0.5) / 1000
        end
        local w = tonumber(v.w)
        if w then out.w = math.floor(math.max(0.3, math.min(2.0, w)) * 1000 + 0.5) / 1000 end
        return out
    end,
}

-- Paint is either a palette index { t, c } or a custom colour { t, rgb = { r, g, b } }.
local function paint(v)
    if type(v) ~= 'table' then return end
    local t = int(v.t, 0, 6)
    if not t then return end
    if v.rgb ~= nil then
        local custom = rgb(v.rgb)
        if custom then return { t = t, rgb = custom } end
        return
    end
    local c = int(v.c, 0, 255)
    if c then return { t = t, c = c } end
end
simple.paint1, simple.paint2 = paint, paint

--- Returns a cleaned copy of the value, or nil if the key/value is not valid.
function Items.sanitize(key, value)
    if type(key) ~= 'string' then return end
    local check = simple[key]
    if check then return check(value) end

    local mod = key:match('^mod:(%d+)$')
    if mod then
        if not allowedMods[tonumber(mod)] then return end
        return int(value, -1, 255)
    end

    local extra = key:match('^extra:(%d+)$')
    if extra then
        if not int(extra, 0, 20) then return end
        return bool(value)
    end
end

--- Cleans a whole change set. Fails entirely if any entry is invalid.
function Items.sanitizeAll(changes)
    if type(changes) ~= 'table' then return end
    local out, count = {}, 0
    for key, value in pairs(changes) do
        local clean = Items.sanitize(key, value)
        if clean == nil then return end
        count = count + 1
        if count > 150 then return end
        out[key] = clean
    end
    return out, count
end

local function basePrice(key, value)
    local prices = Config.Prices
    local mod = key:match('^mod:(%d+)$')
    if mod then
        mod = tonumber(mod)
        local perf = Config.Performance[mod]
        if perf then return perf.base + perf.perLevel * math.max(0, value or 0) end
        if mod == 23 or mod == 24 then return prices.rims end
        local part = partsByMod[mod]
        return (part and part.price) or (mod == 48 and prices.livery) or prices.parts
    end
    if key:find('^extra:') then return prices.extras end
    return prices[key] or 0
end

--- ctx (Liveries.context) adds the unlock price to a Crimson livery the plate doesn't own yet;
--- vehicle adds the exhaust system unlock the same way.
function Items.price(key, value, ctx, vehicle)
    local price = basePrice(key, value)
    if ctx and Liveries.needed(ctx.entry, ctx.unlocks, key, value) then price = price + Liveries.price end
    if key == 'engineSound' and Items.soundNeedsUnlock(vehicle, value) then price = price + (Config.SoundUnlockPrice or 0) end
    return price
end

function Items.total(changes, ctx, vehicle)
    local total = 0
    for key, value in pairs(changes) do total = total + Items.price(key, value, ctx, vehicle) end
    return total
end

function Items.same(a, b)
    local ta = type(a)
    if ta ~= type(b) then return false end
    if ta == 'number' then return math.abs(a - b) < 0.0005 end
    if ta ~= 'table' then return a == b end
    for k, v in pairs(a) do
        if not Items.same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- Keys that must be applied before the rest (wheel type resets rims, rims reset tyres).
local priority = { wheelType = 1, ['mod:23'] = 2, ['mod:24'] = 2, customTyres = 3 }

function Items.ordered(changes)
    local keys = {}
    for key in pairs(changes) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local pa, pb = priority[a] or 2, priority[b] or 2
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    return keys
end

--- Server-side cart lines: client labels are cosmetic, prices are recomputed.
function Items.lines(changes, clientLines, ctx, vehicle)
    local labels = {}
    if type(clientLines) == 'table' then
        for _, line in ipairs(clientLines) do
            if type(line) == 'table' and type(line.key) == 'string' and type(line.label) == 'string' then
                labels[line.key] = line.label:sub(1, 80)
            end
        end
    end
    local lines = {}
    for _, key in ipairs(Items.ordered(changes)) do
        lines[#lines + 1] = { key = key, label = labels[key] or key, price = Items.price(key, changes[key], ctx, vehicle) }
    end
    return lines
end
