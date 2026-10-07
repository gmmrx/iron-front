"""Iron Front compact, genuinely three-dimensional WWII city districts.

Blender --background --factory-startup --python tools/blender/build_mini_cities.py -- --render

Eight one-mesh districts (four regional styles, two deterministic layouts) are
exported with a shared albedo atlas. Walls have actual window openings, inset
glass, stone reveals and projecting sills, not window decals. Streets are narrow
flat ribbons: there is deliberately no terrain, display base or circular plinth.
The footprint is normalised to one unit across X, with its lowest vertex at zero.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
_original_argv = sys.argv
sys.argv = [sys.argv[0]]  # Primitive library has its own, incompatible command-line parser.
import build_assets as A  # noqa: E402
sys.argv = _original_argv

OUT = ROOT / "assets/models/mini_city"
ATLAS = OUT / "textures/material_atlas.png"
NORMAL = OUT / "textures/material_atlas_normal.png"
SOURCE = ROOT / "art/source/mini_city/library.blend"
PREVIEWS = ROOT / "art/previews/mini_city"
STYLES = ("west", "east", "orient", "nordic")

# These linear multipliers live in COLOR_0, not extra material variants. The
# restrained palette breaks repetition without turning districts into bright toys.
WALL_TINTS = {
    "west": ((0.85, 0.81, 0.71), (0.78, 0.75, 0.68), (0.87, 0.76, 0.64),
             (0.73, 0.76, 0.72), (0.83, 0.72, 0.64), (0.90, 0.85, 0.76)),
    "east": ((0.86, 0.81, 0.68), (0.79, 0.73, 0.64), (0.86, 0.73, 0.67),
             (0.74, 0.78, 0.73), (0.90, 0.84, 0.73), (0.79, 0.76, 0.69)),
    "orient": ((0.87, 0.80, 0.67), (0.78, 0.74, 0.64), (0.88, 0.76, 0.60),
               (0.89, 0.85, 0.75), (0.82, 0.75, 0.66), (0.85, 0.72, 0.63)),
    "nordic": ((0.86, 0.83, 0.73), (0.80, 0.73, 0.65), (0.76, 0.80, 0.73),
               (0.89, 0.85, 0.75), (0.79, 0.76, 0.68), (0.87, 0.77, 0.66)),
}
ROOF_TINTS = ((0.84, 0.84, 0.79), (0.94, 0.84, 0.73), (0.79, 0.85, 0.88), (0.87, 0.90, 0.85))


def wire_vertex_tint(material, texture_socket=None):
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    color = nodes.new("ShaderNodeVertexColor")
    color.layer_name = "CityTint"
    color.label = "Native glTF COLOR_0 — no extra surfaces"
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    mix.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
    if texture_socket is not None:
        links.new(texture_socket, mix.inputs[6])
    links.new(color.outputs["Color"], mix.inputs[7])
    links.new(mix.outputs[2], bsdf.inputs["Base Color"])


def normal_atlas(image):
    """Bake a real tangent-space normal texture from a low-strength Bump material.

    No albedo is painted or edited, and no light/AO is baked into the asset. The
    tile and masonry micro relief comes from the shared source image's luminance.
    Plaster gets much less relief; exported materials need only a standard normal
    sampler, supported by both Godot renderers.
    """
    if NORMAL.exists():
        baked = bpy.data.images.load(str(NORMAL), check_existing=True)
        baked.colorspace_settings.name = "Non-Color"
        return baked
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    bpy.ops.mesh.primitive_plane_add(size=1)
    plane = bpy.context.object
    plane.name = "Temporary atlas normal bake plane"
    material = bpy.data.materials.new("Temporary atlas bump bake — not exported")
    material.use_nodes = True
    plane.data.materials.append(material)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    coords = nodes.new("ShaderNodeTexCoord")
    split = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["UV"], split.inputs[0])
    roof = nodes.new("ShaderNodeMath")
    roof.operation = "LESS_THAN"
    roof.inputs[1].default_value = 0.5
    links.new(split.outputs["Y"], roof.inputs[0])
    stone = nodes.new("ShaderNodeMath")
    stone.operation = "GREATER_THAN"
    stone.inputs[1].default_value = 0.5
    links.new(split.outputs["X"], stone.inputs[0])
    roof_strength = nodes.new("ShaderNodeMath")
    roof_strength.operation = "MULTIPLY"
    roof_strength.inputs[1].default_value = 0.12
    links.new(roof.outputs[0], roof_strength.inputs[0])
    stone_strength = nodes.new("ShaderNodeMath")
    stone_strength.operation = "MULTIPLY"
    stone_strength.inputs[1].default_value = 0.035
    links.new(stone.outputs[0], stone_strength.inputs[0])
    add = nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    links.new(roof_strength.outputs[0], add.inputs[0])
    links.new(stone_strength.outputs[0], add.inputs[1])
    base = nodes.new("ShaderNodeMath")
    base.operation = "ADD"
    base.inputs[1].default_value = 0.025
    links.new(add.outputs[0], base.inputs[0])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.018
    links.new(texture.outputs["Color"], bump.inputs["Height"])
    links.new(base.outputs[0], bump.inputs["Strength"])
    links.new(bump.outputs["Normal"], nodes.get("Principled BSDF").inputs["Normal"])
    baked = bpy.data.images.new("material_atlas_normal", width=1024, height=1024, alpha=False)
    baked.colorspace_settings.name = "Non-Color"
    target = nodes.new("ShaderNodeTexImage")
    target.image = baked
    nodes.active = target
    scene.render.bake.use_selected_to_active = False
    scene.render.bake.margin = 4
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    baked.filepath_raw = str(NORMAL)
    baked.file_format = "PNG"
    baked.save()
    bpy.data.objects.remove(plane, do_unlink=True)
    bpy.data.materials.remove(material)
    print("[mini_city] Blender tangent-space normal bake:", NORMAL)
    return baked


def material_setup():
    if not ATLAS.exists():
        raise FileNotFoundError(f"Generate the four-quadrant material atlas first: {ATLAS}")
    image = bpy.data.images.load(str(ATLAS), check_existing=True)
    image.name = "mini_city_material_atlas"
    image.filepath = str(ATLAS)
    m = bpy.data.materials.new("City atlas | plaster · limestone · terracotta · slate")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.86
    texture = m.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    texture.extension = "EXTEND"
    wire_vertex_tint(m, texture.outputs["Color"])
    normal = m.node_tree.nodes.new("ShaderNodeTexImage")
    normal.image = normal_atlas(image)
    normal.image.colorspace_settings.name = "Non-Color"
    normal.extension = "EXTEND"
    normal_map = m.node_tree.nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.65
    m.node_tree.links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    m.node_tree.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    A._mats["city_atlas"] = m
    plain = {
        "city_glass": ((0.105, 0.145, 0.16), 0.37, 0.08),
        "city_timber": ((0.27, 0.145, 0.085), 0.88, 0.0),
        "city_metal": ((0.28, 0.34, 0.315), 0.68, 0.2),
        "city_pavement": ((0.265, 0.255, 0.225), 0.96, 0.0),
        "city_brick": ((0.36, 0.17, 0.115), 0.9, 0.0),
    }
    for name, (color, roughness, metal) in plain.items():
        A.MATERIALS[name] = (None, color, roughness, metal)
        wire_vertex_tint(A.mat(name))


def paint_parts(start, style, index):
    """Per-building colour and subtle bottom dirt, without modifying any vertices."""
    wall = WALL_TINTS[style][(index * 5 + STYLES.index(style)) % len(WALL_TINTS[style])]
    roof_color = ROOF_TINTS[(index + STYLES.index(style)) % len(ROOF_TINTS)]
    for ob in A._parts[start:]:
        layer = ob.data.color_attributes.get("CityTint")
        if layer is None:
            layer = ob.data.color_attributes.new(name="CityTint", type="FLOAT_COLOR", domain="CORNER")
        ob.data.color_attributes.active_color_index = list(ob.data.color_attributes).index(layer)
        ob.data.color_attributes.render_color_index = list(ob.data.color_attributes).index(layer)
        uv = ob.data.uv_layers.active
        for polygon in ob.data.polygons:
            material = ob.data.materials[polygon.material_index].name
            mean_v = sum(uv.data[i].uv.y for i in polygon.loop_indices) / len(polygon.loop_indices)
            tint = roof_color if material.startswith("City atlas") and mean_v < 0.5 else wall
            if material == "city_glass":
                tint = (0.94, 0.96, 0.97)
            elif material == "city_metal":
                tint = (0.85, 0.91, 0.86)
            elif material == "city_timber":
                tint = (0.94, 0.91, 0.84) if style != "nordic" else (wall[0], wall[1], wall[2])
            elif material == "city_pavement":
                tint = (1, 1, 1)
            for i in polygon.loop_indices:
                z = ob.data.vertices[ob.data.loops[i].vertex_index].co.z
                grime = max(0, 1 - z / 0.026) * (0.11 if material != "city_glass" else 0)
                layer.data[i].color = (tint[0] * (1 - grime * 0.80),
                                       tint[1] * (1 - grime), tint[2] * (1 - grime * 1.15), 1)


def atlas_uv(quad, u, v):
    # Blender V starts at the bottom. Leave a substantial gutter to avoid bleed.
    offsets = ((0, 0.5), (0.5, 0.5), (0, 0), (0.5, 0))
    x, y = offsets[quad]
    return (x + 0.016 + 0.468 * u, y + 0.016 + 0.468 * v)


def atlas_part(ob, quad):
    """Map every solid face into one exact atlas quadrant, without UV wrapping."""
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    for polygon in ob.data.polygons:
        n = polygon.normal
        tangent = Vector((1, 0, 0)) if abs(n.z) > 0.8 else Vector((0, 0, 1)).cross(n).normalized()
        bitangent = Vector((0, 1, 0)) if abs(n.z) > 0.8 else n.cross(tangent).normalized()
        ps = [ob.data.vertices[ob.data.loops[i].vertex_index].co for i in polygon.loop_indices]
        xs, ys = [p.dot(tangent) for p in ps], [p.dot(bitangent) for p in ps]
        lo_x, lo_y, dx, dy = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)
        for i, x, y in zip(polygon.loop_indices, xs, ys):
            uv.data[i].uv = atlas_uv(quad, (x - lo_x) / max(dx, 1e-6), (y - lo_y) / max(dy, 1e-6))
    return ob


def box(x, y, z, w, d, h, quad=1, material=None, rot=0, bevel=0):
    ob = A.box(x, y, z, w, d, h, material or "city_atlas", rot=rot)
    if material is None:
        atlas_part(ob, quad)
    if bevel:
        modifier = ob.modifiers.new("Light-catching stone edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
    return ob


class Facade:
    """One small mesh containing wall bands, actual reveals, glass and timber."""
    def __init__(self, quad):
        self.vertices, self.faces, self.materials, self.uvs = [], [], [], []
        self.quad = quad

    def face(self, points, material=0, uvs=None):
        start = len(self.vertices)
        self.vertices.extend(points)
        self.faces.append(tuple(range(start, start + len(points))))
        self.materials.append(material)
        self.uvs.append(uvs)

    def finish(self):
        mesh = bpy.data.meshes.new("Window-opening facades")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        mesh.materials.clear()
        for name in ("city_atlas", "city_glass", "city_timber"):
            mesh.materials.append(A.mat(name))
        layer = mesh.uv_layers.new(name="UVMap")
        for poly, mat, uvs in zip(mesh.polygons, self.materials, self.uvs):
            poly.material_index = mat
            for j, index in enumerate(poly.loop_indices):
                layer.data[index].uv = uvs[j] if uvs else atlas_uv(self.quad, j % 2, j // 2)
        ob = bpy.data.objects.new("Facades with recessed windows", mesh)
        bpy.context.collection.objects.link(ob)
        A._parts.append(ob)
        return ob


def building_facades(w, d, h, floors, wall_quad=0, timber=False, shop=False):
    f = Facade(wall_quad)
    sides = [((-w / 2, -d / 2), (1, 0), (0, -1), w),
             ((w / 2, d / 2), (-1, 0), (0, 1), w),
             ((w / 2, -d / 2), (0, 1), (1, 0), d),
             ((-w / 2, d / 2), (0, -1), (-1, 0), d)]
    floor_h = (h - 0.006) / floors
    for side, (origin, tangent, normal, length) in enumerate(sides):
        columns = max(2, round(length / 0.052))
        cell = length / columns

        def point(s, z, inset=0):
            return (origin[0] + tangent[0] * s - normal[0] * inset,
                    origin[1] + tangent[1] * s - normal[1] * inset, z)

        def plate(s0, s1, z0, z1, material=0, inset=0):
            points = [point(s0, z0, inset), point(s1, z0, inset), point(s1, z1, inset), point(s0, z1, inset)]
            uv = [atlas_uv(wall_quad, s0 / length, z0 / h), atlas_uv(wall_quad, s1 / length, z0 / h),
                  atlas_uv(wall_quad, s1 / length, z1 / h), atlas_uv(wall_quad, s0 / length, z1 / h)]
            f.face(points, material, uv)

        for floor in range(floors):
            bottom, top = 0.006 + floor * floor_h, 0.006 + (floor + 1) * floor_h
            for col in range(columns):
                a, b = col * cell, (col + 1) * cell
                center = (a + b) / 2
                door = side == 0 and floor == 0 and col == columns // 2
                ww = cell * (0.57 if shop and floor == 0 else 0.42)
                wh = floor_h * (0.73 if door else 0.46)
                zl = bottom if door else bottom + floor_h * 0.27
                zh, left, right = zl + wh, center - ww / 2, center + ww / 2
                # Four coplanar wall bands surround a real hole.
                wall_material = 2 if timber else 0
                plate(a, b, bottom, zl, wall_material)
                plate(a, b, zh, top, wall_material)
                plate(a, left, zl, zh, wall_material)
                plate(right, b, zl, zh, wall_material)
                # Stone-faced recess, with the pane 3.2 mm behind the surface.
                hole = [point(left, zl), point(right, zl), point(right, zh), point(left, zh)]
                back = [point(left, zl, 0.0032), point(right, zl, 0.0032),
                        point(right, zh, 0.0032), point(left, zh, 0.0032)]
                for j in range(4):
                    k = (j + 1) % 4
                    f.face([hole[j], hole[k], back[k], back[j]])
                f.face(back, 2 if door else 1)
                # Thin stone frame and timber mullions, geometrically separate.
                fw = 0.0018
                plate(left - fw, left + fw, zl, zh, 0, -0.001)
                plate(right - fw, right + fw, zl, zh, 0, -0.001)
                plate(left - fw, right + fw, zh - fw, zh + fw, 0, -0.001)
                if not door:
                    plate(center - 0.0007, center + 0.0007, zl, zh, 2, 0.0014)
                    plate(left, right, (zl + zh) / 2 - 0.0007, (zl + zh) / 2 + 0.0007, 2, 0.0014)
                    sx, sy, _ = point(center, zl, -0.0012)
                    box(sx, sy, zl - 0.002, ww + 0.007, 0.007, 0.003,
                        rot=math.atan2(tangent[1], tangent[0]))
                elif side == 0:
                    sx, sy, _ = point(center, 0)
                    box(sx + normal[0] * 0.005, sy + normal[1] * 0.005, 0.001,
                        ww + 0.010, 0.018, 0.003, rot=math.atan2(tangent[1], tangent[0]))
    f.finish()


def roof(w, d, z, rise, quad, hip=False):
    # Small physical eaves conceal all building interiors and show a crisp edge.
    box(0, 0, z - 0.004, w + 0.009, d + 0.009, 0.004, quad=1)
    if hip:
        atlas_part(A.hip_roof(0, 0, z, w, d, rise, "city_atlas", overhang=0.006), quad)
        ridge = max(0.010, abs(w - d) * 0.83)
        box(0, 0, z + rise - 0.003, ridge if w >= d else 0.006,
            0.006 if w >= d else ridge, 0.006, quad=quad)
    else:
        ob = A.gable_roof(0, 0, z, w, d, rise, "city_atlas", overhang=0.006)
        atlas_part(ob, quad)
        # Both gable faces are plaster. Assign UVs per face rather than extra material.
        uv = ob.data.uv_layers.active
        for poly in ob.data.polygons:
            if abs(poly.normal.y) > 0.9:
                for i in poly.loop_indices:
                    p = ob.data.vertices[ob.data.loops[i].vertex_index].co
                    uv.data[i].uv = atlas_uv(0, (p.x + w / 2 + 0.006) / (w + 0.012), max(0, (p.z - z) / rise))
        box(0, 0, z + rise - 0.003, 0.006, d + 0.015, 0.006, quad=quad)


def chimney(w, d, h, rise, rng, quad=1):
    x, y = w * 0.22, d * rng.uniform(-0.24, 0.28)
    base = h + rise * 0.33
    box(x, y, base, 0.012, 0.014, 0.024, quad=quad, bevel=0.0008)
    box(x, y, base + 0.024, 0.017, 0.019, 0.003, quad=1)
    box(x, y, base + 0.027, 0.007, 0.009, 0.0008, material="city_glass")


def place_parts(start, x, y, rot):
    matrix = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rot, 4, "Z")
    for ob in A._parts[start:]:
        ob.data.transform(matrix)


def house(style, x, y, w, d, floors, rng, index, rot):
    start = len(A._parts)
    h = (0.065 if floors == 1 else 0.108) * rng.uniform(0.93, 1.10)
    wall_quad = 1 if style == "east" and index % 3 == 0 else 0
    timber = style == "nordic" and index % 3 != 0
    box(0, 0, 0, w + 0.002, d + 0.002, 0.006, quad=1, bevel=0.0007)
    building_facades(w, d, h, floors, wall_quad, timber, shop=index % 5 == 0)
    # Floor strings and corner pilasters avoid facades reading as cardboard cubes.
    if floors > 1:
        box(0, 0, h * 0.52, w + 0.004, d + 0.004, 0.003, quad=1)
    for xx in (-w / 2, w / 2):
        for yy in (-d / 2, d / 2):
            box(xx, yy, 0.006, 0.0035, 0.0035, h - 0.006, quad=1)
    rise = rng.uniform(0.030, 0.041) * (1.28 if style == "nordic" else 1)
    roof_quad = 2 if style == "orient" or (style == "west" and index % 3 != 0) else 3
    hip = style == "orient" or index % 4 == 1
    roof(w, d, h, rise, roof_quad, hip)
    chimney(w, d, h, rise, rng, wall_quad)
    if index % 4 == 0 and not hip:
        # A little plaster dormer with an actual dark window on the front.
        dx, dy, dz = -w * 0.18, -d * 0.19, h + rise * 0.24
        box(dx, dy, dz, 0.032, 0.029, 0.022, quad=0)
        atlas_part(A.gable_roof(dx, dy, dz + 0.022, 0.036, 0.033, 0.015, "city_atlas", overhang=0.003), roof_quad)
        box(dx, dy - 0.015, dz + 0.005, 0.018, 0.001, 0.013, material="city_glass")
    if style == "orient" and floors == 2 and index % 3 == 0:
        # Timber-supported Ottoman upper-storey bay, not a huge fantasy minaret.
        box(0, -d / 2 - 0.014, h * 0.57, w * 0.48, 0.031, h * 0.36, quad=0)
        for xx in (-w * 0.16, 0, w * 0.16):
            box(xx, -d / 2 - 0.030, h * 0.63, 0.017, 0.0014, h * 0.20, material="city_glass")
            box(xx, -d / 2 - 0.014, h * 0.43, 0.0025, 0.025, h * 0.15, material="city_timber")
        box(0, -d / 2 - 0.014, h * 0.93, w * 0.51, 0.036, 0.004, quad=2)
    if index % 5 == 0:
        # Restrained canvas-like shop canopy; no modern signage or unreadable lettering.
        box(w * 0.20, -d / 2 - 0.012, 0.049, w * 0.40, 0.031, 0.003, material="city_timber")
    paint_parts(start, style, index)
    place_parts(start, x, y, rot)


def clock_face(x, y, z):
    box(x, y, z - 0.012, 0.026, 0.0012, 0.026, quad=1)
    box(x, y - 0.001, z - 0.001, 0.009, 0.001, 0.0018, material="city_glass")
    box(x, y - 0.0011, z - 0.001, 0.0018, 0.001, 0.009, material="city_glass")


def civic(style, x, y, rot=0):
    start = len(A._parts)
    w, d, h = 0.235, 0.124, 0.125
    if style == "orient":
        # Compact Ottoman civic/bath complex and low domed hall around a forecourt.
        w, d, h = 0.200, 0.142, 0.10
    box(0, 0, 0, w + 0.012, d + 0.012, 0.008, quad=1, bevel=0.001)
    building_facades(w, d, h, 2, 1 if style == "east" else 0, timber=style == "nordic")
    box(0, 0, h - 0.009, w + 0.010, d + 0.010, 0.009, quad=1)
    for xx in (-w / 2 + 0.009, -w / 4, w / 4, w / 2 - 0.009):
        box(xx, -d / 2 - 0.0015, 0.010, 0.008, 0.005, h - 0.018, quad=1, bevel=0.0006)
    box(0, -d / 2 - 0.025, 0.005, 0.074, 0.045, 0.005, quad=1)
    box(0, -d / 2 - 0.016, 0.010, 0.064, 0.025, 0.005, quad=1)
    if style == "orient":
        # A single lead-covered shallow dome, plus a deliberately low ventilation lantern.
        box(0, 0, h, w + 0.008, d + 0.008, 0.009, quad=1)
        cylinder = A.cylinder(0, 0.013, h + 0.009, 0.060, 0.016, "city_atlas", 20)
        atlas_part(cylinder, 1)
        A.dome(0, 0.013, h + 0.025, 0.061, "city_metal", seg=20, height=0.75)
        A.lathe(0, 0.013, h + 0.071, [(0.005, 0), (0, 0.018)], "city_metal", 8)
        # Shallow entrance arcade and a low stone courtyard wall.
        for xx in (-0.068, 0, 0.068):
            atlas_part(A.cylinder(xx, -d / 2 - 0.015, 0.015, 0.0035, 0.048, "city_atlas", 8), 1)
        box(0, -d / 2 - 0.015, 0.063, 0.161, 0.031, 0.007, quad=1)
    else:
        roof(w, d, h, 0.042 if style != "nordic" else 0.058, 3, True)
        tower_x, tower_y = -0.020, 0.019
        tw, th = 0.048, 0.204 if style != "nordic" else 0.224
        box(tower_x, tower_y, h - 0.01, tw, tw, th - h + 0.010,
            quad=1 if style == "east" else 0, material="city_brick" if style == "nordic" else None, bevel=0.001)
        box(tower_x, tower_y, th - 0.006, tw + 0.007, tw + 0.007, 0.006, quad=1)
        clock_face(tower_x, tower_y - tw / 2 - 0.001, th - 0.022)
        if style == "east":
            # Low eastern cupola, muted aged copper instead of enormous golden onions.
            A.lathe(tower_x, tower_y, th, [(0.025, 0), (0.021, 0.009), (0.026, 0.023),
                                        (0.023, 0.034), (0.012, 0.044), (0, 0.052)], "city_metal", 16)
        else:
            atlas_part(A.hip_roof(tower_x, tower_y, th, tw + 0.009, tw + 0.009,
                                 0.029 if style == "west" else 0.048, "city_atlas", overhang=0), 3)
        chimney(w, d, h, 0.042, random.Random(33))
    paint_parts(start, style, 17)
    place_parts(start, x, y, rot)


def street(points, width):
    # No base: each ribbon occupies only the physical road footprint.
    normals = []
    for i in range(len(points)):
        previous, following = Vector(points[max(i - 1, 0)]), Vector(points[min(i + 1, len(points) - 1)])
        tangent = (following - previous).normalized()
        normals.append(Vector((-tangent.y, tangent.x)))
    outline = [Vector(p) + n * width / 2 for p, n in zip(points, normals)]
    outline += [Vector(p) - n * width / 2 for p, n in zip(points[::-1], normals[::-1])]
    A.poly_prism([(p.x, p.y) for p in outline], 0, 0.0013, "city_pavement")
    # A thin physical curb, broken naturally where other streets intersect it.
    for side in (-1, 1):
        for i in range(len(points) - 1):
            a, b = Vector(points[i]) + normals[i] * width * side / 2, Vector(points[i + 1]) + normals[i + 1] * width * side / 2
            mid, delta = (a + b) / 2, b - a
            box(mid.x, mid.y, 0.0012, delta.length, 0.003, 0.0022,
                rot=math.atan2(delta.y, delta.x))


def courtyard(x, y, w, d):
    # Separate little yards with holes/gaps between blocks; never a whole district slab.
    box(x, y, 0, w, d, 0.0015, material="city_pavement")
    box(x, y + d / 2, 0.0015, w, 0.005, 0.014, quad=1)
    box(x - w / 2, y, 0.0015, 0.005, d, 0.014, quad=1)
    # A hand pump / well and two bench-like street details.
    atlas_part(A.cylinder(x + w * 0.23, y, 0.0015, 0.012, 0.009, "city_atlas", 12), 1)
    box(x + w * 0.23, y, 0.0105, 0.003, 0.003, 0.014, material="city_metal")
    box(x + w * 0.27, y, 0.021, 0.009, 0.003, 0.002, material="city_metal")
    for xx in (-w * 0.23, w * 0.05):
        box(x + xx, y + d * 0.30, 0.007, 0.024, 0.008, 0.003, material="city_timber")


LAYOUT = [
    (-0.338, -0.135, 0.145, 0.128, 2, -0.05),
    (-0.339, -0.298, 0.135, 0.122, 1, 0.06),
    (-0.157, -0.140, 0.136, 0.120, 2, 0.10),
    (-0.151, -0.304, 0.118, 0.107, 1, -0.08),
    (-0.340, 0.156, 0.153, 0.121, 2, 0.04),
    (-0.312, 0.304, 0.135, 0.111, 1, -0.14),
    (-0.137, 0.238, 0.125, 0.120, 2, -0.05),
    (0.122, -0.148, 0.123, 0.119, 2, -0.08),
    (0.122, -0.308, 0.126, 0.117, 1, 0.07),
    (0.302, -0.268, 0.151, 0.119, 2, 0.12),
    (0.354, -0.113, 0.125, 0.137, 1, 0.03),
    (0.353, 0.145, 0.128, 0.125, 2, -0.10),
    (0.310, 0.309, 0.134, 0.107, 1, 0.16),
]


def build(style, variant):
    rng = random.Random(4701 + STYLES.index(style) * 100 + variant * 7)
    A._parts.clear()
    # Uneven old-town spine and a cross lane; outer ends are blunt road ends, not a base.
    street([(-0.456, 0.040), (-0.280, 0.018), (-0.094, 0.001),
            (0.083, 0.014), (0.276, 0.040), (0.465, 0.012)], 0.042)
    street([(-0.048, -0.394), (-0.044, -0.190), (-0.055, 0.008),
            (-0.046, 0.187), (-0.014, 0.389)], 0.036)
    street([(-0.422, -0.218), (-0.240, -0.226), (-0.045, -0.223)], 0.018)
    street([(0.101, -0.382), (0.226, -0.225), (0.224, -0.007)], 0.019)
    street([(0.102, 0.249), (0.274, 0.245), (0.430, 0.246)], 0.016)
    for i, (x, y, w, d, floors, rot) in enumerate(LAYOUT):
        if variant:
            x, y = -x, y + rng.uniform(-0.012, 0.012)
            w, d = w * rng.uniform(0.94, 1.05), d * rng.uniform(0.94, 1.04)
            rot = -rot + rng.uniform(-0.03, 0.03)
            floors = 2 if i in (1, 5, 12) else floors
        house(style, x, y, w, d, floors, rng, i, rot)
    # Civic forecourt: scattered courtyards keep the silhouette irregular and human.
    civic(style, -0.128 if variant else 0.128, 0.150, -0.035 if variant else 0.035)
    courtyard(-0.253 if variant else 0.253, 0.158, 0.057, 0.087)
    courtyard(0.242 if variant else -0.242, -0.302, 0.040, 0.103)
    courtyard(-0.142 if variant else 0.142, -0.061, 0.095, 0.034)
    # Every primitive has the same colour layer, including untinted streets/yards.
    for part in A._parts:
        if part.data.color_attributes.get("CityTint") is None:
            layer = part.data.color_attributes.new(name="CityTint", type="FLOAT_COLOR", domain="CORNER")
            for corner in layer.data:
                corner.color = (1, 1, 1, 1)
            part.data.color_attributes.active_color_index = 0
            part.data.color_attributes.render_color_index = 0
    bpy.ops.object.select_all(action="DESELECT")
    for ob in A._parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = A._parts[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = f"city_{style}_{variant}"
    # Export one deterministic indexed mesh, with recalculated outward normals.
    ob.data.validate(clean_customdata=False)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0000001)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    corners = [v.co.copy() for v in ob.data.vertices]
    lo = Vector(tuple(min(p[j] for p in corners) for j in range(3)))
    hi = Vector(tuple(max(p[j] for p in corners) for j in range(3)))
    width, cx, cy = hi.x - lo.x, (hi.x + lo.x) / 2, (hi.y + lo.y) / 2
    for v in ob.data.vertices:
        v.co = Vector(((v.co.x - cx) / width, (v.co.y - cy) / width, (v.co.z - lo.z) / width))
    ob.data.update()
    # glTF may merge material slots with identical names. Remove duplicate slots here too.
    unique, indices = [], {}
    for i, material in enumerate(ob.data.materials):
        if material.name not in indices:
            indices[material.name] = len(unique)
            unique.append(material)
    new_indices = [indices[ob.data.materials[p.material_index].name] for p in ob.data.polygons]
    ob.data.materials.clear()
    for material in unique:
        ob.data.materials.append(material)
    for p, index in zip(ob.data.polygons, new_indices):
        p.material_index = index
    ob.data.calc_loop_triangles()
    ob["architectural_style"] = style
    ob["layout_variant"] = variant
    ob["buildings"] = 14
    ob["base"] = "No plinth; road and courtyard footprints only"
    ob["geometry"] = "Actual facade openings and recessed panes, one joined district mesh"
    A._parts.clear()
    return ob


def render_previews(built):
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1100
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Soft studio daylight")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.49, 0.55, 0.59, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.32
    scene.world = world
    rig = bpy.data.collections.new("Preview rig — not exported")
    scene.collection.children.link(rig)

    def light(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
        ob = bpy.data.objects.new(name, data)
        ob.location = location
        ob.rotation_euler = (Vector((0, 0, 0.02)) - ob.location).to_track_quat("-Z", "Y").to_euler()
        rig.objects.link(ob)

    light("Warm broad key", (-1.7, -2.2, 3), 240, 2.1, (1, 0.92, 0.82))
    light("Cool sky fill", (2, 0.3, 2), 75, 2.5, (0.77, 0.86, 1))
    floor_material = bpy.data.materials.new("Preview ground | not an asset")
    floor_material.use_nodes = True
    floor_material.diffuse_color = (0.115, 0.145, 0.085, 1)
    floor_material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.115, 0.145, 0.085, 1)
    floor_material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.0015))
    ground = bpy.context.object
    ground.name = "Preview floor — never exported"
    ground.data.materials.append(floor_material)
    for coll in list(ground.users_collection):
        coll.objects.unlink(ground)
    rig.objects.link(ground)
    camera = bpy.data.objects.new("Preview camera", bpy.data.cameras.new("Preview camera"))
    rig.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.28
    camera.location = (1.20, -1.62, 1.65)
    camera.rotation_euler = (Vector((0, 0, 0.06)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    for name, ob in built.items():
        for other in built.values():
            other.hide_render = other is not ob
        scene.render.filepath = str(PREVIEWS / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        if name in ("city_orient_0", "city_west_0"):
            # Honest second angle at the game's nearly overhead camera.
            camera.location = (0.28, -0.38, 2)
            camera.rotation_euler = (Vector((0, 0, 0.02)) - camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(PREVIEWS / f"{name}_overhead.png")
            bpy.ops.render.render(write_still=True)
            camera.location = (1.20, -1.62, 1.65)
            camera.rotation_euler = (Vector((0, 0, 0.06)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    # The gallery in the source stays editable, including its lighting rig.
    for i, ob in enumerate(built.values()):
        ob.hide_render = False
        ob.location = ((i % 4 - 1.5) * 1.24, (i // 4 - 0.5) * 1.15, 0)
    camera.location = (3, -5, 6)
    camera.rotation_euler = (Vector((0, 0, 0.03)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = 5.35
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
    material_setup()
    built, metrics = {}, {}
    for style in STYLES:
        for variant in (0, 1):
            ob = build(style, variant)
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            # glTF is triangle-based anyway. Triangulate only the evaluated export
            # so n-gon road footprints get reliable native tangent-space normals;
            # keep the editable mesh and all geometric dimensions unchanged.
            export_tri = ob.modifiers.new("Export tangent triangulation", "TRIANGULATE")
            export_tri.quad_method = "FIXED"
            export_tri.ngon_method = "BEAUTY"
            bpy.ops.export_scene.gltf(filepath=str(OUT / f"{ob.name}.gltf"), use_selection=True,
                                      export_format="GLTF_SEPARATE", export_texture_dir="textures",
                                      export_apply=True, export_yup=True, export_image_format="AUTO",
                                      export_materials="EXPORT", export_cameras=False, export_lights=False,
                                      export_tangents=True)
            ob.modifiers.remove(export_tri)
            built[ob.name] = ob
            metrics[ob.name] = {"vertices": len(ob.data.vertices), "triangles": len(ob.data.loop_triangles),
                                "materials": len(ob.data.materials), "width": round(ob.dimensions.x, 4),
                                "depth": round(ob.dimensions.y, 4), "height": round(ob.dimensions.z, 4), "buildings": 14,
                                "vertex_colors": "CityTint / native COLOR_0", "normal_texture": "textures/material_atlas_normal.png"}
            print("[mini_city]", ob.name, json.dumps(metrics[ob.name]))
    if args.render:
        render_previews(built)
    else:
        for i, ob in enumerate(built.values()):
            ob.location = ((i % 4 - 1.5) * 1.24, (i // 4 - 0.5) * 1.15, 0)
    # Factory-startup has no .blend filepath yet. Anchor image paths explicitly
    # to the eventual source folder, then keep them relative when saving.
    for image in bpy.data.images:
        if image.source == "FILE" and image.filepath:
            image.filepath = bpy.path.relpath(bpy.path.abspath(image.filepath), start=str(SOURCE.parent))
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), relative_remap=False)
    (OUT / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print("[mini_city] Editable source:", SOURCE)


if __name__ == "__main__":
    main()
