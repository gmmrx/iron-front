"""
Şehir dioramaları: ayrıntılı bina kitinin (build_buildings.py: pencere denizlikleri, kornişler, balkonlar, dükkân
vitrinleri, bacalar) kopyalarıyla kurulan kentler.
    python3 tools/blender/make_industry_textures.py      # kent zemini ve bahçe dokuları (bir kez)
    Blender --background --factory-startup --python tools/blender/build_cities.py -- [--render DIR] [--only city_west_capital]
Çıktı: assets/models/city_<stil>_<boyut>.gltf + .bin (tek mesh; dokular ortak assets/models/textures/ klasöründen).
Düzen: merkezde meydan ve simge yapı; iç halkada avlulu çevre blokları (sokak kenarına dizili, ortası bahçe);
dışta bahçeli evler; en dışta seyrek evler ve ağaçlar. Taban bahçe/çimen; sokaklar asfalt + kaldırım.
Oyunda zemin malzemeleri (garden, city_paving) kenardan dağıtılarak araziyle kaynaşır (conform.gdshader, fade_edge);
taban yarıçapları CityLayer3D.CITY_EXTENT ile eşleşir.
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_assets as A  # noqa: E402
import build_buildings as B  # noqa: E402

OUT = A.OUT
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None
STYLES = ["west", "east", "orient", "nordic"]
SIZES = {"town": (0.95, 0.8), "medium": (1.45, 1.25), "large": (2.1, 1.8), "capital": (2.7, 2.3)}

A.MATERIALS.update({
    "city_paving": ("city_paving", None, 0.92, 0), "city_paving_warm": ("city_paving_warm", None, 0.92, 0),
    "garden": ("garden", None, 1.0, 0),
})


# ------------------------------------------------------------------ bina kiti
KIT = {}          # (stil, tür, i) -> şablon obje (dışa aktarılmaz)


def build_kit(style):
    for i in range(6):
        A._parts.clear()
        B.detailed_house(style, random.Random(hash((style, "house", i)) & 0xffff), i)
        KIT[(style, "house", i)] = B.finish(f"kit_{style}_house_{i}", "stone_sand" if style == "orient" else "stone_light")
    for i in range(6):
        A._parts.clear()
        B.detailed_block(style, random.Random(hash((style, "block", i)) & 0xffff), i)
        KIT[(style, "block", i)] = B.finish(f"kit_{style}_block_{i}", "stone_light")
    for ob in KIT.values():
        ob.hide_render = True
        ob.hide_set(True)


def footprint(kit):
    xs = [v.co.x for v in kit.data.vertices]
    ys = [v.co.y for v in kit.data.vertices]
    return max(xs) - min(xs), max(ys) - min(ys)


def stamp(kit, x, y, rot):
    """Kit binasının kopyasını (x, y)'ye, ön cephesi (yerel -y) rot yönüne dönük koy."""
    ob = kit.copy()
    ob.data = kit.data.copy()
    bpy.context.collection.objects.link(ob)
    ob.hide_render = False
    ob.hide_set(False)
    ob.data.transform(Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(rot, 4, "Z"))
    A._parts.append(ob)
    return ob


def face_rot(nx, ny):
    """Ön cephesi (nx, ny) dış normaline bakan binanın z dönüşü."""
    return math.atan2(nx, -ny)


# ------------------------------------------------------------------ kent dokusu
def ellipse_ground(rx, ry, rng, material, z=0.0, verts=36, jitter=0.06, depth=0.03):
    pts = []
    for i in range(verts):
        a = 2 * math.pi * i / verts
        k = 1.0 + rng.uniform(-jitter, jitter)
        pts.append((math.cos(a) * rx * k, math.sin(a) * ry * k))
    A.poly_prism(pts, z - depth, z + 0.002, material, (0.6, 0.6))


def inside(x, y, rx, ry, margin=0.0):
    return (x / max(rx - margin, 1e-3)) ** 2 + (y / max(ry - margin, 1e-3)) ** 2 < 1.0


def rnorm(x, y, rx, ry):
    return math.sqrt((x / rx) ** 2 + (y / ry) ** 2)


