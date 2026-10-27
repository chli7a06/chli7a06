# Mission Row starter configuration

Replace crimson_doj/config.lua with downloads/config.lua, then run `restart crimson_doj` in the server console. The current ZIP also contains this configuration.

- Original uploaded job thresholds, business jobs, key/command and penal-code settings are preserved.
- Camera: Mission Row entrance, allowed jobs doj/police/sheriff.
- Armory: one radio, grade 1+, on duty with write permission, within 3 metres of (450,-980,30). Cooldown 30 minutes per citizen/job/kit. Item radio must exist in ox_inventory; start that resource first.
- Camera at (440,-981,35), rotation (-20,0,90). These are starter positions for Mission Row; a custom MLO may require different coordinates/rotation.
- Open /dojmdt, choose Equipment & cameras. Esc returns from camera view. Armory collection is available only near the configured location.
- Banking/jail/bodycam remain disabled/unimplemented; no such integrations were enabled.
- Configuration syntax was checked locally; positions and inventory behavior still need verification in your server.
