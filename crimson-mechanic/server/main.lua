local Shops = {}     -- id -> shop
local Tickets = {}   -- id -> pending ticket (only pending ones are cached)
local Stances = {}   -- plate -> stance
local Sounds = {}    -- plate -> engine sound swap
local SoundUnlocks = {} -- plate -> { [sound] = true } exhaust systems paid for
local Installs = {}  -- token -> paid work waiting for the mechanic to commit it
local Offers = {}    -- customer source -> pending invoice
local Snapshots = {} -- netId -> { src, plate, data } how a vehicle looked before a tuner session
local busy, lastAction = {}, {}
local tokenSeq, offerSeq = 0, 0

local STANCE_BAG = 'crimsonStance'
local SOUND_BAG = 'crimsonSound'
local allCategories = {}
for i, cat in ipairs(Config.Categories) do allCategories[i] = cat.id end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

local function result(ok, code, ...)
    return { ok = ok, code = code, args = { ... } }
end

local function toInt(value)
    local number = tonumber(value)
    if number and number == math.floor(number) then return math.floor(number) end
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function notify(source, message, notifyType)
    exports.qbx_core:Notify(source, message, notifyType)
end

local function charName(pd)
    local info = pd and pd.charinfo
    if type(info) ~= 'table' then return '?' end
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

local function log(source, event, message, ...)
    lib.logger(source, event, message:format(...))
end

local function throttled(source)
    local now = GetGameTimer()
    if lastAction[source] and now - lastAction[source] < 500 then return true end
    lastAction[source] = now
    return false
end

local function isAdmin(source)
    return IsPlayerAceAllowed(source, 'command.' .. Config.AdminCommand)
end

local function jobAccess(player, shop)
    local job = player and player.PlayerData.job
    if not job or not shop then return false end
    local minGrade = shop.jobs[job.name]
    if minGrade == nil then return false end
    if (job.grade and job.grade.level or 0) < minGrade then return false end
    if shop.duty and not job.onduty then return false end
    return true
end

local function isBoss(player, shop)
    local job = player and player.PlayerData.job
    return job ~= nil and shop.jobs[job.name] ~= nil and job.isboss == true
end

local function ticketsEnabled(shop)
    return Config.TicketSystem and shop.tickets
end

local function nearBench(coords, shop, pad)
    for _, p in ipairs(shop.points) do
        if #(coords - vector3(p.x, p.y, p.z)) <= (p.r or 3.0) + pad then return true end
    end
    return false
end

local function vehicleFromNet(netId)
    netId = toInt(netId)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    return entity
end

local function plateOf(vehicle)
    return Items.plate(GetVehicleNumberPlateText(vehicle))
end

local function cleanText(text, max)
    if type(text) ~= 'string' then return '' end
    return (text:gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max)
end

-- ------------------------------------------------------------
-- Money
-- ------------------------------------------------------------

local function charge(source, amount)
    if amount <= 0 then return true end
    local balance = exports.qbx_core:GetMoney(source, Config.Account)
    if type(balance) ~= 'number' or balance < amount then return false end
    return exports.qbx_core:RemoveMoney(source, Config.Account, amount, 'mechanic-invoice')
end

local function societyAdd(jobName, amount)
    if not Config.Society or not jobName or amount <= 0 then return end

    if Config.Society == 'snipe-banking' and GetResourceState('snipe-banking') == 'started' then
        -- snipe keeps balances in memory, so it has to go through its export
        local snipe = exports['snipe-banking']
        if snipe:AddMoneyToAccount(jobName, amount) then return end
        local job = exports.qbx_core:GetJob(jobName)
        snipe:CreateJobGangAccount(jobName, job and job.label or jobName, 0, true)
        if snipe:AddMoneyToAccount(jobName, amount) then return end
        lib.print.error(('snipe-banking has no account for %s, $%d society cut not paid'):format(jobName, amount))
        return
    end

    MySQL.insert('INSERT INTO `aj_job_accounts` (`job_name`, `amount`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `amount` = `amount` + VALUES(`amount`)', { jobName, amount })
end

-- ------------------------------------------------------------
-- Shops
-- ------------------------------------------------------------

local function stored(shop)
    return {
        jobs = shop.jobs, duty = shop.duty, tickets = shop.tickets, selfService = shop.selfService,
        allowBelow = shop.allowBelow, commission = shop.commission, blip = shop.blip,
        categories = shop.categories, points = shop.points, liveries = shop.liveries, sounds = shop.sounds,
        washes = shop.washes,
    }
end

local function decodeShop(row)
    local ok, data = pcall(json.decode, row.data or '')
    data = ok and type(data) == 'table' and data or {}
    return {
        id = row.id,
        label = row.label,
        jobs = type(data.jobs) == 'table' and data.jobs or {},
        duty = data.duty == true,
        tickets = data.tickets ~= false,
        selfService = data.selfService == true,
        allowBelow = data.allowBelow == true,
        commission = tonumber(data.commission) or Config.DefaultCommission,
        blip = data.blip ~= false,
        categories = type(data.categories) == 'table' and #data.categories > 0 and data.categories or allCategories,
        points = type(data.points) == 'table' and data.points or {},
        washes = type(data.washes) == 'table' and data.washes or {},
        liveries = data.liveries == true,
        -- shops saved before engine sounds existed follow their Crimson liveries setting
        sounds = data.sounds == true or (data.sounds == nil and data.liveries == true),
    }
end

local function publish()
    local list = {}
    for _, shop in pairs(Shops) do
        local entry = stored(shop)
        entry.id, entry.label = shop.id, shop.label
        entry.tickets = ticketsEnabled(shop)
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    GlobalState:set('crimsonMechanic', list, true)
end

