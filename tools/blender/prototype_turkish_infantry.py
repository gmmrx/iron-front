"""Reference-informed volumetric Turkish infantry prototype, isolated from game assets.

Blender 5.x: blender -b --factory-startup -P tools/blender/prototype_turkish_infantry.py
Not automatic photogrammetry: manually authored silhouettes + image-projected albedo.
"""
import math
import json
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/prototypes/turkish_infantry_v01'
TEX = OUT / 'textures'
REF = ROOT / 'art/references/ww2/001_turkish_infantry_1939/turnaround_v01.png'
OUT.mkdir(parents=True, exist_ok=True)
TEX.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
model = bpy.data.collections.new('TUR_1939_REFERENCE_PROTOTYPE')
scene.collection.children.link(model)
studio = bpy.data.collections.new('STUDIO_NOT_EXPORTED')
scene.collection.children.link(studio)
parts = []


def linear(c):
    c = c / 255.0
    return c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4


def color(rgb):
    return (*[linear(c) for c in rgb], 1)


source = bpy.data.images.load(str(REF))
source.name = 'TUR_001_source_projection'
source.pixels[0]  # Force lazy image decoding before changing the destination path.
source.filepath_raw = str(TEX / 'reference_albedo.png')
source.file_format = 'PNG'
source.save()


def material(name, rgb, rough=.75, metal=0, texture=False, grain=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    links = m.node_tree.links
    bs = n.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = color(rgb)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    if texture:
        im = n.new('ShaderNodeTexImage')
        im.image = source
        im.interpolation = 'Linear'
        links.new(im.outputs['Color'], bs.inputs['Base Color'])
    if grain:
        noise = n.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 220 if name.startswith('Wool') else 140
        noise.inputs['Detail'].default_value = 2
        bump = n.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .18
        bump.inputs['Distance'].default_value = grain
        links.new(noise.outputs['Fac'], bump.inputs['Height'])
        links.new(bump.outputs['Normal'], bs.inputs['Normal'])
    return m


mats = {
    'cloth_photo': material('Wool_reference_albedo', (129,116,85), .88, texture=True, grain=.00045),
    'skin_photo': material('Skin_reference_albedo', (191,148,117), .61, texture=True, grain=.00012),
    'cloth': material('Wool_khaki', (129,117,88), .88, grain=.00045),
    'cloth_dark': material('Wool_seam', (106,94,68), .9),
    'puttee': material('Woven_puttee', (126,116,88), .88, grain=.0004),
    'leather': material('Leather_brown', (82,55,39), .52, grain=.0003),
    'leather_edge': material('Leather_edge', (106,74,53), .56),
    'boot': material('Leather_boot', (67,50,40), .46, grain=.0002),
    'sole': material('Boot_sole', (38,31,27), .86),
    'skin': material('Skin_hands', (173,134,106), .67, grain=.00012),
    'brass': material('Aged_brass', (127,108,68), .43, .72),
    'steel': material('Dark_steel', (65,65,57), .5, .65),
    'red': material('Collar_red', (114,44,34), .85),
    'canteen': material('Canteen_canvas', (104,104,79), .86, grain=.0004),
    'thread': material('Seam_thread', (154,138,103), .9),
}


def put_in(ob, collection):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    collection.objects.link(ob)


def finish(ob, mat, subdiv=0, bevel=0):
    put_in(ob, model)
    ob.data.materials.append(mats[mat])
    for p in ob.data.polygons:
        p.use_smooth = True
    if bevel:
        mod = ob.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
    if subdiv:
        mod = ob.modifiers.new('Surface refinement', 'SUBSURF')
        mod.levels = subdiv
        mod.render_levels = subdiv
    parts.append(ob)
    return ob


def mesh(name, verts, faces, mat, subdiv=0):
    me = bpy.data.meshes.new(name + '_mesh')
    me.from_pydata(verts, [], faces)
    me.update()
    # Recalculate closed-surface normals before choosing projected texture side.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return finish(ob, mat, subdiv)


def loft(name, rings, mat, segments=48, wrinkles=0, subdiv=1):
    """Horizontal elliptical rings: z, x, y, radius_x, radius_y."""
    verts = []
    for ri, (z, x, y, rx, ry) in enumerate(rings):
        for j in range(segments):
            a = 2 * math.pi * j / segments
            fold = wrinkles * math.sin(a * 7 + z * 34) * math.sin(z * 23)
            verts.append((x + (rx + fold) * math.sin(a), y + (ry + fold*.65) * math.cos(a), z))
    faces = []
    for i in range(len(rings)-1):
        for j in range(segments):
            a = i*segments+j
            b = i*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces += [tuple(range(segments-1,-1,-1)), tuple((len(rings)-1)*segments+j for j in range(segments))]
    return mesh(name, verts, faces, mat, subdiv)


def tube(name, centers, radii, mat, segments=24, subdiv=1, wrinkle=0):
    verts=[]
    for i, p in enumerate(centers):
        p=Vector(p)
        tangent=Vector(centers[min(i+1,len(centers)-1)])-Vector(centers[max(i-1,0)])
        tangent.normalize()
        u=tangent.cross(Vector((0,1,0))).normalized()
        v=tangent.cross(u).normalized()
        rx,ry=radii[i] if isinstance(radii[i],tuple) else (radii[i],radii[i])
        for j in range(segments):
            a=j*2*math.pi/segments
            f=wrinkle*math.sin(a*5+i*2.2)
            verts.append(tuple(p+u*(rx+f)*math.cos(a)+v*(ry+f)*math.sin(a)))
    faces=[]
    for i in range(len(centers)-1):
        for j in range(segments):
            a=i*segments+j;b=i*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces += [tuple(range(segments-1,-1,-1)),tuple((len(centers)-1)*segments+j for j in range(segments))]
    return mesh(name,verts,faces,mat,subdiv)


def box(name, center, size, mat, bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob=bpy.context.object;ob.name=name
    ob.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,mat,bevel=bevel)


def ellipsoid(name, center, size, mat, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=20,location=center)
    ob=bpy.context.object;ob.name=name;ob.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,mat)


