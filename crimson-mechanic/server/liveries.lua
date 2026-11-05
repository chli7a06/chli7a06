-- Crimson livery unlocks: storage, enforcement, DB clean-up and the admin command.
-- Unlocks belong to a plate (crimson_mechanic_liveries) and reach clients through
-- the 'crimsonLiveries' global state. Selling them happens in the bill/commit flow
-- of server/main.lua, only at shops with "Unlocks Crimson liveries" ticked.
local cfg = Config.CrimsonLiveries
local Unlocks = {}  -- plate -> { [key] = true }
local strikes = {}  -- entity -> scans in a row still showing a locked livery
local reported = {} -- source -> last client revert report

local function log(source, message, ...)
    message = message:format(...)
    lib.logger(source, 'mechanic:livery', message)
    lib.print.info(message)
end

local function publish()
    Liveries.map = Unlocks
    GlobalState:set('crimsonLiveries', Unlocks, true)
end

local function persist(plate, model, by)
    local keys = {}
    for key in pairs(Unlocks[plate] or {}) do keys[#keys + 1] = key end
    if #keys == 0 then
        Unlocks[plate] = nil
        MySQL.update.await('DELETE FROM crimson_mechanic_liveries WHERE plate = ?', { plate })
    else
        table.sort(keys)
        MySQL.insert.await('INSERT INTO crimson_mechanic_liveries (plate, model, unlocks, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE model = VALUES(model), unlocks = VALUES(unlocks), updated_by = VALUES(updated_by)',
            { plate, model, json.encode(keys), by })
    end
    publish()
end

-- ------------------------------------------------------------
-- Saved properties: a locked livery can't come back from the DB
-- ------------------------------------------------------------

local function sanitizeRows(where, params)
    if not Liveries.enabled then return 0 end
    local fixed = 0
    for _, row in ipairs(MySQL.query.await('SELECT id, plate, vehicle, mods FROM player_vehicles WHERE ' .. where, params) or {}) do
        local entry = Liveries.entry(row.vehicle)
        local ok, props = pcall(json.decode, row.mods or '')
        if entry and ok and type(props) == 'table' and Liveries.sanitizeProps(entry, Unlocks[Items.plate(row.plate)], props) then
            -- only if nobody rewrote the row meanwhile
            local changed = MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE id = ? AND mods = ?', { json.encode(props), row.id, row.mods })
            if (tonumber(changed) or 0) > 0 then fixed = fixed + 1 end
        end
    end
    return fixed
end

local function sanitizePlate(plate)
    return sanitizeRows('plate = ?', { plate })
end

--- Server/main.lua: cleans the props a mechanic is about to save.
function LiverySanitizeProps(vehicle, plate, props)
    local entry = Liveries.entry(GetEntityModel(vehicle))
    if entry then Liveries.sanitizeProps(entry, Unlocks[plate], props) end
end

--- Server/main.lua: pauses enforcement while an unlock shop has the car in the tuner.
function LiveryHold(netId, on)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    Entity(vehicle).state:set('crimsonLiveryHold', on or nil, true)
end

--- Server/main.lua: records liveries paid for at an unlock shop.
function LiveryGrant(source, plate, model, keys, info)
    if #keys == 0 then return end
    local entry = Liveries.entry(model)
    Unlocks[plate] = Unlocks[plate] or {}
    for _, key in ipairs(keys) do Unlocks[plate][key] = true end
    persist(plate, model, info.mechanic)
    for _, key in ipairs(keys) do
        log(source, '%s unlocked %s (%s) on %s at %s for customer %s ($%d bill)',
            info.mechanic, entry and Liveries.label(entry, key) or key, key, plate, info.shop, info.customer, info.price)
    end
end

-- ------------------------------------------------------------
-- Live enforcement
-- ------------------------------------------------------------

-- Client loop (client/liveries.lua) reverts and reports; we only log it.
RegisterNetEvent('crimson-mechanic:server:liveryReverted', function(netId, keys)
    local src = source
    local now = GetGameTimer()
    if reported[src] and now - reported[src] < 2000 then return end
    reported[src] = now
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(keys) ~= 'table' then return end
    local entry = Liveries.entry(GetEntityModel(vehicle))
    if not entry then return end
    local names = {}
    for i = 1, math.min(#keys, 6) do
        if type(keys[i]) == 'string' then names[#names + 1] = Liveries.label(entry, keys[i]:sub(1, 16)) end
    end
    log(src, 'Locked livery %s reverted on %s (%s, owner %s #%d)', table.concat(names, ', '), Items.plate(GetVehicleNumberPlateText(vehicle)), entry.name, GetPlayerName(src) or '?', src)
end)

AddEventHandler('playerDropped', function() reported[source] = nil end)

if Liveries.enabled then
    -- Texture liveries are synced, so the server checks them itself and makes the owner revert.
    CreateThread(function()
        while true do
            Wait(cfg.checkInterval or 2000)
            local seen = {}
            for _, vehicle in ipairs(GetAllVehicles()) do
                local entry = Liveries.entry(GetEntityModel(vehicle))
                if entry and not Entity(vehicle).state.crimsonLiveryHold then
                    local livery = GetVehicleLivery(vehicle)
                    local plate = Items.plate(GetVehicleNumberPlateText(vehicle))
                    if livery and livery >= 0 and Liveries.needed(entry, Unlocks[plate], 'livery', livery) then
                        seen[vehicle] = true
                        strikes[vehicle] = (strikes[vehicle] or 0) + 1
                        Entity(vehicle).state:set('crimsonLiveryFix', GetGameTimer(), true)
                        if strikes[vehicle] == 3 then
                            local owner = NetworkGetEntityOwner(vehicle)
                            log(owner > 0 and owner or 0, 'Locked livery %d on %s (%s) is NOT being reverted by its owner %s #%d',
                                livery, plate, entry.name, owner > 0 and GetPlayerName(owner) or 'server', owner)
                        end
                    end
                end
            end
            for vehicle in pairs(strikes) do
                if not seen[vehicle] then strikes[vehicle] = nil end
            end
        end
    end)

    -- Saves through qbx_vehicles (mechanic installs, persistence, jg, ...)
    AddEventHandler('qbx_vehicles:server:vehicleSaved', function(vehicleId)
        sanitizeRows('id = ?', { vehicleId })
    end)

    -- jobs_creator stores / impounds write mods straight to the DB, then delete the car.
    AddEventHandler('entityRemoved', function(entity)
        if GetEntityType(entity) ~= 2 then return end
        if not Liveries.entry(GetEntityModel(entity)) then return end
        local plate = Items.plate(GetVehicleNumberPlateText(entity))
        SetTimeout(1000, function() sanitizePlate(plate) end)
    end)
end

-- ------------------------------------------------------------
-- Admin command
-- ------------------------------------------------------------

local function reply(source, message, notifyType)
    if source > 0 then exports.qbx_core:Notify(source, message, notifyType or 'inform', 10000) else print(message) end
end

local function vehicleModel(plate)
    local model = MySQL.scalar.await('SELECT vehicle FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if model then return model end
    for _, vehicle in ipairs(GetAllVehicles()) do
        if Items.plate(GetVehicleNumberPlateText(vehicle)) == plate then
            local entry = Liveries.entry(GetEntityModel(vehicle))
            return entry and entry.name
        end
    end
end

if Liveries.enabled then
    lib.addCommand(cfg.command, {
        help = 'Crimson livery unlocks',
        restricted = cfg.group,
        params = {
            { name = 'action', type = 'string', help = 'unlock | lock | info' },
            { name = 'plate', type = 'string', help = 'Vehicle plate' },
            { name = 'what', type = 'string', help = 'Key shown by info (e.g. livery:1), default all', optional = true },
        },
    }, function(source, args)
        local action = tostring(args.action):lower()
        local plate = Items.plate(args.plate):upper()
        local model = vehicleModel(plate)
        local entry = model and Liveries.entry(model)
        if not entry then return reply(source, ('%s is not a Crimson-livery vehicle.'):format(plate), 'error') end

        local all = Liveries.keys(entry)
        local owned = Unlocks[plate] or {}
        if action == 'info' then
            local parts = {}
            for _, k in ipairs(all) do parts[#parts + 1] = ('%s %s (%s)'):format(owned[k.key] and '[x]' or '[ ]', k.label, k.key) end
            return reply(source, ('%s (%s): %s'):format(plate, entry.name, table.concat(parts, ', ')))
        end
        if action ~= 'unlock' and action ~= 'lock' then return reply(source, 'Action must be unlock, lock or info.', 'error') end

        local what = args.what and tostring(args.what):lower() or 'all'
        local keys = {}
        for _, k in ipairs(all) do
            if what == 'all' or what == k.key then keys[#keys + 1] = k.key end
        end
        if #keys == 0 then return reply(source, ('Unknown key %s, see /%s info %s.'):format(what, cfg.command, plate), 'error') end

        local by = source > 0 and ('%s (admin #%d)'):format(GetPlayerName(source) or '?', source) or 'console'
        Unlocks[plate] = owned
        for _, key in ipairs(keys) do owned[key] = action == 'unlock' or nil end
        persist(plate, entry.name, by)
        if action == 'lock' then sanitizePlate(plate) end

        local labels = {}
        for _, key in ipairs(keys) do labels[#labels + 1] = Liveries.label(entry, key) end
        log(source, '%s %s %s on %s (%s)', by, action == 'unlock' and 'unlocked' or 'relocked', table.concat(labels, ', '), plate, entry.name)
        reply(source, ('%s %s on %s.'):format(action == 'unlock' and 'Unlocked' or 'Relocked', table.concat(labels, ', '), plate), 'success')
    end)
end

-- ------------------------------------------------------------
-- Boot
-- ------------------------------------------------------------

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `crimson_mechanic_liveries` (
            `plate` VARCHAR(16) NOT NULL PRIMARY KEY,
            `model` VARCHAR(64) NULL,
            `unlocks` TEXT NOT NULL,
            `updated_by` VARCHAR(100) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    for _, row in ipairs(MySQL.query.await('SELECT plate, unlocks FROM crimson_mechanic_liveries') or {}) do
        local ok, keys = pcall(json.decode, row.unlocks)
        if ok and type(keys) == 'table' then
            local set = {}
            for _, key in ipairs(keys) do set[key] = true end
            Unlocks[row.plate] = set
        end
    end
    publish()

    if not Liveries.enabled then return end
    local names, marks = {}, {}
    for name in pairs(cfg.models) do
        names[#names + 1] = name
        marks[#marks + 1] = '?'
    end
    local fixed = sanitizeRows(('vehicle IN (%s)'):format(table.concat(marks, ',')), names)
    if fixed > 0 then lib.print.info(('Crimson liveries: reset %d saved vehicle(s) to their stock livery'):format(fixed)) end
end)
