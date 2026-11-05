-- Crimson livery enforcement. Whoever owns a locked car puts any livery the plate
-- doesn't own back to stock, whatever set it (garage props, another script, a
-- cheat menu). The server reads texture liveries itself and pings the owner via
-- 'crimsonLiveryFix'; mod slots can only be read client side, so this loop also
-- covers them. 'crimsonLiveryHold' (server set) pauses it while an unlock shop
-- has the car open in the tuner.
if not Liveries.enabled then return end

local function owned(veh)
    return not NetworkGetEntityIsNetworked(veh) or NetworkGetEntityOwner(veh) == cache.playerId
end

local function fix(veh)
    if Entity(veh).state.crimsonLiveryHold then return end
    local ctx = Liveries.context(veh)
    if not ctx then return end

    local fixed = {}
    local livery = GetVehicleLivery(veh)
    if livery >= 0 and Liveries.needed(ctx.entry, ctx.unlocks, 'livery', livery) then
        SetVehicleLivery(veh, 0)
        fixed[#fixed + 1] = Liveries.key('livery', livery)
    end

    local slots = { 48 }
    for slot in pairs(ctx.entry.mods) do slots[#slots + 1] = slot end
    for _, slot in ipairs(slots) do
        local value = GetVehicleMod(veh, slot)
        local key = value >= 0 and Liveries.needed(ctx.entry, ctx.unlocks, 'mod:' .. slot, value)
        if key then
            SetVehicleModKit(veh, 0)
            SetVehicleMod(veh, slot, -1, false)
            fixed[#fixed + 1] = key
        end
    end

    if #fixed > 0 and NetworkGetEntityIsNetworked(veh) then
        TriggerServerEvent('crimson-mechanic:server:liveryReverted', NetworkGetNetworkIdFromEntity(veh), fixed)
    end
end

AddStateBagChangeHandler('crimsonLiveryFix', nil, function(bagName, _, value)
    if not value then return end
    local veh = GetEntityFromStateBagName(bagName)
    if veh == 0 or not owned(veh) then return end
    fix(veh)
end)

CreateThread(function()
    while true do
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if Liveries.entry(GetEntityModel(veh)) and owned(veh) then fix(veh) end
        end
        Wait(1000)
    end
end)
