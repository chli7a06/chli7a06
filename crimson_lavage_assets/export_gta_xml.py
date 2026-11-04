"""Run using Blender and official Sollumz v2.6.0; emits CodeWalker XML, NOT binary YDR."""
import bpy,sys,os
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,os.environ.get('SOLLUMZ_PARENT','/workspace/tools'))
import addon_utils
addon_utils.enable('Sollumz',default_set=True,persistent=False)
from Sollumz.tools.drawablehelper import convert_obj_to_drawable
from Sollumz.ydr.shader_materials import create_shader
from Sollumz.ydr.ydrexport import export_ydr
from Sollumz.tools.meshhelper import get_uv_map_name,get_color_attr_name
bpy.ops.wm.open_mainfile(filepath=str(OUT/'crimson_pressure_washer.blend'))
# generate flat-color DDS swatches ahead of time (see exported textures folder).
for name in ['crimson_pressure_washer','crimson_pressure_hose']:
 obj=bpy.data.objects[name]
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 if not obj.data.uv_layers:obj.data.uv_layers.new()
 obj.data.uv_layers[0].name=get_uv_map_name(0)
 for idx in [0,1]:
  attr=obj.data.color_attributes.get(get_color_attr_name(idx)) or obj.data.color_attributes.new(name=get_color_attr_name(idx),type='BYTE_COLOR',domain='CORNER')
  for item in attr.data:item.color=(1,1,1,1)
 for idx,old in enumerate(list(obj.data.materials)):
  material=create_shader('default.sps');material.name=name+'_material_'+str(idx)
  texture=OUT/'textures'/('swatch_'+str(round(old.diffuse_color[0]*255))+'_'+str(round(old.diffuse_color[1]*255))+'_'+str(round(old.diffuse_color[2]*255))+'.dds')
  image=bpy.data.images.load(str(texture),check_existing=True)
  node=material.node_tree.nodes.get('DiffuseSampler');node.image=image;node.texture_properties.embedded=True
  obj.data.materials[idx]=material
 drawable=convert_obj_to_drawable(obj)
 drawable.drawable_properties.lod_dist_high=100
 export_ydr(drawable,str(OUT/(name+'.ydr.xml')))
 print('EXPORTED',name)
bpy.ops.file.pack_all()
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'crimson_pressure_washer_sollumz.blend'))
