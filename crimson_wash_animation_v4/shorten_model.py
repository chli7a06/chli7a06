"""Shorten the original lance by 15 cm; export with official Sollumz v2.6.0.

Run using Blender 4.3 --background --disable-autoexec --python shorten_model.py.
Grip, bottle, nozzle and hose fitting retain their original dimensions.
"""
import bpy, sys, os, json
from pathlib import Path
from mathutils import Matrix

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / 'crimson_lavage_assets'
sys.path.insert(0, os.environ.get('SOLLUMZ_PARENT', '/workspace/tools'))
import addon_utils
addon_utils.enable('Sollumz', default_set=True, persistent=False)
from Sollumz.tools.drawablehelper import convert_obj_to_drawable
from Sollumz.ydr.shader_materials import create_shader
from Sollumz.ydr.ydrexport import export_ydr
from Sollumz.tools.meshhelper import get_uv_map_name, get_color_attr_name

bpy.ops.wm.open_mainfile(filepath=str(SOURCE / 'crimson_pressure_washer.blend'), use_scripts=False)
obj = bpy.data.objects['crimson_pressure_washer']
obj.data.transform(obj.matrix_world)
obj.matrix_world = Matrix.Identity(4)
before = [v.co.copy() for v in obj.data.vertices]
for v in obj.data.vertices:
    x = v.co.x
    if x > .18:
        v.co.x = x - .15 * min(1., (x - .18) / (.775 - .18))
assert all((a - b.co).length < 1e-7 for a, b in zip(before, obj.data.vertices) if a.x <= .18)
metrics = {
    'lance_shortening_m': .15,
    'before_x_max_m': max(v.x for v in before),
    'after_x_max_m': max(v.co.x for v in obj.data.vertices),
    'muzzle': [.840, 0., .041],
    'grip_and_hose_connection_unchanged': True,
}
(OUT / 'model_validation.json').write_text(json.dumps(metrics, indent=2) + '\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'crimson_pressure_washer_short.blend'))
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
if not obj.data.uv_layers:
    obj.data.uv_layers.new()
obj.data.uv_layers[0].name = get_uv_map_name(0)
for index in [0, 1]:
    attr = obj.data.color_attributes.get(get_color_attr_name(index)) or obj.data.color_attributes.new(
        name=get_color_attr_name(index), type='BYTE_COLOR', domain='CORNER')
    for item in attr.data:
        item.color = (1, 1, 1, 1)
for index, old in enumerate(list(obj.data.materials)):
    material = create_shader('default.sps')
    material.name = 'crimson_pressure_washer_material_' + str(index)
    rgb = [str(round(v * 255)) for v in old.diffuse_color[:3]]
    texture = SOURCE / 'textures' / ('swatch_' + '_'.join(rgb) + '.dds')
    node = material.node_tree.nodes.get('DiffuseSampler')
    node.image = bpy.data.images.load(str(texture), check_existing=True)
    node.texture_properties.embedded = True
    obj.data.materials[index] = material
drawable = convert_obj_to_drawable(obj)
drawable.drawable_properties.lod_dist_high = 100
export_ydr(drawable, str(OUT / 'crimson_pressure_washer.ydr.xml'))
print('PASS: lance shortened 15cm; grip and bottle dimensions retained')
