# Development checks

Node 24+: `npm ci --prefix tests`, then `npm test --prefix tests` from repository root. No npm installation is required for the FiveM resource itself.

The suite checks Lua/JS syntax; server permissions/privacy/migrations/printer ownership; client focus/camera/item/video cancellation; UI forms, physical copy reading and bounded video assembly; payment/refund/uncertain-outcome/prison/capture adapters with mocks; and actual Node filesystem/chunk-transfer code. The runner requires explicit completion summaries because the Lua CLI can emit assertion failures with a misleading exit code.

Optional actual SQL check: `python3 tests/database.test.py`. Requires Docker and the pinned MariaDB image; creates one ephemeral container with no network/host ports and removes it on completion. It never touches the production database.

Optional actual browser check: serve crimson_doj/web on localhost:9341, launch headless Chromium with remote debugging on 9337, then `node tests/browser.test.cjs`. Override MDT_TEST_URL/CHROME_DEBUG_PORT if needed. This container required --single-process --no-zygote; ordinary machines may not. It records/decodes a small real WebM through NUI messages, checks printed-copy rendering, UI and close/camera states; screenshots go to /tmp/crimson-browser-review. NUI responses remain mocked, so this is not FiveM/CEF end-to-end validation.
