# Crimson MDT 2.0 — multi-department preview

Newly authored Qbox server/client, NUI and schema. Inspired by the requested multi-job workflow; this is not XR-MDT source conversion, an escrow unlock, or complete feature parity. Only the supplied Crimson logo is reused. No old Cfx entitlement, qb-core or compatibility bridge is required.

## Installation / upgrade from Crimson DOJ 1.0
1. Back up both the resource and the full database. Keep a copy of your current config.lua.
2. Stop the existing crimson_doj and any duplicate MDT resource before replacing its files. Use the crimson_doj folder in the ZIP, not an extra nested folder.
3. Start oxmysql, ox_lib and qbx_core first; then `ensure crimson_doj`. This preview uses native Qbox exports and current Qbox player_groups membership storage. Vehicle search assumes player_vehicles(plate,citizenid,vehicle).
4. Set Config.Jobs to your actual job names/grades. Defaults include doj, police, sheriff, ambulance, mechanic and burgershot. This resource does not create those Qbox jobs. For example, the existing DOJ setup with Judge grade 3 matches the default doj management grade. Do not copy a grade threshold blindly for other jobs.
5. New tables are automatically created on first start using schema.sql. An account with CREATE TABLE permission is needed then. Existing Crimson DOJ 1.0 records are copied once, transactionally, with IDs preserved, into the justice scope. The old crimson_doj_records table is retained unchanged. This is not a migration of XR-MDT's database. Old audit history remains in the old table and is not imported.
6. If initialization fails, read the console before retrying. Do not delete source data. If v2 tables already contain entries but the v1 migration marker is absent, restore/reconcile a backup instead of forcing conflicting IDs.
7. Open `/dojmdt` or F12. The tablet selects the department from the character's current primary Qbox job. Off-duty staff can open the clock-in screen but cannot read operational records.
8. Review FEATURES.md and complete the live acceptance checks below before using this preview for regular gameplay.

## Department permissions
- Police and DOJ share the justice records scope; each still has a server-enforced module allowlist.
- EMS medical records live in a separate medical scope and are inaccessible to Police/DOJ/Business.
- Businesses are partitioned by job name; one company cannot access another's invoices/catalog/documents.
- Private notes are additionally restricted to their author, including against managers.
- Read/write/manage grade thresholds are enforced on every server request. Writers edit their own records; managers edit department records. Issuing warrants, licenses, catalog management, rank changes, threat changes and audit reads require management permissions.
- Managers cannot alter themselves or equal/higher ranks, or appoint another member to a grade at/above theirs. Job membership changes use native Qbox AddPlayerToJob/RemovePlayerFromJob, not direct SQL job writes.
- GPS location is shared only while a member is on duty and has explicitly opted in. Stop sharing before leaving duty if desired; dropping clears GPS state. Locate gives a current waypoint, not continuous map tracking.

## Cameras and optional ox_inventory armory
Only these two integrations have implemented providers in this preview. Do not enable other integration booleans expecting an implementation.

Cameras: set Config.Integrations.cameras=true and add server-defined entries to Config.Cameras. Each camera must have an explicit jobs allowlist, for example:

```lua
Config.Cameras = {
 {label='Mission Row entrance', jobs={police=true}, x=440.0,y=-981.0,z=35.0,rx=-20.0,ry=0.0,rz=90.0,fov=60},
}
```

These sample coordinates must be adjusted to your actual map. The client receives only authorized camera definitions; Esc returns from the native camera view. This is a fixed security camera, not video recording.

Armory: requires an installed ox_inventory with valid items. Set Config.Integrations.inventory='ox_inventory' and explicitly configure locations/kits. Example (change location, grade and items first):

```lua
Config.Armory = {
 police={coords={x=450.0,y=-980.0,z=30.0}, radius=3.0, kits={
  {label='Radio kit',grade=1,cooldown=1800,items={{name='radio',count=1}}},
 }},
}
```

Collection verifies the current job/duty/grade, server position, kit whitelist and per-citizen kit cooldown. Issued items carry issue metadata; failed multi-item collection attempts roll back issued items. There is no return/reclaim operation or shared stock system yet. Native cameras, GPS, armory and job mutation still require live server tests.

## Business invoices and integration gaps
Invoices are persistent catalog-based records. Product prices and quantities are validated and totals calculated server-side; client-supplied totals are ignored. They remain unpaid and never move money. There is no payment callback, bank/society balance integration or debt collection in this preview. Closing an invoice does not mean payment.

Jail/fines, society banking/payments, actual bodycam capture/streaming, built-in police-call automation and inventory features beyond the explicit armory provider are not implemented. A recording entry stores an HTTPS reference; it does not capture video. To implement the missing providers, supply the installed resource names and versions (names only; do not share secrets). No generic client-provided export/event names are executed.

Supply your own RP penal code in Config.PenalCode; the empty reference is intentional. No laws, fines or jail terms are invented. No original 43 MB map file is needed for this interface; it does not include the original interactive map.

## Persistence and audit limits
Records use optimistic version checks for concurrent edits. Archives filter closed/revoked/archived states on the server. There are no hard deletes. Audit insertion and each record mutation are currently separate SQL operations; a database failure between them can leave a mutation without an audit entry, and retrying a failed create can duplicate a record. This is not a tamper-proof legal archive or financial ledger. Legacy tables are retained for rollback, but new v2 records do not automatically sync back to v1.

Lists/audits page 30 records; citizen search returns at most 40 matches; citizen profiles show latest 200 linked records; employee roster shows at most 200 members. Search matching is literal and values are parameterized. Private/internal errors are not returned to NUI. Text is rendered using textContent; arbitrary record HTML is not executed.

## Verified here
- Lua/JavaScript syntax.
- 62 server checks using mocked Qbox/MySQL: authorization, department/company partitioning, private notes, input checks, stale edits, hierarchy restrictions, GPS consent, camera allowlists, armory location/cooldown, transactional legacy migration setup, and internal error filtering.
- 49 jsdom interaction checks: DOJ/EMS/Business navigation, counts, citizen search/profile, safe text rendering, create/edit dialog, archive filtering, employee form, roster, audit, integration states, duty and closing.
- Native Qbox export signatures were checked against upstream qbx_core commit 58b345e2b53be98928c3e4ee44b100613ac9257f.
- No live FiveM/Qbox/MySQL was available here. SQL execution, native camera/GPS/armory behavior, group changes and persistence in your server remain unverified. DOM tests are not a real CEF visual test.

Development tests (outside the resource): Node.js 24+, `npm ci --prefix tests`, then `npm test --prefix tests` from the repository root. Runtime requires no npm install.

## Live acceptance checks
Test first on a backed-up staging server: unauthorized job denial; off-duty denial; DOJ/Police shared legal access; EMS medical isolation; separate company isolation; private-note isolation; citizen searches; create/edit/archive/reload/restart persistence; legacy record counts/IDs; concurrent edits; staff rank hierarchy; GPS opt-in/out; configured camera permissions; armory location, grade, capacity and cooldown. Inspect F8 and server console. Do not assume the local mocked checks cover these native behaviors.

## 2.0.1 screen transparency fix

Removed document-level dark color scheme and explicitly kept HTML/body transparent while the tablet is hidden. Form controls retain their own dark styling. Added `/mdtclose` (F8: `mdtclose`) to release this resource's NUI focus and owned camera even if the page cannot respond. Resource stop also runs the same cleanup. Added 7 transparency/camera-message DOM assertions and 14 client lifecycle assertions with mocked FiveM natives. All local checks pass; a Chromium screenshot attempt timed out, and actual FiveM/CEF transparency must still be confirmed in-game.
