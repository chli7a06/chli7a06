# Crimson pressure-washer integration

# Current update: 1.4.14 / neutral left support wrist (V7)

The left support hand uses an oblique grip aligned with its forearm, rather than
pointing across the barrel and bending sharply at the wrist. Forearm roll is
aligned with the palm so the wrist does not carry that axial twist. The support
palm shifts slightly below/around the collar. Carry/spray remain separate clips.

V6 carry's forearm/hand-axis bend measured about 77 degrees. V7 importer checks
measure 8.8 degrees in carry and 12.5 in spray, with matching forearm/palm roll.
Finger joint/collar contact checks and binary channel roundtrip pass. Comparing
compiled channels to V6 confirms only left upper-arm/forearm/hand tracks change;
other channel differences remain below 1e-5. This is skeleton validation, not a
live skinned-ped appearance test.

Install the complete resource or replace the old V6 YCD with the supplied
`stream/crimson_wash_custom_v7.ycd` and change both gun dictionaries to
`crimson_wash_custom_v7`. Restart and reconnect. The right hand, attachment,
gun model/length, physical stream direction, surface foam, audio and runtime
motion controller are retained. Test the left-hand appearance on the actual ped.


# Previous update: 1.4.13 / inline PCM audio

The HUD bundle now contains both four-second mono 22050 Hz, 16-bit PCM WAV loops
as data URLs. Normal playback does not request `audio/*.ogg` or any other audio
file URL, removing the external-path/OGG-source dependency behind the reported
media-source error. `web/audio/*.wav` are build inputs; the client receives their
bytes inside `web/wash.js`. Existing OGG files remain only as legacy fallback.

Rebuild original synthetic loops with `scripts/build_wash_audio.py`, then run
`scripts/bundle_wash_audio.py`. The bundler validates WAV format and sample count
before embedding. Install the full updated resource and reconnect so NUI reloads
`web/wash.js`. Browser decoding errors for inline sources now report as decoding
errors rather than suggesting a missing external audio file.

Chromium playback tests deliberately return 404 for every external audio path.
Both inline loops loaded and advanced playback time, stage changes and release
worked, callbacks reported playing, and zero audio-file network requests occurred.
Legacy-JavaScript, singleton/lifecycle and existing wash checks pass. This verifies
browser decoding/playback; actual FiveM/device sound output still needs a live test.


# Previous update: 1.4.12 / audio integrated with the wash HUD

The audio player is bundled into the already-loaded `web/wash.js` HUD entry
point, rather than requiring a separate HTML script tag. `wash-audio.js` remains
its editable source; regenerate the bundle with `scripts/bundle_wash_audio.py`.
A singleton guard avoids duplicate players if an older HTML file loads both.

Lua supplies `GetCurrentResourceName()` with audio updates. The browser uses it
for the status callback even when `GetParentResourceName` is unavailable, and
retries the readiness report if the callback is not ready during initial load.
The earlier "interface non chargée" notification indicated an absent response,
not proof that a particular file was missing; its text now reflects that.

A Chromium test without `GetParentResourceName` or `Object.hasOwn`, using renamed
resource callbacks and legacy HTML with both script tags, confirmed readiness,
water/foam playback and release cleanup, with only one player per source.
This does not verify sound output on the user's FiveM client.

Install the complete resource, especially the updated `web/wash.js`, Lua file
and audio assets. Restart and reconnect to reload NUI. Existing visual spray,
vehicle foam/wetness, emitter direction and animation behavior are unchanged.
If playback is still unavailable, the on-screen error should distinguish media
loading/decoding or blocked playback from a missing UI response.


# Previous update: 1.4.11 / legacy NUI audio compatibility

Replaces `Object.hasOwn` with the older-CEF-compatible
`Object.prototype.hasOwnProperty.call`. With the newer method unavailable, the
previous audio message handler throws before constructing any audio player.
This failure was reproduced in Chromium with `Object.hasOwn` disabled.

The revised player was tested in Chromium against the actual packaged OGG files,
with autoplay enabled as in the game host: water and foam load/decode, playback
time advances, a stage change stops the preceding loop, and release stops both.
This verifies browser playback, not the user's physical audio output or FiveM
CEF configuration.

Playback rejection and media errors are no longer silently swallowed: they send
one status callback identifying blocked playback, unavailable files or decoding.
If the audio UI never reports readiness while spraying, the client displays a
single installation/reconnect notification after three seconds. There is no
routine F8 output. A volume of zero keeps audio disabled.

Install the complete resource and reconnect, including `web/wash-audio.js` and
the new Lua NUI callback. All previous car-body foam/wetness, spray direction,
hand pose and motion behavior are retained. If sound is still absent, report the
exact on-screen audio notification; no unrelated anticheat change is required.


