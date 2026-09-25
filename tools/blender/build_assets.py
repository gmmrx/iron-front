"""
Iron Front — harita assetleri (Blender betiği), v2.
Çalıştırma:
    python3 tools/blender/make_textures.py            # dokular (bir kez)
    Blender --background --factory-startup --python tools/blender/build_assets.py -- [--render DIR] [--only city_west_capital]
Çıktı: assets/models/*.glb

Stil: minyatür savaş haritası. Dokulu cepheler (katlara oturan pencere sıraları), kornişler,
mansard çatılar, çatı pencereleri, bacalar; sokak ızgarası üzerinde yerleşim.
Bölgesel mimari: west (Batı/Orta Avrupa), east (Rus/Doğu), orient (Osmanlı/Orta Doğu/K. Afrika), nordic.
Birim: 1 kat = FLOOR_H; cephe dokusu 3 pencere x 2 kat = TILE_W x TILE_H.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models"
TEX = OUT / "textures"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None

FLOOR_H = 0.11
TILE_W = 0.30
TILE_H = FLOOR_H * 2

# ------------------------------------------------------------------ malzemeler
# ad -> (doku dosyası | None, düz renk, pürüzlülük, metalik)
MATERIALS = {
    "facade_cream": ("facade_cream", None, 0.85, 0), "facade_white": ("facade_white", None, 0.85, 0),
    "facade_ochre": ("facade_ochre", None, 0.85, 0), "facade_grey": ("facade_grey", None, 0.85, 0),
    "facade_pink": ("facade_pink", None, 0.85, 0), "facade_yellow": ("facade_yellow", None, 0.85, 0),
    "facade_beige_flat": ("facade_beige_flat", None, 0.9, 0), "facade_whitewash": ("facade_whitewash", None, 0.9, 0),
    "brick_red": ("brick_red", None, 0.9, 0), "brick_dark": ("brick_dark", None, 0.9, 0),
    "stone_light": ("stone_light", None, 0.8, 0), "stone_sand": ("stone_sand", None, 0.85, 0),
    "roof_terracotta": ("roof_terracotta", None, 0.7, 0), "roof_slate": ("roof_slate", None, 0.55, 0),
    "roof_copper": ("roof_copper", None, 0.45, 0.25), "roof_dark": ("roof_dark", None, 0.7, 0),
    "wood_red": ("wood_red", None, 0.85, 0), "wood_yellow": ("wood_yellow", None, 0.85, 0),
    "wood_white": ("wood_white", None, 0.85, 0),
    "ground_cobble": ("ground_cobble", None, 0.95, 0), "ground_dirt": ("ground_dirt", None, 1.0, 0),
    "concrete": ("concrete", None, 0.9, 0), "asphalt": ("asphalt", None, 0.85, 0), "grass": ("grass", None, 1.0, 0),
    # düz renkler
    "gold": (None, (0.83, 0.62, 0.2), 0.3, 1.0), "onion_blue": (None, (0.16, 0.34, 0.62), 0.35, 0.2),
    "onion_green": (None, (0.18, 0.46, 0.34), 0.4, 0.2), "lead": (None, (0.46, 0.49, 0.52), 0.62, 0.25),
    "tree": (None, (0.13, 0.27, 0.09), 0.9, 0), "tree_dark": (None, (0.08, 0.19, 0.08), 0.9, 0),
    "tree_autumn": (None, (0.32, 0.33, 0.1), 0.9, 0), "trunk": (None, (0.25, 0.17, 0.1), 0.9, 0),
    "steel": (None, (0.28, 0.3, 0.33), 0.4, 0.8), "crane": (None, (0.8, 0.5, 0.1), 0.5, 0.3),
    "hull": (None, (0.2, 0.22, 0.25), 0.5, 0.4), "hull_red": (None, (0.45, 0.12, 0.08), 0.6, 0.1),
    "deck": (None, (0.52, 0.42, 0.3), 0.8, 0), "flag_red": (None, (0.75, 0.08, 0.08), 0.7, 0),
    "white": (None, (0.9, 0.89, 0.85), 0.6, 0), "marking": (None, (0.95, 0.93, 0.8), 0.6, 0),
    "olive": (None, (0.3, 0.33, 0.17), 0.6, 0.2), "hangar": (None, (0.46, 0.48, 0.44), 0.5, 0.6),
    "glass": (None, (0.12, 0.16, 0.2), 0.1, 0.5), "water_tank": (None, (0.35, 0.37, 0.36), 0.5, 0.5),
}
_mats = {}


def mat(name):
    if name in _mats:
        return _mats[name]
    tex, color, rough, metal = MATERIALS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if tex:
        img = bpy.data.images.load(str(TEX / f"{tex}.png"), check_existing=True)
        node = nodes.new("ShaderNodeTexImage")
        node.image = img
        node.extension = "REPEAT"
        m.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        npath = TEX / f"{tex}_n.png"
        if npath.exists():
            nimg = bpy.data.images.load(str(npath), check_existing=True)
            nimg.colorspace_settings.name = "Non-Color"
            ntex = nodes.new("ShaderNodeTexImage")
            ntex.image = nimg
            nmap = nodes.new("ShaderNodeNormalMap")
            nmap.inputs["Strength"].default_value = 1.0
            m.node_tree.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
            m.node_tree.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    _mats[name] = m
    return m


# ------------------------------------------------------------------ geometri çekirdeği
_parts = []   # bu asset için oluşturulan objeler


def _finish(bm, materials, face_mat=None, uv_scale=(TILE_W, TILE_H)):
    """bmesh'ten obje; her yüze dünya ölçekli düzlemsel UV (pencereler katlara oturur)."""
    bm.normal_update()
    me = bpy.data.meshes.new("part")
    uv_layer = bm.loops.layers.uv.new("UVMap")
    tw, th = uv_scale
    for f in bm.faces:
        n = f.normal
        if abs(n.z) > 0.92:
            t, b = Vector((1, 0, 0)), Vector((0, 1, 0))
        else:
            t = Vector((0, 0, 1)).cross(n).normalized()
            b = n.cross(t).normalized()
        for loop in f.loops:
            p = loop.vert.co
            loop[uv_layer].uv = (p.dot(t) / tw, p.dot(b) / th)
        if face_mat:
            f.material_index = face_mat(f)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("part", me)
    bpy.context.collection.objects.link(ob)
    for m in materials:
        ob.data.materials.append(mat(m))
    _parts.append(ob)
    return ob


