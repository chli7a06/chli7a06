Config = {}

Config.Debug = false

-- /mechadmin opens the in-game shop editor. ox_lib grants the command to this principal.
Config.AdminCommand = 'mechadmin'
Config.AdminGroup = 'group.admin'

Config.InteractKey = 38         -- E
Config.MarkerDistance = 15.0    -- bench markers / points only tick inside this range
Config.Marker = { enabled = false, type = 1, color = { 216, 73, 96, 90 } } -- ground circle on benches (admin placement preview always shows)
Config.Blip = { sprite = 446, color = 1, scale = 0.7 }

-- Master switch. When false no shop accepts customer requests, whatever its own toggle says.
Config.TicketSystem = true
Config.RequireOwnership = true  -- customers can only open requests for vehicles they own
Config.MaxOpenTickets = 3       -- pending requests per character
Config.TicketExpireDays = 7     -- pending requests older than this are dropped on start

Config.Account = 'bank'         -- customer pays from this account
-- Where the society cut goes:
-- 'snipe-banking'   -> job account in snipe-banking (what bosses see at the bank)
-- 'aj_job_accounts' -> jobs_creator's own society table
-- false             -> no society payout
Config.Society = 'snipe-banking'
Config.DefaultCommission = 30   -- % of every bill paid to the mechanic (rest goes to the society)
Config.MinPricePercent = 100    -- a bill can't go below this % of the estimate unless the shop allows it
Config.MaxPrice = 1000000
Config.BillDistance = 10.0      -- max distance between mechanic and the customer being billed
Config.OfferTimeout = 45        -- seconds a customer has to accept a bill
Config.InstallTimeout = 90      -- seconds to finish the install after payment, otherwise refunded
Config.InstallDuration = 6000   -- progress bar length (ms)

-- Crimson liveries (crm-auto). Locked by default; only shops with "Unlocks Crimson
-- liveries" ticked in /mechadmin can sell them. An unlock belongs to the plate, so the
-- owner can switch between owned liveries / Clean at any bench afterwards.
-- livery = texture livery index (SetVehicleLivery, or mod 48 if a car uses that)
-- mods   = mod slot -> index -> label (5 = VMT_CHASSIS sticker kits)
Config.CrimsonLiveries = {
    enabled = true,
    price = 15000,                -- per unlock, on top of the normal change price
    command = 'crimsonlivery',    -- /crimsonlivery unlock|lock|info <plate> [key|all]
    group = 'group.admin',
    checkInterval = 2000,         -- ms between enforcement scans
    models = {
        crm_e36        = { livery = { [1] = 'Red Drips' }, mods = { [5] = { [0] = 'Sponsors White', [1] = 'Sponsors Black' } } },
        crm_sentouring = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' } },
        crm_senti8     = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' } },
        crm_sr8        = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [0] = 'Banner + Black Glass' } } },
        crm_sr6        = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [0] = 'Banner + Black Glass' } } },
        crm_sf100      = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [0] = 'Banner + Black Glass' } } },
        crm_puro       = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [0] = 'Banner + Black Glass' } } },
        crm_sr3        = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [1] = 'Banner + Black Glass' } } },
        crm_xls        = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [0] = 'Banner + Black Glass' } } },
        crm_rtx        = { livery = { [1] = 'Sponsors Black', [2] = 'Sponsors White' }, mods = { [5] = { [0] = 'Banner + Black Glass' } } },
    },
}

