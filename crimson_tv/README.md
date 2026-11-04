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
