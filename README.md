# Crimson MDT 4.0.1 — working 4.0 base + cameras and serial search

Camera deletion fix: [single-file update](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_camera_delete_fix.zip). Replace only crimson_doj/web/registry.js and restart crimson_doj. The Delete camera button now deletes directly without any confirmation popup, as requested. The button is disabled while processing and server permission/version checks remain enforced. No native focus/opening, manifest, database or permissions change is needed. The complete resource download below also includes this fix.

[Download complete resource](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_4.0.1_cameras_serial.zip) · [التركيب والتجربة بالدارجة](crimson_doj/INSTALL/STABLE_4_0_1_AR.md) · [Feature status](crimson_doj/FEATURES.md)

Built from the exact 4.0 ZIP the user uploaded and confirmed working. Adds only observed weapon-serial search (last holder name/CID) and persistent camera creation/edit/view/delete in MDT. The original app.js, permissions, schema, style and extension UI are byte-identical to the uploaded base. The only native client difference is the custom-camera selector. Existing MDT opening and cursor behavior are preserved; the experimental 4.1 localization, handshake, timeout and air-unit changes are not loaded in this release.

Use this complete resource to return from the experimental 4.1 builds. Preserve customized configuration, permissions, sounds and recordings before replacing runtime files. No new item or SQL import is required. Earlier 4.1 downloads remain historical artifacts and should not be overlaid onto this version.

Weapon observations cover online ox_inventory holders, not legal ownership or offline/stash inventories. Camera access follows the existing legal-department and management permissions and routing-bucket separation. The original 4.0 bank, documents, badge, legal records, armory, tracking and Origen bridge workflows are retained.

Validation includes Lua authorization/provider tests, DOM workflows, real MariaDB query/schema checks and a comparison against the original 4.0 ZIP that asserts the working opening/focus implementation was preserved. User-confirmed FiveM operation applies to the original 4.0 base; the two new workflows still require in-server acceptance. This independent implementation does not claim full XR parity.