-- Wash stations. Placed per shop in /mechadmin (aim at the bay, then at the spot on the
-- roof / wall the hose hangs from). Anyone can wash a vehicle parked in the bay: the
-- player takes the hose and aims the jet at the car themselves (hold LMB, aim with the
-- camera). Every side (front / left / right / rear) has to be covered in every stage.
Config.Wash = {
    enabled = true,
    price = 250,                  -- default fee for new stations (editable per station)
    accounts = { 'cash', 'bank' },-- tried in this order
    society = true,               -- fee goes to the shop's job account (first job if several)
    radius = 1.5,                 -- default [E] prompt radius for new stations (set per station in /mechadmin)
    -- Automatic wash machine: press [E] (from the driver seat or next to the car), wait, clean.
    auto = {
        price = 2000,             -- default fee for new auto stations
        radius = 3.0,             -- default prompt radius (bigger: the player is in the car)
        duration = 30000,         -- ms
    },
    bayDistance = 4.0,            -- the car to wash must be within this of the bay point (m)
    reach = 6.0,                  -- how far the jet reaches (m)
    scrubReach = 1.0,             -- max distance from the bodywork to scrub a side (m)
    timeout = 300,                -- seconds before an unfinished wash is dropped

    hose = {
        renderer = 'rubber',      -- smooth black tube; 'native' keeps the GTA rope fallback
        radius = 0.008,           -- same 8mm radius as the Blender hose source
        segments = 16,
        sides = 8,
        renderDistance = 35.0,
        ropeType = 3,             -- 1-4 thick ropes, 5-7 thin cables (3 = fuel pump hose). Debug: /washrope 1-7
        slack = 6.0,              -- hose length = anchor-to-bay distance + this
        maxLength = 20.0,
        pinEnds = true,          -- pin to world endpoints; the custom gun has no collision body
        visibleSlack = 0.75,      -- visible cable slack; total walking reach still uses station length
        anchorModel = 'prop_cs_fuel_nozle', -- invisible prop the hose hangs from
        tip = vec3(-0.07, 0.0, -0.18),       -- connector under the custom washer grip
    },

    -- The jet leaves from this hand bone (28422 = right hand prop bone), plus nozzle
    -- (x right, y forward, z up, player space). It follows the crosshair.
    -- Debug: /washfx x y z rx ry rz scale
    nozzleBone = 28422,
    nozzle = vec3(0.0, 0.05, 0.0),
    effects = {
        water = { asset = 'core', name = 'water_cannon_jet', rot = vec3(0.0, 0.0, 0.0), scale = 0.25 },
        -- the user preferred this over scr_carwash / ent_amb_car_wash_jet_soap
        foam  = { asset = 'core', name = 'weap_extinguisher', rot = vec3(0.0, 0.0, 0.0), scale = 0.6 },
    },
    -- true: /washfx, /washhand, /washtip and /washmodel tune the gun live (they print the config line)
    debug = false,

    -- What the player holds. hose = the hose is connected to it. anim plays while spraying / scrubbing.
    -- hidden = the model is invisible (only there to hold the hose end in the hand).
    -- Streamed Crimson washer: origin at grip, +X towards the nozzle.
    -- Hand offsets are initial values and may need in-game calibration.
    tools = {
        gun = {
            model = 'crimson_pressure_washer', hose = true, hidden = false,
            muzzle = vec3(0.840, 0.0, 0.041), -- model-space tip, shared by local/remote jets and aiming
            -- Rigid attachment derived from the authored male freemode clips.
            hand = { bone = 57005, pos = vec3(0.085, 0.025, -0.040), rot = vec3(-90.0, 0.0, 0.0), rotOrder = 2 },
            anim = { dict = 'crimson_wash_custom_v4', clip = 'carry' },
            aimAnim = { dict = 'crimson_wash_custom_v4', clip = 'spray' },
        },
        sponge = {
            model = 'prop_sponge_01',
            hand = { bone = 28422, pos = vec3(0.0, 0.0, -0.01), rot = vec3(90.0, 0.0, 0.0) },
            anim = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base' },       -- front / rear
            sideAnim = { dict = 'amb@world_human_maid_clean@base', clip = 'base' },     -- left / right (wiping like a window)
        },
    },

    -- Played in order. fx = jet effect (no fx = scrub by standing next to each side).
    -- zoneTime = ms of spraying / scrubbing each of the 4 sides needs.
    -- dirt = dirt left at the end of the stage (0-1 of the starting dirt).
    stages = {
        { label = 'Rinse',       tool = 'gun',    fx = 'water', zoneTime = 3000, dirt = 0.7 },
        { label = 'Foam',        tool = 'gun',    fx = 'foam',  zoneTime = 3000, dirt = 0.5 },
        { label = 'Scrub',       tool = 'sponge',               zoneTime = 4500, dirt = 0.2 },
        { label = 'Final rinse', tool = 'gun',    fx = 'water', zoneTime = 3000, dirt = 0.0 },
    },
}

