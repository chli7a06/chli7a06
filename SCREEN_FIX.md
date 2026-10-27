# Black-screen fix 2.0.1

1. Keep crimson_doj stopped while updating. Back up the folder and keep your config.lua.
2. Extract downloads/crimson_doj_2.0.1.zip. Copy its crimson_doj files over the existing resource. If you changed config.lua, preserve your own config rather than overwriting it. Do not leave two different resource folders with the same name.
3. Start crimson_doj from the server console. Before opening the tablet, confirm the game stays visible. Then test opening, Esc, closing, camera view and return.
4. Recovery while running: `/mdtclose` in chat, or `mdtclose` in the client's F8 console. If that does not recover the view, stop crimson_doj from the server console and send the F8 error text.

The fix removes a root-level dark color-scheme that can paint FiveM's fullscreen browser canvas black even when the tablet is hidden. Explicit HTML/body transparency and a native focus/camera cleanup command are included. This diagnosis fits the report that stopping the resource removes the overlay; live CEF behavior still requires confirmation.