def curve(name, points, radius, mat):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=16
    cu.bevel_depth=radius;cu.bevel_resolution=3
    spline=cu.splines.new('POLY');spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bpy.ops.object.convert(target='MESH');ob.select_set(False)
    return finish(ob,mat)


def ribbon(name, points, width, mat, normal=(0,-1,0), thickness=.003):
    verts=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        side=tangent.cross(Vector(normal)).normalized()*width/2
        verts.extend([tuple(Vector(p)-side),tuple(Vector(p)+side)])
    ob=mesh(name,verts,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(points)-1)],mat)
    mod=ob.modifiers.new('Leather thickness','SOLIDIFY');mod.thickness=thickness
    mod=ob.modifiers.new('Rounded strap edges','BEVEL');mod.width=.0012;mod.segments=2
    return ob


# Uniform torso. Rings follow front-reference landmarks; depth is manually inferred.
loft('Tunic',[(.825,0,0,.219,.125),(.835,0,0,.224,.129),(.87,0,0,.22,.126),(.96,0,0,.202,.118),(1.055,0,0,.185,.108),(1.085,0,0,.185,.11),(1.15,0,0,.195,.119),(1.25,0,0,.199,.122),(1.34,0,0,.205,.115),(1.405,0,0,.19,.097),(1.446,0,0,.147,.083),(1.482,0,0,.061,.058)],'cloth_photo',wrinkles=.003)

