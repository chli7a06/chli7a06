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
-- These are deliberately disabled until matched to your installed resources.
Config.Integrations = { jail=false, banking=false, bodycam=false, inventory=false, cameras=false }
Config.Cameras = {} -- { label='Mission Row', x=..., y=..., z=..., rx=..., ry=..., rz=..., fov=60 }
Config.Armory = {} -- Inventory distribution is disabled until a provider is configured.
Config.PenalCode = {
 -- Supply YOUR RP laws: { code='T01', title='...', fine=0, months=0, category='Traffic' }
}
