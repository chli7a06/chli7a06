"""Author two washer upper-body clips from a user-supplied GTA skeleton.
Blender --background --python build_animation.py -- /path/mp_m_freemode_01.yft.xml
Produces CodeWalker YCD XML (requires compilation to binary YCD on Windows).
"""
import bpy,sys,os,math,json,xml.etree.ElementTree as ET
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
OUT=Path(__file__).resolve().parent
if '--' not in sys.argv: raise SystemExit('Supply the skeleton XML after --')
SOURCE=Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
xml=ET.parse(SOURCE).getroot();items=list(xml.find('.//Skeleton/Bones'))
records={};names={};world={};local={}
for b in items:
 i=int(b.find('Index').get('value'));parent=int(b.find('ParentIndex').get('value'))
 t=b.find('Translation');q=b.find('Rotation')
 mat=Matrix.Translation(Vector([float(t.get(k)) for k in 'xyz']))@Quaternion(tuple(float(q.get(k)) for k in 'wxyz')).to_matrix().to_4x4()
 records[i]={'name':b.findtext('Name'),'parent':parent,'tag':int(b.find('Tag').get('value')),'mat':mat}
 names[b.findtext('Name')]=i;local[i]=mat
 world[i]=world[parent]@mat if parent>=0 else mat
# Import the armature using the official Sollumz skeleton importer.
sys.path.insert(0,os.environ.get('SOLLUMZ_PARENT','/workspace/tools'))
import addon_utils
addon_utils.enable('Sollumz',default_set=True,persistent=False)
from Sollumz.cwxml.fragment import Fragment
from Sollumz.ydr.ydrimport import create_armature_obj_from_skel
from Sollumz.sollumz_properties import SollumType
from Sollumz.cwxml.clipdictionary import ClipDictionary
frag=Fragment.from_xml_file(str(SOURCE))
rig=create_armature_obj_from_skel(frag.drawable.skeleton,'Crimson washer authored rig',SollumType.DRAWABLE)
root=world[names['SKEL_ROOT']];rootRot=root.to_quaternion()
def pedpoint(v):return root@Vector(v)
def peddir(v):return rootRot@Vector(v)
def frame(x,z):
 x=Vector(x).normalized();z=Vector(z);z=(z-x*x.dot(z)).normalized();y=z.cross(x).normalized()
 return Matrix(((x.x,y.x,z.x),(x.y,y.y,z.y),(x.z,y.z,z.z))).to_quaternion()
def arm_solution(side,target,pole,hand_rotation,pose):
 upper=names['SKEL_'+side+'_UpperArm'];fore=names['SKEL_'+side+'_Forearm'];hand=names['SKEL_'+side+'_Hand']
 shoulder=world[upper].translation
 l1=local[fore].translation.length;l2=local[hand].translation.length
 delta=target-shoulder;distance=delta.length
 assert distance < l1+l2-.002, f'{side} wrist beyond reach: {distance} vs {l1+l2}'
 direction=delta.normalized();projection=(l1*l1-l2*l2+distance*distance)/(2*distance)
 height=math.sqrt(max(0,l1*l1-projection*projection))
 bend=pole-shoulder;bend=(bend-direction*bend.dot(direction)).normalized()
 elbow=shoulder+direction*projection+bend*height
 for bone,start,end in [(upper,shoulder,elbow),(fore,elbow,target)]:
  restRotation=world[bone].to_quaternion();original=restRotation@Vector((1,0,0))
  rotation=original.rotation_difference((end-start).normalized())@restRotation
  pose[bone]=Matrix.Translation(start)@rotation.to_matrix().to_4x4()
 pose[hand]=Matrix.Translation(target)@hand_rotation.to_matrix().to_4x4()
 return {'shoulder':list(shoulder),'elbow':list(elbow),'wrist':list(target),'reach_ratio':distance/(l1+l2)}
