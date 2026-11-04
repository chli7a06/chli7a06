"""Procedural reference-based pressure washer. Run with Blender 4.3+ --background --python build_model.py."""
import bpy, math, os
from mathutils import Vector
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
parts=[]
def material(name,color,metallic=0,roughness=.35,alpha=1):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,alpha);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,alpha);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
 return m
black=material('Rubber charcoal',(0.027,.03,.032),0,.62)
grey=material('Pistol graphite housing',(.12,.135,.14),.15,.38)
steel=material('Brushed stainless lance',(.55,.60,.64),.88,.24)
brass=material('Brass couplings',(.52,.31,.10),.78,.29)
blue=material('Pale blue foam reservoir',(.39,.68,.73),.05,.2)
white=material('Bottle graduation marks',(.73,.85,.85),.1,.4)
def finish(o,name,mat):
 o.name=name;o.data.materials.append(mat);parts.append(o)
 for p in o.data.polygons:p.use_smooth=True
 return o

def cyl(name,a,b,r,mat,vertices=24,r2=None):
 a,b=Vector(a),Vector(b);d=b-a
 if r2 is None:bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)/2)
 else:bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r2,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,name,mat)
def cube(name,loc,scale,mat,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Moulded edge radii','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,name,mat)
def tube(name,points,r,mat):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=16;curve.bevel_depth=r;curve.bevel_resolution=3
 spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
 for p,co in zip(spline.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False);parts.append(o);return o
# X points towards the jet. Origin is the centre of the pistol grip.
body=cube('Pistol upper shell',(.015,0,.105),(.20,.052,.085),grey,.014)
body.rotation_euler[1]=-.12
cube('Upper black seam',(.015,0,.143),(.16,.054,.008),black,.003)
grip=cube('Angled ergonomic grip',(-.046,0,-.025),(.054,.048,.19),black,.014);grip.rotation_euler[1]=-.27
cube('Grip heel',(-.025,0,-.111),(.062,.055,.025),grey,.008)
for i in range(6):
 o=cube('Grip rib %02d'%i,(-.052+i*.002,0,.025-i*.020),(.055,.051,.004),grey,.001);o.rotation_euler[1]=-.27
# Trigger is surrounded by a rounded guard, separate from grip.
tube('Trigger guard',[(.045,-.001,.095),(.095,-.001,.046),(.080,-.001,-.075),(-.005,-.001,-.094)],.007,grey)
trigger=cube('Black trigger',(.038,-.001,.028),(.013,.018,.086),black,.006);trigger.rotation_euler[1]=-.24
for y in [-.028,.028]:
 cyl('Shell screw',(-.049,y-.001,.115),(-.049,y+.001,.115),.004,steel,12)
# Main long metal lance and brass quick disconnects.
cyl('Outlet brass connector',(.105,0,.108),(.157,0,.108),.019,brass,12)
cyl('Outlet black collar',(.143,0,.108),(.18,0,.106),.022,black)
cyl('Long steel lance',(.172,0,.106),(.795,0,.058),.009,steel)
cyl('Foam cannon inlet coupling',(.775,0,.059),(.824,0,.055),.023,brass,12)
cyl('Foam cannon valve block',(.817,0,.055),(.865,0,.052),.020,brass,16)
cyl('Front spray barrel',(.855,0,.052),(.97,0,.043),.010,steel)
cyl('Nozzle brass lip',(.963,0,.044),(.988,0,.042),.013,brass,12)
cyl('Nozzle opening',(.987,0,.042),(.990,0,.041),.007,black,16)
cyl('Foam adjuster stem',(.838,0,.057),(.838,0,.096),.007,brass,12)
cyl('Foam adjuster knob',(.838,0,.091),(.838,0,.113),.017,black,16)
# Bottle hangs back from the brass head. Build rings along a tilted axis.
neck=Vector((.817,0,.035));axis=Vector((-.34,0,-.94)).normalized();u=Vector((0,1,0));v=axis.cross(u).normalized()
cyl('Bottle brass elbow',neck,neck+axis*.040,.014,brass,16)
cyl('Bottle threaded black cap',neck+axis*.028,neck+axis*.060,.026,black,24)
rings=[(.054,.020),(.069,.025),(.081,.033),(.106,.044),(.206,.049),(.229,.043),(.235,.029)]
verts=[];faces=[];N=32
for d,r in rings:
 for j in range(N):
  pos=neck+axis*d+(u*math.cos(j*math.tau/N)+v*math.sin(j*math.tau/N))*r;verts.append(tuple(pos))