# Previous update: 1.4.10 / independent spray audio and emitter-axis correction

Water and foam now have their own packaged looping audio, driven by desired
spray state rather than particle handles. The owner hears the active stage;
nearby viewers hear it with distance attenuation (24 m default). At most four
streams play per viewer. Releasing LMB, changing stages, losing the visual or
stopping the resource stops the matching sound. NUI also stops audio when its
client heartbeat is absent for 750 ms.

The included OGG files are original synthetic pressure-spray/foam sound effects,
not recordings extracted from GTA. They are reproducible using
`scripts/build_wash_audio.py`. `Config.Wash.sprayAudio` controls volume/range.

The `scr_carwash` water and soap emitters now include -90 degrees X rotation to
map their local +Z emission into the barrel's forward direction. The existing
physical barrel slope, impact test, bodywork foam/wetness and motion fixes remain.

Install the complete resource, including the manifest, updated config, HTML,
`web/wash-audio.js` and both `web/audio/*.ogg` files. Restart and reconnect so
NUI loads the new audio code. When merging custom config, include `sprayAudio`
and the changed `effects.water.rot` / `effects.foam.rot` values.

Mocked tests cover owner/spectator audio selection, attenuation, start/stop,
no restart on volume updates, stage switching, lost-heartbeat cleanup, and the
emitter-axis calculation. Both OGG files decode as non-silent four-second loops.
Lua/JS and existing wash tests pass. Actual CEF playback, perceived sound quality
and particle direction still need a live check on the user's server.


# Previous update: 1.4.9 / bodywork foam, wetness and straight spray

Foam now accumulates as transparent bubble-textured patches at the actual vehicle
impact points. It remains during release/scrubbing. Water rinses nearby foam
patches into wet patches; un-rinsed panels retain their soap. Patches use local
vehicle coordinates and collision normals, and follow the vehicle transform.
They are cleared when the wash ends/cancels or the viewer's visual is removed.
This is a surface visual layer, not a volumetric fluid simulation.

Wet patches prefer GTA's dynamic `splatters_water` decals (1040); transparent
water-drop highlights are used if decal placement fails. Only handles created
by this resource are removed on replacement/cleanup. Foam and wet textures are
included under `textures/` and generated by the repository's deterministic
`scripts/build_wash_surface_textures.py`.

The owner and nearby viewers receive the same bounded snapshot through the
existing wash state bag. It retains at most 48 patches, samples hits at most
once per 180 ms, and skips new revisions for unchanged cells. Late viewers get
the snapshot with the current wash. No new server events or billing changes.

The spray emitter, animated droplets and hit test now share the physical lance
axis. `gun.muzzleDirection=(1,0,-0.08)` follows the front barrel. Camera heading
still steers the body, but no longer bends the water sideways from the muzzle.
Continuous mesh ribbons are disabled; `scr_carwash` water/soap particle effects
provide the main spray, with small animated droplets as a visibility fallback.
The old extinguisher powder effect is replaced by the dedicated soap effect.

Install the full resource including manifest, `client/wash_surface.lua`, updated
`client/wash.lua`, textures and new config fields. Restart and reconnect. Preserve
custom shop/pricing settings and the WaveShield include. Check foam/rinse stages
with two nearby players. Native particle appearance, decal placement on each
vehicle's collision mesh and the final visual realism still require a live test.

Mocked checks cover foam persistence, local rinse removal, wet decals and their
cleanup, moving-car coordinates, bounded/validated snapshots, owner/spectator
rendering and the physical muzzle ray. Previous progress, motion and hose checks
also pass. These checks do not establish an in-game photorealism result.


# Previous update: 1.4.8 / motion stability

Carry/spray tasks start only when the pose changes. The task controller allows
700 ms for blending before checking playback, ignores transient false playback
reports, and recovers persistently interrupted tasks no more often than once
per 1200 ms. Carry/spray transitions use the secondary slot's crossfade without
stopping the previous animation first. Stage-end and sponge-idle cleanup remain.

Body heading is limited to 120 degrees/second with a three-degree resting
deadband, instead of a per-frame step. Spray steering uses the camera heading
rather than the animated muzzle-to-target direction, removing that body/muzzle
feedback path at close range. The actual jet still points at the aim target.

Replace the resource after backing up customized settings, restart and reconnect.
For a manual merge, install `client/wash.lua`; gun config and all streamed assets
are unchanged. Water/foam rendering, input and replication from 1.4.7 are retained.

Mocked tests cover delayed/transient animation playback reports, pose crossfades,
bounded interruption recovery and equal heading speed at 30/144 fps. Existing
wash-progress, spray/spectator/cleanup tests and Lua parsing also pass. A live
FiveM check is still needed to confirm whether this resolves the reported jitter
with the user's other resources and actual ped animation runtime.


