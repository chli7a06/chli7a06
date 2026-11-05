local state = { generation = 0, starting = false }

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function valid(token)
    return state.generation == token
end

local function stop()
    state.generation = state.generation + 1
    state.starting = false
    local rope, gun, ped, animated = state.rope, state.gun, state.ped, state.animated
    state.rope, state.gun, state.vehicle, state.ped, state.anchor, state.animated = nil, nil, nil, nil, nil, nil
    if rope and DoesRopeExist(rope) then DeleteRope(rope) end
    if gun and DoesEntityExist(gun) then DeleteEntity(gun) end
    if animated and ped and DoesEntityExist(ped) then
        StopAnimTask(ped, Config.Animation.Dict, Config.Animation.Name, 2.0)
    end
    -- Rope textures are shared by resources: do not unload another script's textures.
end

local function awaitLoaded(token, request, loaded)
    request()
    local deadline = GetGameTimer() + Config.LoadTimeoutMs
    while valid(token) and not loaded() do
        if GetGameTimer() >= deadline then return false end
        Wait(0)
    end
    return valid(token)
end

local function nearestVehicle(ped)
    local position = GetEntityCoords(ped)
    local best, distance = nil, Config.VehicleSearchRange
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local current = #(position - GetEntityCoords(vehicle))
            if current < distance then best, distance = vehicle, current end
        end
    end
    return best
end

local function offset(entity, point)
    return GetOffsetFromEntityInWorldCoords(entity, point.x, point.y, point.z)
end

local function fail(token, message)
    if valid(token) then stop(); notify(message) end
end

local function start(token)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        fail(token, 'Crimson Lavage: stand outside a vehicle first.')
        return
    end
    local vehicle = nearestVehicle(ped)
    if not vehicle then
        fail(token, 'Crimson Lavage: stand within 6 metres of the supply vehicle.')
        return
    end
    local hash = GetHashKey(Config.Model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        fail(token, 'Crimson Lavage: washer model unavailable. Check the stream files and YTYP.')
        return
    end
    local loaded = awaitLoaded(token, function() RequestModel(hash) end, function() return HasModelLoaded(hash) end)
    if not loaded then
        SetModelAsNoLongerNeeded(hash)
        fail(token, 'Crimson Lavage: model loading timed out.')
        return
    end
    if not awaitLoaded(token, RopeLoadTextures, RopeAreTexturesLoaded) then
        SetModelAsNoLongerNeeded(hash)
        fail(token, 'Crimson Lavage: rope textures did not load.')
        return
    end
    if Config.Animation.Enabled then
        if not awaitLoaded(token, function() RequestAnimDict(Config.Animation.Dict) end,
            function() return HasAnimDictLoaded(Config.Animation.Dict) end) then
            SetModelAsNoLongerNeeded(hash)
            fail(token, 'Crimson Lavage: animation loading timed out.')
            return
        end
    end
    if not DoesEntityExist(vehicle) or PlayerPedId() ~= ped or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        SetModelAsNoLongerNeeded(hash)
        fail(token, 'Crimson Lavage: vehicle or player changed during loading.')
        return
    end
    local pos = GetEntityCoords(ped)
    -- Local prototype: no unvalidated multiplayer hose synchronization is implied.
    local gun = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not gun or gun == 0 or not DoesEntityExist(gun) then
        fail(token, 'Crimson Lavage: unable to create washer prop.')
        return
    end
    state.gun, state.vehicle, state.ped = gun, vehicle, ped
    SetEntityAsMissionEntity(gun, true, true)
    SetEntityCollision(gun, false, false)
    local hand = Config.Hand
    AttachEntityToEntity(gun, ped, GetPedBoneIndex(ped, hand.Bone),
        hand.Position.x, hand.Position.y, hand.Position.z,
        hand.Rotation.x, hand.Rotation.y, hand.Rotation.z,
        false, false, false, true, 2, true)
    local minimum = GetModelDimensions(GetEntityModel(vehicle))
    state.anchor = { x = Config.VehicleAnchor.x, y = minimum.y + Config.VehicleAnchor.rearInset, z = Config.VehicleAnchor.z }
    local gunEnd, vehicleEnd = offset(gun, Config.HoseGunOffset), offset(vehicle, state.anchor)
    local distance = #(gunEnd - vehicleEnd)
    if distance > Config.HoseLength then
        fail(token, 'Crimson Lavage: move closer to the rear of the supply vehicle.')
        return
    end
    local length = math.min(Config.HoseLength, math.max(0.5, distance + Config.HoseSlack))
    local rope = AddRope(gunEnd.x, gunEnd.y, gunEnd.z, 0.0, 0.0, 0.0,
        Config.HoseLength, Config.RopeType, length, 0.5, 0.0, false, false, false, 1.0, false, 0)
    if not rope or not DoesRopeExist(rope) then
        fail(token, 'Crimson Lavage: unable to create the hose.')
        return
    end
    state.rope = rope
    AttachEntitiesToRope(rope, gun, vehicle,
        gunEnd.x, gunEnd.y, gunEnd.z, vehicleEnd.x, vehicleEnd.y, vehicleEnd.z,
        length, false, false, nil, nil)
    RopeForceLength(rope, length)
    if Config.Animation.Enabled then
        TaskPlayAnim(ped, Config.Animation.Dict, Config.Animation.Name, 4.0, -4.0, -1, Config.Animation.Flags, 0.0, false, false, false)
        state.animated = true
    end
    state.starting = false
    notify('Crimson Lavage: prop equipped. Use /' .. Config.Command .. ' again to put it away.')
end

local function toggle()
    if state.starting or state.gun then stop(); return end
    state.starting = true
    local token = state.generation
    CreateThread(function() start(token) end)
end

RegisterCommand(Config.Command, toggle, false)
exports('ToggleWasher', toggle)
exports('StopWasher', stop)

CreateThread(function()
    while true do
        if state.gun then
            if not DoesEntityExist(state.gun) or not DoesEntityExist(state.vehicle)
                or not DoesEntityExist(state.ped) or PlayerPedId() ~= state.ped
                or IsEntityDead(state.ped) or IsPedInAnyVehicle(state.ped, false)
                or not state.rope or not DoesRopeExist(state.rope) then
                stop()
            else
                local gunEnd, vehicleEnd = offset(state.gun, Config.HoseGunOffset), offset(state.vehicle, state.anchor)
                local distance = #(gunEnd - vehicleEnd)
                if distance > Config.HoseLength then
                    stop()
                    notify('Crimson Lavage: you moved beyond the hose length.')
                else
                    RopeForceLength(state.rope, math.min(Config.HoseLength, math.max(0.5, distance + Config.HoseSlack)))
                end
            end
        end
        Wait(100)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stop() end
end)
