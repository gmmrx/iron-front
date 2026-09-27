class_name TreeLayer
extends Node3D
## Haritadaki 3D ağaçlar (data/map/trees.bin: x, z, ölçek, tür). Yalnız yakın zoom'da görünür.

const TREES_PATH := "res://data/map/trees.bin"
const MODEL_PATH := "res://assets/models/trees.glb"
const SHADER := preload("res://assets/shaders/tree.gdshader")
const TREE_SCALE := 2.4
const CHUNK := 384.0
const VISIBLE_RANGE := 480.0

var map: MapView3D
var clear_zones: Array[Vector2] = []   ## ağaç konmayacak alanlar (sanayi parselleri)
var clear_radius := 3.8

func _ready() -> void:
	var meshes := _load_meshes()
	if meshes.is_empty():
		push_warning("Ağaç modelleri yüklenemedi")
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	UnitModels.compat_material(mat)
	mat.set_shader_parameter("height_tex", map.height_texture)
	mat.set_shader_parameter("map_size", map.map_size)
	mat.set_shader_parameter("height_scale", MapView3D.HEIGHT_SCALE)
	var data := FileAccess.get_file_as_bytes(TREES_PATH).to_float32_array()
	var airbases: Array[Vector2] = []
	for sid: int in map.airbase_sites:
		airbases.append(map.airbase_sites[sid][0])
	# temiz alanlar ızgaraya: her ağaç yalnız kendi ve komşu hücrelerine bakar
	var zone_cell := maxf(clear_radius * 2.0, 1.0)
	var zones := {}
	for z in clear_zones:
		var c := Vector2i(floori(z.x / zone_cell), floori(z.y / zone_cell))
		if not zones.has(c):
			zones[c] = []
		zones[c].append(z)
	var r2 := clear_radius * clear_radius
	var groups := {}
	var i := 0
	while i < data.size():
		var p := Vector2(data[i], data[i + 1])
		var sc := data[i + 2] * TREE_SCALE
		var kind := int(data[i + 3])
		i += 4
		var skip := false
		if not zones.is_empty():
			var zc := Vector2i(floori(p.x / zone_cell), floori(p.y / zone_cell))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					for z: Vector2 in zones.get(zc + Vector2i(dx, dy), []):
						if z.distance_squared_to(p) < r2:
							skip = true
		for a in airbases:
			if a.distance_squared_to(p) < 196.0:
				skip = true
				break
		if skip:
			continue
		var key := Vector3i(int(p.x / CHUNK), int(p.y / CHUNK), kind)
		if not groups.has(key):
			groups[key] = []
		var yaw := fposmod(p.x * 12.9898 + p.y * 78.233, TAU)
		groups[key].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(p.x, 0.0, p.y)))
	for key: Vector3i in groups:
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes.get(key.z, meshes.values()[0])
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
		# yükseklik GPU'da eklendiği için sınır kutusu elle genişletilir
		mm.custom_aabb = AABB(Vector3(key.x * CHUNK - 4, -2, key.y * CHUNK - 4), Vector3(CHUNK + 8, 90, CHUNK + 8))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = VISIBLE_RANGE
		mmi.visibility_range_end_margin = VISIBLE_RANGE * 0.15
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
	print("[trees] %d ağaç, %d parça" % [data.size() / 4, groups.size()])

func _load_meshes() -> Dictionary:
	var out := {}
	var scene: Node = (load(MODEL_PATH) as PackedScene).instantiate()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.name.begins_with("tree_"):
			out[int(n.name.substr(5))] = (n as MeshInstance3D).mesh
		stack.append_array(n.get_children())
	scene.free()
	return out
