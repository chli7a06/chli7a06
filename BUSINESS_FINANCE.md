# Company bank inspection (3.0.2)

For an existing Crimson 3.0 installation, back up the resource and apply downloads/crimson_business_bank_3.0.2.zip. It overwrites server.lua, server_extras.lua, web/app.js and fxmanifest.lua; it includes the previous personal-bank-balance update. Keep config.lua and all inventory definitions. Run `ensure crimson_doj` in server console.

Use a configured DOJ manager grade (default doj grade 3), on duty. Open /dojmdt → Businesses → Bank account on a company card. The read-only view shows its current Renewed-Banking job-account balance, up to 100 transactions and a refresh button. No money is moved. Police/EMS/business roles cannot inspect other companies through this endpoint; company managers retain their own Bank account pane.

Only job names explicitly listed in Config.BusinessJobs are available (default mechanic, burgershot). Add your actual business job names there if needed. The corresponding account must exist in Renewed-Banking; missing accounts are labelled unavailable, not $0. The personal-bank card in citizen profiles reads Qbox personal money and remains separate.

Validated with server permission/account allowlist/zero/missing-account/history-cap/field-filter tests and UI navigation/rendering checks. Actual provider values in FiveM still require an in-game check.
