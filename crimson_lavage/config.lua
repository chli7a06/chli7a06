Config = {}
Config.Command = 'lavage'
Config.Model = 'crimson_pressure_washer'
Config.LoadTimeoutMs = 10000
Config.VehicleSearchRange = 6.0
Config.HoseLength = 12.0
Config.HoseSlack = 1.0
Config.RopeType = 4
-- These hand offsets are starting values: check orientation on your player ped.
Config.Hand = {
    Bone = 57005,
    Position = { x = 0.10, y = 0.02, z = -0.02 },
    Rotation = { x = 0.0, y = -90.0, z = 0.0 }
}
-- Local model-space connector on the underside of the gun grip.
Config.HoseGunOffset = { x = -0.07, y = 0.0, z = -0.18 }
-- Rear-centre vehicle anchor; Y is calculated from vehicle model dimensions.
Config.VehicleAnchor = { x = 0.0, rearInset = 0.15, z = 0.45 }
Config.Animation = { Enabled = true, Dict = 'anim@heists@box_carry@', Name = 'idle', Flags = 49 }
