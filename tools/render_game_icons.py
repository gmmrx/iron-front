#!/usr/bin/env python3
"""Render high-resolution, physically lit UI icons inside Blender.

Run with:
  Blender --background --python tools/render_game_icons.py

The output is deterministic and data-driven.  Content icons are rendered at
256x256 with transparent surroundings; Godot downsamples them cleanly.
"""

import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path.cwd()
OUT = ROOT / "assets" / "ui" / "icons_hd"
OUT.mkdir(parents=True, exist_ok=True)

MATS = {}


def material(name, color, metallic=0.55, roughness=0.28):
    if name in MATS:
        return MATS[name]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    MATS[name] = mat
    return mat


GUNMETAL = material("Gunmetal", (0.055, 0.075, 0.085), 0.82, 0.22)
STEEL = material("Steel", (0.42, 0.50, 0.52), 0.88, 0.18)
LIGHT_STEEL = material("Light steel", (0.72, 0.77, 0.74), 0.90, 0.16)
BRASS = material("Aged brass", (0.62, 0.38, 0.10), 0.86, 0.22)
GOLD = material("Highlight brass", (0.92, 0.66, 0.20), 0.82, 0.17)
OLIVE = material("Military olive", (0.18, 0.25, 0.14), 0.42, 0.42)
NAVY = material("Naval blue", (0.045, 0.15, 0.21), 0.60, 0.30)
RED = material("State red", (0.48, 0.045, 0.035), 0.52, 0.30)
BLUE = material("Treaty blue", (0.06, 0.25, 0.38), 0.58, 0.27)
IVORY = material("Ivory enamel", (0.88, 0.82, 0.62), 0.30, 0.25)
BLACK = material("Oil black", (0.012, 0.016, 0.017), 0.35, 0.19)
RUBBER = material("Rubber", (0.018, 0.022, 0.022), 0.05, 0.52)
COPPER = material("Copper", (0.50, 0.16, 0.055), 0.83, 0.22)
CONCRETE = material("Concrete", (0.30, 0.31, 0.29), 0.10, 0.63)
GREEN = material("Alliance green", (0.08, 0.33, 0.20), 0.44, 0.28)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def apply_bevel(obj, width=0.12, segments=3):
    mod = obj.modifiers.new("Precision bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"


def box(name, x, y, w, h, depth=0.34, z=0.58, mat=STEEL, rot=0.0, bevel=0.09):
    bpy.ops.mesh.primitive_cube_add(location=(x, y, z), rotation=(0, 0, rot))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (w, h, depth)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, min(bevel, w * .18, h * .18), 3)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, x, y, radius, depth=0.36, z=0.60, mat=STEEL, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    apply_bevel(obj, min(0.08, radius * .15), 3)
    obj.data.materials.append(mat)
    return obj


def sphere(name, x, y, radius, z=0.64, mat=STEEL):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=radius, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.scale.z = .28
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def torus(name, x, y, major, minor=.12, z=.68, mat=BRASS):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=56, minor_segments=12, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def bar(name, a, b, width=.22, depth=.32, z=.68, mat=STEEL):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    return box(name, (ax + bx) / 2, (ay + by) / 2, math.hypot(dx, dy), width, depth, z, mat, math.atan2(dy, dx), width * .35)


def polygon(name, points, depth=.32, z=.52, mat=STEEL, bevel=.07):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.resolution_u = 2
    curve.fill_mode = "BOTH"
    curve.extrude = depth / 2
    curve.bevel_depth = bevel
    curve.bevel_resolution = 3
    spl = curve.splines.new("POLY")
    spl.points.add(len(points) - 1)
    for point, (x, y) in zip(spl.points, points):
        point.co = (x, y, 0, 1)
    spl.use_cyclic_u = True
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location.z = z
    obj.data.materials.append(mat)
    return obj