# Legs, cloth folds, wrapped puttees and shaped boot volumes.
for s,side in [(-1,'R'),(1,'L')]:
    rings=[(.405,s*.18,0,.06,.062),(.425,s*.177,0,.073,.069),(.45,s*.174,0,.082,.077),(.485,s*.168,0,.079,.083),(.53,s*.16,0,.088,.086),(.60,s*.15,0,.096,.085),(.67,s*.142,0,.105,.092),(.76,s*.133,0,.112,.10),(.85,s*.124,0,.105,.10),(.925,s*.112,0,.10,.10)]
    loft('Trousers_'+side,rings,'cloth_photo',wrinkles=.006)
    puttee=[]
    for i in range(30):
        z=.155+i*(.264/29)
        r=.047+((z-.155)/.264)*.015
        puttee.append((z,s*.183,0,r,r*.98))
    loft('Puttee_'+side,puttee,'cloth_photo',subdiv=0)
    spiral=[]
    for i in range(480):
        t=i/479;a=t*2*math.pi*10;z=.157+t*.26;r=.048+t*.015
        spiral.append((s*.183+r*math.sin(a),r*math.cos(a),z))
    curve('Puttee_wrap_edge_'+side,spiral,.0009,'puttee')
    loft('Boot_'+side,[(.022,s*.184,-.027,.062,.122),(.037,s*.184,-.029,.064,.12),(.065,s*.184,-.034,.061,.115),(.088,s*.184,-.035,.059,.105),(.115,s*.184,-.015,.052,.082),(.145,s*.184,.0,.048,.055),(.18,s*.184,0,.047,.049)],'boot',segments=48)
    loft('Sole_'+side,[(.006,s*.184,-.027,.063,.123),(.009,s*.184,-.027,.064,.124),(.025,s*.184,-.027,.064,.123),(.03,s*.184,-.027,.062,.121)],'sole',segments=48)
    for i in range(6):
        z=.092+i*.012;y=-.095+i*.008
        curve('Boot_lace_'+side+str(i),[(s*.184-.019,y,z),(s*.184+.019,y-.003,z+.009)],.00125,'leather_edge')

# Sleeves: one continuous loft per arm rather than intersecting cylinder segments.
for s,side in [(-1,'R'),(1,'L')]:
    c=[(s*.185,0,1.409),(s*.22,-.001,1.36),(s*.27,-.005,1.285),(s*.324,-.009,1.212),(s*.359,-.012,1.16),(s*.404,-.014,1.103),(s*.452,-.016,1.035),(s*.48,-.017,1.005)]
    r=[(.075,.089),(.081,.084),(.075,.074),(.066,.068),(.064,.065),(.059,.058),(.05,.052),(.047,.048)]
    tube('Sleeve_'+side,c,r,'cloth_photo',segments=40,wrinkle=.0026)
    tube('Cuff_'+side,[c[-2],c[-1],(s*.486,-.017,.996)],[r[-2],r[-1],(.048,.049)],'cloth_photo',segments=32)
    # Palms and five separate articulated finger-shaped volumes, relaxed A-pose.
    axis=Vector((s*.39,0,-.921));across=Vector((s*.921,0,.39))
    wrist=Vector((s*.489,-.015,.989));palm=wrist+axis*.052
    tube('Palm_'+side,[tuple(wrist),tuple(wrist+axis*.026),tuple(palm),tuple(palm+axis*.029)],[(.024,.02),(.031,.021),(.033,.021),(.028,.018)],'skin',segments=24)
    for fi,(offset,length) in enumerate([(-.024,.061),(-.008,.071),(.009,.067),(.024,.05)]):
        start=palm+axis*.024+across*offset
        end=start+axis*length+Vector((0,-.008,0))
        tube('Finger_'+side+str(fi),[tuple(start),tuple(start+axis*length*.4),tuple(start+axis*length*.75+Vector((0,-.004,0))),tuple(end),tuple(end+axis*.003)],[.008,.0075,.0064,.0055,.002],'skin',segments=14)
        nail=ellipsoid('Nail_'+side+str(fi),tuple(end-axis*.005+Vector((0,-.004,0))),(.004,.001,.006),'skin',seg=12)
    t0=palm-across*.027-axis*.018;t1=t0-across*.024+axis*.025;t2=t1+axis*.034
    tube('Thumb_'+side,[tuple(t0),tuple(t1),tuple(t2)],[.011,.009,.0045],'skin',segments=16)

loft('Neck',[(1.455,0,.005,.051,.052),(1.49,0,.005,.052,.054),(1.53,0,.003,.048,.052)],'skin_photo')

