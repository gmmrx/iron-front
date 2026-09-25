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

func _ready() -> void:
	var meshes := _load_meshes()
	if meshes.is_empty():
		push_warning("Ağaç modelleri yüklenemedi")
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("height_tex", map.height_texture)
	mat.set_shader_parameter("map_size", map.map_size)
	mat.set_shader_parameter("height_scale", MapView3D.HEIGHT_SCALE)
	var data := FileAccess.get_file_as_bytes(TREES_PATH).to_float32_array()
	var airbases: Array[Vector2] = []
	for sid: int in map.airbase_sites:
		airbases.append(map.airbase_sites[sid][0])
	var groups := {}
	var i := 0
	while i < data.size():
		var p := Vector2(data[i], data[i + 1])
		var sc := data[i + 2] * TREE_SCALE
		var kind := int(data[i + 3])
		i += 4
		var skip := false
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