def plate(category, accent=BRASS):
    palette = {
        "building": (GUNMETAL, BRASS), "resource": (GUNMETAL, LIGHT_STEEL),
        "equipment": (OLIVE, STEEL), "focus": (GUNMETAL, accent),
        "tech": (NAVY, LIGHT_STEEL), "politics": (GUNMETAL, accent),
    }
    inner, rim = palette.get(category, (GUNMETAL, accent))
    box("Outer forged rim", 0, 0, 5.72, 5.72, .34, .12, rim, bevel=.44)
    box("Recessed enamel plate", 0, 0, 5.30, 5.30, .34, .32, inner, bevel=.37)
    box("Upper glint", -1.18, 2.24, 2.38, .045, .05, .54, GOLD, bevel=.02)
    cylinder("Corner rivet NW", -2.30, 2.30, .09, .12, .58, rim, 24)
    cylinder("Corner rivet SE", 2.30, -2.30, .09, .12, .58, rim, 24)


def star(x=0, y=0, outer=1.65, inner=.72, mat=GOLD, points=5):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.pi / 2 + i * math.pi / points
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    polygon("Relief star", pts, .34, .58, mat, .045)


def gear(x=0, y=0, radius=1.48, mat=BRASS):
    pts = []
    for i in range(32):
        r = radius if i % 4 in (0, 1) else radius * .78
        a = i * math.tau / 32
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    polygon("Machined gear", pts, .32, .57, mat, .04)
    cylinder("Gear hub", x, y, radius * .34, .42, .68, GUNMETAL)


def factory(military=False):
    mat = STEEL if military else IVORY
    polygon("Sawtooth factory", [(-2,-1.7),(-2,.35),(-1.2,1.0),(-1.2,.35),(-.25,1.0),(-.25,.35),(.72,1.0),(.72,-1.7)], .34, .57, mat)
    box("Factory wing", .65, -.72, 2.65, 1.96, .34, .57, mat)
    box("Smokestack", 1.55, .65, .60, 2.65, .38, .60, LIGHT_STEEL)
    box("Stack cap", 1.55, 2.0, .82, .25, .38, .61, BRASS)
    for x in (-1.45, -.6, .25, 1.05):
        box("Lit factory window", x, -1.08, .43, .48, .10, .83, GOLD, bevel=.04)
    if military:
        bar("Artillery barrel", (.15, -.05), (2.2, 1.75), .32, .32, .92, GOLD)
        cylinder("Breech", -.04, -.23, .38, .35, .90, STEEL)


def ship(kind="navy"):
    sizes = {"convoy": 1.8, "destroyer": 2.05, "cruiser": 2.25, "battleship": 2.45, "navy": 2.2}
    w = sizes.get(kind, 2.1)
    polygon("Ship hull", [(-w,-.85),(w,-.85),(w-.52,-1.55),(-w+.48,-1.55)], .38, .58, NAVY)
    box("Ship deck", 0, -.38, w * 1.55, .55, .34, .66, LIGHT_STEEL)
    box("Bridge", -.15, .12, 1.05, .88, .34, .70, IVORY)
    box("Mast", .15, .95, .16, 1.35, .28, .76, BRASS)
    if kind in ("cruiser", "battleship", "destroyer"):
        for x in (-1.12, 1.02):
            cylinder("Naval turret", x, -.08, .31, .36, .84, STEEL)
            bar("Naval gun", (x, .12), (x + (-.7 if x < 0 else .7), .68), .12, .22, .92, GOLD)


def dockyard():
    ship("convoy")
    box("Crane tower", -1.68, .75, .25, 3.3, .28, .86, BRASS)
    bar("Crane boom", (-1.62, 1.84), (1.25, 1.38), .21, .25, .88, BRASS)
    bar("Crane cable", (.85, 1.43), (.85, .35), .08, .15, .91, LIGHT_STEEL)