# Anatomically shaped head surface with actual nose/cheek/eye-socket depth.
headrings=[(1.492,.031,.034),(1.509,.043,.049),(1.527,.058,.064),(1.548,.069,.073),(1.574,.076,.079),(1.602,.079,.083),(1.627,.077,.081),(1.651,.076,.078),(1.677,.071,.073),(1.7,.059,.063),(1.718,.035,.039),(1.725,.006,.008)]
vs=[];fs=[];seg=64
for z,rx,ry in headrings:
    for j in range(seg):
        a=j*2*math.pi/seg;x=rx*math.sin(a);y=ry*math.cos(a)
        front=max(0,-math.cos(a))**5
        nose=.028*math.exp(-(x/.016)**2-((z-1.594)/.021)**2)+.014*math.exp(-(x/.012)**2-((z-1.626)/.03)**2)
        mouth=.007*math.exp(-(x/.031)**2-((z-1.55)/.011)**2)
        chin=.007*math.exp(-(x/.038)**2-((z-1.522)/.016)**2)
        sockets=sum(.006*math.exp(-((x-s*.034)/.019)**2-((z-1.636)/.012)**2) for s in (-1,1))
        y-=front*(nose+mouth+chin-sockets)
        vs.append((x,y,z))
for i in range(len(headrings)-1):
    for j in range(seg):fs.append((i*seg+j,i*seg+(j+1)%seg,(i+1)*seg+(j+1)%seg,(i+1)*seg+j))
fs += [tuple(range(seg-1,-1,-1)),tuple((len(headrings)-1)*seg+j for j in range(seg))]
mesh('Head_sculpted_volume',vs,fs,'skin_photo',2)
for s in (-1,1):
    ellipsoid('Ear_'+str(s),(s*.079,.003,1.607),(.014,.018,.029),'skin_photo')

# Soft field cap with folded band; no helmet, matching first Turkish reference.
cap=loft('Turkish_field_cap',[(1.664,0,0,.08,.09),(1.68,0,0,.082,.094),(1.7,0,0,.078,.096),(1.728,0,.003,.064,.093),(1.753,0,.003,.044,.077),(1.775,0,-.025,.012,.037)],'cloth_photo',segments=48,wrinkles=.0015)
for s in (-1,1):
    ribbon('Cap_fold_'+str(s),[(s*.068,-.066,1.693),(s*.081,-.02,1.682),(s*.077,.046,1.688),(s*.055,.078,1.702)],.026,'cloth',normal=(s,0,0),thickness=.002)

# Front placket and relief pockets; photo carries the matching large-scale cloth detail.
box('Button_placket',(0,-.123,1.247),(.023,.008,.314),'cloth_photo',.002)
for s in (-1,1):
    box('Breast_pocket_'+str(s),(s*.095,-.12,1.277),(.091,.012,.104),'cloth_photo',.004)
    box('Breast_flap_'+str(s),(s*.095,-.129,1.326),(.094,.007,.021),'cloth_photo',.002)
    box('Skirt_pocket_'+str(s),(s*.139,-.109,.929),(.092,.008,.099),'cloth_photo',.003)
    # Triangular red collar tabs backed by uniform cloth.
    verts=[(s*.022,-.062,1.483),(s*.085,-.07,1.442),(s*.047,-.091,1.405)]
    tab=mesh('Collar_'+str(s),verts,[(0,1,2)],'cloth',1)
    sol=tab.modifiers.new('Collar thickness','SOLIDIFY');sol.thickness=.004
    verts2=[(s*.034,-.072,1.466),(s*.07,-.077,1.439),(s*.048,-.095,1.419)]
    tab=mesh('Red_collar_tab_'+str(s),verts2,[(0,1,2)],'red')
    sol=tab.modifiers.new('Tab thickness','SOLIDIFY');sol.thickness=.001
for z in [1.395,1.31,1.223,1.135,.96]:
    ellipsoid('Tunic_button_'+str(z),(0,-.134,z),(.007,.0027,.007),'brass',seg=16)

# Actual leather belt and straps with independent volumes.
loft('Belt',[(1.054,0,0,.194,.12),(1.058,0,0,.197,.123),(1.105,0,0,.197,.123),(1.109,0,0,.194,.12)],'leather',segments=64,subdiv=0)
curve('Belt_upper_stitch',[(.197*math.sin(a),.124*math.cos(a),1.102) for a in [i*2*math.pi/100 for i in range(101)]],.0007,'leather_edge')
for s in (-1,1):
    ribbon('Front_suspenders_'+str(s),[(s*.143,-.018,1.444),(s*.135,-.095,1.39),(s*.13,-.125,1.30),(s*.129,-.13,1.20),(s*.133,-.126,1.105)],.025,'leather')
    ribbon('Shoulder_suspenders_'+str(s),[(s*.143,-.018,1.444),(s*.144,.035,1.446),(s*.126,.092,1.396),(s*.063,.121,1.337),(0,.129,1.293)],.026,'leather',normal=(0,1,0))
