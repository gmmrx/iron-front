"""Dress the user's existing Survivor; never replace or edit the source body/rig."""
import bpy, bmesh, math, json, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/prototypes/turkish_survivor_v01'
OUT.mkdir(parents=True,exist_ok=True)
TEX=OUT/'textures'; TEX.mkdir(exist_ok=True)
SRC=Path('/Users/bugra/Desktop/work/topdown-shoow/assets/aa/CHAR_Survivor.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))
scene=bpy.context.scene
body=bpy.data.objects['CHAR_Survivor']
rig=bpy.data.objects['RIG_Survivor']
rig.data.pose_position='REST'
scene.frame_set(0)
bpy.context.view_layer.update()
original_positions=[tuple(v.co) for v in body.data.vertices]
original_weights=[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]
parts=[]
cloth_collection=bpy.data.collections.new('UNIFORM_ONLY'); scene.collection.children.link(cloth_collection)
studio=bpy.data.collections.new('STUDIO_NOT_EXPORTED'); scene.collection.children.link(studio)
kd=KDTree(len(body.data.vertices))
for v in body.data.vertices: kd.insert(body.matrix_world@v.co,v.index)
kd.balance()
base_bvh=BVHTree.FromPolygons([body.matrix_world@v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
def linear(v):
    v=v/255
    return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
def mat(name,rgb,rough=.8,metal=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*[linear(c) for c in rgb],1)
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=metal
    return m
M={
 'wool':mat('Uniform / khaki wool',(124,116,83)),
 'seam':mat('Uniform / seam',(102,94,66)),
 'thread':mat('Uniform / topstitch',(150,137,101)),
 'leather':mat('Equipment / brown leather',(69,44,29),.57),
 'edge':mat('Equipment / edge leather',(99,66,43),.6),
 'boot':mat('Boot / dark brown leather',(48,36,28),.57),
 'sole':mat('Boot / sole',(28,25,22),.9),
 'brass':mat('Hardware / worn brass',(120,105,66),.43,.65),
 'red':mat('Collar / muted red',(114,37,27)),
}
def move(obj,coll):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    coll.objects.link(obj)
def active(obj):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
def apply(obj,mod):
    active(obj); bpy.ops.object.modifier_apply(modifier=mod.name)
def finish(obj,material):
    move(obj,cloth_collection)
    obj.data.materials.clear(); obj.data.materials.append(M[material])
    for p in obj.data.polygons: p.use_smooth=True
    parts.append(obj)
    return obj
def mesh(name,verts,faces,material):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    obj=bpy.data.objects.new(name,me); scene.collection.objects.link(obj)
    return finish(obj,material)
def bind(obj,bone=None):
    # Interpolated source weights, using the original unmoved body as donor.
    obj.vertex_groups.clear()
    groups={g.name:obj.vertex_groups.new(name=g.name) for g in body.vertex_groups}
    for v in obj.data.vertices:
        if bone:
            groups[bone].add([v.index],1,'REPLACE'); continue
        weights={}
        for _,index,d in kd.find_n(obj.matrix_world@v.co,4):
            fac=1/max(d,.003)**3
            for g in body.data.vertices[index].groups:
                name=body.vertex_groups[g.group].name
                weights[name]=weights.get(name,0)+fac*g.weight
        top=sorted(weights.items(),key=lambda p:-p[1])[:4]
        total=sum(v for _,v in top)
        for name,w in top: groups[name].add([v.index],w/total,'REPLACE')
    mod=obj.modifiers.new('Original Survivor skeleton','ARMATURE'); mod.object=rig
    obj.parent=rig
def shell(name,planes,inflate,material,largest=False):
    ob=body.copy(); ob.data=body.data.copy(); ob.name=name
    ob.animation_data_clear(); ob.modifiers.clear(); ob.parent=None
    scene.collection.objects.link(ob)
    bm=bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00005)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for co,no,outer in planes:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=co,plane_no=no,clear_outer=outer,clear_inner=not outer)
    if largest:
        unseen=set(bm.verts); islands=[]
        while unseen:
            todo=[unseen.pop()]; island=set(todo)
            while todo:
                v=todo.pop()
                for e in v.link_edges:
                    n=e.other_vert(v)
                    if n in unseen: unseen.remove(n); island.add(n); todo.append(n)
            islands.append(island)
        keep=max(islands,key=len)
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v not in keep],context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    smooth=ob.modifiers.new('Tailored cloth smoothing','SMOOTH'); smooth.factor=.5; smooth.iterations=8; apply(ob,smooth)
    # Move along smoothed normals: garment is not a retextured nude body.
    for v in ob.data.vertices:
        v.co+=v.normal*inflate
    ob.data.update()
    finish(ob,material)
    return ob
