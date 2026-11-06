# Crimson washer V9 — support hand 1 cm towards character's right

Moves the support-palm target from `(0.120, 0.075, 0.080)` to
`(0.120, 0.065, 0.080)` in gun coordinates in carry and spray. This is a 1 cm
shift towards the character's right. Hand orientation and finger curls are
retained; the elbow/forearm solve and native roll helper reach the new target.

Use the root `crimson-mechanic.zip`. Both dictionaries and the streamed binary
are already V9; no Blender or CodeWalker conversion is needed. Restart and
reconnect. This update retains all previous spray, foam and inline audio work.

Source uses Blender 4.3, official Sollumz v2.6.0 and the supplied real male
freemode skeleton. Official CodeWalker.Core commit
`485d56bec00262ed7fa472261cce7bbc6202b96e` compiles and rereads the binary.
The importer checks wrist positions, finger/collar distance, elbow axial twist
and native roll-helper distribution. Compiled checks preserve non-left channels
against V8 within 1e-5. Source, mannequin previews and validation JSON are included.
Actual skinned-ped appearance has not been tested in FiveM here.