def jenk(s):
 h=0
 for c in s.lower().encode():h=(h+c)&0xffffffff;h=(h+(h<<10))&0xffffffff;h^=h>>6
 h=(h+(h<<3))&0xffffffff;h^=h>>11;return (h+(h<<15))&0xffffffff
clips=ET.Element('ClipDictionary');clipsNode=ET.SubElement(clips,'Clips');anims=ET.SubElement(clips,'Animations')
metrics={};poses={}
gunGrip=Vector((-.04,-.04,-.025));supportGrip=Vector((.09,0,.075));palmOffset=Vector((.045,0,0))
for clip,rightTarget,pitch in [('carry',(.075,.215,.255),-35),('spray',(.08,.255,.40),0)]:
 pose={i:m.copy() for i,m in world.items()}
 direction=peddir((0,math.cos(math.radians(pitch)),math.sin(math.radians(pitch)))).normalized()
 gunUp=peddir((0,-math.sin(math.radians(pitch)),math.cos(math.radians(pitch)))).normalized()
 gunSide=gunUp.cross(direction).normalized();gunRotation=frame(direction,gunUp)
 rightPalm=pedpoint(rightTarget);gunOrigin=rightPalm-gunRotation@gunGrip;leftPalm=gunOrigin+gunRotation@supportGrip
 rightRot=frame(direction,-gunSide)
 leftRot=frame(-gunSide,gunUp)
 right=rightPalm-rightRot@palmOffset
 left=leftPalm-leftRot@palmOffset
 details={}
 details['right']=arm_solution('R',right,pedpoint((.55,.01,.12)),rightRot,pose)
 details['left']=arm_solution('L',left,pedpoint((-.55,.01,.12)),leftRot,pose)
 # Apply solved matrices parent-first to the Blender armature, and author finger curls.
 for pb in rig.pose.bones:pb.matrix_basis.identity()
 bpy.context.view_layer.update()
 for name in ['SKEL_R_UpperArm','SKEL_R_Forearm','SKEL_R_Hand','SKEL_L_UpperArm','SKEL_L_Forearm','SKEL_L_Hand']:
  rig.pose.bones[name].matrix=pose[names[name]];bpy.context.view_layer.update()
 for side in ['R','L']:
  for digit in range(5):
   for joint in range(3):
    name=f'SKEL_{side}_Finger{digit}{joint}'
    if name not in rig.pose.bones:continue
    pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
    # Modest grip closure; the trigger finger stays less curled.
    angles=(16,29,24) if digit==0 else ((8,20,25) if side=='R' and digit==1 else (28,48,43))
    # The skeleton's finger bend axes are mirrored: R curls around +Z,
    # L around -Z. Using one sign opens the right hand instead of gripping.
    sign=1 if side=='R' else -1
    pb.rotation_quaternion=Quaternion((0,0,1),math.radians(sign*angles[joint]))
 bpy.context.view_layer.update()
 action=bpy.data.actions.new('crimson_wash_v4_'+clip);rig.animation_data_create();rig.animation_data.action=action
 keyed=[]
 for pb in rig.pose.bones:
  if pb.name.startswith(('SKEL_L_Clavicle','SKEL_R_Clavicle','SKEL_L_UpperArm','SKEL_R_UpperArm','SKEL_L_Forearm','SKEL_R_Forearm','SKEL_L_Hand','SKEL_R_Hand','SKEL_L_Finger','SKEL_R_Finger')) or pb.name in ['SKEL_Spine0','SKEL_Spine1','SKEL_Spine2','SKEL_Spine3']:
   pb.rotation_mode='QUATERNION';pb.keyframe_insert(data_path='rotation_quaternion',frame=1);pb.keyframe_insert(data_path='rotation_quaternion',frame=31);keyed.append(pb.name)
 bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
 # Export local absolute rotations as the Sollumz exporter does. Do not include
 # root, locomotion, face or IK tracks: lower-body movement stays game-controlled.
 channels=[]
 for name in keyed:
  pb=rig.pose.bones[name];m=pb.parent.matrix.inverted()@pb.matrix if pb.parent else pb.matrix
  q=m.to_quaternion().normalized();tag=records[names[name]]['tag'];channels.append((tag,1,q))
  if name in ['SKEL_L_Forearm','SKEL_R_Forearm','SKEL_L_Hand','SKEL_R_Hand']:
   channels.append((tag,0,m.translation.copy()))
 channels.sort(key=lambda x:x[0] | (x[1]<<16))
 c=ET.SubElement(clipsNode,'Item')
 for k,v in [('Hash',clip),('Name','pack:/crimson_wash_custom_v4/'+clip+'.clip')]:ET.SubElement(c,k).text=v
 ET.SubElement(c,'Type',value='Animation');ET.SubElement(c,'Unknown30',value='0');ET.SubElement(c,'Tags');ET.SubElement(c,'Properties')
 ET.SubElement(c,'AnimationHash').text='crimson_wash_v4_'+clip
 for k,v in [('StartTime','0'),('EndTime','1'),('Rate','1')]:ET.SubElement(c,k,value=v)
 a=ET.SubElement(anims,'Item');ET.SubElement(a,'Hash').text='crimson_wash_v4_'+clip
 for k,v in [('Unknown10','0'),('FrameCount','31'),('SequenceFrameLimit','61'),('Duration','1')]:ET.SubElement(a,k,value=v)
 ET.SubElement(a,'Unknown1C').text=f'hash_{(jenk("crimson_wash_v4_"+clip)+1)&0xffffffff:08X}'
 ids=ET.SubElement(a,'BoneIds');seqs=ET.SubElement(a,'Sequences');seq=ET.SubElement(seqs,'Item');ET.SubElement(seq,'Hash').text='hash_00000000';ET.SubElement(seq,'FrameCount',value='31');sd=ET.SubElement(seq,'SequenceData')
 for tag,track,value in channels:
  bi=ET.SubElement(ids,'Item')
  for k,v in [('BoneId',str(tag)),('Track',str(track)),('Unk0',str(track))]:ET.SubElement(bi,k,value=v)
  ch=ET.SubElement(ET.SubElement(sd,'Item'),'Channels');item=ET.SubElement(ch,'Item')
  ET.SubElement(item,'Type',value='StaticQuaternion' if track==1 else 'StaticVector3')
  components=(value.x,value.y,value.z,value.w) if track==1 else tuple(value)
  ET.SubElement(item,'Value',**{k:format(v,'.9g') for k,v in zip('xyzw',components)})
 poses[clip]={'matrices':{pb.name:pb.matrix.copy() for pb in rig.pose.bones},'gunOrigin':gunOrigin,'gunRotation':gunRotation,'action':action}
 details['right_grip_error_m']=(rig.pose.bones['SKEL_R_Hand'].matrix.translation-right).length
 details['left_grip_error_m']=(rig.pose.bones['SKEL_L_Hand'].matrix.translation-left).length
 details['right_palm_error_m']=(rig.pose.bones['SKEL_R_Hand'].matrix@palmOffset-rightPalm).length
 details['left_palm_error_m']=(rig.pose.bones['SKEL_L_Hand'].matrix@palmOffset-leftPalm).length
 handMatrix=rig.pose.bones['SKEL_R_Hand'].matrix
 attachment=handMatrix.inverted()@(Matrix.Translation(gunOrigin)@gunRotation.to_matrix().to_4x4())
 angles=attachment.to_euler('ZXY')
 details['attachment']={'bone':57005,'position':list(attachment.translation),'rotation_degrees':[math.degrees(x) for x in angles],'rotation_order':2}
 details['rotation_tracks']=sum(track==1 for _,track,_ in channels);details['translation_tracks']=sum(track==0 for _,track,_ in channels);metrics[clip]=details
 assert details['right_grip_error_m']<.001 and details['left_grip_error_m']<.001
 print('POSE',clip,'errors',details['right_grip_error_m'],details['left_grip_error_m'],'tracks',len(channels))
