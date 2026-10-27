Run from repository root with Node.js 24+: npm ci --prefix tests; npm test --prefix tests.
Tests use fengari (Lua VM), luaparse and jsdom. Qbox, MySQL, FiveM native calls and NUI fetches are mocked. The runner verifies both execution exit status and explicit current-run completion summaries, since the Lua CLI can report Lua assertion failures without a useful exit code.
No production dependencies or npm install are required for the resource itself.