-- minimum active washing time (~54 s by default; walking around the car comes on top)
Config.Wash.duration = 0
for _, stage in ipairs(Config.Wash.stages) do Config.Wash.duration = Config.Wash.duration + stage.zoneTime * 4 end

-- Categories shown in the tuner, in this order. A shop can disable any of them.
Config.Categories = {
    { id = 'parts',       label = 'Body Parts' },
    { id = 'wheels',      label = 'Wheels' },
    { id = 'paint',       label = 'Paint' },
    { id = 'lights',      label = 'Lights & Neons' },
    { id = 'extras',      label = 'Extras' },
    { id = 'performance', label = 'Performance' },
    { id = 'stance',      label = 'Stance' },
    { id = 'repair',      label = 'Repair' },
}

-- Flat prices per change (same defaults as av_tuning).
Config.Prices = {
    parts = 150,
    livery = 150,
    wheelType = 0,
    rims = 150,
    customTyres = 100,
    smoke = 40,
    paint1 = 75,
    paint2 = 50,
    pearl = 100,
    wheelColor = 35,
    interior = 30,
    dashboard = 30,
    windowTint = 60,
    plateIndex = 50,
    xenon = 150,
    neon = 150,
    neonColor = 50,
    extras = 50,
    turbo = 300,
    stance = 75,
    repair = 200,
    engineSound = 500,
}

-- Exhaust systems (engine sound swaps), listed under Performance. Like Crimson liveries
-- they are only sold at shops with "Sells exhaust systems" ticked in /mechadmin, and each
-- non-stock sound needs a one-time unlock per plate (never discounted). Once unlocked the
-- plate can switch between its owned sounds / stock for the normal engineSound price.
-- model -> sounds; the first entry must be the sound in the car's vehicles.meta (stock).
-- Every sound has to be loaded by a car pack, otherwise the car goes silent.
Config.SoundUnlockPrice = 50000
Config.EngineSounds = {
    crm_rtx = {
        { v = 'chargertrackhawkhemiv8', l = 'Supercharged Hemi V8' },
        { v = 'aq07powerstroke67',      l = 'Powerstroke 6.7 Diesel' },
        { v = 'demonv8',                l = 'Demon Supercharged V8' },
    },
    crm_sr6 = {
        { v = 'taaud40v8', l = 'Audi 4.0 V8' },
        { v = 'MONSTER',   l = 'Monster' },                -- vanilla GTA sound
    },
    crm_sr3 = {
        { v = 'ars6c8avant',  l = 'Audi RS6 4.0 V8' },
        { v = 'aq68lam52v10', l = 'Audi R8 5.2 V10' },
    },
    crm_xls = {
        { v = 'ta176m177', l = 'AMG 4.0 Biturbo V8' },
        { v = 'kc98gmls6', l = 'GM LS6 V8' },              -- loaded by KillerGangPack
        { v = 'aqm275amg', l = 'AMG 6.0 Biturbo V12' },
    },
    crm_sr8 = {
        { v = 'ta176m177',    l = 'AMG 4.0 Biturbo V8' },
        { v = 'm5cracklemod', l = 'M5 V8 Crackle' },       -- loaded by KillerGangPack
    },
    ballerp5x = {
        { v = 'BALLER8',                l = 'Stock V8' },              -- vanilla GTA sound
        { v = 'm5cracklemod',           l = 'M5 V8 Crackle' },         -- loaded by KillerGangPack
        { v = 'chargertrackhawkhemiv8', l = 'Supercharged Hemi V8' },  -- loaded by crm-auto
    },
}

