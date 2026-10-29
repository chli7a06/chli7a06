# Crimson 3.2.3 — badge recipient identification

The badge form now has Use my citizen ID, filling the current server-issued session identity/name. Self-issuance resolves the issuer directly rather than depending on the separate online citizen lookup. Other recipient IDs are trimmed, checked against the exact online lookup (with uppercase fallback), and stored under the canonical character ID. Player sources are converted to numbers before native calls. Errors now distinguish offline/unknown citizen IDs, missing primary DOJ/on-duty status and proximity/routing bucket mismatch. Chief grade, ownership binding and post-SQL identity checks remain enforced.

Back up the resource/config and overlay the complete ZIP. Restart crimson_doj, open Employees → Issue DOJ badge, and use Use my citizen ID for your own credential. For another recipient, copy their actual citizen ID from Citizens. No new SQL or inventory-item changes. Existing registered credentials remain valid. Exact /e idcard and pending-only printer queue from 3.2.2 are retained.

Validation: complete local suite passed, including recipient whitespace/canonical lookup, self-issuance, distinct missing-ID errors and actual-ID form autofill. Actual user server state remains unobserved; the previous combined message alone did not prove which prerequisite failed.
