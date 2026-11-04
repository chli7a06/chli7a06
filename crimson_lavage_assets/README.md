# Crimson pressure washer — reference-based 3D source

This is a newly modelled approximation of the supplied single screenshot, not the original asset or an exact reconstruction. Unseen surfaces and dimensions were estimated. The source includes a charcoal pistol grip and trigger guard, a long steel lance, brass foam-cannon fittings, a pale-blue reservoir and a separate curved supply hose.

**Status: editable model and GTA XML sources. Not a ready-to-install FiveM resource.** No binary `.ydr`/`.ytyp` files or live FiveM/Qbox validation are included.

## Files

- `preview.png`: close-up of the gun and bottle.
- `preview_with_hose.png`: gun and sample hose together.
- `crimson_pressure_washer.blend`: editable Blender 4.3 source with separate gun and hose mesh objects; meters; +X is the spray direction; origin is near the pistol grip.
- `crimson_pressure_washer_sollumz.blend`: Sollumz v2.6.0 drawable hierarchy with embedded color textures.
- `crimson_pressure_washer.glb`, `.obj`, `.mtl`: portable gun mesh.
- `crimson_pressure_hose.glb`: static sample hose mesh. It is **not** a simulated hose.
- `*.ydr.xml`, matching texture folders and `crimson_lavage.ytyp.xml`: CodeWalker XML source for the two props.
- `build_model.py`, `export_gta_xml.py`, `render_hose.py`: reproducible modelling/export scripts. The GTA export script requires the official Sollumz v2.6.0 add-on (https://github.com/Sollumz/Sollumz/releases/tag/v2.6.0). Set SOLLUMZ_PARENT to its parent directory; the default path is for this build environment only.

The reservoir uses an opaque material in GTA XML. The reference suggests a translucent bottle; that shader/material refinement is not implemented. The standalone hose is a static reference curve. A moving connection between a van and a player's gun needs an actual FiveM rope script, with appropriate end offsets, cleanup and multiplayer synchronization. Inventory icons/items and washing gameplay are not included.

## Required next step for FiveM

1. Use CodeWalker Explorer on Windows to import/compile the `.ydr.xml` sources with their matching texture folders into binary `.ydr` assets. Compile `crimson_lavage.ytyp.xml` to binary `.ytyp` as well. This conversion was **not** run or verified here.
2. Place the binary `.ydr` files and `crimson_lavage.ytyp` inside the resource's `stream` folder. Do not merely rename XML files to `.ydr`.
3. Register the archetypes in your resource manifest:

```lua
fx_version 'cerulean'
game 'gta5'
files { 'stream/crimson_lavage.ytyp' }
data_file 'DLC_ITYP_REQUEST' 'stream/crimson_lavage.ytyp'
```

4. Model names: `crimson_pressure_washer` and `crimson_pressure_hose`. Verify model loading, appearance, scale and hand attachment offsets on a development server before adding gameplay.
5. For a flexible hose, use FiveM rope natives between the gun and a separately configured machine/van anchor. The van/machine shown in the screenshot was not modelled.

## Validation

Blender generated and reopened the model; OBJ/GLB export completed. Official Sollumz v2.6.0 exported the drawable XML sources. XML parsing, nonempty mesh geometry, texture references and DDS decoding were checked locally. These checks do not establish that CodeWalker compilation, GTA shaders, collisions or FiveM attachment behavior work. The meshes have no custom collision bounds.