-- Performance upgrades: price = base + perLevel * level (level 0 = first upgrade, stock = base).
Config.Performance = {
    [11] = { label = 'Engine',       base = 200, perLevel = 150 },
    [12] = { label = 'Brakes',       base = 150, perLevel = 100 },
    [13] = { label = 'Transmission', base = 175, perLevel = 125 },
    [15] = { label = 'Suspension',   base = 125, perLevel = 100 },
    [16] = { label = 'Armor',        base = 250, perLevel = 200 },
}

-- Visual parts (av_tuning customization.lua). cam = camera preset used when the part is selected.
Config.Parts = {
    { mod = 0,  label = 'Spoiler',        cam = 'rear' },
    { mod = 1,  label = 'Front Bumper',   cam = 'front' },
    { mod = 2,  label = 'Rear Bumper',    cam = 'rear' },
    { mod = 3,  label = 'Side Skirts',    cam = 'side' },
    { mod = 4,  label = 'Exhaust',        cam = 'rear' },
    { mod = 5,  label = 'Roll Cage',      cam = 'interior' },
    { mod = 6,  label = 'Grille',         cam = 'front' },
    { mod = 7,  label = 'Hood',           cam = 'front' },
    { mod = 8,  label = 'Left Fender',    cam = 'left' },
    { mod = 9,  label = 'Right Fender',   cam = 'side' },
    { mod = 10, label = 'Roof',           cam = 'top' },
    { mod = 14, label = 'Horn',           cam = 'front' },
    { mod = 25, label = 'Plate Holder',   cam = 'rear' },
    { mod = 26, label = 'Vanity Plate',   cam = 'front' },
    { mod = 27, label = 'Trim A',         cam = 'interior' },
    { mod = 28, label = 'Ornaments',      cam = 'interior' },
    { mod = 29, label = 'Dashboard',      cam = 'interior' },
    { mod = 30, label = 'Dial',           cam = 'interior' },
    { mod = 31, label = 'Door Speakers',  cam = 'interior' },
    { mod = 32, label = 'Seats',          cam = 'interior' },
    { mod = 33, label = 'Steering Wheel', cam = 'interior' },
    { mod = 34, label = 'Gear Shift',     cam = 'interior' },
    { mod = 35, label = 'Plaques',        cam = 'interior' },
    { mod = 36, label = 'Speakers',       cam = 'trunk' },
    { mod = 37, label = 'Trunk',          cam = 'trunk' },
    { mod = 38, label = 'Hydraulics',     cam = 'side' },
    { mod = 39, label = 'Engine Block',   cam = 'engine' },
    { mod = 40, label = 'Air Filter',     cam = 'engine' },
    { mod = 41, label = 'Struts',         cam = 'engine' },
    { mod = 42, label = 'Arch Cover',     cam = 'side' },
    { mod = 43, label = 'Antenna',        cam = 'top' },
    { mod = 44, label = 'Trim B',         cam = 'side' },
    { mod = 45, label = 'Fuel Tank',      cam = 'rear' },
    { mod = 46, label = 'Windows',        cam = 'side' },
    { mod = 48, label = 'Livery',         cam = 'side' },
    { mod = 49, label = 'Light Bar',      cam = 'top' },
}