def solid(ob,thickness=.003):
    mod=ob.modifiers.new('Real fabric thickness','SOLIDIFY'); mod.thickness=thickness; mod.offset=0; apply(ob,mod)
def sub(ob,levels=1):
    mod=ob.modifiers.new('Cloth surface','SUBSURF'); mod.levels=levels; apply(ob,mod)
def bevel(ob,amount=.002):
    mod=ob.modifiers.new('Rounded manufactured edge','BEVEL'); mod.width=amount; mod.segments=3; apply(ob,mod)
def box(name,loc,size,material,amount=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object; ob.name=name; ob.scale=size
    active(ob); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(ob,material); bevel(ob,amount)
    return ob
def line(name,points,radius,material,bone=None):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.bevel_depth=radius; cu.bevel_resolution=2
    sp=cu.splines.new('POLY'); sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points): p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu); scene.collection.objects.link(ob); active(ob); bpy.ops.object.convert(target='MESH')
    finish(ob,material); bind(ob,bone); return ob
def loft(name,rings,material,n=48):
    verts=[]
    for z,x,y,rx,ry in rings:
        for j in range(n):
            a=j*2*math.pi/n; verts.append((x+rx*math.sin(a),y+ry*math.cos(a),z))
    faces=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(rings)-1) for j in range(n)]
    return mesh(name,verts,faces,material)

# Garment is cut from this exact character, with neck and wrist openings.
planes=[((0,0,.865),(0,0,1),False),((0,0,1.475),(0,0,1),True)]
for sign in [-1,1]:
    elbow=Vector((sign*.295,.007,1.155)); wrist=Vector((sign*.407,-.103,.868))
    planes.append((elbow.lerp(wrist,.89), (wrist-elbow).normalized(),True))
jacket=shell('Tunic | fitted to original body',planes,.024,'wool',True)
# Lower tunic flare and suppress abdominal definition without changing the body.
for v in jacket.data.vertices:
    x,y,z=v.co
    if abs(x)<.245 and z<1.19:
        min_depth=.124 if y<0 else .102
        factor=max(0,1-(abs(x)/.245)**3)
        if y<0: v.co.y=min(y,-min_depth*factor)
        else: v.co.y=max(y,min_depth*factor)
    if .865<z<.99:
        v.co.x*=1+.09*(.99-z)/.125
sub(jacket,1); solid(jacket); bind(jacket)

pants=shell('Trousers | original silhouette with cloth ease',[((0,0,.13),(0,0,1),False),((0,0,1.01),(0,0,1),True)],.027,'wool',True)
for v in pants.data.vertices:
    x,y,z=v.co
    # Slight breeches fullness around upper thigh, taper below knee.
    if .42<z<.78:
        side=1 if x>0 else -1
        center=side*(.108+(.83-z)*.12)
        v.co.x=center+(x-center)*1.13
        v.co.y=(y-.01)*1.10+.01
sub(pants); solid(pants); bind(pants)

# BVH after cloth construction places details on the actual fitted shell.
jmesh=jacket.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
jbvh=BVHTree.FromPolygons([jacket.matrix_world@v.co for v in jmesh.vertices],[list(p.vertices) for p in jmesh.polygons])
def front(x,z,offset=.004):
    hit=jbvh.ray_cast(Vector((x,-1,z)),Vector((0,1,0)))[0]
    return (x,(hit.y if hit else -.13)-offset,z)
def patch(name,x0,x1,z0,z1,material,bulge=.003):
    verts=[]; nx=6; nz=8
    for j in range(nz+1):
        v=j/nz; z=z0+(z1-z0)*v
        for i in range(nx+1):
            u=i/nx; x=x0+(x1-x0)*u
            verts.append(front(x,z,.004+bulge*math.sin(math.pi*u)*math.sin(math.pi*v)))
    faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(nz) for i in range(nx)]
    ob=mesh(name,verts,faces,material); solid(ob,.0018); bind(ob); return ob
