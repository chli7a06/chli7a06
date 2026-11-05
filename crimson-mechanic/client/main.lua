local Shops = {}
local points, blips = {}, {}
local prompt, promptText = nil, nil
local busy, activeOffer = false, nil

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

local function notify(message, notifyType)
    lib.notify({ description = message, type = notifyType or 'inform' })
end

local function notifyResult(r)
    local text = r and Lang.result[r.code] or Lang.result.error
    if r and r.args and #r.args > 0 then
        local ok, formatted = pcall(string.format, text, table.unpack(r.args))
        if ok then text = formatted end
    end
    notify(text, r and r.ok and 'success' or 'error')
end

local function jobAccess(shop)
    local job = QBX.PlayerData.job
    if not job then return false end
    local minGrade = shop.jobs[job.name]
    if minGrade == nil then return false end
    if (job.grade and job.grade.level or 0) < minGrade then return false end
    if shop.duty and not job.onduty then return false end
    return true
end

local function driving()
    if cache.vehicle and cache.seat == -1 then return cache.vehicle end
end

local function pointCoords(point)
    return vec3(point.coords.x, point.coords.y, point.coords.z)
end

local function benchVehicle(point)
    return driving() or lib.getClosestVehicle(pointCoords(point), point.promptRadius + 1.5, false)
end

local function findVehicle(plate, coords, radius)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - coords) <= radius and Items.plate(GetVehicleNumberPlateText(veh)) == plate then
            return veh
        end
    end
end

local function modelLabel(veh)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local label = GetLabelText(name)
    return label ~= 'NULL' and label or name
end

-- Mods only stick when set by the entity owner. A driven vehicle can't migrate.
local function takeControl(veh)
    if not DoesEntityExist(veh) then return false end
    if NetworkGetEntityOwner(veh) == cache.playerId then return true end
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= 0 and driver ~= cache.ped then return false end
    NetworkRequestControlOfEntity(veh)
    local timeout = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(veh)
    end
    return NetworkHasControlOfEntity(veh)
end

-- Undo a preview. If we can't get control, the server has the current owner do it.
local function revert(work)
    takeControl(work.vehicle)
    Tuner.revert(work)
end

-- ------------------------------------------------------------
-- Mechanic flow
-- ------------------------------------------------------------

local function install(work, token)
    local veh = work.vehicle
    lib.progressBar({
        duration = Config.InstallDuration,
        label = Lang.menu.installing,
        canCancel = false,
        disable = { move = true, car = true, combat = true },
        anim = cache.vehicle ~= veh and { dict = 'mini@repair', clip = 'fixing_a_player' } or nil,
    })

    local props
    if takeControl(veh) then
        Tuner.install(work)
        props = lib.getVehicleProperties(veh)
    end
    local r = lib.callback.await('crimson-mechanic:server:commit', false, token, props)
    if not r or not r.ok then
        revert(work)
        return notifyResult(r)
    end
    -- hand over to the saved stance / sound once the updated plate maps have synced
    SetTimeout(3000, function()
        if DoesEntityExist(veh) then
            Stance.preview(veh, nil)
            Sound.preview(veh, nil)
        end
    end)
    notify(r.code == 'installed' and Lang.notify.installed or Lang.notify.not_saved, 'success')
end

