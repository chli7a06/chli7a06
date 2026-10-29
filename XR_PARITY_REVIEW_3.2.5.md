# XR-MDT / Crimson 3.2.5 feature comparison

Result: the main DOJ sections are present, but Crimson is NOT a full functional replica of XR-MDT. Matching menu names do not establish matching workflows. This is a static comparison of the uploaded reference's readable configuration, editable integrations, SQL schema and locale/UI labels with current independent Crimson source. The licensed XR server runtime was not executed or decrypted; labels alone establish an advertised surface, not proven live behavior. Current FiveM acceptance remains separate from implementation availability.

## DOJ and common workflows

| Option | Crimson 3.2.5 | Practical difference / remaining work |
|---|---|---|
| Dashboard | Partial | Counts, recent activity, threat codes and unit status. No arrest/report employee rankings or full wanted-person/vehicle dashboard. |
| Citizen name / ID search | Present | Native Qbox identity lookup with scoped records. |
| Complete citizen profile | Partial | Name, birth date, nationality, personal bank balance and records. No mugshot editor, phone display, standalone wanted flag or dedicated license/conviction tabs. profiles_edit does not change Qbox identity fields. |
| Personal bank balance | Present | Qbox live online / saved offline. DOJ follows profiles_view; missing values are not invented. |
| Citizen wanted status | Partial | Warrants are records; no dedicated profile wanted flag/banner synchronized to other police systems. |
| Case / incident records | Partial | One subject, narrative, text evidence and charges. No structured multiple suspects/officers/vehicles, photo gallery or per-case linked notes like the reference integration exposes. |
| Warrants | Partial | Create/view/status/archive with rank permissions. No automatic expiry enforcement or dedicated wanted-system synchronization. |
| Structured convictions | Missing | Fine/prison actions exist; full persistent offense/charge/sentence history UI is not equivalent to the reference lspd_convictions workflow. |
| Citizen driving / weapon licenses | Missing | No grant/revoke of native player license metadata. Business licenses are a different feature. |
| Vehicle search | Partial | Plate, owner ID, model; flag records. No dedicated photo/wanted profile with integrated tags and note history. |
| Weapon records | Partial | Serial/model/citizen registry. No guarantee of automatic inventory weapon registration/synchronization. |
| Fine / prison / release | Present with providers | Case-linked nearby legal actions, Qbox debit, configured company bank credit, qbx_prison. No automatic debt collection; provider setup and live tests required. |
| Penal code | Partial | Read-only configured law table. Default Config.PenalCode is EMPTY; charges are text rather than a full offense-picker/sentence calculator. |
| Documents | Partial | Text, category, hosted raster image and revision. No rich HTML/page builder, multi-slot signatures or bundled legal templates/reference viewer. |
| Image document printing | Present | ox_target printer, item snapshot, possession-verified reader and pending-only printer queue. Hosted URL is frozen, not external image bytes. |
| Physical document archive | Missing | MDT archive listing exists, but no dedicated archive location with inventory deposit/retrieve and signature workflows from the reference schema/locale. |
| Private notepad | Present | Author-isolated notes with search and persistent records. |
| Employees | Partial | Qbox memberships, grade changes, removal and online/duty status. No persistent duty-time totals, suspend/unsuspend, employee notes or original-style employee badge-number management. |
| Chief-issued DOJ ID item | Present | Custom display name, bound credential, exact /e idcard, Backspace and nearby presentation. This is a custom Crimson workflow, not proof of XR employee-badge parity. |
| Rank permissions | Present with requested overrides | Supplied DOJ grades 0–14. Management >=10; Vehicle search / Businesses / Units accessible outside that gate as requested. |
| Businesses registry | Partial | Configured jobs, license/note records and account inspection. No complete business owner/employee detail tabs, custom logo or legal/suspicious status editor. |
| Business bank balance / history | Present | Apex / Renewed / qb-banking adapters with different capabilities. Apex is the deployed selection; phone company bridge was patched separately. The generic custom-read adapter has no write integration; qb-management has no built-in adapter in this release. |
| All businesses configured | Missing setup | Defaults list only mechanic and burgershot. The uploaded reference lists many more jobs, including mm3_mecano, pharmacy, casino, etc. Actual server job keys must be configured explicitly. |
| Business licenses | Partial | Grant/status/expiry metadata; no timed automatic revocation. |
| Units & opt-in GPS | Present | Duty/status directory and server-authorized opt-in location waypoint. |
| DOJ ↔ police/sheriff map blips | Present | Independent same-bucket on-duty feed. Police-to-police markers stay with origen_police. Not an Origen dispatch/roster database integration. |
| Tracking bands | Missing | No ankle-band item, tracked-subject database, removal/minigame or suspect monitoring. |
| Fixed cameras | Present with setup | Allowlisted native security camera definitions; current defaults cover one Mission Row camera. Not every camera from the original map/config. |
| Bodycam | Partial | Self-recorded timed WebM, storage/playback/delete, provider dependency. No audio, live viewing of another officer's feed or complete equipable bodycam/HUD customization workflow. |
| Manual dispatch | Partial | Manual call records, priority, captured position and waypoint. No automatic incident adapters, responding-unit assignment or direct Origen dispatch integration. DOJ currently has no dispatch module in the default module definition. |
| Armory | Partial | Configured radio kit, location/grade/cooldown checks and rollback. No shared stock, cart/catalog UI, equipment returns or per-user kit editor. |
| Audit logs | Partial | Scoped actions and versioning. Ordinary writes/audit are not all transactional; no full configurable external webhook integration. |
| Statistics / duty leaderboard | Missing | No equivalent full statistics module. |
| Helicopter spawning / air-unit module | Missing | Reference config/locale exposes this surface; no Crimson equivalent. |
| Localization | Partial | UI primarily English; no full reference locale set. |
| UI sounds / tablet animation | Present with setup | Own audio files must be supplied in web/sounds; configuration alone does not contain sounds. Tablet and badge actions use current configured/native handlers. |

