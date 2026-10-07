import bpy, json, os
from mathutils import Vector
OUT = '/Users/bugra/Desktop/work/history-strategy/art/prototypes/turkish_survivor_v01'
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath='/Users/bugra/Desktop/work/topdown-shoow/assets/aa/CHAR_Survivor.glb')
report = []
for obj in bpy.context.scene.objects:
    row = dict(name=obj.name, type=obj.type, location=list(obj.location), dimensions=list(obj.dimensions))
    if obj.type == 'MESH':
        row.update(vertices=len(obj.data.vertices), materials=[m.name for m in obj.data.materials], bounds=[list(obj.matrix_world@Vector(c)) for c in obj.bound_box])
        row['matrix']= [list(r) for r in obj.matrix_world]
        row['raw_bounds']=[[min(v.co[i] for v in obj.data.vertices),max(v.co[i] for v in obj.data.vertices)] for i in range(3)]
    if obj.type == 'ARMATURE':
        row['bones'] = {b.name: [list(b.head_local), list(b.tail_local)] for b in obj.data.bones}
        obj.data.pose_position = 'REST'
    report.append(row)
print(json.dumps(report, indent=2))
print('ACTIONS', [(a.name,list(a.frame_range)) for a in bpy.data.actions])
for img in bpy.data.images:
    print('IMAGE',img.name,list(img.size))
    if img.size[0] > 1:
        img.save_render(os.path.join(OUT, 'source_'+img.name.split('.')[0]+'.png'))
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.render.resolution_x=1000
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.world.color=(.3,.3,.3)
def aim(obj, target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for pos,power,size in [((3,-4,5),450,4),((-3,-2,3),300,3),((1,3,4),500,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    bpy.context.object.data.energy=power
    bpy.context.object.data.shape='DISK'
    bpy.context.object.data.size=size
    aim(bpy.context.object,(0,0,1))
bpy.ops.object.camera_add(location=(2.6,-5,2.5))
scene.camera=bpy.context.object
scene.camera.data.type='ORTHO'
scene.camera.data.ortho_scale=2.4
aim(scene.camera,(0,0,.9))
scene.render.filepath=OUT+'/source_preview.png'
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source_inspection.blend')
bpy.ops.render.render(write_still=True)
