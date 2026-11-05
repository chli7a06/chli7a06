-- Tuner session: live preview on the real vehicle + orbit camera (ported from
-- jobs_creator's garage dock). Nothing is saved here; callers decide whether
-- the preview is billed, sent as a request, or reverted.
Tuner = {}

local session, serial = nil, 0
local L = Lang.ui

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- ------------------------------------------------------------
-- Applying changes
-- ------------------------------------------------------------

local function isBike(veh) return GetVehicleClass(veh) == 8 end

local appliers = {
    livery = function(veh, v) SetVehicleLivery(veh, v) end,
    wheelType = function(veh, v)
        SetVehicleWheelType(veh, v)
        SetVehicleMod(veh, 23, -1, false)
        if isBike(veh) then SetVehicleMod(veh, 24, -1, false) end
    end,
    customTyres = function(veh, v)
        SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), v)
        if isBike(veh) then SetVehicleMod(veh, 24, GetVehicleMod(veh, 24), v) end
    end,
    smoke = function(veh, v)
        ToggleVehicleMod(veh, 20, v ~= false)
        if v then SetVehicleTyreSmokeColor(veh, v[1], v[2], v[3]) end
    end,
    paint1 = function(veh, v)
        local pearl, wheel = GetVehicleExtraColours(veh)
        local _, secondary = GetVehicleColours(veh)
        SetVehicleModColor_1(veh, v.t, 0, 0)
        if v.rgb then
            SetVehicleCustomPrimaryColour(veh, v.rgb[1], v.rgb[2], v.rgb[3])
        else
            ClearVehicleCustomPrimaryColour(veh)
            SetVehicleColours(veh, v.c, secondary)
        end
        SetVehicleExtraColours(veh, pearl, wheel)
    end,
    paint2 = function(veh, v)
        local primary = GetVehicleColours(veh)
        SetVehicleModColor_2(veh, v.t, 0)
        if v.rgb then
            SetVehicleCustomSecondaryColour(veh, v.rgb[1], v.rgb[2], v.rgb[3])
        else
            ClearVehicleCustomSecondaryColour(veh)
            SetVehicleColours(veh, primary, v.c)
        end
    end,
    pearl = function(veh, v)
        local _, wheel = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, v, wheel)
    end,
    wheelColor = function(veh, v)
        local pearl = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, pearl, v)
    end,
    interior = function(veh, v) SetVehicleInteriorColor(veh, v) end,
    dashboard = function(veh, v) SetVehicleDashboardColor(veh, v) end,
    windowTint = function(veh, v) SetVehicleWindowTint(veh, v) end,
    plateIndex = function(veh, v) SetVehicleNumberPlateTextIndex(veh, v) end,
    turbo = function(veh, v) ToggleVehicleMod(veh, 18, v) end,
    xenon = function(veh, v)
        ToggleVehicleMod(veh, 22, v ~= -1)
        if v ~= -1 then SetVehicleXenonLightsColor(veh, v) end
    end,
    neon = function(veh, v)
        for i = 1, 4 do SetVehicleNeonLightEnabled(veh, i - 1, v[i]) end
    end,
    neonColor = function(veh, v) SetVehicleNeonLightsColour(veh, v[1], v[2], v[3]) end,
    stance = function(veh, v) Stance.preview(veh, v) end,
    engineSound = function(veh, v) Sound.preview(veh, v) end,
    repair = function() end, -- applied on install only, damage can't be previewed back
}

local function applyKey(veh, key, value)
    local handler = appliers[key]
    if handler then return handler(veh, value) end

    local mod = key:match('^mod:(%d+)$')
    if mod then
        mod = tonumber(mod)
        local custom = (mod == 23 or mod == 24) and GetVehicleModVariation(veh, mod) or false
        SetVehicleMod(veh, mod, value, custom)
        return
    end

    local extra = key:match('^extra:(%d+)$')
    if extra then
        -- GTA repairs the whole car when an extra is toggled; a preview must never do that
        SetVehicleAutoRepairDisabled(veh, true)
        SetVehicleExtra(veh, tonumber(extra), not value)
        SetVehicleAutoRepairDisabled(veh, false)
    end
