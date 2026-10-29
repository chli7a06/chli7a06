-- Non-destructive defaults for upgrades that retain an older config.lua.
Config.Integrations = Config.Integrations or {}
Config.Printing = Config.Printing or { enabled=false, item='crimson_document', cooldown=5 }
Config.Printers = Config.Printers or {}
Config.Payments = Config.Payments or { maxAmount=1000000, offerCooldown=15 }
Config.Law = Config.Law or { maxFine=100000, maxJailMinutes=120, distance=10.0, fineAccount='doj' }
Config.Bodycam = Config.Bodycam or { duration=30, maxBytes=15728640, maxClips=200, width=1280, height=720 }

-- Set provider explicitly when more than one bank is installed.
Config.Banking = Config.Banking or { provider='auto', accounts={} }

Config.Sounds = Config.Sounds or {enabled=true,volume=0.35,open='open.ogg',close='close.ogg',click='click.ogg',notification='notification.ogg'}
Config.JobBlips = Config.JobBlips or {enabled=true,interval=3000,sprite=1,colour=1,scale=0.8,jobs={doj=true,police=true,sheriff=true}}

-- Uses your installed emote menu's exact /e idcard command.
Config.BadgeEmote = Config.BadgeEmote or {command='e idcard',cancel='e c'}
