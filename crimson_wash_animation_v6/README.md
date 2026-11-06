# Crimson washer V6 — inward support-hand roll

Changes the V5 left-hand orientation by 15 degrees inward around the forward
barrel/collar axis. Both the palm position and orientation rotate about the
model-space collar pivot `(0.125, 0, 0.107)` so the curled fingers keep their
distance from the collar. Applies to both carry and spray.

The right-hand pose, attachment, finger curls and V5 gun model remain unchanged.
The same shortened gun has muzzle `(0.760, 0, 0.041)`. No further length change.
The resource now streams dictionary `crimson_wash_custom_v6` with `carry`/`spray`.

Install the updated root `crimson-mechanic.zip`, restart and reconnect. No Blender
or CodeWalker step is required. Remove old V5 YCD overrides and, when merging
custom config, update both gun animation dictionary references to V6.

The editable animation source, mannequin previews and validation results are
included here. The unchanged gun's source and binary checks are in the sibling
`crimson_wash_animation_v5` directory. Build/import validation uses Blender 4.3
and official Sollumz v2.6.0 with the real male freemode skeleton. CodeWalker.Core
commit `485d56bec00262ed7fa472261cce7bbc6202b96e` compiles and rereads the YCD.

`verify_roundtrip.py` checks both wrists within 1 mm and the curled left-finger
joints around the collar after XML import. `verify_compiled_assets.py` compares
all compiled animation channels to source and confirms the V5 model is retained.
FiveM wrist skinning/contact and the final visual appearance remain untested here.
