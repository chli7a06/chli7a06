# Crimson washer V4 — shorter lance and carry/spray poses

Based on the existing V3 male freemode skeleton and the user's eight-second
`CRIMSON_LAVAGE_V12_APERCU_COMPLET_8S.mp4` reference (included as `reference.mp4`).
The reference guides the lowered carry and raised two-handed spray poses. This
revision does not use the prototype's incompatible proxy skeleton or body tracks.

The long steel section is shortened by **15 cm**. The grip, bottle, front valve,
nozzle and hose connection keep their original dimensions. The front assembly
is moved back along X; the grip origin stays fixed. The new model-space muzzle
is `(0.840, 0, 0.041)`.

The carry pose lowers the lance 35 degrees. The spray pose raises the hands in
front of the upper torso. The support palm moves 5 cm towards the pistol compared
with V3, while the gun/right hand move forward. Both clips use the existing
rigid attachment: bone 57005, position `(0.085, 0.025, -0.040)`, rotation
`(-90, 0, 0)`, rotation order 2. The script blends between the two poses when
LMB is pressed/released. These are two looping poses, not the reference's baked
eight-second playback. No weapon is given or equipped.

## Install

Use the updated **crimson-mechanic.zip**. The resource already contains compiled
`stream/crimson_wash_custom_v4.ycd` and the shortened
`stream/crimson_pressure_washer.ydr`. No Blender or CodeWalker step is required.
Use the supplied gun config and model together so the water starts at the tip.
Keep only one resource streaming the `crimson_pressure_washer` archetype.

## Source and validation

- `build_animation.py`: authors the two poses from the previously supplied real
  `mp_m_freemode_01.yft.xml`; requires Blender 4.3 and official Sollumz v2.6.0.
- `shorten_model.py`: shortens only the long lance and exports YDR XML.
- `verify_roundtrip.py`: uses the official Sollumz importer to check both wrists
  within 1 mm of their authored positions.
- `verify_compiled_assets.py`: compares all 92 compiled animation channels to
  source XML, checks the 15 cm prop reduction and embedded texture names.
- `validation.json`, `model_validation.json`, `compiled_validation.json`: results.
- `.blend` and `.ycd.xml`/`.ydr.xml`: editable source; PNGs are mannequin previews.

Binary compilation and reread used official CodeWalker.Core source commit
`485d56bec00262ed7fa472261cce7bbc6202b96e`, via `XmlYcd.GetYcd(...).Save()` and
`XmlYdr.GetYdr(..., textureFolder).Save()`. Reopened binaries are exported as
`.roundtrip.xml` for independent numeric comparison.

The actual game's character skin, clothing, animation blending and remote-player
appearance have **not** been tested here. Check carry, spray and sponge stages
in FiveM; the previews and automated checks do not establish an exact in-game
match to the video.
