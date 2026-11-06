# Crimson washer V8 — distribute forearm roll

V7 reduced the hand/forearm-axis bend but forced palm roll into the main forearm
bone, creating a large axial rotation at the elbow and visible skin collapse.
V8 restores the forearm's minimal-rotation orientation and uses a side grip with
gun-local hand yaw 50 degrees, roll 130 degrees and support target
`(0.120, 0.075, 0.080)`. These gun-relative angles do not describe elbow rotation.

The native mid-forearm bone `RB_L_ForeArmRoll` (tag 61007) is now animated with
half the hand's axial rotation. Both clips have 47 channels, rather than 46.
The actual imported skeleton checks elbow axial rotation, hand bend, roll-helper
distribution and curled-finger positions. In carry/spray the elbow axial values
are -6.2/-17.0 degrees, helper rotation 19.5/22.4 degrees and hand bend 18.2/13.6
degrees. Unrelated compiled channels remain within 1e-5 of V7.

Use the updated root `crimson-mechanic.zip`; both gun config dictionaries and the
compiled stream file are already V8. No manual conversion is needed. Remove old
V7 overrides, restart and reconnect. Right hand, model/attachment and the existing
audio, spray and bodywork foam remain as before.

Build uses Blender 4.3, official Sollumz v2.6.0 and the real male freemode skeleton
previously supplied by the user. Official CodeWalker.Core commit
`485d56bec00262ed7fa472261cce7bbc6202b96e` compiles and rereads the binary.
Source XML/blend, mannequin previews and validation JSON are included.

The checks verify bones, helper tracks and compiled values. Live skinning on the
user's ped/clothing has not been verified. The mannequin preview does not contain
the original GTA skin mesh and cannot establish that the reported deformation
is fully resolved in game.
