Config = {}

Config.Debug = false -- Enable detailed client diagnostics only when troubleshooting.
Config.PinActiveScreen = true -- Keep playback on this TV until leaving range or explicitly using /tv elsewhere.
Config.ScreenStreamGraceMs = 5000 -- Preserve the browser briefly while the same map prop streams back in.

Config.ScreenSwitchDistance = 2.0 -- Another TV must be this many meters closer before automatic switching.

Config.TVRange = 50.0 -- Detection/render/audio range for TVs. Set to nil to use each model's Range value.
Config.LocationSpawnRange = Config.TVRange -- Spawn/despawn distance for TVs defined in Config.Locations.

Config.Menu = {
    Title = "CRIMSON TV",
    OpenDistance = 5.0, -- Maximum distance allowed to open /tv controls.
    MinRange = 1.0, -- Lowest range players can set from /tv.
    MaxRange = 100.0, -- Highest range players can set from /tv.
    Layout = {
        Panel = {
            Top = "66%",
            Right = "8px",
            Left = "auto",
            Transform = "translateY(-50%)",
        },
        Hint = {
            Top = "calc(66% + 230px)",
            Right = "70px",
            Left = "auto",
            Width = "252px",
            Transform = "none",
        },
    },
}

Config.Models = { -- Any TV Models used on the map or in locations must be defined here.
    -- TV identified by the user's in-game camera raycast.
    -- Standard tvscreen target; visual mapping must be checked in FiveM.
    [777010715] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen",
        Scale = 0.085,
        Offset = vector3(-1.02, -0.055, 1.04),
    },
    [`des_tvsmash_start`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_flatscreen_overlay`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_laptop_lester2`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_monitor_02`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_trev_tv_01`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_02`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_03_overlay`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_06`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_01`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_01_screen`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_02b`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_03`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_03b`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_michael`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_monitor_w_large`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_03`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
    [`prop_tv_flat_02`] = {
        DefaultVolume = 0.5,
        Range = 20.0,
        Target = "tvscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },

    [`xm_prop_x17_screens_02a_06`] = {
    DefaultVolume = 10.0,
    Range = 20.0,
    Scale = 0.55,
    Offset = vector3(0.0, 1.02, 0.3) -- Z pushes it up slightly
},

    [`xm_prop_x17_tv_scrn_01`] = {
    DefaultVolume = 10.0,
    Range = 20.0,
    -- No Target, try without first
    Scale = 0.085,
    Offset = vector3(0.0, 0.02, 0.0)
},

}

Config.Locations = { -- REMOVE ALL IF NOT USING ONESYNC, OR IT SHALL BREAK.
    {
        Model = `prop_tv_flat_01`,
        Position = vector4(144.3038, -1037.4647, 29.4173, 70.81),
    },
}

Config.Channels = { -- These channels are default channels and cannot be overriden.
    {name = "Twitch", url = "twitch.tv/twitch"},
}

Config.BannedWords = {
    "google",
}

Config.Events = { -- Events for approving broadcasts / interactions (due to popular demand).
    ScreenInteract = function(source, data, key, value, cb) -- cb() to approve. 
        if value.url then 
            for i=1, #Config.BannedWords do 
                if string.find(value.url, Config.BannedWords[i]) then 
                    return
                end
            end
        end
        cb()
    end,    
    Broadcast = function(source, data, cb)  -- cb() to approve. 
        cb()
    end,
}
