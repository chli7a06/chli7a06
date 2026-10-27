# Crimson MDT 3.0.0 beta — independent Qbox resource

New Lua, JavaScript, NUI and SQL written for Crimson. No XR-MDT code, escrow files or old entitlement is needed. Only the supplied Crimson logo is reused. This is an independent implementation with its own workflow, not exact feature/visual parity with XR-MDT.

## Runtime prerequisites
Existing Qbox base: qbx_core, ox_lib, oxmysql, ox_inventory. Selected add-ons: Renewed-Banking 2.1.4, qbx_prison 1.0.0, screencapture 0.17.2 and ox_target 1.18.1. A companion pack includes official add-on distributions and their licenses/source archives. Do not overwrite existing customized resources blindly. Node 22 support in current FXServer artifacts is required by the media resource.

See INSTALL/START_HERE_AR.md for installation. No external API key or paid upload service is used. Configure your actual Qbox job names and grade thresholds, merge the inventory item, import the bank SQL, and start dependencies before crimson_doj. Run the console-only `crimsoncheck` command afterwards.

## Implemented workflows
- Department-aware Police/DOJ, EMS, and per-company Business MDT; duty, grade and server-side scope checks.
- Citizen search/profiles; cases, incidents, warrants, evidence/charge text; separate medical reports.
- Staff roster and native Qbox job membership management; self/equal/higher-grade protection.
- Registered vehicle lookup/flags; serial/model weapon registry; configured business licenses/notes.
- Service/product catalog, server-calculated invoices, recipient-confirmed bank payment offers.
- Actual native Qbox bank debits and Renewed-Banking job-account credits; society balance/history and a durable payment journal.
- Manager-only, nearby/same-routing-bucket fines and qbx_prison sentence/release actions linked to a case/incident. Default limits: $100,000 fine, 120 minutes; adjust Config.Law for your RP rules.
- Saved documents, author-private notes, paging/archives, department audit and security code.
- A physical Mission Row printer. Printed copies are immutable database snapshots in transferable ox_inventory items. A holder can read a copy without accessing the MDT/source department. Every read verifies actual server-side possession of the item and its copy ticket.
- Manual dispatch, server-captured call position, units/status, consent-based unit GPS, configurable native fixed cameras, whitelisted proximity/grade/cooldown-checked ox_inventory kits.
- Explicitly self-started, timed bodycam video capture through screencapture. On-screen REC indicator and /bodycamstop. A staff member can stop their own capture after a job/duty change. Private local video storage; department-authorized playback with bounded chunk transfer; manager deletion/retention controls.
- Transparent closed NUI, owned-camera/focus cleanup, /mdtclose recovery and stale-response cancellation.

## Printing setup
Merge the entry from INSTALL/ox_inventory-items.lua into ox_inventory/data/items.lua, inside its returned table. Do not replace your full inventory file. The item is `crimson_document`, consume=0, non-stackable, with client export crimson_doj.useDocument. Restart ox_inventory after changing items.

Default printer: Mission Row (441.4,-982.2,30.7), radius 2 metres, DOJ/Police/Sheriff. Adjust positions/allowlists for your MLO or add separate EMS/Business printers. At the printer, press E and choose a saved document, or view a document in MDT and select Print inventory copy. The item goes to the printer user's inventory; normal ox_inventory transfer can hand it to someone else. Source edits never alter an already printed copy. Reading requires no source MDT permissions, so print/share sensitive documents intentionally.

## Payments and interrupted operations
Invoices do not charge on creation. Send a payment request; the addressed online recipient confirms through ox_lib. Values are re-read server-side; client amounts are ignored. Negative/oversized amounts, missing accounts and insufficient bank balance are rejected. Financial calls use the citizen ID rather than a potentially reused server ID. Destination account derives from the company's server-side scope.

One settlement per invoice/case is recorded and guarded against duplicate submission. A known credit refusal attempts a native Qbox refund. Exceptions/ambiguous provider outcomes and interrupted operations become needs_review, with no automatic replay or blind refund. Money movement across Qbox/Renewed-Banking cannot be part of one SQL transaction; this limitation is explicitly handled, not claimed atomic.

