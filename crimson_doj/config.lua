Config = {}
Config.Command = 'dojmdt'
Config.Key = 'F12'
Config.RequireDuty = true
Config.MaxText = 20000
-- Explicit job membership; absent jobs never get access. Set grades to YOUR server.
Config.Jobs = {
 doj = { department='doj', label='Department of Justice', read=0, write=0, manage=3 },
 police = { department='police', label='Police Department', read=0, write=1, manage=4 },
 sheriff = { department='police', label='Sheriff Department', read=0, write=1, manage=4 },
 ambulance = { department='ems', label='Emergency Medical Services', read=0, write=1, manage=3 },
 mechanic = { department='business', label='Mechanic', read=0, write=0, manage=3 },
 burgershot = { department='business', label='Burger Shot', read=0, write=0, manage=3 },
}
Config.BusinessJobs = { 'mechanic', 'burgershot' }
-- Server-defined integrations. Never accept resource/event names from NUI.
-- Mission Row cameras and ox_inventory armory are enabled below.
-- Mission Row starter setup. Adjust positions if your server uses a different MLO.
Config.Integrations = {
 jail = false,
 banking = false,
 bodycam = false,
 inventory = 'ox_inventory',
 cameras = true,
}
Config.Cameras = {
 {
  label = 'Mission Row entrance',
  jobs = { doj=true, police=true, sheriff=true },
  x=440.0, y=-981.0, z=35.0,
  rx=-20.0, ry=0.0, rz=90.0, fov=60.0,
 },
}
-- Collection requires on-duty status, write permission, grade 1+ and proximity.
-- Item 'radio' must exist in your ox_inventory items configuration.
Config.Armory = {}
for _, job in ipairs({ 'doj', 'police', 'sheriff' }) do
 Config.Armory[job] = {
  coords = { x=450.0, y=-980.0, z=30.0 },
  radius = 3.0,
  kits = {
   {
    label = 'Radio kit',
    grade = 1,
    cooldown = 1800,
    items = { { name='radio', count=1 } },
   },
  },
 }
end
Config.PenalCode = {
 -- Supply YOUR RP laws: { code='T01', title='...', fine=0, months=0, category='Traffic' }
}

-- Physical document copies through ox_inventory. Register the item from INSTALL first.
Config.Printing = { enabled=true, item='crimson_document', cooldown=5 }
Config.Printers = {
 {label='Mission Row printer', coords={x=441.4,y=-982.2,z=30.7}, radius=2.0,
  jobs={doj=true,police=true,sheriff=true}},
}

-- Selected native Qbox providers. Install them before enabling live operations.
Config.Integrations.banking = 'Renewed-Banking'
Config.Integrations.jail = 'qbx_prison'
Config.Integrations.bodycam = 'screencapture'
Config.Payments = { maxAmount=1000000, offerCooldown=15 }
Config.Law = { maxFine=100000, maxJailMinutes=120, distance=10.0, fineAccount='doj' }
Config.Bodycam = { duration=30, maxBytes=15728640, maxClips=200, width=1280, height=720 }

-- Apex treasury adapter for this deployment; other verified banks can be selected.
Config.Banking = Config.Banking or { provider='apex_banking', accounts={} }

-- Put your own audio files here; names are relative to web/sounds/.
Config.Sounds = {enabled=true,volume=0.35,open='open.ogg',close='close.ogg',click='click.ogg',notification='notification.ogg'}
-- Police/sheriff keep their Origen unit markers; DOJ receives their positions here.
Config.JobBlips = {enabled=true,interval=3000,sprite=1,colour=1,scale=0.8,
 jobs={doj=true,police=true,sheriff=true}}

-- Uses your installed emote menu's exact /e idcard command.
Config.BadgeEmote = Config.BadgeEmote or {command='e idcard',cancel='e c'}
