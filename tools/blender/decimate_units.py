"""Muster (MIT, github.com/Kenton-GMI/muster-ww2) modellerini oyun için sadeleştirir.

Kullanım: blender -b -P decimate_units.py -- <girdi_klasörü> <çıktı.glb> <ad=hedef_üçgen> ...
Her girdi GLB tek mesh: vertex rengi (A = ülke rengi maskesi) ve UV (x = parça, y = gölge) korunur.
Tüm modeller tek GLB'de, adlarıyla ayrı mesh nesneleri olarak dışa aktarılır.
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
targets = {a.split("=")[0]: int(a.split("=")[1]) for a in argv[2:]}

bpy.ops.wm.read_factory_settings(use_empty=True)
for name, target in targets.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{src}/{name}.glb")
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    ob = new[0]
    ob.name = name
    ob.data.name = name
    ob.parent = None
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > target:
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = target / tris
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier="dec")
    after = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    me = ob.data
    if me.color_attributes:
        me.color_attributes.active_color = me.color_attributes[0]
        me.color_attributes.render_color_index = 0
    print(f"[decimate] {name}: {tris} -> {after}")

# boş parent/empty nesneleri sil
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_vertex_color="ACTIVE",
                          export_all_vertex_colors=True, export_materials="NONE", export_yup=True)
