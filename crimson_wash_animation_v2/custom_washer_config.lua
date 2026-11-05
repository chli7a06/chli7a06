-- Apply only after compiling and installing crimson_wash_custom_v2.ycd.
local gun = Config.Wash.tools.gun
gun.pose = nil
gun.model = 'crimson_pressure_washer'
gun.hidden = false
gun.hand = { bone = 57005,
    pos = vec3(0.085000, 0.025000, -0.040000),
    rot = vec3(-89.999982, 0.000000, -0.000010), rotOrder = 2 }
gun.anim = { dict = 'crimson_wash_custom_v2', clip = 'carry' }
gun.aimAnim = { dict = 'crimson_wash_custom_v2', clip = 'spray' }
gun.muzzle = vec3(0.990, 0.0, 0.041)
Config.Wash.hose.tip = vec3(-0.07, 0.0, -0.18)
