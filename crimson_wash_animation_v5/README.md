# Crimson washer V5 — left-hand contact and shorter lance

Refines V4 using the user's in-game close-up. The left-hand wrist is moved so
the curled fingers wrap the outlet/collar, instead of closing to one side of it.
In model coordinates the support-palm target changes from `(0.090, 0, 0.075)`
to `(0.125, 0.070, 0.095)`. Both carry and spray use the correction. Right-hand
pose, finger curls, attachment and gameplay stay as in V4.

The long lance is shortened **8 cm further than V4**, or 23 cm relative to the
original model. Grip, bottle, valve/nozzle and hose connector keep their sizes.
The front assembly translates back along X. The muzzle is now `(0.760, 0, 0.041)`.

## Install

Use the root `crimson-mechanic.zip`. Compiled V5 YCD and shortened YDR are already
in `stream/`; no Blender or CodeWalker step is needed. Use the new gun config
and model together. Replace the old resource after backing up custom config,
remove old V4 YCD overrides, then restart and reconnect.

## Validation and source

`build_animation.py` uses the same real male freemode skeleton as V3/V4, with
official Sollumz v2.6.0 and Blender 4.3. `shorten_model.py` edits only the lance.
`verify_roundtrip.py` checks both wrist positions within 1 mm after importing
the exported XML, and checks the four curled left-finger middle joints around
the physical collar. This catches the sideways fist alignment missed by the
previous wrist-only check. Results are in `grip_validation.json`.

Official CodeWalker.Core commit `485d56bec00262ed7fa472261cce7bbc6202b96e`
compiles both binaries and rereads them. `verify_compiled_assets.py` compares all
92 animation channels to source and checks compiled model bounds and embedded
textures. Its results are in `compiled_validation.json`; source poses/model
have their own validation JSON files. All editable blends/XML and mannequin
previews are included.

Live FiveM skinning, hand contact, clothing clearance and remote-player visuals
have not been tested here. The finger-joint check confirms skeleton alignment;
it does not establish perfect contact for the actual character's finger meshes.