## Scope intentionally changed by user request

- Mechanic/burgershot cannot enter MDT. The reference exposes a business MDT, and legacy business invoice/product code remains in Crimson, but it is not accessible under the default current whitelist. This is deliberate, not full business-module parity.
- Management is grade 10+, with specific rank grants still enforced. Earlier grade 6/9 employee grants do not bypass that gate.
- No direct Print inventory copy button. Physical printing uses ox_target, and printed records leave the printer queue while staying in MDT.
- /dojbadge self-issuance is removed. Chiefs issue named database-bound credentials.

## Readable evidence examined

Reference: configs/config.doj.lua (documents, grade grants, businesses); configs/config.main.lua (archives, bodycam, tracking, heli); configs/config.armory.lua; configs/locales/en.lua (DOJ dashboards, employees, business detail tabs, signatures/archive, armory controls); editable/server/doj.lua (citizen mugshots/phone, multi-entity incidents, galleries, vehicle details, citizen notes/wanted/convictions/licenses); editable/server/lspd.lua; editable/server/sv_items.lua; INSTALL/database_qb.sql (structured incident participants, convictions/licenses, tracking, stock/kits and archive tables).

Crimson: server.lua, server_extras.lua, server_banking.lua, permissions.lua, server_badge.lua, client_badge.lua, server_blips.lua, client_blips.lua, web/app.js, schema.sql and config.lua at version 3.2.5. No protected XR implementation was copied or bypassed.

## Suggested completion order

1. Complete citizen/vehicle profiles and structured cases with multiple participants/evidence images.
2. Add actual citizen license management, structured convictions and penal-code data/selection.
3. Extend employee records with duty time, notes and suspension; expand business details and actual server job list.
4. Add signature-capable documents and physical archive deposit/retrieval.
5. Add armory stock/returns, tracking bands and verified dispatch/bodycam integrations if those are still wanted.

No missing feature is enabled just by adding a sidebar label or setting an integration boolean. Each needs independent implementation and in-server acceptance. This review makes no changes to the resource runtime.