end

--- Puts a vehicle back exactly as snapshotted. ox_lib restores the general
--- properties, then our own keys are re-applied because ox_lib skips paint
--- finishes on palette colours and extras outside 1-15.
local function restore(veh, snap, keys)
    Stance.preview(veh, nil)
    Sound.preview(veh, nil)
    if not snap or not DoesEntityExist(veh) then return end
    SetVehicleModKit(veh, 0)
    lib.setVehicleProperties(veh, snap.props)

    local list = snap.orig
    if keys then
        local want = {}
        for _, key in ipairs(keys) do want[key] = true end
        if want.wheelType then want['mod:23'], want['mod:24'], want.customTyres = true, true, true end
        list = {}
        for key in pairs(want) do list[key] = snap.orig[key] end
    end
    for _, key in ipairs(Items.ordered(list)) do
        if key ~= 'stance' and key ~= 'repair' and key ~= 'engineSound' then applyKey(veh, key, list[key]) end
    end
end

-- The server asks for an undo (cancel, decline, refund, disconnect); only the
-- current owner of the vehicle can make it stick, so every client checks.
AddStateBagChangeHandler('crimsonRevert', nil, function(bagName, _, value)
    if not value then return end
    local found, veh = pcall(lib.waitFor, function()
        local entity = GetEntityFromStateBagName(bagName)
        if entity > 0 then return entity end
    end, nil, 10000)
    if not found or not veh then return end

    Stance.preview(veh, nil)
    Sound.preview(veh, nil)
    for _ = 1, 10 do
        if not DoesEntityExist(veh) then return end
        if NetworkGetEntityOwner(veh) == cache.playerId then
            restore(veh, value)
            Entity(veh).state:set('crimsonRevert', nil, true)
            return
        end
        Wait(400)
    end
end)

-- ------------------------------------------------------------
-- Catalog (what the NUI lists for this vehicle)
-- ------------------------------------------------------------

local function opt(v, l, hex, p)
    return { v = v, l = l, hex = hex, p = p }
end

local function hexOf(rgb)
    return ('#%02x%02x%02x'):format(rgb[1], rgb[2], rgb[3])
end