-- Camera presets. a = angle around the vehicle (0 front, 90 right, 180 rear, 270 left),
-- z = zoom factor, ay/az = aim offset (fraction of length / metres up), doors = doors opened.
Config.Cameras = {
    default  = { a = 140, z = 1.0,  ay = 0.0,   az = 0.35 },
    front    = { a = 25,  z = 0.85, ay = 0.35,  az = 0.2 },
    rear     = { a = 205, z = 0.85, ay = -0.35, az = 0.25 },
    side     = { a = 90,  z = 0.9,  ay = 0.0,   az = 0.2 },
    left     = { a = 270, z = 0.9,  ay = 0.0,   az = 0.2 },
    top      = { a = 160, z = 1.0,  ay = 0.0,   az = 0.6, lift = 1.2 },
    wheel    = { a = 55,  z = 0.6,  ay = 0.3,   az = -0.1 },
    interior = { a = 100, z = 0.55, ay = 0.05,  az = 0.45, doors = { 0, 1 } },
    engine   = { a = 10,  z = 0.7,  ay = 0.4,   az = 0.5, doors = { 4 } },
    trunk    = { a = 190, z = 0.7,  ay = -0.4,  az = 0.5, doors = { 5 } },
}

Config.WheelTypes = {
    { v = 0,  l = 'Sport' },   { v = 1,  l = 'Muscle' },  { v = 2,  l = 'Lowrider' },
    { v = 3,  l = 'SUV' },     { v = 4,  l = 'Offroad' }, { v = 5,  l = 'Tuner' },
    { v = 7,  l = 'Highend' }, { v = 8,  l = "Benny's" }, { v = 9,  l = 'Bespoke' },
    { v = 10, l = 'Dragster' },{ v = 11, l = 'Street' },  { v = 12, l = 'Rally' },
}

Config.PaintTypes = {
    { v = 0, l = 'Normal' }, { v = 1, l = 'Metallic' }, { v = 2, l = 'Pearl' },
    { v = 3, l = 'Matte' },  { v = 4, l = 'Metal' },    { v = 5, l = 'Chrome' },
}

Config.WindowTints = {
    { v = 0, l = 'None' }, { v = 1, l = 'Pure Black' }, { v = 2, l = 'Dark Smoke' },
    { v = 3, l = 'Light Smoke' }, { v = 4, l = 'Stock' }, { v = 5, l = 'Limo' }, { v = 6, l = 'Green' },
}

Config.PlateStyles = {
    { v = 0, l = 'Blue on White 1' }, { v = 1, l = 'Yellow on Black' }, { v = 2, l = 'Yellow on Blue' },
    { v = 3, l = 'Blue on White 2' }, { v = 4, l = 'Blue on White 3' }, { v = 5, l = 'Yankton' },
}

Config.XenonColors = {
    { v = -1,  l = 'Off',          hex = '#2a2e36' },
    { v = 255, l = 'Stock',        hex = '#e8eef9' },
    { v = 0,   l = 'White',        hex = '#ffffff' }, { v = 1,  l = 'Blue',         hex = '#1e6bff' },
    { v = 2,   l = 'Electric Blue',hex = '#3fb6ff' }, { v = 3,  l = 'Mint Green',   hex = '#6dffb0' },
    { v = 4,   l = 'Lime Green',   hex = '#a6ff2e' }, { v = 5,  l = 'Yellow',       hex = '#ffe52e' },
    { v = 6,   l = 'Golden Shower',hex = '#ffbf2e' }, { v = 7,  l = 'Orange',       hex = '#ff8a1e' },
    { v = 8,   l = 'Red',          hex = '#ff2626' }, { v = 9,  l = 'Pony Pink',    hex = '#ff7bd0' },
    { v = 10,  l = 'Hot Pink',     hex = '#ff2ea8' }, { v = 11, l = 'Purple',       hex = '#9b3dff' },
    { v = 12,  l = 'Blacklight',   hex = '#5b2eff' },
}

