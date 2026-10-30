# Crimson MDT 4.0.2 — stable opening, chest view, DOJ seal and ranks

[Download complete 4.0.2 resource](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_4.0.2_doj_update.zip) · [التركيب بالدارجة](crimson_doj/INSTALL/UPGRADE_4_0_2_AR.md)

Adds a chest-bone gameplay camera prepared before recording, with perspective cleanup on stop/failure/logout/resource stop; the exact uploaded DOJ PNG in MDT and badge; the requested 15 rank names; and Management from Senior Judge (12) upward. Existing native Qbox grade names are synchronized at runtime while retaining pay/boss/bank flags and without rewriting the Qbox jobs file. Missing native ranks are reported rather than invented.

MDT opening/focus stays on the user-confirmed 4.0 implementation. The only app.js change is the badge image path. The inline native camera selector now rejects security-camera playback during a chest-view recording. There is no experimental 4.1 UI handshake or 8-second timeout. No new SQL table or inventory item is needed. The direct camera-delete fix and observed serial search are included. The player sees the chest camera during recording because screencapture captures the rendered game frame; game audio is still unavailable.

Automated checks cover authorization, UI, chest-camera ownership/cleanup, capture preparation/failure and salary-preserving grade sync. In-engine acceptance of the new camera view still requires testing on the user's models/MLO/vehicles. Follow the guide and retain customized config/sounds/recordings; use the new permissions and manifest from this release.

## Previous tested base

# Crimson MDT 4.0.1 — working 4.0 base + cameras and serial search

Camera deletion fix: [single-file update](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_camera_delete_fix.zip). Replace only crimson_doj/web/registry.js and restart crimson_doj. The Delete camera button now deletes directly without any confirmation popup, as requested. The button is disabled while processing and server permission/version checks remain enforced. No native focus/opening, manifest, database or permissions change is needed. The complete resource download below also includes this fix.

[Download complete resource](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_4.0.1_cameras_serial.zip) · [التركيب والتجربة بالدارجة](crimson_doj/INSTALL/STABLE_4_0_1_AR.md) · [Feature status](crimson_doj/FEATURES.md)

Built from the exact 4.0 ZIP the user uploaded and confirmed working. Adds only observed weapon-serial search (last holder name/CID) and persistent camera creation/edit/view/delete in MDT. The original app.js, permissions, schema, style and extension UI are byte-identical to the uploaded base. The only native client difference is the custom-camera selector. Existing MDT opening and cursor behavior are preserved; the experimental 4.1 localization, handshake, timeout and air-unit changes are not loaded in this release.

Use this complete resource to return from the experimental 4.1 builds. Preserve customized configuration, permissions, sounds and recordings before replacing runtime files. No new item or SQL import is required. Earlier 4.1 downloads remain historical artifacts and should not be overlaid onto this version.

Weapon observations cover online ox_inventory holders, not legal ownership or offline/stash inventories. Camera access follows the existing legal-department and management permissions and routing-bucket separation. The original 4.0 bank, documents, badge, legal records, armory, tracking and Origen bridge workflows are retained.

Validation includes Lua authorization/provider tests, DOM workflows, real MariaDB query/schema checks and a comparison against the original 4.0 ZIP that asserts the working opening/focus implementation was preserved. User-confirmed FiveM operation applies to the original 4.0 base; the two new workflows still require in-server acceptance. This independent implementation does not claim full XR parity.
