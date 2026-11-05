# Crimson custom washer upper-body animation source

Two newly authored upper-body poses, made against the user-supplied `mp_m_freemode_01` skeleton and the Crimson washer model:

- `carry`: both hands low in front, lance tilted down 25 degrees.
- `spray`: both hands raised, lance horizontal ahead of the torso.

**Status: authored Blender and CodeWalker XML source. Binary YCD compilation and live FiveM validation are still required. This is not an already verified in-game animation or an exact copy of the reference video's original animation.** The previous stock-animation/IK trials are not represented as successful.

## Convert using CodeWalker

1. Extract this ZIP to a normal Windows work folder.
2. Navigate to that folder in CodeWalker RPF Explorer. Right-click inside it and choose **Import XML…**.
3. Choose `crimson_wash_custom.ycd.xml`. A successful conversion should create `crimson_wash_custom.ycd` (without `.xml`). No original GTA file needs editing, and no new RPF archive is required.
4. Send back the compiled `.ycd` for inclusion in the mechanic resource, or use the integration notes below.

Do not merely rename the XML extension. The Linux build environment cannot run CodeWalker binary compilation; it has not been performed or verified here.

## Files

- `crimson_wash_custom.ycd.xml`: two clip entries (`carry`, `spray`) in dictionary `crimson_wash_custom`, each referencing 42 authored rotation tracks. These include upper-body, arms, hands and fingers; no root motion, locomotion, face or leg animation tracks are included.
- `crimson_wash_poses.blend`: editable rig and two keyed pose actions, based on the supplied skeleton. No original GTA character mesh or textures are bundled.
- `preview_carry.png`, `preview_spray.png`: neutral capsule-mannequin previews with the actual prop. These illustrate skeleton placement; they are not a screenshot of the skinning/animation inside GTA.
- `validation.json`: reach ratios, authored wrist/palm errors and derived hand-to-prop transforms.
- `build_animation.py`: Blender 4.3 source builder. Requires official Sollumz v2.6.0 and the supplied skeleton XML. Pass the skeleton path after `--`; set `SOLLUMZ_PARENT` to the add-on's parent directory if not under `/workspace/tools`. It also expects the sibling `crimson_lavage_assets/crimson_pressure_washer.blend` from the original model-source package.
- `verify_roundtrip.py`: reloads the generated XML through the official Sollumz animation importer and checks decoded wrist positions against the authoring metrics.
- `custom_washer_config.lua`: prepared integration override. Do not activate before installing a compiled YCD.

## Integration after compilation

1. Put the compiled `crimson_wash_custom.ycd` in `crimson-mechanic/stream`. Animation dictionaries stream automatically by their file basename.
2. Copy `custom_washer_config.lua` into the resource root. Add it to the client script list **after `config.lua` has loaded and before `client/wash.lua`**. It disables the prior experimental runtime IK controller and uses a rigid attachment derived from these authored poses.
3. Retain the current wash script's `aimAnim` support: it chooses `carry` when holding and `spray` while pressing the spray control. Sponge stages retain their previous animation.
4. Restart with no active wash sessions. Test the male freemode ped, both poses, movement, spray direction, stage transitions and cleanup before deploying.

No weapon is granted, equipped or removed by these clips/config overrides. Inventory integration is not used. The prop, washing effects and smooth black hose remain part of the existing mechanic script.

## Evidence and limits

- The source skeleton has 128 bones. Each custom clip contains 42 rotation tracks and a one-second static hold loop; game animation blending supplies the transition between them.
- Target wrist reach is below full arm length in both poses, and authored wrist/palm target errors are below 1mm.
- The official Sollumz v2.6.0 YCD importer successfully round-tripped both decoded wrist positions to within 1mm.
- The XML was parsed and checked for clip links, track count, normalized quaternions and the absence of root/leg/face tracks.
- Carry and spray derive the same rigid right-hand prop offset: position (0.085, -0.025, 0.040), rotation (90, 0, 0), native rotation order 2. The corresponding native attachment convention still needs live verification.
- No binary YCD compiler, live FiveM runtime, original character skin mesh, female ped retargeting or multiplayer animation validation was available. Finger skinning, exact grip contact, movement masks, anti-cheat behavior and runtime visual resemblance remain unverified. These source-preview checks do not establish those outcomes.
