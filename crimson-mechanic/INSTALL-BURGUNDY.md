# Crimson mechanic — Burgundy UI

Replace the existing `crimson-mechanic` resource with this folder after backing it up. Keep your existing config and server-specific changes if you have edited them. The supplied config is unchanged from the original archive.

UI changes are in `web/index.html`, `web/style.css`, `web/app.js`, and the new local `web/icons.js`. The manifest includes the icon script. `client/tuner.lua` also explicitly clears keep-input on session cleanup.

Restart `crimson-mechanic` when no tuning sessions are active. Existing dependencies (WaveShield, ox_lib, oxmysql, qbx_core) are unchanged.

The left panel holds categories and parts; options remain at the bottom; work order and confirmation remain at the top right. Rotation is below the server logo. Adjust `--rotation-top: 16vh` in `web/style.css` if your logo placement differs. This resource does not draw or replace your server logo or HUD.

Icons are bundled SVG geometry, with no CDN or font dependency. All prices, translations, supported modifications, and billing behavior continue to come from the original script.

In-game verification: open the tuner, change and remove an option, test paint/sliders and camera dragging, cancel with Escape and the close button (verify restoration), reopen and confirm a work order. Confirm mouse/keyboard return after closing, player death, vehicle deletion, and resource stop. Test your usual resolution and UI scale. Browser checks cannot certify FiveM focus or billing.
