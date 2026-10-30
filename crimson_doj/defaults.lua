-- Non-destructive defaults for upgrades that retain an older config.lua.
Config.Integrations = Config.Integrations or {}
Config.Printing = Config.Printing or { enabled=false, item='crimson_document', cooldown=5 }
Config.Printers = Config.Printers or {}
Config.Payments = Config.Payments or { maxAmount=1000000, offerCooldown=15 }
Config.Law = Config.Law or { maxFine=100000, maxJailMinutes=120, distance=10.0, fineAccount='doj' }
Config.Bodycam = Config.Bodycam or { duration=3600, maxBytes=536870912, maxClips=200, width=1280, height=720 }

-- Set provider explicitly when more than one bank is installed.
Config.Banking = Config.Banking or { provider='auto', accounts={} }

Config.Sounds = Config.Sounds or {enabled=true,volume=0.35,open='open.ogg',close='close.ogg',click='click.ogg',notification='notification.ogg'}
Config.JobBlips = Config.JobBlips or {enabled=true,interval=3000,sprite=1,colour=1,scale=0.8,jobs={doj=true,police=true,sheriff=true}}

-- Uses your installed emote menu's exact /e idcard command.
Config.BadgeEmote = Config.BadgeEmote or {command='e idcard',cancel='e c'}

Config.DiscoverBusinesses = Config.DiscoverBusinesses ~= false
Config.BusinessExcludedJobs = Config.BusinessExcludedJobs or {unemployed=true}
Config.LicenseTypes = Config.LicenseTypes or {driver='Driving license',weapon='Weapon license',business='Business license'}
Config.Tracking = Config.Tracking or {enabled=true,item='crimson_tracking_band',tool='electronickit',grade=5,bypassGrade=10}
Config.ArmoryCatalog = Config.ArmoryCatalog or {{name='radio',label='Radio',grade=0}}
Config.DispatchSources = Config.DispatchSources or {}
Config.AutomaticGunshots = Config.AutomaticGunshots ~= false

Config.EnableLiveBodycam = Config.EnableLiveBodycam or false
Config.DispatchSources.origen_police = true

Config.StockArmory = Config.StockArmory ~= false

Config.RequireBodycamItem = Config.RequireBodycamItem ~= false
Config.BodycamItem = Config.BodycamItem or 'crimson_bodycam'

-- Records the last observed online inventory holder, not verified legal ownership.
Config.WeaponObservation = Config.WeaponObservation ~= false
