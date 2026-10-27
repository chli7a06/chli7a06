Config = {}
Config.Command = 'dojmdt'
Config.Key = 'F12'
-- Use YOUR Qbox job names and grade levels. Never grant access to all jobs.
Config.Jobs = {
    doj = { read = 0, write = 0, manage = 14 },
}
Config.RequireDuty = true
Config.MaxText = 12000
