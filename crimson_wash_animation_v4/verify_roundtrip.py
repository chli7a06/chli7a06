import bpy,sys,os,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
sys.path.insert(0,os.environ.get('SOLLUMZ_PARENT','/workspace/tools'))
import addon_utils
addon_utils.enable('Sollumz',default_set=True,persistent=False)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'crimson_wash_poses.blend'))
from Sollumz.ycd.ycdimport import import_ycd
from Sollumz.sollumz_properties import SollumType
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
expected=json.loads((OUT/'validation.json').read_text())
dictionary=import_ycd(str(OUT/'crimson_wash_custom_v4.ycd.xml'))
checked=[]
for collection in dictionary.children:
 for obj in collection.children:
  if obj.sollum_type!=SollumType.ANIMATION:continue
  properties=obj.animation_properties;properties.target_id=rig.data
  rig.animation_data.action=properties.action
  bpy.context.scene.frame_set(0);bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
  clip=properties.hash.removeprefix('crimson_wash_v4_')
  for side,name in [('right','SKEL_R_Hand'),('left','SKEL_L_Hand')]:
   actual=rig.pose.bones[name].matrix.translation
   wanted=Vector(expected[clip][side]['wrist'])
   gap=(actual-wanted).length
   assert gap<.001,(clip,side,gap)
  checked.append(clip)
assert set(checked)=={'carry','spray'}
print('PASS: official Sollumz YCD importer round-trips both authored wrist positions within 1mm')
