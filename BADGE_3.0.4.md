# DOJ badge — 3.0.4

Install the complete resource ZIP after backing up your config and recordings; preserve existing database records and merge local config settings. No SQL change.

Copy only the crimson_doj_badge entry from crimson_doj/INSTALL/ox_inventory-items.lua INSIDE the existing return table in ox_inventory/data/items.lua. Do not add another return table or duplicate existing items. Restart the server after updating inventory items.

On-duty DOJ: /dojbadge issues an owner-bound item, provided there is space. Use it in inventory to show a non-interactive card for eight seconds to yourself and players within three metres in the same routing bucket. Names and current rank come from Qbox. The card uses the Crimson logo, not a character photograph. Badge number is DOJ- plus the character ID. A transferred badge cannot be used by another character; staff who leave DOJ or go off duty cannot show it. Issuance cooldown 60 seconds; display cooldown three seconds. No emote-menu dependency.

Validation: full existing local suite plus badge slot/ownership/job/duty checks, live identity fields, display rate limit, distance and routing-bucket isolation. Actual FiveM inventory use and card appearance need in-server verification.