def street(x0, y0, ang, length, width, rx, ry, surface, margin=0.26):
    """Elips içinde kalan sokak parçaları: asfalt şerit + iki yanda kaldırım."""
    steps = max(4, int(length / 0.12))
    c, s = math.cos(ang), math.sin(ang)
    for k in range(steps):
        t = -length / 2 + (k + 0.5) * length / steps
        px, py = x0 + c * t, y0 + s * t
        if not inside(px, py, rx, ry, margin):
            continue
        seg = length / steps + 0.002
        A.box(px, py, 0.002, seg, width, 0.003, surface, rot=ang, uv=(0.3, 0.3))
        for side in (-1, 1):
            ox, oy = -s * side * (width / 2 + 0.008), c * side * (width / 2 + 0.008)
            A.box(px + ox, py + oy, 0.002, seg, 0.016, 0.006, "concrete", rot=ang, uv=(0.3, 0.3))


def fitting(style, kind, limit):
    """Parsele sığan kit binaları (taban ölçüsünün uzun kenarı limit altında)."""
    return [KIT[(style, kind, i)] for i in range(6) if max(footprint(KIT[(style, kind, i)])) <= limit]


def lot(style, cx, cy, L, rot, rng, kind):
    """Parsel: ortada tek bina, çevresi bahçe; bina parselden taşmaz, komşu parselle arada sokak ve boşluk kalır."""
    c, s = math.cos(rot), math.sin(rot)
    A.box(cx, cy, 0.001, L * 0.96, L * 0.96, 0.002, "garden", rot=rot, uv=(0.3, 0.3))
    kits = fitting(style, kind, L * 0.88)
    if not kits:
        return
    kit = rng.choice(kits)
    w, d = footprint(kit)
    # bina sokağa (parselin güney kenarına) yaslanır, arkasında bahçe kalır
    ly = -(L / 2 - d / 2 - 0.03)
    stamp(kit, cx - ly * s, cy + ly * c, face_rot(s, -c))
    if max(w, d) <= L * 0.66:
        for qx in (-1, 1):
            if rng.random() < 0.6:
                ox, oy = qx * L * 0.33, L * 0.33
                A.tree(cx + ox * c - oy * s, cy + ox * s + oy * c, rng, 0.9, style)


def city(style, size):
    rx, ry = SIZES[size]
    rng = random.Random(hash((size, style, "v4")) & 0xffff)
    ellipse_ground(rx * 1.04, ry * 1.04, rng, "garden")
    if size == "town":
        return town(style, rx, ry, rng)
    spacing = 0.62
    street_w = 0.06
    L = spacing - street_w - 0.03
    rot = rng.uniform(-0.3, 0.3)
    c, s = math.cos(rot), math.sin(rot)
    surface = "asphalt" if style != "orient" else "ground_dirt"
    n = int(max(rx, ry) / spacing) + 2
    for i in range(-n, n + 1):
        o = (i + 0.5) * spacing
        lng = 2.2 * max(rx, ry)
        street(o * c, o * s, rot + math.pi / 2, lng, street_w, rx, ry, surface)
        street(-o * s, o * c, rot, lng, street_w, rx, ry, surface)
    dense = {"medium": 0.45, "large": 0.6, "capital": 0.68}[size]
    plaza = {"medium": 0.36, "large": 0.42, "capital": 0.62}[size]
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            bx0, by0 = i * spacing, j * spacing
            wx, wy = bx0 * c - by0 * s, bx0 * s + by0 * c
            if not inside(wx, wy, rx, ry, 0.3):
                if inside(wx, wy, rx, ry, 0.0) and rng.random() < 0.5:
                    A.tree(wx + rng.uniform(-0.1, 0.1), wy + rng.uniform(-0.1, 0.1), rng, 1.0, style)
                continue
            if math.hypot(wx, wy) < plaza:
                continue
            r = rnorm(wx, wy, rx, ry)
            # sade: her parselde tek bina; dış halkada bazı parseller yalnız bahçe
            if r > dense and rng.random() < 0.25:
                A.box(wx, wy, 0.001, L * 0.96, L * 0.96, 0.002, "garden", rot=rot, uv=(0.3, 0.3))
                A.tree(wx, wy, rng, 1.1, style)
                continue
            lot(style, wx, wy, L, rot, rng, "block" if r < dense else "house")
    # meydan + simge yapı
    A.box(0, 0, 0.002, plaza * 1.7, plaza * 1.7, 0.004, "city_paving_warm", rot=rot, uv=(0.25, 0.25))
    landmark(style, size, rot, rng, plaza)
    # kenar ağaçları
    for _ in range({"medium": 18, "large": 24, "capital": 30}[size]):
        a = rng.uniform(0, 2 * math.pi)
        k = rng.uniform(0.92, 1.05)
        A.tree(math.cos(a) * rx * k, math.sin(a) * ry * k, rng, 1.0, style)


