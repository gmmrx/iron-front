"""
Harita askeri (tümen başına tek figür): gerçek iskelet, deri ağırlıkları, modüler dönem üniforması, tüfek ve hareketler.
    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_soldier.py -- [--render DIR] [--pose]

Kaynaklar (CC0, Quaternius; tools/blender/sources/quaternius/):
  - Universal Base Characters: erkek taban gövde (deri, yüz, göz dokuları), kısa saç
  - Universal Animation Library: iskelet (DEF-* kemikleri) ve hareketler (yürüyüş, koşu, çömelme, ölüm...)
Hareket kütüphanesinin iskeleti gövdenin eklem noktalarına taşınır (kemik yönleri korunur, hareketler aynen uyar);
gövdenin ağırlık grupları iskelet adlarına çevrilir.

Üniforma gövdeden türetilir: bölge yüzeyi kopyalanır, dışa şişirilir, düzleştirilir ve gövdenin dışında tutulur
(kıvrımlar, bol kesim); aynı ağırlıkları taşıdığı için hareket ederken gövde kumaştan taşmaz. Kumaşın altında kalan
gövde silinir. Parça kimlikleri (UV2.x) oyunda ülkeye göre kask, bacak, pantolon ve teçhizat seçer; renk yuvaları
(UV2.y) ülke renklerini alır (assets/shaders/soldier.gdshader, data/common/uniforms.json).

Çıktı: tools/blender/scenes/soldier.glb (+ .blend) -> tools/godot/bake_soldier.gd -> assets/models/soldier_*.res
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "blender" / "sources" / "quaternius"
TEX = ROOT / "assets" / "models" / "textures"
SCENES = ROOT / "tools" / "blender" / "scenes"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None

## Gövde (UE adları) -> hareket iskeleti (DEF-* adları)
BONE_MAP = {
    "root": "root", "pelvis": "DEF-hips", "spine_01": "DEF-spine.001", "spine_02": "DEF-spine.002",
    "spine_03": "DEF-spine.003", "neck_01": "DEF-neck", "Head": "DEF-head",
}
for s, S in (("l", "L"), ("r", "R")):
    BONE_MAP.update({
        f"clavicle_{s}": f"DEF-shoulder.{S}", f"upperarm_{s}": f"DEF-upper_arm.{S}",
        f"lowerarm_{s}": f"DEF-forearm.{S}", f"hand_{s}": f"DEF-hand.{S}",
        f"thigh_{s}": f"DEF-thigh.{S}", f"calf_{s}": f"DEF-shin.{S}", f"foot_{s}": f"DEF-foot.{S}",
        f"ball_{s}": f"DEF-toe.{S}",
    })
    for f in ("index", "middle", "ring", "pinky"):
        for k in (1, 2, 3):
            BONE_MAP[f"{f}_0{k}_{s}"] = f"DEF-f_{f}.0{k}.{S}"
    for k in (1, 2, 3):
        BONE_MAP[f"thumb_0{k}_{s}"] = f"DEF-thumb.0{k}.{S}"


def log(*a):
    print("[soldier]", *a, flush=True)


# ------------------------------------------------------------------ A. taban: iskelet + gövde
def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path), merge_vertices=True)
    return [o for o in bpy.data.objects if o not in before]


def load_base():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ual = import_gltf(SRC / "AnimationLibrary_Godot_Standard.glb")
    ubc = import_gltf(SRC / "Superhero_Male_FullBody.gltf")
    hair = import_gltf(SRC / "Hair_Buzzed.gltf")
    rig = next(o for o in ual if o.type == "ARMATURE")
    src = next(o for o in ubc if o.type == "ARMATURE")
    # hareket iskeletini gövdenin eklemlerine taşı (yön ve dönüş açısı korunur)
    heads = {BONE_MAP[b.name]: src.matrix_world @ b.head_local for b in src.data.bones if b.name in BONE_MAP}
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    for b in eb:
        b.use_connect = False
    inv = rig.matrix_world.inverted()
    for name, h in heads.items():
        b = eb.get(name)
        if b is None:
            continue
        d = b.tail - b.head
        b.head = inv @ h
        b.tail = b.head + d
    bpy.ops.object.mode_set(mode="OBJECT")
    # gövde, göz, kaş, saç: ağırlık grupları iskelet adlarına; uç kemikleri bir üstüne katılır
    meshes = [o for o in ubc + hair if o.type == "MESH" and o.data.materials]
    for o in meshes:
        remap_groups(o)
        mw = o.matrix_world.copy()
        o.parent = rig
        o.matrix_world = mw
        for m in o.modifiers:
            if m.type == "ARMATURE":
                m.object = rig
        if not any(m.type == "ARMATURE" for m in o.modifiers):
            m = o.modifiers.new("Armature", "ARMATURE")
            m.object = rig
    for o in ual + ubc + hair:
        if o not in meshes and o is not rig:
            bpy.data.objects.remove(o, do_unlink=True)
    rig.name = "Soldier"
    body = next(o for o in meshes if o.name.startswith("SuperHero"))
    body.name = "body"
    log("taban hazır:", [o.name for o in rig.children], len(bpy.data.actions), "hareket")
    return rig, body


def remap_groups(o):
    names = {vg.index: vg.name for vg in o.vertex_groups}
    leaf = {}
    for vg in list(o.vertex_groups):
        n = vg.name
        if n in BONE_MAP:
            vg.name = BONE_MAP[n]
        elif n.endswith("_leaf_l") or n.endswith("_leaf_r"):
            leaf[vg.index] = n
    # uç kemik ağırlığı -> 03 kemiği
    for idx, n in leaf.items():
        side = n[-1]
        parent = n.replace("_04_leaf_", "_03_") if "_04_leaf_" in n else n.replace("_leaf_", "_")
        tgt = o.vertex_groups.get(BONE_MAP.get(parent, ""))
        if tgt is None:
            continue
        for v in o.data.vertices:
            for g in v.groups:
                if g.group == idx and g.weight > 0:
                    tgt.add([v.index], g.weight, "ADD")
    for idx in sorted(leaf, reverse=True):
        o.vertex_groups.remove(o.vertex_groups[idx])
    bad = [vg.name for vg in o.vertex_groups if not vg.name.startswith("DEF-") and vg.name != "root"]
    if bad:
        log("eşlenmeyen gruplar", o.name, bad)


def set_action(rig, name, frame):
    act = bpy.data.actions[name]
    rig.animation_data_create()
    rig.animation_data.action = act
    if hasattr(rig.animation_data, "action_slot") and act.slots:
        rig.animation_data.action_slot = act.slots[0]
    bpy.context.scene.frame_set(int(frame))


# ------------------------------------------------------------------ B. kumaş: gövdeden türetilen üniforma
## Parça kimlikleri (UV2.x): 0 her zaman; oyun ülkenin üniforma tanımına göre gerisini açar/kapatır
HELMETS = ["m35", "brodie", "m1", "adrian", "ssh", "m33", "type90", "sidecap"]      # 1..8
LEGS = ["boots", "puttees", "anklets", "leggings"]                                  # 10..13
P_BREECHES, P_STRAIGHT, P_SKIRT, P_BLOUSE = 14, 15, 16, 17
KIT = ["ystraps", "pouch_triple", "pouch_box", "chest_pouches", "breadbag", "gasmask", "pack", "roll"]  # 20..27
## Renk yuvaları (UV2.y): ülke renkleri
S_WOOL, S_HELMET, S_LEATHER, S_BOOTS, S_WEB, S_COLLAR, S_SKIN, S_FIXED = range(8)
PREVIEW = {S_WOOL: (0.36, 0.33, 0.2), S_HELMET: (0.25, 0.28, 0.2), S_LEATHER: (0.28, 0.16, 0.08),
           S_BOOTS: (0.05, 0.045, 0.04), S_WEB: (0.5, 0.45, 0.3), S_COLLAR: (0.45, 0.05, 0.05),
           S_SKIN: (0.8, 0.6, 0.48), S_FIXED: (0.4, 0.4, 0.4)}
HAND = [f"DEF-hand.{S}" for S in "LR"] + [f"DEF-f_{f}.0{k}.{S}" for f in ("index", "middle", "ring", "pinky")
                                          for k in (1, 2, 3) for S in "LR"] + [f"DEF-thumb.0{k}.{S}" for k in (1, 2, 3) for S in "LR"]
HEAD = ["DEF-head", "DEF-neck"]
LEG = [f"DEF-{b}.{S}" for b in ("thigh", "shin", "foot", "toe") for S in "LR"]
FOOT = [f"DEF-{b}.{S}" for b in ("foot", "toe") for S in "LR"]


class Body:
    """Taban gövdenin dinlenme pozu verisi: konum, normal, ağırlık; yakın nokta ve ağırlık sorguları."""

    def __init__(self, obj, rig):
        me = obj.data
        mw = obj.matrix_world
        r3 = mw.to_3x3()
        self.P = np.array([(mw @ v.co)[:] for v in me.vertices])
        me.calc_loop_triangles()
        self.tris = [t.vertices[:] for t in me.loop_triangles]
        self.polys = [p.vertices[:] for p in me.polygons]
        names = {vg.index: vg.name for vg in obj.vertex_groups}
        self.W = [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in me.vertices]
        self.slim(rig)
        self.N = normals_of(self.P, [t for t in self.tris])
        self.bvh = BVHTree.FromPolygons([Vector(p) for p in self.P], self.tris)

    def slim(self, rig):
        """Kalıp gövdesi: süper kahraman kas kütlesini gerçek bir asker bedenine indirir (kol, omuz, göğüs, sırt)."""
        bones = rig.data.bones
        for S in "LR":
            sh = rig.matrix_world @ bones[f"DEF-upper_arm.{S}"].head_local
            wr = rig.matrix_world @ bones[f"DEF-hand.{S}"].head_local
            axis = (wr - sh).normalized()
            names = [f"DEF-upper_arm.{S}", f"DEF-forearm.{S}", f"DEF-shoulder.{S}"]
            for i in range(len(self.P)):
                w = self.ws(i, names)
                if w < 0.05:
                    continue
                p = Vector(self.P[i])
                t = (p - sh).dot(axis)
                if t < -0.06:
                    continue
                c = sh + axis * max(t, 0.0)
                k = 1.0 - 0.2 * min(w, 1.0) * min(1.0, (t + 0.06) / 0.1)
                self.P[i] = np.array(c + (p - c) * k)
        # göğüs ve kanat kasları: gövde eksenine doğru hafif
        for i in range(len(self.P)):
            x, y, z = self.P[i]
            if 1.18 < z < 1.5 and abs(x) < 0.26:
                k = math.sin(math.pi * (z - 1.18) / 0.32)
                if y < -0.02:
                    self.P[i][1] = y * (1.0 - 0.12 * k)
                elif y > 0.08:
                    self.P[i][1] = 0.08 + (y - 0.08) * (1.0 - 0.3 * k)
                if abs(x) > 0.12:
                    self.P[i][0] = x * (1.0 - 0.06 * k)

    def ws(self, i, names):
        w = self.W[i]
        return sum(w.get(n, 0.0) for n in names)

    def nearest(self, p):
        loc, n, ti, d = self.bvh.find_nearest(Vector(p))
        return loc, n, ti

    def weights_at(self, p):
        loc, n, ti = self.nearest(p)
        a, b, c = (Vector(self.P[i]) for i in self.tris[ti])
        bw = barycentric(loc, a, b, c)
        out = {}
        for k, i in enumerate(self.tris[ti]):
            for g, w in self.W[i].items():
                out[g] = out.get(g, 0.0) + w * bw[k]
        return out


def barycentric(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
    d20, d21 = v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-12:
        return (1.0, 0.0, 0.0)
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    return (1.0 - v - w, v, w)


def mix_weights(a, b, t):
    out = {}
    for g, w in a.items():
        out[g] = out.get(g, 0.0) + w * (1.0 - t)
    for g, w in b.items():
        out[g] = out.get(g, 0.0) + w * t
    return out


class Piece:
    """Tek malzemeli, tek parça kimlikli ağ: köşe, yüz, ağırlık; build() ile iskelete bağlı obje olur."""

    def __init__(self, name, material, pid=0, slot=S_FIXED):
        self.name, self.material, self.pid, self.slot = name, material, pid, slot
        self.V, self.F, self.Wt = [], [], []

    def add(self, verts, faces, weights):
        o = len(self.V)
        self.V += [tuple(v) for v in verts]
        self.F += [tuple(i + o for i in f) for f in faces]
        self.Wt += weights
        return o


PIECES = []


def build(piece, rig, uv_scale=4.0):
    me = bpy.data.meshes.new(piece.name)
    me.from_pydata(piece.V, [], piece.F)
    me.validate()
    ob = bpy.data.objects.new(piece.name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = rig
    ob.modifiers.new("Armature", "ARMATURE").object = rig
    groups = {}
    for i, w in enumerate(piece.Wt):
        items = sorted(((g, x) for g, x in w.items() if x > 1e-3), key=lambda t: -t[1])[:4]
        tot = sum(x for _, x in items) or 1.0
        for g, x in items:
            if g not in groups:
                groups[g] = ob.vertex_groups.new(name=g)
            groups[g].add([i], x / tot, "REPLACE")
    # UV: kutu izdüşümü (metre * uv_scale); UV2: parça kimliği ve renk yuvası
    uv = me.uv_layers.new(name="UVMap")
    pu = me.uv_layers.new(name="pieces")
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u, v = [(co.y, co.z), (co.x, co.z), (co.x, co.y)][ax]
            uv.data[li].uv = (u * uv_scale, v * uv_scale)
            pu.data[li].uv = (piece.pid + 0.5, piece.slot + 0.5)
    for poly in me.polygons:
        poly.use_smooth = True
    ob.data.materials.append(material(piece.material, piece.slot))
    PIECES.append((piece, ob))
    return ob


_mats = {}


def material(name, slot):
    key = f"{name}"
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    attr = m.node_tree.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "preview"
    attr.attribute_type = "OBJECT"
    m.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = {"steel": 0.55, "metal": 0.4, "wood": 0.6, "leather": 0.55}.get(name, 0.85)
    _mats[key] = m
    return m


def preview_color(ob, slot):
    ob["preview"] = (*PREVIEW[slot], 1.0)


def mesh_adjacency(nv, faces):
    nb = [set() for _ in range(nv)]
    ecount = {}
    for f in faces:
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            nb[a].add(b)
            nb[b].add(a)
            e = (min(a, b), max(a, b))
            ecount[e] = ecount.get(e, 0) + 1
    bnd = set()
    for (a, b), c in ecount.items():
        if c == 1:
            bnd.add(a)
            bnd.add(b)
    return nb, bnd, [e for e, c in ecount.items() if c == 1]


def fit(body, P, thick, nb, bnd, iters=14, lam=0.55, extra=None):
    """Laplace düzleştirme + gövdenin dışında en az 'thick' kalma: kas hatları kaybolur, bol kumaş kalır."""
    P = P.copy()
    for _ in range(iters):
        Q = P.copy()
        for i in range(len(P)):
            ns = nb[i]
            if i in bnd:
                ns = [j for j in ns if j in bnd] or ns
            if ns:
                Q[i] = P[i] + lam * (np.mean([P[j] for j in ns], axis=0) - P[i])
        P = Q
        for i in range(len(P)):
            loc, n, ti = body.nearest(P[i])
            s = (Vector(P[i]) - loc).dot(n)
            if s < thick[i]:
                P[i] = np.array(loc + n * thick[i])
        if extra:
            extra(P)
    return P


def normals_of(P, faces):
    N = np.zeros_like(P)
    for f in faces:
        for k in range(1, len(f) - 1):
            a, b, c = P[f[0]], P[f[k]], P[f[k + 1]]
            n = np.cross(b - a, c - a)
            for i in f:
                N[i] += n
    ln = np.linalg.norm(N, axis=1)
    ln[ln == 0] = 1
    return N / ln[:, None]


def cloth(body, name, mat, pid, slot, select, thick_fn, iters=14, hem=0.8, extra=None):
    R = [i for i in range(len(body.P)) if select(i)]
    Rs = set(R)
    faces0 = [f for f in body.polys if all(v in Rs for v in f)]
    used = sorted({v for f in faces0 for v in f})
    idx = {v: k for k, v in enumerate(used)}
    faces = [tuple(idx[v] for v in f) for f in faces0]
    P0 = body.P[used]
    thick = np.array([thick_fn(i, body.P[i], body.N[i]) for i in used])
    nb, bnd, bedges = mesh_adjacency(len(used), faces)
    P = fit(body, P0 + body.N[used] * thick[:, None], thick, nb, bnd, iters=iters, extra=extra)
    W = [dict(body.W[i]) for i in used]
    # açık kenarlara iç kıvrım (kol ağzı, yaka, paça içi görünmesin)
    if hem > 0 and bedges:
        N = normals_of(P, faces)
        ring = {}
        newP = []
        for (a, b) in bedges:
            for v in (a, b):
                if v not in ring:
                    ring[v] = len(P) + len(newP)
                    newP.append(P[v] - N[v] * thick[v] * hem)
                    W.append(dict(W[v]))
        P = np.vstack([P, np.array(newP)])
        for (a, b) in bedges:
            # yön: kenarın ait olduğu yüzün tersine
            f = next(ff for ff in faces if a in ff and b in ff)
            k = f.index(a)
            if f[(k + 1) % len(f)] == b:
                faces.append((b, a, ring[a], ring[b]))
            else:
                faces.append((a, b, ring[b], ring[a]))
    pc = Piece(name, mat, pid, slot)
    pc.add(P, faces, W)
    return pc, used


def loft(rings, closed=True, cap_top=False, cap_bottom=False):
    """rings: [N x M x 3]; ardışık halkaları dörtgenlerle bağlar."""
    n, m = len(rings), len(rings[0])
    V = [tuple(p) for r in rings for p in r]
    F = []
    for i in range(n - 1):
        for j in range(m if closed else m - 1):
            a = i * m + j
            b = i * m + (j + 1) % m
            F.append((a, b, b + m, a + m))
    if cap_bottom:
        F.append(tuple(range(m - 1, -1, -1)))
    if cap_top:
        F.append(tuple((n - 1) * m + j for j in range(m)))
    return V, F


def outer_radius(body, z, center, angles, sel=None, band=0.035):
    """Yatay kesitte merkeze göre her açıdaki en dış gövde yarıçapı (kalça+iki bacak zarfı)."""
    m = np.abs(body.P[:, 2] - z) < band
    if sel is not None:
        m &= sel
    Q = body.P[m][:, :2] - np.array(center)
    ang = np.arctan2(Q[:, 1], Q[:, 0])
    rad = np.linalg.norm(Q, axis=1)
    out = []
    for a in angles:
        d = np.abs((ang - a + np.pi) % (2 * np.pi) - np.pi)
        k = d < 0.35
        out.append(rad[k].max() if k.any() else 0.0)
    out = np.array(out)
    for _ in range(3):
        out = np.maximum(out, (np.roll(out, 1) + np.roll(out, -1)) * 0.5)
    return out


def ray_outer(bvh, origin, direction, far=0.6):
    """Dışarıdan içeri ışın: en dış yüzeye çarpma noktası."""
    o = Vector(origin) + Vector(direction) * far
    hit, n, i, d = bvh.ray_cast(o, -Vector(direction), far)
    return hit, n


def make_uniform(rig, body):
    B = Body(body, rig)
    P = B.P
    is_hand = np.array([B.ws(i, HAND) for i in range(len(P))])
    is_head = np.array([B.ws(i, HEAD) for i in range(len(P))])
    is_leg = np.array([B.ws(i, LEG) for i in range(len(P))])
    is_foot = np.array([B.ws(i, FOOT) for i in range(len(P))])
    Z = P[:, 2]
    WAIST = 0.985
    # --- tunik gövde + kollar
    def tunic_sel(i):
        return is_hand[i] < 0.3 and is_head[i] < 0.5 and is_leg[i] < 0.3 and Z[i] > WAIST - 0.02

    def tunic_t(i, p, n):
        ax = abs(p[0])
        if ax > 0.22:
            return 0.024 if ax < 0.6 else 0.024 - (ax - 0.6) * 0.05
        return 0.026

    tunic, t_used = cloth(B, "tunic", "wool", 0, S_WOOL, tunic_sel, tunic_t, iters=60)
    PIECES_OUT = [tunic]
    # --- pantolon: galife (dizaltına kadar, uyluk yanları şişkin) ve düz (bileğe kadar)
    def trouser_sel(lo):
        return lambda i: is_hand[i] < 0.3 and (is_leg[i] >= 0.3 or Z[i] < WAIST + 0.08) and Z[i] > lo and is_foot[i] < 0.5

    def breeches_t(i, p, n):
        t = 0.016
        if 0.45 < p[2] < 0.93:
            k = math.sin(math.pi * (p[2] - 0.45) / 0.48)
            side = max(0.0, n[0] * (1 if p[0] > 0 else -1)) * 0.8 + max(0.0, -n[1]) * 0.35
            t += 0.055 * k * k * side
        return t

    def straight_t(i, p, n):
        z = p[2]
        return 0.018 + max(0.0, 0.54 - max(z, 0.2)) * 0.05 - max(0.0, 0.2 - z) * 0.05

    breeches, _ = cloth(B, "breeches", "wool", P_BREECHES, S_WOOL, trouser_sel(0.27), breeches_t, iters=40)
    straight, _ = cloth(B, "straight", "wool", P_STRAIGHT, S_WOOL, trouser_sel(0.085), straight_t, iters=40)
    PIECES_OUT += [breeches, straight]
    # --- etek (uzun tunik): belden üst uyluğa, kalça + iki bacak zarfı
    M = 40
    ang = [2 * math.pi * j / M for j in range(M)]
    center = (0.0, 0.02)
    zs = [WAIST + 0.035, WAIST - 0.015, 0.94, 0.895, 0.85, 0.805, 0.765]
    notarm = is_hand < 0.3
    rings, prev = [], None
    for k, z in enumerate(zs):
        r = outer_radius(B, z, center, ang, sel=notarm, band=0.03)
        r = r + 0.022 + 0.003 * k
        # kumaş aşağı doğru daralmaz; açılar arasında güçlü düzleştirme (düz dökülen)
        if prev is not None:
            r = np.maximum(r, prev + 0.002)
        for _ in range(6):
            r = 0.5 * r + 0.25 * (np.roll(r, 1) + np.roll(r, -1))
        prev = r
        rings.append([(center[0] + math.cos(a) * r[j], center[1] + math.sin(a) * r[j], z) for j, a in enumerate(ang)])
    # etek ucu: içe kıvrım
    last = rings[-1]
    rings.append([(center[0] + (x - center[0]) * 0.93, center[1] + (y - center[1]) * 0.93, z + 0.012) for x, y, z in last])
    V, F = loft(rings)
    W = []
    for idx_v, v in enumerate(V):
        k = idx_v // M
        near = B.weights_at(v)
        W.append(mix_weights({"DEF-hips": 1.0}, near, min(0.5, k * 0.09)))
    skirt = Piece("skirt", "wool", P_SKIRT, S_WOOL)
    skirt.add(V, F, W)
    # iç kıvrım: etek ucu
    PIECES_OUT.append(skirt)
    # --- yaka: tuniğin boyun ağzından dik yaka + dışa kıvrık kenar
    PIECES_OUT.append(collar(tunic))
    # --- ayakkabı (her zaman), uzun çizme konçu, dolak, kısa tozluk, uzun tozluk
    foot_sel = lambda i: (is_foot[i] >= 0.3 or (is_leg[i] >= 0.5 and Z[i] < 0.17))
    shoe, _ = cloth(B, "shoe", "leather", 0, S_BOOTS, foot_sel, lambda i, p, n: 0.011 + max(0.0, p[2] - 0.1) * 0.05,
                    iters=30, hem=0.6)
    flat = [k for k, v in enumerate(shoe.V) if v[2] < 0.035]
    for k in flat:
        x, y, z = shoe.V[k]
        shoe.V[k] = (x, y, max(0.004, z * 0.35))
    PIECES_OUT += [shoe, sole(shoe)]

    def leg_sel(lo, hi):
        return lambda i: is_leg[i] >= 0.5 and lo < Z[i] < hi and is_foot[i] < 0.6

    boots, _ = cloth(B, "boots", "leather", 10, S_BOOTS, leg_sel(0.09, 0.47),
                     lambda i, p, n: 0.014 + max(0.0, p[2] - 0.12) * 0.045, iters=40, hem=0.7)
    puttees, _ = cloth(B, "puttees", "wool", 11, S_WOOL, leg_sel(0.1, 0.4),
                       lambda i, p, n: 0.021 + max(0.0, p[2] - 0.15) * 0.012, iters=40, hem=0.6)
    spiral(puttees)
    anklets, _ = cloth(B, "anklets", "canvas", 12, S_WEB, leg_sel(0.075, 0.2),
                       lambda i, p, n: 0.04, iters=30, hem=0.5)
    leggings, _ = cloth(B, "leggings", "canvas", 13, S_WEB, leg_sel(0.075, 0.34),
                        lambda i, p, n: 0.036 + max(0.0, 0.2 - p[2]) * 0.03, iters=30, hem=0.5)
    PIECES_OUT += [boots, puttees, anklets, leggings]
    # --- gövdeden kumaş altında kalanları sil (baş, boyun, eller kalır)
    keep = [i for i in range(len(P)) if is_hand[i] >= 0.3 or is_head[i] >= 0.5]
    return B, PIECES_OUT, set(keep)


def collar(tunic):
    """Tuniğin boyun ağzı halkasından yaka: dik bant + dışa kıvrılan kenar."""
    V = np.array(tunic.V)
    nb, bnd, bedges = mesh_adjacency(len(V), tunic.F)
    neck = [v for v in bnd if V[v][2] > 1.38 and abs(V[v][0]) < 0.16]
    c = V[neck].mean(axis=0)
    neck.sort(key=lambda v: math.atan2(V[v][1] - c[1], V[v][0] - c[0]))
    rings = [[], [], [], []]
    W = []
    for v in neck:
        p = V[v]
        rad = np.array([p[0] - c[0], p[1] - c[1], 0.0])
        rad /= max(np.linalg.norm(rad), 1e-6)
        front = max(0.0, -rad[1])
        h = 0.03 - 0.01 * front
        b = p + rad * 0.002 - np.array([0, 0, 0.01])
        t = p + rad * 0.006 + np.array([0, 0, h])
        o = t + rad * 0.012 - np.array([0, 0, h * 0.6])
        i = b + rad * 0.014 + np.array([0, 0, 0.004])
        for k, q in enumerate((b, t, o, i)):
            rings[k].append(tuple(q))
    Vc, Fc = loft(rings)
    for k in range(4):
        W += [dict(tunic.Wt[v]) for v in neck]
    pc = Piece("collar", "wool", 0, S_WOOL)
    pc.add(Vc, Fc, W)
    return pc


def sole(shoe):
    """Kalın deri taban + topuk: ayakkabı alt izinin dışa taşan ofseti."""
    V = np.array(shoe.V)
    out = []
    for S in (1, -1):
        m = (V[:, 2] < 0.03) & (V[:, 0] * S > 0)
        Q = V[m]
        if not len(Q):
            continue
        c = Q[:, :2].mean(axis=0)
        M = 24
        ang = [2 * math.pi * j / M for j in range(M)]
        d = Q[:, :2] - c
        a = np.arctan2(d[:, 1], d[:, 0])
        r = np.linalg.norm(d, axis=1)
        rr = []
        for x in ang:
            k = np.abs((a - x + np.pi) % (2 * np.pi) - np.pi) < 0.3
            rr.append(r[k].max() + 0.006 if k.any() else 0.05)
        rings = []
        for z in (-0.008, 0.012):
            ring = []
            for j, x in enumerate(ang):
                px, py = c[0] + math.cos(x) * rr[j], c[1] + math.sin(x) * rr[j]
                zz = z + (0.014 if z > 0 and py > c[1] + 0.03 else 0.0)   # topuk
                zz = z if z < 0 else zz
                ring.append((px, py, zz))
            rings.append(ring)
        Vs, Fs = loft(rings, cap_top=True, cap_bottom=True)
        out.append((Vs, Fs, [dict(shoe.Wt[int(np.argmin(np.linalg.norm(V - np.array(v), axis=1)))]) for v in Vs]))
    pc = Piece("sole", "leather", 0, S_FIXED)
    for Vs, Fs, Ws in out:
        pc.add(Vs, Fs, Ws)
    return pc


def spiral(pc):
    """Dolak sargısı: bacak ekseni etrafında eğik sarım sırtları."""
    V = np.array(pc.V)
    for S in (1, -1):
        m = V[:, 0] * S > 0
        c = V[m][:, :2].mean(axis=0)
        for k in np.where(m)[0]:
            x, y, z = V[k]
            a = math.atan2(y - c[1], x - c[0])
            ph = (z / 0.042 + a / (2 * math.pi)) % 1.0
            bump = 0.004 * (1.0 - abs(ph - 0.5) * 2.0) ** 0.5
            d = np.array([x - c[0], y - c[1]])
            d /= max(np.linalg.norm(d), 1e-6)
            V[k][0] += d[0] * bump
            V[k][1] += d[1] * bump
    pc.V = [tuple(v) for v in V]


# ------------------------------------------------------------------ C. teçhizat, başlıklar, tüfek
def fwd_dir(theta):
    """Belden açı: 0 ön (-Y), + sağ (-X), ±pi arka."""
    return Vector((-math.sin(theta), -math.cos(theta), 0.0))


class Surface:
    """Üniforma dış yüzeyi (tunik + etek + pantolon): ışınla yüzeye oturtma ve en yakın nokta."""

    def __init__(self, pieces):
        V, F = [], []
        for pc in pieces:
            o = len(V)
            V += [Vector(v) for v in pc.V]
            F += [tuple(i + o for i in f) for f in pc.F]
        self.bvh = BVHTree.FromPolygons(V, F)

    def ray(self, origin, direction, far=0.7):
        d = Vector(direction).normalized()
        hit, n, i, dist = self.bvh.ray_cast(Vector(origin) - d * far, d, far * 2)
        return hit, n

    def around(self, theta, z, cx=0.0, cy=0.02):
        d = fwd_dir(theta)
        c = Vector((cx, cy, z))
        hit, n = self.ray(c + d * 0.6, -d, 0.6)
        if hit is None:
            return c + d * 0.15, d
        return hit, d

    def nearest(self, p):
        loc, n, i, d = self.bvh.find_nearest(Vector(p))
        return loc, n


def rbox(center, side, out, up, w, d, h, round_=0.35, seg=4, taper=0.0):
    """Yuvarlatılmış kutu (süperelips kesit, yükseklik boyunca): çanta, fişeklik, matara."""
    side, out, up = side.normalized(), out.normalized(), up.normalized()
    M = seg * 4
    rings = []
    zs = [-h / 2, -h / 2 + h * 0.08, 0.0, h / 2 - h * 0.08, h / 2]
    shr = [0.86, 1.0, 1.0, 1.0, 0.9]
    for k, z in enumerate(zs):
        ring = []
        tz = 1.0 - taper * (z / h + 0.5)
        for j in range(M):
            a = 2 * math.pi * (j + 0.5) / M
            ca, sa = math.cos(a), math.sin(a)
            ex = 2.0 / (1.0 + round_ * 6)
            x = math.copysign(abs(ca) ** ex, ca) * w / 2 * shr[k] * tz
            y = math.copysign(abs(sa) ** ex, sa) * d / 2 * shr[k]
            ring.append(tuple(center + side * x + out * y + up * z))
        rings.append(ring)
    return loft(rings, cap_top=True, cap_bottom=True)


def tube(points, radius, seg=8, closed=False):
    pts = [Vector(p) for p in points]
    rings = []
    n = len(pts)
    prev_side = None
    for i, p in enumerate(pts):
        a = pts[(i - 1) % n] if (closed or i > 0) else p
        b = pts[(i + 1) % n] if (closed or i < n - 1) else p
        t = (b - a).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        side = t.cross(ref).normalized() if prev_side is None else (prev_side - t * prev_side.dot(t)).normalized()
        prev_side = side
        up = side.cross(t).normalized()
        rings.append([tuple(p + (side * math.cos(2 * math.pi * j / seg) + up * math.sin(2 * math.pi * j / seg)) * radius)
                      for j in range(seg)])
    V, F = loft(rings + ([rings[0]] if closed else []), cap_top=not closed, cap_bottom=not closed)
    return V, F


def strap(surf, path, width=0.034, thick=0.004, off=0.004, step=0.018):
    """Yüzeyi izleyen kalın kayış: yol noktaları yüzeye oturtulur, yeniden örneklenir."""
    pts = [Vector(p) for p in path]
    dense = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = max(1, int((b - a).length / step))
        for k in range(n):
            dense.append(a.lerp(b, k / n))
    dense.append(pts[-1])
    on = []
    for q in dense:
        loc, n = surf.nearest(q)
        on.append((loc, n))
    # düzleştir
    P = [loc for loc, n in on]
    for _ in range(3):
        P = [P[0]] + [(P[i - 1] + P[i] * 2 + P[i + 1]) / 4 for i in range(1, len(P) - 1)] + [P[-1]]
    rings = []
    for i, p in enumerate(P):
        loc, n = surf.nearest(p)
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        sd = n.cross(t).normalized()
        base = loc + n * off
        rings.append([tuple(base + sd * width / 2 + n * thick), tuple(base - sd * width / 2 + n * thick),
                      tuple(base - sd * width / 2), tuple(base + sd * width / 2)])
    return loft(rings, cap_top=True, cap_bottom=True)


def rigid(B, anchor, verts):
    w = B.weights_at(anchor)
    return [dict(w) for _ in verts]


def surface_weights(B, verts):
    return [B.weights_at(v) for v in verts]


def make_gear(B, cloth_pieces):
    surf = Surface([pc for pc in cloth_pieces if pc.name in ("tunic", "skirt", "breeches")])
    out = []
    WB0, WB1 = 0.99, 1.04   # kemer alt/üst
    # --- kemer (her zaman): dış yüzeye oturan bant + toka
    M = 44
    rings = [[], [], [], []]
    for j in range(M):
        th = 2 * math.pi * j / M
        lo, d = surf.around(th, WB0)
        hi, d2 = surf.around(th, WB1)
        r0 = Vector((lo.x, lo.y, WB0)) + d * 0.004
        r1 = Vector((hi.x, hi.y, WB1)) + d * 0.004
        rings[0].append(tuple(r0 - d * 0.004))
        rings[1].append(tuple(r0 + d * 0.005))
        rings[2].append(tuple(r1 + d * 0.005))
        rings[3].append(tuple(r1 - d * 0.004))
    V, F = loft(rings + [rings[0]])
    belt = Piece("belt", "leather", 0, S_LEATHER)
    belt.add(V, F, surface_weights(B, V))
    out.append(belt)
    belt_r = {}

    def on_belt(th, z=(WB0 + WB1) / 2, extra=0.0):
        p, d = surf.around(th, z)
        return p + d * (0.009 + extra), d

    c, d = on_belt(0.0, extra=0.002)
    V, F = rbox(c, Vector((1, 0, 0)), d, Vector((0, 0, 1)), 0.06, 0.012, 0.048, round_=0.2)
    buckle = Piece("buckle", "metal", 0, S_FIXED)
    buckle.add(V, F, rigid(B, c, V))
    out.append(buckle)

    def hang(name, mat, pid, slot, th, w, dep, h, top=WB1 + 0.004, extra=0.0, round_=0.35, taper=0.0, flap=True):
        c, d = on_belt(th, extra=dep / 2 + extra)
        side = Vector((0, 0, 1)).cross(d).normalized()
        cc = Vector((c.x, c.y, top - h / 2))
        V, F = rbox(cc, side, d, Vector((0, 0, 1)), w, dep, h, round_=round_, taper=taper)
        pc = Piece(name, mat, pid, slot)
        pc.add(V, F, rigid(B, cc - d * dep, V))
        if flap:
            fc = cc + d * (dep / 2 + 0.003) + Vector((0, 0, h * 0.28))
            V2, F2 = rbox(fc, side, d, Vector((0, 0, 1)), w * 1.02, 0.006, h * 0.46, round_=0.15)
            pc.add(V2, F2, rigid(B, cc - d * dep, V2))
        out.append(pc)
        return pc

    # --- matara (sağ arka) + kapak, kürek (sol yan), her zaman
    th = 2.25
    c, d = on_belt(th, extra=0.035)
    side = Vector((0, 0, 1)).cross(d).normalized()
    cc = Vector((c.x, c.y, WB0 - 0.085))
    V, F = rbox(cc, side, d, Vector((0, 0, 1)), 0.1, 0.06, 0.17, round_=0.9)
    pc = Piece("canteen", "canvas", 0, S_WEB)
    pc.add(V, F, rigid(B, cc - d * 0.05, V))
    cup = cc + Vector((0, 0, 0.09))
    V2, F2 = rbox(cup, side, d, Vector((0, 0, 1)), 0.075, 0.05, 0.04, round_=0.6)
    pc.add(V2, F2, rigid(B, cc - d * 0.05, V2))
    out.append(pc)
    c, d = on_belt(-1.75, extra=0.02)
    side = Vector((0, 0, 1)).cross(d).normalized()
    blade = Vector((c.x, c.y, WB0 - 0.1))
    V, F = rbox(blade, side, d, Vector((0, 0, 1)), 0.15, 0.025, 0.18, round_=0.5, taper=0.25)
    pc = Piece("shovel", "leather", 0, S_LEATHER)
    pc.add(V, F, rigid(B, blade - d * 0.03, V))
    out.append(pc)
    V, F = tube([blade + Vector((0, 0, 0.09)) + side * 0.01, blade + Vector((0, 0, 0.3)) - side * 0.06], 0.013, seg=8)
    pc = Piece("shovel_handle", "wood", 0, S_FIXED)
    pc.add(V, F, rigid(B, blade - d * 0.03, V))
    out.append(pc)
    # --- fişeklikler: üçlü (20+1) ve kutu (20+2)
    for S in (1, -1):
        for k, a in enumerate((0.36, 0.55, 0.74)):
            hang("pouch3", "leather", 21, S_LEATHER, S * a, 0.052, 0.036, 0.078, flap=True)
        for a in (0.42, 0.72):
            hang("pouchbox", "leather", 22, S_LEATHER, S * a, 0.078, 0.042, 0.088, flap=True)
    # --- ekmek torbası (sol arka, 24), gaz maskesi kutusu (arka, 25)
    hang("breadbag", "canvas", 24, S_WEB, -2.35, 0.2, 0.07, 0.17, top=WB0 + 0.005, round_=0.7, flap=True)
    c, d = on_belt(2.85, extra=0.06)
    base = Vector((c.x, c.y, WB0 - 0.02))
    axis_top = base + Vector((0.09, 0.02, 0.24))
    ribs = [base.lerp(axis_top, t) for t in np.linspace(0, 1, 7)]
    V, F = tube(ribs, 0.052, seg=14)
    for i in range(len(V)):
        ring = i // 14
        if 0 < ring < 6 and ring % 2 == 0:
            q = Vector(V[i])
            ax = base.lerp(axis_top, ring / 6)
            V[i] = tuple(ax + (q - ax) * 1.07)
    pc = Piece("gasmask", "steel", 25, S_HELMET)
    pc.add(V, F, rigid(B, base - d * 0.04, V))
    out.append(pc)
    # --- Y askı (20): önde fişeklik arkasından omuza, sırtta birleşip kemere
    for S in (1, -1):
        path = [(S * 0.095, -0.3, WB1), (S * 0.1, -0.3, 1.2), (S * 0.11, -0.3, 1.38), (S * 0.12, -0.12, 1.53),
                (S * 0.12, 0.02, 1.56), (S * 0.11, 0.2, 1.45), (S * 0.04, 0.25, 1.3), (0.0, 0.25, 1.26)]
        V, F = strap(surf, path)
        pc = Piece("ystrap", "leather", 20, S_LEATHER)
        pc.add(V, F, surface_weights(B, V))
        out.append(pc)
    V, F = strap(surf, [(0.0, 0.25, 1.27), (0.0, 0.25, 1.12), (0.0, 0.25, WB1)])
    pc = Piece("ystrap_back", "leather", 20, S_LEATHER)
    pc.add(V, F, surface_weights(B, V))
    out.append(pc)
    # --- İngiliz tipi göğüs çantaları + çapraz askılar (23)
    for S in (1, -1):
        hit, n = surf.ray((S * 0.1, -0.5, 1.19), (0, 1, 0))
        if hit is not None:
            cc = hit + Vector((0, -0.036, 0))
            V, F = rbox(cc, Vector((1, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.13, 0.065, 0.15, round_=0.3)
            pc = Piece("chestpouch", "canvas", 23, S_WEB)
            pc.add(V, F, rigid(B, hit, V))
            fc = cc + Vector((0, -0.036, 0.04))
            V2, F2 = rbox(fc, Vector((1, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.135, 0.006, 0.07, round_=0.15)
            pc.add(V2, F2, rigid(B, hit, V2))
            out.append(pc)
        path = [(S * 0.1, -0.3, 1.27), (S * 0.12, -0.2, 1.5), (S * 0.12, 0.02, 1.56), (S * 0.08, 0.2, 1.4),
                (-S * 0.06, 0.25, 1.2), (-S * 0.1, 0.25, WB1)]
        V, F = strap(surf, path, width=0.04)
        pc = Piece("brace", "canvas", 23, S_WEB)
        pc.add(V, F, surface_weights(B, V))
        out.append(pc)
    # --- sırt çantası (26)
    hit, n = surf.ray((0.0, 0.6, 1.3), (0, -1, 0))
    cc = hit + Vector((0, 0.06, 0.0))
    V, F = rbox(cc, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.27, 0.1, 0.25, round_=0.45)
    pc = Piece("pack", "canvas", 26, S_WEB)
    pc.add(V, F, rigid(B, hit, V))
    fc = cc + Vector((0, 0.052, 0.05))
    V2, F2 = rbox(fc, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.275, 0.008, 0.16, round_=0.2)
    pc.add(V2, F2, rigid(B, hit, V2))
    out.append(pc)
    # --- kaput rulosu (27): sol omuzdan sağ kalçaya çapraz halka
    loop_pts = []
    for k in range(28):
        a = 2 * math.pi * k / 28
        # eğik düzlem: sol omuz üstü (a=0) -> ön göğüs -> sağ kalça (a=pi) -> sırt
        top = Vector((0.15, 0.03, 1.56))
        bot = Vector((-0.2, 0.03, 1.0))
        mid = (top + bot) / 2
        ax_long = (top - bot) / 2
        q = mid + ax_long * math.cos(a) + Vector((0, -1, 0)) * math.sin(a) * 0.2
        hit, n = surf.nearest(q)
        dirn = (q - mid)
        dirn.z *= 0.3
        loop_pts.append(hit + n * 0.045)
    V, F = tube(loop_pts, 0.042, seg=10, closed=True)
    pc = Piece("roll", "wool", 27, S_HELMET)
    pc.add(V, F, surface_weights(B, V))
    out.append(pc)
    # --- tunik ayrıntıları (her zaman): düğmeler, göğüs cepleri kapakları, yaka arması
    for z in (1.43, 1.33, 1.23, 1.13, 1.05):
        hit, n = surf.ray((0.0, -0.5, z), (0, 1, 0))
        if hit is None:
            continue
        V, F = rbox(hit + n * 0.004, Vector((1, 0, 0)), n, Vector((0, 0, 1)), 0.016, 0.008, 0.016, round_=0.9, seg=2)
        pc = Piece("button", "metal", 0, S_FIXED)
        pc.add(V, F, rigid(B, hit, V))
        out.append(pc)
    for S in (1, -1):
        hit, n = surf.ray((S * 0.1, -0.5, 1.36), (0, 1, 0))
        if hit is not None:
            V, F = rbox(hit + n * 0.004, Vector((1, 0, 0)), n, Vector((0, 0, 1)), 0.11, 0.006, 0.045, round_=0.2)
            pc = Piece("pocketflap", "wool", 0, S_WOOL)
            pc.add(V, F, rigid(B, hit, V))
            out.append(pc)
    return out


def helmet_shell(Rx, Ry, Rz, zc, yc, drop, flare, M=36, crest=0.0, lip=0.004):
    """Kask kabuğu: elips kubbe + açıya göre sarkan/açılan etek; içe dönük kalın kenar."""
    rings = []
    for k in range(9):
        phi = math.radians(90 - k * 11.25)
        if k == 0:
            phi = math.radians(89.0)
        ring = []
        for j in range(M):
            th = 2 * math.pi * j / M
            d = fwd_dir(th)
            x = d.x * Rx * math.cos(phi)
            y = yc + d.y * Ry * math.cos(phi)
            z = zc + Rz * math.sin(phi)
            if crest and abs(math.sin(th)) < 0.12:
                z += crest * (1.0 - abs(math.sin(th)) / 0.12) * math.sin(phi) ** 0.5
            ring.append((x, y, z))
        rings.append(ring)
    for s in (0.35, 0.7, 1.0):
        ring = []
        for j in range(M):
            th = 2 * math.pi * j / M
            d = fwd_dir(th)
            dr, fl = drop(th), flare(th)
            x = d.x * (Rx + fl * s * s)
            y = yc + d.y * (Ry + fl * s * s)
            z = zc - dr * s
            ring.append((x, y, z))
        rings.append(ring)
    last = rings[-1]
    rings.append([(x * 0.985, yc + (y - yc) * 0.985, z + lip) for x, y, z in last])
    rings.append([(x * 0.94, yc + (y - yc) * 0.94, z + lip * 2.5) for x, y, z in last])
    V, F = loft(rings)
    # kutup: tepe noktası
    top = len(V)
    V.append((0.0, yc, zc + Rz + crest * 0.5))
    for j in range(M):
        F.append((top, (j + 1) % M, j))
    return V, F


def blend3(front, side, back):
    def f(th):
        c, s = math.cos(th), math.sin(th)
        return front * max(c, 0) ** 2 + back * max(-c, 0) ** 2 + side * s * s
    return f


def make_helmets(B):
    out = []
    specs = {
        "m35": dict(Rx=0.116, Ry=0.131, Rz=0.098, zc=1.75, yc=0.006, drop=blend3(0.012, 0.072, 0.086), flare=blend3(0.03, 0.024, 0.034)),
        "brodie": dict(Rx=0.104, Ry=0.114, Rz=0.085, zc=1.748, yc=0.004, drop=blend3(0.012, 0.012, 0.012), flare=blend3(0.075, 0.075, 0.075)),
        "m1": dict(Rx=0.12, Ry=0.134, Rz=0.1, zc=1.75, yc=0.006, drop=blend3(0.016, 0.058, 0.052), flare=blend3(0.022, 0.006, 0.016)),
        "adrian": dict(Rx=0.11, Ry=0.12, Rz=0.09, zc=1.757, yc=0.004, drop=blend3(0.026, 0.014, 0.036), flare=blend3(0.058, 0.018, 0.062), crest=0.02),
        "ssh": dict(Rx=0.116, Ry=0.127, Rz=0.106, zc=1.75, yc=0.006, drop=blend3(0.01, 0.062, 0.07), flare=blend3(0.016, 0.012, 0.017)),
        "m33": dict(Rx=0.114, Ry=0.128, Rz=0.104, zc=1.75, yc=0.006, drop=blend3(0.012, 0.064, 0.072), flare=blend3(0.022, 0.01, 0.016)),
        "type90": dict(Rx=0.114, Ry=0.126, Rz=0.102, zc=1.75, yc=0.006, drop=blend3(0.02, 0.052, 0.056), flare=blend3(0.014, 0.012, 0.013)),
    }
    for k, name in enumerate(HELMETS):
        pid = 1 + k
        if name == "sidecap":
            V, F = sidecap()
            pc = Piece("helmet_" + name, "wool", pid, S_WOOL)
        else:
            V, F = helmet_shell(**specs[name])
            pc = Piece("helmet_" + name, "steel", pid, S_HELMET)
        pc.add(V, F, [{"DEF-head": 1.0} for _ in V])
        out.append(pc)
        if name == "type90":
            c = Vector((0.0, -0.128, 1.79))
            V2, F2 = rbox(c, Vector((1, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.022, 0.006, 0.022, round_=0.3, seg=2)
            st = Piece("helmet_star", "metal", pid, S_FIXED)
            st.add(V2, F2, [{"DEF-head": 1.0} for _ in V2])
            out.append(st)
    return out


def sidecap():
    """Kayık kep: önden arkaya uzanan, üstte sırt çizgisi olan kumaş kep; sağa hafif yatık."""
    rings = []
    ys = np.linspace(-0.135, 0.14, 11)
    for y in ys:
        u = min(1.0, abs(y) / 0.142)
        w = 0.098 * math.sqrt(max(0.0, 1.0 - u ** 2.4)) + 0.004
        zb = 1.742 + 0.012 * u * u + (0.006 if y > 0 else 0.0)
        zt = zb + 0.045 + 0.03 * (1.0 - u * u)
        prof = [(-w, zb), (-w * 1.02, zb + 0.022), (-w * 0.55, zt - 0.012), (0.0, zt), (w * 0.55, zt - 0.012),
                (w * 1.02, zb + 0.022), (w, zb), (w * 0.9, zb - 0.004), (0.0, zb + 0.02), (-w * 0.9, zb - 0.004)]
        ring = []
        for x, z in prof:
            a = math.radians(-7)
            xx = x * math.cos(a) - (z - 1.74) * math.sin(a)
            zz = 1.74 + x * math.sin(a) + (z - 1.74) * math.cos(a)
            ring.append((xx, 0.004 + y, zz))
        rings.append(ring)
    return loft(rings, cap_top=True, cap_bottom=True)


def make_rifle(rig):
    """Sürgülü piyade tüfeği (tüfek uzayı: +Y namlu yönü, +Z üst, köken = sağ el kavrama noktası)."""
    sec = [(-0.33, 0.015, -0.115, 0.021), (-0.25, 0.02, -0.095, 0.021), (-0.15, 0.023, -0.065, 0.019),
           (-0.07, 0.025, -0.036, 0.016), (-0.02, 0.024, -0.022, 0.015), (0.03, 0.028, -0.02, 0.016),
           (0.12, 0.03, -0.015, 0.017), (0.25, 0.03, 0.0, 0.016), (0.4, 0.032, 0.008, 0.015), (0.6, 0.032, 0.014, 0.013)]
    rings = []
    for y, zt, zb, hw in sec:
        ring = []
        for j in range(12):
            a = 2 * math.pi * j / 12
            cx = math.cos(a)
            sz = math.sin(a)
            ex = 0.6
            x = math.copysign(abs(cx) ** ex, cx) * hw
            z = (zt + zb) / 2 + math.copysign(abs(sz) ** ex, sz) * (zt - zb) / 2
            ring.append((x, y, z))
        rings.append(ring)
    V, F = loft(rings, cap_top=True, cap_bottom=True)
    wood = [(V, F)]
    hg = [[(math.cos(2 * math.pi * j / 10) * 0.011, y, 0.036 + max(0, math.sin(2 * math.pi * j / 10)) * 0.017)
           for j in range(10)] for y in (0.27, 0.57)]
    wood.append(loft(hg, cap_top=True, cap_bottom=True))
    metal = []
    metal.append(tube([(0, 0.0, 0.037), (0, 0.24, 0.037)], 0.016, seg=12))
    metal.append(tube([(0, 0.23, 0.036), (0, 0.83, 0.036)], 0.0085, seg=10))
    metal.append(tube([(0.014, 0.07, 0.042), (0.05, 0.06, 0.025)], 0.005, seg=6))
    metal.append(rbox(Vector((0.055, 0.058, 0.022)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.02, 0.02, 0.02, round_=0.9, seg=2))
    for y in (0.42, 0.6):
        metal.append(rbox(Vector((0, y, 0.026)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)), 0.036, 0.05, 0.012, round_=0.5, seg=2))
    metal.append(rbox(Vector((0, 0.81, 0.05)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.006, 0.012, 0.018, round_=0.2, seg=2))
    metal.append(rbox(Vector((0, 0.05, -0.03)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.008, 0.07, 0.012, round_=0.3, seg=2))
    # kayış: dipçik altından ön bileziğe sarkan
    pts = []
    for k in range(13):
        t = k / 12
        y = -0.2 + t * 0.62
        z = -0.08 + t * 0.1 - math.sin(math.pi * t) * 0.07
        pts.append((0.0, y, z))
    rings = []
    for i, p in enumerate(pts):
        q = Vector(p)
        rings.append([tuple(q + Vector((0.011, 0, 0.002))), tuple(q + Vector((-0.011, 0, 0.002))),
                      tuple(q + Vector((-0.011, 0, -0.002))), tuple(q + Vector((0.011, 0, -0.002)))])
    sling = [loft(rings, cap_top=True, cap_bottom=True)]
    return {"wood": wood, "metal": metal, "leather": sling}


# ------------------------------------------------------------------ D. tüfek bağlantısı ve hareketler
## El eksenleri tüfek uzayında (+Y namlu, +Z üst, +X sağ). Y: bilek->parmak kökü, Z: serçe->işaret kökü.
## Sağ el kabzayı yandan sarar (el sırtı sağa), sol el ön kundağı avucunda taşır (avuç yukarı).
R_HAND_Y, R_HAND_Z = Vector((-0.25, 0.1, -0.96)), Vector((0.0, 0.95, 0.3))
L_HAND_Y, L_HAND_Z = Vector((0.7, 0.55, 0.1)), Vector((-0.55, 0.7, 0.2))
L_GRIP = Vector((0.0, 0.2, 0.012))       # sol el kavrama noktası (tüfek uzayı)
SHOTS = {"fire": [8, 40], "fire_kneel": [12, 47]}   # ateş kareleri (namlu alevi oyunda bu karelerde)


def frame_from(origin, x, y, z):
    m = Matrix.Identity(4)
    for r in range(3):
        m[r][0], m[r][1], m[r][2], m[r][3] = x[r], y[r], z[r], origin[r]
    return m


def axes(yv, zv):
    y = yv.normalized()
    z = (zv - y * zv.dot(y)).normalized()
    return y.cross(z), y, z


def hand_anat(rig, S, pose):
    get = (lambda n: rig.pose.bones[n].head) if pose else (lambda n: rig.data.bones[n].head_local)
    h = get(f"DEF-hand.{S}")
    m = get(f"DEF-f_middle.01.{S}")
    i, p = get(f"DEF-f_index.01.{S}"), get(f"DEF-f_pinky.01.{S}")
    x, y, z = axes(m - h, i - p)
    return frame_from(h, x, y, z), (m - h).length


def grip_offsets(rig):
    """K: el çatısının tüfek uzayındaki yeri (tüfek * K = el); O: kemik çatısından anatomik çatıya sabit fark."""
    out = {}
    for S, (yv, zv), grip, palm in (("R", (R_HAND_Y, R_HAND_Z), Vector((0, 0, 0)), -1.0),
                                    ("L", (L_HAND_Y, L_HAND_Z), L_GRIP, 1.0)):
        H, L = hand_anat(rig, S, False)
        x, y, z = axes(yv, zv)
        # yumruk merkezi = bilek + Y*0.72L + avuç yönü*0.03 (sağda avuç -X, solda +X)
        wrist = grip - y * (0.72 * L) - x * (0.03 * palm)
        K = frame_from(wrist, x, y, z)
        O = rig.data.bones[f"DEF-hand.{S}"].matrix_local.inverted() @ H
        out[S] = (K, O)
    return out


def rifle_rest(rig, grips):
    H, L = hand_anat(rig, "R", False)
    K, O = grips["R"]
    return H @ K.inverted()


def build_rifle(rig, grips):
    T = rifle_rest(rig, grips)
    parts = make_rifle(rig)
    out = []
    for mat_name, lst in parts.items():
        slot = S_LEATHER if mat_name == "leather" else S_FIXED
        pc = Piece("rifle_" + mat_name, mat_name, 30, slot)
        for V, F in lst:
            V2 = [tuple(T @ Vector(v)) for v in V]
            pc.add(V2, F, [{"DEF-hand.R": 1.0} for _ in V2])
        out.append(pc)
    return out


def rot_about(center, R3):
    return Matrix.Translation(center) @ R3.to_4x4() @ Matrix.Translation(-center)


## Yerleşimler dinlenme pozuna göre (karakter -Y'ye bakar); oyunda göğüs kemiğini izler.
def carry_frame(o, f, u):
    x, y, z = axes(Vector(f), Vector(u))
    return frame_from(Vector(o), x, y, z)


PLACE = {
    "carry": carry_frame((-0.1, -0.25, 1.05), (0.46, -0.3, 0.84), (0.0, -1.0, 0.3)),
    "carry_low": carry_frame((-0.12, -0.27, 1.0), (0.55, -0.55, 0.5), (0.0, -1.0, 0.6)),
    "aim": carry_frame((-0.1, -0.33, 1.5), (0.06, -1.0, 0.0), (0.0, 0.0, 1.0)),
}
TWIST = {"aim": -25.0}


def fingers(rig, side, curl):
    """Kavrama: parmak eklemleri kendi X ekseni etrafında büker (işaret parmağı tetikte daha açık)."""
    for f in ("index", "middle", "ring", "pinky"):
        for k, a in zip((1, 2, 3), curl):
            pb = rig.pose.bones[f"DEF-f_{f}.0{k}.{side}"]
            aa = a * (0.45 if (f == "index" and side == "R") else 1.0)
            pb.matrix_basis = pb.matrix_basis @ Matrix.Rotation(math.radians(aa), 4, "X")
    for k, a in zip((1, 2, 3), (10, 25, 20)):
        pb = rig.pose.bones[f"DEF-thumb.0{k}.{side}"]
        pb.matrix_basis = pb.matrix_basis @ Matrix.Rotation(math.radians(a), 4, "X")


def twist_spine(rig, deg):
    vl = bpy.context.view_layer
    for n, k in (("DEF-spine.001", 0.3), ("DEF-spine.002", 0.35), ("DEF-spine.003", 0.35),
                 ("DEF-neck", -0.45), ("DEF-head", -0.55)):
        pb = rig.pose.bones[n]
        R = Matrix.Rotation(math.radians(deg * k), 3, "Z")
        pb.matrix = rot_about(pb.head, R) @ pb.matrix
        vl.update()
    # yanağı dipçiğe yasla: baş öne ve sağa eğik
    pb = rig.pose.bones["DEF-head"]
    R = Matrix.Rotation(math.radians(12), 3, "X") @ Matrix.Rotation(math.radians(-8), 3, "Y")
    pb.matrix = rot_about(pb.head, R) @ pb.matrix
    vl.update()


def recoil(frame, shots):
    k = 0.0
    for s in shots:
        dt = frame - s
        if 0 <= dt < 12:
            k = max(k, math.exp(-dt / 2.2))
    return k


def setup_ik(rig):
    cons = []
    empties = {}
    for S in "LR":
        tgt = bpy.data.objects.new(f"ik_{S}", None)
        pole = bpy.data.objects.new(f"pole_{S}", None)
        for e in (tgt, pole):
            bpy.context.scene.collection.objects.link(e)
        fa = rig.pose.bones[f"DEF-forearm.{S}"]
        ik = fa.constraints.new("IK")
        ik.target, ik.pole_target, ik.chain_count = tgt, pole, 2
        ik.pole_angle = math.radians(-90)
        cr = rig.pose.bones[f"DEF-hand.{S}"].constraints.new("COPY_ROTATION")
        cr.target = tgt
        cons += [(fa, ik), (rig.pose.bones[f"DEF-hand.{S}"], cr)]
        empties[S] = (tgt, pole, ik)
    return cons, empties


POLES = {"R": Vector((-0.55, 0.35, -0.45)), "L": Vector((0.35, -0.05, -0.55))}
POLES_AIM = {"R": Vector((-0.6, 0.1, -0.1)), "L": Vector((0.25, -0.2, -0.6))}


def calibrate_poles(rig, empties, grips):
    """Kutup açısını dirseği kutup hedefine en yakın getiren değere ayarlar (kemik dönüş açısından bağımsız)."""
    vl = bpy.context.view_layer
    set_action(rig, "Idle_Loop", 0)
    vl.update()
    ref = chest_now(rig)
    place_targets(rig, empties, grips, PLACE["carry"], POLES, ref)
    for S in "LR":
        tgt, pole, ik = empties[S]
        best = None
        for a in range(-180, 180, 10):
            ik.pole_angle = math.radians(a)
            vl.update()
            e = rig.pose.bones[f"DEF-forearm.{S}"].head
            d = (e - pole.location).length
            if best is None or d < best[0]:
                best = (d, a)
        ik.pole_angle = math.radians(best[1])
        log("kutup açısı", S, best[1])


def place_targets(rig, empties, grips, T, poles, ref, rec=0.0):
    """T: tüfek çatısı (armatür uzayı); ref: kutup hedefleri için göğüs referansı (göğüs(f) @ ref^-1)."""
    chest = rig.pose.bones["DEF-spine.003"].matrix
    if rec:
        T = T @ Matrix.Translation(Vector((0, -0.035 * rec, 0.004 * rec))) @ Matrix.Rotation(math.radians(7 * rec), 4, "X")
    for S in "LR":
        K, O = grips[S]
        tgt, pole, ik = empties[S]
        tgt.matrix_world = rig.matrix_world @ (T @ K @ O.inverted())
        pole.location = rig.matrix_world @ (chest @ ref.inverted() @ (ref.translation + poles[S]))
    bpy.context.view_layer.update()
    return T


def chest_now(rig):
    return rig.pose.bones["DEF-spine.003"].matrix.copy()


CLIPS = [
    # ad, kaynak, yerleşim, döngü
    ("idle", "Idle_Loop", "carry_low", True),
    ("march", "Walk_Loop", "carry", True),
    ("advance", "Jog_Fwd_Loop", "carry", True),
    ("crouch_move", "Crouch_Fwd_Loop", "carry_low", True),
    ("fire", "Idle_Loop", "aim", True),
    ("fire_kneel", "Crouch_Idle_Loop", "aim", True),
    ("death", "Death01", None, False),
    ("hit", "Hit_Chest", None, False),
]


def bake_clips(rig, grips):
    vl = bpy.context.view_layer
    cons, empties = setup_ik(rig)
    calibrate_poles(rig, empties, grips)
    baked = {}
    # referans: ayakta bekleme (Idle_Loop kare 0) göğsü; yerleşimler bu pozda dünyaya göre verilir
    for c_owner, c in cons:
        c.mute = True
    set_action(rig, "Idle_Loop", 0)
    vl.update()
    idle_ref = chest_now(rig)
    twist_spine(rig, TWIST["aim"])
    idle_twist = chest_now(rig)
    for name, src, place, loop in CLIPS:
        act = bpy.data.actions[src]
        n = int(round(act.frame_range[1]))
        frames = list(range(0, n if loop else n + 1))
        for c_owner, c in cons:
            c.mute = True
        clip_ref, clip_place = idle_ref, PLACE.get(place)
        if place == "aim":
            # nişan: tüfek dünyaya göre ileri; göğsün kare 0'daki yerine taşınır, sonra göğsü izler
            set_action(rig, src, 0)
            twist_spine(rig, TWIST["aim"])
            clip_ref = chest_now(rig)
            clip_place = Matrix.Translation(clip_ref.translation - idle_twist.translation) @ PLACE["aim"]
        for c_owner, c in cons:
            c.mute = place is None
        data = []
        for f in frames:
            set_action(rig, src, f)
            if place and TWIST.get(place):
                twist_spine(rig, TWIST[place])
            if place:
                poles = POLES_AIM if place == "aim" else POLES
                T = chest_now(rig) @ clip_ref.inverted() @ clip_place
                place_targets(rig, empties, grips, T, poles, idle_ref, recoil(f, SHOTS.get(name, [])))
            vl.update()
            rec = {}
            for pb in rig.pose.bones:
                rec[pb.name] = rig.convert_space(pose_bone=pb, matrix=pb.matrix, from_space="POSE", to_space="LOCAL")
            data.append(rec)
        baked[name] = (frames, data, loop)
        log("hareket", name, "<-", src, len(frames), "kare")
    for c_owner, c in cons:
        c_owner.constraints.remove(c)
    for S in "LR":
        for e in empties[S][:2]:
            bpy.data.objects.remove(e, do_unlink=True)
    # yeni aksiyonlar: kayıtlı yerel matrisler + parmak kavrayışı
    new = {}
    for name, (frames, data, loop) in baked.items():
        act = bpy.data.actions.new(name)
        rig.animation_data.action = act
        for f, rec in zip(frames, data):
            for pb in rig.pose.bones:
                pb.matrix_basis = rec[pb.name]
            fingers(rig, "R", (55, 70, 45))
            if name not in ("death", "hit"):
                fingers(rig, "L", (40, 55, 35))
            for pb in rig.pose.bones:
                pb.keyframe_insert("location", frame=f, group=pb.name)
                pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
        act.use_fake_user = True
        act["loop"] = loop
        new[name] = act
    return new


def trim_body(body, keep):
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    kill = [f for f in bm.faces if not any(v.index in keep for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()


# ------------------------------------------------------------------ önizleme
def render_poses(rig, poses, tag):
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 420, 620
    scene.view_settings.view_transform = "AgX"
    if scene.world is None:
        w = bpy.data.worlds.new("w")
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.65, 0.7, 1)
        scene.world = w
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.5
        sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.lens = 60
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam = scene.camera
    out = []
    for i, pose in enumerate(poses):
        act, frame, view = pose[:3]
        tz, dist = (pose[3], pose[4]) if len(pose) > 3 else (0.92, 4.2)
        show = pose[5] if len(pose) > 5 else None
        if show is not None:
            show_config(**show)
        if act:
            set_action(rig, act, frame)
        yaw = math.radians(view)
        c = Vector((0, 0, tz))
        cam.location = c + Vector((math.sin(yaw) * -dist, -math.cos(yaw) * dist, 0.9 * dist / 4.2))
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        p = RENDER_DIR / f"{tag}_{i:02d}.png"
        scene.render.filepath = str(p)
        bpy.ops.render.render(write_still=True)
        out.append(p)
    return out


def show_config(helmet="m35", legs="puttees", tunic=0, kit=("ystraps", "pouch_triple", "breadbag", "gasmask")):
    """Önizleme: parça kimliklerine göre bir ülke üniforması seçer."""
    hid = 1 + HELMETS.index(helmet)
    lid = 10 + LEGS.index(legs)
    trouser = P_BREECHES if legs in ("boots", "puttees") else P_STRAIGHT
    bits = {20 + KIT.index(k) for k in kit}
    for pc, ob in PIECES:
        pid = pc.pid
        vis = True
        if 1 <= pid <= 8:
            vis = pid == hid
        elif 10 <= pid <= 13:
            vis = pid == lid
        elif pid in (P_BREECHES, P_STRAIGHT):
            vis = pid == trouser
        elif pid == P_SKIRT:
            vis = tunic == 0
        elif 20 <= pid <= 27:
            vis = pid in bits
        ob.hide_render = not vis


def main():
    rig, body = load_base()
    B, pieces, keep = make_uniform(rig, body)
    pieces += make_gear(B, pieces)
    pieces += make_helmets(B)
    grips = grip_offsets(rig)
    pieces += build_rifle(rig, grips)
    trim_body(body, keep)
    body["preview"] = (*PREVIEW[S_SKIN], 1.0)
    body.data.materials.clear()
    body.data.materials.append(material("skin", S_SKIN))
    for pc in pieces:
        ob = build(pc, rig)
        preview_color(ob, pc.slot)
    log("parçalar:", len(pieces), "köşe", sum(len(pc.V) for pc in pieces), "gövde", len(body.data.vertices))
    clips = bake_clips(rig, grips)
    if RENDER_DIR:
        g = dict()
        poses = [("march", 6, 45, 1.25, 2.0, g), ("march", 6, 100, 1.25, 2.0, g), ("fire", 20, 90, 1.4, 1.6, g),
                 ("fire", 20, 20, 1.4, 1.6, g), ("fire_kneel", 20, 90, 1.0, 2.0, g), ("idle", 10, 30, 1.2, 2.0, g),
                 ("advance", 5, 90, 1.1, 2.4, g)]
        render_poses(rig, poses, "base")


if __name__ == "__main__":
    main()
