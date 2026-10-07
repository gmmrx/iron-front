extends RefCounted
## Shared materials, lazy meshes; fixed world footprints, clipped to real land.
const SHADER := preload("res://assets/shaders/city_ground.gdshader")
const EARTH := preload("res://assets/models/textures/ground_dirt.png")
const PAVING := preload("res://assets/models/textures/city_paving.png")
const GROUND_Y := 0.001
const ROAD_Y := 0.003
const GRID := 12
const ROAD_STEP := 0.04
var _earth: ShaderMaterial
var _road: ShaderMaterial

func _materials() -> void:
	if _earth != null: return
	_earth = ShaderMaterial.new()
	_earth.shader = SHADER
	_earth.set_shader_parameter("ground_tex", EARTH)
	_earth.set_shader_parameter("tint", Color(0.88, 0.88, 0.80, 0.60))
	UnitModels.compat_material(_earth)
	_road = ShaderMaterial.new()
	_road.shader = SHADER
	_road.set_shader_parameter("ground_tex", PAVING)
	_road.set_shader_parameter("tint", Color(1.80, 1.75, 1.62, 0.82))
	_road.set_shader_parameter("road", true)
	UnitModels.compat_material(_road)

func build(map: MapView3D, center: Vector2, width: float, angle: float, city_id: int) -> MeshInstance3D:
	_materials()
	var mesh := ArrayMesh.new()
	var ground := _arrays()
	# Feathered compacted ground, not a circular stand or a solid city plinth.
	for y in GRID:
		for x in GRID:
			var a := Vector2(lerpf(-0.62, 0.62, float(x) / GRID), lerpf(-0.55, 0.55, float(y) / GRID))
			var b := a + Vector2(1.24, 1.10) / GRID
			var points := [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]
			var dry := true
			for q: Vector2 in points:
				if not _land(map, center + _rotate(q * width, angle)):
					dry = false
					break
			if not dry: continue
			var start: int = ground[Mesh.ARRAY_VERTEX].size()
			for q: Vector2 in points:
				var edge := maxf(absf(q.x) / 0.60, absf(q.y) / 0.53)
				var irregular := sin(q.x * 25.0 + city_id) * sin(q.y * 18.0) * 0.03
				var alpha := 1.0 - smoothstep(0.68, 1.0, edge + irregular)
				_vertex(ground, q * width, GROUND_Y, q * width / 0.8, Vector2.ZERO, alpha)
			ground[Mesh.ARRAY_INDEX].append_array([start, start + 2, start + 1, start, start + 3, start + 2])
	_add_surface(mesh, ground, _earth)
	var roads := _arrays()
	var paths := exit_paths(map, center, width, angle, city_id)
	for path: Dictionary in paths:
		_road_ribbon(roads, path["points"], path["width"])
	_add_surface(mesh, roads, _road)
	var node := MeshInstance3D.new()
	node.name = "CityGround_%d" % city_id
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.transform = Transform3D(Basis(Vector3.UP, angle), Vector3(center.x, 0.0, center.y))
	node.set_meta("exit_paths", paths)
	node.set_meta("city_id", city_id)
	return node

## The actual ends of the two streets in the Blender kit; Blender XY -> Godot XZ (-Y).
func exit_paths(map: MapView3D, center: Vector2, width: float, angle: float, city_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Solved from the exported POSITION buffer, not guessed from the source
	# district. Normalisation moves the original street endpoints slightly.
	var sockets := [Vector2(-0.496990, -0.044403), Vector2(0.496445, -0.014201), Vector2(-0.056901, 0.423730), Vector2(-0.020227, -0.420851)]
	var directions := [Vector2(-0.9923, -0.1240), Vector2(0.9892, 0.1466), Vector2(-0.0196, 0.9998), Vector2(0.1565, -0.9877)]
	for i in sockets.size():
		# Two main approaches; only larger districts get a short side lane.
		# Avoid giving every tiny town the same four-armed cross silhouette.
		if i >= 2 and (width < 3.0 or i != 2 + posmod(city_id, 2)):
			continue
		var heading: Vector2 = directions[i]
		var start: Vector2 = (sockets[i] - heading * 0.01) * width
		var length := width * (0.29 + float(posmod(city_id * 17 + i * 31, 23)) / 100.0)
		if i >= 2: length *= 0.65
		var bend := float(posmod(city_id + i * 7, 11) - 5) * 0.026
		var points := PackedVector2Array([start])
		var road_width := width * (0.045303 if i < 2 else 0.038831)
		var edge := Vector2(-heading.y, heading.x) * road_width * 0.66
		if not _land(map, center + _rotate(start, angle)) or not _land(map, center + _rotate(start + edge, angle)) or not _land(map, center + _rotate(start - edge, angle)):
			continue
		var steps := ceili(length / (width * ROAD_STEP))
		for j in range(1, steps + 1):
			var t := float(j) / steps
			var dir := heading.rotated(bend * t)
			var q := start + dir * length * t
			var side := Vector2(-dir.y, dir.x) * road_width * 0.66
			if not _land(map, center + _rotate(q, angle)) or not _land(map, center + _rotate(q + side, angle)) or not _land(map, center + _rotate(q - side, angle)):
				break
			points.append(q)
		if points.size() >= 4:
			out.append({"socket": i, "points": points, "width": road_width})
	return out

func _road_ribbon(arrays: Array, points: PackedVector2Array, width: float) -> void:
	var arc := 0.0
	var total := 0.0
	for i in range(1, points.size()): total += points[i].distance_to(points[i - 1])
	var start: int = arrays[Mesh.ARRAY_VERTEX].size()
	for i in points.size():
		if i > 0: arc += points[i].distance_to(points[i - 1])
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x) * width * 0.65
		for sign_value: float in [-1.0, 1.0]:
			_vertex(arrays, points[i] + side * sign_value, ROAD_Y,
					Vector2((sign_value + 1.0) * 0.5, arc / 0.55), Vector2(sign_value, arc / maxf(total, 0.001)), 1.0)
		if i > 0:
			var a := start + (i - 1) * 2
			arrays[Mesh.ARRAY_INDEX].append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])

func _arrays() -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	out[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	out[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	out[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	out[Mesh.ARRAY_COLOR] = PackedColorArray()
	out[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return out

func _vertex(arrays: Array, p: Vector2, height: float, uv: Vector2, uv2: Vector2, alpha: float) -> void:
	arrays[Mesh.ARRAY_VERTEX].append(Vector3(p.x, height, p.y))
	arrays[Mesh.ARRAY_NORMAL].append(Vector3.UP)
	arrays[Mesh.ARRAY_TEX_UV].append(uv)
	arrays[Mesh.ARRAY_TEX_UV2].append(uv2)
	arrays[Mesh.ARRAY_COLOR].append(Color(1.0, 1.0, 1.0, alpha))

func _add_surface(mesh: ArrayMesh, arrays: Array, material: Material) -> void:
	if arrays[Mesh.ARRAY_INDEX].is_empty(): return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

static func _rotate(p: Vector2, angle: float) -> Vector2:
	return p.rotated(-angle)

func _land(map: MapView3D, p: Vector2) -> bool:
	var province := World.province(map.province_at(p))
	return province != null and province.is_land()