def infrastructure():
    polygon("Road bed", [(-1.75,-2.15),(-.52,2.05),(.52,2.05),(1.75,-2.15)], .24, .58, CONCRETE)
    for y in (-1.45,-.55,.35,1.25):
        box("Road stripe", 0, y, .18, .52, .10, .82, IVORY, bevel=.025)
    for x in (-2.05,2.05):
        bar("Rail", (x,-2.05),(x,.85), .13, .22, .79, STEEL)
    for y in (-1.8,-1.2,-.6,0,.6):
        box("Rail sleeper", 0, y, 4.45, .15, .16, .72, BRASS, bevel=.025)


def plane(kind="fighter"):
    color = LIGHT_STEEL if kind == "fighter" else OLIVE
    polygon("Aircraft fuselage", [(-.18,-2.2),(.18,-2.2),(.42,.2),(.18,2.18),(-.18,2.18),(-.42,.2)], .32, .61, color)
    if kind == "bomber":
        polygon("Broad bomber wings", [(-2.45,-.25),(-2.3,.38),(-.18,.74),(2.3,.38),(2.45,-.25),(.15,.08)], .30, .61, color)
    else:
        polygon("Fighter wings", [(-2.25,-.05),(-2.05,.48),(-.16,.74),(2.05,.48),(2.25,-.05),(.15,.12)], .30, .61, color)
    polygon("Tailplane", [(-.85,-1.62),(-.72,-1.18),(0,-1.0),(.72,-1.18),(.85,-1.62),(0,-1.4)], .30, .62, color)
    sphere("Canopy", 0, .58, .28, .90, BLUE)


def anchor():
    torus("Anchor ring", 0, 1.65, .36, .10, .77, GOLD)
    bar("Anchor shank", (0,1.34),(0,-1.25), .30, .30, .74, LIGHT_STEEL)
    bar("Anchor stock", (-1.05,.72),(1.05,.72), .23, .28, .77, GOLD)
    bar("Anchor left fluke", (0,-1.2),(-1.35,-.42), .27, .30, .76, LIGHT_STEEL)
    bar("Anchor right fluke", (0,-1.2),(1.35,-.42), .27, .30, .76, LIGHT_STEEL)


def anti_air():
    box("AA carriage", 0, -1.45, 3.3, .55, .40, .61, OLIVE)
    cylinder("AA mount", 0, -.82, .62, .42, .67, STEEL)
    bar("AA left barrel", (-.25,-.58),(-.75,1.95), .22, .26, .83, LIGHT_STEEL)
    bar("AA right barrel", (.25,-.58),(.75,1.95), .22, .26, .83, LIGHT_STEEL)
    cylinder("AA left muzzle", -.75, 1.95, .18, .28, .86, BRASS)
    cylinder("AA right muzzle", .75, 1.95, .18, .28, .86, BRASS)


def refinery():
    for x, r, h in [(-1.25,.72,1.95),(1.15,.82,2.42)]:
        box("Storage tank body", x, -.55, r*2, h, .38, .61, STEEL, bevel=.28)
        box("Tank brass band", x, -.15, r*2.06, .16, .42, .83, BRASS, bevel=.03)
    bar("Refinery pipe", (-1.15,.52),(-.25,1.42), .18, .25, .87, COPPER)
    bar("Refinery pipe", (-.25,1.42),(1.15,1.42), .18, .25, .87, COPPER)
    box("Flare stack", 1.9, 1.0, .24, 2.25, .30, .75, GUNMETAL)
    polygon("Flare", [(1.58,2.08),(1.9,2.62),(2.2,2.06),(1.9,1.72)], .20, .73, GOLD)


