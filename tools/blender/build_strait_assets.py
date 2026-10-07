"""Iron Front: restrained 1930s maritime miniatures, genuine editable 3D.

Blender --background --factory-startup --python tools/blender/build_strait_assets.py -- --render

Output: shore_terminal, steam_ferry, little_belt_span, little_belt_end.
Blender Z-up exports to Godot Y-up; +X remains the pier/ship/bridge axis. One
joined mesh per model, native PBR, native colour/tangent attributes, no billboard.
Only the shared city atlas/normal and existing primitive code are reused.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_mini_cities as C  # noqa: E402
A = C.A
OUT = ROOT / "assets/models/strait"
SOURCE = ROOT / "art/source/strait/library.blend"
PREVIEWS = ROOT / "art/previews/strait"


def setup_materials():
    # Reuse the already-baked native material system. No city image is modified.
    C.material_setup()
    definitions = {
        "marine_hull": ((0.095, 0.145, 0.145), 0.71, 0.12),
        "marine_keel": ((0.22, 0.105, 0.072), 0.84, 0.03),
        "marine_black": ((0.042, 0.047, 0.047), 0.88, 0.04),
        "marine_cream": ((0.72, 0.74, 0.69), 0.79, 0.04),
        "bridge_steel": ((0.235, 0.285, 0.27), 0.67, 0.38),
    }
    for name, (color, roughness, metal) in definitions.items():
        A.MATERIALS[name] = (None, color, roughness, metal)
        C.wire_vertex_tint(A.mat(name))


def tint(ob, color=(1, 1, 1), grime=False):
    layer = ob.data.color_attributes.get("CityTint")
    if layer is None:
        layer = ob.data.color_attributes.new(name="CityTint", type="FLOAT_COLOR", domain="CORNER")
    index = list(ob.data.color_attributes).index(layer)
    ob.data.color_attributes.active_color_index = index
    ob.data.color_attributes.render_color_index = index
    for loop in ob.data.loops:
        z = ob.data.vertices[loop.vertex_index].co.z
        dirt = max(0, 1 - max(0, z) / 0.05) * 0.10 if grime else 0
        layer.data[loop.index].color = (color[0] * (1 - dirt), color[1] * (1 - dirt), color[2] * (1 - dirt * 1.15), 1)
    return ob


def move_parts(start, x=0, y=0, z=0, rot=0):
    matrix = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, "Z")
    for ob in A._parts[start:]:
        ob.data.transform(matrix)


def beam(a, b, width=0.003, material="city_metal", depth=None):
    a, b = Vector(a), Vector(b)
    delta = b - a
    depth = depth or width
    ob = A.box(0, 0, -depth / 2, delta.length, width, depth, material)
    q = Vector((1, 0, 0)).rotation_difference(delta.normalized())
    ob.data.transform(Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())
    return ob


def rod(a, b, radius=0.0012, material="city_metal", segments=8):
    a, b = Vector(a), Vector(b)
    delta = b - a
    ob = A.cylinder(0, 0, 0, radius, delta.length, material, segments)
    q = Vector((0, 0, 1)).rotation_difference(delta.normalized())
    ob.data.transform(Matrix.Translation(a) @ q.to_matrix().to_4x4())
    return ob


def ring(x, y, z, radius, tube, material, orientation="Y", life_ring=False):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=tube,
                                    major_segments=24, minor_segments=6)
    ob = bpy.context.object
    ob.name = "Life ring" if life_ring else "Rubber wharf fender"
    matrix = Matrix.Translation((x, y, z))
    if orientation == "Y":
        matrix = matrix @ Matrix.Rotation(math.pi / 2, 4, "X")
    elif orientation == "X":
        matrix = matrix @ Matrix.Rotation(math.pi / 2, 4, "Y")
    ob.data.transform(matrix)
    ob.data.materials.append(A.mat(material))
    for p in ob.data.polygons:
        p.use_smooth = True
    A._parts.append(ob)
    tint(ob)
    if life_ring:
        layer = ob.data.color_attributes.get("CityTint")
        for loop in ob.data.loops:
            p = ob.data.vertices[loop.vertex_index].co
            angle = math.atan2(p.z - z, p.x - x)
            band = int((angle + math.pi) / (math.pi / 4)) % 2 == 0
            layer.data[loop.index].color = (0.92, 0.16, 0.075, 1) if band else (1, 1, 0.91, 1)
    return ob


def rail_line(points, height=0.025, material="city_metal", posts=True):
    if posts:
        for p in points:
            rod(p, (p[0], p[1], p[2] + height), 0.0016, material)
    for a, b in zip(points, points[1:]):
        for h in (height * 0.48, height):
            rod((a[0], a[1], a[2] + h), (b[0], b[1], b[2] + h), 0.0011, material)


def small_building(x, y, w, d, h, rot=0, canopy=False):
    start = len(A._parts)
    C.box(0, 0, 0, w + 0.010, d + 0.010, 0.009, quad=1, bevel=0.001)
    C.building_facades(w, d, h, 1, wall_quad=0)
    C.roof(w, d, h, 0.035, 3, hip=True)
    C.box(0, 0, h - 0.009, w + 0.005, d + 0.005, 0.007, quad=1)
    for xx in (-w / 2, w / 2):
        for yy in (-d / 2, d / 2):
            C.box(xx, yy, 0.009, 0.005, 0.005, h - 0.009, quad=1)
    if canopy:
        C.box(0, -d / 2 - 0.031, 0.071, w * 0.85, 0.073, 0.005, material="city_timber")
        for xx in (-w * 0.35, w * 0.35):
            C.box(xx, -d / 2 - 0.057, 0.009, 0.004, 0.004, 0.062, material="city_timber")
        C.box(0, -d / 2 - 0.006, 0.063, w * 0.44, 0.006, 0.015, material="city_timber")
    C.paint_parts(start, "west", 4)
    move_parts(start, x, y, 0.036, rot)


def lighthouse(x, y):
    start = len(A._parts)
    C.atlas_part(A.cylinder(0, 0, 0.036, 0.043, 0.009, "city_atlas", 8), 1)
    C.atlas_part(A.cylinder(0, 0, 0.045, 0.027, 0.125, "city_atlas", 8, r_top=0.024), 1)
    # Actual door and narrow recessed-looking dark slots on the octagonal tower.
    C.box(0, -0.0275, 0.049, 0.015, 0.002, 0.031, material="city_timber")
    C.box(0, -0.0265, 0.118, 0.009, 0.0018, 0.021, material="city_glass")
    C.atlas_part(A.cylinder(0, 0, 0.168, 0.036, 0.007, "city_atlas", 12), 1)
    # Eight lantern panes are actual glass geometry, separated by metal uprights.
    for i in range(8):
        a, b = i * math.tau / 8, (i + 1) * math.tau / 8
        pa, pb = Vector((math.cos(a) * 0.024, math.sin(a) * 0.024, 0.175)), Vector((math.cos(b) * 0.024, math.sin(b) * 0.024, 0.175))
        beam(pa + Vector((0, 0, 0.021)), pb + Vector((0, 0, 0.021)), 0.0014)
        rod(pa, pa + Vector((0, 0, 0.043)), 0.0013)
        pts = [pa, pb, pb + Vector((0, 0, 0.043)), pa + Vector((0, 0, 0.043))]
        part = mesh("Lantern glass", [tuple(p) for p in pts], [(0, 1, 2, 3)], ["city_glass"])
        tint(part, (0.86, 0.92, 0.90))
    A.lathe(0, 0, 0.218, [(0.032, 0), (0.030, 0.003), (0.009, 0.025), (0.003, 0.029)], "city_metal", 16)
    rod((0, 0, 0.247), (0, 0, 0.265), 0.0013)
    ring(0, 0, 0.181, 0.033, 0.0012, "city_metal", orientation="Z")
    C.paint_parts(start, "west", 1)
    move_parts(start, x, y)


def bollard(x, y, z):
    A.cylinder(x, y, z, 0.005, 0.014, "city_metal", 10)
    C.box(x, y, z + 0.010, 0.020, 0.006, 0.004, material="city_metal")
    C.box(x, y, z, 0.018, 0.015, 0.003, material="city_metal")


def crate(x, y, z, w=0.035):
    C.box(x, y, z, w, w * 0.84, w * 0.75, material="city_timber")
    for xx in (-w * 0.34, w * 0.34):
        C.box(x + xx, y, z, 0.003, w * 0.89, w * 0.81, material="city_metal")
    for k in range(3):
        C.box(x, y - w * 0.43, z + 0.004 + k * w * 0.23, w, 0.002, 0.002, material="city_timber")


def terminal():
    A._parts.clear()
    # Only the actual quayside and pier: no circular base or decorative terrain.
    outline = [(-0.5, -0.28), (-0.18, -0.28), (-0.13, -0.21), (-0.13, 0.23), (-0.20, 0.28), (-0.5, 0.28)]
    C.atlas_part(A.poly_prism(outline, 0, 0.036, "city_atlas"), 1)
    C.box(0.185, 0, 0.026, 0.630, 0.215, 0.010, quad=1, bevel=0.001)
    # Timber piles and horizontal support beams visible below the wharf deck.
    for x in (-0.080, 0.175, 0.430):
        for y in (-0.082, 0.082):
            A.cylinder(x, y, 0, 0.013, 0.028, "city_timber", 10)
        C.box(x, 0, 0.022, 0.018, 0.205, 0.006, material="city_timber")
    small_building(-0.350, 0.010, 0.275, 0.190, 0.115, math.pi / 2, canopy=True)
    small_building(-0.338, -0.210, 0.185, 0.104, 0.068, math.pi / 2)
    lighthouse(-0.318, 0.223)
    # Stone cap strips and a small cargo yard keep the edge readable at map scale.
    C.box(-0.146, 0, 0.036, 0.016, 0.455, 0.006, quad=1)
    for x in (0.020, 0.205, 0.425):
        for y in (-0.092, 0.092):
            bollard(x, y, 0.036)
            ring(x, y * 1.185, 0.019, 0.010, 0.0033, "marine_black")
    rail_line([(-0.116, -0.112, 0.036), (-0.005, -0.112, 0.036), (0.100, -0.112, 0.036)], 0.030)
    rail_line([(0.335, -0.112, 0.036), (0.495, -0.112, 0.036), (0.495, 0.108, 0.036)], 0.030)
    # Pier ladder descends to the waterline, with six real rungs.
    for x in (0.275, 0.300):
        rod((x, -0.125, 0.004), (x, -0.125, 0.052), 0.0018)
    for z in (0.010, 0.018, 0.026, 0.034, 0.042):
        rod((0.275, -0.125, z), (0.300, -0.125, z), 0.0015)
    crate(-0.170, -0.190, 0.036)
    crate(-0.202, -0.224, 0.036, 0.040)
    crate(-0.201, -0.224, 0.066, 0.025)
    # One low gangway, parallel to the pier, with open boarding space.
    C.box(0.205, -0.100, 0.038, 0.085, 0.019, 0.003, material="city_timber")
    return finish("shore_terminal", center_xy=True, floor_zero=True, normalise_width=True)


def mesh(name, vertices, faces, materials, face_materials=None, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    for name in materials:
        data.materials.append(A.mat(name))
    uv = data.uv_layers.new(name="UVMap")
    for p in data.polygons:
        p.use_smooth = smooth
        p.material_index = face_materials[p.index] if face_materials else 0
        for i in p.loop_indices:
            v = data.vertices[data.loops[i].vertex_index].co
            uv.data[i].uv = (v.x + 0.5, v.z + 0.5)
    ob = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(ob)
    A._parts.append(ob)
    return ob


HULL_STATIONS = [(-0.500, 0.066), (-0.465, 0.086), (-0.405, 0.106), (-0.310, 0.118),
                 (-0.200, 0.125), (-0.080, 0.125), (0.070, 0.124), (0.190, 0.117),
                 (0.300, 0.102), (0.380, 0.080), (0.445, 0.052), (0.485, 0.026), (0.500, 0.003)]


def boat_hull():
    # Cross-section keel -> flared topsides -> mirrored keel, with gentle sheer.
    profile = [(-0.62, -0.042), (-0.88, -0.027), (-0.98, 0), (-1, 0.055),
               (1, 0.055), (0.98, 0), (0.88, -0.027), (0.62, -0.042), (0, -0.047)]
    vertices, faces, mats = [], [], []
    for x, width in HULL_STATIONS:
        sheer = 0.010 * (abs(x) / 0.5) ** 4
        vertices.extend((x, width * sy, z + (sheer if z > 0 else 0)) for sy, z in profile)
    n = len(profile)
    for i in range(len(HULL_STATIONS) - 1):
        for j in range(n):
            k = (j + 1) % n
            if j == 3:  # Top deck is its own timber face.
                continue
            faces.append((i * n + j, (i + 1) * n + j, (i + 1) * n + k, i * n + k))
            mats.append(1 if j in (0, 6, 7, 8) else 0)
    faces.extend([tuple(range(n - 1, -1, -1)), tuple((len(HULL_STATIONS) - 1) * n + j for j in range(n))])
    mats.extend([0, 0])
    hull = mesh("Curved riveted displacement hull", vertices, faces, ["marine_hull", "marine_keel"], mats, True)
    tint(hull, (0.93, 0.97, 0.94))
    # Sheered timber deck follows the curved hull plan instead of a floating box.
    deck_points = [(x, -w * 0.987) for x, w in HULL_STATIONS]
    deck_points += [(x, w * 0.987) for x, w in HULL_STATIONS[::-1]]
    A.poly_prism(deck_points, 0.054, 0.060, "city_timber")
    for y in (-0.100, -0.075, -0.050, -0.025, 0, 0.025, 0.050, 0.075, 0.100):
        length = 0.57 if abs(y) > 0.085 else 0.72 if abs(y) > 0.055 else 0.85
        C.box(-0.035, y, 0.060, length, 0.0012, 0.0005, material="marine_black")
    # Thin physical rubbing strakes follow both curved sides.
    for side in (-1, 1):
        pts = [(x, w * side, 0.035) for x, w in HULL_STATIONS]
        for a, b in zip(pts, pts[1:]):
            beam(a, b, 0.003, "marine_black", depth=0.004)


def cabin(x, z, w, d, h):
    start = len(A._parts)
    C.building_facades(w, d, h, 1, wall_quad=0)
    C.box(0, 0, h, w + 0.018, d + 0.018, 0.005, material="marine_cream")
    C.paint_parts(start, "west", 2)
    move_parts(start, x, 0, z)


def ferry():
    A._parts.clear()
    boat_hull()
    cabin(-0.025, 0.061, 0.615, 0.167, 0.059)
    # An upper promenade plus offset enclosed wheelhouse gives period ferry silhouette.
    C.box(-0.028, 0, 0.121, 0.644, 0.193, 0.006, material="marine_cream")
    cabin(0.126, 0.128, 0.235, 0.128, 0.043)
    C.box(0.126, 0, 0.174, 0.253, 0.145, 0.003, material="marine_cream")
    # Funnel with bands, steam vent and a tall but restrained foremast.
    A.cylinder(-0.135, 0, 0.128, 0.021, 0.065, "marine_cream", 20, r_top=0.018)
    A.cylinder(-0.135, 0, 0.174, 0.019, 0.006, "marine_black", 20)
    A.cylinder(-0.135, 0, 0.193, 0.020, 0.004, "marine_black", 20)
    A.cylinder(-0.135, 0, 0.197, 0.014, 0.002, "marine_black", 16)
    rod((-0.205, 0, 0.127), (-0.205, 0, 0.221), 0.0017)
    rod((-0.205, -0.028, 0.196), (-0.205, 0.028, 0.196), 0.0013)
    rod((-0.205, 0, 0.221), (-0.307, -0.055, 0.127), 0.00065, segments=6)
    rod((-0.205, 0, 0.221), (-0.307, 0.055, 0.127), 0.00065, segments=6)
    rod((0.350, 0, 0.061), (0.350, 0, 0.189), 0.0016)
    rod((0.350, -0.022, 0.166), (0.350, 0.022, 0.166), 0.0012)
    # Deck railing: posts and two thin horizontal bars, no opaque toy walls.
    for side in (-1, 1):
        pts = [(x, w * side * 0.975, 0.061) for x, w in HULL_STATIONS]
        rail_line(pts, 0.026)
        rail_line([(-0.336, side * 0.095, 0.128), (-0.215, side * 0.095, 0.128),
                   (-0.095, side * 0.095, 0.128), (0.020, side * 0.095, 0.128),
                   (0.150, side * 0.095, 0.128), (0.290, side * 0.095, 0.128)], 0.024)
    for x in (-0.500, 0.500):
        width = HULL_STATIONS[0 if x < 0 else -1][1] * 0.975
        rail_line([(x, -width, 0.061), (x, width, 0.061)], 0.026, posts=False)
    # Two actual, quarter-painted life rings with straps on each cabin side.
    for y in (-0.086, 0.086):
        for x in (-0.170, 0.065):
            ring(x, y, 0.104, 0.010, 0.0023, "marine_cream", life_ring=True)
            C.box(x, y, 0.116, 0.003, 0.003, 0.007, material="city_timber")
    # External stair and rail up to the rear promenade.
    for i in range(7):
        x, z = -0.410 + i * 0.010, 0.063 + i * 0.009
        C.box(x, -0.062, z, 0.012, 0.035, 0.005, material="marine_cream")
    for side in (-1, 1):
        rod((-0.412, -0.062 + side * 0.018, 0.086), (-0.343, -0.062 + side * 0.018, 0.145), 0.0013)
    for x in (-0.440, 0.405):
        for y in (-0.034, 0.034):
            bollard(x, y, 0.061)
    # Round portholes on the free hull ends and an understated bow capstan.
    for x in (-0.400, -0.355, 0.350, 0.395):
        for side in (-1, 1):
            ring(x, side * (0.105 if x < 0 else 0.088), 0.040, 0.004, 0.0011, "marine_cream")
    A.cylinder(0.415, 0, 0.061, 0.009, 0.012, "city_metal", 12)
    return finish("steam_ferry", center_xy=True, normalise_width=True)


def i_beam(a, b, width=0.009, material="bridge_steel"):
    a, b = Vector(a), Vector(b)
    delta = b - a
    rotation = Vector((1, 0, 0)).rotation_difference(delta.normalized()).to_matrix().to_4x4()
    start = len(A._parts)
    A.box(0, 0, -width / 2, delta.length, width, width * 0.17, material)
    A.box(0, 0, width / 2 - width * 0.17, delta.length, width, width * 0.17, material)
    A.box(0, 0, -width / 2 + width * 0.17, delta.length, width * 0.18, width * 0.66, material)
    matrix = Matrix.Translation((a + b) / 2) @ rotation
    for ob in A._parts[start:]:
        ob.data.transform(matrix)


def rivet_plate(x, y, z):
    C.box(x, y, z - 0.010, 0.021, 0.0023, 0.020, material="bridge_steel")
    outward = -1 if y < 0 else 1
    for dx in (-0.006, 0.006):
        for dz in (-0.005, 0.005):
            rod((x + dx, y, z + dz), (x + dx, y + outward * 0.002, z + dz), 0.0012, "city_metal", 6)


def bridge_span():
    A._parts.clear()
    C.box(0.5, 0, -0.010, 1, 0.190, 0.010, material="city_pavement")
    for side in (-1, 1):
        C.box(0.5, side * 0.091, -0.002, 1, 0.015, 0.005, quad=1)
        bottom = [(i / 8, side * 0.107, 0.019) for i in range(9)]
        top = [(i / 8, side * 0.107, 0.084 + 0.034 * math.sin(math.pi * i / 8)) for i in range(9)]
        for i in range(8):
            i_beam(bottom[i], bottom[i + 1], 0.007)
            i_beam(top[i], top[i + 1], 0.007)
            i_beam(bottom[i], top[i + 1], 0.0048)
            i_beam(top[i], bottom[i + 1], 0.0048)
        for i in range(9):
            i_beam(bottom[i], top[i], 0.005)
            rivet_plate(i / 8, side * 0.112, bottom[i][2])
            rivet_plate(i / 8, side * 0.112, top[i][2])
        rail_line([(i / 8, side * 0.095, 0.003) for i in range(9)], 0.034, "bridge_steel")
    # Crossframes above the deck and lateral ties below it, like a real through truss.
    for i in range(9):
        x = i / 8
        z = 0.084 + 0.034 * math.sin(math.pi * x)
        i_beam((x, -0.107, z), (x, 0.107, z), 0.005)
        i_beam((x, -0.102, -0.008), (x, 0.102, -0.008), 0.006)
    for i in range(8):
        x, xx = i / 8, (i + 1) / 8
        rod((x, -0.102, -0.012), (xx, 0.102, -0.012), 0.0015, "bridge_steel")
        rod((x, 0.102, -0.012), (xx, -0.102, -0.012), 0.0015, "bridge_steel")
    # Ends provide low river piers under the roadway, not above it.
    for x in (0.035, 0.965):
        C.atlas_part(A.poly_prism([(x - 0.027, -0.117), (x + 0.027, -0.117),
                                   (x + 0.027, 0.117), (x - 0.027, 0.117)], -0.079, -0.017, "city_atlas"), 1)
        C.box(x, 0, -0.017, 0.065, 0.246, 0.009, quad=1)
    return finish("little_belt_span", forward_x=True)


def bridge_end():
    A._parts.clear()
    # Low land approach, ending in the stone abutment facing the steel span at +X.
    C.box(0.5, 0, -0.010, 1, 0.190, 0.010, material="city_pavement")
    for side in (-1, 1):
        C.box(0.5, side * 0.096, -0.004, 1, 0.016, 0.008, quad=1)
        C.box(0.880, side * 0.116, -0.085, 0.205, 0.036, 0.122, quad=1, bevel=0.001)
        C.box(0.880, side * 0.116, 0.037, 0.218, 0.045, 0.005, quad=1)
        rail_line([(i / 8, side * 0.096, 0.004) for i in range(7)], 0.034, "bridge_steel")
    C.atlas_part(A.poly_prism([(0.775, -0.135), (0.988, -0.135),
                               (0.988, 0.135), (0.775, 0.135)], -0.094, -0.016, "city_atlas"), 1)
    C.box(0.892, 0, -0.016, 0.216, 0.250, 0.010, quad=1)
    # Stone pilasters and modest vintage lamps, not modern highway fixtures.
    for side in (-1, 1):
        C.box(0.768, side * 0.111, 0, 0.030, 0.030, 0.049, quad=1)
        C.box(0.768, side * 0.111, 0.049, 0.035, 0.035, 0.006, quad=1)
        rod((0.768, side * 0.111, 0.055), (0.768, side * 0.111, 0.105), 0.0015, "bridge_steel")
        C.box(0.768, side * 0.111, 0.099, 0.009, 0.009, 0.014, material="city_glass")
        C.box(0.768, side * 0.111, 0.113, 0.013, 0.013, 0.003, material="bridge_steel")
    return finish("little_belt_end", forward_x=True)


def finish(name, center_xy=False, floor_zero=False, normalise_width=False, forward_x=False):
    for part in A._parts:
        if part.data.color_attributes.get("CityTint") is None:
            tint(part)
    bpy.ops.object.select_all(action="DESELECT")
    for part in A._parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = A._parts[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = name
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0000001)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.validate(clean_customdata=False)
    lo = Vector(tuple(min(v.co[i] for v in ob.data.vertices) for i in range(3)))
    hi = Vector(tuple(max(v.co[i] for v in ob.data.vertices) for i in range(3)))
    offset = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z if floor_zero else 0)) if center_xy else Vector((0, 0, lo.z if floor_zero else 0))
    scale = 1 / (hi.x - lo.x) if normalise_width else 1
    for v in ob.data.vertices:
        v.co = (v.co - offset) * scale
        if forward_x:
            v.co.x = (v.co.x - lo.x) / (hi.x - lo.x)
    unique, lookup = [], {}
    for material in ob.data.materials:
        if material.name not in lookup:
            lookup[material.name] = len(unique)
            unique.append(material)
    indices = [lookup[ob.data.materials[p.material_index].name] for p in ob.data.polygons]
    ob.data.materials.clear()
    for material in unique:
        ob.data.materials.append(material)
    for p, index in zip(ob.data.polygons, indices):
        p.material_index = index
    ob.data.update()
    ob.data.calc_loop_triangles()
    ob["asset_family"] = "1930s maritime miniature"
    ob["orientation"] = "+X water / bow / bridge advance; Blender Z -> Godot Y"
    A._parts.clear()
    return ob


def export_asset(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    tri = ob.modifiers.new("Export-only native tangent triangulation", "TRIANGULATE")
    tri.quad_method, tri.ngon_method = "FIXED", "BEAUTY"
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{ob.name}.gltf"), use_selection=True,
                              export_format="GLTF_SEPARATE", export_texture_dir="textures",
                              export_apply=True, export_yup=True, export_image_format="AUTO",
                              export_materials="EXPORT", export_cameras=False, export_lights=False,
                              export_tangents=True, export_keep_originals=True)
    ob.modifiers.remove(tri)
    lo = [min(v.co[i] for v in ob.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in ob.data.vertices) for i in range(3)]
    return {"vertices": len(ob.data.vertices), "triangles": len(ob.data.loop_triangles),
            "surfaces": len(ob.data.materials), "bounds_blender_xyz": {"min": lo, "max": hi},
            "dimensions": [hi[i] - lo[i] for i in range(3)], "node_transform": "identity",
            "native_materials": "PBR / COLOR_0 / TANGENT / shared city albedo+normal"}


def render(built):
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1500, 1100
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Maritime daylight")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.46, 0.54, 0.61, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.32
    scene.world = world
    rig = bpy.data.collections.new("Preview-only daylight and water — never exported")
    scene.collection.children.link(rig)
    for name, location, energy, size, color in (
            ("Daylight", (-1.8, -2.5, 3.5), 260, 2.2, (1, 0.93, 0.84)),
            ("Sky fill", (2, 0.8, 2.3), 70, 2.7, (0.79, 0.89, 1))):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
        ob = bpy.data.objects.new(name, data)
        ob.location = location
        ob.rotation_euler = (Vector((0, 0, 0.02)) - ob.location).to_track_quat("-Z", "Y").to_euler()
        rig.objects.link(ob)
    ground_material = bpy.data.materials.new("Preview-only calm water")
    ground_material.use_nodes = True
    bsdf = ground_material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.052, 0.125, 0.145, 1)
    bsdf.inputs["Roughness"].default_value = 0.54
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.051))
    ground = bpy.context.object
    ground.data.materials.append(ground_material)
    for coll in list(ground.users_collection):
        coll.objects.unlink(ground)
    rig.objects.link(ground)
    camera = bpy.data.objects.new("Maritime preview camera", bpy.data.cameras.new("Maritime preview camera"))
    rig.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.27

    def look(location, target=(0, 0, 0.04)):
        camera.location = location
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()

    for name, ob in built.items():
        for other in built.values():
            other.hide_render = other is not ob
        target = (0.5, 0, 0.018) if name.startswith("little_belt") else (0, 0, 0.025)
        look((target[0] + 0.86, -1.3, 1.25), target)
        scene.render.filepath = str(PREVIEWS / f"{name}.png")
        bpy.ops.render.render(write_still=True)
    # Honest paired docking preview: no fake perspective painted onto the models.
    for ob in built.values():
        ob.hide_render = ob.name.startswith("little_belt")
    boat = built["steam_ferry"]
    boat.location = (0.150, -0.285, 0.0)
    camera.data.ortho_scale = 1.48
    look((1.25, -1.7, 1.6), (0.03, -0.075, 0.030))
    scene.render.filepath = str(PREVIEWS / "terminal_and_ferry.png")
    bpy.ops.render.render(write_still=True)
    boat.location = (0, 0, 0)
    # Source gallery arranges all four editable meshes without affecting exports.
    positions = {"shore_terminal": (-0.78, 0.42, 0), "steam_ferry": (0.61, 0.40, 0),
                 "little_belt_span": (-1.27, -0.48, 0), "little_belt_end": (0.10, -0.48, 0)}
    for name, ob in built.items():
        ob.hide_render = False
        ob.location = positions[name]
    camera.data.ortho_scale = 2.95
    look((2.0, -3.2, 3.6), (0, 0, 0.02))
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1200
    scene.render.filepath = str(PREVIEWS / "library.png")
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    setup_materials()
    built, metrics = {}, {}
    for builder in (terminal, ferry, bridge_span, bridge_end):
        ob = builder()
        built[ob.name] = ob
        metrics[ob.name] = export_asset(ob)
        if ob.name == "shore_terminal":
            metrics[ob.name]["land_side_x_range"] = [-0.5, -0.13]
            metrics[ob.name]["water_side_pier_x_range"] = [-0.13, 0.5]
        if ob.name == "steam_ferry":
            metrics[ob.name]["waterline_blender_z"] = 0
        if ob.name.startswith("little_belt"):
            metrics[ob.name]["deck_blender_z"] = 0
        print("[strait]", ob.name, json.dumps(metrics[ob.name]), flush=True)
        if metrics[ob.name]["surfaces"] > 8 or metrics[ob.name]["triangles"] > 20000:
            raise ValueError(f"Budget exceeded: {ob.name}")
    (OUT / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print("[strait] All four glTF assets are ready for engine import.", flush=True)
    if args.render:
        render(built)
    for image in bpy.data.images:
        if image.source == "FILE" and image.filepath:
            image.filepath = bpy.path.relpath(bpy.path.abspath(image.filepath), start=str(SOURCE.parent))
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), relative_remap=False)
    print("[strait] Editable source:", SOURCE, flush=True)


if __name__ == "__main__":
    main()