ET.indent(clips);path=OUT/'crimson_wash_custom_v4.ycd.xml';ET.ElementTree(clips).write(path,encoding='utf-8',xml_declaration=True)
parsed=ClipDictionary.from_xml_file(str(path));assert len(parsed.clips)==2 and len(parsed.animations)==2
(OUT/'validation.json').write_text(json.dumps(metrics,indent=2))
rig.animation_data.action=poses['carry']['action'];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'crimson_wash_poses.blend'))
# Lightweight mannequin preview: no original GTA mesh/textures are distributed.
def mat(name,color,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.48;return m
skin=mat('Neutral mannequin skin',(.55,.34,.23));cloth=mat('Neutral shirt',(.14,.17,.19));ground=mat('Ground',(.055,.065,.075))
def sphere(name,p,r,material,scale=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=r,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(material)
 if scale:o.scale=scale
 for f in o.data.polygons:f.use_smooth=True
 return o
preview=[]
def rod(name,a,b,r,material):
 a,b=Vector(a),Vector(b);d=b-a
 if d.length<.001:return
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(material);preview.append(o)
 for f in o.data.polygons:f.use_smooth=True
with bpy.data.libraries.load(str(OUT.parent/'crimson_lavage_assets/crimson_pressure_washer.blend'),link=False) as (src,dst):dst.objects=['crimson_pressure_washer']
gun=dst.objects[0];bpy.context.collection.objects.link(gun)
# Shorten only the long lance: keep the grip and bottle at their original size.
# This is the same deformation used by shorten_model.py and the runtime muzzle.
# Bake the source object's transform so the preview uses GTA drawable coordinates.
gun.data.transform(gun.matrix_world);gun.matrix_world=Matrix.Identity(4)
for vertex in gun.data.vertices:
 x=vertex.co.x
 if x>.18:vertex.co.x=x-.15*min(1.,(x-.18)/(.775-.18))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.world.color=(.13,.13,.13)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.95));bpy.context.object.data.materials.append(ground)