def resource_symbol(kind):
    if kind == "oil":
        sphere("Oil drop", 0, -.35, 1.26, .76, BLACK)
        polygon("Oil drop crown", [(-1.04,.1),(0,2.1),(1.04,.1)], .36, .58, BLACK)
        sphere("Oil glint", -.42, .25, .22, .93, LIGHT_STEEL)
    elif kind == "steel":
        box("I-beam web", 0, 0, .48, 3.75, .42, .64, STEEL)
        box("I-beam top", 0, 1.72, 2.75, .48, .42, .64, LIGHT_STEEL)
        box("I-beam foot", 0, -1.72, 2.75, .48, .42, .64, LIGHT_STEEL)
    elif kind == "aluminium":
        polygon("Aluminium ingot", [(-1.75,-1.3),(1.72,-1.3),(1.18,1.35),(-1.12,1.35)], .46, .60, LIGHT_STEEL)
        bar("Ingot highlight", (-1.05,.86),(1.0,.86), .15, .14, .96, IVORY)
    elif kind == "tungsten":
        polygon("Tungsten crystal", [(0,2.05),(1.5,.62),(1.1,-1.65),(-1.1,-1.65),(-1.5,.62)], .48, .57, STEEL)
        bar("Crystal facet", (0,1.75),(0,-1.45), .13, .18, .95, GOLD)
    elif kind == "chromium":
        torus("Chromium hex ring", 0, 0, 1.55, .36, .75, LIGHT_STEEL)
        cylinder("Chromium core", 0, 0, .68, .38, .72, BLUE)
    else:
        torus("Rubber tyre", 0, 0, 1.56, .62, .72, RUBBER)
        cylinder("Tyre hub", 0, 0, .62, .30, .72, STEEL)


def tank(heavy=False):
    box("Tank tracks", 0, -1.0, 4.25 if heavy else 3.75, .92, .42, .61, GUNMETAL, bevel=.30)
    box("Tank hull", 0, -.38, 3.5 if heavy else 3.05, 1.15, .42, .70, OLIVE, bevel=.22)
    cylinder("Tank turret", .20, .46, .78 if heavy else .66, .42, .82, STEEL)
    bar("Tank cannon", (.65,.58),(2.35,1.05), .20, .28, .94, LIGHT_STEEL)
    for x in (-1.25,-.42,.42,1.25):
        cylinder("Road wheel", x, -1.03, .29, .18, .88, BRASS, 32)


def artillery(kind="artillery"):
    cylinder("Gun wheel left", -1.02, -1.05, .58, .30, .68, GUNMETAL)
    cylinder("Gun wheel right", .65, -.92, .50, .30, .68, GUNMETAL)
    angle = 1.0 if kind == "anti_air" else .52
    bar("Gun barrel", (-.25,-.35),(2.2 * math.cos(angle), -.1 + 2.2 * math.sin(angle)), .26, .31, .86, LIGHT_STEEL)
    box("Gun shield", -.20, -.10, 1.35, 1.05, .28, .78, OLIVE, rot=-.08)


def rifle():
    bar("Rifle stock", (-1.75,-1.55),(1.55,1.40), .34, .34, .76, BRASS)
    bar("Rifle barrel", (.75,.68),(2.12,1.93), .17, .25, .82, LIGHT_STEEL)
    bar("Rifle magazine", (-.15,-.03),(-.05,-.85), .31, .27, .89, GUNMETAL)


def crate():
    box("Support crate", 0, 0, 3.65, 3.1, .43, .61, OLIVE, bevel=.22)
    bar("Crate brace", (-1.55,-1.22),(1.55,1.22), .22, .22, .88, BRASS)
    bar("Crate brace", (-1.55,1.22),(1.55,-1.22), .22, .22, .88, BRASS)
    cylinder("Medical seal", 0, 0, .58, .18, .98, RED)
    box("Medical cross", 0, 0, 1.02, .25, .12, 1.10, IVORY)
    box("Medical cross", 0, 0, .25, 1.02, .12, 1.10, IVORY)


