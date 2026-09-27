"""
Sanayi ve askerî tesis kütüphanesi: her inşaat türünün haritada dikilen binası.
    python3 tools/blender/make_industry_textures.py      # dokular (bir kez)
    Blender --background --factory-startup --python tools/blender/build_industry.py -- [--render DIR] [--only ad] [--save-blend FILE]
Çıktılar:
    assets/models/industry.gltf (+.bin)  oyun (dokular ortak assets/models/textures/ klasöründen): her tesis bir mesh (ind_<tür>), hareketli parçalar ayrı mesh
                                        (ind_<tür>__<parça>, orijini pivotta) ve ek pivotlar boş düğüm (ind_<tür>__<parça>__pK)
    tools/blender/scenes/industry_rigged.glb    rig'li sürüm: hareketli parçalar kemiğe bağlı, döngülü animasyonlarla
    tools/blender/scenes/industry_library.blend rig'li kütüphane sahnesi (Blender'da açıp incelemek için)
Birim ve yön: build_assets.py ile aynı (1 kat = 0.11); orijin tesis tabanının merkezi, z=0 zemin.
Kıyı tesislerinde (tersane, deniz üssü) su tarafı -Y'dir (Godot'da +Z).
Parça davranışları oyunda game/map/industry_layer.gd PART_MODES ile eşleşir.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_assets as A  # noqa: E402

OUT = A.OUT
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None
SCENES = A.ROOT / "tools" / "blender" / "scenes"
SAVE_BLEND = Path(ARGS[ARGS.index("--save-blend") + 1]) if "--save-blend" in ARGS else SCENES / "industry_library.blend"

# ------------------------------------------------------------------ malzemeler ve UV ölçekleri
A.MATERIALS.update({
    "ind_brick": ("ind_brick", None, 0.9, 0), "ind_brick_yellow": ("ind_brick_yellow", None, 0.9, 0),
    "corrugated": ("corrugated", None, 0.55, 0.35), "corrugated_dark": ("corrugated_dark", None, 0.6, 0.3),
    "corrugated_red": ("corrugated_red", None, 0.65, 0.2), "skylight": ("skylight", None, 0.15, 0.3),
    "yard_concrete": ("yard_concrete", None, 0.92, 0), "yard_asphalt": ("yard_asphalt", None, 0.85, 0),
    "gravel": ("gravel", None, 1.0, 0), "ballast": ("ballast", None, 1.0, 0), "sandbag": ("sandbag", None, 1.0, 0),
    "timber": ("timber", None, 0.85, 0), "camo": ("camo", None, 0.75, 0.1),
    "steel_panel": ("steel_panel", None, 0.5, 0.6), "crane_paint": ("crane_paint", None, 0.5, 0.35),
    "tank_white": ("tank_white", None, 0.45, 0.3), "tank_grey": ("tank_grey", None, 0.5, 0.4),
    "office_cream": ("office_cream", None, 0.85, 0),
    "rail": (None, (0.34, 0.33, 0.33), 0.3, 0.9), "rubber": (None, (0.06, 0.06, 0.06), 0.9, 0),
    "black": (None, (0.05, 0.05, 0.055), 0.5, 0.4), "tarp": (None, (0.30, 0.31, 0.20), 0.9, 0),
    "sand": (None, (0.72, 0.62, 0.42), 1.0, 0), "coal": (None, (0.07, 0.07, 0.07), 0.9, 0),
    "khaki": (None, (0.45, 0.42, 0.30), 0.8, 0), "dark_green": (None, (0.18, 0.24, 0.16), 0.7, 0.2),
    "lamp": (None, (0.95, 0.9, 0.7), 0.3, 0),
})
UV = {
    "ind_brick": (0.24, 0.2), "ind_brick_yellow": (0.24, 0.2), "corrugated": (0.2, 0.2), "corrugated_dark": (0.2, 0.2),
    "corrugated_red": (0.2, 0.2), "skylight": (0.1, 0.1), "yard_concrete": (0.5, 0.5), "yard_asphalt": (0.5, 0.5),
    "gravel": (0.3, 0.3), "ballast": (0.2, 0.2), "sandbag": (0.08, 0.05), "timber": (0.12, 0.12), "camo": (0.5, 0.5),
    "steel_panel": (0.16, 0.16), "crane_paint": (0.12, 0.12), "tank_white": (0.3, 0.16), "tank_grey": (0.3, 0.16),
    "office_cream": (A.TILE_W, A.TILE_H), "brick_red": (0.2, 0.08), "brick_dark": (0.2, 0.08),
    "concrete": (0.4, 0.4), "roof_slate": (0.2, 0.2), "roof_terracotta": (0.2, 0.2), "wood_yellow": (0.1, 0.1),
    "wood_red": (0.12, 0.12),
}


def uv(m):
    return UV.get(m, (A.TILE_W, A.TILE_H))


_EMIT = {}


def emissive(name, color, strength):
    if name in _EMIT:
        return name
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    A._mats[name] = m
    A.MATERIALS[name] = (None, color, 0.5, 0)
    _EMIT[name] = m
    return name


# ------------------------------------------------------------------ geometri yardımcıları
def bx(x, y, z, w, d, h, m, top=None, rot=0.0, bevel=0.0):
    ob = A.box(x, y, z, w, d, h, m, top, rot, uv(m))
    if bevel > 0:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 1
        b.limit_method = "ANGLE"
    return ob


def place(ob, M):
    ob.data.transform(M)
    return ob


def beam(p0, p1, t, m, t2=None):
    """p0 → p1 arası kare kesitli kiriş (kafes, iskele, çatı makası)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    ob = A.box(0, 0, 0, t, t2 or t, L, m, None, 0.0, uv(m))
    up = "Y" if abs(d.normalized().y) < 0.95 else "X"
    rot = d.to_track_quat("Z", up).to_matrix().to_4x4()
    return place(ob, Matrix.Translation(p0) @ rot)