patch('Tunic | center button placket',-.014,.014,.88,1.423,'wool',.001)
for i,z in enumerate([1.38,1.30,1.22,1.14,1.065,.95]):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=front(0,z,.010))
    ob=bpy.context.object; ob.name='Tunic | button %02d'%i; ob.scale=(.0045,.002,.0045)
    active(ob); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); finish(ob,'brass'); bind(ob)
for sign in [-1,1]:
    x0,x1=sorted((sign*.038,sign*.134))
    patch('Tunic | breast pocket',x0,x1,1.212,1.318,'wool',.006)
    patch('Tunic | breast pocket flap',x0-.002,x1+.002,1.285,1.322,'wool',.007)
    for x in [x0+.004,x1-.004]:
        line('Pocket | fine topstitch',[front(x,1.218+t*.066,.008) for t in [i/16 for i in range(17)]],.00055,'thread')
    x0,x1=sorted((sign*.055,sign*.161))
    patch('Tunic | lower pocket flap',x0,x1,.923,.963,'wool',.007)
    # Collar polygon follows original neck, short instead of oversized collar blocks.
    verts=[(sign*.014,-.104,1.425),(sign*.066,-.085,1.464),(sign*.087,-.099,1.421),(sign*.049,-.133,1.399)]
    ob=mesh('Tunic | collar leaf',verts,[(0,1,2,3)],'wool'); solid(ob,.004); bevel(ob,.002); bind(ob)
    verts=[(sign*.038,-.118,1.429),(sign*.061,-.101,1.446),(sign*.071,-.111,1.426),(sign*.049,-.131,1.412)]
    ob=mesh('Tunic | red collar tab',verts,[(0,1,2,3)],'red'); solid(ob,.001); bind(ob)

# Waist belt follows body cross-section, with small buckle and keepers.
belt=loft('Equipment | leather waist belt',[(1.006,0,.002,.190,.153),(1.045,0,.002,.190,.153)],'leather')
solid(belt,.004); bind(belt)
for x in [-.023,.023]: bind(box('Belt | buckle side',(x,-.158,1.026),(.004,.006,.038),'brass'))
for z in [1.008,1.044]: bind(box('Belt | buckle rail',(0,-.158,z),(.047,.006,.004),'brass'))
bind(box('Belt | buckle tongue',(0,-.162,1.026),(.031,.003,.002),'brass',.0008))
for sign in [-1,1]:
    for index in range(3):
        x=sign*(.062+index*.036)
        y=-.153*math.sqrt(max(.1,1-(x/.197)**2))-.022
        bind(box('Equipment | cartridge pouch',(x,y,1.015),(.032,.033,.069),'leather',.005))
        bind(box('Equipment | pouch flap',(x,y-.017,1.039),(.034,.005,.027),'edge',.004))

# Footwear is clothing around the existing feet, not replacement legs.
for sign,label in [(-1,'R'),(1,'L')]:
    ankle=Vector((sign*.182,.052,0)); forward=Vector((sign*.21,-.978,0))
    across=Vector((.978,sign*.21,0))
    def shoe(name,rings,material):
        verts=[]; n=48
        for z,rx,ry,shift in rings:
            for j in range(n):
                a=2*math.pi*j/n
                pos=ankle+across*(rx*math.sin(a))+forward*(shift+ry*math.cos(a)); pos.z=z
                verts.append(tuple(pos))
        faces=[tuple(reversed(range(n)))]
        faces += [(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(rings)-1) for j in range(n)]
        ob=mesh(name+' '+label,verts,faces,material); bevel(ob,.002); bind(ob); return ob
    shoe('Boot | leather upper',[(.024,.059,.129,.055),(.045,.061,.133,.055),(.078,.060,.130,.050),(.10,.057,.105,.035),(.133,.050,.078,.008),(.16,.047,.058,0),(.24,.052,.056,0),(.248,.052,.056,0)],'boot')
    shoe('Boot | stitched sole',[(.006,.063,.139,.055),(.023,.063,.139,.055),(.027,.061,.136,.055)],'sole')
    for j in range(5):
        z=.125+j*.022
        pts=[]
        for offset in [-.018,.018]:
            p=ankle+across*offset+forward*(.077 if j==0 else .059); p.z=z; pts.append(tuple(p))
        line('Boot | lace',pts,.0015,'edge')
    # Puttees, modest cloth band above ankle boot.
    ob=loft('Puttee '+label,[(.227,sign*.18,.051,.058,.063),(.245,sign*.178,.051,.059,.063),(.30,sign*.17,.05,.063,.067),(.37,sign*.163,.046,.069,.073)],'seam')
    solid(ob,.003); bind(ob)
    for j in range(6):
        z=.244+j*.021; x=sign*(.178-(z-.245)*.13); rx=.059+(z-.245)*.09; ry=rx+.004
        pts=[(x+rx*math.sin(a),.05+ry*math.cos(a),z+.003*math.sin(a)) for a in [k*2*math.pi/48 for k in range(49)]]
        line('Puttee | wrapping edge',pts,.0009,'wool')