for i in range(len(rings)-1):
 for j in range(N):faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
faces.extend([tuple(reversed(range(N))),tuple((len(rings)-1)*N+j for j in range(N))])
mesh=bpy.data.meshes.new('Foam bottle ring mesh');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Foam reservoir bottle',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,blue)
# Molded ribs around reservoir, reinforcing its reference silhouette.
for i,d in enumerate([.110,.133,.156,.179,.202]):
 center=neck+axis*d
 bpy.ops.mesh.primitive_torus_add(major_radius=.0465,minor_radius=.0013,major_segments=32,minor_segments=6,location=center)
 o=bpy.context.object;o.rotation_euler=axis.to_track_quat('Z','Y').to_euler();finish(o,'Bottle molded rib %02d'%i,blue)
# Supply hose connection points down/back from the grip.
cyl('Hose inlet brass',(-.034,0,-.109),(-.055,0,-.154),.014,brass,12)
cyl('Hose inlet rubber cuff',(-.052,0,-.146),(-.083,0,-.200),.018,black,20)
# Consolidate gun to a single mesh with named material slots; separate hose asset.
for o in bpy.context.selected_objects:o.select_set(False)
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join();gun=bpy.context.object;gun.name='crimson_pressure_washer';bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');gun.select_set(False)
parts.clear()
hose=tube('crimson_pressure_hose',[(-.081,0,-.194),(-.23,.02,-.40),(-.60,.10,-.68),(-1.18,.22,-.76),(-1.80,.30,-.55),(-2.25,.40,-.20),(-2.70,.40,-.12)],.008,black)
hose.select_set(False)
# Export editable source and portable interchange before adding presentation scene.
gun.select_set(True);bpy.context.view_layer.objects.active=gun
bpy.ops.wm.obj_export(filepath=str(OUT/'crimson_pressure_washer.obj'),export_selected_objects=True,export_materials=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'crimson_pressure_washer.glb'),export_format='GLB',use_selection=True)
gun.select_set(False);hose.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'crimson_pressure_hose.glb'),export_format='GLB',use_selection=True)
hose.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'crimson_pressure_washer.blend'))
# Render on a dark ground, camera shows the trigger silhouette and hanging bottle.
groundmat=material('Preview ground',(.035,.043,.052),.05,.65)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.81));ground=bpy.context.object;ground.data.materials.append(groundmat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.world.color=(.14,.14,.14)
def area(name,loc,energy,size,color):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector((.25,0,-.05))-o.location).to_track_quat('-Z','Y').to_euler()
area('Large soft key',(.4,-2.0,2.3),380,3,(1,.91,.78));area('Cool rim',(1.0,1.5,1.1),330,2,(.65,.82,1));area('Fill',(-1.7,-.4,.8),120,2,(.85,.91,1))
bpy.ops.object.camera_add(location=(1.55,-2.6,1.02));cam=bpy.context.object;cam.rotation_euler=(Vector((.24,0,-.13))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.55;scene.camera=cam
# Hide the long sample hose in close-up, retain visible end curl.
hose.hide_render=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'preview.png')
bpy.ops.render.render(write_still=True)
print('MODEL_COMPLETE',len(gun.data.vertices),'vertices',len(gun.data.polygons),'faces')
