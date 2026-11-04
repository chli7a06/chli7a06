import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'crimson_pressure_washer.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False;scene.world.color=(.14,.14,.14)
m=bpy.data.materials.new('Ground');m.diffuse_color=(.045,.05,.06,1)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.81));bpy.context.object.data.materials.append(m)
for loc,power,size in [((.5,-2,3),700,4),((-2,2,2),500,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((-.7,0,-.3))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.4,-4,2));cam=bpy.context.object;cam.rotation_euler=(Vector((-.8,.1,-.3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.3;scene.camera=cam
scene.render.resolution_x=1200;scene.render.resolution_y=750;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/'preview_with_hose.png');bpy.ops.render.render(write_still=True)
