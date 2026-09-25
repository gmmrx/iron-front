"""
Tekil bina kütüphanesi: şehirler oyunda bu binalardan yan yana kurulur (zemin plakası yok).
    Blender --background --factory-startup --python tools/blender/build_buildings.py -- [--render DIR] [--save-blend FILE]
Çıktı: assets/models/buildings.glb — düğüm adları: <stil>_<tür>_<n>
  stiller: west, east, orient, nordic
  türler : house_0..5, block_0..5, church_0, landmark_0, factory_0
  ayrıca : port_0 (rıhtım + vinç + ambar + gemi)
Her binanın altında zemine gömülen taş temel vardır (eğimli arazide havada kalmaz).
Orijin: taban merkezi, z=0 zemin seviyesi.
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_assets as A  # noqa: E402

OUT = A.OUT
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None
SAVE_BLEND = Path(ARGS[ARGS.index("--save-blend") + 1]) if "--save-blend" in ARGS else None
STYLES = ["west", "east", "orient", "nordic"]
PLINTH_DEPTH = 0.16


def finish(name, plinth_mat="stone_light", recenter=True):
    """Parçaları birleştir, gömülü temel ekle, orijini taban merkezine al."""
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in A._parts:
        for v in ob.data.vertices:
            lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
            hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    if name.startswith("bridge"):
        recenter = False
    if recenter:
        A.box(cx, cy, -PLINTH_DEPTH, (hi.x - lo.x) * 0.98, (hi.y - lo.y) * 0.98, PLINTH_DEPTH + 0.004, plinth_mat)
    else:
        cx, cy = 0.0, 0.0
    bpy.ops.object.select_all(action="DESELECT")
    for ob in A._parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = A._parts[0]
    bpy.ops.object.convert(target="MESH")   # bevel/solidify uygula
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    for v in ob.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
    # Exporttan önce bozuk/çakışan custom-data katmanlarını temizle. Bu çağrı
    # Blender'ın glTF dışa aktarımında görülen rastgele normal ve yüz hatalarını engeller.
    ob.data.validate(clean_customdata=False)
    ob.data.update()
    A._parts.clear()
    return ob


# ------------------------------------------------------------------ ayrıntılı binalar
# Cephe dokusunda pencere sütunları 0.1 aralıklı, katlar 0.11 yüksekliğinde. Binalar (0,0)'dan başlayıp
# +x/+y yönünde kurulur ki pencereler duvar kenarına tam otursun; finish() orijini merkeze alır.
COL = 0.1
FH = A.FLOOR_H


def bevel_all(ob, width=0.0035):
    m = ob.modifiers.new("bevel", "BEVEL")
    m.width = width
    m.segments = 2
    m.limit_method = "ANGLE"
    m.harden_normals = False
    return ob


def solid(ob, t=0.012):
    m = ob.modifiers.new("solid", "SOLIDIFY")
    m.thickness = t
    m.offset = -1
    return ob


def facade_details(w, d, floors, wall_mat, trim_mat, front_door=True, sills=True, balconies=False, shop=False):
    """Pencere denizlikleri/lentoları, kat silmesi, korniş, kapı ve (bloklarda) balkon/dükkân bandı."""
    faces = [  # (başlangıç, yön, uzunluk, dışa normal)
        ((0, 0), (1, 0), w, (0, -1)), ((w, d), (-1, 0), w, (0, 1)),
        ((w, 0), (0, 1), d, (1, 0)), ((0, d), (0, -1), d, (-1, 0)),
    ]
    for fi, (o, t, L, n) in enumerate(faces):
        cols = int(round(L / COL))
        rot = math.atan2(t[1], t[0])
        for c in range(cols):
            cx = o[0] + t[0] * (c + 0.5) * COL + n[0] * 0.006
            cy = o[1] + t[1] * (c + 0.5) * COL + n[1] * 0.006
            for f in range(floors):
                z0 = f * FH
                if f == 0 and fi == 0 and front_door and c == cols // 2:
                    A.box(cx, cy, 0, 0.042, 0.014, 0.075, "wood_red", rot=rot)                 # kapı
                    A.box(cx + n[0] * 0.012, cy + n[1] * 0.012, 0.08, 0.07, 0.03, 0.008, trim_mat, rot=rot)  # saçak
                    continue
                if f == 0 and shop and fi == 0:
                    A.box(cx, cy, 0.012, 0.075, 0.012, 0.07, "glass", rot=rot)                  # vitrin
                    A.box(cx + n[0] * 0.01, cy + n[1] * 0.01, 0.086, 0.09, 0.03, 0.006, "wood_red", rot=rot)  # tente
                    continue
                if sills:
                    A.box(cx + n[0] * 0.004, cy + n[1] * 0.004, z0 + 0.024, 0.052, 0.016, 0.006, trim_mat, rot=rot)
                    A.box(cx + n[0] * 0.002, cy + n[1] * 0.002, z0 + 0.092, 0.05, 0.01, 0.008, trim_mat, rot=rot)
                if balconies and fi == 0 and f >= 1 and c % 2 == 1:
                    bx, by = cx + n[0] * 0.022, cy + n[1] * 0.022
                    A.box(bx, by, z0 + 0.018, 0.075, 0.04, 0.006, trim_mat, rot=rot)
                    A.box(bx + n[0] * 0.018, by + n[1] * 0.018, z0 + 0.024, 0.075, 0.004, 0.022, "steel", rot=rot)
    # kat silmesi ve korniş
    h = floors * FH
    if floors >= 2:
        A.box(w / 2, d / 2, FH - 0.004, w + 0.01, d + 0.01, 0.008, trim_mat)
    A.box(w / 2, d / 2, h - 0.006, w + 0.022, d + 0.022, 0.014, trim_mat)


def detailed_house(style, rng, i):
    w = [0.2, 0.3, 0.2, 0.3, 0.38, 0.28][i]
    d = [0.2, 0.2, 0.2, 0.2, 0.24, 0.28][i]
    floors = ([2, 2, 1, 1, 3, 2] if style != "orient" else [2, 1, 2, 1, 2, 2])[i]
    h = floors * FH
    if style == "orient":
        wall = rng.choice(["facade_beige_flat", "facade_whitewash"])
        bevel_all(A.box(w / 2, d / 2, 0, w, d, h, wall, top="concrete"))
        facade_details(w, d, floors, wall, "stone_sand", sills=True, balconies=i in (4, 5))
        A.box(w / 2, d / 2, h, w + 0.008, d + 0.008, 0.02, "stone_sand")       # parapet
        if i == 3:
            solid(A.hip_roof(w / 2, d / 2, h + 0.02, w, d, 0.05, "roof_terracotta"))
        if i == 4:  # iç avlulu/teraslı kent evi silueti
            A.box(w * 0.72, d * 0.5, h + 0.02, 0.07, d * 0.7, 0.055, wall)
            A.dome(w * 0.72, d * 0.5, h + 0.075, 0.035, "roof_copper", seg=12, height=0.55)
        if i == 5:  # gölgeli giriş revakı
            for x in (w * 0.28, w * 0.72):
                A.cylinder(x, -0.008, 0, 0.009, 0.09, "stone_sand", 10)
            A.box(w / 2, -0.008, 0.09, w * 0.62, 0.055, 0.012, "stone_sand")
        return
    if style == "nordic":
        wall = ["wood_red", "wood_yellow", "wood_white", "wood_red", "wood_yellow", "wood_white"][i]
        roof = rng.choice(["roof_dark", "roof_slate"])
        bevel_all(A.box(w / 2, d / 2, 0, w, d, h, wall))
        facade_details(w, d, floors, wall, "white")
        solid(A.gable_roof(w / 2, d / 2, h, w, d, 0.13, roof, math.pi / 2, 0.025, wall))
        A.chimney(w * 0.3, d / 2, h + 0.05, 0.0)
        if i >= 4:
            A.box(w / 2, -0.016, 0.035, w * 0.7, 0.07, 0.012, "wood_white")
        return
    if style == "east":
        wall = ["facade_pink", "facade_yellow", "wood_yellow", "facade_white", "facade_cream", "wood_white"][i]
        roof = ["roof_copper", "roof_slate", "roof_dark", "roof_copper", "roof_copper", "roof_slate"][i]
    else:
        wall = ["facade_cream", "facade_white", "facade_ochre", "facade_yellow", "brick_red", "facade_grey"][i]
        roof = ["roof_terracotta", "roof_slate", "roof_terracotta", "roof_dark", "roof_slate", "roof_terracotta"][i]
    bevel_all(A.box(w / 2, d / 2, 0, w, d, h, wall))
    facade_details(w, d, floors, wall, "white")
    solid(A.gable_roof(w / 2, d / 2, h, w, d, 0.11, roof, math.pi / 2 if w > d else 0.0, 0.028, wall))
    A.chimney(w * 0.25, d * 0.5, h + 0.04, 0.0)
    if i == 1:   # çatı penceresi
        A.box(w * 0.65, d * 0.28, h + 0.02, 0.045, 0.04, 0.045, wall)
        solid(A.gable_roof(w * 0.65, d * 0.28, h + 0.065, 0.045, 0.04, 0.025, roof, 0.0, 0.006), 0.006)
    if i == 4:   # sıra evlerde cepheyi bölen taş payandalar
        for x in (0.0, w * 0.5, w):
            A.box(x, -0.008, 0, 0.014, 0.018, h, "stone_light")
    if i == 5:   # köşe villa girişi ve küçük sundurma
        A.box(w / 2, -0.018, 0.065, w * 0.45, 0.065, 0.012, "stone_light")
        for x in (w * 0.34, w * 0.66):
            A.cylinder(x, -0.018, 0, 0.008, 0.065, "stone_light", 8)


def detailed_block(style, rng, i):
    w = [0.3, 0.4, 0.3, 0.4, 0.46, 0.42][i]
    d = [0.3, 0.3, 0.3, 0.3, 0.34, 0.36][i]
    floors = [3, 4, 5, 4, 5, 6][i]
    h = floors * FH
    if style == "orient":
        wall = ["facade_beige_flat", "facade_whitewash", "facade_beige_flat", "facade_whitewash", "facade_beige_flat", "facade_whitewash"][i]
        bevel_all(A.box(w / 2, d / 2, 0, w, d, h, wall, top="concrete"))
        facade_details(w, d, floors, wall, "stone_sand", shop=True, balconies=True)
        A.box(w / 2, d / 2, h, w + 0.01, d + 0.01, 0.02, "stone_sand")
        if i >= 4:
            A.box(w * 0.76, d * 0.68, h + 0.02, 0.09, 0.09, 0.07, "facade_beige_flat")
            A.dome(w * 0.76, d * 0.68, h + 0.09, 0.045, "roof_copper", seg=12, height=0.55)
        return
    walls = {"west": ["facade_cream", "facade_grey", "brick_red", "facade_white"],
             "east": ["facade_pink", "facade_yellow", "facade_grey", "facade_cream", "brick_red", "facade_white"],
             "nordic": ["facade_yellow", "brick_red", "facade_ochre", "facade_cream", "brick_dark", "facade_white"]}[style]
    if style == "west":
        walls += ["facade_ochre", "brick_dark"]
    wall = walls[i]
    bevel_all(A.box(w / 2, d / 2, 0, w, d, h, wall))
    facade_details(w, d, floors, wall, "stone_light", shop=(i % 2 == 0), balconies=(i >= 2))
    if style == "west" and i in (0, 3, 5):
        A.mansard_roof(w / 2, d / 2, h + 0.008, w, d, FH * 0.85, "roof_slate", "roof_slate")
        for k in range(int(round(w / COL))):
            A.box((k + 0.5) * COL, 0.04, h + 0.03, 0.035, 0.03, 0.045, "white")
    else:
        roof = {"west": "roof_terracotta", "east": "roof_copper", "nordic": "roof_dark"}[style]
        solid(A.hip_roof(w / 2, d / 2, h + 0.008, w, d, 0.09, roof, 0.0, 0.02))
    A.chimney(w * 0.2, d * 0.7, h + 0.05, 0.0)
    A.chimney(w * 0.8, d * 0.3, h + 0.05, 0.0)
    if i >= 4:
        # Büyük kent bloklarında belirgin giriş saçağı ve çatı servis hacmi.
        A.box(w / 2, -0.022, 0.09, w * 0.32, 0.075, 0.012, "stone_light")
        A.box(w * 0.72, d * 0.62, h + 0.012, 0.1, 0.08, 0.055, wall, top="roof_dark")


def door(x, y, w, d, rot, material="wood_red"):
    c, s = math.cos(rot), math.sin(rot)
    oy = -d / 2 - 0.004
    A.box(x - oy * s, y + oy * c, 0, 0.035, 0.012, 0.06, material, rot=rot)


def build_style(style, rng):
    made = []
    # evler: farklı genişlik/kat/çatı
    for i in range(6):
        A._parts.clear()
        detailed_house(style, random.Random(hash((style, "house", i)) & 0xffff), i)
        made.append(finish(f"{style}_house_{i}", "stone_sand" if style == "orient" else "stone_light"))
    for i in range(6):
        A._parts.clear()
        detailed_block(style, random.Random(hash((style, "block", i)) & 0xffff), i)
        made.append(finish(f"{style}_block_{i}", "stone_light"))
    A._parts.clear()
    A.church(0, 0, 0.0, style, big=True)
    made.append(finish(f"{style}_church_0"))
    A._parts.clear()
    if style == "west":
        A.palace(0, 0, "west")
    elif style == "orient":
        A.mosque(0, 0, 0.0, 1.5)
    elif style == "east":
        A.church(0, 0, 0.0, "east", big=True)
        A.box(0.0, -0.5, 0, 0.8, 0.3, 0.26, "facade_yellow")
        A.hip_roof(0.0, -0.5, 0.26, 0.8, 0.3, 0.07, "roof_copper", 0.0)
        A.flag(0.45, -0.5, 0.33)
    else:
        # İskandinav belediye sarayı: tuğla gövde + ince kule
        A.box(0, 0, 0, 0.8, 0.4, 0.3, "brick_red")
        A.hip_roof(0, 0, 0.3, 0.8, 0.4, 0.12, "roof_copper", 0.0)
        A.box(0.3, 0.0, 0, 0.14, 0.14, 0.75, "brick_red")
        A.lathe(0.3, 0.0, 0.75, [(0.09, 0), (0.0, 0.3)], "roof_copper", 8)
        A.flag(-0.3, 0.0, 0.42)
    made.append(finish(f"{style}_landmark_0"))
    A._parts.clear()
    A.factory(0, 0, 0.0, rng)
    made.append(finish(f"{style}_factory_0", "concrete"))
    return made


def build_port():
    A._parts.clear()
    A.box(0, 0.1, -0.04, 0.9, 0.5, 0.06, "concrete", uv=(0.4, 0.4))            # rıhtım
    A.box(0.15, -0.45, -0.04, 0.16, 0.5, 0.05, "concrete", uv=(0.4, 0.4))      # iskele
    A.box(-0.2, 0.2, 0.02, 0.36, 0.24, 0.16, "brick_red")
    A.gable_roof(-0.2, 0.2, 0.18, 0.36, 0.24, 0.08, "roof_slate", math.pi / 2, 0.01, "brick_red")
    for dx, dy in [(-0.025, -0.025), (0.025, -0.025), (-0.025, 0.025), (0.025, 0.025)]:
        A.box(0.28 + dx, 0.0 + dy, 0.02, 0.01, 0.01, 0.42, "crane")
    A.box(0.28, 0.0, 0.44, 0.08, 0.08, 0.05, "crane")
    A.box(0.28, -0.2, 0.48, 0.03, 0.5, 0.025, "crane")
    A.ship(0.42, -0.62, 0.0)
    ob = finish("port_0", "concrete")
    return [ob]


def build_bridge():
    """Çelik kafes köprü: 'bridge_span' x ekseninde 1 birim uzunluk (tekrarlanır), orijinde taş ayak;
    'bridge_end' rampalı taş başlık. Tabliye üstü z=0."""
    out = []
    A._parts.clear()
    W = 0.18
    A.box(0.5, 0, -0.035, 1.0, W, 0.035, "stone_light", uv=(0.3, 0.3))                 # açık renk taşıyıcı tabliye
    A.box(0.5, 0, 0.002, 1.0, W * 0.58, 0.006, "asphalt", uv=(0.3, 0.3))               # yol yüzeyi
    A.box(0.5, 0, -0.052, 1.0, W + 0.025, 0.017, "steel")                             # tabliye altı
    for side in (-1, 1):
        y = side * (W / 2 + 0.005)
        A.box(0.5, y, 0.11, 1.0, 0.014, 0.014, "stone_light")                          # açık üst başlık
        A.box(0.5, y, -0.01, 1.0, 0.014, 0.016, "stone_light")                         # açık alt başlık
        for k in range(5):
            x0 = k * 0.2
            A.box(x0, y, 0.0, 0.012, 0.012, 0.115, "steel")                           # dikme
            # çapraz: iki uç arası eğik çubuk
            import bmesh as _bm
            bm = _bm.new()
            _bm.ops.create_cube(bm, size=1.0)
            L = math.hypot(0.2, 0.11)
            from mathutils import Matrix as _M
            _bm.ops.transform(bm, matrix=_M.Translation((x0 + 0.1, y, 0.055)) @ _M.Rotation(math.atan2(0.11, 0.2) * (1 if k % 2 == 0 else -1), 4, "Y") @ _M.Diagonal((L, 0.01, 0.01, 1)), verts=bm.verts)
            A._finish(bm, ["steel"])
        A.box(1.0, y, 0.0, 0.012, 0.012, 0.115, "steel")
    for k in range(5):                                                                 # üst bağlantılar
        A.box(k * 0.2 + 0.1, 0, 0.11, 0.01, W + 0.02, 0.01, "steel")
    A.box(0.0, 0, -1.2, 0.07, W * 0.9, 1.16, "stone_light")                           # ayak (suya iner)
    A.box(0.0, 0, -0.06, 0.1, W + 0.04, 0.02, "stone_light")
    ob = finish("bridge_span", "stone_light")
    out.append(ob)
    A._parts.clear()
    A.box(0.15, 0, -0.35, 0.3, W + 0.04, 0.35, "stone_light")                         # başlık
    A.box(0.15, 0, -0.01, 0.3, W * 0.58, 0.012, "asphalt", uv=(0.3, 0.3))
    for side in (-1, 1):
        A.box(0.15, side * (W / 2 + 0.01), 0.0, 0.3, 0.015, 0.03, "stone_light")       # korkuluk
    out.append(finish("bridge_end", "stone_light"))
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(9)
    made = []
    for st in STYLES:
        made += build_style(st, rng)
    made += build_port()
    made += build_bridge()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in made:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "buildings.glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_apply=True)
    for ob in made:
        print(f"[bina] {ob.name}: {len(ob.data.polygons)} yüz, {ob.dimensions.x:.2f}x{ob.dimensions.y:.2f}")
    if RENDER_DIR:
        render(made)
    if SAVE_BLEND:
        arrange_library(made)
        add_review_assets()
        SAVE_BLEND.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(SAVE_BLEND))


def arrange_library(made):
    """İnsan gözüyle QA için tüm kiti düzenli bir Blender sahnesine dizer."""
    for ob in made:
        ob.hide_render = False
        ob.hide_viewport = False
        ob.rotation_euler = (0.0, 0.0, 0.0)
    rows = {"west": 3.0, "east": 1.0, "orient": -1.0, "nordic": -3.0}
    for style, y in rows.items():
        row = [o for o in made if o.name.startswith(style + "_")]
        x = -5.4
        for ob in row:
            ob.location = (x + ob.dimensions.x * 0.5, y, 0.0)
            x += max(ob.dimensions.x, 0.38) + 0.22
    extras = [o for o in made if not any(o.name.startswith(s + "_") for s in STYLES)]
    x = -1.8
    for ob in extras:
        ob.location = (x + ob.dimensions.x * 0.5, -5.0, 0.0)
        x += ob.dimensions.x + 0.35
    # Sahne Blender'da açıldığında koleksiyonun tamamı seçili ve kadraja hazır olsun.
    bpy.ops.object.select_all(action="DESELECT")
    for ob in made:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = made[0]


def add_review_assets():
    """Tam şehir dioramaları ve stratejik yapıları QA sahnesine ekler."""
    review_specs = [(OUT / "airbase.glb", Vector((-2.0, -6.7, 0.0))),
                    (OUT / "trees.glb", Vector((2.0, -6.7, 0.0)))]
    sizes = ("town", "medium", "large", "capital")
    for row, style in enumerate(STYLES):
        for col, size in enumerate(sizes):
            review_specs.append((OUT / f"city_{style}_{size}.glb",
                                 Vector((-15.0 + col * 10.0, -13.0 - row * 12.0, 0.0))))
    for path, anchor in review_specs:
        if not path.exists():
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        imported = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        imported.sort(key=lambda o: o.name)
        for ob in imported:
            ob.location += anchor
            ob["qa_asset"] = path.stem
    bpy.ops.object.select_all(action="SELECT")


def render(made):
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 800
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
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    for st in STYLES:
        row = [o for o in made if o.name.startswith(st + "_")]
        for o in made:
            o.hide_render = o not in row
        x = 0.0
        for o in row:
            o.location = (x + o.dimensions.x / 2, 0, 0)
            x += o.dimensions.x + 0.12
        cam.data.ortho_scale = x * 1.05
        cam.location = (x / 2, -x * 0.9, x * 0.62)
        cam.rotation_euler = (math.radians(58), 0, 0)
        scene.render.filepath = str(RENDER_DIR / f"buildings_{st}.png")
        bpy.ops.render.render(write_still=True)


main()
