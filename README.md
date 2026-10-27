# Crimson MDT 3.0.1 beta — Qbox

[Download complete pack](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_qbox_pack_3.0.1.zip) · [Crimson resource only](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_doj_3.0.1.zip)

[التركيب بالدارجة](INSTALL_AR.md) · [English setup, permissions and limits](INSTALL_CRIMSON.md) · [Feature status](crimson_doj/FEATURES.md)

Independent Police/DOJ/EMS/Business MDT with Crimson branding. v3 adds physical document printing/items, recipient-confirmed bank payments, case-linked fines and prison actions, local bodycam capture and private playback. Includes source, schema and tests. No XR-MDT escrow files or old Cfx entitlement are required; this is its own implementation, not full/exact XR-MDT parity.

The companion pack contains official Renewed-Banking, qbx_prison, screencapture and ox_target releases/source with original attribution/licenses and source archives. Your existing Qbox/ox_lib/oxmysql/ox_inventory base is still required. Import the bank SQL and register the document item before live use. Do not overwrite existing customized dependencies blindly.

**Beta:** tests here include mocked Qbox/provider workflows, real filesystem/transfer code, actual MariaDB schema/migration checks and real Chromium/WebM rendering. Actual FiveM natives/providers were not executed here. Complete the staged in-game acceptance checks before regular use. Bodycam video is experimental and has no audio with the selected provider. Cross-provider money operations have a durable needs-review path rather than a false atomicity guarantee.

Prior downloadable versions remain under downloads; the initial DOJ-only version remains on main. Runtime recordings are private server files and must be backed up together with the database.

Personal citizen bank balance: current online / saved offline, visible only to Police/DOJ managers. [Small update for an existing v3 install](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/crimson_bank_balance_3.0.1.zip).
