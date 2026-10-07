extends RefCounted
## Joined Blender miniatures. Keep imported hierarchy transforms, PBR materials and LODs intact.

const DIRECTORY := "res://assets/models/strait/"
## Rejected civilian studies remain on disk, but cannot enter the live map library.
const KINDS := ["little_belt_span", "little_belt_end"]
var _cache := {}

func model(kind: String) -> Dictionary:
	if not kind in KINDS:
		return {}
	if not _cache.has(kind):
		var loaded := _load_model(DIRECTORY + kind + ".gltf")
		# Do not cache absent exports: the library can be populated while the editor is open.
		if loaded.is_empty():
			return {}
		_cache[kind] = loaded
	return _cache[kind]

func _load_model(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var node: MeshInstance3D = meshes[0] if not meshes.is_empty() else null
	var mesh: Mesh = node.mesh if node != null else null
	var imported := _scene_transform(node)
	scene.free()
	if mesh == null:
		return {}
	var imported_bounds: AABB = imported * mesh.get_aabb()
	var length := maxf(imported_bounds.size.x, 0.001)
	var normalization := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / length), Vector3.ZERO)
	var normalized := normalization * imported
	return {
		"mesh": mesh,
		"path": path,
		"imported_transform": imported,
		"imported_bounds": imported_bounds,
		"transform": normalized,
		"bounds": normalized * mesh.get_aabb(),
		"length": length,
		"normalization": 1.0 / length,
	}

func _scene_transform(node: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current != null:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform
