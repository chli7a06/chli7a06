# Crimson pressure-washer integration

# Current update: 1.4.3 / V4

This package includes the compiled V4 carry/spray clips and a washer with its long
lance shortened by 15 cm. Grip and bottle dimensions are retained. The config
uses dictionary `crimson_wash_custom_v4` and muzzle `(0.840, 0, 0.041)`; install
the model and gun config together. No XML conversion is needed.

Cancel washing, back up your resource/config, then replace it with this folder.
If merging into customized settings, copy only `Config.Wash.tools.gun` from the
new config. Remove any old V1/V2/V3 YCD from this resource and keep the V4 YCD.
Restart `crimson-mechanic`, reconnect and compare lowered carry / LMB spray to
the reference. Keep WaveShield's existing resource include. Do not run the old
standalone `crimson_lavage` resource alongside this one: it streams the same prop.

CodeWalker compilation/reread, numeric channel checks, official Sollumz wrist
roundtrip, Lua parsing and mocked muzzle/hose/cleanup checks pass. FiveM skinning,
hand contact and the final visual match still need a live test. The mechanic,
server billing, UI and hose code are unchanged by V4. Earlier update notes below
describe previous releases; use the current dictionary and muzzle above.

## Previous integration notes

This package integrates the user's compiled pressure washer into the existing manual wash workflow. It retains the existing WaveShield include and ox_lib, oxmysql and qbx_core dependencies.

## Installation

1. Back up the existing `crimson-mechanic` resource and any server-specific config changes. Restart only when no tuning/wash sessions are active.
2. Stop the standalone `crimson_lavage` prop prototype if installed and remove its `ensure` entry. Both packages use the same model/archetype names; do not stream duplicate copies.
3. Replace `crimson-mechanic` with this folder. If preserving a customized config, merge the changed `Config.Wash.hose` and `Config.Wash.tools.gun` fields from the supplied config, including the visible custom model, hand attachment and muzzle coordinates. Do not discard your prices, shops or other settings.
4. Keep WaveShield and the original dependencies started, then run `refresh` and `restart crimson-mechanic`.
5. Use the existing manual wash station interaction ([E]) as before. Rinse/foam/final rinse use the custom washer and GTA rope; scrub still uses the sponge. Automatic washing is unchanged.

The existing station's roof/wall anchor remains the hose supply point. This integration does not change it to a vehicle/van. The sample static hose YDR is retained with its matching YTYP archetype; the live moving hose uses the script's existing rope system.

## Changes

- Streamed the original three compiled files without modifying them; registered `crimson_lavage.ytyp` in the manifest.
- Selected the visible `crimson_pressure_washer` model instead of the hidden fuel nozzle, and set initial grip, hose connector and model-tip coordinates.
- Kept the original wash stages, prices, server-side authorization/payment/cleaning logic, mechanic tools, NUI and state-bag synchronization.
- Converted the actual model-tip position into ped-local coordinates for local particles/aim checks and world coordinates for remote effects. Original hand-offset fallback remains for non-gun tools.
- Made visual asset requests use native readiness checks. Cleanup handles cancellation during model, rope or particle loading; partially created visuals are registered for immediate removal on cancellation/restart.
- Debug remains off by default; no routine F8 messages or new standalone command added.

The hand pose and particle rotation are starting values. Verify them in FiveM before production use; change `Config.Wash.tools.gun.hand`, `.muzzle`, `Config.Wash.hose.tip` and effect rotation as needed. The screenshot's translucent bottle appearance is not fully reproduced by this opaque model material.

## Validation and limits

Mocked integration tests run real visual functions for custom model/rope creation, local and remote muzzle offsets, sponge transitions, cancellation during model/rope/effect loading and idempotent cleanup with no leaked test props. All 14 Lua files parsed after substituting FiveM-only hash literals in temporary copies, and existing web JavaScript syntax checks passed.

Tests: `texlua tests/crimson_mechanic_washer.test.lua` from the repository root. The test is outside this distributable resource folder.

**No live FiveM/Qbox/MySQL server was available.** Rope physics, in-game hand pose, multiplayer visuals, washing completion, cancellation and billing still need validation on your development server. No live-runtime or payment test is claimed. The original server/UI source files remain byte-for-byte identical to the uploaded archive. Existing original documentation is retained; this file describes the added washer integration.

## Grip and hose revision (1.3.3)

The gun now uses the weapon-hand prop bone, a corrected model-axis rotation, and the `anim@move_m@security_guard` / `idle` armed-guard holding clip. The dictionary/clip pair was checked against the GTA animation list; its actual appearance with this prop still requires in-game hand-offset calibration. No real weapon is granted or removed.

