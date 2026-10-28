# Crimson 3.1.0 — DOJ ranks, sounds and legal-unit map markers

Back up the resource/config, recordings and database. Overwrite using the COMPLETE crimson_doj_3.1.0.zip, including fxmanifest.lua, permissions.lua, server_blips.lua and client_blips.lua. Preserve your local bank and printer settings. No SQL migration or inventory-item changes. Keep the working lb-phone Apex patch and existing origen_police/ox_target resources. Restart crimson_doj after deployment.

## Job access and exact DOJ grades

permissions.lua contains the supplied 0–14 DOJ grade table, preserving every boolean and label, including non-monotonic grants. Config.MDTJobs defaults to doj/police/sheriff/ambulance; mechanics and burgershot cannot bootstrap or request records even if an older Config.Jobs still contains them. Business registry/balance inspection remains available. Existing police/EMS grade thresholds remain intact. Primary job/duty changes close stale MDT information immediately.

DOJ report creation starts at grade 1, warrant creation at 4, vehicle editing at 5. Employee management is ONLY grades 6,9,13,14. Warrant status/revocation is ONLY 7,10,11,12,13,14 (8 and 9 do not inherit 7). Business management and code changes are ONLY 13,14. Undefined DOJ ranks are denied. UI controls and server requests both enforce the rules. The existing grade-3 global management shortcut no longer applies to DOJ.

Module mapping: case/incident/document/recording use reports_view/create/delete; private notes use profiles_view/edit; vehicle flags/weapon records use vehicles_view/edit; business licenses/notes use business_view/manage. Citizen bank inspection follows profiles_view; company bank inspection follows business_view. Fine/jail/release follows convictions_create. The source citizen identity remains Qbox-owned: profiles_edit does not rewrite legal names, birth dates or money. Private-note isolation remains mandatory. Report/warrant delete permissions map to archive/revoke/status operations in this resource, not physical removal of database evidence. Editing another author's record with status-only authority preserves its narrative/details.

The rank labels/permissions are MDT configuration, not a mutation of qbx_core jobs. Your Qbox DOJ job must contain the numeric grades you intend to assign. Keep existing payroll/job settings; no job salaries are invented by this release.

## Your audio files

Put your own files into crimson_doj/web/sounds/:
- open.ogg: successful MDT opening
- close.ogg: MDT closing
- click.ogg: UI buttons while open
- notification.ogg: saved records and badge presentation

Config.Sounds controls enabled, volume (0–1) and each filename. Real .mp3/.wav files also work by changing the corresponding filename; renaming a file extension does not convert audio. Only local simple filenames are accepted; external URLs/path traversal are refused. Missing audio never blocks record access. No XR sounds are shipped. Defaults fill these settings when retaining an older config.

## DOJ / Origen map markers

Config.JobBlips enables server-generated positions for on-duty doj/police/sheriff. DOJ sees other DOJ units plus police/sheriff. Police/sheriff receive DOJ units only; their existing police-to-police/sheriff markers remain owned by origen_police, avoiding duplicate police markers. This is an independent map overlay, not an Origen dispatch or roster API modification. No Origen code changes are needed. Match the actual job resource keys if your server uses different names.

Positions are sampled every three seconds, restricted by routing bucket and legal job/duty. Civilian/business clients receive no location feed. Job/duty/disconnect changes remove markers; client timeout clears stale markers after 15 seconds, and shutdown removes owned handles. Config.JobBlips controls jobs, interval, sprite, colour, scale and enabled. Police and DOJ must be on duty and in the same routing bucket to see one another.

## Validation and limits

Lua/JS syntax and the full local suite passed: 254 server authorization checks including all 15 ranks, 75 DOM checks including explicit employee/business controls and sound paths, existing financial/media/client tests, and new map audience/duty/bucket/lifecycle checks. Native FiveM sound, map appearance and actual Origen coexistence still require a live test with two players. No live database, balances, other resources or external messages were touched.
