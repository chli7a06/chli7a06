# Crimson MDT 2.0 — multi-department preview

[Download preview ZIP](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/crimson_doj.zip)

Independent Qbox implementation with freshly written server/client, UI and SQL. The only reused asset is the supplied Crimson logo. No XR-MDT escrow files, entitlement or QB compatibility bridge are required.

Department-aware Police / DOJ / EMS / Business workflow: scoped records and citizen profiles, cases/warrants/incidents, patient reports, documents/private notes/archive, Qbox staff membership management, vehicle search/flags, weapon register, business licenses, company catalogs and computed invoices, manual dispatch, opt-in unit GPS, audit, and configurable native cameras/ox_inventory armory.

**This is a preview, not full XR-MDT feature parity.** Payment/banking, jail/fines, actual bodycam capture, physical document/signature workflows, and automatic dispatch still need implementation/integration. No live FiveM/Qbox/MySQL validation was available. See the [feature comparison](crimson_doj/FEATURES.md) and [installation, permissions, migration, tests and limits](INSTALL_CRIMSON.md).

The working initial DOJ-only release remains on [main](https://github.com/chli7a06/chli7a06/tree/main). Back up both resource and database before testing this preview; the one-time migration copies old Crimson DOJ records without deleting their table.

Local checks: 62 server assertions with mocked Qbox/MySQL, 49 DOM interaction checks, Lua/JavaScript syntax. These do not replace live server acceptance tests.

## Mission Row configuration

The current preview ZIP enables Mission Row cameras and a one-radio ox_inventory kit for DOJ/Police/Sheriff. [Setup and exact locations](MISSION_ROW.md). [Download config.lua](https://github.com/chli7a06/chli7a06/raw/refs/heads/multi-department-preview/downloads/config.lua).

## 2.0.1 screen transparency fix

Removed document-level dark color scheme and explicitly kept HTML/body transparent while the tablet is hidden. Form controls retain their own dark styling. Added `/mdtclose` (F8: `mdtclose`) to release this resource's NUI focus and owned camera even if the page cannot respond. Resource stop also runs the same cleanup. Added 7 transparency/camera-message DOM assertions and 14 client lifecycle assertions with mocked FiveM natives. All local checks pass; a Chromium screenshot attempt timed out, and actual FiveM/CEF transparency must still be confirmed in-game.