ribbon('Back_Y_strap',[(0,.129,1.293),(0,.126,1.20),(0,.124,1.105)],.027,'leather',normal=(0,1,0))
curve('Buckle', [(-.026,-.131,1.063),(.026,-.131,1.063),(.026,-.131,1.104),(-.026,-.131,1.104),(-.026,-.131,1.063)], .003,'brass')
curve('Buckle_tongue',[(0,-.134,1.063),(0,-.134,1.10)],.0018,'brass')
for s in (-1,1):
    for i in range(3):
        x=s*(.068+i*.044);y=-.125*math.sqrt(1-(x/.215)**2)-.022
        box('Ammo_pouch_'+str(s)+'_'+str(i),(x,y,1.081),(.041,.035,.085),'leather',.006)
        box('Pouch_flap_'+str(s)+'_'+str(i),(x,y-.012,1.119),(.043,.037,.021),'leather',.004)
        box('Pouch_tab_'+str(s)+'_'+str(i),(x,y-.021,1.09),(.008,.004,.038),'leather_edge',.001)
        ellipsoid('Pouch_stud_'+str(s)+'_'+str(i),(x,y-.025,1.08),(.0025,.0018,.0025),'brass',seg=12)

# Canteen fixed at one rear hip (reference views disagree; one placement chosen).
ellipsoid('Canteen_body',(.17,.12,.988),(.052,.035,.083),'canteen')
box('Canteen_neck',(.17,.122,1.065),(.02,.024,.029),'steel',.004)
ellipsoid('Canteen_cap',(.17,.122,1.083),(.014,.015,.009),'steel',seg=20)
ribbon('Canteen_retention',[(.17,.079,1.05),(.17,.081,.934),(.17,.151,.913),(.17,.159,1.04)],.012,'leather',normal=(1,0,0))


# Apply modeling modifiers, then give every mesh a UV map. Clothing/head project actual source.
# Front is -Y. Front/back UVs refer to the same source image, not independent invented renders.
for ob in parts:
    bpy.context.view_layer.objects.active=ob
    ob.select_set(True)
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.select_set(False)
    uv=ob.data.uv_layers.new(name='ReferenceUV')
    for poly in ob.data.polygons:
        worldnormal=ob.matrix_world.to_3x3()@poly.normal
        front=worldnormal.y<=0
        for li in poly.loop_indices:
            co=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co
            # 254 px/metre matches the 453 px tall reference figure.
            px=(207+co.x*254*.985) if front else (585-co.x*254*.985)
            py=465-co.z*254
            uv.data[li].uv=(px/1536,1-py/1024)


# Bake all visible materials to portable atlas images, including procedural grain normal.
all_materials=[]
for ob in parts:
    for m in ob.data.materials:
        if m not in all_materials:all_materials.append(m)
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
character=bpy.context.object;character.name='TUR_1939_Infantry_Textured'
character['provenance']='Manually authored volumetric mesh; photo-projected source 001 albedo, procedural gear materials. Not automatic photogrammetry.'
character['readiness']='Visual prototype; no rig/animation, no game LOD. Historical validation pending.'
character['reference']='art/references/ww2/001_turkish_infantry_1939/turnaround_v01.png'
reference_uv=character.data.uv_layers.get('ReferenceUV')
for m in all_materials:
    for node in list(m.node_tree.nodes):
        if node.type=='TEX_IMAGE':
            u=m.node_tree.nodes.new('ShaderNodeUVMap');u.uv_map='ReferenceUV'
            m.node_tree.links.new(u.outputs['UV'],node.inputs['Vector'])
atlas_uv=character.data.uv_layers.new(name='GameAtlasUV')
character.data.uv_layers.active=atlas_uv
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.008)
bpy.ops.object.mode_set(mode='OBJECT')
atlas_uv.active_render=True

