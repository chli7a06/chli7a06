# Crimson washer animation V3 — forward clearance refinement

Authored from the supplied male freemode skeleton and the user's side/front screenshots. This is animation SOURCE for CodeWalker compilation, not an already installed/verified FiveM binary.

## Bounded changes from V2

- Advanced the gun and both hand targets together by 9cm in carry and 8cm in spray. Target height, lateral position and gun pitch remain unchanged.
- The purpose is to move the pistol housing out of the torso without leaving the hands behind. Actual clearance against the user's GTA body/clothing still requires a client test.
- Added small thumb/non-trigger-finger curl increments; the right trigger finger is unchanged. V2's mirrored hand orientation and explicit forearm/hand position tracks are retained.
- Both arms remain within the supplied rig's anatomical reach. The left carry arm is close to full reach (~97%); ped/body differences may need further tuning.
- Native attachment remains approximately bone 57005, position (0.085, 0.025, -0.040), rotation (-90, 0, 0), order 2. The new dictionary is `crimson_wash_custom_v3` with `carry` and `spray` clips.
- The preview now bakes the original prop object transform before display, so preview mesh coordinates match drawable coordinates. The compiled prop itself is unchanged.

## Convert once with CodeWalker

1. Extract this ZIP into a work folder and open it in CodeWalker RPF Explorer.
2. Enable Edit mode; right-click the empty area, select **Import XML…** and choose `crimson_wash_custom_v3.ycd.xml`.
3. Send back the compiled `crimson_wash_custom_v3.ycd` (without `.xml`) for integration into the mechanic resource.

Do not rename XML to YCD. The current mechanic package has not been switched to an uncompiled dictionary. No original GTA file needs modifying.

## Files and checks

The Blender source, carry/spray capsule-mannequin previews, authoring script, official-Sollumz importer round-trip check, metrics and prepared client config override are included. The source builder requires Blender 4.3, Sollumz v2.6.0 (SOLLUMZ_PARENT selects its parent folder), the user-supplied skeleton XML path after `--`, and the sibling original `crimson_lavage_assets/crimson_pressure_washer.blend` source file.

Checks verify both hand targets advanced by the specified distances while preserving height/side, valid arm reach, sub-millimetre authored grip errors, 42 normalized rotation tracks plus 4 finite position tracks per clip, and round-tripped wrist positions within 1mm through the official Sollumz importer.

**No live FiveM or actual GTA character-skinning test was possible here.** Capsule previews are not proof of correct finger contact, clothing clearance, attachment conventions or exact reference-video appearance. No weapon or inventory is added. Existing hose, washing stages, mechanic UI and billing remain unchanged; only the animation source and its pending integration override are revised.