def pipe(p0, p1, r, m, seg=8):
    """p0 → p1 arası silindir (boru, yatay tank, direk)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    ob = A.lathe(0, 0, 0, [(r, 0), (r, d.length)], m, seg)
    up = "Y" if abs(d.normalized().y) < 0.95 else "X"
    rot = d.to_track_quat("Z", up).to_matrix().to_4x4()
    return place(ob, Matrix.Translation(p0) @ rot)


def lattice_mast(x, y, z, w, h, m, step=0.06, t=0.006):
    """Kafes kule: dört köşe dikmesi + her yüzde çapraz bağlantılar."""
    c = [(x - w / 2, y - w / 2), (x + w / 2, y - w / 2), (x + w / 2, y + w / 2), (x - w / 2, y + w / 2)]
    for px, py in c:
        beam((px, py, z), (px, py, z + h), t, m)
    n = max(1, int(h / step))
    for k in range(n):
        z0, z1 = z + h * k / n, z + h * (k + 1) / n
        for i in range(4):
            a, b = c[i], c[(i + 1) % 4]
            beam((a[0], a[1], z0), (b[0], b[1], z1), t * 0.6, m)
            beam((a[0], a[1], z1), (b[0], b[1], z1), t * 0.6, m)


def lattice_boom(p0, p1, w, m, step=0.05, t=0.005):
    """Yatay kafes kiriş (vinç kolu): üçgen kesit."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0)
    L = d.length
    fwd = d.normalized()
    side = fwd.cross(Vector((0, 0, 1))).normalized() * (w / 2)
    up = Vector((0, 0, w * 0.9))
    rails = [(p0 - side, p1 - side), (p0 + side, p1 + side), (p0 + up, p1 + up * 0.35)]
    for a, b in rails:
        beam(a, b, t, m)
    n = max(1, int(L / step))
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        ups = up * (1 - 0.65 * t0)
        ups1 = up * (1 - 0.65 * t1)
        a0, b0 = p0.lerp(p1, t0) - side, p0.lerp(p1, t0) + side
        a1, b1 = p0.lerp(p1, t1) - side, p0.lerp(p1, t1) + side
        c0, c1 = p0.lerp(p1, t0) + ups, p0.lerp(p1, t1) + ups1
        beam(a0, b1, t * 0.5, m)
        beam(a0, c1, t * 0.5, m)
        beam(b0, c1, t * 0.5, m)
        beam(a1, b1, t * 0.5, m)


