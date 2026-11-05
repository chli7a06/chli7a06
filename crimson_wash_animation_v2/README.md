# Crimson washer animation revision 2 — SOURCE, not a compiled resource

This revises the custom carry/spray clips based on the user's in-game screenshots and original two-hand pressure-washer reference. It retains the two authored upper-body poses and adjusts the grip rather than adding weapons or changing inventory.

## Changes

- Corrected right palm orientation. The right hand's finger bend axes mirror the left hand in the supplied skeleton; the previous shared bend sign could open the right fingers instead of closing them.
- Reauthored finger closure, leaving the right trigger finger less curled than the other fingers.
- Added explicit local-position channels for both forearms and hands (4 total), alongside the 42 rotation channels. This is intended to stop inherited base-animation translations from altering the authored arm chain. It is a hypothesis for the visible wrist gap, not an in-game-confirmed diagnosis.
- Recomputed the rigid prop attachment from the new hand orientation. It is approximately position (0.085, 0.025, -0.040), rotation (-90, 0, 0), bone 57005, order 2. It differs from revision 1; do not reuse the old attachment values.
- New dictionary name `crimson_wash_custom_v2` and animation signatures distinguish this revision from the previously compiled file.

## Convert and send back

1. Extract this ZIP to a Windows work folder and open the folder in CodeWalker RPF Explorer.
2. Enable Edit mode; right-click inside the folder, select **Import XML…**, choose `crimson_wash_custom_v2.ycd.xml`.
3. A successful conversion creates `crimson_wash_custom_v2.ycd` without `.xml`. Send back that compiled file for the final mechanic ZIP integration.

Do not rename the XML to YCD, and do not replace an original GTA file. This Linux environment cannot run CodeWalker's binary compilation; it has not been done here.

## Contents

`preview_carry.png` and `preview_spray.png` are capsule-mannequin previews, not screenshots of actual GTA character skinning. `crimson_wash_poses.blend` contains the editable skeleton and actions. `build_animation.py`, `verify_roundtrip.py` and `validation.json` preserve authoring and checks. `custom_washer_config.lua` is the prepared integration override; activate it only after the compiled YCD has been added to the mechanic resource's stream folder.

Rebuilding requires Blender 4.3, official Sollumz v2.6.0 and the user-supplied skeleton XML path after `--`. `SOLLUMZ_PARENT` can select the add-on parent directory. The builder also expects the sibling `crimson_lavage_assets/crimson_pressure_washer.blend` model-source file. No original character mesh/textures or raw uploaded skeleton XML are redistributed.

## Validation and limits

The official Sollumz importer re-imported both clips and reproduced the authored wrist positions within 1mm. XML checks verified two linked clips, 42 normalized rotation tracks and 4 finite position tracks per pose, reachable wrists and a shared attachment transform. Root, face and leg animation tracks remain excluded.

**Still requires CodeWalker compilation and live FiveM testing.** The source changes are not a claim that the runtime wrist gap, skinning, finger contact or exact reference pose is fixed. Only the supplied male-freemode skeleton was authored; no female/custom-ped retargeting was tested. Carry and spray are static one-second hold loops blended by the game, not a motion-captured copy of the reference animation. The existing mechanic resource has not been changed to reference this uncompiled dictionary yet.
