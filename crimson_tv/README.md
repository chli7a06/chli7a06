# crimson_tv

Framework-agnostic television resource for FiveM servers.

## Features

- Play YouTube videos on supported TV props.
- Play Twitch streams on supported TV props.
- Open direct-link web pages on the TV.
- Adjust local TV volume per player.
- Interact with on-screen browser elements.
- Optional broadcast command for shared channels.
- Custom premium `/tv` menu with configurable branding and placement.

## Dependencies

- `ox_lib`
- Generic Dui Renderer / render target support required by the original resource setup

## Install

1. Place the `crimson_tv` folder inside your server `resources`.
2. Make sure `ox_lib` is installed and started before `crimson_tv`.
3. Add `ensure crimson_tv` to your server config.
4. If you are not using the sample spawned TV in `Config.Locations`, remove it.
5. Restart the server or run `restart crimson_tv`.

## Commands

- `/tv` opens the television control menu near a supported screen.
- `/broadcast` starts or stops a personal broadcast channel.

## Configuration

Main configuration lives in `config.lua`.

- `Config.Menu`
  Controls the custom menu branding and screen placement.
- `Config.Models`
  Lists supported TV/monitor models, ranges, offsets, and render targets.
- `Config.Locations`
  Optional spawned TVs. Remove these if you do not want scripted TVs.
- `Config.Channels`
  Default broadcast channels available server-wide.
- `Config.BannedWords`
  Blocks URLs containing banned words.
- `Config.Events`
  Approval hooks for screen interactions and broadcasts.

## Share / Pack Notes

- This resource now uses a single self-contained menu page for easier sharing.
- Unused temporary menu assets were removed from the manifest.
- Branding and menu placement are configurable through `Config.Menu`, so server owners do not need to edit HTML.
- The resource remains framework-agnostic as long as `ox_lib` is available.

## Notes

- The default menu branding is set to `CRIMSON TV` / `CRIMSON EMPIRE`.
- Browser/video inputs still use `ox_lib` dialogs.
- `Config.Locations` requires OneSync if you use spawned TVs.

## Crimson adaptation
Adapted from the supplied ptelevision.zip; this is a renamed and branded version, not a new independent implementation. Events, runtime textures, DUI paths and NUI callback destinations use crimson_tv. Do not run the old resource alongside this one: both register /tv and /broadcast.

Only ox_lib is required as a resource dependency. The optional anticheat include from the supplied example was removed; no WaveShield installation or framework-specific Qbox/ESX bridge is required.

Installation in server.cfg:
```cfg
ensure ox_lib
ensure crimson_tv
```

Validation: local JavaScript and Lua syntax checks only. Lua syntax checks substitute FiveM backtick hash literals in temporary copies because ordinary Lua cannot parse that FiveM extension. No live FiveM, media playback, synchronization or browser rendering validation was performed. Verify /tv near a supported prop, playback, volume, /broadcast with two players, and restart cleanup on a development server. YouTube/Twitch embedding depends on their current platform policies and client connectivity. The supplied server event permission hooks remain permissive; review Config.Events before public deployment.

## TV detection
Supported map models are configured in Config.Models. Custom models need the correct render target or scaleform settings.

Model 777010715 is enabled based on the in-game aimed-object diagnostic. It uses the standard tvscreen render target provisionally. Detection/configuration checks pass locally; its actual model render-target mapping still requires in-game validation. If controls open but the display stays blank, report F8 errors and the model asset/name so the render mapping can be checked.

DUI lifecycle fix: pending operations stop when a TV browser is absent or replaced, readiness waits are bounded, and render/audio workers belong to their own screen session. Mocked regression checks: from the repository root run `texlua tests/crimson_tv_dui.test.lua` and `texlua tests/crimson_tv_menu.test.lua`. These do not validate FiveM native implementations or the provisional model render target.

Build 2026-11-04-dui-handshake-1 uses the local TV page pageLoaded callback for initial browser readiness rather than polling IS_DUI_AVAILABLE (native 7aac3b4c). F8 prints BUILD on startup, TV page ready on acknowledgement, or a timeout if the page fails to load. Mocked tests cover acknowledgement, screen switch cancellation and timeout; actual client rendering remains unverified.

Build 2026-11-04-target-renderer-2: named render targets draw the DUI texture directly without loading generic_texture_renderer. Previously its unbounded load could stall browser creation if that external scaleform was absent. Models without a named target still require this scaleform, with a 10-second timeout. Run `texlua tests/crimson_tv_renderer.test.lua` for the mocked regression test. F8 now reports Opening TV and render-target linkage to diagnose actual model mapping.

Build 2026-11-04-signed-target-3 accepts negative signed render-target IDs. The user reported a linked tvscreen with ID -1994970322; the previous positive-only check incorrectly skipped drawing. The regression test now exercises that exact signed ID and verifies the render function is reached. In-game visual confirmation remains pending.

## Menu appearance (1.3.0)
Hookah-reference styling: rounded charcoal rows, red selection, circular TV action icons, a rounded header with close button, descriptions and ESC hint. Panel anchors remain Top=66%, Right=8px and translateY(-50%) through the existing Config.Menu.Layout settings. Browser validation at 1920x1080 confirmed five actions, the same anchors, keyboard navigation and close callbacks. The temporary TV diagnostic command has been removed. Live FiveM appearance still requires client confirmation.

Version 1.3.1 removes the header subtitle and fixes mouse clicks: hover/selection now updates classes on existing buttons instead of rebuilding the menu DOM during pointer interaction. Chromium validation clicked all five actions with pointer down/up, confirmed stable button nodes and callback indexes, and rechecked keyboard selection, close and the original panel anchors.

Version 1.3.2 stabilizes automatic TV selection. The active TV remains selected unless another is at least Config.ScreenSwitchDistance (default 2m) closer; the same margin applies at the render-range boundary. A transient object-pool omission does not discard an existing active entity. Real switches start the replacement in the same polling iteration, removing the former 2.5-second empty interval. Run `texlua tests/crimson_tv_selection.test.lua` for mocked checks; live playback continuity still needs in-game confirmation.

Version 1.3.3 pins automatic playback to the active TV while it remains in range. Use /tv next to another supported screen to explicitly switch. If the map recreates the same model at the same coordinates (within 0.25m), the renderer rebinds the entity handle without recreating the browser. A 5-second streaming grace preserves the session during brief absence. Config.PinActiveScreen, Config.ScreenStreamGraceMs and Config.Debug control this behavior. Debug is off by default; a single build marker and actual initialization failures remain visible. Chromium/ox_lib font warnings are independent. Mocked checks cover pinning, rebinding and grace expiry; live logo continuity still requires confirmation.

Version 1.3.4 uses system monospace fonts for the TV display instead of loading VCR_OSD_MONO. No custom font request is made by the display stylesheet. Other resources such as ox_lib can still emit their own font-loading warnings.
