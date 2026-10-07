extends Node3D
## Sparse atmospheric patches, independent of military discovery. Generated once;
## spatial batches let off-screen clouds be culled rather than filling the viewport.
const SHADER := preload("res://assets/shaders/ambient_clouds.gdshader")
const SEED := 19360901
const AREA_PER_CLOUD := 650000.0
const CHUNK := 2048.0
const MIN_GAP := 240.0
const HEIGHT := 140.0
var material: ShaderMaterial
var patches: Array[Dictionary] = []
var batches: Array[MultiMeshInstance3D] = []

static func layout(size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if size.x <= 0.0 or size.y <= 0.0: return out
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var count := clampi(roundi(size.x * size.y / AREA_PER_CLOUD), 1, 256)
	for attempt in count * 16:
		if out.size() >= count: break
		var center := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
		var fits := true
		for old: Dictionary in out:
			if center.distance_squared_to(old["position"]) < MIN_GAP * MIN_GAP:
				fits = false
				break
		if not fits: continue
		var width := rng.randf_range(160.0, 380.0)
		out.append({"position": center, "size": Vector2(width, width * rng.randf_range(0.45, 0.75)),
				"height": HEIGHT + rng.randf_range(-30.0, 32.0), "angle": rng.randf_range(-PI, PI),
				"custom": Color(rng.randf(), rng.randf(), rng.randf(), 1.0)})
	return out

func setup(size: Vector2, wrap: bool) -> void:
	patches = layout(size)
	material = ShaderMaterial.new()
	material.shader = SHADER
	UnitModels.compat_material(material)
	var groups := {}
	for patch: Dictionary in patches:
		var p: Vector2 = patch["position"]
		var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
		if not groups.has(key): groups[key] = []
		groups[key].append(patch)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for key: Vector2i in groups:
		_build_batch(key, groups[key], plane, 0.0)
		if wrap:
			if key.x <= 2: _build_batch(key, groups[key], plane, size.x)
			if key.x >= floori(size.x / CHUNK) - 3: _build_batch(key, groups[key], plane, -size.x)
	visible = false

func _build_batch(key: Vector2i, list: Array, plane: Mesh, offset: float) -> void:
	var origin := Vector3((key.x + 0.5) * CHUNK, HEIGHT, (key.y + 0.5) * CHUNK)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = plane
	mm.instance_count = list.size()
	for i in list.size():
		var patch: Dictionary = list[i]
		var p: Vector2 = patch["position"]
		var scale: Vector2 = patch["size"]
		var basis := Basis(Vector3.UP, patch["angle"]).scaled(Vector3(scale.x, 1.0, scale.y))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, patch["height"], p.y) - origin))
		mm.set_instance_custom_data(i, patch["custom"])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.position = origin + Vector3(offset, 0.0, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 24.0
	add_child(instance)
	batches.append(instance)

func set_camera_distance(distance: float) -> void:
	var amount := smoothstep(260.0, 650.0, distance) * 0.85
	material.set_shader_parameter("cloud_amount", amount)
	visible = amount > 0.003