scene.render.engine='CYCLES'
scene.cycles.samples=8
scene.cycles.device='CPU'
scene.render.bake.use_clear=True
scene.render.bake.margin=12
atlas_size=2048
images={}
for suffix,kind,colorspace in [('basecolor','DIFFUSE','sRGB'),('normal','NORMAL','Non-Color'),('roughness','ROUGHNESS','Non-Color')]:
    img=bpy.data.images.new('TUR_1939_'+suffix,width=atlas_size,height=atlas_size,alpha=False)
    img.colorspace_settings.name=colorspace
    for m in all_materials:
        nodes=m.node_tree.nodes
        target=nodes.new('ShaderNodeTexImage');target.name='BakeTarget_'+suffix;target.image=img
        for no in nodes:no.select=False
        target.select=True;nodes.active=target
    if kind=='DIFFUSE':
        scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
    print('BAKE',suffix,flush=True)
    bpy.ops.object.bake(type=kind)
    img.filepath_raw=str(TEX/f'turkish_infantry_{suffix}_2k.png');img.file_format='PNG';img.save()
    images[suffix]=img

portable=bpy.data.materials.new('TUR_1939_Baked_PBR');portable.use_nodes=True
nodes=portable.node_tree.nodes;links=portable.node_tree.links;bs=nodes.get('Principled BSDF')
for suffix in ['basecolor','roughness','normal']:
    node=nodes.new('ShaderNodeTexImage');node.image=images[suffix]
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map='GameAtlasUV';links.new(uvnode.outputs['UV'],node.inputs['Vector'])
    if suffix=='normal':
        nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.45
        links.new(node.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    else:links.new(node.outputs['Color'],bs.inputs['Base Color' if suffix=='basecolor' else 'Roughness'])
character.data.materials.clear();character.data.materials.append(portable)
for poly in character.data.polygons:poly.material_index=0

# Portable export contains only the volumetric soldier; studio is deliberately excluded.
bpy.ops.object.select_all(action='DESELECT');character.select_set(True)
bpy.context.view_layer.objects.active=character
bpy.ops.export_scene.gltf(filepath=str(OUT/'turkish_infantry_v01.glb'),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')

# Neutral studio renders are generated by Blender from the actual mesh, not imagegen.
scene.render.engine='CYCLES';scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=1500;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.world=bpy.data.worlds.new('Neutral studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.35,.4,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
floor_mat=material('Studio_floor',(54,59,62),.92)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.003));floor=bpy.context.object;floor.name='Studio_floor';floor.data.materials.append(floor_mat);put_in(floor,studio)

def light(name,loc,energy,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size
    ob=bpy.data.objects.new(name,d);studio.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-3,-4,5),360,4)
light('Fill',(3,-2,2.8),180,3)
light('Rim',(0,3,4),420,3)
camd=bpy.data.cameras.new('Inspection_camera');cam=bpy.data.objects.new('Inspection_camera',camd);studio.objects.link(cam);scene.camera=cam;camd.type='ORTHO';camd.ortho_scale=2.06

def camera(loc):
    cam.location=loc;cam.rotation_euler=(Vector((0,0,.91))-cam.location).to_track_quat('-Z','Y').to_euler()

stats={'mesh_vertices':len(character.data.vertices),'polygons':len(character.data.polygons),'triangles':sum(len(p.vertices)-2 for p in character.data.polygons),'height_metres':round(character.dimensions.z,3),'textures':[im.filepath_raw for im in images.values()],'rigged':False,'automated_image_to_3d':False,'method':'manual volume construction and reference albedo projection; procedural materials baked to 2K atlases'}
(OUT/'model_stats.json').write_text(json.dumps(stats,indent=2))
for name,loc in [('front',(0,-5,.94)),('three_quarter',(3,-5,2.2)),('rear',(-3,5,2.0))]:
    camera(loc);scene.render.filepath=str(OUT/f'preview_{name}.png')
    print('RENDER',name,flush=True);bpy.ops.render.render(write_still=True)
camera((3,-5,2.2))
for im in images.values():im.pack()
source.pack()
# Open on the model in material preview, not on a blank scene.
bpy.ops.object.select_all(action='DESELECT');character.select_set(True);bpy.context.view_layer.objects.active=character
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=2.8
            area.spaces.active.region_3d.view_location=(0,0,.9)
            area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'turkish_infantry_v01.blend'))
print('COMPLETE',json.dumps(stats),flush=True)