The rope uses type 3, pins its endpoints directly to the animated gun connector and the station anchor, and limits visible slack separately from the allowed wash reach. Direct pinning avoids relying on a physics attachment to the custom YDR, which has no collision body. The length is explicitly forced after creation and updated when endpoint distance changes. Set `Config.Wash.hose.pinEnds = false` only to test the alternative entity-attachment behavior. A failed local hose creation shows an in-game notification, not routine F8 logging.

Replace/merge the updated gun hand/animation and hose configuration as well as `client/wash.lua`; keeping the previous config retains the old pose. Cancel an active wash before restarting. Mocked tests cover pinned connector position, length changes, local/remote nozzle positioning and cancellation cleanup. Neither this revision nor the earlier attachment values were calibrated on a live FiveM client here.

## Two-state grip and smooth hose revision (1.3.4)

The gun now has separate carry and spray clips: `move_weapon@rifle@generic` / `idle` when holding, and `combat@aim_turns@rifle` / `r_0` while spraying. Both names exist in the GTA animation list. Animations are reasserted if interrupted; sponge animations remain unchanged. The model's roll was flipped to place the reservoir below the lance. **Actual two-hand alignment and pose resemblance to the supplied screenshots have not been verified in FiveM.** These remain configurable through `tools.gun.hand`, `.anim` and `.aimAnim`.

`Config.Wash.hose.renderer = 'rubber'` now draws a smooth black, round tube along a live sagging curve. Its default radius is 0.008m, matching the Blender source hose. This is a procedural visual representation, **not deformation of the static `crimson_pressure_hose.ydr` binary**. The static source and compiled asset are retained. This mode avoids the braided GTA rope texture, does not replace any globally shared GTA texture, and does not create physical rope or hidden anchor entities. Hose reach/cancellation still uses the existing wash-session limits. It is a visual curve, with a midpoint ground-height approximation; it has no full terrain/wall collision simulation.

The default near hose has 16 spans and 8 sides (256 triangles); distant hoses use fewer spans and the render distance is 35m. Geometry tables and circle samples are reused. Tune `hose.segments`, `.sides`, `.radius` and `.renderDistance` if many wash sessions are visible. Native-rope fallback remains available through `hose.renderer = 'native'` and is regression-tested.

Mocked checks cover both rendering modes, finite mesh coordinates including vertical endpoints, near-black material colors, idle/spray animation selection, local/remote muzzle offsets and cleanup. **No live render/performance, ped-animation or collision testing was possible here.** Do not treat the animation-list check as proof of an exact screenshot match. Install the updated config and client wash file together; no CodeWalker reconversion is needed.

## Chest-relative two-hand IK revision (1.3.5)

The prior screenshots showed that clip selection plus a weapon-bone attachment still produced a backwards/upward model and incorrect arms. The gun now uses an optional `tools.gun.pose` controller instead: it is positioned from the chest in world space, its source +X axis points forward with camera pitch/yaw while spraying, and its +Z orientation keeps the bottle below the lance. Carry and spray have separate chest-relative grip targets.

The controller requests right-arm IK (native part 4) toward the model grip and left-arm IK (part 3) toward the front support point on the gun. Requests are refreshed every frame and expire on their own after the session ends; no real weapon or persistent IK player flags are created/changed. The walking base clip remains the verified `move_weapon@rifle@generic` idle for both states; arm placement is controlled by IK rather than the previous aim-turn clip. Physics/gravity are disabled on the local visual gun; it is no longer attached to the rotating weapon-hand bone when `pose` is set. Other tools retain their normal attachment and animations.

**This is still not a live-verified custom animation.** Mocked tests verify the forward/down carry direction, forward/up spray direction, both IK target indexes, the grip-height change and cleanup. They cannot verify the game's actual IK solver, hand orientation, finger closure, shoulder appearance or exact resemblance to the reference video. Ped-dependent tuning remains under `pose.carry`, `.spray`, `.rightGrip` and `.leftGrip`.

Install the updated `client/wash.lua` and the new `Config.Wash.tools.gun.pose` config together. Keeping only the old hand settings will retain the old attachment behavior. WaveShield, server billing, UI and the black rubber hose renderer remain unchanged.

## Actual-palm anchoring correction (1.3.6)

