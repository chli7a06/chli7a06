-- /mechadmin: create shops and place their [E] benches in game.
local A = Lang.admin
local openAdmin

local function notifyResult(r)
    local text = r and Lang.result[r.code] or Lang.result.error
    lib.notify({ description = text, type = r and r.ok and 'success' or 'error' })
end

local function isHit(hit) return hit == true or hit == 1 end

--- Aim placement: marker follows the camera, scroll changes the radius.
--- help = text UI format (gets the radius). anchor = wash bay coords: picks the exact point a
--- hose hangs from instead (line drawn from the bay, no radius, no ped-height offset).
local function aim(radius, help, anchor)
    help = help or A.aim_help
    local target, running = nil, true
    CreateThread(function()
        while running do
            local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, 30.0)
            target = isHit(hit) and coords or nil
        end
    end)

    local chosen
    lib.showTextUI(help:format(radius), { position = 'left-center' })
    while true do
        DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 177, true)

        if target and anchor then
            local c = Config.Marker.color
            DrawMarker(28, target.x, target.y, target.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, c[1], c[2], c[3], 220, false, false, 2, false, nil, nil, false)
            DrawLine(anchor.x, anchor.y, anchor.z, target.x, target.y, target.z, 255, 255, 255, 200)
        elseif target then
            local c, size = Config.Marker.color, radius * 2.0
            DrawMarker(1, target.x, target.y, target.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.35, c[1], c[2], c[3], 140, false, false, 2, false, nil, nil, false)
            DrawMarker(2, target.x, target.y, target.z + 1.1, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 255, 255, 200, true, true, 2, false, nil, nil, false)
        end

        local step = not anchor and (IsDisabledControlJustPressed(0, 15) and 0.25 or IsDisabledControlJustPressed(0, 14) and -0.25) or 0
        if step ~= 0 then
            radius = math.max(0.5, math.min(10.0, radius + step))
            lib.showTextUI(help:format(radius), { position = 'left-center' })
        end
        if IsControlJustPressed(0, 38) and target then
            chosen = target
            break
        end
        if IsDisabledControlJustPressed(0, 177) then break end
        Wait(0)
    end
    running = false
    lib.hideTextUI()
    if chosen and anchor then return chosen end
    -- benches are stored at ped height, like a player standing on the spot
    if chosen then return { x = chosen.x, y = chosen.y, z = chosen.z + 1.0, r = radius } end
end

