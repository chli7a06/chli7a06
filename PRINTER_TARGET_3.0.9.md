# Printer ox_target interaction — 3.0.9

The printer uses an invisible ox_target sphere at each Config.Printers coordinate. The old red DrawMarker and Press E help prompt have been removed. Debug/sprite drawing is disabled. Use your configured ox_target key (usually Left Alt), aim at the printer location, and choose Use Crimson printer. Existing saved-document selection and physical inventory copies remain.

Printer zone visibility uses the configured job allowlist; server-side permission, duty/write, printer identity, proximity, item issuance and cooldown checks are unchanged. Zones are removed on resource shutdown and rebuilt on ox_target restart. ox_target is now an explicit resource dependency. Keep your existing ox_target installation.

Back up config/recordings, overwrite with the complete resource ZIP and preserve your local printer coordinates and bank configuration. No SQL or inventory-item changes. Ensure ox_target is running, then restart crimson_doj. There is no fallback to E/markers. Printer targets stay at the existing location; no printer prop is spawned.

Validation: Lua/JS syntax and the full local suite passed. Additional mocked client checks cover invisible zone definitions, job groups, document selection, correct printer indices, restart replacement, stop cleanup, and target unavailability. Actual targeting and map positions require a live FiveM check.
