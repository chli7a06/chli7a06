# Crimson DOJ 1.0 — independent Qbox resource

All Lua, HTML, JavaScript, CSS and SQL in this folder are newly authored. Only the user-supplied Crimson logo is reused. No XR-MDT code, encrypted files, .fxap metadata, license-check bypass, WaveShield include, or QB compatibility bridge is included or required.

## Included workflow
- Qbox server-side job, grade and duty authorization on every request.
- Dashboard counts; search existing Qbox citizens by name or citizen ID.
- Citizen profiles and linked cases, warrants and documents.
- Create and edit records, management-only warrant creation and status changes.
- Version checks prevent silently overwriting a concurrent edit.
- Persistent SQL records and audit entries, with management-only audit view.
- Crimson logo, red/charcoal NUI, /dojmdt command and remappable F12 key.
- Read-only character lookup: no balance, job, inventory, jail or license mutations.

## Install
1. Back up your server/database. Stop the previous crimson_doj/xr-mdt to avoid conflicts.
2. Extract this crimson_doj folder into your server resources.
3. Requires qbx_core, ox_lib and oxmysql. Ensure they are configured and start first.
4. Edit config.lua to match your actual Qbox job and grade levels. Defaults: doj read/write grade 0; manage grade 14. RequireDuty=true means the character must be on duty. If your top grade is lower, explicitly adjust manage. Ordinary writers can edit only their own non-warrant records, without changing status.
5. Tables crimson_doj_records and crimson_doj_audit are automatically created on start. The database account needs CREATE TABLE permission the first time; alternatively import schema.sql using an administrator. This does not migrate or delete XR-MDT tables.
6. Add `ensure crimson_doj` after its dependencies in server.cfg.
7. Log in with a configured DOJ character, go on duty, and run /dojmdt or F12. If F12 has an old saved binding, change it in FiveM key bindings.
8. Test unauthorized jobs and off-duty characters are rejected; test a writer and a manager separately; search a citizen; create/edit/close a case and warrant; reconnect and confirm persistence. Inspect server and F8 logs.

## Scope and limitations
This is a new initial DOJ implementation, not feature parity with XR-MDT. It does not include dispatch, GPS/map tracking, bodycams, armory, EMS/business tablets, employee management, fines, jail integration, uploads, document signing, PDF export or old-data migration. No map.webp is needed. Records are plaintext legal notes, not automatic gameplay enforcement. There is no delete operation: managers close/revoke records. Lists show latest 100 records, profiles latest 200, searches up to 40 matches; full pagination is not implemented.

Validation: JavaScript and Lua syntax; 19 server tests with mocked Qbox/database cover job/duty/grade denial, unauthorized edits, malformed inputs and stale versions. DOM interaction checks in jsdom with mocked NUI responses passed for opening, counts, search, profiles, safe text rendering, creation form and closing. Chromium execution hung and did not complete; no real-browser visual validation is claimed. No live FiveM/Qbox/MySQL instance was available, so actual runtime compatibility, SQL execution and persistence still require the installation checks above. A successful mocked test is not proof that the resource works in your server.

Audit insertion and record mutation are separate SQL calls; a database failure between them can leave a record without its audit entry. Back up your database and avoid treating this initial audit log as a tamper-proof legal archive.