The user's subsequent screenshots showed that the IK targets alone did not make the arms reach the chest-relative prop. The model placement now follows the actual right-hand bone, with a model-grip correction, even when IK is blending or fails to move the arm. Arm and torso IK are explicitly enabled before targets are submitted; the non-physical local gun is frozen while script transforms update it. Both IK requests still expire normally; the enable flags are not forcibly disabled at cleanup, which could interfere with normal aiming or other scripts.

The regression test deliberately leaves the mocked hand unmoved and verifies that the model grip still coincides with the actual palm. This tests the attachment math, not the visual success of the GTA IK solver. **Exact two-hand posture, finger alignment and the reference animation remain unverified on a live client.** If the pose is still wrong, an in-game calibrated/custom animation is required; the mocked tests must not be presented as animation validation.

## Compiled custom animation integration (1.4.0)

The user converted `crimson_wash_custom.ycd.xml` with CodeWalker and supplied the resulting binary YCD. That unmodified compiled file is now in `stream/crimson_wash_custom.ycd`. Its RSC7 header/version, compressed payload and carry/spray name presence were checked locally. Animation dictionaries stream automatically by basename; no weapon or inventory registration is involved.

`Config.Wash.tools.gun.anim` uses `crimson_wash_custom` / `carry`, and `.aimAnim` uses `crimson_wash_custom` / `spray`. The gun attaches to bone 57005 with the transform derived from the authored skeleton: position (0.085, -0.025, 0.040), rotation (90, 0, 0), rotation order 2. The experimental per-frame chest/hand world-space controller and all explicit IK enabling/target calls have been removed. Hands now come from the authored animation tracks; the prop follows the hand through the normal attachment native.

Update the entire resource or merge the new gun config, `client/wash.lua` and the YCD stream file together. **Do not keep an old `gun.pose` config or override file from the experimental builds.** Cancel an active wash before restart. Keep WaveShield and all original dependencies running. Stop the separate `crimson_lavage` prototype to avoid duplicate prop/archetype registrations.

Local tests pass for custom clip selection, derived attachment config, absence of runtime IK/weapon grants, hose renderers, nozzle positions, sponge transitions and cleanup. All Lua files parsed; original server/billing/UI/mechanic source remains unmodified. **The compiled YCD has not yet been executed in FiveM here.** Verify male freemode carry/spray poses, hand contact, movement, transitions to sponge and cancellation in-game. No exact reference-video match, female-ped retargeting or live anti-cheat compatibility is claimed.

## Compiled V2 grip refinement (1.4.1)

The user supplied the CodeWalker-compiled `crimson_wash_custom_v2.ycd`. It is installed unmodified in stream, and the older `crimson_wash_custom.ycd` is removed from this package. Header version 46, raw-deflate payload and carry/spray names were verified; the file differs from V1.

Both animation references now use `crimson_wash_custom_v2`. The V2 hand attachment is position (0.085, 0.025, -0.040), rotation (-90, 0, 0), bone 57005/order 2. V1's attachment values are incompatible with the revised right-palm orientation. Update the config and YCD together. Remove the old stream file from an existing installation rather than merging folders blindly, and remove any manually added custom_washer_config.lua override that references V1.

The V2 source corrects mirrored right-finger bend direction and includes explicit forearm/hand position channels. Source importer round-trip checks passed, along with integration/muzzle/hose/cleanup tests. **These are not live FiveM animation or skinning tests.** Confirm carry and spray poses on the supplied male freemode skeleton, hand contact, sponge transitions and remote-player appearance before treating the refinement as complete. Mechanics/server billing/UI and WaveShield remain unchanged.

## Forward-clearance animation V3 integration (1.4.2)

The user compiled and supplied `crimson_wash_custom_v3.ycd`. It replaces V2 in the stream folder and both carry/spray config references. The compiled file is copied byte-for-byte; RSC7 version 46, decompression and both clip names were checked. The rigid attachment values remain bone 57005, position (0.085, 0.025, -0.040), rotation (-90, 0, 0), order 2.

V3 source advances the gun and both hands together by 9cm in carry / 8cm in spray, with small thumb/finger curl refinements. Source reach/position and importer round-trip checks passed. **Actual clearance against the user's character/clothing and final hand contact are still pending a live FiveM test.** No claim of confirmed in-game correction is made.

Cancel washing before updating, preserve customized settings in a backup, remove the old `crimson_wash_custom.ycd` / `crimson_wash_custom_v2.ycd` files, and update both gun animation references to `crimson_wash_custom_v3`. Avoid old override files pointing to previous dictionaries. Existing hose, mechanic/server/UI files and WaveShield behavior are unchanged by this revision.