Config.NeonColors = {
    { l = 'White', rgb = { 222, 222, 255 } }, { l = 'Blue', rgb = { 2, 21, 255 } },
    { l = 'Electric Blue', rgb = { 3, 83, 255 } }, { l = 'Mint Green', rgb = { 0, 255, 140 } },
    { l = 'Lime Green', rgb = { 94, 255, 1 } }, { l = 'Yellow', rgb = { 255, 255, 0 } },
    { l = 'Golden Shower', rgb = { 255, 150, 0 } }, { l = 'Orange', rgb = { 255, 62, 0 } },
    { l = 'Red', rgb = { 255, 1, 1 } }, { l = 'Pony Pink', rgb = { 255, 50, 100 } },
    { l = 'Hot Pink', rgb = { 255, 5, 190 } }, { l = 'Purple', rgb = { 35, 1, 255 } },
    { l = 'Blacklight', rgb = { 15, 3, 255 } },
}

Config.SmokeColors = {
    { l = 'White', rgb = { 254, 254, 254 } }, { l = 'Black', rgb = { 1, 1, 1 } },
    { l = 'Blue', rgb = { 0, 150, 255 } }, { l = 'Yellow', rgb = { 255, 255, 50 } },
    { l = 'Orange', rgb = { 255, 153, 51 } }, { l = 'Red', rgb = { 255, 10, 10 } },
    { l = 'Green', rgb = { 10, 255, 10 } }, { l = 'Purple', rgb = { 153, 10, 153 } },
    { l = 'Pink', rgb = { 255, 102, 178 } }, { l = 'Gray', rgb = { 128, 128, 128 } },
}

-- Stance sliders. Values are offsets from the vehicle's stock setup.
Config.Stance = {
    { id = 'cf', label = 'Front Camber', min = -0.30, max = 0.30, step = 0.01, default = 0.0 },
    { id = 'cr', label = 'Rear Camber',  min = -0.30, max = 0.30, step = 0.01, default = 0.0 },
    { id = 'tf', label = 'Front Track',  min = -0.20, max = 0.20, step = 0.005, default = 0.0 },
    { id = 'tr', label = 'Rear Track',   min = -0.20, max = 0.20, step = 0.005, default = 0.0 },
    { id = 'h',  label = 'Ride Height',  min = -0.10, max = 0.15, step = 0.005, default = 0.0 },
}
Config.StanceRange = 120.0 -- stance is only applied to vehicles within this distance