def sawtooth(x, y, z, w, d, n, h, roof="corrugated_dark", glass="skylight", end="ind_brick"):
    """Testere dişi çatı: sırtlar x boyunca, cam yüzler +y'ye (kuzey ışığı) bakar."""
    step = d / n
    for i in range(n):
        y0 = y - d / 2 + i * step
        y1 = y0 + step
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in [
            (x - w / 2, y0, z), (x + w / 2, y0, z), (x + w / 2, y1, z + h), (x - w / 2, y1, z + h),
            (x - w / 2, y1, z), (x + w / 2, y1, z)]]
        f_roof = bm.faces.new([v[0], v[1], v[2], v[3]])
        f_glass = bm.faces.new([v[3], v[2], v[5], v[4]])
        f_e0 = bm.faces.new([v[0], v[3], v[4]])
        f_e1 = bm.faces.new([v[1], v[5], v[2]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ids = {f_roof: 0, f_glass: 1, f_e0: 2, f_e1: 2}
        A._finish(bm, [roof, glass, end], lambda f, ids=ids: ids.get(f, 0), uv(roof))
        # sırt boyunca ince saçak/dere
        bx(x, y1 + 0.002, z + h, w + 0.01, 0.008, 0.006, "steel")


def monitor_roof(x, y, z, w, d, h, roof="corrugated", glass="skylight", rot=0.0):
    """Fener (monitör) çatı: alçak beşik + ortada cam şeritli yükseltilmiş sırt."""
    A.gable_roof(x, y, z, w, d, h * 0.55, roof, rot, 0.012)
    c, s = math.cos(rot), math.sin(rot)
    bx(x, y, z + h * 0.35, w * 0.34, d * 0.96, h * 0.32, glass, rot=rot)
    A.gable_roof(x, y, z + h * 0.67, w * 0.42, d * 0.98, h * 0.3, roof, rot, 0.008)


def track(x, y, rot, L, sleeper_step=0.022):
    """Demiryolu: balast şeridi + traversler + iki ray (yerel y boyunca)."""
    c, s = math.cos(rot), math.sin(rot)

    def at(lx, ly):
        return x + lx * c - ly * s, y + lx * s + ly * c
    px, py = at(0, 0)
    bx(px, py, 0.0, 0.07, L, 0.007, "ballast", rot=rot)
    n = int(L / sleeper_step)
    for k in range(n):
        ly = -L / 2 + (k + 0.5) * sleeper_step
        qx, qy = at(0, ly)
        bx(qx, qy, 0.007, 0.052, 0.009, 0.004, "timber", rot=rot)
    for lx in (-0.0165, 0.0165):
        qx, qy = at(lx, 0)
        bx(qx, qy, 0.011, 0.004, L, 0.005, "rail", rot=rot)


def wheel_set(cx, cy, z, rot, n, spacing, r=0.011, gauge=0.033, m="black"):
    c, s = math.cos(rot), math.sin(rot)
    for k in range(n):
        ly = (k - (n - 1) / 2) * spacing
        for lx in (-gauge / 2, gauge / 2):
            px, py = cx + lx * c - ly * s, cy + lx * s + ly * c
            ob = A.lathe(0, 0, 0, [(r, 0), (r, 0.006)], m, 10)
            place(ob, Matrix.Translation((px, py, z + r)) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Translation((0, 0, -0.003)))


def boxcar(x, y, rot, m="wood_red"):
    bx(x, y, 0.028, 0.044, 0.12, 0.05, m, "roof_dark", rot)
    bx(x, y, 0.018, 0.04, 0.124, 0.01, "black", rot=rot)
    wheel_set(x, y, 0.007, rot, 2, 0.08)


def tank_car(x, y, rot, m="black"):
    c, s = math.cos(rot), math.sin(rot)
    bx(x, y, 0.018, 0.04, 0.12, 0.01, "black", rot=rot)
    p0 = Vector((x - 0.055 * -s, y - 0.055 * c, 0.05))
    p1 = Vector((x + 0.055 * -s, y + 0.055 * c, 0.05))
    pipe(p0, p1, 0.022, m, 12)
    A.cylinder(x, y, 0.07, 0.008, 0.012, m, 8)
    wheel_set(x, y, 0.007, rot, 2, 0.08)


def locomotive(x, y, rot):
    c, s = math.cos(rot), math.sin(rot)

    def at(ly, z):
        return Vector((x - ly * s, y + ly * c, z))
    bx(x, y, 0.018, 0.042, 0.15, 0.012, "black", rot=rot)
    pipe(at(-0.06, 0.05), at(0.035, 0.05), 0.022, "black", 14)
    A.cylinder(*at(-0.045, 0.07)[:2], 0.07, 0.008, 0.028, "black", 10)       # baca
    A.dome(*at(-0.01, 0.07)[:2], 0.07, 0.011, "black", 10)                     # buhar domu
    bx(*at(0.055, 0)[:2], 0.03, 0.046, 0.045, 0.06, "black", "roof_dark", rot)  # kabin
    bx(*at(0.055, 0.0)[:2], 0.05, 0.047, 0.03, 0.012, "glass", rot=rot)
    bx(*at(0.11, 0)[:2], 0.024, 0.044, 0.06, 0.036, "black", "coal", rot)       # kömürlük
    bx(*at(-0.08, 0)[:2], 0.02, 0.044, 0.006, 0.02, "hull_red", rot=rot)       # ön tampon
    wheel_set(x - 0.0 * s, y, 0.007, rot, 4, 0.034, 0.014)


def truck(x, y, rot, m="olive", cargo="tarp"):
    c, s = math.cos(rot), math.sin(rot)

    def at(ly):
        return x - ly * s, y + ly * c
    bx(*at(-0.03), 0.012, 0.034, 0.028, 0.03, m, rot=rot)                 # kabin
    bx(*at(-0.03), 0.03, 0.03, 0.02, 0.006, "glass", rot=rot)
    bx(*at(0.018), 0.012, 0.038, 0.062, 0.012, m, rot=rot)                # kasa
    A.gable_roof(*at(0.018), 0.024, 0.036, 0.06, 0.018, cargo, rot + math.pi / 2, 0.002)
    wheel_set(*at(0.0), 0.0, rot, 2, 0.05, 0.009, 0.036, "rubber")


def crates(x, y, rot, n, rng, m="wood_yellow"):
    c, s = math.cos(rot), math.sin(rot)
    for k in range(n):
        lx, ly = rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)
        sz = rng.uniform(0.012, 0.02)
        z = 0.0 if rng.random() < 0.7 else sz
        bx(x + lx * c - ly * s, y + lx * s + ly * c, z, sz, sz, sz, m, rot=rot + rng.uniform(-0.3, 0.3))


def barrels(x, y, n, rng, m="hull_red"):
    for k in range(n):
        a = k * 2.4
        r = 0.012 * math.sqrt(k)
        A.cylinder(x + math.cos(a) * r, y + math.sin(a) * r, 0, 0.0055, 0.016, m, 8)


def fence(points, h=0.035, step=0.05, m="steel"):
    for i in range(len(points) - 1):
        p0, p1 = Vector((*points[i], 0)), Vector((*points[i + 1], 0))
        n = max(1, int((p1 - p0).length / step))
        for k in range(n + 1):
            p = p0.lerp(p1, k / n)
            beam(p, p + Vector((0, 0, h)), 0.003, m)
        for zz in (h * 0.4, h * 0.95):
            beam(p0 + Vector((0, 0, zz)), p1 + Vector((0, 0, zz)), 0.0015, m)


def yard(w, d, m="yard_concrete", x=0.0, y=0.0):
    """Tesis avlusu: zemine gömülü kalın plaka (eğimli arazide havada kalmaz), üst yüzü avlu dokusu."""
    bx(x, y, -0.14, w, d, 0.145, "concrete", m)
    bx(x, y, 0.004, w + 0.006, d + 0.006, 0.002, m)


def pilasters(x, y, w, d, h, m, step, rot=0.0, depth=0.012):
    """Uzun duvarlarda payandalar (cepheye ritim ve gölge)."""
    c, s = math.cos(rot), math.sin(rot)
    n = int(round(w / step))
    for k in range(n + 1):
        lx = -w / 2 + k * w / n
        for ly in (-d / 2 - depth / 2, d / 2 + depth / 2):
            bx(x + lx * c - ly * s, y + lx * s + ly * c, 0, 0.018, depth, h, m, rot=rot)


def chimney(x, y, h, r=0.034, m="brick_dark"):
    """Yüksek sanayi bacası: kare kaide, konik gövde, çelik bilezikler, taç."""
    bx(x, y, 0, r * 2.4, r * 2.4, h * 0.1, m, "concrete", bevel=0.002)
    A.cylinder(x, y, h * 0.1, r, h * 0.9, m, 16, r_top=r * 0.68)
    for t in (0.35, 0.6, 0.82):
        rr = r * (1 - 0.32 * (t - 0.1) / 0.9) + 0.002
        A.cylinder(x, y, h * t, rr, 0.006, "black", 16)
    A.cylinder(x, y, h, r * 0.8, 0.02, "black", 16)
    A.cylinder(x, y, h + 0.02, r * 0.62, 0.004, "coal", 16)


def water_tower(x, y, h=0.26, r=0.055, m="tank_grey"):
    legs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    k = r * 0.75
    for i, (lx, ly) in enumerate(legs):
        beam((x + lx * k * 1.2, y + ly * k * 1.2, 0), (x + lx * k, y + ly * k, h), 0.007, "steel")
        nx, ny = legs[(i + 1) % 4]
        for zz in (h * 0.33, h * 0.66):
            beam((x + lx * k * 1.1, y + ly * k * 1.1, zz), (x + nx * k * 1.1, y + ny * k * 1.1, zz), 0.003, "steel")
    A.cylinder(x, y, h, r, r * 1.3, m, 18)
    A.lathe(x, y, h + r * 1.3, [(r * 1.03, 0), (r * 0.05, r * 0.5), (0.0, r * 0.52)], "steel", 18)


def storage_tank(x, y, r, h, m="tank_white"):
    A.cylinder(x, y, 0, r, h, m, 24)
    A.lathe(x, y, h, [(r * 1.01, 0), (r * 0.5, r * 0.12), (0.0, r * 0.15)], "tank_grey", 24)
    A.cylinder(x, y, h - 0.004, r + 0.002, 0.006, "steel", 24)          # üst bilezik
    # dış merdiven: tank çevresinde yükselen basamak şeridi
    for k in range(10):
        a = k * 0.26
        zz = h * (k + 0.5) / 10
        bx(x + math.cos(a) * (r + 0.006), y + math.sin(a) * (r + 0.006), zz, 0.012, 0.006, 0.003, "steel", rot=a + math.pi / 2)


def column(x, y, r, h, platforms=3, m="steel_panel"):
    """Damıtma kolonu: gövde, platform halkaları, üst başlık, yan boru."""
    A.cylinder(x, y, 0, r * 1.25, 0.02, "concrete", 12)
    A.cylinder(x, y, 0.02, r, h, m, 14)
    A.dome(x, y, 0.02 + h, r, m, 14, 0.6)
    for k in range(platforms):
        zz = 0.02 + h * (k + 1) / (platforms + 1)
        A.cylinder(x, y, zz, r + 0.012, 0.004, "steel", 14)
        for a in range(0, 360, 60):
            ar = math.radians(a)
            beam((x + math.cos(ar) * (r + 0.012), y + math.sin(ar) * (r + 0.012), zz),
                 (x + math.cos(ar) * (r + 0.012), y + math.sin(ar) * (r + 0.012), zz + 0.014), 0.0015, "steel")
    pipe((x + r * 0.9, y, 0.02 + h * 0.95), (x + r * 0.9, y, 0.02), 0.005, "steel", 6)


def hull(x, y, L, W, H, done=1.0, m_low="hull_red", m_up="hull", deck="deck"):
    """Gemi gövdesi (yerel y boyunca, pruva -y): istasyon kesitlerinden örülen gerçek gövde; sivri pruva, yuvarlak kıç,
    su hattının altı ayrı boya. done < 1: pruva tarafındaki istasyonlar yalnız kaburga (yapım hâlinde)."""
    n = 16
    prof = [(-1.0, 1.0), (-0.98, 0.62), (-0.86, 0.3), (-0.55, 0.08), (0.0, 0.0), (0.55, 0.08), (0.86, 0.3), (0.98, 0.62), (1.0, 1.0)]

    def half(t):
        if t < 0.32:
            return W / 2 * max(0.02, (t / 0.32) ** 0.75)
        if t > 0.86:
            return W / 2 * (1 - 0.3 * ((t - 0.86) / 0.14) ** 1.5)
        return W / 2

    def keel(t):
        return H * 0.25 * max(0.0, (0.12 - t) / 0.12)           # pruvada omurga yükselir

    def sheer(t):
        return H + H * 0.18 * (1 - t) ** 3                       # güverte pruvaya doğru kalkar
    rings = []
    for i in range(n + 1):
        t = i / n
        yy = y - L / 2 + t * L
        hw, z0, z1 = half(t), keel(t), sheer(t)
        rings.append([(x + u * hw, yy, z0 + (z1 - z0) * v) for (u, v) in prof])
    solid_from = int(round(n * (1 - done)))
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings[solid_from:]]
    faces_low, faces_up = [], []
    for i in range(len(vr) - 1):
        for j in range(len(prof) - 1):
            f = bm.faces.new([vr[i][j], vr[i][j + 1], vr[i + 1][j + 1], vr[i + 1][j]])
            zc = sum(v.co.z for v in f.verts) / 4
            (faces_low if zc < H * 0.38 else faces_up).append(f)
    deck_faces = []
    for i in range(len(vr) - 1):
        deck_faces.append(bm.faces.new([vr[i][0], vr[i + 1][0], vr[i + 1][-1], vr[i][-1]]))
    stern = bm.faces.new(vr[-1][::-1] if True else vr[-1])
    if solid_from > 0:
        bm.faces.new(vr[0])                                      # yapım hâlinde: açık kesit kapağı
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ids = {f: 0 for f in faces_low}
    ids.update({f: 1 for f in faces_up})
    ids.update({f: 2 for f in deck_faces})
    ids[stern] = 1
    A._finish(bm, [m_low, m_up, deck], lambda f, ids=ids: ids.get(f, 1), (0.2, 0.2))
    # yapım hâlindeki kısım: kaburgalar ve boyuna kirişler
    for i in range(solid_from + 1):
        r = rings[i]
        for j in range(len(r) - 1):
            beam(r[j], r[j + 1], 0.0035, "steel_panel")
    if solid_from > 0:
        for j in (0, 2, 4, 6, 8):
            beam(rings[0][j], rings[solid_from][j], 0.003, "steel_panel")


