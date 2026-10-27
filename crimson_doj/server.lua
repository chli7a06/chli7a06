local ready = false
local rate = {}
local kinds = { case = true, warrant = true, document = true }
local states = { open = true, closed = true, revoked = true }
local function fail(message) return { ok = false, error = message } end
local function text(value, limit, required)
    if type(value) ~= 'string' or #value > limit or value:find('%z') then return nil end
    value = value:match('^%s*(.-)%s*$')
    if required and value == '' then return nil end
    return value
end
local function identity(source)
    local player = exports.qbx_core:GetPlayer(source)
    local p = player and player.PlayerData
    if not p or not p.job or type(p.citizenid) ~= 'string' then return end
    local policy = Config.Jobs[p.job.name]
    if not policy or (Config.RequireDuty and not p.job.onduty) then return end
    local grade = type(p.job.grade) == 'table' and tonumber(p.job.grade.level) or tonumber(p.job.grade)
    if not grade or grade < policy.read then return end
    return p, grade >= policy.write, grade >= policy.manage
end
local function person(cid)
    return MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1', {cid})
end
local function serializePerson(row)
    local ok, info = pcall(json.decode, row.charinfo or '{}')
    info = ok and type(info) == 'table' and info or {}
    return { citizenid = row.citizenid, firstname = info.firstname or '', lastname = info.lastname or '', birthdate = info.birthdate or '', nationality = info.nationality or '' }
end
local function audit(actor, action, id)
    MySQL.insert.await('INSERT INTO crimson_doj_audit (actor, action, record_id) VALUES (?, ?, ?)', {actor, action, id})
end
MySQL.ready(function()
    local ok, err = pcall(function()
        local schema = LoadResourceFile(GetCurrentResourceName(), 'schema.sql')
        -- Schema is explicitly loaded below from a server-side file, never supplied by clients.
        assert(schema, 'schema.sql missing')
        for statement in schema:gmatch('([^;]+);') do MySQL.query.await(statement) end
        MySQL.query.await('SELECT citizenid, charinfo FROM players LIMIT 0')
    end)
    ready = ok
    if not ok then print('[crimson_doj] Database initialization failed: ' .. tostring(err)) end
end)
AddEventHandler('playerDropped', function() rate[source] = nil end)
lib.callback.register('crimson_doj:request', function(source, action, payload)
    -- Every operation authorizes against current server-side job/duty/grade.
    local p, write, manage = identity(source)
    if not p then return fail('Access denied: DOJ job, grade and duty required') end
    if not ready then return fail('Database not ready. Check server console.') end
    local now = GetGameTimer()
    local bucket = rate[source]
    if not bucket or now - bucket.start >= 10000 then bucket = { start = now, count = 0 } rate[source] = bucket end
    bucket.count = bucket.count + 1
    if bucket.count > 35 then return fail('Too many requests. Wait a moment.') end
    if type(action) ~= 'string' or type(payload) ~= 'table' then return fail('Invalid request') end
    local ok, result, reason = pcall(function()
        if action == 'bootstrap' then
            return { citizenid = p.citizenid, canWrite = write, canManage = manage,
                counts = MySQL.query.await('SELECT kind, status, COUNT(*) AS total FROM crimson_doj_records GROUP BY kind, status') }
        elseif action == 'search' then
            local query = text(payload.query, 80, true)
            if not query or #query < 2 then return nil, 'Enter at least 2 characters' end
            -- Literal search, not SQL wildcard interpolation.
            local rows = MySQL.query.await([[SELECT citizenid, charinfo FROM players
                WHERE LOCATE(LOWER(?), LOWER(citizenid)) > 0
                OR LOCATE(LOWER(?), LOWER(CONCAT(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ''), ' ', COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')), '')))) > 0
                ORDER BY citizenid LIMIT 40]], {query, query})
            local out = {} for _, row in ipairs(rows) do out[#out+1] = serializePerson(row) end
            audit(p.citizenid, 'profile_search', nil)
            return out
        elseif action == 'profile' then
            local cid = text(payload.citizenid, 64, true)
            if not cid then return nil, 'Invalid citizen ID' end
            local row = person(cid)
            if not row then return nil, 'Citizen not found' end
            audit(p.citizenid, 'profile_read', nil)
            return { person = serializePerson(row), records = MySQL.query.await('SELECT * FROM crimson_doj_records WHERE citizenid = ? ORDER BY id DESC LIMIT 200', {cid}) }
        elseif action == 'list' then
            if not kinds[payload.kind] then return nil, 'Invalid record type' end
            return MySQL.query.await('SELECT * FROM crimson_doj_records WHERE kind = ? ORDER BY id DESC LIMIT 100', {payload.kind})
        elseif action == 'create' then
            if not write then return nil, 'Write permission required' end
            local cid = text(payload.citizenid, 64, true)
            local title = text(payload.title, 160, true)
            local body = text(payload.body, Config.MaxText, true)
            if not cid or not title or not body or not kinds[payload.kind] then return nil, 'Invalid fields or text too long' end
            if not person(cid) then return nil, 'Citizen not found' end
            -- New warrants require management grade, not merely read/write access.
            if payload.kind == 'warrant' and not manage then return nil, 'Management permission required for warrants' end
            local id = MySQL.insert.await('INSERT INTO crimson_doj_records (kind, citizenid, title, body, created_by, updated_by) VALUES (?, ?, ?, ?, ?, ?)', {payload.kind, cid, title, body, p.citizenid, p.citizenid})
            audit(p.citizenid, 'create_' .. payload.kind, id)
            return { id = id }
        elseif action == 'update' then
            if not write then return nil, 'Write permission required' end
            local id, version = tonumber(payload.id), tonumber(payload.version)
            local title, body = text(payload.title, 160, true), text(payload.body, Config.MaxText, true)
            if not id or id % 1 ~= 0 or not version or version % 1 ~= 0 or not title or not body or not states[payload.status] then return nil, 'Invalid fields' end
            local row = MySQL.single.await('SELECT * FROM crimson_doj_records WHERE id = ?', {id})
            if not row then return nil, 'Record not found' end
            if not manage and (row.created_by ~= p.citizenid or row.kind == 'warrant' or payload.status ~= row.status) then return nil, 'Management permission required' end
            local changed = MySQL.update.await('UPDATE crimson_doj_records SET title = ?, body = ?, status = ?, updated_by = ?, version = version + 1 WHERE id = ? AND version = ?', {title, body, payload.status, p.citizenid, id, version})
            if changed ~= 1 then return nil, 'Record changed by another user. Reload first.' end
            audit(p.citizenid, 'update_' .. row.kind, id)
            return { id = id }
        elseif action == 'audit' then
            if not manage then return nil, 'Management permission required' end
            return MySQL.query.await('SELECT * FROM crimson_doj_audit ORDER BY id DESC LIMIT 100')
        end
        return nil, 'Unknown action'
    end)
    if not ok then
        print('[crimson_doj] Request failed (' .. tostring(action) .. '): ' .. tostring(result))
        return fail('Server error. Check server console.')
    end
    -- pcall must retain the validation error returned by the operation.
    if result == nil then return fail(reason or 'Request rejected') end
    return { ok = true, data = result }
end)