local function settingsDialog(shop)
    local jobs = lib.callback.await('crimson-mechanic:server:admin:jobs', false)
    if not jobs or not jobs.ok then return notifyResult(jobs) end

    local currentJobs, grade = {}, 0
    for name, minGrade in pairs(shop and shop.jobs or {}) do
        currentJobs[#currentJobs + 1] = name
        grade = math.max(grade, minGrade)
    end
    local categories, allIds = {}, {}
    for i, cat in ipairs(Config.Categories) do
        categories[i] = { value = cat.id, label = cat.label }
        allIds[i] = cat.id
    end

    local input = lib.inputDialog(shop and shop.label or A.create, {
        { type = 'input', label = A.f_label, default = shop and shop.label, required = true, max = 48 },
        { type = 'multi-select', label = A.f_jobs, options = jobs.jobs, default = currentJobs, required = true, searchable = true },
        { type = 'number', label = A.f_grade, default = grade, min = 0, max = 20 },
        { type = 'checkbox', label = A.f_duty, checked = shop and shop.duty or false },
        { type = 'checkbox', label = A.f_tickets, checked = not shop or shop.tickets },
        { type = 'checkbox', label = A.f_self, checked = shop and shop.selfService or false },
        { type = 'checkbox', label = A.f_below, checked = shop and shop.allowBelow or false },
        { type = 'number', label = A.f_commission, default = shop and shop.commission or Config.DefaultCommission, min = 0, max = 100 },
        { type = 'checkbox', label = A.f_blip, checked = not shop or shop.blip },
        { type = 'multi-select', label = A.f_categories, options = categories, default = shop and shop.categories or allIds },
        { type = 'checkbox', label = A.f_liveries, checked = shop and shop.liveries or false },
        { type = 'checkbox', label = A.f_sounds, checked = shop and shop.sounds or false },
    })
    if not input then return end

    local r = lib.callback.await('crimson-mechanic:server:admin:saveShop', false, {
        id = shop and shop.id,
        label = input[1], jobs = input[2], grade = input[3], duty = input[4], tickets = input[5],
        selfService = input[6], allowBelow = input[7], commission = input[8], blip = input[9], categories = input[10],
        liveries = input[11], sounds = input[12],
    })
    notifyResult(r)
    return r and r.ok and r.args[1]
end

local function jobNames(shop)
    local names = {}
    for name in pairs(shop.jobs) do names[#names + 1] = name end
    return #names > 0 and table.concat(names, ', ') or '-'
end

-- The state bag update lands a moment after the callback returns.
local function reopen(shopId)
    SetTimeout(250, function() openAdmin(shopId) end)
end

local function addPoint(shop, point)
    if not point then return reopen(shop.id) end
    notifyResult(lib.callback.await('crimson-mechanic:server:admin:addPoint', false, shop.id, point))
    reopen(shop.id)
end

local function benchesMenu(shop)
    local options = {}
    for i, p in ipairs(shop.points) do
        local id = ('cm_admin_bench_%d_%d'):format(shop.id, i)
        lib.registerContext({
            id = id,
            title = A.bench:format(i),
            menu = 'cm_admin_benches',
            options = {
                {
                    title = A.teleport, icon = 'location-arrow',
                    onSelect = function()
                        lib.callback.await('crimson-mechanic:server:admin:wsBypass', false) -- WaveShield bypass (crimson-wsbypass)
                        SetEntityCoords(cache.ped, p.x, p.y, p.z - 1.0, false, false, false, false)
                    end,
                },
                {
                    title = A.remove, icon = 'trash',
                    onSelect = function()
                        notifyResult(lib.callback.await('crimson-mechanic:server:admin:removePoint', false, shop.id, i))
                        reopen(shop.id)
                    end,
                },
            },
        })
        options[#options + 1] = { title = A.bench:format(i), description = A.bench_desc:format(p.r or 3.0, p.x, p.y, p.z), icon = 'location-dot', menu = id }
    end
    if #options == 0 then options[1] = { title = '-', disabled = true } end
    lib.registerContext({ id = 'cm_admin_benches', title = shop.label, menu = 'cm_admin_shop', options = options })
end

local function placeWash(shop)
    local bay = aim(Config.Wash.radius, A.aim_bay)
    if not bay then return reopen(shop.id) end
    local hose = aim(0, A.aim_hose, vec3(bay.x, bay.y, bay.z))
    if not hose then return reopen(shop.id) end
    local input = lib.inputDialog(A.place_wash, {
        { type = 'number', label = A.wash_price, default = Config.Wash.price, min = 0, max = Config.MaxPrice, required = true },
    })
    if not input then return reopen(shop.id) end
    notifyResult(lib.callback.await('crimson-mechanic:server:admin:addWash', false, shop.id, {
        x = bay.x, y = bay.y, z = bay.z, r = bay.r, hx = hose.x, hy = hose.y, hz = hose.z, price = input[1],
    }))
    reopen(shop.id)
end

local function placeAutoWash(shop)
    local bay = aim(Config.Wash.auto.radius, A.aim_auto)
    if not bay then return reopen(shop.id) end
    local input = lib.inputDialog(A.place_auto, {
        { type = 'number', label = A.wash_price, default = Config.Wash.auto.price, min = 0, max = Config.MaxPrice, required = true },
    })
    if not input then return reopen(shop.id) end
    notifyResult(lib.callback.await('crimson-mechanic:server:admin:addWash', false, shop.id, {
        type = 'auto', x = bay.x, y = bay.y, z = bay.z, r = bay.r, price = input[1],
    }))
    reopen(shop.id)
end

local function washesMenu(shop)
    local options = {}
    for i, w in ipairs(shop.washes or {}) do
        local id = ('cm_admin_wash_%d_%d'):format(shop.id, i)
        lib.registerContext({
            id = id,
            title = (w.type == 'auto' and A.auto_wash or A.wash):format(i),
            menu = 'cm_admin_washes',
            options = {
                {
                    title = A.teleport, icon = 'location-arrow',
                    onSelect = function()
                        lib.callback.await('crimson-mechanic:server:admin:wsBypass', false)
                        SetEntityCoords(cache.ped, w.x, w.y, w.z - 1.0, false, false, false, false)
                    end,
                },
                {
                    title = A.edit_wash, icon = 'sliders',
                    onSelect = function()
                        local input = lib.inputDialog(A.edit_wash, {
                            { type = 'number', label = A.wash_price, default = w.price, min = 0, max = Config.MaxPrice, required = true },
                            { type = 'number', label = A.radius, default = w.r, min = 0.5, max = 10.0, step = 0.25, precision = 2, required = true },
                        })
                        if input then
                            notifyResult(lib.callback.await('crimson-mechanic:server:admin:editWash', false, shop.id, i, input[1], input[2]))
                        end
                        reopen(shop.id)
                    end,
                },
                {
                    title = A.remove, icon = 'trash',
                    onSelect = function()
                        notifyResult(lib.callback.await('crimson-mechanic:server:admin:removeWash', false, shop.id, i))
                        reopen(shop.id)
                    end,
                },
            },
        })
        local title, description, icon
        if w.type == 'auto' then
            title, description, icon = A.auto_wash:format(i), A.auto_desc:format(w.price, w.r), 'car-on'
        else
            local hoseLength = #(vec3(w.hx, w.hy, w.hz) - vec3(w.x, w.y, w.z))
            title, description, icon = A.wash:format(i), A.wash_desc:format(w.price, w.r, hoseLength), 'shower'
        end
        options[#options + 1] = { title = title, description = description, icon = icon, menu = id }
    end
    if #options == 0 then options[1] = { title = '-', disabled = true } end
    lib.registerContext({ id = 'cm_admin_washes', title = shop.label, menu = 'cm_admin_shop', options = options })
end

local function shopMenu(shop)
    benchesMenu(shop)
    washesMenu(shop)
    lib.registerContext({
        id = 'cm_admin_shop',
        title = shop.label,
        menu = 'cm_admin',
        options = {
            {
                title = A.place_aim, description = A.place_aim_desc, icon = 'crosshairs',
                onSelect = function() addPoint(shop, aim(3.0)) end,
            },
            {
                title = A.place_here, icon = 'street-view',
                onSelect = function()
                    local input = lib.inputDialog(A.place_here, { { type = 'number', label = A.radius, default = 3.0, min = 0.5, max = 10.0, step = 0.5 } })
                    if not input then return reopen(shop.id) end
                    local c = GetEntityCoords(cache.vehicle or cache.ped)
                    addPoint(shop, { x = c.x, y = c.y, z = c.z, r = input[1] })
                end,
            },
            { title = A.benches:format(#shop.points), icon = 'list', menu = 'cm_admin_benches' },
            {
                title = A.place_wash, description = A.place_wash_desc, icon = 'shower',
                disabled = not Config.Wash.enabled,
                onSelect = function() placeWash(shop) end,
            },
            {
                title = A.place_auto, description = A.place_auto_desc, icon = 'car-on',
                disabled = not Config.Wash.enabled,
                onSelect = function() placeAutoWash(shop) end,
            },
            { title = A.washes:format(#(shop.washes or {})), icon = 'list', menu = 'cm_admin_washes' },
            {
                title = A.edit, icon = 'sliders',
                onSelect = function()
                    settingsDialog(shop)
                    reopen(shop.id)
                end,
            },
            {
                title = A.toggle:format(shop.tickets and Lang.on or Lang.off), icon = shop.tickets and 'toggle-on' or 'toggle-off',
                onSelect = function()
                    notifyResult(lib.callback.await('crimson-mechanic:server:toggleTickets', false, shop.id))
                    reopen(shop.id)
                end,
            },
            {
                title = A.delete, icon = 'trash',
                onSelect = function()
                    local confirm = lib.alertDialog({ header = A.delete, content = A.delete_confirm:format(shop.label), centered = true, cancel = true })
                    if confirm ~= 'confirm' then return reopen(shop.id) end
                    notifyResult(lib.callback.await('crimson-mechanic:server:admin:deleteShop', false, shop.id))
                    reopen()
                end,
            },
        },
    })
    lib.showContext('cm_admin_shop')
end

openAdmin = function(shopId)
    local shops = GetMechanicShops()
    if shopId and shops[shopId] then return shopMenu(shops[shopId]) end

    local options = {
        {
            title = A.create, description = A.create_desc, icon = 'plus',
            onSelect = function()
                local id = settingsDialog()
                reopen(id)
            end,
        },
    }
    local ids = {}
    for id in pairs(shops) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local shop = shops[id]
        options[#options + 1] = {
            title = shop.label,
            description = A.shop_desc:format(#shop.points, jobNames(shop), shop.tickets and Lang.on or Lang.off),
            icon = 'warehouse',
            onSelect = function() shopMenu(shop) end,
        }
    end
    lib.registerContext({ id = 'cm_admin', title = A.title, options = options })
    lib.showContext('cm_admin')
end

RegisterNetEvent('crimson-mechanic:client:admin', function() openAdmin() end)