def truck():
    box("Truck cargo", -.72, .18, 2.7, 1.55, .42, .66, OLIVE, bevel=.16)
    box("Truck cab", 1.15, -.08, 1.20, 1.42, .42, .69, STEEL, bevel=.15)
    box("Truck window", 1.23, .28, .70, .52, .10, .96, BLUE, bevel=.05)
    for x in (-1.35,.95): torus("Truck tyre", x, -.92, .45, .16, .86, RUBBER)


def strait_treaty():
    polygon("Bosphorus water", [(-.55,-2.25),(.35,-1.4),(-.28,-.55),(.50,.34),(-.36,1.2),(.55,2.25),(-.72,2.25),(-1.18,1.1),(-.50,.18),(-1.15,-.62),(-.28,-1.45)], .28, .58, BLUE)
    for x in (-1.92,1.92):
        box("Strait fortress", x, -.75, .92, 1.4, .38, .67, CONCRETE, bevel=.12)
        box("Fortress tower", x, .08, .38, .72, .40, .72, LIGHT_STEEL, bevel=.08)
    bar("Treaty ribbon", (-1.45,1.55),(1.45,1.55), .42, .28, .88, IVORY)
    cylinder("Treaty seal", 1.42, 1.55, .30, .18, .99, RED)


def kemalist():
    for i in range(12):
        a = i * math.tau / 12
        bar("Sun ray", (math.cos(a)*.82, math.sin(a)*.82),(math.cos(a)*2.0, math.sin(a)*2.0), .18, .22, .72, GOLD)
    cylinder("Rising state sun", 0, 0, .92, .38, .79, RED)
    star(0, 0, .58, .24, IVORY)


def book_wheat():
    polygon("Left open book", [(-2,-1.2),(-.15,-.75),(-.15,1.35),(-2,.85)], .28, .60, IVORY)
    polygon("Right open book", [(.15,-.75),(2,-1.2),(2,.85),(.15,1.35)], .28, .60, IVORY)
    bar("Wheat stem", (0,-1.45),(0,2.0), .12, .18, .91, GOLD)
    for y in (-.5,.05,.6,1.15):
        bar("Wheat grain", (0,y),(-.52,y+.38), .18, .17, .91, GOLD)
        bar("Wheat grain", (0,y),(.52,y+.38), .18, .17, .91, GOLD)


def fortification():
    polygon("Fortified bunker", [(-2.1,-1.35),(2.1,-1.35),(1.7,1.15),(-1.7,1.15)], .48, .56, CONCRETE)
    box("Bunker firing slit", 0, .15, 2.45, .38, .14, .96, GUNMETAL, bevel=.05)
    for x in (-1.48,1.48): cylinder("Bunker bolt", x, -.88, .12, .14, .99, BRASS, 24)


def diplomacy_symbol(axis=False):
    for x, mat in [(-.72, BLUE),(.72, RED if axis else GREEN)]:
        polygon("Alliance shield", [(x-0.72,.9),(x+.72,.9),(x+.58,-.5),(x,-1.25),(x-.58,-.5)], .34, .62, mat)
    bar("Treaty clasp", (-.72,-.25),(.72,-.25), .45, .30, .91, GOLD)
    star(-.72,.25,.36,.16,IVORY)
    star(.72,.25,.36,.16,IVORY)


def propaganda():
    polygon("Megaphone bell", [(-1.9,-1.05),(.55,-.42),(.55,.72),(-1.9,1.32)], .36, .60, RED)
    box("Megaphone body", .88, .15, .72, 1.05, .38, .69, LIGHT_STEEL)
    bar("Megaphone handle", (.72,-.28),(1.25,-1.42), .30, .30, .81, BRASS)
    for y in (-.75,0,.75): bar("Broadcast ray", (1.55,y*.55),(2.38,y), .15, .18, .82, GOLD)


