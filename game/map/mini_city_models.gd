extends RefCounted
## Haritadaki kompakt kent minyatürleri. Sekiz stil/varyant mesh'i ortak kullanılır;
## her şehir için geometri ya da malzeme kopyalanmaz. Şehir kimliği görünüşü sabit tutar.

const DIRECTORY := "res://assets/models/mini_city/"
const STYLES := ["west", "east", "orient", "nordic"]
var fallback_path := "res://assets/models/city-hall.glb"
var _cache := {}

static func source_path(style: String, city_id: int) -> String:
	var architecture: String = style if style in STYLES else "west"
	return DIRECTORY + "city_%s_%d.gltf" % [architecture, absi(city_id) % 2]

func model_for(c: City) -> Dictionary:
	var path := source_path(c.style, c.id)
	if not _cache.has(path):
		var model := _load_model(path, false)
		if model.is_empty():
			if not _cache.has(fallback_path):
				_cache[fallback_path] = _load_model(fallback_path, true)
			model = _cache[fallback_path]
		_cache[path] = model
	return _cache[path]

func _load_model(path: String, legacy: bool) -> Dictionary:
	if path.is_empty() or not ResourceLoader.exists(path):
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var node: MeshInstance3D = meshes[0] if not meshes.is_empty() else null
	var mesh: Mesh = node.mesh if node != null else null
	var transform := _scene_transform(node)
	scene.free()
	if mesh == null:
		return {}
	if legacy:
		# Eski belediye kaidesinin güçlü metal haritası gök yansıması olmayan haritada
		# siyaha dönüyordu. Yalnız yedek mesh'in her yüzeyini düzelt; yeni dokulara dokunma.
		mesh = mesh.duplicate() as Mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				var copy := material.duplicate() as StandardMaterial3D
				copy.metallic = 0.08
				mesh.surface_set_material(surface, copy)
	# Sahnenin içindeki dönüşüm (ör. içe aktarımdaki kök ölçek/dönüş) mesh'i tek
	# başına alınca kaybolmasın. Geometriyi yeniden üretmeden dönüşümü örneğe taşı:
	# malzeme, normal/tangent ve motorun içe aktardığı LOD'lar ortak mesh'te kalır.
	var bounds: AABB = transform * mesh.get_aabb()
	var center := bounds.get_center()
	transform.origin -= Vector3(center.x, 0.0, center.z)
	bounds = transform * mesh.get_aabb()
	var width := maxf(bounds.size.x, 0.001)
	var glass := -1                                   # pencere camı yüzeyi: gece yanar (DayNight.window_material)
	for surface in mesh.get_surface_count():
		var sm := mesh.surface_get_material(surface)
		if sm and sm.resource_name.contains("glass"):
			glass = surface
	return {
		"glass": glass,
		"mesh": mesh,
		"transform": transform,
		"bounds": bounds,
		"path": path,
		"legacy": legacy,
		"scale": 1.0 / width,
		"bottom": -bounds.position.y / width,
		"height": bounds.size.y / width,
		"footprint": maxf(bounds.size.x, bounds.size.z) / width * 0.5,
	}

func _scene_transform(node: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current != null:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform
