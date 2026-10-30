> Historical 4.0 audit. Version 4.1 adds French UI, a configured helicopter fleet, observed weapon serial search and persistent camera management. Read crimson_doj/INSTALL/UPGRADE_4_1_AR.md and FEATURES.md for current status; the remaining-boundaries paragraph below describes 4.0.

# Independent Crimson 4.0 preview — completion audit

This supersedes the 3.2.5 implementation status, while retaining that document as the original source comparison. No escrow runtime was decrypted or copied. The uploaded Origen readable integrations were examined; full protected Origen internals remain outside this integration.

| Previous gap | Current implementation and boundary |
|---|---|
| Citizen/vehicle profile | Scoped mugshot/photo, wanted reason, native phone/licenses, editable annotations and append-only note history. Legal identity fields are not rewritten. |
| Structured cases | Validated participants with suspect/officer/victim/witness roles, registered plates and image URLs, plus notes and optimistic version conflicts. External physical evidence inventories are not synchronized. |
| Convictions/penal picker | 309 unique offenses from readable supplied config, authoritative fine/month calculation, persistent legal history and optional subject-matched case. Enforcement remains a separate case legal action. |
| Citizen licenses | Online Qbox SetMetaData and offline JSON merge. Origen cache invalidation bridge; empty vendor export stubs are not used. |
| Staff | Notes, native police_badge number, accumulated Crimson duty time and persisted MDT suspension; requested grade/permission gates remain. Suspension is not a universal vendor suspension API. |
| Business files | Discover Qbox job keys, owner/logo/status/notes, native membership directory and license links, existing provider-backed finance. Bank accounts are not fabricated for jobs without one. |
| Documents | Safe heading/bold/list editor and preview, hosted images, designated-CID signatures bound to possessed physical copy. Not arbitrary HTML/PDF or byte-frozen external images. |
| Physical archive | At configured department printer: inventory deposit/retrieve with durable pending states. Retrieval/list are Management; original MDT record persists. |
| Armory | Configured catalog, bounded cart, shared stock reservation, durable issuance/return journal and per-character editable/deletable kits. Starts zero; manager restock is explicit. Unknown third-party key APIs are not guessed. |
| Tracking | Inventory band, nearby server-authorized placement linked to case, scoped/routing-bucket blips, officer removal or timed tool/minigame flow. Client skill success is not anti-cheat proof. |
| Dispatch | DOJ manual dispatch, responders, optional gunshot sensor and supplied Origen SendAlert bridge. Separate assignment records; no assumed private Origen API. Client-observed gunshots are not authoritative anti-cheat evidence. |
| Statistics | Scoped record/custody/report-author counts and accumulated duty leaderboard. No claim of complete external historical analytics. |
| Live bodycam | Provider SDK viewer, short-lived one-use grant, own-host consent and role-revocation checks. Requires external Cloudflare SFU Worker and explicit enable. Provider game capture has no game audio. Recorded WebM and live cannot run together. |
| Automatic expiry | Expired warrants/business-license records closed by periodic server tick. No external wanted database writes. |

Remaining parity boundaries: helicopter/air-unit spawning, complete translations, arbitrary HTML/PDF page builder, automatic weapon inventory registry, automatic debt collection, broader camera map configuration, external wanted/evidence/assignment sync and audio capture. These are not represented as implemented menu labels or guessed provider exports. Mechanics remain denied MDT access by the user's explicit whitelist requirement.

## Verification and rollout

Automated tests cover actual shipped Lua entry points with mocked FiveM/Qbox/inventory providers, DOM workflows, media code and real isolated MariaDB schema/JSON/stock concurrency checks. In-engine multiplayer testing has not occurred in this environment. Use INSTALL/UPGRADE_4_AR.md, keep customized config/sounds/recordings, add only the two new inventory definitions and install only the small own Origen bridge. No original third-party Origen ZIP is redistributed.
