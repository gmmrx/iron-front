"""
Birim modelleri (1936-45 dönemi, stilize low-poly): kara, deniz, hava.
    Blender --background --factory-startup --python tools/blender/build_units.py -- [--render DIR]
Çıktı: assets/models/units.glb (düğümler aşağıdaki MODELS adlarıyla)

Vertex rengi: RGB = taban rengi, A = ülke rengi maskesi (1 = üniforma/gövde ülke rengine boyanır).
UV.x = parça kimliği (oyundaki shader animasyonu için):
  0 gövde · 1 sol bacak · 2 sağ bacak · 3 kollar/silah · 4 pervane · 5 kule/top namlusu
Ölçek: asker boyu ~1.0; tank ~1.6 uzunluk; gemiler ~6-12; uçaklar ~2.4 kanat açıklığı.
Yön: modelin önü +Y.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None

# renkler
UNIFORM = (0.42, 0.44, 0.30)      # boyanacak bölgelerin önizleme rengi
SKIN = (0.78, 0.60, 0.46)
LEATHER = (0.25, 0.17, 0.10)
WOOD = (0.40, 0.26, 0.14)
GUNMETAL = (0.16, 0.17, 0.18)
STEEL = (0.35, 0.37, 0.38)
TRACK = (0.12, 0.12, 0.12)
RUBBER = (0.08, 0.08, 0.08)
HULL = (0.43, 0.46, 0.49)
HULL_DARK = (0.30, 0.32, 0.35)
DECK = (0.55, 0.45, 0.32)
RED_HULL = (0.45, 0.13, 0.10)
GLASS = (0.20, 0.30, 0.38)
BLACK = (0.05, 0.05, 0.05)


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _tag(self, faces, color, tint, part):
        for f in faces:
            for loop in f.loops:
                loop[self.col] = (*color, 1.0 if tint else 0.0)
                loop[self.uv].uv = (float(part) + 0.5, 0.5)

    def box(self, center, size, color, tint=False, part=0, rot=None, taper=1.0):
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        for v in verts:
            k = taper if v.co.z > 0 else 1.0
            v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2]))
        m = Matrix.Translation(center)
        if rot:
            m = m @ rot
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = list({f for v in verts for f in v.link_faces})
        self._tag(faces, color, tint, part)

    def cyl(self, center, r, depth, color, tint=False, part=0, axis="Z", seg=10, r2=None):
        geom = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
        verts = geom["verts"]
        rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(center) @ rot, verts=verts)
        self._tag(list({f for v in verts for f in v.link_faces}), color, tint, part)

    def sphere(self, center, r, color, tint=False, part=0, scale=(1, 1, 1), half=False):
        geom = bmesh.ops.create_uvsphere(self.bm, u_segments=10, v_segments=6, radius=r)
        verts = geom["verts"]
        if half:
            kill = [v for v in verts if v.co.z < -1e-4]
            bmesh.ops.delete(self.bm, geom=kill, context="VERTS")
            verts = [v for v in verts if v.is_valid]
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(center) @ Matrix.Diagonal((*scale, 1)), verts=verts)
        self._tag(list({f for v in verts for f in v.link_faces}), color, tint, part)

    def hull(self, length, beam, height, color, bow=0.28, stern=0.12, z0=0.0, taper_bottom=0.72):
        """Gemi gövdesi: sivri pruva, küt kıç; alt kısım daralır."""
        L, B = length / 2, beam / 2
        prof = [(-L, -B * 0.8), (-L + stern * length, -B), (L - bow * length, -B), (L, 0.0),
                (L - bow * length, B), (-L + stern * length, B), (-L, B * 0.8)]
        top = [self.bm.verts.new((y * 1.0, x, z0 + height)) for x, y in [(p[1], p[0]) for p in prof]]
        bot = [self.bm.verts.new((y * taper_bottom, x * 0.96, z0)) for x, y in [(p[1], p[0]) for p in prof]]
        # yukarıdaki: (x=genişlik, y=uzunluk) — önce doğru eksenleri kur
        for v, (px, py) in zip(top, prof):
            v.co = Vector((py, px, z0 + height))
        for v, (px, py) in zip(bot, prof):
            v.co = Vector((py * taper_bottom, px * 0.97, z0))
        n = len(prof)
        faces = []
        for i in range(n):
            faces.append(self.bm.faces.new([bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]]))
        faces.append(self.bm.faces.new(top))
        faces.append(self.bm.faces.new(bot[::-1]))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self._tag(faces, color, False, 0)

    def finish(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]
            me.color_attributes.render_color_index = 0
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        m = bpy.data.materials.get("unit") or _make_material()
        me.materials.append(m)
        return ob


def _make_material():
    m = bpy.data.materials.new("unit")
    m.use_nodes = True
    nodes = m.node_tree.nodes
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    m.node_tree.links.new(attr.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    return m


# ------------------------------------------------------------------ kara
def soldier_body(b, x=0.0, y=0.0, rifle=True, aiming=False, kneel=False):
    z = -0.18 if kneel else 0.0
    # bacaklar (parça 1-2), bot
    for side, part in ((-1, 1), (1, 2)):
        b.box((x + side * 0.07, y, 0.22 + z * 0.5), (0.11, 0.12, 0.42), UNIFORM, True, part)
        b.box((x + side * 0.07, y + 0.03, 0.03), (0.11, 0.18, 0.07), LEATHER, False, part)
    # gövde + kemer + sırt çantası
    b.box((x, y, 0.62 + z), (0.30, 0.18, 0.40), UNIFORM, True, 0, taper=0.92)
    b.box((x, y, 0.47 + z), (0.31, 0.19, 0.05), LEATHER)
    b.box((x, y - 0.13, 0.66 + z), (0.22, 0.09, 0.24), (0.33, 0.30, 0.20))
    # kafa + miğfer
    b.sphere((x, y + 0.01, 0.93 + z), 0.085, SKIN)
    b.sphere((x, y + 0.01, 0.955 + z), 0.12, UNIFORM, True, 0, scale=(1, 1.05, 0.62), half=True)
    b.cyl((x, y + 0.01, 0.955 + z), 0.13, 0.015, UNIFORM, True, 0, seg=12)
    # kollar + tüfek (parça 3)
    if aiming:
        b.box((x - 0.12, y + 0.14, 0.78 + z), (0.08, 0.28, 0.08), UNIFORM, True, 3)
        b.box((x + 0.12, y + 0.12, 0.76 + z), (0.08, 0.24, 0.08), UNIFORM, True, 3)
        if rifle:
            b.box((x + 0.02, y + 0.32, 0.80 + z), (0.035, 0.62, 0.05), WOOD, False, 3)
            b.box((x + 0.02, y + 0.58, 0.815 + z), (0.02, 0.22, 0.02), GUNMETAL, False, 3)
    else:
        for side in (-1, 1):
            b.box((x + side * 0.19, y + 0.02, 0.62 + z), (0.08, 0.09, 0.34), UNIFORM, True, 3)
        if rifle:
            b.box((x + 0.21, y - 0.03, 0.72 + z), (0.035, 0.05, 0.75), WOOD, False, 3, rot=Matrix.Rotation(0.25, 4, "X"))


def soldier():
    b = Builder()
    soldier_body(b)
    return b.finish("soldier")


def soldier_aim():
    b = Builder()
    soldier_body(b, aiming=True)
    return b.finish("soldier_aim")


def mg_team():
    b = Builder()
    soldier_body(b, x=-0.25, aiming=True, kneel=True, rifle=False)
    soldier_body(b, x=0.25, kneel=True)
    b.box((-0.25, 0.55, 0.55), (0.06, 0.7, 0.07), GUNMETAL, False, 3)
    b.cyl((-0.25, 0.62, 0.52), 0.05, 0.14, GUNMETAL, False, 3, axis="Y")
    for s in (-1, 1):
        b.box((-0.25 + s * 0.08, 0.8, 0.26), (0.02, 0.02, 0.5), GUNMETAL, False, 3, rot=Matrix.Rotation(s * 0.3, 4, "Y"))
    return b.finish("mg_team")


def artillery():
    b = Builder()
    # lafet, tekerler, kalkan, namlu (parça 5), mürettebat
    b.box((0, -0.35, 0.28), (0.14, 1.1, 0.12), UNIFORM, True, 0, rot=Matrix.Rotation(-0.18, 4, "X"))
    for s in (-1, 1):
        b.cyl((s * 0.36, 0.1, 0.32), 0.32, 0.08, WOOD, False, 0, axis="X", seg=14)
        b.cyl((s * 0.36, 0.1, 0.32), 0.1, 0.1, GUNMETAL, False, 0, axis="X", seg=8)
    b.box((0, 0.2, 0.62), (0.7, 0.05, 0.42), UNIFORM, True, 0)
    b.cyl((0, 0.55, 0.62), 0.07, 1.2, GUNMETAL, False, 5, axis="Y", seg=10)
    b.cyl((0, 1.14, 0.62), 0.09, 0.08, GUNMETAL, False, 5, axis="Y", seg=10)
    b.box((0, 0.15, 0.55), (0.28, 0.45, 0.22), STEEL, False, 5)
    soldier_body(b, x=-0.55, y=-0.3)
    soldier_body(b, x=0.6, y=-0.1, kneel=True, rifle=False)
    return b.finish("artillery")


def tank(name, medium=False):
    b = Builder()
    L = 1.9 if medium else 1.55
    W = 1.0 if medium else 0.82
    # paletler + tekerler
    for s in (-1, 1):
        b.box((s * W * 0.42, 0, 0.2), (W * 0.22, L, 0.36), TRACK, taper=0.96)
        for i in range(5):
            b.cyl((s * W * 0.53, -L * 0.36 + i * L * 0.18, 0.15), 0.1, 0.05, RUBBER, axis="X", seg=10)
        b.box((s * W * 0.43, 0, 0.41), (W * 0.26, L * 1.02, 0.04), UNIFORM, True)   # çamurluk
    # gövde (eğimli ön plaka)
    b.box((0, -0.05, 0.47), (W * 0.62, L * 0.92, 0.3), UNIFORM, True, taper=0.9)
    b.box((0, L * 0.43, 0.42), (W * 0.6, 0.18, 0.2), UNIFORM, True, 0, rot=Matrix.Rotation(0.6, 4, "X"))
    b.box((0, -L * 0.42, 0.5), (W * 0.5, 0.12, 0.2), GUNMETAL)                      # motor ızgarası
    # kule (parça 5): döner
    tr = 0.36 if medium else 0.28
    b.cyl((0, -0.05, 0.62), tr, 0.26 if medium else 0.22, UNIFORM, True, 5, seg=12, r2=tr * 0.85)
    b.cyl((0, -0.12, 0.78 if medium else 0.73), tr * 0.35, 0.08, UNIFORM, True, 5, seg=10)       # kapak
    b.cyl((0, 0.45 if medium else 0.35, 0.67), 0.045 if medium else 0.03, 0.95 if medium else 0.55, GUNMETAL, False, 5, axis="Y", seg=8)
    b.box((0.2, -0.3, 0.52), (0.18, 0.3, 0.08), (0.30, 0.28, 0.20))                # takım kutusu
    return b.finish(name)


def truck():
    b = Builder()
    for s in (-1, 1):
        for yy in (0.45, -0.35, -0.6):
            b.cyl((s * 0.36, yy, 0.16), 0.16, 0.12, RUBBER, axis="X", seg=10)
    b.box((0, 0, 0.3), (0.62, 1.6, 0.1), GUNMETAL)
    b.box((0, 0.5, 0.52), (0.6, 0.45, 0.4), UNIFORM, True, taper=0.92)              # kabin
    b.box((0, 0.76, 0.42), (0.5, 0.2, 0.22), UNIFORM, True)                           # motor
    b.box((0, 0.52, 0.62), (0.52, 0.02, 0.14), GLASS)
    b.box((0, -0.35, 0.55), (0.66, 0.95, 0.42), (0.36, 0.34, 0.24), False, taper=0.95)  # branda
    return b.finish("truck")


# ------------------------------------------------------------------ deniz
def turret(b, y, z, big=1.0, twin=True):
    b.cyl((0, y, z), 0.28 * big, 0.2 * big, HULL_DARK, False, 5, seg=12)
    b.box((0, y + 0.05 * big, z + 0.12 * big), (0.5 * big, 0.5 * big, 0.2 * big), HULL, False, 5, taper=0.85)
    for s in ((-1, 1) if twin else (0,)):
        b.cyl((s * 0.09 * big, y + 0.55 * big, z + 0.14 * big), 0.035 * big, 0.7 * big, GUNMETAL, False, 5, axis="Y", seg=6)


def funnel(b, y, z, h=0.7, r=0.16):
    b.cyl((0, y, z + h / 2), r, h, HULL_DARK, seg=10, r2=r * 0.92)
    b.cyl((0, y, z + h + 0.02), r * 1.05, 0.06, BLACK, seg=10)


def destroyer():
    b = Builder()
    b.hull(6.0, 0.72, 0.42, HULL)
    b.hull(6.0, 0.73, 0.12, RED_HULL, z0=-0.12)
    b.box((0, 0, 0.44), (0.62, 5.2, 0.03), DECK)
    b.box((0, -0.35, 0.44), (0.18, 5.0, 0.03), (0.6, 0.6, 0.6), True)              # ülke rengi şerit
    b.box((0, 1.1, 0.6), (0.46, 0.9, 0.32), HULL, taper=0.9)                        # köprü üstü
    b.box((0, 1.25, 0.86), (0.36, 0.4, 0.2), HULL_DARK)
    b.cyl((0, 1.0, 1.25), 0.03, 0.9, GUNMETAL, seg=6)                               # direk
    funnel(b, 0.2, 0.44, 0.55, 0.14)
    funnel(b, -0.45, 0.44, 0.5, 0.13)
    turret(b, 2.0, 0.44, 0.55, False)
    turret(b, -2.2, 0.44, 0.55, False)
    b.box((0, -1.3, 0.52), (0.3, 0.6, 0.12), GUNMETAL)                              # torpido
    b.box((0, -2.9, 0.62), (0.3, 0.02, 0.18), (0.6, 0.6, 0.6), True)                # sancak (ülke rengi)
    return b.finish("destroyer")


def cruiser():
    b = Builder()
    b.hull(8.5, 1.0, 0.6, HULL)
    b.hull(8.5, 1.01, 0.15, RED_HULL, z0=-0.15)
    b.box((0, 0, 0.62), (0.9, 7.4, 0.03), DECK)
    b.box((0, 0.6, 0.85), (0.7, 1.8, 0.45), HULL, taper=0.9)
    b.box((0, 0.9, 1.25), (0.52, 0.8, 0.35), HULL_DARK, taper=0.85)
    b.cyl((0, 0.8, 1.9), 0.04, 1.3, GUNMETAL, seg=6)
    funnel(b, -0.3, 0.62, 0.8, 0.2)
    funnel(b, -0.9, 0.62, 0.75, 0.19)
    turret(b, 2.6, 0.62, 0.8)
    turret(b, 1.8, 0.8, 0.8)
    turret(b, -2.6, 0.62, 0.8)
    b.box((0, -3.9, 0.9), (0.4, 0.02, 0.24), (0.6, 0.6, 0.6), True)
    return b.finish("cruiser")


def battleship():
    b = Builder()
    b.hull(12.0, 1.7, 0.85, HULL, bow=0.24)
    b.hull(12.0, 1.71, 0.2, RED_HULL, z0=-0.2)
    b.box((0, 0, 0.87), (1.5, 10.6, 0.04), DECK)
    b.box((0, 0.3, 1.2), (1.1, 3.2, 0.65), HULL, taper=0.88)
    b.box((0, 0.8, 1.8), (0.8, 1.3, 0.7), HULL_DARK, taper=0.8)                     # pagoda kulesi
    b.box((0, 0.9, 2.4), (0.5, 0.6, 0.4), HULL)
    b.cyl((0, 0.8, 3.1), 0.05, 1.4, GUNMETAL, seg=6)
    funnel(b, -0.6, 0.87, 1.1, 0.3)
    turret(b, 3.9, 0.87, 1.3)
    turret(b, 2.7, 1.2, 1.3)
    turret(b, -3.3, 0.87, 1.3)
    turret(b, -4.4, 0.87, 1.2)
    for s in (-1, 1):
        for yy in (-1.5, -0.8, 1.6):
            b.cyl((s * 0.62, yy, 1.02), 0.1, 0.18, HULL_DARK, seg=8)                  # ikincil toplar
    b.box((0, -5.6, 1.2), (0.5, 0.02, 0.3), (0.6, 0.6, 0.6), True)
    return b.finish("battleship")


def submarine():
    b = Builder()
    b.cyl((0, 0, 0.0), 0.32, 5.6, HULL_DARK, axis="Y", seg=12)
    b.sphere((0, 2.8, 0.0), 0.32, HULL_DARK, scale=(1, 1.6, 1))
    b.sphere((0, -2.8, 0.0), 0.32, HULL_DARK, scale=(1, 1.3, 1))
    b.box((0, 0.2, 0.36), (0.3, 5.0, 0.06), DECK)
    b.box((0, 0.5, 0.55), (0.28, 0.9, 0.5), HULL_DARK, taper=0.85)                 # kule
    b.cyl((0, 0.6, 1.0), 0.03, 0.5, GUNMETAL, seg=6)
    b.cyl((0, 1.4, 0.45), 0.06, 0.5, GUNMETAL, axis="Y", seg=6)                     # güverte topu
    b.box((0, 0.5, 0.82), (0.29, 0.3, 0.06), (0.6, 0.6, 0.6), True)
    return b.finish("submarine")


def cargo_ship():
    b = Builder()
    b.hull(7.0, 1.1, 0.7, (0.24, 0.22, 0.2), bow=0.18)
    b.hull(7.0, 1.11, 0.16, RED_HULL, z0=-0.16)
    b.box((0, 0, 0.72), (1.0, 6.2, 0.03), DECK)
    for yy in (2.0, 1.0, -1.2):
        b.box((0, yy, 0.8), (0.8, 0.7, 0.18), (0.3, 0.26, 0.2))                    # ambar kapakları
    b.box((0, -2.3, 1.1), (0.9, 1.1, 0.75), (0.85, 0.83, 0.78))                     # köprü
    funnel(b, -2.5, 1.45, 0.6, 0.18)
    b.cyl((0, 1.5, 1.4), 0.04, 1.4, WOOD, seg=6)
    b.cyl((0, -0.1, 1.4), 0.04, 1.4, WOOD, seg=6)
    b.box((0, -3.4, 1.0), (0.4, 0.02, 0.24), (0.6, 0.6, 0.6), True)
    return b.finish("cargo_ship")


# ------------------------------------------------------------------ hava
def fighter():
    b = Builder()
    b.cyl((0, 0.1, 0), 0.13, 1.7, UNIFORM, True, 0, axis="Y", seg=10, r2=0.06)
    b.cyl((0, 0.98, 0), 0.14, 0.18, GUNMETAL, axis="Y", seg=10)
    b.box((0, 0.25, -0.03), (2.3, 0.42, 0.05), UNIFORM, True, 0, taper=0.8)          # kanat
    b.box((0, -0.72, 0.02), (0.8, 0.22, 0.03), UNIFORM, True)                        # yatay kuyruk
    b.box((0, -0.74, 0.16), (0.03, 0.24, 0.28), UNIFORM, True, taper=0.6)            # dikey kuyruk
    b.sphere((0, 0.25, 0.1), 0.1, GLASS, scale=(0.8, 1.6, 0.8))                       # kokpit
    b.box((0, 1.08, 0), (0.9, 0.04, 0.08), (0.2, 0.2, 0.2), False, 4)                 # pervane (parça 4)
    b.box((0, 1.08, 0), (0.08, 0.04, 0.9), (0.2, 0.2, 0.2), False, 4)
    for s in (-1, 1):
        b.box((s * 0.95, 0.25, -0.02), (0.2, 0.3, 0.052), (0.85, 0.85, 0.82))          # kanat rozeti alanı
    return b.finish("fighter")


def bomber():
    b = Builder()
    b.cyl((0, 0, 0), 0.2, 2.6, UNIFORM, True, 0, axis="Y", seg=10, r2=0.1)
    b.sphere((0, 1.3, 0), 0.2, GLASS, scale=(1, 1.3, 1))
    b.box((0, 0.3, 0.02), (3.8, 0.55, 0.07), UNIFORM, True, 0, taper=0.85)
    b.box((0, -1.2, 0.05), (1.2, 0.3, 0.04), UNIFORM, True)
    b.box((0, -1.24, 0.26), (0.04, 0.3, 0.44), UNIFORM, True, taper=0.6)
    for s in (-1, 1):
        b.cyl((s * 0.75, 0.55, -0.03), 0.12, 0.6, UNIFORM, True, 0, axis="Y", seg=8)  # motorlar
        b.box((s * 0.75, 0.87, -0.03), (0.7, 0.03, 0.06), (0.2, 0.2, 0.2), False, 4)
        b.box((s * 0.75, 0.87, -0.03), (0.06, 0.03, 0.7), (0.2, 0.2, 0.2), False, 4)
    return b.finish("bomber")


MODELS = [soldier, soldier_aim, mg_team, artillery, lambda: tank("light_tank"), lambda: tank("medium_tank", True),
          truck, destroyer, cruiser, battleship, submarine, cargo_ship, fighter, bomber]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obs = [fn() for fn in MODELS]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "units.glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    for ob in obs:
        print(f"[birim] {ob.name}: {len(ob.data.polygons)} yüz, {ob.dimensions.x:.2f}x{ob.dimensions.y:.2f}x{ob.dimensions.z:.2f}")
    if RENDER_DIR:
        render(obs)


def render(obs):
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1500, 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.68, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    groups = [["soldier", "soldier_aim", "mg_team", "artillery", "light_tank", "medium_tank", "truck"],
              ["destroyer", "cruiser", "battleship", "submarine", "cargo_ship"], ["fighter", "bomber"]]
    for gi, names in enumerate(groups):
        row = [o for o in obs if o.name in names]
        for o in obs:
            o.hide_render = o not in row
        x = 0.0
        for o in row:
            o.location = (x + o.dimensions.x / 2, 0, 0)
            o.rotation_euler = (0, 0, math.radians(-35))
            x += max(o.dimensions.x, o.dimensions.y * 0.7) + 0.4
        cam.data.ortho_scale = x * 1.05
        cam.location = (x / 2, -x * 0.9, x * 0.55)
        cam.rotation_euler = (math.radians(60), 0, 0)
        scene.render.filepath = str(RENDER_DIR / f"units_{gi}.png")
        bpy.ops.render.render(write_still=True)


main()
