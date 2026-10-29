# Crimson / supplied Origen bridge

Install only `crimson_bridge.lua` at `origen_police/custom/server/menu/crimson_bridge.lua`. The supplied Origen manifest includes that glob. Restart Origen and Crimson after installation. No protected runtime or original HTML is replaced or redistributed.

Verified against the uploaded readable `custom/client/commands.lua`, `custom/client/rpol.lua`, `custom/server/menu/licenses.lua` and `fxmanifest.lua`:

- Imports client `SendAlert:police` into Crimson dispatch, bounded and rate limited, with server-captured source position. Leaves Origen's original handler intact.
- Clears Origen `cachedLicenses[citizenid]` after Crimson changes native Qbox `metadata.licences`.
- Requires started crimson_doj and the configured DispatchSources allowlist. Keep the invoking resource named origen_police, or change the allowlist deliberately.

This is one-way alert import, not shared assignments, evidence, roster, wanted flags or incident tables. Supplied AddLicense/RemoveLicense and vehicle key helpers were empty placeholders; they are not called as working integrations. The private HTML bodycam callback is not used as a public API. Crimson legal blips remain independently scoped and do not duplicate Origen police-to-police markers.
