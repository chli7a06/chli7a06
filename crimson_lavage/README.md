# Crimson Lavage — prop and rope prototype (0.1.0)

This resource streams the three compiled assets supplied by the user after CodeWalker conversion. It attaches the washer to the local player's right hand and creates a dynamic FiveM rope to the rear of a nearby vehicle.

## Install and try

1. Put the `crimson_lavage` folder in your server's `resources` directory.
2. Add `ensure crimson_lavage` to `server.cfg`, or run it from the server console after `refresh`.
3. Stand outside a vehicle, within 6 metres of its centre, preferably next to its rear. Use `/lavage`.
4. Use `/lavage` again to put it away. The resource also removes the prop and hose on death, entering a vehicle, changing player ped, loss of the supply vehicle, exceeding the 12m hose length, or stopping the resource.

No Qbox bridge, ox_lib, WaveShield, database or inventory dependency is required. No routine console logging is added. User-facing loading failures appear as game feed notifications.

## Scope

**This is a local visual prototype, not a complete car-washing job.** The washer and rope are visible to the local client only. No multiplayer synchronization, networked washing state, water spray, dirt changes, payment, job permissions, inventory items or machine/van model are implemented. This stage validates the compiled model, hand pose and dynamic hose first.

The static `crimson_pressure_hose.ydr` is retained as an optional asset but is not spawned as the moving hose: the runtime uses GTA rope physics. A static mesh cannot simulate a flexible connection.

## Configuration

`config.lua` contains the command name, 10-second load timeout, hand bone and attachment offsets, gun-side connector offset, rear-of-vehicle anchor, maximum hose length, rope type and optional holding animation. The supplied offsets and upper-body animation are initial values, not an in-game calibrated match to the screenshot. Custom vehicles may need a different anchor. Test them in FiveM and adjust before adding gameplay.

Local integration exports, for use by a later client script:

```lua
exports.crimson_lavage:ToggleWasher()
exports.crimson_lavage:StopWasher()
```

## Validation

- The uploaded YDR and YTYP files have RSC7 headers and are copied without modification.
- Lua parsing and mocked lifecycle tests passed: equip/unequip, idempotent cleanup, missing model/vehicle, rope creation failure, cancellation during model load, death, distance limit and resource-stop cleanup.
- Run `texlua tests/crimson_lavage.test.lua` from the repository root for those tests.
- **No live FiveM execution or rope physics, animation and attachment calibration was possible here.** CodeWalker gun preview was supplied by the user; that does not establish in-game behavior.