-- GTA paint colours (av_tuning painting.lua).
Config.Colors = {
    { v = 0, l = 'Black', hex = '#000000' }, { v = 147, l = 'Carbon Black', hex = '#293542' },
    { v = 1, l = 'Graphite', hex = '#251607' }, { v = 11, l = 'Anthracite Black', hex = '#383e42' },
    { v = 2, l = 'Black Steel', hex = '#0d1115' }, { v = 3, l = 'Dark Steel', hex = '#8d9296' },
    { v = 4, l = 'Silver', hex = '#c0c0c0' }, { v = 5, l = 'Bluish Silver', hex = '#8a9a9a' },
    { v = 6, l = 'Rolled Steel', hex = '#ced2d7' }, { v = 7, l = 'Shadow Silver', hex = '#939097' },
    { v = 8, l = 'Stone Silver', hex = '#99a6b0' }, { v = 9, l = 'Midnight Silver', hex = '#1b1e24' },
    { v = 10, l = 'Cast Iron Silver', hex = '#272c36' }, { v = 27, l = 'Red', hex = '#8d0607' },
    { v = 28, l = 'Torino Red', hex = '#bf0010' }, { v = 29, l = 'Formula Red', hex = '#500001' },
    { v = 150, l = 'Lava Red', hex = '#cf1020' }, { v = 30, l = 'Blaze Red', hex = '#6b0000' },
    { v = 31, l = 'Grace Red', hex = '#903346' }, { v = 32, l = 'Garnet Red', hex = '#9a2a2a' },
    { v = 33, l = 'Sunset Red', hex = '#bd1159' }, { v = 34, l = 'Cabernet Red', hex = '#280008' },
    { v = 143, l = 'Wine Red', hex = '#722f37' }, { v = 35, l = 'Candy Red', hex = '#ff0800' },
    { v = 135, l = 'Hot Pink', hex = '#ff69b4' }, { v = 137, l = 'Pfister Pink', hex = '#ffa6c9' },
    { v = 136, l = 'Salmon Pink', hex = '#ff9999' }, { v = 36, l = 'Sunrise Orange', hex = '#e67451' },
    { v = 38, l = 'Orange', hex = '#ffa500' }, { v = 138, l = 'Bright Orange', hex = '#c68525' },
    { v = 99, l = 'Gold', hex = '#ffd700' }, { v = 90, l = 'Bronze', hex = '#cd7f32' },
    { v = 88, l = 'Yellow', hex = '#ffff00' }, { v = 89, l = 'Race Yellow', hex = '#f5d365' },
    { v = 91, l = 'Dew Yellow', hex = '#a2ae54' }, { v = 49, l = 'Dark Green', hex = '#023020' },
    { v = 50, l = 'Racing Green', hex = '#004225' }, { v = 51, l = 'Sea Green', hex = '#2e8b57' },
    { v = 52, l = 'Olive Green', hex = '#808000' }, { v = 53, l = 'Bright Green', hex = '#aaff00' },
    { v = 54, l = 'Gasoline Green', hex = '#549b8c' }, { v = 92, l = 'Lime Green', hex = '#32cd32' },
    { v = 141, l = 'Midnight Blue', hex = '#1e2333' }, { v = 61, l = 'Galaxy Blue', hex = '#00344c' },
    { v = 62, l = 'Dark Blue', hex = '#00008b' }, { v = 63, l = 'Saxon Blue', hex = '#5d7fbe' },
    { v = 64, l = 'Blue', hex = '#0000ff' }, { v = 65, l = 'Mariner Blue', hex = '#163a78' },
    { v = 66, l = 'Harbor Blue', hex = '#69a0ce' }, { v = 67, l = 'Diamond Blue', hex = '#70d1f4' },
    { v = 68, l = 'Surf Blue', hex = '#56859e' }, { v = 69, l = 'Nautical Blue', hex = '#12345b' },
    { v = 73, l = 'Racing Blue', hex = '#77a2d1' }, { v = 70, l = 'Ultra Blue', hex = '#124b89' },
    { v = 74, l = 'Light Blue', hex = '#add8e6' }, { v = 96, l = 'Chocolate Brown', hex = '#7b3f00' },
    { v = 101, l = 'Bison Brown', hex = '#664b47' }, { v = 95, l = 'Creek Brown', hex = '#36332e' },
    { v = 94, l = 'Feltzer Brown', hex = '#2f240e' }, { v = 97, l = 'Maple Brown', hex = '#bb9351' },
    { v = 103, l = 'Beechwood Brown', hex = '#6c4c3c' }, { v = 104, l = 'Sienna Brown', hex = '#7f4737' },
    { v = 98, l = 'Saddle Brown', hex = '#8b4513' }, { v = 100, l = 'Moss Brown', hex = '#8a7941' },
    { v = 102, l = 'Woodbeech Brown', hex = '#6c4c3c' }, { v = 105, l = 'Sandy Brown', hex = '#f4a460' },
    { v = 106, l = 'Bleached Brown', hex = '#f3e7e0' }, { v = 71, l = 'Schafter Purple', hex = '#3f446c' },
    { v = 72, l = 'Spinnaker Purple', hex = '#3e4670' }, { v = 142, l = 'Midnight Purple', hex = '#161221' },
    { v = 145, l = 'Bright Purple', hex = '#bf40bf' }, { v = 107, l = 'Cream', hex = '#a6a7ad' },
    { v = 111, l = 'Ice White', hex = '#e5e5e0' }, { v = 112, l = 'Frost White', hex = '#f2edd5' },
}