Review the Payments log and both providers. ONLY after verifying actual balances/transactions, the server console may resolve accounting metadata:

`crimsonresolve <record-id> <paid|refunded|failed> <verified reason>`

This command accepts only needs_review entries and moves no funds. It is not available through NUI or game clients. Already settled/refunded/failed invoices are not charged again; archive an obsolete invoice and create a replacement only after reconciliation. Bank history integration is best-effort; the MDT payment journal is authoritative for this resource's operation state, not a replacement for checking provider balances.

General record mutation and audit insertion remain separate operations; an audit failure can leave a saved ordinary record without its audit entry, and a failed create retry can duplicate an ordinary record. This is not a tamper-proof evidentiary archive.

## Prison behavior
Install qbx_prison and its inventory prerequisites. Both officer and target must be online, nearby and in the same routing bucket. Only configured legal managers can use legal actions. The target is the case/incident subject, never an arbitrary client-supplied player ID. Self-actions, out-of-range amounts/time and duplicate sentence execution for a case are rejected. Interrupted custody operations are not automatically retried.

The selected qbx_prison default confiscates inventory and may reset the prisoner's primary job to unemployed; release returns inventory through that provider. Review its settings/source for your server. This adapter does not silently rewrite those defaults. Fines/prison terms are administrator-configured RP actions, not a bundled legal code.

## Bodycam and video storage
Use Recording library → Record my bodycam. It records YOUR gameplay only, not another player's machine. Closing the tablet does not stop a capture; /bodycamstop does. Current provider records WebM video without microphone/game audio; its video API is experimental and needs live FiveM/CEF validation. Default duration 30 seconds at up to 1280×720, max 15 MiB per clip, max 200 stored clips globally. No remote upload endpoint or key is used.

Clips are moved from screencapture/tmp into crimson_doj/recordings, which is not included in the client manifest. Rooted path/extension/signature/size checks reject invalid files. Playback rechecks the viewer's department before bounded server-to-client transfer; maximum 4 concurrent transfers. Client cancel/disconnect releases transfers. Screenshots/video are self-reported gameplay captures, not attested evidence. Back up recordings together with the database; do not delete this directory during updates. Provider failures may still require checking its temporary folder.

## Upgrade and persistence
Use the new config.lua or merge new fields using defaults.lua/installation notes; blindly preserving an old config can leave providers/printers disabled. Preserve your actual Jobs/grades/MLO positions. New schema tables create automatically (CREATE permission required on first start). Original Crimson DOJ 1.0 records copy once transactionally into the justice scope with IDs preserved; old source tables stay intact. Original XR-MDT databases are not migrated. Old audit history remains in its original table. v3 records do not sync back into v1.

Police/DOJ share justice records; EMS medical records and different companies are isolated. Private notes remain author-only even for managers. Lists page 30; citizen search max 40; profiles latest 200 records; employee roster max 200. Dates on warrants/licenses are stored references and do not enforce gameplay expiry automatically. No hard deletion of ordinary records; manager video deletion removes the clip and archives its record.

## Validation and remaining live checks
Local tests exercise permissions/isolation, printing possession/snapshots, payment consent and exact amounts, duplicate prevention, credit refusal/refund, ambiguous provider outcomes, prison bounds/proximity, recording lifecycle, private file paths/size checks, actual Node file/stream bytes, UI forms and close/cancel races. A real MariaDB container validates actual schema/migration/JSON update statements. Real Chromium renders the UI, verifies transparency and decodes a WebM clip transferred through the NUI message handler.

No FiveM engine was available here: native Qbox/ox_inventory/provider actions remain mocked in automated tests. Provider installation, world positions, actual camera views, item use/transfer, actual capture/stream performance, and end-to-end money/prison behavior MUST be tested on a backed-up staging server. These local checks are not a claim that every original XR-MDT feature or every live integration works.