def radio_radar(radar=False):
    box("Radio chassis", 0, -.35, 3.75, 2.5, .42, .63, GUNMETAL, bevel=.28)
    if radar:
        polygon("Radar dish", [(-1.4,.5),(1.4,.5),(0,2.05)], .28, .62, LIGHT_STEEL)
        cylinder("Radar pivot", 0, .48, .34, .30, .87, BRASS)
    else:
        torus("Radio dial", -.78, -.18, .58, .12, .91, BRASS)
        for x in (.42,1.0): cylinder("Radio knob", x, -.34, .18, .14, .94, LIGHT_STEEL, 24)
        bar("Radio aerial", (1.25,.78),(1.75,2.15), .11, .16, .82, GOLD)


def doctrine():
    polygon("Doctrine shield", [(-1.65,1.6),(1.65,1.6),(1.42,-.5),(0,-2.0),(-1.42,-.5)], .36, .59, RED)
    bar("Crossed sword", (-1.35,-1.22),(1.28,1.38), .23, .28, .90, LIGHT_STEEL)
    bar("Crossed sword", (1.35,-1.22),(-1.28,1.38), .23, .28, .90, GOLD)


def symbol_for(key, category):
    k = key.lower()
    if "montreux" in k: return strait_treaty()
    if "kemal" in k: return kemalist()
    if "village" in k: return book_wheat()
    if any(x in k for x in ("thrace","maginot","defense","fortif")): return fortification()
    if any(x in k for x in ("allies","balkan","saadabad","pact","guarantee","united_front","tripartite")): return diplomacy_symbol("axis" in k or "tripartite" in k)
    if any(x in k for x in ("propaganda","unity","new_deal","politic")): return propaganda()
    if any(x in k for x in ("montreux",)): return strait_treaty()
    if any(x in k for x in ("dockyard",)): return dockyard()
    if any(x in k for x in ("naval_base",)): return anchor()
    if any(x in k for x in ("navy","fleet","ocean","mare","kaigun","aegean")): return ship("battleship")
    if "submarine" in k: return ship("submarine")
    if "destroyer" in k: return ship("destroyer")
    if "cruiser" in k: return ship("cruiser")
    if "battleship" in k: return ship("battleship")
    if "convoy" in k: return ship("convoy")
    if any(x in k for x in ("anti_air",)): return anti_air()
    if any(x in k for x in ("air_base",)): return plane("fighter")
    if any(x in k for x in ("air","fighter","cas","nuri","bomber")): return plane("bomber" if "bomber" in k else "fighter")
    if any(x in k for x in ("synthetic","refinery","rubber")): return refinery() if category != "resource" else resource_symbol("rubber")
    if any(x in k for x in ("rail","infra","construction","weser")): return infrastructure()
    if any(x in k for x in ("karabuk","steel")): return resource_symbol("steel")
    if any(x in k for x in ("factory","industry","industrial","plan","arms","arsenal","rearm","mobiliz","sumerbank","manchuria")): return factory(any(x in k for x in ("arms","rearm","arsenal","military")))
    if any(x in k for x in ("tank","armor")): return tank("medium" in k or "2" in k)
    if any(x in k for x in ("artillery","anti_tank")): return artillery("anti_tank" if "anti_tank" in k else "artillery")
    if any(x in k for x in ("infantry","equipment","weapons")): return rifle()
    if any(x in k for x in ("motor",)): return truck()
    if any(x in k for x in ("support",)): return crate()
    if any(x in k for x in ("radio","radar","comput")): return radio_radar("radar" in k)
    if any(x in k for x in ("research","electronics")): return gear()
    if any(x in k for x in ("doctrine","army","war","barbarossa","purge","rhineland","danzig","winter")): return doctrine()
    if category == "resource": return resource_symbol(k.replace("resource_", ""))
    if any(x in k for x in ("hatay","mosul","poland","baltic","sudeten","bohemia","albania","greece","denmark","west","south")): return fortification()
    if any(x in k for x in ("neutral","peace")): return diplomacy_symbol(False)
    star(mat=GOLD)