def landmark(style, size, rot, rng, plaza):
    if size == "capital":
        if style == "west":
            A.palace(0, 0, "west")
        elif style == "orient":
            A.mosque(0, 0, rot, 1.8)
        elif style == "east":
            A.kremlin(0, 0)
        else:
            A.box(0, 0, 0, 0.8, 0.4, 0.3, "brick_red")
            A.hip_roof(0, 0, 0.3, 0.8, 0.4, 0.12, "roof_copper", 0.0)
            A.box(0.3, 0.0, 0, 0.14, 0.14, 0.75, "brick_red")
            A.lathe(0.3, 0.0, 0.75, [(0.09, 0), (0.0, 0.3)], "roof_copper", 8)
        # meydan çevresinde ağaç sıraları
        for k in range(12):
            a = k * math.pi / 6
            A.tree(math.cos(a) * plaza * 0.78, math.sin(a) * plaza * 0.78, rng, 0.85, style)
    else:
        if style == "orient":
            A.mosque(0, 0, rot, 1.2 if size == "large" else 1.0)
        else:
            A.church(0, 0, rot, style, big=size == "large")
        for k in range(6):
            a = k * math.pi / 3 + 0.4
            A.tree(math.cos(a) * plaza * 0.72, math.sin(a) * plaza * 0.72, rng, 0.8, style)


def town(style, rx, ry, rng):
    """Kasaba: ana cadde boyunca aralıklı evler, kilise/cami, bahçeler ve çevresinde ağaçlar."""
    rot = rng.uniform(0, math.pi)
    c, s = math.cos(rot), math.sin(rot)
    street(0, 0, rot, 2.0, 0.06, rx, ry, "ground_dirt", 0.08)
    street(0, 0, rot + math.pi / 2, 1.2, 0.05, rx, ry, "ground_dirt", 0.12)
    if style == "orient":
        A.mosque(0.2 * -s, 0.2 * c, rot, 0.8)
    else:
        A.church(0.2 * -s, 0.2 * c, rot, style)
    houses = fitting(style, "house", 0.36)
    for k in (-2, -1, 1, 2):
        for side in (-1, 1):
            t = k * 0.42 + rng.uniform(-0.02, 0.02)
            kit = rng.choice(houses)
            w, d = footprint(kit)
            o = side * (0.07 + d / 2)
            stamp(kit, t * c - o * s, t * s + o * c, face_rot(-side * -s, -side * c))
            if rng.random() < 0.5:
                o2 = side * (0.07 + d + 0.08)
                A.tree(t * c - o2 * s, t * s + o2 * c, rng, 1.0, style)
    for _ in range(16):
        a = rng.uniform(0, 2 * math.pi)
        k = rng.uniform(0.8, 1.05)
        A.tree(math.cos(a) * rx * k, math.sin(a) * ry * k * 0.9, rng, 1.0, style)


# ------------------------------------------------------------------ çıkış
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    built = {}
    for style in STYLES:
        build_kit(style)
        for size in SIZES:
            name = f"city_{style}_{size}"
            if ONLY and name != ONLY:
                continue
            A._parts.clear()
            city(style, size)
            ob = A.finalize(name)
            ob.data.validate(clean_customdata=False)
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.convert(target="MESH")
            # GLTF + ortak doku klasörü: dokular her şehirde kopyalanmaz (web paketi küçük kalır)
            bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.gltf"), use_selection=True, export_format="GLTF_SEPARATE",
                                      export_texture_dir="textures", export_apply=True, export_yup=True,
                                      export_image_format="AUTO")
            built[name] = ob
            print(f"[kent] {name}: {len(ob.data.polygons)} yüz, {ob.dimensions.x:.2f}x{ob.dimensions.y:.2f}")
    if RENDER_DIR:
        A.RENDER_DIR = RENDER_DIR
        for ob in KIT.values():
            ob.hide_render = True
        A.render_previews(built)


if __name__ == "__main__":
    main()
