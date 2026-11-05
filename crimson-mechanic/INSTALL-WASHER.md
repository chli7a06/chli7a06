# Crimson pressure-washer integration

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