def scaffold_box(x, y, w, d, h, step=0.05):
    """Kereste iskele: dikmeler, kat kalasları, çaprazlar."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam((x + sx * w / 2, y + sy * d / 2, 0), (x + sx * w / 2, y + sy * d / 2, h), 0.004, "timber")
    nz = max(1, int(h / step))
    for k in range(1, nz + 1):
        zz = h * k / nz
        bx(x, y - d / 2, zz, w, 0.014, 0.003, "timber")
        bx(x, y + d / 2, zz, w, 0.014, 0.003, "timber")
        beam((x - w / 2, y - d / 2, zz - h / nz), (x + w / 2, y - d / 2, zz), 0.002, "timber")


# ------------------------------------------------------------------ montaj
MODELS = {}      # ad -> ana obje
PARTS = {}       # ad -> [(parça adı, obje, mod)]


def assemble(name):
    parts = list(A._parts)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    ob.data.validate(clean_customdata=False)
    ob.data.update()
    A._parts.clear()
    return ob


def part(asset, pname, build, pivot, mode, extra_pivots=()):
    """Ayrı parça: yerel orijinde kurulur, pivota taşınır. mode: osc (sallanma), spin (dönme), flicker (alev),
    level (seviyeye göre çoğalır), rail (durağan; oyunda yalnız bölgede tren istasyonu varsa gösterilir)."""
    saved = list(A._parts)
    A._parts.clear()
    build()
    ob = assemble(f"{asset}__{pname}")
    A._parts.extend(saved)
    ob.location = Vector(pivot)
    PARTS.setdefault(asset, []).append((pname, ob, mode, list(extra_pivots)))
    return ob


# ------------------------------------------------------------------ tesisler
def civilian_factory(variant):
    rng = random.Random(40 + variant)
    brick = "ind_brick" if variant == 0 else "ind_brick_yellow"
    yard(1.02, 0.84)
    # ana hal
    hw, hd, hh = 0.6, 0.42, 0.2
    bx(0.04, 0.02, 0, hw, hd, hh, brick, bevel=0.002)
    pilasters(0.04, 0.02, hw, hd, hh + 0.012, "brick_dark", 0.12)
    bx(0.04, 0.02, hh, hw + 0.016, hd + 0.016, 0.012, "concrete")        # korniş
    if variant == 0:
        sawtooth(0.04, 0.02, hh + 0.012, hw, hd, 5, 0.075)
    else:
        for k in range(3):
            monitor_roof(0.04 - hw / 2 + hw / 6 + k * hw / 3, 0.02, hh + 0.012, hw / 3, hd, 0.11, "corrugated", "skylight",
                         math.pi / 2)
    # idare binası + saat
    ox, oy = -0.3, -0.27
    bx(ox, oy, 0, 0.22, 0.14, 0.33, "office_cream", bevel=0.002)
    A.hip_roof(ox, oy, 0.33, 0.22, 0.14, 0.07, "roof_slate")
    bx(ox, oy - 0.072, 0.0, 0.05, 0.012, 0.075, "wood_red")                 # kapı
    bx(ox, oy - 0.086, 0.078, 0.08, 0.03, 0.006, "concrete")                # saçak
    pipe((ox, oy - 0.07, 0.285), (ox, oy - 0.078, 0.285), 0.022, "white", 16)       # saat kadranı
    pipe((ox, oy - 0.078, 0.285), (ox, oy - 0.08, 0.285), 0.024, "black", 16)
    beam((ox, oy - 0.081, 0.285), (ox, oy - 0.081, 0.302), 0.002, "black")          # akrep/yelkovan
    beam((ox, oy - 0.081, 0.285), (ox + 0.012, oy - 0.081, 0.285), 0.002, "black")
    # baca(lar)
    chimney(0.36, 0.3, 0.78)
    if variant == 1:
        chimney(0.2, 0.33, 0.62, 0.028, "brick_red")
    # su kulesi, kazan dairesi
    water_tower(-0.4, 0.28)
    bx(0.33, 0.12 + 0.2, 0, 0.14, 0.1, 0.12, "brick_dark", "roof_dark", bevel=0.002)
    # yükleme rampası + saçak + sandıklar
    bx(0.04, 0.26, 0, hw * 0.8, 0.06, 0.03, "concrete")
    bx(0.04, 0.27, 0.12, hw * 0.8, 0.07, 0.006, "corrugated")
    for k in range(4):
        beam((0.04 - hw * 0.38 + k * hw * 0.25, 0.3, 0.03), (0.04 - hw * 0.38 + k * hw * 0.25, 0.3, 0.12), 0.004, "steel")
    crates(-0.1, 0.25, 0.0, 5, rng)
    crates(0.18, 0.26, 0.0, 4, rng)
    barrels(0.3, -0.25, 7, rng)
    # demiryolu kolu + vagonlar: ayrı parça, oyunda yalnız bölgede tren istasyonu varsa görünür
    def rail():
        track(0.04, 0.37, math.pi / 2, 1.0)
        boxcar(-0.18, 0.37, math.pi / 2)
        boxcar(0.0, 0.37, math.pi / 2, "wood_yellow" if variant else "wood_red")
    part(f"ind_civilian_factory_{variant}", "rail", rail, (0.0, 0.0, 0.0), "rail")
    # kamyon, kapı, çit
    truck(0.12, -0.33, 0.3)
    fence([(-0.5, -0.41), (-0.14, -0.41)])
    fence([(0.04, -0.41), (0.5, -0.41), (0.5, 0.41)])
    bx(-0.12, -0.41, 0, 0.02, 0.02, 0.05, "brick_dark")
    bx(0.02, -0.41, 0, 0.02, 0.02, 0.05, "brick_dark")


def military_factory():
    rng = random.Random(51)
    yard(1.12, 0.92, "yard_asphalt")
    # büyük montaj hali (kamuflaj boyalı sac, fener çatı)
    bx(-0.08, 0.1, 0, 0.72, 0.36, 0.25, "camo", bevel=0.002)
    monitor_roof(-0.08, 0.1, 0.25, 0.72, 0.36, 0.13, "camo", "skylight", 0.0)
    for sx in (-1, 1):
        bx(-0.08 + sx * 0.362, 0.1, 0.0, 0.008, 0.2, 0.2, "black")          # büyük sürgülü kapılar
    # dövme atölyesi (tuğla, iki baca)
    bx(0.4, 0.2, 0, 0.18, 0.3, 0.17, "ind_brick", bevel=0.002)
    A.gable_roof(0.4, 0.2, 0.17, 0.18, 0.3, 0.07, "corrugated_dark", math.pi / 2, 0.01)
    chimney(0.44, 0.38, 0.55, 0.026)
    chimney(0.36, 0.38, 0.5, 0.024)
    # açık avlu: portal vinç rayları + test sahası tankları
    track(-0.08, -0.24, math.pi / 2, 0.8)
    for gx in (-0.3, 0.06):
        for gy in (-0.36, -0.12):
            lattice_mast(gx, gy, 0, 0.02, 0.2, "crane_paint", 0.05, 0.004)
        lattice_boom((gx, -0.37, 0.2), (gx, -0.11, 0.2), 0.03, "crane_paint", 0.04, 0.004)
    for k in range(6):
        tx = -0.4 + (k % 3) * 0.12
        ty = -0.3 + (k // 3) * 0.11
        bx(tx, ty, 0.006, 0.05, 0.085, 0.024, "olive", rot=math.pi / 2)
        A.cylinder(tx, ty, 0.03, 0.018, 0.016, "olive", 12)
        beam((tx, ty, 0.04), (tx + 0.05, ty, 0.04), 0.004, "olive")
        for lx in (-0.03, 0.03):
            bx(tx, ty + lx, 0.0, 0.086, 0.012, 0.012, "black", rot=0.0)
    # nöbetçi kuleleri + dikenli tel
    for (px, py) in [(-0.54, -0.44), (0.54, -0.44), (0.54, 0.44), (-0.54, 0.44)]:
        for lx, ly in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
            beam((px + lx * 0.012, py + ly * 0.012, 0), (px + lx * 0.009, py + ly * 0.009, 0.13), 0.004, "timber")
        bx(px, py, 0.13, 0.036, 0.036, 0.025, "timber")
        A.hip_roof(px, py, 0.155, 0.04, 0.04, 0.02, "roof_dark")
    fence([(-0.54, -0.44), (0.54, -0.44), (0.54, 0.44), (-0.54, 0.44), (-0.54, -0.44)], 0.04)
    truck(0.35, -0.3, math.pi / 2)
    truck(0.35, -0.2, math.pi / 2, "olive", "olive")
    crates(0.2, -0.36, 0.0, 6, rng, "olive")


def dockyard():
    rng = random.Random(62)
    # kara tarafı avlu (+y), rıhtım kenarı -y'de; kızak suya uzanır
    yard(1.0, 0.56, "yard_concrete", 0.0, 0.2)
    bx(0.0, -0.08, -0.14, 1.0, 0.02, 0.15, "stone_light")                          # rıhtım duvarı
    for k in range(6):
        A.cylinder(-0.45 + k * 0.18, -0.075, 0.01, 0.006, 0.012, "black", 8)       # babalar
    # kızak: suya doğru eğimli beton rampa
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [(-0.13, 0.36, 0.005), (0.13, 0.36, 0.005), (0.13, -0.52, -0.06), (-0.13, -0.52, -0.06),
                                   (-0.13, 0.36, -0.14), (0.13, 0.36, -0.14), (0.13, -0.52, -0.14), (-0.13, -0.52, -0.14)]]
    for f in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 3, 7, 4), (1, 5, 6, 2), (0, 4, 5, 1), (3, 2, 6, 7)]:
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    A._finish(bm, ["concrete"], None, uv("concrete"))
    # yapım halindeki gemi (pruva suya bakar) + iskele
    hull(0.0, -0.06, 0.74, 0.17, 0.12, done=0.62)
    for side in (-1, 1):
        for k in range(6):
            yy = -0.36 + k * 0.12
            beam((side * 0.11, yy, 0.0), (side * 0.11, yy, 0.16), 0.003, "timber")
        for zz in (0.05, 0.1, 0.15):
            bx(side * 0.11, -0.06, zz, 0.012, 0.72, 0.003, "timber")
    # atölyeler, levha stokları
    bx(-0.34, 0.3, 0, 0.26, 0.2, 0.17, "corrugated", bevel=0.002)
    A.gable_roof(-0.34, 0.3, 0.17, 0.26, 0.2, 0.07, "corrugated_dark", 0.0, 0.01)
    bx(0.36, 0.28, 0, 0.22, 0.24, 0.14, "ind_brick", bevel=0.002)
    sawtooth(0.36, 0.28, 0.14, 0.22, 0.24, 3, 0.05)
    for k in range(5):
        bx(-0.3 + k * 0.03, 0.08, 0.0 + k * 0.004, 0.08, 0.05, 0.004, "steel_panel")
    part("ind_dockyard", "rail", lambda: track(0.22, 0.12, 0.0, 0.5), (0.0, 0.0, 0.0), "rail")
    crates(0.3, 0.02, 0.0, 5, rng, "wood_yellow")
    # çekiç başlı vinç kulesi (kol ayrı parça)
    lattice_mast(0.2, -0.02, 0, 0.06, 0.52, "crane_paint", 0.05, 0.006)
    bx(0.2, -0.02, 0.52, 0.08, 0.08, 0.02, "crane_paint")

    def jib():
        lattice_boom((-0.14, 0, 0.02), (0.4, 0, 0.02), 0.05, "crane_paint", 0.045, 0.005)
        bx(-0.18, 0, 0.0, 0.08, 0.06, 0.05, "concrete")                           # karşı ağırlık
        bx(0.0, 0, 0.0, 0.06, 0.06, 0.04, "crane_paint", "corrugated_dark")         # makine dairesi
        bx(0.32, 0, -0.01, 0.03, 0.03, 0.012, "black")                              # araba
        beam((0.32, 0, -0.01), (0.32, 0, -0.3), 0.0015, "black")                    # halat
        bx(0.32, 0, -0.32, 0.012, 0.012, 0.014, "hull_red")                          # kanca
    part("ind_dockyard", "jib", jib, (0.2, -0.02, 0.54), "osc")


def refinery():
    rng = random.Random(73)
    yard(1.02, 0.9, "gravel")
    # depolama tankları (etrafında toprak set)
    for (tx, ty, r) in [(-0.34, 0.24, 0.1), (-0.12, 0.26, 0.085), (-0.34, 0.02, 0.085)]:
        bx(tx, ty, 0, r * 2.6, r * 2.6, 0.012, "ground_dirt")
        storage_tank(tx, ty, r, 0.12)
    # damıtma kolonları ve reaktörler
    for (cx, cy, r, h) in [(0.12, 0.2, 0.028, 0.5), (0.2, 0.2, 0.022, 0.4), (0.28, 0.22, 0.03, 0.56)]:
        column(cx, cy, r, h)
    for k in range(3):
        yy = -0.12 + k * 0.08
        pipe((0.05, yy, 0.05), (0.26, yy, 0.05), 0.028, "tank_grey", 14)
        for sx in (0.08, 0.22):
            bx(sx, yy, 0, 0.02, 0.05, 0.03, "concrete")
    # boru rafı (kafes) ve üzerinden geçen borular
    for k in range(6):
        px = -0.2 + k * 0.09
        beam((px, -0.3, 0), (px, -0.3, 0.12), 0.006, "steel")
        beam((px, -0.36, 0), (px, -0.36, 0.12), 0.006, "steel")
        beam((px, -0.36, 0.12), (px, -0.3, 0.12), 0.005, "steel")
    for k, (m, r) in enumerate([("black", 0.008), ("tank_grey", 0.006), ("hull_red", 0.005), ("steel", 0.007)]):
        pipe((-0.24, -0.35 + k * 0.016, 0.13 + r), (0.3, -0.35 + k * 0.016, 0.13 + r), r, m, 8)
    for k, (cx, cy) in enumerate([(0.12, 0.2), (0.2, 0.2), (0.28, 0.22)]):
        zz = 0.2 + k * 0.04
        pipe((cx, -0.33, 0.13), (cx, -0.33, zz), 0.005, "steel", 6)            # raftan yukarı
        pipe((cx, -0.33, zz), (cx, cy - 0.03, zz), 0.005, "steel", 6)           # kolona yatay
    # soğutma kulesi (hiperboloit) + kumanda binası
    A.lathe(0.36, -0.2, 0, [(0.1, 0), (0.075, 0.12), (0.068, 0.2), (0.075, 0.26), (0.074, 0.261)], "concrete", 24)
    bx(-0.1, -0.2, 0, 0.14, 0.1, 0.1, "ind_brick", "roof_dark", bevel=0.002)
    # meşale bacası (alev ayrı parça)
    beam((0.42, 0.34, 0), (0.42, 0.34, 0.62), 0.012, "steel_panel")
    for zz in (0.2, 0.42):
        for (dx, dy) in [(0.06, 0), (-0.06, 0), (0, 0.06)]:
            beam((0.42 + dx, 0.34 + dy, 0), (0.42, 0.34, zz), 0.003, "steel")
    fl = emissive("flame", (1.0, 0.55, 0.15), 6.0)

    def flame():
        A.lathe(0, 0, 0, [(0.012, 0), (0.02, 0.02), (0.014, 0.05), (0.0, 0.08)], fl, 10)
    part("ind_refinery", "flame", flame, (0.42, 0.34, 0.62), "flicker")
    fence([(-0.5, -0.44), (0.5, -0.44), (0.5, 0.44), (-0.5, 0.44), (-0.5, -0.44)], 0.03)
    barrels(0.0, -0.4, 9, rng, "black")


def rail_depot():
    rng = random.Random(84)
    yard(1.0, 0.7, "gravel")
    # istasyon binası + peron + saçak
    bx(-0.2, -0.24, 0, 0.36, 0.12, 0.2, "office_cream", bevel=0.002)
    A.hip_roof(-0.2, -0.24, 0.2, 0.36, 0.12, 0.06, "roof_slate")
    bx(-0.2, -0.24, 0.2, 0.08, 0.13, 0.1, "office_cream")                      # saat kulesi
    A.hip_roof(-0.2, -0.24, 0.3, 0.08, 0.13, 0.05, "roof_copper")
    bx(0.0, -0.13, 0, 0.9, 0.06, 0.02, "concrete")                             # peron
    for k in range(7):
        beam((-0.36 + k * 0.12, -0.13, 0.02), (-0.36 + k * 0.12, -0.13, 0.1), 0.004, "steel")
    bx(0.0, -0.13, 0.1, 0.9, 0.08, 0.005, "corrugated")
    # hatlar (vagonlar oyunda seviyeye göre eklenir: @ pivotları)
    for k in range(4):
        track(0.0, -0.06 + k * 0.08, math.pi / 2, 1.0)
    locomotive(-0.2, -0.06, math.pi / 2)
    # makas kulübesi, su deposu, kömür yığını, lokomotif hangarı
    bx(0.4, -0.24, 0, 0.06, 0.06, 0.08, "brick_red", "roof_dark")
    water_tower(0.28, -0.26, 0.16, 0.035)
    bx(-0.42, 0.28, 0, 0.1, 0.08, 0.02, "coal")
    bx(0.3, 0.3, 0, 0.3, 0.12, 0.13, "ind_brick", bevel=0.002)
    A.gable_roof(0.3, 0.3, 0.13, 0.3, 0.12, 0.05, "corrugated_dark", 0.0, 0.01)
    crates(-0.05, 0.3, 0.0, 5, rng)

    def wagons():
        boxcar(0.0, 0.0, math.pi / 2)
        boxcar(0.13, 0.0, math.pi / 2, "wood_yellow")
    extra = [(0.25, 0.1, 0.0), (0.0, 0.18, 0.0), (-0.1, 0.02, 0.0), (0.3, 0.02, 0.0)]
    part("ind_rail", "wagons", wagons, (0.05, 0.02, 0.0), "level", extra)


def naval_base():
    rng = random.Random(95)
    yard(1.0, 0.44, "yard_concrete", 0.0, 0.26)
    bx(0.0, 0.04, -0.14, 1.0, 0.02, 0.15, "stone_light")
    # iskeleler suya (-y) uzanır
    for px in (-0.3, 0.05, 0.38):
        bx(px, -0.22, -0.14, 0.07, 0.5, 0.15, "concrete", "yard_concrete")
        for k in range(5):
            A.cylinder(px + 0.03, -0.42 + k * 0.1, 0.01, 0.005, 0.01, "black", 8)
    # demirli muhrip
    hull(-0.13, -0.22, 0.4, 0.06, 0.035, 1.0, "hull", "hull")
    bx(-0.13, -0.2, 0.05, 0.035, 0.12, 0.03, "hull")
    A.cylinder(-0.13, -0.16, 0.08, 0.008, 0.03, "hull", 8)
    for yy in (-0.33, -0.1):
        A.cylinder(-0.13, yy, 0.05, 0.012, 0.01, "hull", 10)
        beam((-0.13, yy, 0.058), (-0.13, yy - 0.03, 0.058), 0.003, "hull")
    # ambarlar, yakıt tankları, liman vinci
    for k, px in enumerate((-0.32, 0.0, 0.32)):
        bx(px, 0.3, 0, 0.24, 0.16, 0.12, "corrugated" if k != 1 else "ind_brick", bevel=0.002)
        A.gable_roof(px, 0.3, 0.12, 0.24, 0.16, 0.05, "corrugated_dark", 0.0, 0.01)
    for (tx, ty) in [(0.44, 0.12), (0.44, 0.24)]:
        storage_tank(tx, ty, 0.04, 0.07, "tank_grey")
    lattice_mast(0.2, 0.1, 0, 0.04, 0.2, "crane_paint", 0.05, 0.005)
    lattice_boom((0.2, 0.1, 0.2), (0.2, -0.12, 0.28), 0.03, "crane_paint", 0.04, 0.004)
    part("ind_naval_base", "rail", lambda: track(0.0, 0.14, math.pi / 2, 1.0), (0.0, 0.0, 0.0), "rail")
    crates(-0.15, 0.12, 0.0, 6, rng, "olive")
    barrels(0.12, 0.2, 6, rng, "black")


def anti_air():
    rng = random.Random(106)
    yard(0.8, 0.8, "gravel")
    # dört top çukuru (kum torbası halka) + merkezde komuta sığınağı
    pits = [(-0.22, -0.22), (0.22, -0.22), (0.22, 0.22), (-0.22, 0.22)]
    for (px, py) in pits:
        for k in range(12):
            a = k * math.pi / 6
            bx(px + math.cos(a) * 0.1, py + math.sin(a) * 0.1, 0, 0.055, 0.028, 0.04, "sandbag", rot=a + math.pi / 2)
        bx(px, py, 0.0, 0.16, 0.16, 0.004, "concrete")
        crates(px + 0.06, py + 0.06, 0.4, 3, rng, "olive")
    bx(0, 0, 0, 0.16, 0.12, 0.05, "concrete", bevel=0.004)
    bx(0, 0, 0.05, 0.18, 0.14, 0.012, "sandbag")
    # uzaklık ölçer ve ışıldak
    A.cylinder(0.0, 0.09, 0, 0.01, 0.06, "dark_green", 8)
    beam((-0.04, 0.09, 0.07), (0.04, 0.09, 0.07), 0.01, "dark_green")
    A.cylinder(0.33, 0.0, 0, 0.012, 0.03, "dark_green", 10)
    A.lathe(0.33, 0.0, 0.03, [(0.022, 0), (0.024, 0.02), (0.0, 0.022)], "dark_green", 12)
    truck(-0.33, 0.02, 0.0, "olive", "tarp")
    fence([(-0.38, -0.38), (0.38, -0.38), (0.38, 0.38), (-0.38, 0.38), (-0.38, -0.38)], 0.03)

    def gun():
        # döner kaide, kalkan, iki yanlı namlu yükselişte
        A.cylinder(0, 0, 0, 0.034, 0.012, "dark_green", 16)
        bx(0, 0, 0.012, 0.05, 0.04, 0.03, "dark_green")
        bx(0, -0.024, 0.012, 0.06, 0.004, 0.045, "dark_green")
        for lx in (-0.009, 0.009):
            pipe((lx, -0.01, 0.032), (lx, -0.11, 0.11), 0.0042, "black", 8)
        for lx in (-0.03, 0.03):
            beam((lx, 0.0, 0.0), (lx * 2.2, 0.03, -0.002), 0.004, "dark_green")
    part("ind_anti_air", "gun", gun, (pits[0][0], pits[0][1], 0.004), "osc", [(p[0], p[1], 0.004) for p in pits[1:]])


def site():
    """İnşaat şantiyesi: temel, yarım duvarlar, kereste iskele, malzeme yığınları, kule vinç (kol ayrı)."""
    rng = random.Random(117)
    yard(0.9, 0.72, "ground_dirt")
    bx(0.04, 0.02, 0.0, 0.56, 0.4, 0.02, "concrete")
    for (x, y, w, d, h) in [(0.04, -0.18, 0.56, 0.02, 0.12), (-0.24, 0.02, 0.02, 0.4, 0.08), (0.32, 0.02, 0.02, 0.4, 0.16),
                            (0.1, 0.22, 0.4, 0.02, 0.05)]:
        bx(x, y, 0.02, w, d, h, "ind_brick")
    scaffold_box(0.04, 0.02, 0.62, 0.46, 0.22)
    for k in range(4):
        beam((-0.22 + k * 0.17, 0.02, 0.02), (-0.22 + k * 0.17, 0.02, 0.16), 0.008, "steel")
    # malzeme: tuğla paletleri, kereste yığını, kum, betoniyer
    for k in range(3):
        bx(-0.36, -0.2 + k * 0.06, 0, 0.04, 0.04, 0.03, "brick_red")
    for k in range(4):
        bx(0.38, -0.28, k * 0.008, 0.16, 0.05, 0.008, "timber", rot=0.08 * k)
    A.lathe(-0.33, 0.25, 0, [(0.06, 0), (0.035, 0.03), (0.0, 0.04)], "sand", 12)
    A.cylinder(0.3, 0.26, 0.02, 0.02, 0.03, "hull_red", 10)
    bx(-0.15, 0.3, 0, 0.12, 0.07, 0.07, "wood_yellow", "corrugated")              # şantiye kulübesi
    truck(-0.2, -0.3, 0.0, "hull_red", "sand")
    fence([(-0.44, -0.35), (0.44, -0.35), (0.44, 0.35), (-0.44, 0.35), (-0.44, -0.35)], 0.03, 0.05, "timber")
    # kule vinç direği
    lattice_mast(-0.3, -0.05, 0, 0.04, 0.5, "crane_paint", 0.05, 0.005)

    def jib():
        lattice_boom((-0.1, 0, 0.0), (0.36, 0, 0.0), 0.035, "crane_paint", 0.04, 0.004)
        bx(-0.12, 0, -0.02, 0.05, 0.04, 0.04, "concrete")
        bx(0.0, 0, -0.03, 0.04, 0.04, 0.04, "crane_paint", "white")
        beam((0.24, 0, 0.0), (0.24, 0, -0.26), 0.0015, "black")
        bx(0.24, 0, -0.29, 0.04, 0.02, 0.02, "brick_red")
    part("ind_site", "jib", jib, (-0.3, -0.05, 0.52), "spin")


ASSETS = {
    "ind_civilian_factory_0": lambda: civilian_factory(0),
    "ind_civilian_factory_1": lambda: civilian_factory(1),
    "ind_military_factory": military_factory,
    "ind_dockyard": dockyard,
    "ind_refinery": refinery,
    "ind_rail": rail_depot,
    "ind_naval_base": naval_base,
    "ind_anti_air": anti_air,
    "ind_site": site,
}


# ------------------------------------------------------------------ rig: kemik + döngülü animasyon
FRAMES = 240


def rig(asset, pname, ob, mode, pivots):
    """Hareketli parçayı bir armatür kemiğine bağla, döngülü eylem kaydet (rig'li GLB ve .blend için)."""
    arm_data = bpy.data.armatures.new(f"{asset}__{pname}_rig")
    arm = bpy.data.objects.new(f"{asset}__{pname}_rig", arm_data)
    bpy.context.collection.objects.link(arm)
    arm.location = ob.location
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    b = arm_data.edit_bones.new("pivot")
    b.head = (0, 0, 0)
    b.tail = (0, 0, 0.08)
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = "pivot"
    ob.location = (0, -0.08, 0)          # kemik ucuna göre: pivota geri al
    pb = arm.pose.bones["pivot"]
    pb.rotation_mode = "XYZ"
    arm.animation_data_create()
    act = bpy.data.actions.new(f"{asset}__{pname}_loop")
    arm.animation_data.action = act
    steps = 8
    for k in range(steps + 1):
        f = 1 + k * FRAMES / steps
        t = k / steps
        if mode == "spin":
            pb.rotation_euler = (0, math.tau * t, 0)
        elif mode == "osc":
            pb.rotation_euler = (0, math.sin(math.tau * t) * 0.9, 0)
        elif mode == "flicker":
            s = 1.0 + 0.2 * math.sin(math.tau * t * 3)
            pb.scale = (s, s, s)
            pb.keyframe_insert("scale", frame=f)
            continue
        else:
            continue
        pb.keyframe_insert("rotation_euler", frame=f)
    return arm


# ------------------------------------------------------------------ çıkış
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    x = 0.0
    for name, fn in ASSETS.items():
        if ONLY and name != ONLY:
            continue
        A._parts.clear()
        fn()
        ob = assemble(name)
        ob.location = (x, 0, 0)
        MODELS[name] = ob
        for (pname, pob, mode, extra) in PARTS.get(name, []):
            pob.location = Vector(pob.location) + Vector((x, 0, 0))
            pob["mode"] = mode
            for k, pv in enumerate(extra):
                e = bpy.data.objects.new(f"{name}__{pname}__p{k + 1}", None)
                bpy.context.collection.objects.link(e)
                e.location = Vector(pv) + Vector((x, 0, 0))
        x += 1.6
        print(f"[tesis] {name}: {len(ob.data.polygons)} yüz, {ob.dimensions.x:.2f}x{ob.dimensions.y:.2f}x{ob.dimensions.z:.2f}")
        for (pname, pob, mode, extra) in PARTS.get(name, []):
            print(f"        parça {pname}: {len(pob.data.polygons)} yüz, mod {mode}, pivot {len(extra) + 1}")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / "industry.gltf"), use_selection=True, export_format="GLTF_SEPARATE",
                              export_texture_dir="textures", export_yup=True, export_apply=True, export_animations=False)
    if RENDER_DIR:
        render()
    # rig'li sürüm: parçalar kemiklere bağlanır, döngülü eylemler kaydedilir
    for name, lst in PARTS.items():
        for (pname, pob, mode, extra) in lst:
            rig(name, pname, pob, mode, extra)
    bpy.ops.object.select_all(action="SELECT")
    SCENES.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(SCENES / "industry_rigged.glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_apply=False, export_animations=True)
    if SAVE_BLEND and not ONLY:
        SAVE_BLEND.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(SAVE_BLEND), relative_remap=True)


def render():
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1100, 800
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.64, 0.74, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.angle = math.radians(2)
    sun.rotation_euler = (math.radians(52), 0, math.radians(-38))
    scene.collection.objects.link(sun)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
    g = bpy.data.objects.new("ground", bpy.data.meshes.new("g"))
    bm.to_mesh(g.data)
    g.location.z = -0.002
    g.data.materials.append(A.mat("grass"))
    scene.collection.objects.link(g)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, ob in MODELS.items():
        parts = [p for (_, p, _, _) in PARTS.get(name, [])]
        for other in list(MODELS.values()) + [p for lst in PARTS.values() for (_, p, _, _) in lst]:
            other.hide_render = other is not ob and other not in parts
        c = Vector(ob.location)
        size = max(ob.dimensions.x, ob.dimensions.y)
        cam.location = c + Vector((size * 0.55, -size * 1.15, size * 0.95))
        cam.rotation_euler = (c + Vector((0, 0, 0.08)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(RENDER_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
