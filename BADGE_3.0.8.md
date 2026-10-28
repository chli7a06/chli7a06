# Badge display compatibility — 3.0.8

The badge renderer is now bundled in the main app.js, so it does not depend on an additional script entry being present in a retained HTML/manifest. The standalone copy has an idempotent guard. Existing display stays non-interactive for eight seconds; it works with the MDT closed. Server audience stays the owner plus players within three metres in the same routing bucket. Ownership/job/duty validation stays enabled. Obtain your bound item using /dojbadge; unbound giveitem copies are not valid credentials.

Back up config/recordings and overwrite with the complete resource ZIP. No SQL or item-definition changes. Retain Apex banking selection. Do not replace the directory with only a UI file. Restart crimson_doj, issue your badge on duty, then use the issued item.

Validation: full local suite passed, including five additional UI checks for visibility while MDT is closed, server identity, CSS visibility, injection-safe rendering and single-card rendering. Existing mocked server checks verify owner and nearby same-bucket recipient delivery. Actual FiveM inventory/CEF and a second connected player need live acceptance. This addresses a possible missing-script cause; no claim is made that the screenshot identified the exact local installation state.