# Compact soft field cap, fitted around the existing skull.
cap=loft('Field cap | crown',[(1.685,0,-.055,.090,.110),(1.696,0,-.055,.092,.112),(1.748,0,-.05,.088,.104),(1.773,0,-.05,.061,.073),(1.787,0,-.05,.001,.001)],'wool')
sub(cap); solid(cap); bind(cap,'Head')
band=loft('Field cap | band',[(1.68,0,-.055,.091,.112),(1.704,0,-.055,.093,.113)],'seam'); solid(band); bind(band,'Head')
verts=[]; n=32
for radius in [0,1]:
    for i in range(n+1):
        a=-1.05+2.1*i/n
        verts.append((math.sin(a)*(.091+radius*.013),-.055-math.cos(a)*(.112+radius*.035),1.684-radius*.009))
faces=[(i,i+1,n+2+i,n+1+i) for i in range(n)]
visor=mesh('Field cap | short cloth visor',verts,faces,'wool'); solid(visor,.003); bevel(visor,.001); bind(visor,'Head')

# Render material microstructure; clothing PBR maps are baked for export below.
for key in ['wool','seam','leather','edge','boot']:
    m=M[key]; nd=m.node_tree.nodes; lk=m.node_tree.links; bs=nd.get('Principled BSDF')
    noise=nd.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=330 if key in ['wool','seam'] else 160
    noise.inputs['Detail'].default_value=2
    bump=nd.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.17; bump.inputs['Distance'].default_value=.00035
    lk.new(noise.outputs['Fac'],bump.inputs['Height']); lk.new(bump.outputs['Normal'],bs.inputs['Normal'])

# Keep the complete original body untouched and preserve all source clips.
assert original_positions==[tuple(v.co) for v in body.data.vertices]
assert original_weights==[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]
for img in list(bpy.data.images):
    if img.size[0]>1 and img.name not in ['Render Result','Viewer Node']:
        img.pixels[0]; img.filepath_raw=str(TEX/(img.name+'.png')); img.file_format='PNG'; img.save(); img.pack()

def aim(ob,target): ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES'; scene.cycles.samples=48
scene.render.resolution_x=1200; scene.render.resolution_y=1500; scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral studio'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.17,.20,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
scene.view_settings.view_transform='AgX'
for pos,power,size in [((3,-4,5),400,4),((-3,-2,3),260,3),((1,3,4),550,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos); ob=bpy.context.object; move(ob,studio)
    ob.data.energy=power; ob.data.shape='DISK'; ob.data.size=size; aim(ob,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200); ground=bpy.context.object; ground.name='Studio ground'; ground.location.z=-.01; move(ground,studio)
ground.data.materials.append(mat('Studio neutral',(48,54,59)))
bpy.ops.object.camera_add(location=(2.5,-5,2.4)); cam=bpy.context.object; move(cam,studio); scene.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=2.03; aim(cam,(0,0,.9))
scene.render.filepath=str(OUT/'preview_three_quarter.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'turkish_survivor_v01.blend'))
bpy.ops.render.render(write_still=True)
cam.location=(0,-5,1.6); aim(cam,(0,0,.9)); scene.render.filepath=str(OUT/'preview_front.png'); bpy.ops.render.render(write_still=True)
stats={'source':str(SRC),'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'body_unchanged':True,'source_vertices':len(body.data.vertices),'bones':len(rig.data.bones),'animations':[a.name for a in bpy.data.actions],'clothing_objects':len(parts),'clothing_vertices':sum(len(p.data.vertices) for p in parts)}
(OUT/'validation.json').write_text(json.dumps(stats,indent=2))
print(json.dumps(stats,indent=2))