for loc,energy,size in [((1,-3,3),650,4),((-2,1,2),550,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=size;o.rotation_euler=(Vector((0,-.1,.2))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2,-3,1.25));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=2.1;camera.rotation_euler=(Vector((0,-.15,.3))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
for clip in ['carry','spray']:
 for o in preview:bpy.data.objects.remove(o,do_unlink=True)
 preview=[];data=poses[clip];matrices=data['matrices']
 gun.matrix_world=Matrix.Translation(data['gunOrigin'])@data['gunRotation'].to_matrix().to_4x4()
 preview.append(sphere('Torso',(0,.03,.17),1,cloth,(.20,.11,.32)))
 preview.append(sphere('Head',world[names['SKEL_Head']].translation+Vector((0,0,.04)),.105,skin,(.88,.9,1.15)))
 for side in ['R','L']:
  for first,second,r,material in [('UpperArm','Forearm',.046,cloth),('Forearm','Hand',.035,skin)]:
   rod(side+first,matrices[f'SKEL_{side}_{first}'].translation,matrices[f'SKEL_{side}_{second}'].translation,r,material)
  hand=matrices[f'SKEL_{side}_Hand'];palm=hand@Vector((.045,0,0));o=sphere(side+' palm',palm,1,skin,(.055,.030,.020));o.rotation_euler=hand.to_euler();preview.append(o)
  for digit in range(5):
   for joint in range(2):
    n1=f'SKEL_{side}_Finger{digit}{joint}';n2=f'SKEL_{side}_Finger{digit}{joint+1}'
    if n1 in matrices and n2 in matrices:rod(n1,matrices[n1].translation,matrices[n2].translation,.008,skin)
 scene.render.filepath=str(OUT/('preview_'+clip+'.png'));bpy.ops.render.render(write_still=True)
print('AUTHORED_TWO_CLIPS_COMPLETE')