# Previous update: 1.4.7 / nonblocking input and visible spray

LMB now has a physical mouse-button binding, with enabled/disabled attack controls
24 and 257 as additional input sources. Releasing the button or ending the wash
clears the held state. The HUD still shows LMB; no weapon is equipped or fired.
Particle dictionaries are requested without yielding the wash loop, so an absent
particle asset cannot freeze progress or replicated start/stop updates.

`Config.Wash.visualSpray` adds animated translucent water streams/droplets and a
wider white foam spray. These are drawn independently of native particle handles
on each viewer, from the same muzzle and replicated aim/impact distance. They stop
on release, sponge stages, cancellation or cleanup. Far viewers use reduced mesh
detail; the configured render distance is 100 m. GTA particle effects remain as
an additional layer when available. The custom renderer is a visual approximation,
not a simulated fluid or a foam coating accumulating on the vehicle.

Replace the resource, restart and reconnect. For customized configs, merge the
new `visualSpray` settings and install the new `client/wash.lua`. The V6 hand pose
and V5 gun length/muzzle are retained. Keep the WaveShield include.

Mocked tests run the actual rinse/foam stage through input, aim, progress and
replicated state while particle loading is unavailable. They also test direct
water/foam rendering without a particle handle, distance clipping, spectator
rendering, release, pose bindings, hose creation and cleanup. Lua syntax passes.
A live test is still required: hold LMB while aiming at the car, verify progress
and visible spray, and ask a second nearby player to check water/foam and release.


# Previous update: 1.4.6 / shared water and foam jets

Water and foam particles now attach to each viewer's local washer prop, using
its physical muzzle and a world-aim-to-gun-local rotation conversion. This
replaces the different owner-ped/spectator-world emitter paths. Existing player
state bags replicate effect type, aim and release; each nearby client creates
one emitter. Late/returning viewers are rebuilt by the existing state poll.
If a player's ped is replaced, their prop/effect copy is rebuilt as well.

Water scale is 0.40, foam scale 0.80, with full alpha and explicit water/white
foam colours. Both configured particle names were checked against the GTA data
dump. `Config.Wash.effectDistance` defaults to 100 metres for nearby viewers and
particle far clipping; entities still have to be streamed by FiveM/OneSync.
Shared effect dictionaries remain loaded until resource stop. Failed handles
retry with a delay; pending asset loads are cancelled on release/replacement.

Replace the resource after backing up custom config, or merge `client/wash.lua`,
`Config.Wash.effects`, and `Config.Wash.effectDistance`. Restart and reconnect.
The V6 hand pose, shortened model, muzzle and hose are retained. Keep WaveShield.

Mocked checks cover owner/spectator gun attachment, replicated start/stop,
rotated-tool aiming, missing-handle retry and cancellation during loading.
Lua and web syntax checks pass. Actual particle visibility/shape and multiplayer
rendering still need a live test: with two nearby players, compare rinse and foam,
release LMB, move out of range and back, and stop the wash to check cleanup.


# Previous update: 1.4.5 / V6

The left support hand rolls inward by 15 degrees around the collar axis in carry
and spray. Its position rotates about the same collar pivot to preserve finger
contact. The right-hand pose, gun model, length and muzzle `(0.760, 0, 0.041)`
remain as in V5. The gun dictionary is now `crimson_wash_custom_v6`.

Back up custom settings, cancel washing and replace this resource. If merging a
custom config, update both gun animation dictionaries to V6 and replace the old
V5 YCD with the included V6 YCD. Restart `crimson-mechanic` and reconnect.
No asset conversion is required. Automated import/compiled-channel/grip checks
pass; the final wrist appearance still needs a live FiveM check.


# Previous update: 1.4.4 / V5

Left-hand support is realigned around the front collar in carry and spray.
The lance is 8 cm shorter than V4 (23 cm shorter than the original), with the
same-size grip and bottle. Use dictionary `crimson_wash_custom_v5` and muzzle
`(0.760, 0, 0.041)` together with the included compiled YDR/YCD.

Back up custom settings, cancel washing and replace this resource. If merging a
custom config, update `Config.Wash.tools.gun`. Remove old V4 YCD overrides, restart
`crimson-mechanic` and reconnect. No Blender or CodeWalker conversion is needed.

Both compiled binaries were reread successfully. Wrist import/export and curled
left-finger/collar checks pass for carry and spray, along with resource integration
checks. Actual finger skin/contact on the live ped still needs a FiveM test.
The right-hand pose, hose code, mechanic/server/UI files and WaveShield include
are unchanged from V4.


# Previous update: 1.4.3 / V4

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
