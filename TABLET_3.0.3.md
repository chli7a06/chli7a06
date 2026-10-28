# Crimson 3.0.3

Opening the authorized MDT now uses the tablet2 pose (female seated-wall tablet base) and prop_cs_tablet directly, without an emote-menu dependency. Closing, recovery and resource shutdown stop the owned animation and delete the prop; delayed loading cannot recreate it after closing.

Personal bank balances remain under Citizens → citizen profile, for DOJ/police managers. DOJ management can inspect configured company accounts under Businesses → Bank account. Company accounts require Renewed-Banking running and Config.BusinessJobs matching real account/job names. Missing balances show Unavailable. Default DOJ management grade is 3.

Install the complete downloads/crimson_doj_3.0.3.zip over the existing resource after backing up config, recordings and database. Merge your local job/position settings. Keep existing database records. No dependency changes or schema changes in this update.

Validation: Lua/JS syntax and full local mocked authorization/UI/client/service/media suite passed, including tablet creation, close/shutdown cleanup and delayed-load cancellation. Actual animation appearance and live bank providers still require FiveM verification.
