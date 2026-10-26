# Crimson DOJ — installation candidate

This is an adaptation of the supplied XR-MDT files, not a rewritten or runtime-verified resource. Original author attribution and escrow files are preserved.

Changes: Config.Framework=qbox; resource folder crimson_doj; DOJ logo and favicon use the supplied Crimson image; red/charcoal CSS theme; manifest declares qbx_core, ox_lib and oxmysql instead of yarn (the supplied UI is prebuilt).

## Before installation
- Back up the existing resource and database. Do not run xr-mdt and crimson_doj together: original event and database names are intentionally retained because escrow code cannot be edited.
- Requires an authorized FiveM Asset Escrow entitlement for the original resource. Renaming may be restricted by its protected code; this cannot be verified here. If the original enforces its resource name, obtain vendor support before using crimson_doj.
- Requires Qbox with its QB compatibility bridge enabled: editable code still calls exports['qb-core']:GetCoreObject(). This is NOT a complete native Qbox API rewrite.
- Requires ox_lib, oxmysql and the existing WaveShield resource referenced by the original manifest. No anticheat integration was removed.
- Review INSTALL/inventory_setup.md for inventory items. Inventory and integrations must match your server.
- Review configs/config.doj.lua: job is doj; grades and permissions must match your Qbox jobs. Existing grades and business lists were preserved.
- Review configs/config.webhook.lua locally and disable or replace destinations you do not own; never share credentials.
- Import INSTALL/database_qbox.sql only after reviewing it against a backed-up database; do not blindly re-import existing tables.

## Installation and verification
1. Copy the crimson_doj folder into your resources directory.
2. Add your original map.webp to web/dist/images/map.webp. It was unavailable in the transferable uploads; map views remain incomplete until then.
3. Start dependencies first, then ensure crimson_doj. Avoid running a second copy of the original MDT.
4. Inspect both server and F8 logs for escrow/name restrictions, missing exports, schema errors and absent files.
5. Use a test character with the doj job and an allowed grade. Try /dojmdt (F12) and the DOJ configuration command /doj (K), checking actual command registration on your server.
6. Verify logo/theme, authorization, profiles, reports, cases, warrants, documents, permissions and persistence after reconnect. Check unauthorized jobs cannot access protected actions.

## Known limitations
No FiveM server, Qbox runtime, live database or escrow entitlement was available here. Only UI JavaScript syntax and static file checks were run. Full gameplay behavior and resource renaming are unverified.
The original upload's index.html references render_engine.js, and its manifest lists armory.html, but neither file was present in the supplied original dist listing. Their impact must be checked in FiveM; they have not been invented or replaced.
Other images may be referenced by optional departments (for example lssd/sasp/logo.png); only uploaded images are included. DOJ uses crimson-logo.png directly.