local function mechanicWork(shop, veh, ticket)
    if not takeControl(veh) then return notify(Lang.notify.vehicle_busy, 'error') end

    local work = Tuner.open({
        vehicle = veh, shop = shop, mode = ticket and 'ticket' or 'mechanic',
        preset = ticket and ticket.changes,
        title = ticket and ('%s · #%d'):format(shop.label, ticket.id) or nil,
    })
    if not work then return end

    local fields = {}
    if not ticket then
        local options = {}
        if shop.selfService then options[1] = { value = 'self', label = Lang.menu.myself } end
        for _, p in ipairs(lib.callback.await('crimson-mechanic:server:getNearby', false, shop.id) or {}) do
            options[#options + 1] = { value = tostring(p.id), label = ('%s (#%d)'):format(p.name, p.id) }
        end
        if #options == 0 then
            revert(work)
            return notify(Lang.notify.no_customers, 'error')
        end
        fields[1] = { type = 'select', label = Lang.menu.customer, options = options, default = options[1].value, required = true }
    end
    local minimum = shop.allowBelow and 0 or math.floor(work.total * Config.MinPricePercent / 100)
    fields[#fields + 1] = { type = 'number', label = Lang.menu.price, default = work.total, min = minimum, max = Config.MaxPrice, required = true }

    local input = lib.inputDialog(('%s — $%s'):format(Lang.menu.bill_title, work.total), fields)
    if not input then return revert(work) end

    local target = not ticket and input[1] or nil
    if ticket or target ~= 'self' then notify(Lang.notify.waiting) end
    local r = lib.callback.await('crimson-mechanic:server:bill', false, {
        shopId = shop.id,
        netId = NetworkGetNetworkIdFromEntity(veh),
        changes = work.changes,
        lines = work.lines,
        price = math.floor(tonumber(input[#fields]) or 0),
        target = target,
        ticketId = ticket and ticket.id,
    })
    if not r or not r.ok then
        revert(work)
        return notifyResult(r)
    end
    install(work, r.args[1])
end

local openWorkshop

local function ticketMenu(shop, point, t)
    local id = 'cm_ticket_' .. t.id
    local options = {
        {
            title = Lang.menu.ticket_work,
            description = Lang.menu.ticket_work_desc,
            icon = 'screwdriver-wrench',
            onSelect = function()
                if not t.online then return notifyResult({ code = 'customer_offline' }) end
                local veh = findVehicle(t.plate, pointCoords(point), point.promptRadius + 2.0)
                if not veh then return notify(Lang.notify.ticket_vehicle_missing:format(t.plate), 'error') end
                mechanicWork(shop, veh, t)
            end,
        },
        {
            title = Lang.menu.ticket_reject,
            icon = 'ban',
            onSelect = function()
                local input = lib.inputDialog(Lang.menu.ticket_reject, { { type = 'input', label = Lang.menu.reject_reason, max = 200 } })
                if not input then return lib.showContext(id) end
                notifyResult(lib.callback.await('crimson-mechanic:server:rejectTicket', false, t.id, input[1]))
                openWorkshop(shop, point)
            end,
        },
    }
    for _, line in ipairs(t.items or {}) do
        options[#options + 1] = { title = line.label, description = ('$%s'):format(line.price), icon = 'wrench', disabled = true }
    end
    lib.registerContext({ id = id, title = Lang.menu.ticket_title:format(t.id, t.model or '?', t.plate), menu = 'cm_tickets', options = options })
    return id
end

openWorkshop = function(shop, point)
    local data = lib.callback.await('crimson-mechanic:server:getWorkshop', false, shop.id)
    if not data or not data.ok then return notifyResult(data) end

    local veh = benchVehicle(point)
    local ticketOptions = {}
    for _, t in ipairs(data.tickets) do
        ticketOptions[#ticketOptions + 1] = {
            title = Lang.menu.ticket_title:format(t.id, t.model or '?', t.plate),
            description = Lang.menu.ticket_desc:format(t.customer or '?', #(t.items or {}), t.estimate, t.online and '' or Lang.menu.offline),
            icon = 'file-invoice-dollar',
            menu = ticketMenu(shop, point, t),
        }
    end
    if #ticketOptions == 0 then ticketOptions[1] = { title = Lang.menu.no_tickets, disabled = true } end
    lib.registerContext({ id = 'cm_tickets', title = Lang.menu.tickets, menu = 'cm_workshop', options = ticketOptions })

    local options = {
        {
            title = Lang.menu.tune,
            description = veh and Lang.menu.tune_desc:format(Items.plate(GetVehicleNumberPlateText(veh))) or Lang.menu.tune_none,
            icon = 'screwdriver-wrench',
            disabled = not veh,
            onSelect = function() mechanicWork(shop, veh) end,
        },
        {
            title = Lang.menu.tickets,
            description = data.ticketsOn and Lang.menu.tickets_desc:format(#data.tickets) or Lang.menu.tickets_off,
            icon = 'clipboard-list',
            menu = 'cm_tickets',
        },
    }
    if data.canToggle then
        options[#options + 1] = {
            title = Lang.menu.toggle:format(data.ticketsOn and Lang.on or Lang.off),
            description = Lang.menu.toggle_desc,
            icon = data.ticketsOn and 'toggle-on' or 'toggle-off',
            onSelect = function()
                notifyResult(lib.callback.await('crimson-mechanic:server:toggleTickets', false, shop.id))
                openWorkshop(shop, point)
            end,
        }
    end
    lib.registerContext({ id = 'cm_workshop', title = ('%s — %s'):format(shop.label, Lang.menu.workshop), options = options })
    lib.showContext('cm_workshop')
end

-- ------------------------------------------------------------
-- Customer flow
-- ------------------------------------------------------------

local function openRequest(shop, veh, preset)
    local work = Tuner.open({ vehicle = veh, shop = shop, mode = 'customer', preset = preset })
    if not work then return end
    Tuner.revert(work) -- customers only preview; the mechanic installs
    notifyResult(lib.callback.await('crimson-mechanic:server:createTicket', false, {
        shopId = shop.id,
        netId = NetworkGetNetworkIdFromEntity(veh),
        changes = work.changes,
        lines = work.lines,
        model = modelLabel(veh),
    }))
end

local function customerRequest(shop, veh)
    local existing = lib.callback.await('crimson-mechanic:server:getMyTicket', false, shop.id, NetworkGetNetworkIdFromEntity(veh))
    if not existing then return openRequest(shop, veh) end

    local options = {
        {
            title = Lang.menu.my_ticket_edit,
            description = Lang.menu.my_ticket_edit_desc,
            icon = 'pen',
            onSelect = function() openRequest(shop, veh, existing.changes) end,
        },
        {
            title = Lang.menu.my_ticket_cancel,
            icon = 'xmark',
            onSelect = function()
                notifyResult(lib.callback.await('crimson-mechanic:server:cancelTicket', false, existing.id))
            end,
        },
    }
    for _, line in ipairs(existing.items or {}) do
        options[#options + 1] = { title = line.label, description = ('$%s'):format(line.price), icon = 'wrench', disabled = true }
    end
    lib.registerContext({ id = 'cm_my_ticket', title = ('%s #%d · $%s'):format(Lang.menu.my_ticket, existing.id, existing.estimate), options = options })
    lib.showContext('cm_my_ticket')
end

-- ------------------------------------------------------------
-- Invoice from a mechanic
-- ------------------------------------------------------------

RegisterNetEvent('crimson-mechanic:client:offer', function(offer)
    if activeOffer then
        return TriggerServerEvent('crimson-mechanic:server:respondOffer', offer.id, false)
    end
    activeOffer = offer.id
    SetTimeout(offer.timeout * 1000, function()
        if activeOffer == offer.id then lib.closeAlertDialog() end
    end)
    local answer = lib.alertDialog({
        header = Lang.offer.header:format(offer.shop),
        content = Lang.offer.content:format(offer.mechanic, offer.price, offer.plate, offer.summary),
        centered = true,
        cancel = true,
        labels = { confirm = Lang.offer.accept:format(offer.price), cancel = Lang.offer.decline },
    })
    activeOffer = nil
    TriggerServerEvent('crimson-mechanic:server:respondOffer', offer.id, answer == 'confirm')
end)

-- ------------------------------------------------------------
-- Bench points
-- ------------------------------------------------------------

local function showPrompt(point, text)
    if prompt == point and promptText == text then return end
    lib.showTextUI(text, { position = 'left-center' })
    prompt, promptText = point, text
end

local function hidePrompt(point)
    if not prompt or (point and prompt ~= point) then return end
    lib.hideTextUI()
    prompt, promptText = nil, nil
end

local function promptFor(shop)
    if jobAccess(shop) then return Lang.prompt.workshop end
    if shop.tickets and driving() then return Lang.prompt.request end
end

local function interact(shop, point)
    if jobAccess(shop) then return openWorkshop(shop, point) end
    local veh = driving()
    if veh and shop.tickets then return customerRequest(shop, veh) end
end

local function nearby(self)
    local shop = Shops[self.shopId]
    if not shop then return end
    local mechanic = jobAccess(shop)

    if Config.Marker.enabled and (mechanic or shop.tickets) then
        local c, size = Config.Marker.color, self.promptRadius * 2.0
        DrawMarker(Config.Marker.type, self.coords.x, self.coords.y, self.coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            size, size, 0.35, c[1], c[2], c[3], c[4], false, false, 2, false, nil, nil, false)
    end

    if busy or Tuner.isOpen() or self.currentDistance > self.promptRadius then return hidePrompt(self) end
    local text = promptFor(shop)
    if not text then return hidePrompt(self) end
    showPrompt(self, text)

    if IsControlJustReleased(0, Config.InteractKey) then
        hidePrompt(self)
        busy = true
        CreateThread(function()
            local ok, err = pcall(interact, shop, self)
            if not ok then lib.print.error(err) end
            busy = false
        end)
    end
end

local function onExit(self) hidePrompt(self) end

local function rebuild(list)
    hidePrompt()
    for _, point in ipairs(points) do point:remove() end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    points, blips, Shops = {}, {}, {}

    for _, shop in ipairs(list or {}) do
        shop.categorySet = {}
        for _, id in ipairs(shop.categories or {}) do shop.categorySet[id] = true end
        Shops[shop.id] = shop

        for i, p in ipairs(shop.points or {}) do
            local point = lib.points.new({
                coords = vec3(p.x, p.y, p.z),
                distance = Config.MarkerDistance,
                shopId = shop.id,
                index = i,
                promptRadius = p.r or 3.0, -- not "radius": lib.points overwrites that with distance
            })
            point.nearby, point.onExit = nearby, onExit
            points[#points + 1] = point
        end

        local first = shop.points and shop.points[1]
        if shop.blip and first then
            local blip = AddBlipForCoord(first.x, first.y, first.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.label)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end

AddStateBagChangeHandler('crimsonMechanic', 'global', function(_, _, value)
    rebuild(value)
end)

CreateThread(function()
    rebuild(GlobalState.crimsonMechanic)
end)

--- Shops as synced from the server (used by the admin editor).
function GetMechanicShops() return Shops end

exports('IsTunerOpen', function() return Tuner.isOpen() end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    hidePrompt()
end)
