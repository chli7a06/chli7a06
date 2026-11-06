import bpy,sys,os,json,math
from pathlib import Path
from mathutils import Vector, Matrix, Euler
OUT=Path(__file__).resolve().parent
sys.path.insert(0,os.environ.get('SOLLUMZ_PARENT','/workspace/tools'))
import addon_utils
addon_utils.enable('Sollumz',default_set=True,persistent=False)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'crimson_wash_poses.blend'))
from Sollumz.ycd.ycdimport import import_ycd
from Sollumz.sollumz_properties import SollumType
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
expected=json.loads((OUT/'validation.json').read_text())
dictionary=import_ycd(str(OUT/'crimson_wash_custom_v7.ycd.xml'))
checked=[]
grip_results={}
wrist_results={}
for collection in dictionary.children:
 for obj in collection.children:
  if obj.sollum_type!=SollumType.ANIMATION:continue
  properties=obj.animation_properties;properties.target_id=rig.data
  rig.animation_data.action=properties.action
  bpy.context.scene.frame_set(0);bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
  clip=properties.hash.removeprefix('crimson_wash_v7_')
  for side,name in [('right','SKEL_R_Hand'),('left','SKEL_L_Hand')]:
   actual=rig.pose.bones[name].matrix.translation
   wanted=Vector(expected[clip][side]['wrist'])
   gap=(actual-wanted).length
   assert gap<.001,(clip,side,gap)
  # The old wrist target alone passed while the curled fingers missed the collar.
  # Verify the actual middle finger joints against the physical collar as well.
  attachment=Matrix.Translation(Vector((.085,.025,-.040)))@Euler((-1.5707963267948966,0,0),'ZXY').to_matrix().to_4x4()
  gun_inverse=(rig.pose.bones['SKEL_R_Hand'].matrix@attachment).inverted()
  distances={}
  for digit in [1,2,3,4]:
   joint=gun_inverse@rig.pose.bones[f'SKEL_L_Finger{digit}1'].matrix.translation
   collar=Vector((max(.105,min(.18,joint.x)),0,.107))
   distance=(joint-collar).length
   assert .015<distance<.055,(clip,digit,distance)
   distances[str(digit)]=distance
  fore=rig.pose.bones['SKEL_L_Forearm'].matrix.to_quaternion()
  hand=rig.pose.bones['SKEL_L_Hand'].matrix.to_quaternion()
  axis=fore@Vector((1,0,0))
  bend=math.degrees(axis.angle(hand@Vector((1,0,0))))
  palmZ=hand@Vector((0,0,1));palmZ=(palmZ-axis*palmZ.dot(axis)).normalized()
  twist=math.degrees((fore@Vector((0,0,1))).angle(palmZ))
  assert bend<25 and twist<5,(clip,bend,twist)
  wrist_results[clip]={'bend_degrees':bend,'twist_degrees':twist}
  grip_results[clip]=distances
  checked.append(clip)
assert set(checked)=={'carry','spray'}
print('PASS: official Sollumz YCD importer round-trips both authored wrist positions within 1mm')
(OUT/'grip_validation.json').write_text(json.dumps({'middle_joint_distances_to_collar_axis_m':grip_results,'wrist_angles':wrist_results,'live_fivem_tested':False},indent=2)+'\n')
print('PASS: left finger contact, wrist bend below 25 degrees and wrist twist below 5 degrees in both clips')
