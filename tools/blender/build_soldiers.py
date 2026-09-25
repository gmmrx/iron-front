"""
Piyade figürleri (Blender, prosedürel): tek taban asker + ülkeye göre üniforma, başlık, teçhizat ve tüfek.
    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_soldiers.py -- [--render DIR] [--only turkey,...]
Çıktı: assets/models/soldiers.glb — düğümler inf_<kit>, mg_<kit>

Kaynak referanslar: art/references/ww2/NNN_*/turnaround_v01.png (+ prompt/REVIEW). Ölçü metre; boy ~1.75.
Vertex rengi RGB = gerçek malzeme rengi, A = 0 (ülke rengine boyanmaz; oyun bu modelleri "yerli" sayar).
UV.x = parça kimliği (oyun shader animasyonu): 0 gövde/baş · 1 sol bacak · 2 sağ bacak · 3 kollar + silah.
Bacaklar kalçadan (z = 0.86) salınır, kollar ateşte geri teper (assets/shaders/unit.gdshader). Önü +Y.
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
ONLY = ARGS[ARGS.index("--only") + 1].split(",") if "--only" in ARGS else None

SKIN = (0.76, 0.58, 0.44)
SKIN_DARK = (0.62, 0.45, 0.33)
HAIR = (0.16, 0.11, 0.08)
WOOD = (0.36, 0.22, 0.11)
WOOD_LIGHT = (0.46, 0.30, 0.16)
GUNMETAL = (0.13, 0.14, 0.15)
STEEL = (0.32, 0.33, 0.34)
BRASS = (0.62, 0.50, 0.24)
CANTEEN = (0.36, 0.40, 0.30)

## Ülke kitleri (renkler lineer RGB; referans paftalardan alınmış, malzeme türüne göre ayrık)
KITS = {
    # 001 Türk piyadesi 1939: haki yün, dolak, kahverengi deri, haki kep, kırmızı yaka işareti, Türk Mauseri
    "turkey": dict(tunic=(0.50, 0.44, 0.27), trousers=(0.50, 0.44, 0.27), puttee=(0.52, 0.47, 0.31), boot=(0.24, 0.14, 0.08),
                   leather=(0.34, 0.20, 0.11), head="sidecap", cap=(0.47, 0.41, 0.25), tab=(0.62, 0.10, 0.08),
                   straps="y", pouches=2, canteen=True, rifle="mauser", breeches=True, high_boot=False),
    # 002 Alman Heer 1940: feldgrau M36, koyu yeşil yaka, M35 çelik miğfer, siyah deri, uzun çizme, Kar98k
    "germany": dict(tunic=(0.35, 0.38, 0.30), trousers=(0.33, 0.35, 0.33), puttee=None, boot=(0.06, 0.06, 0.06),
                    leather=(0.08, 0.07, 0.06), head="stahlhelm", cap=(0.30, 0.33, 0.28), tab=(0.16, 0.24, 0.16),
                    straps="y", pouches=2, canteen=True, rifle="mauser", breeches=False, high_boot=True),
    # 003 Sovyet 1941: haki-kahve gimnastyorka, SSh-40, dolak, kahverengi deri, Mosin-Nagant
    "soviet": dict(tunic=(0.47, 0.42, 0.26), trousers=(0.40, 0.36, 0.24), puttee=(0.44, 0.40, 0.26), boot=(0.12, 0.09, 0.06),
                   leather=(0.32, 0.20, 0.12), head="ssh40", cap=(0.36, 0.38, 0.30), tab=None,
                   straps="none", pouches=1, canteen=True, rifle="mosin", breeches=True, high_boot=False),
    # 004 Britanya 1940: battledress haki, Brodie miğfer, haki dokuma askı, tozluk, Lee-Enfield
    "uk": dict(tunic=(0.44, 0.39, 0.25), trousers=(0.44, 0.39, 0.25), puttee=(0.46, 0.42, 0.28), boot=(0.10, 0.08, 0.06),
               leather=(0.50, 0.46, 0.32), head="brodie", cap=(0.30, 0.32, 0.24), tab=None,
               straps="web", pouches=2, canteen=True, rifle="enfield", breeches=False, high_boot=False),
    # 005 ABD 1944: zeytin yeşili, M1 miğfer, tozluk, M1 Garand
    "usa": dict(tunic=(0.40, 0.38, 0.26), trousers=(0.38, 0.36, 0.25), puttee=(0.55, 0.52, 0.38), boot=(0.30, 0.20, 0.12),
                leather=(0.46, 0.44, 0.32), head="m1", cap=(0.30, 0.33, 0.24), tab=None,
                straps="web", pouches=2, canteen=True, rifle="garand", breeches=False, high_boot=False),
    # 006 Fransız 1940: haki (1935 sonrası), Adrian miğfer, dolak, kahverengi deri, MAS-36
    "france": dict(tunic=(0.42, 0.40, 0.26), trousers=(0.40, 0.38, 0.25), puttee=(0.42, 0.40, 0.27), boot=(0.20, 0.12, 0.07),
                   leather=(0.36, 0.22, 0.12), head="adrian", cap=(0.30, 0.33, 0.24), tab=None,
                   straps="y", pouches=2, canteen=True, rifle="mas36", breeches=True, high_boot=False),
    # 007 İtalyan 1940: gri-yeşil, M33 miğfer, dolak, gri-yeşil deri, Carcano
    "italy": dict(tunic=(0.40, 0.42, 0.31), trousers=(0.40, 0.42, 0.31), puttee=(0.42, 0.44, 0.32), boot=(0.18, 0.12, 0.08),
                  leather=(0.30, 0.30, 0.22), head="m33", cap=(0.34, 0.37, 0.28), tab=None,
                  straps="none", pouches=2, canteen=True, rifle="carcano", breeches=True, high_boot=False),
    # Japon 1938: haki-sarı Tip 98, Tip 90 miğfer, dolak, Arisaka
    "japan": dict(tunic=(0.50, 0.44, 0.24), trousers=(0.48, 0.42, 0.24), puttee=(0.48, 0.43, 0.26), boot=(0.20, 0.13, 0.08),
                  leather=(0.36, 0.24, 0.13), head="type90", cap=(0.42, 0.38, 0.22), tab=(0.62, 0.10, 0.08),
                  straps="none", pouches=2, canteen=True, rifle="arisaka", breeches=True, high_boot=False),
    # Genel (kit yoksa): haki, sade kep, dolak — oyun ülke rengine göre hafif tonlar
    "generic": dict(tunic=(0.46, 0.42, 0.28), trousers=(0.44, 0.40, 0.27), puttee=(0.46, 0.42, 0.29), boot=(0.20, 0.13, 0.08),
                    leather=(0.34, 0.22, 0.12), head="sidecap", cap=(0.42, 0.38, 0.25), tab=None,
                    straps="y", pouches=2, canteen=True, rifle="mauser", breeches=True, high_boot=False),
}


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _tag(self, faces, color, part):
        for f in faces:
            for loop in f.loops:
                loop[self.col] = (*color, 0.0)
                loop[self.uv].uv = (float(part) + 0.5, 0.5)

    def _place(self, verts, center, rot=None):
        m = Matrix.Translation(center)
        if rot is not None:
            m = m @ rot
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        return list({f for v in verts for f in v.link_faces})

    def box(self, center, size, color, part=0, rot=None, taper=1.0, taper_y=None):
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        for v in verts:
            k = taper if v.co.z > 0 else 1.0
            ky = (taper_y if taper_y is not None else taper) if v.co.z > 0 else 1.0
            v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1] * ky, v.co.z * size[2]))
        self._tag(self._place(verts, center, rot), color, part)

    def cyl(self, center, r, depth, color, part=0, axis="Z", seg=10, r2=None, rot=None):
        geom = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
        verts = geom["verts"]
        ax = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        m = ax if rot is None else rot @ ax
        self._tag(self._place(verts, center, m), color, part)

    def sphere(self, center, r, color, part=0, scale=(1, 1, 1), half=False, u=12, v=8):
        geom = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=r)
        verts = geom["verts"]
        if half:
            kill = [vv for vv in verts if vv.co.z < -1e-4]
            bmesh.ops.delete(self.bm, geom=kill, context="VERTS")
            verts = [vv for vv in verts if vv.is_valid]
        bmesh.ops.transform(self.bm, matrix=Matrix.Diagonal((*scale, 1)), verts=verts)
        self._tag(self._place(verts, center), color, part)

    def finish(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        me.color_attributes.active_color = me.color_attributes[0]
        me.color_attributes.render_color_index = 0
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        mat = bpy.data.materials.get("soldier") or _make_material()
        me.materials.append(mat)
        return ob


def _make_material():
    m = bpy.data.materials.new("soldier")
    m.use_nodes = True
    nodes = m.node_tree.nodes
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    m.node_tree.links.new(attr.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
    return m


def rx(a):
    return Matrix.Rotation(a, 4, "X")


def ry(a):
    return Matrix.Rotation(a, 4, "Y")


def rz(a):
    return Matrix.Rotation(a, 4, "Z")


# ------------------------------------------------------------------ gövde (Skin modifier ile organik)
HIP = 0.86          # kalça yüksekliği (shader ile aynı)
HEAD_Z = 1.62


def limb(b, p0, p1, r0, r1, color, part, seg=9):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    if L < 1e-5:
        return
    rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    b.cyl(tuple(p0 + d * 0.5), r0, L, color, part, seg=seg, r2=r1, rot=rot)


def skeleton(k, hands):
    """Eklemler: ad -> (konum, (rx, ry)); bölge etiketi kenarlarda. hands = (sol el, sağ el) dünya konumları."""
    thigh = 0.098 if k["breeches"] else 0.086
    calf = 0.066
    hl, hr = Vector(hands[0]), Vector(hands[1])
    J = {
        "pelvis": ((0, 0.0, 0.94), (0.165, 0.115)), "spine": ((0, 0.01, 1.10), (0.175, 0.118)),
        "chest": ((0, 0.02, 1.30), (0.195, 0.125)), "neck": ((0, 0.02, 1.47), (0.058, 0.058)),
        "shl": ((-0.215, 0.0, 1.41), (0.072, 0.072)), "shr": ((0.215, 0.0, 1.41), (0.072, 0.072)),
        "elbl": ((-0.26, 0.15, 1.18), (0.052, 0.052)), "elbr": ((0.27, 0.05, 1.15), (0.052, 0.052)),
        "handl": (tuple(hl), (0.042, 0.042)), "handr": (tuple(hr), (0.042, 0.042)),
        "hipl": ((-0.095, 0.0, HIP), (thigh, thigh)), "hipr": ((0.095, 0.0, HIP), (thigh, thigh)),
        "kneel": ((-0.10, 0.01, 0.48), (0.072, 0.072)), "kneer": ((0.10, 0.01, 0.48), (0.072, 0.072)),
        "ankl": ((-0.10, 0.0, 0.10), (calf * 0.85, calf * 0.85)), "ankr": ((0.10, 0.0, 0.10), (calf * 0.85, calf * 0.85)),
    }
    # (a, b, bölge, parça)
    E = [("pelvis", "spine", "tunic", 0), ("spine", "chest", "tunic", 0), ("chest", "neck", "skin", 0),
         ("chest", "shl", "tunic", 0), ("shl", "elbl", "sleeve", 3), ("elbl", "handl", "sleeve", 3),
         ("chest", "shr", "tunic", 0), ("shr", "elbr", "sleeve", 3), ("elbr", "handr", "sleeve", 3),
         ("pelvis", "hipl", "trousers", 1), ("hipl", "kneel", "trousers", 1), ("kneel", "ankl", "puttee", 1),
         ("pelvis", "hipr", "trousers", 2), ("hipr", "kneer", "trousers", 2), ("kneer", "ankr", "puttee", 2)]
    return J, E


def skin_body(b, k, hands):
    """Skin+Subsurf ile organik gövde; yüzler en yakın kenara göre bölge rengi ve parça kimliği alır."""
    J, E = skeleton(k, hands)
    me = bpy.data.meshes.new("tmp_body")
    ob = bpy.data.objects.new("tmp_body", me)
    bpy.context.collection.objects.link(ob)
    bm = bmesh.new()
    names = list(J.keys())
    vs = {n: bm.verts.new(J[n][0]) for n in names}
    for a, bb, _r, _p in E:
        bm.edges.new((vs[a], vs[bb]))
    bm.to_mesh(me)
    bm.free()
    skin = ob.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    for i, n in enumerate(names):
        rx, ry = J[n][1]
        me.skin_vertices[0].data[i].radius = (rx, ry)
        if n == "pelvis":
            me.skin_vertices[0].data[i].use_root = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    # yüzleri Builder'a taşı ve etiketle
    colors = {"tunic": k["tunic"], "sleeve": k["tunic"], "trousers": k["trousers"], "puttee": k["puttee"] or k["trousers"], "skin": SKIN}
    segs = [(Vector(J[a][0]), Vector(J[bb][0]), r, p) for a, bb, r, p in E]
    src = bmesh.new()
    src.from_mesh(ob.data)
    for f in src.faces:
        c = f.calc_center_median()
        best = None
        for p0, p1, region, part in segs:
            d = p1 - p0
            t = max(0.0, min(1.0, (c - p0).dot(d) / max(d.length_squared, 1e-9)))
            dist = (p0 + d * t - c).length
            if best is None or dist < best[0]:
                best = (dist, region, part, t)
        _dist, region, part, t = best
        color = colors[region]
        # eller: kol kenarının uç kısmı ten rengi; manşet koyu şerit
        if region == "sleeve" and part == 3 and t > 0.86 and ("handl" in names) and (c - Vector(hands[0])).length < 0.075 or (c - Vector(hands[1])).length < 0.075:
            color = SKIN
        elif region == "sleeve" and t > 0.78:
            color = tuple(cc * 0.88 for cc in k["tunic"])
        elif region == "puttee" and k["puttee"]:
            # dolak sarımı: şeritler
            band = int((c.z - 0.10) / 0.055) % 2
            color = k["puttee"] if band == 0 else tuple(cc * 0.9 for cc in k["puttee"])
        verts = [b.bm.verts.new(v.co.copy()) for v in f.verts]
        nf = b.bm.faces.new(verts)
        b._tag([nf], color, part)
    src.free()
    bpy.data.objects.remove(ob, do_unlink=True)
    bmesh.ops.remove_doubles(b.bm, verts=b.bm.verts, dist=1e-6)


def gear(b, k):
    """Teçhizat (parça 0): kemer, toka, askılar, fişeklikler, matara, ekmek torbası, göğüs cepleri, yaka işareti, botlar."""
    tunic = k["tunic"]
    shade = tuple(c * 0.86 for c in tunic)
    for s in (-1, 1):
        b.box((s * 0.085, 0.145, 1.29), (0.10, 0.02, 0.11), shade, 0)
        b.box((s * 0.085, 0.15, 1.345), (0.105, 0.015, 0.025), tunic, 0)
    if k["tab"]:
        for s in (-1, 1):
            b.box((s * 0.045, 0.075, 1.47), (0.035, 0.012, 0.02), k["tab"], 0)
    b.cyl((0, 0.0, 1.00), 0.185, 0.05, k["leather"], 0, seg=14, r2=0.185)
    b.box((0, 0.13, 1.00), (0.05, 0.015, 0.04), BRASS, 0)
    if k["straps"] in ("y", "web"):
        col = k["leather"]
        for s in (-1, 1):
            b.box((s * 0.10, 0.135, 1.21), (0.04, 0.012, 0.36), col, 0, rot=rx(-0.08))
            b.box((s * 0.085, -0.13, 1.21), (0.04, 0.012, 0.36), col, 0, rot=rz(s * 0.25) @ rx(0.06))
        b.box((0, -0.15, 1.31), (0.04, 0.012, 0.20), col, 0)
    for s in (-1, 1):
        for i in range(k["pouches"]):
            xo = s * (0.07 + i * 0.075)
            b.box((xo, 0.135, 1.00), (0.065, 0.06, 0.075), k["leather"], 0, taper=0.9)
            b.box((xo, 0.14, 1.035), (0.07, 0.065, 0.02), tuple(c * 0.8 for c in k["leather"]), 0)
    if k["canteen"]:
        b.sphere((0.15, -0.13, 0.95), 0.06, CANTEEN, 0, scale=(1, 0.55, 1.15))
        b.cyl((0.15, -0.13, 1.02), 0.02, 0.03, GUNMETAL, 0, seg=8)
    b.box((-0.14, -0.14, 0.93), (0.13, 0.07, 0.13), tuple(c * 0.95 for c in tunic), 0, taper=0.9)
    # botlar (bacak parçalarıyla salınır)
    for side, part in ((-1, 1), (1, 2)):
        x = side * 0.10
        if k["high_boot"]:
            b.cyl((x, 0.0, 0.26), 0.07, 0.34, k["boot"], part, seg=10, r2=0.064)
        b.box((x, 0.02, 0.06), (0.105, 0.17, 0.12), k["boot"], part, taper=0.92)
        b.box((x, 0.14, 0.035), (0.10, 0.09, 0.07), k["boot"], part, taper=0.85)


def head(b, k):
    """Baş (parça 0): kafa, boyun, kulaklar; başlık türü kite göre."""
    b.sphere((0, 0.01, HEAD_Z), 0.098, SKIN, 0, scale=(0.92, 1.0, 1.1))       # kafa
    b.sphere((0, -0.02, HEAD_Z + 0.02), 0.099, HAIR, 0, scale=(0.94, 0.95, 0.85), half=True)  # saç (üst yarı)
    for s in (-1, 1):
        b.sphere((s * 0.09, 0.0, HEAD_Z - 0.01), 0.022, SKIN_DARK, 0, u=8, v=5, scale=(0.5, 1, 1))
    b.box((0, 0.095, HEAD_Z - 0.015), (0.025, 0.03, 0.04), SKIN_DARK, 0, taper=0.7)  # burun
    cap = k["cap"]
    h = k["head"]
    if h == "sidecap":
        # yumuşak haki kep (Türk saha başlığı): öne doğru alçalan kama gövde, yan kulaklık şeridi
        b.box((0, 0.0, HEAD_Z + 0.09), (0.19, 0.24, 0.07), cap, 0, taper=0.55, taper_y=0.8)
        b.box((0, 0.0, HEAD_Z + 0.055), (0.21, 0.25, 0.03), tuple(c * 0.9 for c in cap), 0)
    elif h == "stahlhelm":
        b.sphere((0, 0.0, HEAD_Z + 0.02), 0.128, cap, 0, scale=(1.0, 1.08, 0.85), half=True)
        b.cyl((0, -0.005, HEAD_Z + 0.005), 0.145, 0.03, cap, 0, seg=14, r2=0.13)     # kenar/siperlik
        b.box((0, -0.13, HEAD_Z - 0.03), (0.22, 0.05, 0.07), cap, 0, taper=0.7)       # ense koruması
    elif h == "ssh40":
        b.sphere((0, 0.0, HEAD_Z + 0.03), 0.125, cap, 0, scale=(1.0, 1.02, 0.9), half=True)
        b.cyl((0, 0.0, HEAD_Z + 0.02), 0.132, 0.02, cap, 0, seg=14)
    elif h == "brodie":
        b.sphere((0, 0.0, HEAD_Z + 0.06), 0.11, cap, 0, scale=(1.0, 1.0, 0.6), half=True)
        b.cyl((0, 0.0, HEAD_Z + 0.05), 0.175, 0.015, cap, 0, seg=16)                 # geniş kenar
    elif h == "m1":
        b.sphere((0, 0.0, HEAD_Z + 0.025), 0.122, cap, 0, scale=(1.0, 1.05, 0.9), half=True)
        b.cyl((0, 0.0, HEAD_Z + 0.015), 0.128, 0.02, cap, 0, seg=14)
    elif h == "adrian":
        b.sphere((0, 0.0, HEAD_Z + 0.03), 0.115, cap, 0, scale=(1.0, 1.05, 0.9), half=True)
        b.cyl((0, 0.0, HEAD_Z + 0.02), 0.15, 0.015, cap, 0, seg=14)
        b.box((0, 0.0, HEAD_Z + 0.135), (0.02, 0.14, 0.035), cap, 0)                  # tepe ibiği
    elif h == "m33":
        b.sphere((0, 0.0, HEAD_Z + 0.03), 0.122, cap, 0, scale=(1.0, 1.06, 0.88), half=True)
        b.cyl((0, 0.0, HEAD_Z + 0.02), 0.135, 0.02, cap, 0, seg=14)
    elif h == "type90":
        b.sphere((0, 0.0, HEAD_Z + 0.03), 0.118, cap, 0, scale=(1.0, 1.04, 0.86), half=True)
        b.cyl((0, 0.0, HEAD_Z + 0.02), 0.13, 0.02, cap, 0, seg=14)
        if k["tab"]:
            b.box((0, 0.118, HEAD_Z + 0.06), (0.03, 0.01, 0.035), k["tab"], 0)        # ön yıldız alanı


def rifle(b, kind, origin, rot):
    """Tüfek (parça 3): kundak + namlu + mekanizma; boy ~1.1 m (Mauser). Yerel eksen: +Y namlu yönü."""
    def R(v):
        return Vector(origin) + rot @ Vector(v)
    stock = WOOD if kind != "enfield" else WOOD_LIGHT
    L = {"mauser": 1.11, "mosin": 1.23, "enfield": 1.13, "garand": 1.10, "mas36": 1.02, "carcano": 1.02, "arisaka": 1.28}.get(kind, 1.1)
    # dipçik → kabza → el kundağı
    b.box(R((0, -0.30, -0.01)), (0.045, 0.30, 0.085), stock, 3, rot=rot, taper=0.75)
    b.box(R((0, -0.10, 0.0)), (0.04, 0.16, 0.055), stock, 3, rot=rot)
    b.box(R((0, 0.22, 0.0)), (0.04, 0.50, 0.045), stock, 3, rot=rot, taper=0.85)
    # namlu + gövde
    b.cyl(R((0, 0.10, 0.02)), 0.02, 0.36, GUNMETAL, 3, axis="Y", seg=8, rot=rot)
    b.cyl(R((0, L * 0.5 - 0.02, 0.025)), 0.011, L * 0.55, GUNMETAL, 3, axis="Y", seg=8, rot=rot)
    # sürgü kolu (sağ) + arpacık + kayış halkası
    b.cyl(R((0.035, -0.02, 0.035)), 0.008, 0.06, STEEL, 3, axis="X", seg=6, rot=rot)
    b.box(R((0, L * 0.5 + 0.05, 0.04)), (0.012, 0.02, 0.02), GUNMETAL, 3, rot=rot)
    if kind == "garand":
        b.box(R((0, -0.02, -0.02)), (0.045, 0.12, 0.03), GUNMETAL, 3, rot=rot)


def rifle_pose(kind):
    """Tüfek dünyaya yerleşimi ve iki elin konumu (göğüs önünde çapraz hazır ol)."""
    r_rot = rz(0.55) @ rx(-1.05)
    origin = Vector((0.0, 0.20, 1.12))
    def R(v):
        return tuple(origin + r_rot @ Vector(v))
    return origin, r_rot, R((0.0, 0.30, -0.03)), R((0.0, -0.12, -0.02))


def lmg(b, origin, rot):
    """Hafif makineli (parça 3): iki ayaklı, üstten şarjörlü; tüfek yerine aynı tutuşta."""
    def R(v):
        return Vector(origin) + rot @ Vector(v)
    b.box(R((0, -0.28, -0.01)), (0.05, 0.28, 0.09), WOOD, 3, rot=rot, taper=0.75)
    b.box(R((0, 0.05, 0.0)), (0.06, 0.40, 0.07), GUNMETAL, 3, rot=rot)
    b.cyl(R((0, 0.55, 0.02)), 0.016, 0.62, GUNMETAL, 3, axis="Y", seg=8, rot=rot)
    b.box(R((0, 0.02, 0.09)), (0.03, 0.06, 0.16), GUNMETAL, 3, rot=rot)
    for s_ in (-1, 1):
        b.cyl(R((s_ * 0.03, 0.70, -0.10)), 0.007, 0.22, STEEL, 3, axis="Z", seg=6, rot=rot @ rx(0.25 * s_))


def soldier(kit_name, role):
    k = KITS[kit_name]
    b = Builder()
    origin, rot, hand_l, hand_r = rifle_pose(k["rifle"])
    skin_body(b, k, (hand_l, hand_r))
    gear(b, k)
    head(b, k)
    if role == "mg":
        lmg(b, origin, rot)
    else:
        rifle(b, k["rifle"], origin, rot)
    return b.finish(f"{role}_{kit_name}")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    names = ONLY or list(KITS.keys())
    obs = []
    for kit in names:
        for role in ("inf", "mg"):
            obs.append(soldier(kit, role))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "soldiers.glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    for ob in obs:
        print(f"[asker] {ob.name}: {len(ob.data.polygons)} yüz, {ob.dimensions.x:.2f}x{ob.dimensions.y:.2f}x{ob.dimensions.z:.2f}")
    if RENDER_DIR:
        render(obs)


def render(obs):
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 700, 1000
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.64, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    for ob in obs:
        ob.hide_render = True
    for ob in obs:
        ob.hide_render = False
        # kameralar modele bakar (önü +Y): ön = +Y tarafından, yan = +X tarafından, üç çeyrek
        for tag, (rot, loc) in {"front": ((math.radians(90), 0, math.radians(180)), (0, 4, 0.9)),
                                "side": ((math.radians(90), 0, math.radians(90)), (4, 0, 0.9)),
                                "three": ((math.radians(80), 0, math.radians(140)), (2.6, 3.2, 1.35))}.items():
            cam.location = loc
            cam.rotation_euler = rot
            cam.data.ortho_scale = 2.0
            scene.render.filepath = str(RENDER_DIR / f"{ob.name}_{tag}.png")
            bpy.ops.render.render(write_still=True)
        ob.hide_render = True


main()