local toggles = { opt(false, L.off), opt(true, L.on) }
local colorOptions, neonOptions, smokeOptions, xenonOptions = {}, {}, { opt(false, L.off, '#2a2e36') }, {}
for i, c in ipairs(Config.Colors) do colorOptions[i] = opt(c.v, c.l, c.hex) end
for i, c in ipairs(Config.NeonColors) do neonOptions[i] = opt(c.rgb, c.l, hexOf(c.rgb)) end
for _, c in ipairs(Config.SmokeColors) do smokeOptions[#smokeOptions + 1] = opt(c.rgb, c.l, hexOf(c.rgb)) end
for i, c in ipairs(Config.XenonColors) do xenonOptions[i] = opt(c.v, c.l, c.hex) end
local wheelTypeOptions = {}
for i, w in ipairs(Config.WheelTypes) do wheelTypeOptions[i] = opt(w.v, w.l) end

local categoryCams = {
    parts = 'default', wheels = 'wheel', paint = 'default', lights = 'front',
    extras = 'default', performance = 'engine', stance = 'wheel', repair = 'default',
}

local function modOptions(veh, mod, fallback, priced)
    local count = GetNumVehicleMods(veh, mod)
    if count <= 0 then return end
    local key = 'mod:' .. mod
    local list = { opt(-1, L.stock, nil, priced and Items.price(key, -1) or nil) }
    for i = 0, count - 1 do
        local label
        if priced then
            label = L.level:format(i + 1)
        else
            local text = GetModTextLabel(veh, mod, i)
            text = text and GetLabelText(text)
            label = (text and text ~= 'NULL' and text ~= '') and text or ('%s %d'):format(fallback, i + 1)
        end
        list[#list + 1] = opt(i, label, nil, priced and Items.price(key, i) or nil)
    end
    return list
end

local function paintType(t)
    t = tonumber(t) or 0
    return (t >= 0 and t <= 5) and t or 0
end

local function paintValue(veh, primary)
    if primary then
        local t = paintType(GetVehicleModColor_1(veh))
        if GetIsVehiclePrimaryColourCustom(veh) then return { t = t, rgb = { GetVehicleCustomPrimaryColour(veh) } } end
        return { t = t, c = (GetVehicleColours(veh)) }
    end
    local t = paintType(GetVehicleModColor_2(veh))
    if GetIsVehicleSecondaryColourCustom(veh) then return { t = t, rgb = { GetVehicleCustomSecondaryColour(veh) } } end
    local _, secondary = GetVehicleColours(veh)
    return { t = t, c = secondary }
end

-- Crimson liveries the plate doesn't own: marked locked, and priced with the
-- unlock only at a shop that sells them (any other shop refuses them in setKey).
local function markLocked(s, key, options)
    if not s.ctx then return options end
    local any = false
    for _, o in ipairs(options) do
        if Liveries.needed(s.ctx.entry, s.ctx.unlocks, key, o.v) then
            any = true
            o.l = (s.shop.liveries and L.unlock or L.locked):format(o.l)
        end
    end
    if any and s.shop.liveries then
        for _, o in ipairs(options) do o.p = Items.price(key, o.v, s.ctx) end
    end
    return options
end

local builders = {}

function builders.parts(veh, add, s)
    for _, part in ipairs(Config.Parts) do
        local options = modOptions(veh, part.mod, part.label)
        if options then
            local key = 'mod:' .. part.mod
            add({ key = key, label = part.label, type = 'options', options = markLocked(s, key, options), value = GetVehicleMod(veh, part.mod), cam = part.cam })
        end
    end
    local liveries = GetVehicleLiveryCount(veh)
    if liveries > 0 then
        local options = {}
        for i = 0, liveries - 1 do
            local text = GetLiveryName(veh, i)
            text = text and GetLabelText(text)
            local label = (text and text ~= 'NULL' and text ~= '') and text or ('%s %d'):format(L.labels.livery, i + 1)
            options[#options + 1] = opt(i, label)
        end
        add({ key = 'livery', label = L.labels.livery, type = 'options', options = markLocked(s, 'livery', options), value = GetVehicleLivery(veh), cam = 'side' })
    end
end

function builders.wheels(veh, add)
    local bike = isBike(veh)
    if not bike then
        add({ key = 'wheelType', label = L.labels.wheelType, type = 'options', options = wheelTypeOptions, value = GetVehicleWheelType(veh), cam = 'wheel' })
    end
    local rims = modOptions(veh, 23, L.labels.rims)
    if rims then add({ key = 'mod:23', label = L.labels.rims, type = 'options', options = rims, value = GetVehicleMod(veh, 23), cam = 'wheel' }) end
    if bike then
        local rear = modOptions(veh, 24, L.labels.rearRims)
        if rear then add({ key = 'mod:24', label = L.labels.rearRims, type = 'options', options = rear, value = GetVehicleMod(veh, 24), cam = 'rear' }) end
    end
    add({ key = 'customTyres', label = L.labels.customTyres, type = 'options', options = toggles, value = GetVehicleModVariation(veh, 23) == true, cam = 'wheel' })
    add({ key = 'smoke', label = L.labels.smoke, type = 'swatch', custom = true, options = smokeOptions, value = IsToggleModOn(veh, 20) and { GetVehicleTyreSmokeColor(veh) } or false, cam = 'wheel' })
end

function builders.paint(veh, add)
    local pearl, wheel = GetVehicleExtraColours(veh)
    local tint = GetVehicleWindowTint(veh)
    add({ key = 'paint1', label = L.labels.paint1, type = 'paint', custom = true, types = Config.PaintTypes, options = colorOptions, value = paintValue(veh, true) })
    add({ key = 'paint2', label = L.labels.paint2, type = 'paint', custom = true, types = Config.PaintTypes, options = colorOptions, value = paintValue(veh, false) })
    add({ key = 'pearl', label = L.labels.pearl, type = 'swatch', options = colorOptions, value = pearl })
    add({ key = 'wheelColor', label = L.labels.wheelColor, type = 'swatch', options = colorOptions, value = wheel, cam = 'wheel' })
    add({ key = 'interior', label = L.labels.interior, type = 'swatch', options = colorOptions, value = GetVehicleInteriorColor(veh), cam = 'interior' })
    add({ key = 'dashboard', label = L.labels.dashboard, type = 'swatch', options = colorOptions, value = GetVehicleDashboardColour(veh), cam = 'interior' })
    add({ key = 'windowTint', label = L.labels.windowTint, type = 'options', options = Config.WindowTints, value = tint < 0 and 0 or tint, cam = 'side' })
    add({ key = 'plateIndex', label = L.labels.plateIndex, type = 'options', options = Config.PlateStyles, value = GetVehicleNumberPlateTextIndex(veh), cam = 'rear' })
end

function builders.lights(veh, add)
    local xenon = -1
    if IsToggleModOn(veh, 22) then
        xenon = GetVehicleXenonLightsColor(veh)
        if xenon < 0 or (xenon > 12 and xenon ~= 255) then xenon = 255 end
    end
    add({ key = 'xenon', label = L.labels.xenon, type = 'swatch', options = xenonOptions, value = xenon, cam = 'front' })
    local sides = {}
    for i = 0, 3 do sides[i + 1] = IsVehicleNeonLightEnabled(veh, i) == true end
    add({ key = 'neon', label = L.labels.neon, type = 'multi', fields = L.neon_sides, value = sides, cam = 'side' })
    add({ key = 'neonColor', label = L.labels.neonColor, type = 'swatch', custom = true, options = neonOptions, value = { GetVehicleNeonLightsColour(veh) }, cam = 'side' })
end

function builders.extras(veh, add)
    for id = 0, 20 do
        if DoesExtraExist(veh, id) then
            local on = IsVehicleExtraTurnedOn(veh, id)
            add({ key = 'extra:' .. id, label = L.labels.extra:format(id), type = 'options', options = toggles, value = on == true or on == 1 })
        end
    end
end

local perfOrder = {}
for mod in pairs(Config.Performance) do perfOrder[#perfOrder + 1] = mod end
table.sort(perfOrder)

function builders.performance(veh, add, s)
    for _, mod in ipairs(perfOrder) do
        local options = modOptions(veh, mod, Config.Performance[mod].label, true)
        if options then
            add({ key = 'mod:' .. mod, label = Config.Performance[mod].label, type = 'options', options = options, value = GetVehicleMod(veh, mod) })
        end
    end
    add({ key = 'turbo', label = L.labels.turbo, type = 'options', options = toggles, value = IsToggleModOn(veh, 18) == true })

    -- only shops that sell exhaust systems list them (the server refuses them elsewhere);
    -- sounds the plate doesn't own yet carry the one-time unlock
    local sounds = s.shop.sounds and Items.soundOptions(GetEntityModel(veh))
    if sounds then
        local options = {}
        for i, sound in ipairs(sounds) do
            local label = Items.soundNeedsUnlock(veh, sound.v) and L.unlock:format(sound.l) or sound.l
            options[i] = opt(sound.v, label, nil, Items.price('engineSound', sound.v, nil, veh))
        end
        add({ key = 'engineSound', label = L.labels.engineSound, type = 'options', options = options, value = Sound.get(veh) })
    end
end

function builders.stance(veh, add)
    local fields = {}
    for i, f in ipairs(Config.Stance) do fields[i] = f end
    if GetVehicleMod(veh, 23) ~= -1 then
        fields[#fields + 1] = { id = 'w', label = L.wheel_width, min = 0.5, max = 1.5, step = 0.01 }
    end
    add({ key = 'stance', label = L.labels.stance, type = 'sliders', fields = fields, value = Stance.get(veh) })
end

function builders.repair(veh, add, s)
    local damaged = GetVehicleBodyHealth(veh) < 995.0 or GetVehicleEngineHealth(veh) < 995.0
    if damaged or s.changes.repair then
        add({ key = 'repair', label = L.labels.repair, type = 'options', options = { opt(false, L.off), opt(true, L.full_repair) }, value = s.changes.repair == true })
    end
end

local function buildCatalog(s)
    local categories, items = {}, {}
    for _, cat in ipairs(Config.Categories) do
        if s.shop.categorySet[cat.id] then
            local list = {}
            builders[cat.id](s.vehicle, function(item)
                item.cat = cat.id
                item.cam = item.cam or categoryCams[cat.id]
                item.price = Items.price(item.key, 0)
                list[#list + 1] = item
                items[item.key] = item
            end, s)
            if #list > 0 then categories[#categories + 1] = { id = cat.id, label = cat.label, items = list } end
        end
    end
    return categories, items
end

local function diff(s)
    for key, item in pairs(s.items) do
        if s.orig[key] == nil then
            -- repair only shows up once requested, its baseline is always "not repaired"
            if key == 'repair' then s.orig[key] = false else s.orig[key] = item.value end
        end
        if Items.same(item.value, s.orig[key]) then
            s.changes[key] = nil
        else
            s.changes[key] = item.value
        end
    end
end

local function validOption(item, value)
    -- custom RGB is already range-checked by Items.sanitize
    if item.custom and type(value) == 'table' and item.type == 'swatch' then return true end
    if item.type == 'options' or item.type == 'swatch' then
        for _, o in ipairs(item.options) do
            if Items.same(o.v, value) then return true end
        end
        return false
    elseif item.type == 'paint' then
        local t, c = false, value.rgb ~= nil
        for _, o in ipairs(item.types) do if o.v == value.t then t = true break end end
        if not c then
            for _, o in ipairs(item.options) do if o.v == value.c then c = true break end end
        end
        return t and c
    end
    return true
end

local function describe(item, value)
    if item.type == 'paint' then
        local t, c = '', value.rgb and hexOf(value.rgb):upper() or tostring(value.c)
        for _, o in ipairs(item.types) do if o.v == value.t then t = o.l end end
        if not value.rgb then
            for _, o in ipairs(item.options) do if o.v == value.c then c = o.l end end
        end
        return ('%s %s'):format(t, c)
    elseif item.type == 'multi' then
        local on = {}
        for i, name in ipairs(item.fields) do if value[i] then on[#on + 1] = name end end
        return #on > 0 and table.concat(on, ', ') or L.off
    elseif item.type == 'sliders' then
        return 'Custom'
    end
    for _, o in ipairs(item.options or {}) do
        if Items.same(o.v, value) then return o.l end
    end
    if type(value) == 'table' and #value == 3 then return hexOf(value):upper() end
    return 'Custom'
end

local function cart(s)
    local lines, total = {}, 0
    for key, value in pairs(s.changes) do
        local item = s.items[key]
        local price = Items.price(key, value, s.ctx, s.vehicle)
        lines[#lines + 1] = { key = key, label = item and ('%s: %s'):format(item.label, describe(item, value)) or key, price = price }
        total = total + price
    end
    table.sort(lines, function(a, b) return a.label < b.label end)
    return { lines = lines, total = total }
end

local function setKey(s, key, value, force)
    local item = s.items[key]
    if not item then return false end
    local clean = Items.sanitize(key, value)
    if clean == nil or (not force and not validOption(item, clean)) then return false end
    if not force and s.ctx and not s.shop.liveries and Liveries.needed(s.ctx.entry, s.ctx.unlocks, key, clean) then return false end
    applyKey(s.vehicle, key, clean)
    item.value = clean
    local rebuilt = key == 'wheelType'
    if rebuilt then s.categories, s.items = buildCatalog(s) end
    diff(s)
    return true, rebuilt
end

-- ------------------------------------------------------------
-- Camera (garage dock orbit, angles relative to the vehicle)
-- ------------------------------------------------------------

local MIN_DISTANCE = 2.2
local WALL_MARGIN = 0.45
local GROUND_MARGIN = 0.40

-- Desired camera position for the current angle, pulled in so it never enters geometry.
local function desiredPosition(s)
    local origin = GetEntityCoords(s.vehicle)
    local pivot = vector3(origin.x, origin.y, origin.z + 0.35)
    local rad = math.rad(s.angle - GetEntityHeading(s.vehicle))
    local dx, dy = math.sin(rad), math.cos(rad)
    local dist = s.distance * s.zoom

    local far = vector3(pivot.x + dx * dist, pivot.y + dy * dist, pivot.z + s.height * s.zoom + s.lift)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(pivot.x, pivot.y, pivot.z, far.x, far.y, far.z, 1 + 16, s.vehicle, 4)
    local _, hit, endCoords = GetShapeTestResult(probe)
    if hit == 1 then
        local hx, hy, hz = endCoords.x - pivot.x, endCoords.y - pivot.y, endCoords.z - pivot.z
        local reached = math.sqrt(hx * hx + hy * hy + hz * hz)
        local full = math.sqrt((far.x - pivot.x) ^ 2 + (far.y - pivot.y) ^ 2 + (far.z - pivot.z) ^ 2)
        local safe = math.max(MIN_DISTANCE, reached - WALL_MARGIN)
        if full > 0.01 and safe < full then
            local t = safe / full
            far = vector3(pivot.x + (far.x - pivot.x) * t, pivot.y + (far.y - pivot.y) * t, pivot.z + (far.z - pivot.z) * t)
        end
    end

    local found, groundZ = GetGroundZFor_3dCoord(far.x, far.y, far.z + 1.5, false)
    if found and far.z < groundZ + GROUND_MARGIN then
        far = vector3(far.x, far.y, groundZ + GROUND_MARGIN)
    end
    return far
end

-- snap = true places the camera immediately (first frame of a session).
local function camera(s, snap)
    local target = desiredPosition(s)
    if snap or not s.camPos then
        s.camPos = target
    else
        local blend = 0.30
        s.camPos = vector3(
            s.camPos.x + (target.x - s.camPos.x) * blend,
            s.camPos.y + (target.y - s.camPos.y) * blend,
            s.camPos.z + (target.z - s.camPos.z) * blend
        )
    end
    SetCamCoord(s.cam, s.camPos.x, s.camPos.y, s.camPos.z)
    PointCamAtEntity(s.cam, s.vehicle, 0.0, s.aimY, s.aimZ, true)
end

local eased = { 'zoom', 'lift', 'aimY', 'aimZ' }

-- Eases angle (shortest way round) and focus values toward their targets.
local function step(s)
    local moving = false
    local diffAngle = (s.targetAngle - s.angle + 180.0) % 360.0 - 180.0
    if math.abs(diffAngle) >= 0.08 then
        s.angle = (s.angle + diffAngle * 0.20) % 360.0
        moving = true
    elseif s.angle ~= s.targetAngle then
        s.angle = s.targetAngle
        moving = true
    end
    for _, field in ipairs(eased) do
        local delta = s.target[field] - s[field]
        if math.abs(delta) > 0.002 then
            s[field] = s[field] + delta * 0.20
            moving = true
        elseif s[field] ~= s.target[field] then
            s[field] = s.target[field]
            moving = true
        end
    end
    return moving
end

local function focus(s, camName, category)
    local preset = Config.Cameras[camName] or Config.Cameras.default
    s.targetAngle = preset.a + 0.0
    s.target.zoom = preset.z
    s.target.lift = preset.lift or 0.0
    s.target.aimY = (preset.ay or 0.0) * s.halfLength
    s.target.aimZ = preset.az or 0.35

    local wanted = {}
    for _, door in ipairs(preset.doors or {}) do wanted[door] = true end
    for door in pairs(s.doors) do
        if not wanted[door] then SetVehicleDoorShut(s.vehicle, door, false) s.doors[door] = nil end
    end
    for door in pairs(wanted) do
        if not s.doors[door] and GetIsDoorValid(s.vehicle, door) then
            SetVehicleDoorOpen(s.vehicle, door, false, false)
            s.doors[door] = true
        end
    end
    SetVehicleLights(s.vehicle, category == 'lights' and 2 or 0)
end

-- ------------------------------------------------------------
-- Session
-- ------------------------------------------------------------

local function finish(result)
    local s = session
    if not s then return end
    session = nil
    if DoesEntityExist(s.vehicle) then
        for door in pairs(s.doors) do SetVehicleDoorShut(s.vehicle, door, false) end
        SetVehicleLights(s.vehicle, 0)
        FreezeEntityPosition(s.vehicle, false)
    end
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(s.cam, false)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    LocalPlayer.state:set('invBusy', false, false)
    send('close')
    if not result then Tuner.revert(s) end
    s.promise:resolve(result or false)
end

function Tuner.isOpen() return session ~= nil end

--- opts: vehicle, shop, mode ('mechanic' | 'customer' | 'ticket'), preset?, title?
--- Returns false when cancelled (preview reverted), otherwise the work order.
function Tuner.open(opts)
    local veh = opts.vehicle
    if session or not veh or not DoesEntityExist(veh) then return false end

    serial = serial + 1
    local s = {
        id = serial, vehicle = veh, mode = opts.mode, shop = opts.shop,
        promise = promise.new(), changes = {}, orig = {}, doors = {},
        target = { zoom = 1.0, lift = 0.0, aimY = 0.0, aimZ = 0.35 },
    }
    SetVehicleModKit(veh, 0)
    s.props = lib.getVehicleProperties(veh)
    s.props.extras = nil -- restored through our own keys, without GTA's auto-repair
    s.ctx = Liveries.context(veh)
    s.categories, s.items = buildCatalog(s)
    for key, item in pairs(s.items) do s.orig[key] = item.value end
    s.snapshot = { props = s.props, orig = s.orig }

    -- The server keeps the snapshot so the car is undone even if we lose it or disconnect.
    if NetworkGetEntityIsNetworked(veh) then
        s.netId = NetworkGetNetworkIdFromEntity(veh)
        if not lib.callback.await('crimson-mechanic:server:snapshot', false, s.netId, s.snapshot) then
            lib.notify({ description = Lang.notify.vehicle_locked, type = 'error' })
            return false
        end
    end

    local preset = opts.preset and Items.sanitizeAll(opts.preset)
    if preset then
        for _, key in ipairs(Items.ordered(preset)) do
            if key == 'repair' then s.changes.repair = preset.repair or nil
            elseif s.items[key] or key == 'mod:23' or key == 'mod:24' then applyKey(veh, key, preset[key]) end
        end
        s.categories, s.items = buildCatalog(s)
        diff(s)
    end

    local low, high = GetModelDimensions(GetEntityModel(veh))
    s.distance = math.max(5.0, math.max(high.y - low.y, high.x - low.x) * 1.45)
    s.height = math.max(1.2, (high.z - low.z) * 0.7)
    s.halfLength = (high.y - low.y) / 2
    s.angle, s.targetAngle = 140.0, 140.0
    s.zoom, s.lift, s.aimY, s.aimZ = 1.0, 0.0, 0.0, 0.35
    s.settle = 0
    s.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(s.cam, 50.0)
    FreezeEntityPosition(veh, true)

    session = s
    camera(s, true)
    RenderScriptCams(true, true, 600, true, true)
    SetNuiFocus(true, true)
    -- keep game input so push-to-talk works; every other control is disabled in the loop
    SetNuiFocusKeepInput(true)
    LocalPlayer.state:set('invBusy', true, false)

    local plate = Items.plate(GetVehicleNumberPlateText(veh))
    send('open', {
        session = s.id,
        mode = s.mode,
        title = opts.title or s.shop.label,
        subtitle = ('%s · %s'):format(GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))), plate),
        categories = s.categories,
        cart = cart(s),
        locale = {
            mode = L[s.mode], confirm = L['confirm_' .. s.mode], cancel = L.cancel, cart = L.cart,
            empty = L.empty, total = L.total, rotate = L.rotate, none = L.none, paintType = L.paint_type,
            customColor = L.custom_color, off = L.off,
        },
    })
    return Citizen.Await(s.promise)
end

--- Puts the vehicle back as it was before the session: right away if we own it,
--- and through the server so whoever owns it does it otherwise.
function Tuner.revert(work)
    local veh = work.vehicle
    local keys = {}
    for key in pairs(work.changes or {}) do keys[#keys + 1] = key end

    if DoesEntityExist(veh) and (not NetworkGetEntityIsNetworked(veh) or NetworkGetEntityOwner(veh) == cache.playerId) then
        restore(veh, work.snapshot, keys)
    elseif DoesEntityExist(veh) then
        Stance.preview(veh, nil)
        Sound.preview(veh, nil)
    end
    if work.netId then
        lib.callback('crimson-mechanic:server:revert', false, function() end, work.netId, keys)
    end
end

--- Re-applies a work order (the preview may have been lost to an owner change) and repairs.
function Tuner.install(work)
    local veh = work.vehicle
    SetVehicleModKit(veh, 0)
    for _, key in ipairs(Items.ordered(work.changes)) do applyKey(veh, key, work.changes[key]) end
    if work.changes.repair then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
    end
end

-- ------------------------------------------------------------
-- NUI
-- ------------------------------------------------------------

local function guard(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local s = session
        if not s or type(data) ~= 'table' or tonumber(data.session) ~= s.id then return cb({ ok = false }) end
        cb(handler(s, data) or { ok = false })
    end)
end

local function reply(s, key, rebuilt)
    local item = s.items[key]
    return { ok = true, cart = cart(s), key = key, value = item and item.value, categories = rebuilt and s.categories or nil }
end

guard('tuner:set', function(s, d)
    local ok, rebuilt = setKey(s, d.key, d.value)
    if not ok then return end
    return reply(s, d.key, rebuilt)
end)

guard('tuner:remove', function(s, d)
    local key = d.key
    if s.changes[key] == nil then return end
    local ok, rebuilt = setKey(s, key, s.orig[key], true)
    if not ok then return end
    if key == 'wheelType' then
        -- wheel type reset the rims; put the original rims/tyres back too
        for _, k in ipairs({ 'mod:23', 'mod:24', 'customTyres' }) do
            if s.items[k] and s.orig[k] ~= nil then setKey(s, k, s.orig[k], true) end
        end
        rebuilt = true
    end
    return reply(s, key, rebuilt)
end)

guard('tuner:focus', function(s, d)
    local item = d.key and s.items[d.key]
    local category = item and item.cat or d.category
    focus(s, item and item.cam or categoryCams[category] or 'default', category)
    return { ok = true }
end)

guard('tuner:rotate', function(s, d)
    local delta = tonumber(d.delta) or 0
    s.targetAngle = (s.targetAngle + math.max(-90, math.min(90, delta))) % 360
    return { ok = true }
end)

guard('tuner:confirm', function(s)
    if not next(s.changes) then return end
    local order = cart(s)
    finish({
        vehicle = s.vehicle, changes = s.changes, lines = order.lines, total = order.total,
        snapshot = s.snapshot, netId = s.netId,
    })
    return { ok = true }
end)

-- Typing in a text field (hex colour) must not leak keys into the game.
guard('tuner:typing', function(_, d)
    SetNuiFocusKeepInput(d.typing ~= true)
    return { ok = true }
end)

guard('tuner:cancel', function()
    finish()
    return { ok = true }
end)

CreateThread(function()
    while true do
        local s = session
        if s then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            EnableControlAction(0, 249, true) -- INPUT_PUSH_TO_TALK (pma-voice proximity + radio)
            if not DoesEntityExist(s.vehicle) or IsEntityDead(cache.ped) then
                finish()
            elseif step(s) then
                s.settle = 12
                camera(s)
            elseif s.settle > 0 then
                s.settle = s.settle - 1
                camera(s)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then finish() end
end)
