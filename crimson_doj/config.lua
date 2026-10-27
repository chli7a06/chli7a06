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