def accent_for(key):
    choices = [BRASS, RED, BLUE, GREEN, STEEL, COPPER]
    return choices[sum(ord(c) for c in key) % len(choices)]


def setup_world():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 20
    scene.render.film_transparent = True
    scene.render.resolution_percentage = 100
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("Icon world") if not bpy.data.worlds else bpy.data.worlds[0]
    scene.world = world
    world.color = (0.008, 0.012, 0.016)
    return scene


def camera_and_lights():
    bpy.ops.object.camera_add(location=(0, -7.8, 8.8))
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 7.5
    cam.rotation_euler = ((Vector((0,0,.25)) - cam.location).to_track_quat("-Z", "Y").to_euler())
    bpy.context.scene.camera = cam
    for name, loc, energy, size, color in [
        ("Key", (-4.2,-4.8,8.5), 1050, 4.0, (1.0,.72,.38)),
        ("Cool fill", (4.5,-1.0,5.8), 760, 5.0, (.34,.60,1.0)),
        ("Rim", (0,5.0,7.0), 900, 3.0, (1.0,.38,.16)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        light.rotation_euler = ((Vector((0,0,0)) - light.location).to_track_quat("-Z", "Y").to_euler())


def render_icon(filename, key, category):
    target = OUT / f"{filename}.png"
    if target.exists():
        return
    clear_scene()
    accent = accent_for(key)
    plate(category, accent)
    symbol_for(key, category)
    camera_and_lights()
    scene = bpy.context.scene
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)


def load_data():
    common = ROOT / "data" / "common"
    buildings = list(json.loads((common / "buildings.json").read_text())["buildings"])
    equipment = list(json.loads((common / "equipment.json").read_text())["equipment"])
    resources = ["oil", "steel", "aluminium", "tungsten", "chromium", "rubber"]
    focus_trees = json.loads((common / "focuses.json").read_text())["trees"]
    focuses = sorted({f["id"] for tree in focus_trees.values() for f in tree})
    techs = list(json.loads((common / "technologies.json").read_text())["techs"])
    spirits_data = json.loads((common / "spirits.json").read_text())
    politics = [("spirit", x) for x in spirits_data["spirits"]]
    politics += [("advisor", x) for x in spirits_data["advisors"]]
    politics += [("decision", x) for x in spirits_data["decisions"]]
    events = list(json.loads((common / "events.json").read_text())["events"])
    laws_data = json.loads((common / "laws.json").read_text())["groups"]
    laws = [law for group in laws_data.values() for law in group["laws"]]
    return buildings, resources, equipment, focuses, techs, politics, events, laws


def main():
    setup_world()
    buildings, resources, equipment, focuses, techs, politics, events, laws = load_data()
    jobs = []
    jobs += [(f"building_{x}", x, "building") for x in buildings]
    jobs += [(f"resource_{x}", x, "resource") for x in resources]
    jobs += [(f"equipment_{x}", x, "equipment") for x in equipment]
    jobs += [(f"focus_{x}", x, "focus") for x in focuses]
    jobs += [(f"tech_{x}", x, "tech") for x in techs]
    jobs += [(f"{kind}_{x}", x, "politics") for kind, x in politics]
    jobs += [(f"event_{x}", x, "focus") for x in events]
    jobs += [(f"law_{x}", x, "politics") for x in laws]
    core = ["politics", "research", "diplomacy", "trade", "construction", "production",
            "army", "navy", "air", "political_power", "stability", "war_support",
            "manpower", "factory", "military_factory"]
    jobs += [(x, x, "politics") for x in core]
    for i, (filename, key, category) in enumerate(jobs, 1):
        print(f"[{i:03}/{len(jobs):03}] {filename}", flush=True)
        render_icon(filename, key, category)
    print(f"Rendered {len(jobs)} high-resolution icons to {OUT}")


if __name__ == "__main__":
    main()
