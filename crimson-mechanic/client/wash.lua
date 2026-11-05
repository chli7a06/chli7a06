-- Wash stations: the player takes a hose hanging from the canopy and aims the jet at the
-- car themselves (hold LMB, aim with the camera). Each stage (rinse, foam, scrub, final
-- rinse) needs every side of the car covered; the dirt goes down as they work.
-- Gun, hose and jet are local props/effects on every client, rebuilt from the washer's
-- 'crimsonWash' state bag (same idea as ox_fuel's hose), so nothing networked is spawned.
local W = Config.Wash
local L = Lang.wash
local STATE_KEY = 'crimsonWash'
local REMOTE_RANGE = 60.0
local ZONES = { 'front', 'left', 'right', 'rear' }
local UNARMED = `WEAPON_UNARMED`

local points = {}
local prompt, promptText = nil, nil
local washing = false
local sessionCount = 0
local visuals = {} -- [serverId] = { id, tool, visual, loading }

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

local function takeControl(veh)
    if NetworkGetEntityOwner(veh) == cache.playerId then return true end
    NetworkRequestControlOfEntity(veh)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(veh)
    end
    return NetworkHasControlOfEntity(veh)
end

local function cleanVehicle(veh)
    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)
end

-- ------------------------------------------------------------
-- Visuals (every client, from the state bag)
-- ------------------------------------------------------------

local function stopJet(v)
    if v and v.fx then
        StopParticleFxLooped(v.fx, false)
        v.fx, v.fxKey = nil, nil
    end
end

local function destroyVisual(v)
    if not v or v.destroyed then return end
    v.destroyed = true
    stopJet(v)
    if v.rope and DoesRopeExist(v.rope) then DeleteRope(v.rope) end
    if v.tool and DoesEntityExist(v.tool) then DeleteEntity(v.tool) end
    if v.anchor and DoesEntityExist(v.anchor) then DeleteEntity(v.anchor) end
    v.rope, v.tool, v.anchor, v.hoseMesh = nil, nil, nil, nil
end

-- ox_lib asset requests may yield or raise on timeout. Check native readiness,
-- not an undocumented return value, before creating the visuals.
local function requestModel(model)
    local ok = pcall(lib.requestModel, model, 5000)
    return ok and HasModelLoaded(model)
end

local function attachTool(entity, ped, hand)
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, hand.bone),
        hand.pos.x, hand.pos.y, hand.pos.z, hand.rot.x, hand.rot.y, hand.rot.z,
        true, true, false, true, hand.rotOrder or 0, true)
end

