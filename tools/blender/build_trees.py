"""
Harita ağaçları: 3 iğne yapraklı + 3 yaprak döken varyant (vertex renkli, düşük poligon).
    Blender --background --factory-startup --python tools/blender/build_trees.py -- [--render DIR]
Çıktı: assets/models/trees.glb  (düğümler: tree_0 .. tree_5; tür = varyant*2 + iğne(1)/yaprak(0))
Boy ~1 birim; oyunda ölçeklenir. Renk COLOR_0'da (tree.gdshader okur).
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def paint(bm, color_fn):
    layer = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for loop in f.loops:
            loop[layer] = (*color_fn(loop.vert.co, f.normal), 1.0)


def trunk(bm, h, r, rng):
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r, radius2=r * 0.6, depth=h)
    for v in geom["verts"]:
        v.co.z += h / 2


def conifer(seed):
    rng = random.Random(seed)
    bm = bmesh.new()
    trunk(bm, 0.22, 0.035, rng)
    tiers = rng.choice([4, 5])
    z = 0.12
    height = rng.uniform(0.95, 1.1)
    for i in range(tiers):
        t = i / (tiers - 1)
        r = (0.30 - 0.2 * t) * rng.uniform(0.9, 1.1)
        h = (height - 0.12) / tiers * 1.9
        geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=9, radius1=r, radius2=0.0, depth=h)
        for v in geom["verts"]:
            v.co.z += z + h / 2
            # dal uçlarını düzensizleştir
            if v.co.z < z + 0.02 and (v.co.x or v.co.y):
                ang = math.atan2(v.co.y, v.co.x)
                k = 1.0 + 0.18 * math.sin(ang * 3 + seed + i) + rng.uniform(-0.06, 0.06)
                v.co.x *= k
                v.co.y *= k
                v.co.z -= rng.uniform(0.0, 0.04)
        z += (height - 0.12) / tiers
    dark, mid, light = (0.05, 0.12, 0.06), (0.09, 0.2, 0.09), (0.18, 0.3, 0.13)

    def col(co, n):
        if co.z < 0.13 and math.hypot(co.x, co.y) < 0.05:
            return (0.22, 0.14, 0.08)
        t = min(max(co.z / height, 0), 1)
        c = lerp(dark, mid, t)
        sun = max(n.dot(Vector((0.5, -0.4, 0.75)).normalized()), 0.0)
        return lerp(c, light, sun * 0.45 * (0.5 + t * 0.5))
    paint(bm, col)
    return bm


def deciduous(seed, subdiv=2):
    rng = random.Random(seed)
    bm = bmesh.new()
    trunk(bm, 0.42, 0.045, rng)
    height = rng.uniform(0.85, 1.0)
    blobs = [(0.0, 0.0, 0.62, 0.30)]
    for _ in range(rng.randint(2, 3)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.12, 0.2)
        blobs.append((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.5, 0.72), rng.uniform(0.17, 0.23)))
    for bx, by, bz, br in blobs:
        geom = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=br)
        for v in geom["verts"]:
            p = v.co.copy()
            d = 1.0 + 0.22 * noise.noise(p * 7.0 + Vector((seed, seed * 2, 0)))
            v.co = Vector((p.x * d + bx, p.y * d + by, p.z * d * 0.85 + bz * height))
    dark, mid, light = (0.06, 0.15, 0.05), (0.13, 0.3, 0.08), (0.3, 0.48, 0.14)
    autumn = rng.random() < 0.12
    if autumn:
        mid, light = (0.26, 0.28, 0.07), (0.45, 0.42, 0.12)

    def col(co, n):
        if co.z < 0.42 and math.hypot(co.x, co.y) < 0.06:
            return (0.25, 0.17, 0.1)
        t = min(max((co.z - 0.3) / 0.6, 0), 1)
        c = lerp(dark, mid, t)
        sun = max(n.dot(Vector((0.5, -0.4, 0.75)).normalized()), 0.0)
        return lerp(c, light, sun * 0.55)
    paint(bm, col)
    return bm


def to_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    # renk katmanını etkin ve render katmanı yap (glTF COLOR_0 olarak dışa aktarılsın)
    if me.color_attributes:
        me.color_attributes.active_color = me.color_attributes[0]
        me.color_attributes.render_color_index = 0
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    m = bpy.data.materials.get("tree") or bpy.data.materials.new("tree")
    m.use_nodes = True
    nodes = m.node_tree.nodes
    if "Color Attribute" not in nodes:
        attr = nodes.new("ShaderNodeVertexColor")
        attr.name = "Color Attribute"
        attr.layer_name = "Col"
        m.node_tree.links.new(attr.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def grove(kind, seed):
    """Koru: 4-6 küçük ağaç (tür: iğne yapraklı ağırlıklı ya da yaprak döken ağırlıklı)."""
    rng = random.Random(seed)
    needle = kind % 2 == 1
    out = bmesh.new()
    n = rng.randint(4, 6)
    pts = []
    while len(pts) < n:
        a = rng.uniform(0, 2 * math.pi)
        r = 0.55 * math.sqrt(rng.random())
        p = (math.cos(a) * r, math.sin(a) * r)
        if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > 0.09 for q in pts):
            pts.append(p)
    for i, (x, y) in enumerate(pts):
        mix = rng.random() < 0.2
        use_needle = needle != mix
        tb = conifer(seed * 13 + i) if use_needle else deciduous(seed * 17 + i, 1)
        sc = rng.uniform(0.38, 0.55)
        bmesh.ops.transform(tb, matrix=Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z") @ Matrix.Scale(sc, 4),
                            verts=tb.verts)
        me = bpy.data.meshes.new("tmp")
        tb.to_mesh(me)
        tb.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obs = []
    for variant in range(3):
        for needle in (0, 1):
            kind = variant * 2 + needle
            ob = to_object(f"tree_{kind}", grove(kind, 300 + kind * 7))
            ob.location.x = kind * 1.0
            obs.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    # dışa aktarımda her ağaç kendi orijininde olsun
    for ob in obs:
        ob.location.x = 0
    bpy.ops.export_scene.gltf(filepath=str(OUT / "trees.glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    for ob in obs:
        print(f"[tree] {ob.name}: {len(ob.data.polygons)} yüz")
    if RENDER_DIR:
        RENDER_DIR.mkdir(parents=True, exist_ok=True)
        for i, ob in enumerate(obs):
            ob.location.x = (i - 2.5) * 0.8
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_EEVEE"
        scene.view_settings.view_transform = "Standard"
        scene.render.resolution_x, scene.render.resolution_y = 1000, 360
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.7, 0.78, 1)
        world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
        scene.world = world
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.location = (0, -5.2, 1.6)
        cam.rotation_euler = (math.radians(80), 0, 0)
        scene.collection.objects.link(cam)
        scene.camera = cam
        scene.render.filepath = str(RENDER_DIR / "trees.png")
        bpy.ops.render.render(write_still=True)


main()
