-- Apply only AFTER crimson_wash_custom.ycd has been compiled and installed in stream.
-- Load after config.lua and before client/wash.lua. No weapon or inventory is used.
local gun = Config.Wash.tools.gun
gun.model = 'crimson_pressure_washer'
gun.hidden = false
gun.pose = nil -- Disable previous experimental world-space/IK controller.
gun.hand = {
    bone = 57005,
    pos = vec3(0.085, -0.025, 0.040),
    rot = vec3(90.0, 0.0, 0.0),
    rotOrder = 2,
}
gun.anim = { dict = 'crimson_wash_custom', clip = 'carry' }
gun.aimAnim = { dict = 'crimson_wash_custom', clip = 'spray' }
gun.muzzle = vec3(0.990, 0.0, 0.041)
Config.Wash.hose.tip = vec3(-0.07, 0.0, -0.18)