local function updateHose(v)
    if not v or v.destroyed or not v.rope or not DoesRopeExist(v.rope)
        or not DoesEntityExist(v.tool) or not DoesEntityExist(v.anchor) then return end
    local t = W.hose.tip
    local tip = GetOffsetFromEntityInWorldCoords(v.tool, t.x, t.y, t.z)
    local anchor = GetEntityCoords(v.anchor)
    local length = math.max(0.5, math.min(v.hoseMaxLength, #(tip - anchor) + (W.hose.visibleSlack or 0.75)))
    if not v.hoseLength or math.abs(v.hoseLength - length) > 0.1 then
        RopeForceLength(v.rope, length)
        v.hoseLength = length
    end
    if W.hose.pinEnds ~= false then
        local count = GetRopeVertexCount(v.rope)
        if count > 1 then
            PinRopeVertex(v.rope, 0, tip.x, tip.y, tip.z)
            PinRopeVertex(v.rope, count - 1, anchor.x, anchor.y, anchor.z)
        end
    end
end

local function addHose(v, data, isCurrent)
    if W.hose.renderer == 'rubber' then
        if not isCurrent() then return end
        v.hoseMesh = true
        v.hoseAnchor = vec3(data.ax, data.ay, data.az)
        v.hoseMaxLength = data.len
        return
    end
    local model = joaat(W.hose.anchorModel)
    if not requestModel(model) then return end
    if not isCurrent() then SetModelAsNoLongerNeeded(model); return end
    local a = vec3(data.ax, data.ay, data.az)
    v.anchor = CreateObjectNoOffset(model, a.x, a.y, a.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if v.anchor == 0 then v.anchor = nil return end
    SetEntityAsMissionEntity(v.anchor, true, true)
    SetEntityCollision(v.anchor, false, false)
    SetEntityAlpha(v.anchor, 0, false)
    FreezeEntityPosition(v.anchor, true)

    Wait(100)
    RopeLoadTextures()
    local timeout = GetGameTimer() + 5000
    while not RopeAreTexturesLoaded() and GetGameTimer() < timeout do Wait(50) end
    if not isCurrent() or not RopeAreTexturesLoaded() or not DoesEntityExist(v.tool) then return end

    local t = W.hose.tip
    local tip = GetOffsetFromEntityInWorldCoords(v.tool, t.x, t.y, t.z)
    local length = math.max(0.5, math.min(data.len, #(tip - a) + (W.hose.visibleSlack or 0.75)))
    local rope = AddRope(a.x, a.y, a.z, 0.0, 0.0, 0.0, length, W.hose.ropeType, length, 0.5, 1.0, false, false, false, 1.0, false, 0)
    if not rope or not DoesRopeExist(rope) then return end
    v.rope, v.hoseMaxLength = rope, data.len
    -- A custom YDR without a collision body is not a reliable physics anchor.
    -- Pin both endpoints directly; they are refreshed from the animated prop.
    if W.hose.pinEnds == false then
        AttachEntitiesToRope(rope, v.tool, v.anchor, tip.x, tip.y, tip.z, a.x, a.y, a.z, length, false, false, nil, nil)
    end
    updateHose(v)
end

local function createVisual(ped, data, isCurrent, onCreated)
    local tool = W.tools[data.tool]
    if not tool then return end
    local model = joaat(tool.model)
    if not requestModel(model) then return end
    if not isCurrent() or not DoesEntityExist(ped) then SetModelAsNoLongerNeeded(model); return end

    local v = { ped = ped, toolKey = data.tool, remote = ped ~= cache.ped }
    local c = GetEntityCoords(ped)
    v.tool = CreateObject(model, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if v.tool == 0 or not DoesEntityExist(ped) then
        destroyVisual(v)
        return
    end
    SetEntityAsMissionEntity(v.tool, true, true)
    SetEntityCollision(v.tool, false, false)
    if tool.hidden then SetEntityAlpha(v.tool, 0, false) end
    attachTool(v.tool, ped, tool.hand)
    onCreated(v) -- Register partial visuals before any yielding hose setup.
    if tool.hose then addHose(v, data, isCurrent) end
    if not isCurrent() then destroyVisual(v); return end
    if tool.hose and not v.rope and not v.hoseMesh and not v.remote then
        notify('Unable to create the wash hose. Check the station anchor and rope textures.', 'error')
    end
    return v
end

local function washAnimation(tool, pressing)
    return pressing and tool.aimAnim or ((pressing or tool.hose) and tool.anim or nil)
end

--- Effect APIs take a ped-local offset. Convert the model's actual muzzle
--- into ped space; keep the original hand offset as a fallback for other tools.
local function nozzleOffset(ped, visual)
    if not visual and ped == cache.ped then
        local own = visuals[cache.serverId]
        visual = own and own.visual
    end
    local tool = visual and W.tools[visual.toolKey]
    if tool and tool.muzzle and visual.tool and DoesEntityExist(visual.tool) then
        local m = tool.muzzle
        local world = GetOffsetFromEntityInWorldCoords(visual.tool, m.x, m.y, m.z)
        return GetOffsetFromEntityGivenWorldCoords(ped, world.x, world.y, world.z)
    end
    local hand = GetPedBoneCoords(ped, W.nozzleBone, 0.0, 0.0, 0.0)
    return GetOffsetFromEntityGivenWorldCoords(ped, hand.x, hand.y, hand.z) + W.nozzle
end

--- Other players' jets are drawn at world coords (an effect looped on a remote ped is only
--- seen by its owner), so the nozzle position and rotation are worked out here.
local function jetWorld(v)
    local n, c = nozzleOffset(v.ped, v), W.effects[v.fxKey].rot
    local pos = GetOffsetFromEntityInWorldCoords(v.ped, n.x, n.y, n.z)
    return pos, vec3(v.pitch + c.x, c.y, GetEntityHeading(v.ped) + v.yaw + c.z)
end

--- Points the jet: pitch = up/down, yaw = left/right of where the ped faces (degrees).
--- Also moves it to the hand, so it is called every frame while a jet is on (see below).
local function aimJet(v, pitch, yaw)
    if not v or not v.fx then return end
    v.pitch, v.yaw = pitch or v.pitch or 0.0, yaw or v.yaw or 0.0
    if v.remote then
        local pos, rot = jetWorld(v)
        SetParticleFxLoopedOffsets(v.fx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z)
        return
    end
    local n, c = nozzleOffset(v.ped, v), W.effects[v.fxKey].rot
    SetParticleFxLoopedOffsets(v.fx, n.x, n.y, n.z, v.pitch + c.x, c.y, v.yaw + c.z)
end

--- Jet on (fx = key in Config.Wash.effects) or off (fx = nil).
local function setJet(v, fx, pitch, yaw)
    if not v or v.destroyed or not DoesEntityExist(v.ped) then return end
    if v.fxKey ~= fx then stopJet(v) end
    local effect = fx and W.effects[fx]
    if not effect then return end
    if not v.fx then
        local loaded = pcall(lib.requestNamedPtfxAsset, effect.asset, 5000)
        if not loaded or not HasNamedPtfxAssetLoaded(effect.asset) or v.destroyed or not DoesEntityExist(v.ped) then return end
        if v.remote then
            v.fxKey, v.pitch, v.yaw = fx, pitch or 0.0, yaw or 0.0
            local pos, rot = jetWorld(v)
            UseParticleFxAssetNextCall(effect.asset)
            v.fx = StartParticleFxLoopedAtCoord(effect.name, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, effect.scale, false, false, false, false)
        else
            local n = nozzleOffset(v.ped, v)
            UseParticleFxAssetNextCall(effect.asset)
            v.fx = StartParticleFxLoopedOnEntity(effect.name, v.ped, n.x, n.y, n.z, effect.rot.x, effect.rot.y, effect.rot.z, effect.scale, false, false, false)
        end
        v.fxKey = fx
        RemoveNamedPtfxAsset(effect.asset)
    end
    aimJet(v, pitch or 0.0, yaw or 0.0)
end


-- The Blender hose is a static curved mesh. Its binary YDR cannot be
-- stretched by a rope native. Draw a round rubber tube along a live curve
-- using the same source radius, without replacing global GTA rope textures.
local function drawRubberHose(v)
    if not v.hoseMesh or not v.tool or not DoesEntityExist(v.tool) then return end
    local a = v.hoseAnchor
    local t = W.hose.tip
    local b = GetOffsetFromEntityInWorldCoords(v.tool, t.x, t.y, t.z)
    local midpoint = vec3((a.x+b.x)*0.5, (a.y+b.y)*0.5, (a.z+b.z)*0.5)
    local viewDistance = #(GetEntityCoords(cache.ped) - midpoint)
    if viewDistance > (W.hose.renderDistance or 35.0) then return end
    local segments = math.max(4, math.min(24, math.floor(W.hose.segments or 16)))
    if viewDistance > 12 then segments = math.min(segments, 8) end
    local sides = math.max(6, math.min(10, math.floor(W.hose.sides or 8)))
    local radius = math.max(0.003, math.min(0.02, W.hose.radius or 0.008))
    local dx, dy, dz = b.x-a.x, b.y-a.y, b.z-a.z
    local distance = math.sqrt(dx*dx+dy*dy+dz*dz)
    if distance < 0.02 then return end
    local horizontal = math.sqrt(dx*dx+dy*dy)
    local sideX, sideY = 1.0, 0.0
    if horizontal > 0.001 then sideX, sideY = -dy/horizontal, dx/horizontal end
    local sag = math.min(0.9, distance*0.15)
    local now = GetGameTimer()
    if not v.groundCheckedAt or now-v.groundCheckedAt > 500 then
        v.groundCheckedAt = now
        local found, ground = GetGroundZFor_3dCoord(midpoint.x, midpoint.y, math.max(a.z,b.z)+5.0, false)
        v.hoseGround = found and ground or nil
    end
    if not v.hoseCircle or #v.hoseCircle ~= sides then
        v.hoseCircle = {}
        for j=0,sides-1 do
            local angle=j*math.pi*2/sides
            v.hoseCircle[j+1]={c=math.cos(angle),s=math.sin(angle)}
        end
    end
    local rings = v.hoseRings or {}
    v.hoseRings = rings
    for i=0,segments do
        local u = i/segments
        local x,y,z = a.x+dx*u, a.y+dy*u, a.z+dz*u-4*sag*u*(1-u)
        if i>0 and i<segments and v.hoseGround then z=math.max(z,v.hoseGround+radius) end
        local tangentZ = dz-4*sag*(1-2*u)
        local tangentLength = math.sqrt(dx*dx+dy*dy+tangentZ*tangentZ)
        local tx,ty,tz = 0.0,0.0,1.0
        if tangentLength > 0.0001 then tx,ty,tz=dx/tangentLength,dy/tangentLength,tangentZ/tangentLength end
        local ux,uy,uz = -tz*sideY,tz*sideX,tx*sideY-ty*sideX
        local upLength = math.sqrt(ux*ux+uy*uy+uz*uz)
        if upLength < 0.001 then ux,uy,uz,upLength=0,1,0,1 end
        ux,uy,uz=ux/upLength,uy/upLength,uz/upLength
        local ring=rings[i+1] or {}
        for j=1,sides do
            local circle=v.hoseCircle[j]
            local c,s=circle.c*radius,circle.s*radius
            local vertex=ring[j] or {}
            vertex.x,vertex.y,vertex.z=x+sideX*c+ux*s,y+sideY*c+uy*s,z+uz*s
            ring[j]=vertex
        end
        rings[i+1]=ring
    end
    for i=1,segments do
        for j=1,sides do
            local nextJ=j%sides+1
            local p,q,r,s=rings[i][j],rings[i][nextJ],rings[i+1][nextJ],rings[i+1][j]
            -- A subtle cylindrical highlight, with no braided rope texture.
            local shade=12+math.floor(6*math.max(0,math.sin(j*math.pi*2/sides)))
            DrawPoly(p.x,p.y,p.z,q.x,q.y,q.z,r.x,r.y,r.z,shade,shade+1,shade+2,255)
            DrawPoly(p.x,p.y,p.z,r.x,r.y,r.z,s.x,s.y,s.z,shade,shade+1,shade+2,255)
        end
    end
end

-- Keep particles at the muzzle and adjust hose slack as the player moves.
CreateThread(function()
    while true do
        local activeJet, activeHose = false, false
        for _, entry in pairs(visuals) do
            local v = entry.visual
            if v and not v.destroyed and DoesEntityExist(v.ped) then
                if v.fx then activeJet = true; aimJet(v) end
                if v.rope then activeHose = true; updateHose(v) end
                if v.hoseMesh then activeHose = true; drawRubberHose(v) end
            end
        end
        Wait((activeJet or activeHose) and 0 or 250)
    end
end)

local function validState(data)
    return type(data) == 'table' and type(data.id) == 'number' and type(data.tool) == 'string'
        and type(data.ax) == 'number' and type(data.ay) == 'number' and type(data.az) == 'number'
        and type(data.len) == 'number'
end

local function jetOf(data)
    return type(data.fx) == 'string' and data.fx or nil, tonumber(data.pitch) or 0.0, tonumber(data.yaw) or 0.0
end

local function stopVisual(serverId)
    local entry = visuals[serverId]
    if not entry then return end
    visuals[serverId] = nil
    destroyVisual(entry.visual)
end

local function refreshVisual(serverId, data, ped)
    local entry = visuals[serverId]
    if entry and (entry.id ~= data.id or entry.tool ~= data.tool) then
        stopVisual(serverId)
        entry = nil
    end
    if entry then
        if entry.visual then setJet(entry.visual, jetOf(data)) end
        return
    end

    entry = { id = data.id, tool = data.tool }
    visuals[serverId] = entry
    CreateThread(function()
        local visual = createVisual(ped, data,
            function() return visuals[serverId] == entry end,
            function(v) entry.visual = v end)
        if visuals[serverId] ~= entry then return destroyVisual(visual) end
        if not visual then visuals[serverId] = nil; return end
        entry.visual = visual
        local current = Player(serverId).state[STATE_KEY]
        if validState(current) then setJet(visual, jetOf(current)) end
    end)
end

local function inRange(data)
    return #(vec3(data.ax, data.ay, data.az) - GetEntityCoords(cache.ped)) <= REMOTE_RANGE
end

AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end
    local serverId = GetPlayerServerId(ply)
    if not validState(value) then return stopVisual(serverId) end
    -- our own jet is aimed every frame by the wash loop
    if ply == cache.playerId and visuals[serverId] and visuals[serverId].id == value.id and visuals[serverId].tool == value.tool then
        return
    end
    local ped = GetPlayerPed(ply)
    if DoesEntityExist(ped) and inRange(value) then refreshVisual(serverId, value, ped) end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local seen = {}
        for _, ply in ipairs(GetActivePlayers()) do
            local serverId = GetPlayerServerId(ply)
            local data = Player(serverId).state[STATE_KEY]
            local ped = GetPlayerPed(ply)
            if validState(data) and DoesEntityExist(ped) and inRange(data) then
                seen[serverId] = true
                if ply ~= cache.playerId or not visuals[serverId] then refreshVisual(serverId, data, ped) end
            end
        end
        for serverId in pairs(visuals) do
            if not seen[serverId] then stopVisual(serverId) end
        end
    end
end)

-- Dirt level while being washed (server/main.lua washDirt): only the owner's change sticks.
AddStateBagChangeHandler('crimsonDirt', nil, function(bagName, _, value)
    if type(value) ~= 'number' then return end
    local veh = GetEntityFromStateBagName(bagName)
    if veh ~= 0 and NetworkGetEntityOwner(veh) == cache.playerId then SetVehicleDirtLevel(veh, value) end
end)

--- Moves the dirt of the car being washed toward level (at most every 0.5 s, small steps skipped).
local function washDirt(session, level, force)
    local now = GetGameTimer()
    if not force and (now - (session.dirtAt or 0) < 500 or math.abs(level - (session.dirtSent or -1)) < 0.25) then return end
    session.dirtAt, session.dirtSent = now, level
    if NetworkGetEntityOwner(session.vehicle) == cache.playerId then SetVehicleDirtLevel(session.vehicle, level) end
    TriggerServerEvent('crimson-mechanic:server:washDirt', level)
end

-- The server marks a washed vehicle; only its owner can make the clean stick.
AddStateBagChangeHandler('crimsonWashed', nil, function(bagName, _, value)
    if not value then return end
    local found, veh = pcall(lib.waitFor, function()
        local entity = GetEntityFromStateBagName(bagName)
        if entity > 0 then return entity end
    end, nil, 10000)
    if not found or not veh then return end
    for _ = 1, 10 do
        if not DoesEntityExist(veh) then return end
        if NetworkGetEntityOwner(veh) == cache.playerId then
            cleanVehicle(veh)
            Entity(veh).state:set('crimsonWashed', nil, true)
            return
        end
        Wait(400)
    end
end)

-- ------------------------------------------------------------
-- Washing (local player)
-- ------------------------------------------------------------

local function publish(session, stage, jet)
    if not session then
        if LocalPlayer.state[STATE_KEY] then LocalPlayer.state:set(STATE_KEY, nil, true) end
        return
    end
    LocalPlayer.state:set(STATE_KEY, {
        id = session.id, tool = stage.tool,
        fx = jet and stage.fx or false, pitch = jet and jet.pitch or 0.0, yaw = jet and jet.yaw or 0.0,
        ax = session.anchor.x, ay = session.anchor.y, az = session.anchor.z, len = session.length,
    }, true)
end

local function vehicleMoved(session)
    local veh = session.vehicle
    return not DoesEntityExist(veh) or #(GetEntityCoords(veh) - session.vehicleCoords) > 1.0
        or GetPedInVehicleSeat(veh, -1) ~= 0
end

--- Which side of the car a point is on, and how far it is outside the body (m).
local function sideOf(veh, coords)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local center = (min + max) / 2
    local half = (max - min) / 2
    local p = GetOffsetFromEntityGivenWorldCoords(veh, coords.x, coords.y, coords.z) - center
    local nx, ny = p.x / half.x, p.y / half.y
    local zone
    if math.abs(ny) >= math.abs(nx) then
        zone = ny > 0 and 'front' or 'rear'
    else
        zone = nx > 0 and 'right' or 'left'
    end
    local dx, dy = math.max(0.0, math.abs(p.x) - half.x), math.max(0.0, math.abs(p.y) - half.y)
    return zone, math.sqrt(dx * dx + dy * dy)
end

local function camDirection()
    local rot = GetGameplayCamRot(2)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    return vec3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

--- Jet follows the crosshair: returns the jet direction, and where / what it lands on.
--- One ray from the camera, world + vehicles only (hitting our own gun or hose made the aim jump).
local function aimAt(ped)
    local n = nozzleOffset(ped)
    local origin = GetOffsetFromEntityInWorldCoords(ped, n.x, n.y, n.z)
    local camCoords = GetGameplayCamCoord()
    local camDir = camDirection()
    local far = camCoords + camDir * (W.reach + 8.0)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z, far.x, far.y, far.z, 1 | 2, ped, 7)
    local _, hit, at, _, entity = GetShapeTestResult(handle)
    hit = hit == 1 or hit == true

    -- anything between the camera and the player doesn't count
    if hit and #(at - camCoords) < #(origin - camCoords) + 0.3 then hit = false end
    local target = hit and at or far

    local dir = target - origin
    local len = #dir
    if len < 0.01 then return end
    dir = dir / len
    if not hit or len > W.reach then return dir end
    return dir, at, entity
end

--- Turns the ped toward a heading a bit per frame (snapping it every frame made it flicker).
local function turnTo(ped, heading)
    local current = GetEntityHeading(ped)
    local diff = (heading - current + 180.0) % 360.0 - 180.0
    if math.abs(diff) < 2.0 then return current end
    local step = math.max(-12.0, math.min(12.0, diff * 0.35))
    SetEntityHeading(ped, current + step)
    return current + step
end

local function disableControls()
    DisableControlAction(0, 21, true)  -- sprint
    DisableControlAction(0, 22, true)  -- jump
    DisableControlAction(0, 23, true)  -- enter vehicle
    DisableControlAction(0, 24, true)  -- attack
    DisableControlAction(0, 25, true)  -- aim
    DisableControlAction(0, 37, true)  -- weapon wheel
    DisableControlAction(0, 44, true)  -- cover
    DisableControlAction(0, 73, true)  -- X
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 263, true)
end

-- Wash HUD (web/wash.js, same look as the fuel / hookah HUDs). Only sent when it changes.
local hudSent
local function hud(data)
    if not data then
        if hudSent then SendNUIMessage({ action = 'washHide' }) end
        hudSent = nil
        return
    end
    local key = json.encode(data)
    if key == hudSent then return end
    hudSent = key
    SendNUIMessage({ action = 'wash', data = data })
end

local function stageHud(stage, index, progress, state)
    local rows, total = {}, 0
    for _, zone in ipairs(ZONES) do
        local pct = math.floor(progress[zone] / stage.zoneTime * 100)
        total = total + pct
        rows[#rows + 1] = {
            label = L.zones[zone], value = pct >= 100 and '✓' or pct .. '%',
            done = pct >= 100, active = state.zone == zone,
        }
    end
    if state.stretched then rows[#rows + 1] = { label = L.hose_limit, warn = true } end
    rows[#rows + 1] = { kbd = 'LMB', label = stage.fx and L.spray or L.scrub, active = state.pressing }
    rows[#rows + 1] = { kbd = 'X', label = L.stop }
    hud({
        title = L.hud_title, sub = L.hud_sub:format(stage.label, index, #W.stages),
        pct = total / #ZONES, flowing = state.zone ~= nil, rows = rows,
    })
end

--- One stage: runs until every side is done. Returns true, or false + reason.
local function runStage(session, stage, index)
    local veh = session.vehicle
    local tool = W.tools[stage.tool]
    local animations = { tool.anim }
    if tool.aimAnim then animations[#animations+1] = tool.aimAnim end
    if tool.sideAnim then animations[#animations+1] = tool.sideAnim end
    for _, anim in ipairs(animations) do lib.requestAnimDict(anim.dict, 2000) end
    local playing -- anim currently looping
    local progress = { front = 0, left = 0, right = 0, rear = 0 }
    local from = session.dirt * (index == 1 and 1.0 or W.stages[index - 1].dirt)
    local to = session.dirt * stage.dirt
    local needed = stage.zoneTime * #ZONES

    publish(session, stage)
    local last, lastHud, lastSync, synced = GetGameTimer(), 0, 0, nil
    local lastZone, lastZoneAt = nil, 0
    local outcome, reason = true, nil

    while true do
        local now = GetGameTimer()
        local dt = math.min(now - last, 200)
        last = now
        local ped = cache.ped

        if vehicleMoved(session) then outcome, reason = false, L.moved break end
        if IsEntityDead(ped) or cache.vehicle then outcome, reason = false, L.cancelled break end
        if now > session.deadline then outcome, reason = false, L.timeout break end
        disableControls()
        if IsDisabledControlJustPressed(0, 73) then outcome, reason = false, L.cancelled break end
        if GetSelectedPedWeapon(ped) ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true) end

        -- the hose only reaches so far
        local stretched = false
        if tool.hose then
            local d = #(GetEntityCoords(ped) - session.anchor)
            if d > session.length + 2.0 then outcome, reason = false, L.too_far break end
            stretched = d > session.length
        end

        local pressing = IsDisabledControlPressed(0, 24) and not stretched
        local zone, jet
        -- the hose is gripped the whole time; the sponge only moves while scrubbing
        local anim = washAnimation(tool, pressing)
        if pressing and stage.fx then
            ShowHudComponentThisFrame(14)
            local dir, at, entity = aimAt(ped)
            if dir then
                local heading = GetHeadingFromVector_2d(dir.x, dir.y)
                local facing = turnTo(ped, heading)
                -- the jet points at the crosshair even while the ped is still turning
                jet = { pitch = math.deg(math.asin(dir.z)), yaw = (heading - facing + 180.0) % 360.0 - 180.0 }
                if at and entity == veh then zone = sideOf(veh, at) end
            end
        elseif pressing then
            local z, gap = sideOf(veh, GetEntityCoords(ped))
            if gap <= W.scrubReach then
                zone = z
                local c = GetEntityCoords(veh)
                local p = GetEntityCoords(ped)
                turnTo(ped, GetHeadingFromVector_2d(c.x - p.x, c.y - p.y))
            end
            -- sides face the player: wipe like a window
            if (z == 'left' or z == 'right') and tool.sideAnim then anim = tool.sideAnim end
        end
        if zone then progress[zone] = math.min(stage.zoneTime, progress[zone] + dt) end

        -- animation + jet on/off
        if anim ~= playing or (anim and not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3)) then
            if playing then StopAnimTask(ped, playing.dict, playing.clip, 1.0) end
            if anim then TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, -4.0, -1, 49, 0.0, false, false, false) end
            playing = anim
        end
        local own = visuals[cache.serverId]
        if own and own.visual then setJet(own.visual, jet and stage.fx, jet and jet.pitch, jet and jet.yaw) end
        -- others see the jet through the state bag (throttled)
        local jetKey = jet and ('%d:%d'):format(math.floor(jet.pitch / 5), math.floor(jet.yaw / 10)) or false
        if jetKey ~= synced and now - lastSync > 250 then
            synced, lastSync = jetKey, now
            publish(session, stage, jet)
        end

        local done = 0
        for _, z in ipairs(ZONES) do done = done + progress[z] end
        -- each side cleaned brings the car closer to this step's dirt level
        washDirt(session, from + (to - from) * done / needed)

        -- the side being hit stays highlighted a moment so the HUD doesn't blink
        if zone then lastZone, lastZoneAt = zone, now end
        if now - lastHud > 150 then
            lastHud = now
            stageHud(stage, index, progress, {
                zone = now - lastZoneAt < 400 and lastZone or nil, pressing = pressing, stretched = stretched,
            })
        end

        if done >= needed then break end
        Wait(0)
    end

    if playing then StopAnimTask(cache.ped, playing.dict, playing.clip, 1.0) end
    for _, anim in ipairs(animations) do RemoveAnimDict(anim.dict) end
    return outcome, reason
end

local function startWash(shop, index)
    local station = shop.washes[index]
    local bay = vec3(station.x, station.y, station.z)
    -- the radius is only the prompt area; the car can be anywhere in the bay
    local veh = lib.getClosestVehicle(bay, W.bayDistance, false)
    if not veh then return notify(L.no_vehicle, 'error') end

    local r = lib.callback.await('crimson-mechanic:server:washStart', false, shop.id, index, NetworkGetNetworkIdFromEntity(veh))
    if not r or not r.ok then return notifyResult(r) end

    sessionCount = sessionCount + 1
    local anchor = vec3(station.hx, station.hy, station.hz)
    local session = {
        id = sessionCount,
        vehicle = veh,
        vehicleCoords = GetEntityCoords(veh),
        anchor = anchor,
        length = math.min(W.hose.maxLength, #(anchor - bay) + W.hose.slack),
        owner = takeControl(veh),
        dirt = math.max(GetVehicleDirtLevel(veh), 0.0),
        deadline = GetGameTimer() + W.timeout * 1000,
    }
    SetCurrentPedWeapon(cache.ped, UNARMED, true)

    local completed, reason = true, nil
    for i, stage in ipairs(W.stages) do
        completed, reason = runStage(session, stage, i)
        if not completed then break end
    end
    publish(nil)
    hud(nil)

    if not completed then
        -- unpaid: the dirt washed off so far comes back
        washDirt(session, session.dirt, true)
        TriggerServerEvent('crimson-mechanic:server:washCancel')
        return notify(reason or L.cancelled, 'error')
    end

    r = lib.callback.await('crimson-mechanic:server:washFinish', false)
    if r and r.ok and DoesEntityExist(veh) and NetworkGetEntityOwner(veh) == cache.playerId then
        cleanVehicle(veh)
    end
    notifyResult(r)
end

--- Automatic machine: pay, wait, clean. Works from the driver seat or on foot next to the car.
local function autoWash(shop, index)
    local station = shop.washes[index]
    local bay = vec3(station.x, station.y, station.z)
    local veh = cache.vehicle and cache.seat == -1 and cache.vehicle or lib.getClosestVehicle(bay, W.bayDistance, false)
    if not veh or #(GetEntityCoords(veh) - bay) > W.bayDistance then return notify(L.no_vehicle, 'error') end

    local r = lib.callback.await('crimson-mechanic:server:washStart', false, shop.id, index, NetworkGetNetworkIdFromEntity(veh))
    if not r or not r.ok then return notifyResult(r) end

    local price = r.args[1] or 0
    local coords = GetEntityCoords(veh)
    takeControl(veh)
    local session = { vehicle = veh }
    local dirt = GetVehicleDirtLevel(veh)
    local started = GetGameTimer()
    local outcome, reason = true, nil

    while true do
        local now = GetGameTimer()
        local t = math.min(1.0, (now - started) / W.auto.duration)
        if not DoesEntityExist(veh) or #(GetEntityCoords(veh) - coords) > 1.0 then outcome, reason = false, L.moved break end
        if IsEntityDead(cache.ped) then outcome, reason = false, L.cancelled break end

        -- the car stays put while the machine runs
        for _, control in ipairs({ 21, 22, 23, 59, 60, 63, 64, 71, 72, 73, 75, 76 }) do DisableControlAction(0, control, true) end
        if IsDisabledControlJustPressed(0, 73) then outcome, reason = false, L.cancelled break end

        -- dirt fades over the cycle
        washDirt(session, dirt * (1.0 - t))
        hud({
            title = L.auto_title, sub = L.auto_progress, pct = t * 100, flowing = true, auto = true,
            rows = {
                { label = L.time_left, value = ('%ds'):format(math.ceil((1.0 - t) * W.auto.duration / 1000)), active = true },
                { label = L.price, value = '$' .. price },
                { kbd = 'X', label = L.stop },
            },
        })
        if t >= 1.0 then break end
        Wait(0)
    end
    hud(nil)

    if not outcome then
        -- unpaid: the dirt washed off so far comes back
        washDirt(session, dirt, true)
        TriggerServerEvent('crimson-mechanic:server:washCancel')
        return notify(reason, 'error')
    end

    r = lib.callback.await('crimson-mechanic:server:washFinish', false)
    if r and r.ok and DoesEntityExist(veh) and NetworkGetEntityOwner(veh) == cache.playerId then
        cleanVehicle(veh)
    end
    notifyResult(r)
end

-- ------------------------------------------------------------
-- Stations
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

local function nearby(self)
    if Config.Marker.enabled then
        local c, size = Config.Marker.color, self.promptRadius * 2.0
        DrawMarker(Config.Marker.type, self.coords.x, self.coords.y, self.coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            size, size, 0.35, c[1], c[2], c[3], c[4], false, false, 2, false, nil, nil, false)
    end

    if washing or self.currentDistance > self.promptRadius then return hidePrompt(self) end

    local text
    if self.auto then
        if cache.vehicle and cache.seat ~= -1 then return hidePrompt(self) end -- passengers
        text = self.price > 0 and L.auto_prompt:format(self.price) or L.auto_prompt_free
    else
        if cache.vehicle then return showPrompt(self, L.step_out) end
        text = self.price > 0 and L.prompt:format(self.price) or L.prompt_free
    end
    showPrompt(self, text)

    if IsControlJustReleased(0, Config.InteractKey) then
        hidePrompt(self)
        washing = true
        CreateThread(function()
            local ok, err = pcall(self.auto and autoWash or startWash, self.shop, self.index)
            if not ok then
                lib.print.error(err)
                publish(nil)
                hud(nil)
                ClearPedTasks(cache.ped)
                TriggerServerEvent('crimson-mechanic:server:washCancel')
            end
            washing = false
        end)
    end
end

local function onExit(self) hidePrompt(self) end

local function rebuild(list)
    hidePrompt()
    for _, point in ipairs(points) do point:remove() end
    points = {}
    if not W.enabled then return end

    for _, shop in ipairs(list or {}) do
        for i, w in ipairs(shop.washes or {}) do
            local point = lib.points.new({
                coords = vec3(w.x, w.y, w.z),
                distance = Config.MarkerDistance,
                shop = shop,
                index = i,
                auto = w.type == 'auto',
                promptRadius = w.r or (w.type == 'auto' and W.auto.radius or W.radius), -- not "radius": lib.points overwrites that with distance
                price = w.price or (w.type == 'auto' and W.auto.price or W.price),
            })
            point.nearby, point.onExit = nearby, onExit
            points[#points + 1] = point
        end
    end
end

AddStateBagChangeHandler('crimsonMechanic', 'global', function(_, _, value)
    rebuild(value)
end)

CreateThread(function()
    rebuild(GlobalState.crimsonMechanic)
end)

-- ------------------------------------------------------------
-- Debug: tune the gun live while washing (Config.Wash.debug)
-- ------------------------------------------------------------

if W.debug then
    local function numbers(args, count)
        local n = {}
        for i = 1, count do
            n[i] = tonumber(args[i])
            if not n[i] then return end
        end
        return n
    end

    local function rebuildOwn()
        stopVisual(cache.serverId) -- the 1 s refresh loop rebuilds it from the state bag
    end

    -- /washfx x y z rx ry rz scale: nozzle position (player offset) + jet rotation/scale of the current effect
    RegisterCommand('washfx', function(_, args)
        local n = numbers(args, 7)
        local own = visuals[cache.serverId]
        local key = own and own.visual and own.visual.fxKey or 'water'
        local effect = W.effects[key]
        if n then
            W.nozzle, effect.rot, effect.scale = vec3(n[1], n[2], n[3]), vec3(n[4], n[5], n[6]), n[7]
            if own and own.visual then stopJet(own.visual) end
        end
        print(('nozzle = vec3(%.3f, %.3f, %.3f),'):format(W.nozzle.x, W.nozzle.y, W.nozzle.z))
        print(('%s = { asset = %q, name = %q, rot = vec3(%.1f, %.1f, %.1f), scale = %.2f },')
            :format(key, effect.asset, effect.name, effect.rot.x, effect.rot.y, effect.rot.z, effect.scale))
    end, false)

    -- /washhand x y z rx ry rz [bone]: gun position in the hand
    RegisterCommand('washhand', function(_, args)
        local n = numbers(args, 6)
        local hand = W.tools.gun.hand
        if n then
            hand.pos, hand.rot = vec3(n[1], n[2], n[3]), vec3(n[4], n[5], n[6])
            hand.bone = tonumber(args[7]) or hand.bone
            rebuildOwn()
        end
        print(('hand = { bone = %d, pos = vec3(%.3f, %.3f, %.3f), rot = vec3(%.1f, %.1f, %.1f) },')
            :format(hand.bone, hand.pos.x, hand.pos.y, hand.pos.z, hand.rot.x, hand.rot.y, hand.rot.z))
    end, false)

    -- /washtip x y z: where the hose plugs into the gun (gun offset)
    RegisterCommand('washtip', function(_, args)
        local n = numbers(args, 3)
        if n then
            W.hose.tip = vec3(n[1], n[2], n[3])
            rebuildOwn()
        end
        local t = W.hose.tip
        print(('tip = vec3(%.3f, %.3f, %.3f),'):format(t.x, t.y, t.z))
    end, false)

    -- /washrope 1-7: try another rope look for the hose
    RegisterCommand('washrope', function(_, args)
        local t = tonumber(args[1])
        if t and t >= 1 and t <= 7 then
            W.hose.ropeType = math.floor(t)
            rebuildOwn()
        end
        print(('ropeType = %d,'):format(W.hose.ropeType))
    end, false)

    -- /washeffect asset name [water|foam]: try another particle effect for the jet
    RegisterCommand('washeffect', function(_, args)
        local key = args[3] or 'water'
        local effect = W.effects[key]
        if effect and args[1] and args[2] then
            effect.asset, effect.name = args[1], args[2]
            local own = visuals[cache.serverId]
            if own and own.visual then stopJet(own.visual) end
        end
        if effect then
            print(('%s = { asset = %q, name = %q, rot = vec3(%.1f, %.1f, %.1f), scale = %.2f },')
                :format(key, effect.asset, effect.name, effect.rot.x, effect.rot.y, effect.rot.z, effect.scale))
        end
    end, false)

    -- /washmodel prop_name: try another gun model (/washmodel none = bare hose end)
    RegisterCommand('washmodel', function(_, args)
        local gun = W.tools.gun
        if args[1] == 'none' then
            gun.hidden = true
            rebuildOwn()
        elseif args[1] then
            gun.model, gun.hidden = args[1], false
            rebuildOwn()
        end
        print(('model = %q, hidden = %s,'):format(gun.model, tostring(gun.hidden == true)))
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    hidePrompt()
    if washing then
        hud(nil)
        ClearPedTasks(cache.ped)
        LocalPlayer.state:set(STATE_KEY, nil, true)
    end
    for serverId in pairs(visuals) do stopVisual(serverId) end
end)

-- A wash cut short by a resource restart survives in the state bag: clear it.
publish(nil)
