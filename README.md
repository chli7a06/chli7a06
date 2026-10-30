# Correctif 4.1.1 — NUI française

[Correctif léger pour une installation 4.1](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_hotfix_4.1.1.zip) · [Version complète corrigée](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_4.1.1_preview.zip)

Fixes the French UI accidentally translating the HTTP POST method, which made FiveM NUI receive empty request data. POST/JSON transport stays fixed in every language; malformed Lua callback inputs now return an error without throwing. Existing configuration/database/items are unchanged. For an existing 4.1 install, overlay the three hotfix files (do not delete the resource directory), then restart crimson_doj. Regression tests validate HTTP method/content type during French workflows and empty/malformed callback handling.

# Crimson MDT 4.1 preview — Qbox

[Download corrected 4.1.1 preview](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_4.1.1_preview.zip) · [التركيب من 4.0](crimson_doj/INSTALL/UPGRADE_4_1_AR.md)

French default UI; Mission Row helicopter issue/return with qbx_vehiclekeys; server-observed online weapon serial search; persistent scoped camera editor and viewer. Existing Apex, badge, printing and rank behavior are preserved. No new inventory item or schema table is required. User-provided documents/identity text are not translated. Automated checks pass; these new features still need FiveM multiplayer acceptance. This is not full XR parity or an Origen private-API integration.

## Previous release

# Crimson MDT 4.0 preview — Qbox

[Download 4.0 preview](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_4.0.0_preview.zip) · [التركيب والتحديث](crimson_doj/INSTALL/UPGRADE_4_AR.md) · [Current feature audit](XR_PARITY_REVIEW_4.0.md)

Adds full citizen/vehicle annotations, structured cases and convictions, native licenses, staff duty/suspension, business files, signed physical documents/archive, stock armory/kits/returns, tracking, dispatch responders/Origen alert bridge and statistics. Live bodycam is video-only and requires a separately deployed screencapture SFU Worker. This preview is independently implemented and is not exact XR parity. Automated checks pass; FiveM multiplayer acceptance is still required. Preserve customized configuration, sounds and recordings when upgrading.

## Earlier releases

# Crimson MDT 3.0.2 beta — Qbox

[Download complete pack](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_qbox_pack_3.0.2.zip) · [Crimson resource only](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_3.0.2.zip)

[التركيب بالدارجة](INSTALL_AR.md) · [English setup, permissions and limits](INSTALL_CRIMSON.md) · [Feature status](crimson_doj/FEATURES.md)

Independent Police/DOJ/EMS/Business MDT with Crimson branding. v3 adds physical document printing/items, recipient-confirmed bank payments, case-linked fines and prison actions, local bodycam capture and private playback. Includes source, schema and tests. No XR-MDT escrow files or old Cfx entitlement are required; this is its own implementation, not full/exact XR-MDT parity.

The companion pack contains official Renewed-Banking, qbx_prison, screencapture and ox_target releases/source with original attribution/licenses and source archives. Your existing Qbox/ox_lib/oxmysql/ox_inventory base is still required. Import the bank SQL and register the document item before live use. Do not overwrite existing customized dependencies blindly.

**Beta:** tests here include mocked Qbox/provider workflows, real filesystem/transfer code, actual MariaDB schema/migration checks and real Chromium/WebM rendering. Actual FiveM natives/providers were not executed here. Complete the staged in-game acceptance checks before regular use. Bodycam video is experimental and has no audio with the selected provider. Cross-provider money operations have a durable needs-review path rather than a false atomicity guarantee.

Prior downloadable versions remain under downloads; the initial DOJ-only version remains on main. Runtime recordings are private server files and must be backed up together with the database.

Personal citizen bank balance: current online / saved offline, visible only to Police/DOJ managers. [Small update for an existing v3 install](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_business_bank_3.0.2.zip).

DOJ managers can inspect company balances/history from Businesses → Bank account. [Details](BUSINESS_FINANCE.md).
