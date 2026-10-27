# Crimson 3.0.0 beta validation

Passed current-source checks: 235 default-suite assertions, 16 real MariaDB assertions, and 14 real Chromium assertions. Lua and JavaScript syntax checks pass. Test sources and locked development dependencies are in tests/.

Qbox, ox_inventory, Renewed-Banking, qbx_prison, screencapture API effects and FiveM natives are mocked in the service/client tests. Real filesystem/path/transfer code runs in Node; real MariaDB executes schema/migration/payment JSON updates; real Chromium renders the NUI, assembles and decodes a locally generated WebM, and renders/clears printed documents. Closed/camera-hidden/closed-again screenshots have zero opaque pixels. These are not in-game FiveM acceptance tests.

Provider release archives were checked for integrity, required built assets, native Qbox support and the APIs used by the adapters. Their FiveM execution was not performed here. RESULTS.json contains source hashes and exact screenshot alpha ranges.