local function saveShop(shop)
    MySQL.update.await('UPDATE crimson_mechanic_shops SET label = ?, data = ? WHERE id = ?', { shop.label, json.encode(stored(shop)), shop.id })
    publish()
end

-- ------------------------------------------------------------
-- Stance persistence
-- ------------------------------------------------------------

-- Clients match stanced vehicles by plate, so it survives garages, respawns and
-- restarts whatever script spawned the car (no spawn-timing guesswork).
local function publishStances()
    GlobalState:set(STANCE_BAG, Stances, true)
end

local function setStance(plate, data)
    local neutral = true
    for _, field in ipairs(Config.Stance) do
        if math.abs(data[field.id] or 0) > 0.0005 then neutral = false break end
    end
    if neutral then
        Stances[plate] = nil
        MySQL.update('DELETE FROM crimson_mechanic_stance WHERE plate = ?', { plate })
    else
        Stances[plate] = data
        MySQL.insert('INSERT INTO crimson_mechanic_stance (plate, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { plate, json.encode(data) })
    end
    publishStances()
end

-- ------------------------------------------------------------
-- Engine sound persistence
-- ------------------------------------------------------------

-- Same as stance: a plate -> sound map clients match against (client/sound.lua).
local function publishSounds()
    GlobalState:set(SOUND_BAG, Sounds, true)
end

local function setSound(plate, model, sound)
    local options = Items.soundOptions(model)
    if not options or not Items.soundAllowed(model, sound) then return end
    if sound == options[1].v then
        Sounds[plate] = nil
        MySQL.update('DELETE FROM crimson_mechanic_sounds WHERE plate = ?', { plate })
    else
        Sounds[plate] = sound
        MySQL.insert('INSERT INTO crimson_mechanic_sounds (plate, sound) VALUES (?, ?) ON DUPLICATE KEY UPDATE sound = VALUES(sound)', { plate, sound })
    end
    publishSounds()
end

local function publishSoundUnlocks()
    Items.soundUnlocks = SoundUnlocks
    GlobalState:set('crimsonSoundUnlocks', SoundUnlocks, true)
end

local function grantSound(plate, sound)
    SoundUnlocks[plate] = SoundUnlocks[plate] or {}
    SoundUnlocks[plate][sound] = true
    local keys = {}
    for key in pairs(SoundUnlocks[plate]) do keys[#keys + 1] = key end
    table.sort(keys)
    MySQL.insert('INSERT INTO crimson_mechanic_sound_unlocks (plate, unlocks) VALUES (?, ?) ON DUPLICATE KEY UPDATE unlocks = VALUES(unlocks)', { plate, json.encode(keys) })
    publishSoundUnlocks()
end

--- Error code when a change set has an engine sound this shop can't fit on this car.
local function soundError(shop, vehicle, changes)
    if changes.engineSound == nil then return end
    if not shop.sounds then return 'sound_locked' end
    if not Items.soundAllowed(GetEntityModel(vehicle), changes.engineSound) then return 'invalid' end
end

-- ------------------------------------------------------------
-- Tickets
-- ------------------------------------------------------------

local function decodeTicket(row)
    local okC, changes = pcall(json.decode, row.changes or '')
    local okI, items = pcall(json.decode, row.items or '')
    return {
        id = row.id, shop = row.shop_id, citizenid = row.citizenid, customer = row.customer,
        plate = row.plate, model = row.model, estimate = row.estimate, created = row.created,
        changes = okC and changes or {}, items = okI and items or {},
    }
end

local function publicTicket(t)
    return {
        id = t.id, customer = t.customer, plate = t.plate, model = t.model, estimate = t.estimate,
        items = t.items, changes = t.changes, online = exports.qbx_core:GetPlayerByCitizenId(t.citizenid) ~= nil,
    }
end

local function closeTicket(id, status, extra)
    Tickets[id] = nil
    MySQL.update('UPDATE crimson_mechanic_tickets SET status = ?, price = ?, mechanic = ?, note = ? WHERE id = ?',
        { status, extra and extra.price, extra and extra.mechanic, extra and extra.note, id })
end

local function notifyMechanics(shop, message)
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if jobAccess(player, shop) then notify(player.PlayerData.source, message, 'inform') end
    end
end

local function notifyCitizen(citizenid, message, notifyType)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if player then notify(player.PlayerData.source, message, notifyType) end
end

-- ------------------------------------------------------------
-- Invoices (customer accept / decline)
-- ------------------------------------------------------------

local function sendOffer(target, payload)
    offerSeq = offerSeq + 1
    local offer = { id = offerSeq, promise = promise.new() }
    Offers[target] = offer
    payload.id, payload.timeout = offer.id, Config.OfferTimeout
    TriggerClientEvent('crimson-mechanic:client:offer', target, payload)
    SetTimeout((Config.OfferTimeout + 2) * 1000, function()
        if Offers[target] == offer then
            Offers[target] = nil
            offer.promise:resolve(false)
        end
    end)
    return Citizen.Await(offer.promise)
end

RegisterNetEvent('crimson-mechanic:server:respondOffer', function(offerId, accepted)
    local offer = Offers[source]
    if not offer or offer.id ~= offerId then return end
    Offers[source] = nil
    offer.promise:resolve(accepted == true)
end)

-- ------------------------------------------------------------
-- Preview snapshots (undo unpaid / cancelled work)
-- ------------------------------------------------------------

-- Whoever owns the vehicle right now restores it (see client/tuner.lua), so this
-- works even if the mechanic left the car, lost control of it or disconnected.
local function revertVehicle(netId, keys)
    local snap = Snapshots[netId]
    if not snap then return end
    Snapshots[netId] = nil
    if snap.hold then LiveryHold(netId, false) end
    if keys and #keys == 0 then return end -- nothing was changed, just release it

    local orig = snap.data.orig
    if keys then
        local want, subset = {}, {}
        for _, key in ipairs(keys) do if type(key) == 'string' then want[key] = true end end
        if want.wheelType then want['mod:23'], want['mod:24'], want.customTyres = true, true, true end
        for key in pairs(want) do subset[key] = orig[key] end
        orig = subset
    end

    local vehicle = vehicleFromNet(netId)
    if vehicle and plateOf(vehicle) == snap.plate then
        Entity(vehicle).state:set('crimsonRevert', { props = snap.data.props, orig = orig }, true)
    end
end

lib.callback.register('crimson-mechanic:server:snapshot', function(source, netId, data)
    netId = toInt(netId)
    local vehicle = vehicleFromNet(netId)
    if not vehicle or type(data) ~= 'table' or type(data.props) ~= 'table' or type(data.orig) ~= 'table' then return false end

    local coords = GetEntityCoords(vehicle)
    if #(GetEntityCoords(GetPlayerPed(source)) - coords) > 15.0 then return false end
    local atBench
    for _, shop in pairs(Shops) do
        if nearBench(coords, shop, 3.0) then atBench = shop break end
    end
    if not atBench then return false end

    local held = Snapshots[netId]
    if held and held.src ~= source and getPlayer(held.src) then return false end -- someone else is working on it
    if #json.encode(data.props) > 20000 then return false end

    local orig, count = {}, 0
    for key, value in pairs(data.orig) do
        local clean = Items.sanitize(key, value)
        if clean ~= nil then
            count = count + 1
            if count > 200 then return false end
            orig[key] = clean
        end
    end
    -- an unlock shop may preview locked Crimson liveries, so enforcement waits
    local hold = atBench.liveries and Liveries.entry(GetEntityModel(vehicle)) ~= nil
    Snapshots[netId] = { src = source, plate = plateOf(vehicle), hold = hold, data = { props = data.props, orig = orig } }
    if hold then LiveryHold(netId, true) end
    return true
end)

lib.callback.register('crimson-mechanic:server:revert', function(source, netId, keys)
    netId = toInt(netId)
    local snap = netId and Snapshots[netId]
    if not snap or snap.src ~= source then return false end
    revertVehicle(netId, type(keys) == 'table' and keys or nil)
    return true
end)

local function refund(token)
    local job = Installs[token]
    if not job then return end
    Installs[token] = nil
    revertVehicle(job.netId) -- paid work that never got saved is undone too
    local ticket = job.ticket and Tickets[job.ticket]
    if ticket then ticket.locked = nil end -- request goes back to the queue
    if job.price > 0 then exports.qbx_core:AddMoney(job.customerCid, Config.Account, job.price, 'mechanic-refund') end
    notifyCitizen(job.customerCid, Lang.notify.refunded:format(job.price), 'inform')
    log(job.src, 'mechanic:refund', 'Refunded $%d to %s for %s', job.price, job.customerCid, job.plate)
end

-- ------------------------------------------------------------
-- Mechanic callbacks
-- ------------------------------------------------------------

lib.callback.register('crimson-mechanic:server:getWorkshop', function(source, shopId)
    local shop = Shops[toInt(shopId)]
    local player = getPlayer(source)
    if not jobAccess(player, shop) then return result(false, 'no_permission') end
    local list = {}
    for _, t in pairs(Tickets) do
        if t.shop == shop.id then list[#list + 1] = publicTicket(t) end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { ok = true, tickets = list, ticketsOn = ticketsEnabled(shop), canToggle = isBoss(player, shop) or isAdmin(source) }
end)

lib.callback.register('crimson-mechanic:server:getNearby', function(source, shopId)
    local shop = Shops[toInt(shopId)]
    if not jobAccess(getPlayer(source), shop) then return {} end
    local origin = GetEntityCoords(GetPlayerPed(source))
    local bucket = GetPlayerRoutingBucket(source)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target ~= source and GetPlayerRoutingBucket(target) == bucket then
            local distance = #(GetEntityCoords(GetPlayerPed(target)) - origin)
            local player = distance <= Config.BillDistance and getPlayer(target)
            if player then list[#list + 1] = { id = target, name = charName(player.PlayerData), distance = distance } end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end)

lib.callback.register('crimson-mechanic:server:bill', function(source, data)
    if type(data) ~= 'table' or throttled(source) then return result(false, 'slow') end
    local shop = Shops[toInt(data.shopId)]
    local mechanic = getPlayer(source)
    if not jobAccess(mechanic, shop) then return result(false, 'no_permission') end
    if busy[source] then return result(false, 'busy') end

    local vehicle = vehicleFromNet(data.netId)
    if not vehicle or not nearBench(GetEntityCoords(vehicle), shop, 3.0) then return result(false, 'vehicle_far') end
    if not nearBench(GetEntityCoords(GetPlayerPed(source)), shop, 8.0) then return result(false, 'vehicle_far') end
    local plate = plateOf(vehicle)

    local changes, count = Items.sanitizeAll(data.changes)
    if not changes or count == 0 then return result(false, 'invalid') end
    local liveryCtx = Liveries.context(vehicle)
    local unlocks = Liveries.neededAll(liveryCtx and liveryCtx.entry, liveryCtx and liveryCtx.unlocks, changes)
    if #unlocks > 0 and not shop.liveries then return result(false, 'livery_locked') end
    local soundErr = soundError(shop, vehicle, changes)
    if soundErr then return result(false, soundErr) end
    local soundUnlock = Items.soundNeedsUnlock(vehicle, changes.engineSound) and changes.engineSound or nil
    local estimate = Items.total(changes, liveryCtx, vehicle)
    local price = toInt(data.price)
    if not price or price < 0 or price > Config.MaxPrice then return result(false, 'invalid') end
    local minimum = shop.allowBelow and 0 or math.floor(estimate * Config.MinPricePercent / 100)
    -- the unlocks themselves are never discounted
    minimum = math.max(minimum, #unlocks * Liveries.price + (soundUnlock and Config.SoundUnlockPrice or 0))
    if price < minimum then return result(false, 'below_min', minimum) end

    local ticket
    if data.ticketId then
        ticket = Tickets[toInt(data.ticketId)]
        if not ticket or ticket.shop ~= shop.id or ticket.plate ~= plate then return result(false, 'invalid') end
        -- another mechanic is already billing / installing this request
        if ticket.locked then return result(false, 'ticket_busy') end
    end

    local customer
    if ticket then
        customer = exports.qbx_core:GetPlayerByCitizenId(ticket.citizenid)
        if not customer then return result(false, 'customer_offline') end
        if customer.PlayerData.source == source and not shop.selfService then return result(false, 'no_self') end
    elseif data.target == 'self' then
        if not shop.selfService then return result(false, 'no_self') end
        customer = mechanic
    else
        customer = getPlayer(toInt(data.target) or -1)
        if not customer or customer.PlayerData.source == source then return result(false, 'customer_offline') end
    end

    local target = customer.PlayerData.source
    local isSelf = target == source
    if not isSelf then
        if #(GetEntityCoords(GetPlayerPed(target)) - GetEntityCoords(GetPlayerPed(source))) > Config.BillDistance + 5.0 then
            return result(false, 'customer_far')
        end
        if Offers[target] then return result(false, 'customer_busy') end
    end

    local lines = Items.lines(changes, data.lines, liveryCtx, vehicle)
    busy[source] = true
    if ticket then ticket.locked = source end
    local function fail(code)
        busy[source] = nil
        if ticket then ticket.locked = nil end
        return result(false, code)
    end

    if not isSelf then
        local summary = {}
        for i = 1, math.min(#lines, 12) do summary[i] = ('- %s'):format(lines[i].label) end
        if #lines > 12 then summary[#summary + 1] = ('- +%d more'):format(#lines - 12) end
        local accepted = sendOffer(target, {
            shop = shop.label, mechanic = charName(mechanic.PlayerData), plate = plate,
            price = price, summary = table.concat(summary, '\n'),
        })
        if not accepted then return fail('declined') end
    end

    customer = getPlayer(target)
    if not customer or not getPlayer(source) or not DoesEntityExist(vehicle) then return fail('customer_offline') end
    if ticket and not Tickets[ticket.id] then return fail('invalid') end -- cancelled while the invoice was open
    if not charge(target, price) then
        if not isSelf then notify(target, Lang.result.no_money, 'error') end
        return fail('no_money')
    end

    tokenSeq = tokenSeq + 1
    local token = ('%d-%d'):format(tokenSeq, math.random(100000, 999999))
    Installs[token] = {
        src = source, customerCid = customer.PlayerData.citizenid, price = price, shop = shop.id,
        plate = plate, netId = toInt(data.netId), changes = changes, ticket = ticket and ticket.id,
        self = isSelf, lines = lines, unlocks = unlocks, model = liveryCtx and liveryCtx.entry.name,
        soundUnlock = soundUnlock,
    }
    SetTimeout(Config.InstallTimeout * 1000, function()
        if Installs[token] then refund(token) end
    end)
    busy[source] = nil
    if not isSelf then notify(target, Lang.notify.paid:format(price, shop.label), 'success') end
    return result(true, 'paid', token)
end)

lib.callback.register('crimson-mechanic:server:commit', function(source, token, props)
    local job = Installs[token]
    if not job or job.src ~= source then return result(false, 'invalid') end

    local vehicle = vehicleFromNet(job.netId)
    if not vehicle or plateOf(vehicle) ~= job.plate or type(props) ~= 'table' then
        refund(token)
        return result(false, 'vehicle_far')
    end
    Installs[token] = nil
    local snap = Snapshots[job.netId]
    Snapshots[job.netId] = nil -- installed for real, nothing to undo

    local shop = Shops[job.shop]
    local mechanic = getPlayer(source)
    if #job.unlocks > 0 then
        local customer = exports.qbx_core:GetPlayerByCitizenId(job.customerCid)
        LiveryGrant(source, job.plate, job.model, job.unlocks, {
            mechanic = mechanic and ('%s (%s)'):format(charName(mechanic.PlayerData), mechanic.PlayerData.citizenid) or tostring(source),
            customer = customer and ('%s (%s)'):format(charName(customer.PlayerData), job.customerCid) or job.customerCid,
            shop = shop and shop.label or tostring(job.shop),
            price = job.price,
        })
        if not job.self then notifyCitizen(job.customerCid, Lang.notify.livery_unlocked:format(job.plate), 'success') end
    end
    -- released once clients have the new unlock, or they'd revert what was just bought
    if snap and snap.hold then SetTimeout(3000, function() LiveryHold(job.netId, false) end) end

    props.plate = job.plate
    LiverySanitizeProps(vehicle, job.plate, props) -- nothing locked the plate doesn't own gets saved
    local ok, success = pcall(function()
        return exports.qbx_vehicles:SaveVehicle(vehicle, { props = props })
    end)
    local saved = ok and success == true
    if job.changes.stance then setStance(job.plate, job.changes.stance) end
    if job.changes.engineSound then setSound(job.plate, GetEntityModel(vehicle), job.changes.engineSound) end
    if job.soundUnlock then
        grantSound(job.plate, job.soundUnlock)
        log(source, 'mechanic:exhaust', '%s unlocked exhaust system %s on %s for customer %s ($%d bill)',
            mechanic and charName(mechanic.PlayerData) or source, job.soundUnlock, job.plate, job.customerCid, job.price)
        if not job.self then notifyCitizen(job.customerCid, Lang.notify.sound_unlocked:format(job.plate), 'success') end
    end

    local jobName = mechanic and mechanic.PlayerData.job.name
    if job.self then
        societyAdd(jobName, job.price)
    else
        local cut = math.floor(job.price * ((shop and shop.commission) or Config.DefaultCommission) / 100)
        if cut > 0 then
            exports.qbx_core:AddMoney(source, Config.Account, cut, 'mechanic-commission')
            notify(source, Lang.notify.earned:format(cut), 'success')
        end
        societyAdd(jobName, job.price - cut)
    end

    if job.ticket then
        closeTicket(job.ticket, 'completed', { price = job.price, mechanic = mechanic and mechanic.PlayerData.citizenid })
    end
    if not job.self then notifyCitizen(job.customerCid, Lang.notify.ticket_done:format(job.plate), 'success') end

    log(source, 'mechanic:install', '%s installed %d change(s) on %s for $%d (customer %s%s)',
        mechanic and charName(mechanic.PlayerData) or source, #job.lines, job.plate, job.price, job.customerCid,
        job.ticket and (', ticket #' .. job.ticket) or '')
    return result(true, saved and 'installed' or 'not_saved')
end)

lib.callback.register('crimson-mechanic:server:rejectTicket', function(source, ticketId, reason)
    local ticket = Tickets[toInt(ticketId)]
    local player = getPlayer(source)
    if not ticket or not jobAccess(player, Shops[ticket.shop]) then return result(false, 'no_permission') end
    if ticket.locked then return result(false, 'ticket_busy') end
    reason = cleanText(reason, 200)
    closeTicket(ticket.id, 'rejected', { mechanic = player.PlayerData.citizenid, note = reason })
    notifyCitizen(ticket.citizenid, Lang.notify.ticket_rejected:format(Shops[ticket.shop].label, reason ~= '' and reason or '-'), 'error')
    return result(true, 'ticket_rejected')
end)

lib.callback.register('crimson-mechanic:server:toggleTickets', function(source, shopId)
    if throttled(source) then return result(false, 'slow') end
    local shop = Shops[toInt(shopId)]
    if not shop then return result(false, 'invalid') end
    local player = getPlayer(source)
    if not isAdmin(source) and not (jobAccess(player, shop) and isBoss(player, shop)) then return result(false, 'no_permission') end
    shop.tickets = not shop.tickets
    saveShop(shop)
    log(source, 'mechanic:toggle', 'Request system of %s set to %s', shop.label, tostring(shop.tickets))
    return result(true, 'toggled', shop.tickets and Lang.on or Lang.off)
end)

-- ------------------------------------------------------------
-- Customer callbacks
-- ------------------------------------------------------------

lib.callback.register('crimson-mechanic:server:getMyTicket', function(source, shopId, netId)
    local shop = Shops[toInt(shopId)]
    local player = getPlayer(source)
    local vehicle = vehicleFromNet(netId)
    if not shop or not player or not vehicle then return end
    local plate, cid = plateOf(vehicle), player.PlayerData.citizenid
    for _, t in pairs(Tickets) do
        if t.shop == shop.id and t.plate == plate and t.citizenid == cid then return publicTicket(t) end
    end
end)

lib.callback.register('crimson-mechanic:server:cancelTicket', function(source, ticketId)
    local ticket = Tickets[toInt(ticketId)]
    local player = getPlayer(source)
    if not ticket or not player or ticket.citizenid ~= player.PlayerData.citizenid then return result(false, 'invalid') end
    if ticket.locked then return result(false, 'ticket_busy') end
    closeTicket(ticket.id, 'cancelled')
    return result(true, 'ticket_cancelled')
end)

lib.callback.register('crimson-mechanic:server:createTicket', function(source, data)
    if type(data) ~= 'table' or throttled(source) then return result(false, 'slow') end
    local shop = Shops[toInt(data.shopId)]
    local player = getPlayer(source)
    if not shop or not player then return result(false, 'invalid') end
    if not ticketsEnabled(shop) then return result(false, 'tickets_off') end

    local vehicle = vehicleFromNet(data.netId)
    if not vehicle or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then return result(false, 'not_driver') end
    if not nearBench(GetEntityCoords(vehicle), shop, 3.0) then return result(false, 'vehicle_far') end

    local plate, cid = plateOf(vehicle), player.PlayerData.citizenid
    if Config.RequireOwnership then
        local owner = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
        if owner ~= cid then return result(false, 'not_owner') end
    end

    local changes, count = Items.sanitizeAll(data.changes)
    if not changes or count == 0 then return result(false, 'invalid') end
    local liveryCtx = Liveries.context(vehicle)
    if not shop.liveries and #Liveries.neededAll(liveryCtx and liveryCtx.entry, liveryCtx and liveryCtx.unlocks, changes) > 0 then
        return result(false, 'livery_locked')
    end
    local soundErr = soundError(shop, vehicle, changes)
    if soundErr then return result(false, soundErr) end

    local open, replaced = 0, nil
    for _, t in pairs(Tickets) do
        if t.citizenid == cid then
            if t.shop == shop.id and t.plate == plate then
                if t.locked then return result(false, 'ticket_busy') end -- being worked on right now
                replaced = t.id
            else
                open = open + 1
            end
        end
    end
    if open >= Config.MaxOpenTickets then return result(false, 'too_many', Config.MaxOpenTickets) end
    if replaced then closeTicket(replaced, 'cancelled', { note = 'replaced' }) end

    local items = Items.lines(changes, data.lines, liveryCtx, vehicle)
    local estimate = Items.total(changes, liveryCtx, vehicle)
    local ticket = {
        shop = shop.id, citizenid = cid, customer = charName(player.PlayerData), plate = plate,
        model = cleanText(data.model, 64), changes = changes, items = items, estimate = estimate, created = os.time(),
    }
    ticket.id = MySQL.insert.await(
        'INSERT INTO crimson_mechanic_tickets (shop_id, citizenid, customer, plate, model, changes, items, estimate) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { shop.id, cid, ticket.customer, plate, ticket.model, json.encode(changes), json.encode(items), estimate })
    if not ticket.id then return result(false, 'error') end
    Tickets[ticket.id] = ticket

    notifyMechanics(shop, Lang.notify.new_ticket:format(shop.label, plate))
    log(source, 'mechanic:ticket', '%s opened request #%d on %s at %s ($%d)', ticket.customer, ticket.id, plate, shop.label, estimate)
    return result(true, 'ticket_created', ticket.id, estimate)
end)

-- ------------------------------------------------------------
-- Admin
-- ------------------------------------------------------------

lib.addCommand(Config.AdminCommand, { help = 'Mechanic shop editor', restricted = Config.AdminGroup }, function(source)
    TriggerClientEvent('crimson-mechanic:client:admin', source)
end)

local function adminCallback(name, handler)
    lib.callback.register(name, function(source, ...)
        if not isAdmin(source) then return result(false, 'no_permission') end
        return handler(source, ...)
    end)
end

adminCallback('crimson-mechanic:server:admin:jobs', function()
    local list = {}
    for name, job in pairs(exports.qbx_core:GetJobs()) do
        list[#list + 1] = { value = name, label = ('%s (%s)'):format(job.label or name, name) }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return { ok = true, jobs = list }
end)

adminCallback('crimson-mechanic:server:admin:saveShop', function(source, data)
    if type(data) ~= 'table' then return result(false, 'invalid') end
    local label = cleanText(data.label, 48)
    if label == '' then return result(false, 'invalid') end

    local grade = math.max(0, toInt(data.grade) or 0)
    local jobs = {}
    for _, name in ipairs(type(data.jobs) == 'table' and data.jobs or {}) do
        if type(name) == 'string' and exports.qbx_core:GetJob(name) then jobs[name] = grade end
    end

    local valid, categories = {}, {}
    for _, id in ipairs(allCategories) do valid[id] = true end
    for _, id in ipairs(type(data.categories) == 'table' and data.categories or {}) do
        if valid[id] then categories[#categories + 1] = id end
    end

    local shop = Shops[toInt(data.id) or -1]
    if not shop then
        shop = { points = {}, washes = {} }
    end
    shop.label = label
    shop.jobs = jobs
    shop.duty = data.duty == true
    shop.tickets = data.tickets == true
    shop.selfService = data.selfService == true
    shop.allowBelow = data.allowBelow == true
    shop.commission = math.max(0, math.min(100, toInt(data.commission) or Config.DefaultCommission))
    shop.blip = data.blip == true
    shop.categories = #categories > 0 and categories or allCategories
    shop.liveries = data.liveries == true
    shop.sounds = data.sounds == true

    if shop.id then
        saveShop(shop)
    else
        shop.id = MySQL.insert.await('INSERT INTO crimson_mechanic_shops (label, data) VALUES (?, ?)', { label, json.encode(stored(shop)) })
        if not shop.id then return result(false, 'error') end
        Shops[shop.id] = shop
        publish()
    end
    log(source, 'mechanic:admin', 'Saved shop #%d %s', shop.id, label)
    return result(true, 'saved', shop.id)
end)

adminCallback('crimson-mechanic:server:admin:deleteShop', function(source, shopId)
    local shop = Shops[toInt(shopId)]
    if not shop then return result(false, 'invalid') end
    Shops[shop.id] = nil
    MySQL.update.await('DELETE FROM crimson_mechanic_shops WHERE id = ?', { shop.id })
    for id, t in pairs(Tickets) do
        if t.shop == shop.id then closeTicket(id, 'cancelled', { note = 'shop deleted' }) end
    end
    publish()
    log(source, 'mechanic:admin', 'Deleted shop #%d %s', shop.id, shop.label)
    return result(true, 'deleted')
end)

-- WaveShield bypass (crimson-wsbypass) for the editor's "teleport to bench" button
adminCallback('crimson-mechanic:server:admin:wsBypass', function(source)
    if GetResourceState('crimson-wsbypass') ~= 'started' then return false end
    return exports['crimson-wsbypass']:Temp(source, 5, 'mechanic-admin-tp')
end)

adminCallback('crimson-mechanic:server:admin:addPoint', function(source, shopId, point)
    local shop = Shops[toInt(shopId)]
    if not shop or type(point) ~= 'table' then return result(false, 'invalid') end
    local x, y, z = tonumber(point.x), tonumber(point.y), tonumber(point.z)
    if not x or not y or not z then return result(false, 'invalid') end
    if #shop.points >= 30 then return result(false, 'max_points') end
    local r = math.max(0.5, math.min(10.0, tonumber(point.r) or 3.0))
    local round = function(n) return math.floor(n * 100 + 0.5) / 100 end
    shop.points[#shop.points + 1] = { x = round(x), y = round(y), z = round(z), r = round(r) }
    saveShop(shop)
    log(source, 'mechanic:admin', 'Added bench to %s at %.2f %.2f %.2f', shop.label, x, y, z)
    return result(true, 'saved')
end)

adminCallback('crimson-mechanic:server:admin:removePoint', function(source, shopId, index)
    local shop = Shops[toInt(shopId)]
    index = toInt(index)
    if not shop or not index or not shop.points[index] then return result(false, 'invalid') end
    table.remove(shop.points, index)
    saveShop(shop)
    return result(true, 'deleted')
end)

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

-- Station type: 'auto' = automatic machine, nil = self-wash with the hose.
local function washDefaults(station)
    return station.type == 'auto' and Config.Wash.auto or Config.Wash
end

local function washPrice(value, station)
    return math.max(0, math.min(Config.MaxPrice, toInt(value) or washDefaults(station).price))
end

local function washRadius(value, station)
    return round2(math.max(0.5, math.min(10.0, tonumber(value) or washDefaults(station).radius)))
end

adminCallback('crimson-mechanic:server:admin:addWash', function(source, shopId, data)
    local shop = Shops[toInt(shopId)]
    if not shop or type(data) ~= 'table' then return result(false, 'invalid') end
    local auto = data.type == 'auto'
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local hx, hy, hz = tonumber(data.hx), tonumber(data.hy), tonumber(data.hz)
    if not x or not y or not z then return result(false, 'invalid') end
    if not auto and (not hx or not hy or not hz) then return result(false, 'invalid') end
    if #shop.washes >= 10 then return result(false, 'max_washes') end
    local station = { type = auto and 'auto' or nil, x = round2(x), y = round2(y), z = round2(z) }
    station.r = washRadius(data.r, station)
    station.price = washPrice(data.price, station)
    if not auto then station.hx, station.hy, station.hz = round2(hx), round2(hy), round2(hz) end
    shop.washes[#shop.washes + 1] = station
    saveShop(shop)
    log(source, 'mechanic:admin', 'Added %s wash station to %s at %.2f %.2f %.2f', auto and 'auto' or 'self', shop.label, x, y, z)
    return result(true, 'saved')
end)

adminCallback('crimson-mechanic:server:admin:editWash', function(_, shopId, index, price, radius)
    local shop = Shops[toInt(shopId)]
    local station = shop and shop.washes[toInt(index) or -1]
    if not station then return result(false, 'invalid') end
    station.price = washPrice(price, station)
    station.r = washRadius(radius, station)
    saveShop(shop)
    return result(true, 'saved')
end)

adminCallback('crimson-mechanic:server:admin:removeWash', function(_, shopId, index)
    local shop = Shops[toInt(shopId)]
    index = toInt(index)
    if not shop or not index or not shop.washes[index] then return result(false, 'invalid') end
    table.remove(shop.washes, index)
    saveShop(shop)
    return result(true, 'deleted')
end)

-- ------------------------------------------------------------
-- Wash stations
-- ------------------------------------------------------------

local Washes = {} -- source -> wash in progress

local function chargeWash(source, amount)
    if amount <= 0 then return true end
    for _, account in ipairs(Config.Wash.accounts) do
        local balance = exports.qbx_core:GetMoney(source, account)
        if type(balance) == 'number' and balance >= amount
            and exports.qbx_core:RemoveMoney(source, account, amount, 'car-wash') then
            return true
        end
    end
    return false
end

local function washJob(shop)
    local names = {}
    for name in pairs(shop.jobs) do names[#names + 1] = name end
    table.sort(names)
    return names[1]
end

lib.callback.register('crimson-mechanic:server:washStart', function(source, shopId, index, netId)
    if not Config.Wash.enabled then return result(false, 'invalid') end
    if throttled(source) then return result(false, 'slow') end
    if Washes[source] then return result(false, 'busy') end

    local shop = Shops[toInt(shopId) or -1]
    local station = shop and shop.washes[toInt(index) or -1]
    local vehicle = vehicleFromNet(netId)
    if not station or not vehicle then return result(false, 'invalid') end

    local bay = vector3(station.x, station.y, station.z)
    if #(GetEntityCoords(vehicle) - bay) > Config.Wash.bayDistance + 2.0
        or #(GetEntityCoords(GetPlayerPed(source)) - bay) > station.r + 3.0 then
        return result(false, 'vehicle_far')
    end
    netId = toInt(netId)
    for _, w in pairs(Washes) do
        if w.netId == netId then return result(false, 'wash_busy') end
    end

    local price = station.price or washDefaults(station).price
    -- self-wash: the whole hose routine; auto: the machine cycle
    local duration = station.type == 'auto' and Config.Wash.auto.duration or Config.Wash.duration
    if price > 0 then
        local total = 0
        for _, account in ipairs(Config.Wash.accounts) do
            total = math.max(total, tonumber(exports.qbx_core:GetMoney(source, account)) or 0)
        end
        if total < price then return result(false, 'wash_no_money', price) end
    end

    Washes[source] = { shop = shop.id, netId = netId, started = GetGameTimer(), duration = duration, price = price, plate = plateOf(vehicle) }
    return result(true, 'ok', price)
end)

-- Dirt during a wash: the washer may not own the car, so the level goes on the car's
-- state bag and whoever owns it applies it (client/wash.lua).
local function setWashDirt(w, level)
    local vehicle = w and vehicleFromNet(w.netId)
    if vehicle then Entity(vehicle).state:set('crimsonDirt', level, true) end
end

RegisterNetEvent('crimson-mechanic:server:washDirt', function(level)
    level = tonumber(level)
    if not level then return end
    setWashDirt(Washes[source], math.floor(math.max(0.0, math.min(15.0, level)) * 10 + 0.5) / 10)
end)

lib.callback.register('crimson-mechanic:server:washFinish', function(source)
    local w = Washes[source]
    Washes[source] = nil
    if not w then return result(false, 'invalid') end
    setWashDirt(w, nil)
    if GetGameTimer() - w.started < w.duration * 0.9 then return result(false, 'invalid') end

    local vehicle = vehicleFromNet(w.netId)
    if not vehicle or plateOf(vehicle) ~= w.plate then return result(false, 'invalid') end
    if not chargeWash(source, w.price) then return result(false, 'wash_no_money', w.price) end

    local shop = Shops[w.shop]
    if shop and Config.Wash.society and w.price > 0 then societyAdd(washJob(shop), w.price) end
    -- whoever owns the vehicle applies it (client/wash.lua)
    Entity(vehicle).state:set('crimsonWashed', os.time(), true)
    log(source, 'mechanic:wash', 'Washed %s at %s for $%d', w.plate, shop and shop.label or '?', w.price)
    return result(true, 'washed')
end)

RegisterNetEvent('crimson-mechanic:server:washCancel', function()
    setWashDirt(Washes[source], nil)
    Washes[source] = nil
end)

-- ------------------------------------------------------------
-- Boot / cleanup
-- ------------------------------------------------------------

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `crimson_mechanic_shops` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `label` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `crimson_mechanic_tickets` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `shop_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `customer` VARCHAR(100) NULL,
            `plate` VARCHAR(16) NOT NULL,
            `model` VARCHAR(64) NULL,
            `changes` LONGTEXT NOT NULL,
            `items` LONGTEXT NOT NULL,
            `estimate` INT NOT NULL DEFAULT 0,
            `price` INT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
            `mechanic` VARCHAR(50) NULL,
            `note` VARCHAR(255) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX `status_shop` (`status`, `shop_id`)
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `crimson_mechanic_stance` (
            `plate` VARCHAR(16) NOT NULL PRIMARY KEY,
            `data` TEXT NOT NULL
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `crimson_mechanic_sounds` (
            `plate` VARCHAR(16) NOT NULL PRIMARY KEY,
            `sound` VARCHAR(64) NOT NULL
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `crimson_mechanic_sound_unlocks` (
            `plate` VARCHAR(16) NOT NULL PRIMARY KEY,
            `unlocks` TEXT NOT NULL
        )
    ]])
    if Config.Society == 'aj_job_accounts' then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `aj_job_accounts` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `job_name` VARCHAR(60) UNIQUE NOT NULL,
                `amount` INT DEFAULT 0,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]])
    end

    MySQL.update.await("UPDATE crimson_mechanic_tickets SET status = 'expired' WHERE status = 'pending' AND created_at < (NOW() - INTERVAL ? DAY)", { Config.TicketExpireDays })

    for _, row in ipairs(MySQL.query.await('SELECT id, label, data FROM crimson_mechanic_shops') or {}) do
        Shops[row.id] = decodeShop(row)
    end
    for _, row in ipairs(MySQL.query.await("SELECT id, shop_id, citizenid, customer, plate, model, changes, items, estimate, UNIX_TIMESTAMP(created_at) AS created FROM crimson_mechanic_tickets WHERE status = 'pending'") or {}) do
        Tickets[row.id] = decodeTicket(row)
    end
    for _, row in ipairs(MySQL.query.await('SELECT plate, data FROM crimson_mechanic_stance') or {}) do
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == 'table' then Stances[row.plate] = data end
    end
    for _, row in ipairs(MySQL.query.await('SELECT plate, sound FROM crimson_mechanic_sounds') or {}) do
        Sounds[row.plate] = row.sound
    end
    for _, row in ipairs(MySQL.query.await('SELECT plate, unlocks FROM crimson_mechanic_sound_unlocks') or {}) do
        local ok, keys = pcall(json.decode, row.unlocks)
        if ok and type(keys) == 'table' then
            local set = {}
            for _, key in ipairs(keys) do set[key] = true end
            SoundUnlocks[row.plate] = set
        end
    end
    publish()
    publishStances()
    publishSounds()
    publishSoundUnlocks()
end)

local function cleanup(source)
    if Washes[source] then setWashDirt(Washes[source], nil) end
    busy[source], lastAction[source], Washes[source] = nil, nil, nil
    local offer = Offers[source]
    if offer then
        Offers[source] = nil
        offer.promise:resolve(false)
    end
    for token, job in pairs(Installs) do
        if job.src == source then refund(token) end
    end
    for _, t in pairs(Tickets) do
        if t.locked == source then t.locked = nil end
    end
    for netId, snap in pairs(Snapshots) do
        if snap.src == source then revertVehicle(netId) end
    end
end

AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('qbx_core:server:playerLoggedOut', cleanup)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for token in pairs(Installs) do refund(token) end
    for netId in pairs(Snapshots) do revertVehicle(netId) end
end)