def _xf(x, y, z, rot):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, "Z")


def box(x, y, z, w, d, h, wall, top=None, rot=0.0, uv=(TILE_W, TILE_H)):
    """Tabanı z'de, merkezi (x, y) olan kutu. Yan yüzler 'wall', üst yüz 'top'."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal((w, d, h, 1)) @ Matrix.Translation((0, 0, 0.5)), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=_xf(x, y, z, rot), verts=bm.verts)
    mats = [wall] if top is None else [wall, top]
    return _finish(bm, mats, (lambda f: 1 if f.normal.z > 0.9 else 0) if top else None, uv)


def poly_prism(points, z0, z1, material, uv=(TILE_W, TILE_H)):
    bm = bmesh.new()
    bot = [bm.verts.new((p[0], p[1], z0)) for p in points]
    top = [bm.verts.new((p[0], p[1], z1)) for p in points]
    n = len(points)
    for i in range(n):
        bm.faces.new([bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]])
    bm.faces.new(top)
    bm.faces.new(bot[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, [material], None, uv)


def gable_roof(x, y, z, w, d, h, material, rot=0.0, overhang=0.02, gable_mat=None):
    """Beşik çatı, mahya yerel y boyunca. Alın üçgenleri gable_mat (duvar) ile."""
    w2, d2 = w / 2 + overhang, d / 2 + overhang
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [(-w2, -d2, 0), (w2, -d2, 0), (w2, d2, 0), (-w2, d2, 0), (0, -d2, h), (0, d2, h)]]
    faces = [bm.faces.new([v[i] for i in f]) for f in [(0, 1, 4), (2, 3, 5), (0, 4, 5, 3), (1, 2, 5, 4), (0, 3, 2, 1)]]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=_xf(x, y, z, rot), verts=bm.verts)
    tri = {faces[0], faces[1]}
    mats = [material] if gable_mat is None else [material, gable_mat]
    return _finish(bm, mats, (lambda f: 1 if f in tri else 0) if gable_mat else None, (TILE_W * 0.8, TILE_W * 0.8))


def hip_roof(x, y, z, w, d, h, material, rot=0.0, overhang=0.02):
    w2, d2 = w / 2 + overhang, d / 2 + overhang
    r = min(w2, d2) * 0.95
    bm = bmesh.new()
    if w2 >= d2:
        pts = [(-w2, -d2, 0), (w2, -d2, 0), (w2, d2, 0), (-w2, d2, 0), (-w2 + r, 0, h), (w2 - r, 0, h)]
        faces = [(0, 1, 5, 4), (2, 3, 4, 5), (3, 0, 4), (1, 2, 5), (0, 3, 2, 1)]
    else:
        pts = [(-w2, -d2, 0), (w2, -d2, 0), (w2, d2, 0), (-w2, d2, 0), (0, -d2 + r, h), (0, d2 - r, h)]
        faces = [(0, 1, 4), (2, 3, 5), (1, 2, 5, 4), (3, 0, 4, 5), (0, 3, 2, 1)]
    v = [bm.verts.new(p) for p in pts]
    for f in faces:
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=_xf(x, y, z, rot), verts=bm.verts)
    return _finish(bm, [material], None, (TILE_W * 0.8, TILE_W * 0.8))


def mansard_roof(x, y, z, w, d, h, material, top_mat, rot=0.0, inset=0.07):
    """Dik alt eğim + düz üst (Paris tipi)."""
    w2, d2 = w / 2 + 0.01, d / 2 + 0.01
    wi, di = w2 - inset, d2 - inset
    bm = bmesh.new()
    b = [bm.verts.new(p) for p in [(-w2, -d2, 0), (w2, -d2, 0), (w2, d2, 0), (-w2, d2, 0)]]
    t = [bm.verts.new(p) for p in [(-wi, -di, h), (wi, -di, h), (wi, di, h), (-wi, di, h)]]
    for i in range(4):
        bm.faces.new([b[i], b[(i + 1) % 4], t[(i + 1) % 4], t[i]])
    top = bm.faces.new(t)
    bm.faces.new(b[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=_xf(x, y, z, rot), verts=bm.verts)
    return _finish(bm, [material, top_mat], lambda f: 1 if f.normal.z > 0.95 else 0, (TILE_W * 0.8, TILE_W * 0.8))


def lathe(x, y, z, profile, material, segments=16):
    """(r, z) profilini z ekseni etrafında döndür (kubbe, soğan kubbe, minare)."""
    bm = bmesh.new()
    rings = []
    for r, pz in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((x + math.cos(a) * r, y + math.sin(a) * r, z + pz)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]])
    if profile[0][0] > 1e-4:
        bm.faces.new(rings[0][::-1])
    if profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(bm, [material], None, (0.2, 0.2))
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def cylinder(x, y, z, r, h, material, seg=12, r_top=None):
    rt = r if r_top is None else r_top
    return lathe(x, y, z, [(r, 0), (r, 0.0001), (rt, h)] if rt > 1e-4 else [(r, 0), (1e-5, h)], material, seg)


def dome(x, y, z, r, material, seg=20, height=1.0):
    prof = [(r * math.cos(a), r * math.sin(a) * height) for a in [i * math.pi / 2 / 8 for i in range(9)]]
    prof[-1] = (0.0, prof[-1][1])
    return lathe(x, y, z, prof, material, seg)


def onion(x, y, z, r, material, seg=16):
    prof = [(r * 0.75, 0), (r * 1.0, r * 0.35), (r * 1.05, r * 0.7), (r * 0.85, r * 1.15),
            (r * 0.45, r * 1.5), (r * 0.12, r * 1.8), (r * 0.03, r * 2.1), (0.0, r * 2.2)]
    return lathe(x, y, z, prof, material, seg)


def cross(x, y, z, s=0.05):
    box(x, y, z, 0.008, 0.008, s, "gold")
    box(x, y, z + s * 0.62, s * 0.55, 0.008, 0.008, "gold")


# ------------------------------------------------------------------ yapı taşları
def chimney(x, y, z, rot, material="brick_red"):
    box(x, y, z, 0.035, 0.035, 0.07, material, rot=rot)
    box(x, y, z + 0.07, 0.045, 0.045, 0.012, "concrete", rot=rot)


def house(x, y, rot, rng, style):
    floors = rng.choice([1, 2, 2])
    bays = rng.choice([2, 2, 3])
    w = bays * TILE_W / 3
    d = rng.uniform(0.16, 0.22)
    h = floors * FLOOR_H
    if style == "orient":
        wall = rng.choice(["facade_beige_flat", "facade_whitewash", "facade_beige_flat"])
        box(x, y, 0, w, d, h, wall, top="concrete", rot=rot)
        box(x, y, h, w + 0.008, d + 0.008, 0.012, "stone_sand", rot=rot)          # parapet
        if rng.random() < 0.35:
            hip_roof(x, y, h + 0.012, w, d, 0.05, "roof_terracotta", rot)
        return
    if style == "nordic":
        wall = rng.choice(["wood_red", "wood_red", "wood_yellow", "wood_white"])
        roof = rng.choice(["roof_dark", "roof_slate", "roof_terracotta"])
        box(x, y, 0, w, d, h, wall, rot=rot)
        gable_roof(x, y, h, w, d, d * 0.95, roof, rot + math.pi / 2 if w > d else rot, 0.02, wall)
        return
    if style == "east":
        wall = rng.choice(["wood_yellow", "facade_pink", "facade_yellow", "wood_white", "facade_white"])
        roof = rng.choice(["roof_copper", "roof_slate", "roof_dark", "roof_copper"])
    else:
        wall = rng.choice(["facade_cream", "facade_white", "facade_ochre", "facade_yellow", "facade_cream"])
        roof = rng.choice(["roof_terracotta", "roof_terracotta", "roof_slate", "roof_dark"])
    box(x, y, 0, w, d, h, wall, rot=rot)
    along = w > d
    gable_roof(x, y, h, w, d, min(w, d) * 0.55, roof, rot + (math.pi / 2 if along else 0), 0.015, wall)
    c, s = math.cos(rot), math.sin(rot)
    ox = w * 0.25
    chimney(x + ox * c, y + ox * s, h + min(w, d) * 0.2, rot)


def block(x, y, rot, rng, style, w=None, d=None, floors=None):
    floors = floors or rng.randint(3, 5)
    w = w or rng.choice([2, 3, 3, 4]) * TILE_W / 3 * 1.0
    d = d or rng.uniform(0.28, 0.4)
    h = floors * FLOOR_H
    if style == "orient":
        wall = rng.choice(["facade_beige_flat", "facade_whitewash", "facade_beige_flat"])
        box(x, y, 0, w, d, h, wall, top="concrete", rot=rot)
        box(x, y, h, w + 0.01, d + 0.01, 0.015, "stone_sand", rot=rot)
        return
    if style == "east":
        wall = rng.choice(["facade_pink", "facade_yellow", "facade_grey", "facade_cream", "facade_white"])
    elif style == "nordic":
        wall = rng.choice(["facade_yellow", "facade_cream", "facade_ochre", "brick_red"])
    else:
        wall = rng.choice(["facade_cream", "facade_white", "facade_grey", "facade_ochre", "brick_red", "facade_cream"])
    # zemin kat bandı (taş), duvar, korniş
    box(x, y, 0, w + 0.006, d + 0.006, FLOOR_H * 0.55, "stone_light", rot=rot)
    box(x, y, 0, w, d, h, wall, rot=rot)
    box(x, y, h - 0.004, w + 0.016, d + 0.016, 0.016, "stone_light", rot=rot)
    kind = rng.random()
    if style == "west" and kind < 0.5:
        mansard_roof(x, y, h + 0.012, w, d, FLOOR_H * 0.9, "roof_slate", "roof_slate", rot)
        # çatı pencereleri
        c, s = math.cos(rot), math.sin(rot)
        n = max(1, int(w / 0.1))
        for i in range(n):
            off = -w / 2 + (i + 0.5) * w / n
            for side in (-1, 1):
                ly = side * (d / 2 - 0.025)
                dx, dy = off * c - ly * s, off * s + ly * c
                box(x + dx, y + dy, h + 0.03, 0.035, 0.03, 0.045, "white", rot=rot)
                gable_roof(x + dx, y + dy, h + 0.075, 0.035, 0.03, 0.02, "roof_slate", rot + math.pi / 2, 0.005)
    elif style == "east":
        hip_roof(x, y, h + 0.012, w, d, 0.08, rng.choice(["roof_copper", "roof_slate", "roof_dark"]), rot)
    else:
        hip_roof(x, y, h + 0.012, w, d, 0.09, rng.choice(["roof_terracotta", "roof_slate", "roof_dark"]), rot)
    c, s = math.cos(rot), math.sin(rot)
    for side in (-0.3, 0.3):
        chimney(x + side * w * c, y + side * w * s, h + 0.04, rot)


def church(x, y, rot, style, big=False):
    k = 1.35 if big else 1.0
    c, s = math.cos(rot), math.sin(rot)
    if style == "orient":
        mosque(x, y, rot, k)
        return
    if style == "east":
        box(x, y, 0, 0.3 * k, 0.3 * k, 0.28 * k, "facade_whitewash", rot=rot)
        hip_roof(x, y, 0.28 * k, 0.3 * k, 0.3 * k, 0.05 * k, "roof_copper", rot)
        cylinder(x, y, 0.3 * k, 0.07 * k, 0.1 * k, "facade_whitewash", 12)
        onion(x, y, 0.4 * k, 0.07 * k, "gold")
        cross(x, y, 0.4 * k + 0.154 * k, 0.05 * k)
        for dx, dy in [(-0.1, -0.1), (0.1, -0.1), (-0.1, 0.1), (0.1, 0.1)]:
            px, py = x + (dx * c - dy * s) * k, y + (dx * s + dy * c) * k
            cylinder(px, py, 0.28 * k, 0.035 * k, 0.07 * k, "facade_whitewash", 10)
            onion(px, py, 0.35 * k, 0.035 * k, "onion_blue")
        # çan kulesi
        bx, by = x - 0.3 * k * s, y + 0.3 * k * c
        box(bx, by, 0, 0.12 * k, 0.12 * k, 0.45 * k, "facade_whitewash", rot=rot)
        cylinder(bx, by, 0.45 * k, 0.05 * k, 0.12 * k, "roof_copper", 8, r_top=0.0)
        return
    wall = "wood_white" if style == "nordic" else "stone_light"
    roof = "roof_dark" if style == "nordic" else "roof_slate"
    box(x, y, 0, 0.2 * k, 0.5 * k, 0.24 * k, wall, rot=rot)
    gable_roof(x, y, 0.24 * k, 0.2 * k, 0.5 * k, 0.16 * k * (1.4 if style == "nordic" else 1), roof, rot, 0.015, wall)
    # transept
    box(x + 0.05 * k * -s, y + 0.05 * k * c, 0, 0.42 * k, 0.14 * k, 0.2 * k, wall, rot=rot)
    gable_roof(x + 0.05 * k * -s, y + 0.05 * k * c, 0.2 * k, 0.42 * k, 0.14 * k, 0.11 * k, roof, rot + math.pi / 2, 0.01, wall)
    tx, ty = x + 0.3 * k * s, y - 0.3 * k * c
    box(tx, ty, 0, 0.13 * k, 0.13 * k, 0.52 * k, wall, rot=rot)
    box(tx, ty, 0.52 * k, 0.15 * k, 0.15 * k, 0.02 * k, "stone_light", rot=rot)
    spire = lathe(0, 0, 0.54 * k, [(0.075 * k, 0), (0.0, 0.32 * k)], roof, 4)
    spire.rotation_euler.z = rot + math.pi / 4
    spire.location = (tx, ty, 0)
    cross(tx, ty, 0.86 * k, 0.05 * k)


def minaret(x, y, h, r=0.022):
    cylinder(x, y, 0, r * 1.2, h * 0.15, "stone_sand", 12)
    cylinder(x, y, h * 0.15, r, h * 0.7, "stone_sand", 12)
    cylinder(x, y, h * 0.72, r * 1.6, h * 0.03, "stone_sand", 12)     # şerefe
    cylinder(x, y, h * 0.75, r * 0.9, h * 0.12, "stone_sand", 12)
    lathe(x, y, h * 0.87, [(r * 1.0, 0), (0.0, h * 0.2)], "lead", 12)


def mosque(x, y, rot, k=1.0):
    c, s = math.cos(rot), math.sin(rot)
    box(x, y, 0, 0.42 * k, 0.42 * k, 0.2 * k, "stone_sand", top="concrete", rot=rot)
    cylinder(x, y, 0.2 * k, 0.19 * k, 0.05 * k, "stone_sand", 24)
    dome(x, y, 0.25 * k, 0.19 * k, "lead", 24)
    lathe(x, y, 0.25 * k + 0.19 * k, [(0.012 * k, 0), (0.0, 0.06 * k)], "gold", 8)
    for dx, dy in [(0.21, 0), (-0.21, 0)]:            # yarım kubbeler
        px, py = x + (dx * c - dy * s) * k, y + (dx * s + dy * c) * k
        dome(px, py, 0.2 * k, 0.1 * k, "lead", 16)
    for dx, dy in [(-0.26, -0.26), (0.26, -0.26), (-0.26, 0.26), (0.26, 0.26)]:
        minaret(x + (dx * c - dy * s) * k, y + (dx * s + dy * c) * k, 0.62 * k)
    # avlu
    ax, ay = x + 0.42 * k * s, y - 0.42 * k * c
    box(ax, ay, 0, 0.46 * k, 0.36 * k, 0.012, "ground_cobble", rot=rot)
    for i in range(5):
        for side in (-1, 1):
            ox = (-0.2 + i * 0.1) * k
            oy = side * 0.16 * k
            dome(ax + ox * c - oy * s, ay + ox * s + oy * c, 0.06 * k, 0.035 * k, "lead", 10)
            box(ax + ox * c - oy * s, ay + ox * s + oy * c, 0, 0.08 * k, 0.05 * k, 0.06 * k, "stone_sand", rot=rot)


def palace(x, y, style):
    """Başkentin simge yapısı (stile göre)."""
    if style == "orient":
        mosque(x, y + 0.9, 0.0, 1.9)
        box(x, y - 0.35, 0, 1.3, 0.38, 0.26, "stone_sand", top="concrete")
        box(x, y - 0.35, 0.26, 1.34, 0.42, 0.03, "stone_light")
        for i in range(11):
            cylinder(x - 0.55 + i * 0.11, y - 0.56, 0, 0.018, 0.25, "white", 10)
        flag(x + 0.75, y - 0.35)
        return
    if style == "east":
        kremlin(x, y)
        return
    k = 1.5
    box(x, y, 0, 1.25 * k, 0.62 * k, 0.05 * k, "stone_light")
    box(x, y, 0.05 * k, 1.15 * k, 0.55 * k, 0.3 * k, "facade_white")
    box(x, y, 0.35 * k - 0.004, 1.19 * k, 0.59 * k, 0.02 * k, "stone_light")
    mansard_roof(x, y, 0.37 * k, 1.15 * k, 0.55 * k, 0.08 * k, "roof_copper", "roof_slate")
    for i in range(10):                                            # sütunlu revak
        cylinder(x - 0.4 * k + i * 0.089 * k, y - 0.33 * k, 0.05 * k, 0.02 * k, 0.28 * k, "white", 10)
    box(x, y - 0.33 * k, 0.33 * k, 0.9 * k, 0.07 * k, 0.03 * k, "stone_light")
    pediment(x, y - 0.33 * k, 0.36 * k, 0.9 * k, 0.07 * k, 0.12 * k)
    cylinder(x, y + 0.05 * k, 0.45 * k, 0.17 * k, 0.12 * k, "stone_light", 24)   # kasnak
    for i in range(16):
        a = i * 2 * math.pi / 16
        cylinder(x + math.cos(a) * 0.175 * k, y + 0.05 * k + math.sin(a) * 0.175 * k, 0.45 * k, 0.008 * k, 0.12 * k, "white", 6)
    dome(x, y + 0.05 * k, 0.57 * k, 0.18 * k, "roof_copper", 24, 1.15)
    cylinder(x, y + 0.05 * k, 0.77 * k, 0.03 * k, 0.07 * k, "white", 10)
    lathe(x, y + 0.05 * k, 0.84 * k, [(0.035 * k, 0), (0.0, 0.05 * k)], "gold", 10)
    flag(x + 0.95 * k, y + 0.2 * k)


def kremlin(x, y):
    # kırmızı tuğla sur + köşe kuleleri (yeşil çadır çatı) + altın soğan kubbeli katedral + sarı saray
    pts = [(-1.1, -0.8), (1.1, -0.9), (1.2, 0.8), (-1.0, 0.95)]
    for i in range(4):
        a, b = Vector((*pts[i], 0)), Vector((*pts[(i + 1) % 4], 0))
        mid = (a + b) / 2
        L = (b - a).length
        rot = math.atan2(b.y - a.y, b.x - a.x)
        box(x + mid.x, y + mid.y, 0, L, 0.05, 0.14, "brick_red", rot=rot)
        for t in (0.33, 0.66):
            p = a.lerp(b, t)
            box(x + p.x, y + p.y, 0.14, 0.03, 0.06, 0.03, "brick_red", rot=rot)
    for (px, py) in pts:
        box(x + px, y + py, 0, 0.14, 0.14, 0.34, "brick_red")
        t_ = lathe(0, 0, 0.34, [(0.1, 0), (0.0, 0.22)], "onion_green", 4)
        t_.rotation_euler.z = math.pi / 4
        t_.location = (x + px, y + py, 0)
    tx, ty = x + 0.05, y - 0.85                                      # Spasskaya
    box(tx, ty, 0, 0.18, 0.18, 0.55, "brick_red")
    box(tx, ty, 0.55, 0.14, 0.14, 0.14, "white")
    lathe(tx, ty, 0.69, [(0.1, 0), (0.0, 0.26)], "onion_green", 8)
    lathe(tx, ty, 0.95, [(0.02, 0), (0.0, 0.04)], "flag_red", 6)
    church(x - 0.3, y + 0.1, 0.0, "east", big=True)
    church(x + 0.35, y + 0.35, 0.3, "east", big=False)
    box(x + 0.45, y - 0.2, 0, 0.7, 0.3, 0.26, "facade_yellow")
    hip_roof(x + 0.45, y - 0.2, 0.26, 0.7, 0.3, 0.07, "roof_copper", 0.0)
    flag(x + 0.45, y - 0.2, 0.33)


def pediment(x, y, z, w, d, h, material="stone_light"):
    """Revak üstü üçgen alınlık (x boyunca geniş, y boyunca ince)."""
    bm = bmesh.new()
    f = [bm.verts.new((x + px, y - d / 2, z + pz)) for px, pz in [(-w / 2, 0), (w / 2, 0), (0, h)]]
    b = [bm.verts.new((x + px, y + d / 2, z + pz)) for px, pz in [(-w / 2, 0), (w / 2, 0), (0, h)]]
    bm.faces.new(f)
    bm.faces.new(b[::-1])
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new([f[i], b[i], b[j], f[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _finish(bm, [material])


def flag(x, y, z=0.0):
    cylinder(x, y, z, 0.008, 0.7, "steel", 6)
    box(x + 0.07, y, z + 0.6, 0.14, 0.006, 0.09, "flag_red")


def factory(x, y, rot, rng):
    c, s = math.cos(rot), math.sin(rot)
    w, d = 0.62, 0.38
    box(x, y, 0, w, d, 0.2, "brick_red", rot=rot)
    for i in range(4):
        ox = -w / 2 + (i + 0.5) * w / 4
        gable_roof(x + ox * c, y + ox * s, 0.2, w / 4, d, 0.09, "roof_slate", rot, 0.0, "glass")
    for j, ox in enumerate([w * 0.35, w * 0.55]):
        cx, cy = x + ox * c - 0.08 * s, y + ox * s + 0.08 * c
        cylinder(cx, cy, 0, 0.045, 0.75 + j * 0.12, "brick_dark", 12, r_top=0.034)
        cylinder(cx, cy, 0.75 + j * 0.12, 0.04, 0.03, "concrete", 12)
    # su kulesi
    wx, wy = x - w * 0.6 * c + 0.1 * s, y - w * 0.6 * s - 0.1 * c
    for dx, dy in [(-0.03, -0.03), (0.03, -0.03), (-0.03, 0.03), (0.03, 0.03)]:
        box(wx + dx, wy + dy, 0, 0.008, 0.008, 0.28, "steel")
    cylinder(wx, wy, 0.28, 0.06, 0.09, "water_tank", 14)
    lathe(wx, wy, 0.37, [(0.062, 0), (0.0, 0.035)], "water_tank", 14)


def tree(x, y, rng, s=1.0, style="west"):
    h = rng.uniform(0.09, 0.15) * s
    cylinder(x, y, 0, 0.008 * s, h * 0.45, "trunk", 5)
    conifer = rng.random() < (0.75 if style == "nordic" else 0.35 if style != "orient" else 0.1)
    if conifer:
        for k in range(3):
            r = 0.05 * s * (1 - k * 0.25)
            lathe(x, y, h * 0.3 + k * h * 0.28, [(r, 0), (0.0, h * 0.55)], rng.choice(["tree_dark", "tree"]), 7)
    else:
        m = rng.choice(["tree", "tree", "tree_dark", "tree_autumn"]) if style != "orient" else "tree"
        for k in range(rng.randint(2, 3)):
            ox, oy = rng.uniform(-0.02, 0.02) * s, rng.uniform(-0.02, 0.02) * s
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rng.uniform(0.04, 0.055) * s)
            bmesh.ops.transform(bm, matrix=Matrix.Translation((x + ox, y + oy, h * 0.45 + 0.04 * s + k * 0.02 * s)), verts=bm.verts)
            _finish(bm, [m], None, (0.2, 0.2))


# ------------------------------------------------------------------ yerleşim planı
def ground(rx, ry, rng, material, verts=24, jitter=0.12):
    pts = []
    for i in range(verts):
        a = 2 * math.pi * i / verts
        k = 1.0 + rng.uniform(-jitter, jitter)
        pts.append((math.cos(a) * rx * k, math.sin(a) * ry * k))
    poly_prism(pts, -0.03, 0.002, material, (0.6, 0.6))
    return pts


def inside(p, rx, ry, margin=0.0):
    return (p[0] / (rx - margin)) ** 2 + (p[1] / (ry - margin)) ** 2 < 1.0


def grid_city(rx, ry, rng, style, block_spacing=0.62, street=0.07, dense=0.6, landmark=None, factories=0):
    """Hafif döndürülmüş sokak ızgarası: sokaklar parke/asfalt, parseller bina ile dolu."""
    rot = rng.uniform(-0.25, 0.25)
    c, s = math.cos(rot), math.sin(rot)
    ground(rx, ry, rng, "ground_cobble")
    n = int(max(rx, ry) / block_spacing) + 2
    street_mat = "asphalt" if style != "orient" else "ground_dirt"
    for i in range(-n, n + 1):   # sokaklar
        o = (i + 0.5) * block_spacing
        L = 2 * max(rx, ry)
        for (x0, y0, ang, len_) in [(o * c, o * s, rot + math.pi / 2, L), (-o * s, o * c, rot, L)]:
            # sokak şeridi, elips içine kırpılmış parçalar
            steps = 24
            for k in range(steps):
                t = -len_ / 2 + (k + 0.5) * len_ / steps
                px, py = x0 + math.cos(ang) * t, y0 + math.sin(ang) * t
                if inside((px, py), rx, ry, 0.05):
                    box(px, py, 0.002, len_ / steps + 0.002, street, 0.002, street_mat, rot=ang, uv=(0.3, 0.3))
    reserved = []
    if landmark:
        reserved.append((0.0, 0.0, landmark))
    for fi in range(factories):
        a = rng.uniform(0, 2 * math.pi)
        fx, fy = math.cos(a) * rx * 0.72, math.sin(a) * ry * 0.72
        factory(fx, fy, rot + rng.choice([0, math.pi / 2]), rng)
        reserved.append((fx, fy, 0.5))
    lot = (block_spacing - street) / 2
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            bx, by = i * block_spacing, j * block_spacing
            for qx in (-0.5, 0.5):
                for qy in (-0.5, 0.5):
                    lx, ly = bx + qx * lot, by + qy * lot
                    wx, wy = lx * c - ly * s, lx * s + ly * c
                    if not inside((wx, wy), rx, ry, 0.18):
                        continue
                    if any((wx - rx_) ** 2 + (wy - ry_) ** 2 < rr ** 2 for rx_, ry_, rr in reserved):
                        continue
                    r_norm = math.sqrt((wx / rx) ** 2 + (wy / ry) ** 2)
                    face = rot + (0 if qy < 0 else math.pi) + (math.pi / 2 if rng.random() < 0.5 else 0)
                    if r_norm < dense and rng.random() < 0.92:
                        block(wx, wy, face, rng, style, w=lot * 0.92, d=lot * 0.82,
                              floors=rng.randint(4, 6) if r_norm < dense * 0.5 else rng.randint(3, 4))
                    elif rng.random() < 0.8:
                        house(wx, wy, face, rng, style)
                    elif style != "orient":
                        tree(wx, wy, rng, 1.0, style)
    return rot


def ring_trees(n, r_in, r_out, rng, style):
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(r_in, r_out)
        tree(math.cos(a) * r, math.sin(a) * r * 0.85, rng, 1.0, style)


def build_town(style):
    rng = random.Random(hash(("town", style)) & 0xffff)
    ground(0.95, 0.8, rng, "ground_dirt" if style == "orient" else "ground_cobble")
    rot = rng.uniform(0, math.pi)
    c, s = math.cos(rot), math.sin(rot)
    # ana cadde boyunca evler
    box(0, 0, 0.002, 1.7, 0.08, 0.002, "ground_dirt", rot=rot, uv=(0.3, 0.3))
    church(0.12 * -s, 0.12 * c, rot, style)
    for k in range(-3, 4):
        for side in (-1, 1):
            if k == 0 and side == 1:
                continue
            t = k * 0.23 + rng.uniform(-0.03, 0.03)
            o = side * rng.uniform(0.17, 0.22)
            house(t * c - o * s, t * s + o * c, rot + (0 if side < 0 else math.pi), rng, style)
    ring_trees(18, 0.9, 1.3, rng, style)


def build_medium(style):
    rng = random.Random(hash(("medium", style)) & 0xffff)
    grid_city(1.45, 1.25, rng, style, dense=0.45, landmark=0.34)
    church(0, 0, rng.uniform(0, 1), style, big=True)
    ring_trees(22, 1.45, 1.9, rng, style)


def build_large(style):
    rng = random.Random(hash(("large", style)) & 0xffff)
    grid_city(2.1, 1.8, rng, style, dense=0.7, landmark=0.4, factories=2)
    church(0, 0, rng.uniform(0, 1), style, big=True)
    ring_trees(26, 2.1, 2.6, rng, style)


def build_capital(style):
    rng = random.Random(hash(("capital", style)) & 0xffff)
    grid_city(2.7, 2.3, rng, style, dense=0.75, landmark=1.45, factories=2)
    box(0, 0, 0.003, 2.4, 2.2, 0.004, "stone_light", uv=(0.4, 0.4))       # meydan
    palace(0, 0, style)
    for i in range(10):
        for side in (-1, 1):
            tree(-1.05 + i * 0.235, side * 1.0, rng, 0.9, style)
    ring_trees(30, 2.7, 3.2, rng, style)


def build_port():
    rng = random.Random(7)
    box(0, 0.1, -0.08, 2.6, 1.0, 0.1, "concrete", uv=(0.4, 0.4))            # rıhtım
    box(0.35, -0.72, -0.08, 0.28, 0.66, 0.09, "concrete", uv=(0.4, 0.4))    # iskele
    for (x, m) in [(-0.85, "brick_red"), (-0.3, "brick_dark")]:             # ambarlar
        box(x, 0.3, 0.02, 0.48, 0.34, 0.2, m)
        gable_roof(x, 0.3, 0.22, 0.48, 0.34, 0.1, "roof_slate", math.pi / 2, 0.01, m)
    # kafes vinç
    for dx, dy in [(-0.04, -0.04), (0.04, -0.04), (-0.04, 0.04), (0.04, 0.04)]:
        box(0.8 + dx, -0.2 + dy, 0.02, 0.012, 0.012, 0.62, "crane")
    for z in (0.15, 0.3, 0.45):
        box(0.8, -0.2, z, 0.1, 0.1, 0.012, "crane")
    box(0.8, -0.2, 0.64, 0.12, 0.12, 0.08, "crane")
    box(0.8, -0.5, 0.7, 0.04, 0.75, 0.035, "crane")
    box(0.8, 0.05, 0.7, 0.05, 0.25, 0.05, "steel")
    cylinder(0.8, -0.8, 0.4, 0.004, 0.3, "steel", 4)
    ship(1.05, -1.0, 0.0)
    for i in range(7):                                                      # yük yığınları
        box(-1.0 + i * 0.11, -0.25, 0.02, 0.09, 0.2, 0.06 + rng.random() * 0.06,
            rng.choice(["wood_red", "olive", "steel", "wood_yellow"]))
    box(-0.05, 0.25, 0.02, 0.012, 0.9, 0.012, "steel")                     # ray


def ship(x, y, rot):
    L, B, H = 1.15, 0.24, 0.1
    prof = [(-L / 2, 0.0), (-L / 2 + 0.04, B / 2), (L / 2 - 0.22, B / 2), (L / 2, 0.0), (L / 2 - 0.22, -B / 2), (-L / 2 + 0.04, -B / 2)]
    pts = [(x + px, y + py) for px, py in prof]
    poly_prism(pts, -0.07, 0.0, "hull_red")
    poly_prism(pts, 0.0, H, "hull")
    box(x - 0.24, y, H, 0.22, 0.17, 0.1, "white")
    box(x - 0.24, y, H + 0.1, 0.16, 0.13, 0.05, "white")
    cylinder(x - 0.2, y, H + 0.15, 0.03, 0.12, "flag_red", 12)
    for ox in (0.05, 0.25):
        box(x + ox, y, H, 0.16, 0.18, 0.02, "deck")
    cylinder(x + 0.15, y, H, 0.008, 0.28, "steel", 6)


def build_airbase():
    rng = random.Random(8)
    # Pist, banket, paralel taksi yolu ve apron. Zemin plakası yok; tamamı
    # düzleştirilmiş haritaya birkaç milimetre gömülerek z-fighting önlenir.
    box(0, -0.28, 0.002, 3.65, 0.56, 0.004, "concrete", uv=(0.45, 0.45))
    box(0, -0.28, 0.007, 3.45, 0.39, 0.004, "asphalt", uv=(0.4, 0.4))
    for i in range(13):
        box(-1.56 + i * 0.26, -0.28, 0.012, 0.13, 0.02, 0.002, "marking")
    # pist başı çizgileri
    for side in (-1, 1):
        sx = side * 1.58
        for j in range(5):
            box(sx, -0.28 + (j - 2) * 0.055, 0.012, 0.16, 0.018, 0.002, "marking")
    box(0.15, 0.38, 0.004, 2.45, 0.42, 0.006, "concrete", uv=(0.4, 0.4))
    box(-0.95, 0.05, 0.006, 0.22, 0.58, 0.005, "asphalt", rot=-0.38, uv=(0.4, 0.4))
    box(1.05, 0.05, 0.006, 0.22, 0.58, 0.005, "asphalt", rot=0.38, uv=(0.4, 0.4))
    for x in [-0.55, 0.05, 0.65]:
        bm = bmesh.new()
        seg = 12
        prof = [(math.cos(math.pi * i / seg) * 0.22, math.sin(math.pi * i / seg) * 0.22) for i in range(seg + 1)]
        f = [bm.verts.new((x + py, 0.82 - 0.27, pz)) for py, pz in prof]
        b = [bm.verts.new((x + py, 0.82 + 0.27, pz)) for py, pz in prof]
        for i in range(seg):
            bm.faces.new([f[i], f[i + 1], b[i + 1], b[i]])
        bm.faces.new(f[::-1])
        bm.faces.new(b)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        _finish(bm, ["hangar"], None, (0.2, 0.2))
        # okunaklı sürgülü hangar kapısı
        box(x, 0.545, 0.01, 0.32, 0.015, 0.17, "steel")
        for k in (-1, 0, 1):
            box(x + k * 0.09, 0.535, 0.025, 0.008, 0.01, 0.14, "concrete")
    # kontrol kulesi: kademeli gövde, cam kabin ve saçak
    box(1.28, 0.72, 0, 0.18, 0.18, 0.43, "facade_white")
    box(1.28, 0.72, 0.43, 0.27, 0.27, 0.11, "glass")
    box(1.28, 0.72, 0.54, 0.31, 0.31, 0.026, "concrete")
    cylinder(1.28, 0.72, 0.566, 0.012, 0.12, "steel", 8)
    # uçak park yerleri ve yakıt tesisatı
    for i, x in enumerate([0.9, 0.55, 0.2, -0.15, -0.5, -0.85]):
        plane(x, 0.27, math.pi / 2 + (0.06 if i % 2 else -0.06))
        box(x, 0.48, 0.01, 0.025, 0.025, 0.006, "marking")
    for x in (1.0, 1.16):
        cylinder(x, 1.02, 0.0, 0.07, 0.16, "water_tank", 16)
        lathe(x, 1.02, 0.16, [(0.072, 0), (0.0, 0.035)], "water_tank", 16)
    # rüzgâr tulumu / meydan işareti
    cylinder(-1.25, 0.82, 0, 0.009, 0.42, "steel", 8)
    box(-1.18, 0.82, 0.37, 0.14, 0.018, 0.055, "flag_red")
    ring_trees(18, 2.0, 2.45, rng, "west")


def plane(x, y, rot):
    c, s = math.cos(rot), math.sin(rot)
    box(x, y, 0.03, 0.035, 0.3, 0.035, "olive", rot=rot)                    # gövde (yerel y)
    box(x, y + 0.0, 0.045, 0.42, 0.07, 0.01, "olive", rot=rot)              # kanat (yerel x)
    tx, ty = x + 0.13 * s, y - 0.13 * c
    box(tx, ty, 0.05, 0.16, 0.04, 0.008, "olive", rot=rot)
    box(tx, ty, 0.05, 0.008, 0.04, 0.06, "olive", rot=rot)
    px, py = x - 0.155 * s, y + 0.155 * c
    box(px, py, 0.02, 0.09, 0.006, 0.09, "steel", rot=rot)


STYLES = ["west", "east", "orient", "nordic"]
ASSETS = {}
for _st in STYLES:
    ASSETS[f"city_{_st}_town"] = (lambda st: lambda: build_town(st))(_st)
    ASSETS[f"city_{_st}_medium"] = (lambda st: lambda: build_medium(st))(_st)
    ASSETS[f"city_{_st}_large"] = (lambda st: lambda: build_large(st))(_st)
    ASSETS[f"city_{_st}_capital"] = (lambda st: lambda: build_capital(st))(_st)
ASSETS["port"] = build_port
ASSETS["airbase"] = build_airbase


# ------------------------------------------------------------------ dışa aktarma
def finalize(name):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in _parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = _parts[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    return joined


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    built = {}
    for name, fn in ASSETS.items():
        if ONLY and name != ONLY:
            continue
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
        bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[name]
        _parts.clear()
        fn()
        ob = finalize(name)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), use_selection=True, export_format="GLB",
                                  export_apply=True, export_yup=True, export_image_format="AUTO")
        built[name] = ob
        print(f"[asset] {name}: {len(ob.data.polygons)} yüz, {len(ob.data.materials)} malzeme")
    if RENDER_DIR:
        render_previews(built)


def render_previews(built):
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 900, 600
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.7, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.75
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(3)
    sun.rotation_euler = (math.radians(48), 0, math.radians(35))
    scene.collection.objects.link(sun)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    g = bpy.data.objects.new("ground", bpy.data.meshes.new("g"))
    bm.to_mesh(g.data)
    g.location.z = -0.031
    g.data.materials.append(mat("grass"))
    scene.collection.objects.link(g)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 55
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, ob in built.items():
        for other in built.values():
            other.hide_render = other is not ob
        size = max(ob.dimensions.x, ob.dimensions.y)
        cam.location = Vector((size * 0.55, -size * 1.25, size * 1.05))
        cam.rotation_euler = (Vector((0, 0, 0.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(RENDER_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
