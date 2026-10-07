extends "res://tests/test_case.gd"
## Real exported district assets, not the legacy city-hall fallback.

const MODELS := preload("res://game/map/mini_city_models.gd")

func _city(style: String, variant: int) -> City:
	var c := City.new()
	c.style = style
	c.id = variant
	return c

func test_all_eight_districts_are_imported_and_grounded() -> void:
	var library := MODELS.new()
	for style: String in MODELS.STYLES:
		for variant in 2:
			var c := _city(style, variant)
			var model: Dictionary = library.model_for(c)
			var name := "%s_%d" % [style, variant]
			if not check(not model.is_empty(), name + " model exists"):
				continue
			if not check(not bool(model["legacy"]), name + " uses new city rather than fallback"):
				continue
			var mesh: Mesh = model["mesh"]
			var bounds := mesh.get_aabb()
			near(bounds.size.x, 1.0, 0.002, name + " normalized width")
			near(bounds.position.y, 0.0, 0.002, name + " bottom at ground")
			gt(bounds.size.y, 0.05, name + " real 3D buildings")
			lt(bounds.size.y, 0.6, name + " low urban silhouette")
			var packed := load(model["path"]) as PackedScene
			var scene := packed.instantiate()
			var instances := scene.find_children("*", "MeshInstance3D", true, false)
			eq(instances.size(), 1, name + " one joined mesh")
			if instances.size() == 1:
				var node := instances[0] as MeshInstance3D
				check(node.transform.is_equal_approx(Transform3D.IDENTITY), name + " exported transforms baked")
			scene.free()

func test_districts_keep_uv_materials_and_bounded_geometry() -> void:
	var library := MODELS.new()
	for style: String in MODELS.STYLES:
		for variant in 2:
			var model: Dictionary = library.model_for(_city(style, variant))
			if model.is_empty() or bool(model["legacy"]):
				fail("new district missing: %s_%d" % [style, variant])
				continue
			var mesh: Mesh = model["mesh"]
			ge(mesh.get_surface_count(), 2, "separate building/detail materials")
			le_surfaces(mesh.get_surface_count(), 8)
			var triangles := 0
			var atlas_found := false
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
				var material := mesh.surface_get_material(surface) as StandardMaterial3D
				if not check(material != null, "native PBR material on each surface"):
					continue
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				eq(colors.size(), vertices.size(), "native vertex tint for each vertex")
				# Godot can omit a multiply-by-white for untinted pavement surfaces.
				var has_tint := false
				for color: Color in colors:
					if not color.is_equal_approx(Color.WHITE):
						has_tint = true
						break
				if has_tint:
					check(material.vertex_color_use_as_albedo, "native vertex tint survives glTF import")
				if material.albedo_texture != null:
					atlas_found = true
					var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					eq(uv.size(), vertices.size(), "atlas surface has UV for every vertex")
					ge(material.albedo_texture.get_width(), 1024, "high resolution shared atlas")
					check(material.normal_enabled and material.normal_texture != null, "native PBR normal atlas survives glTF import")
			check(atlas_found, "district has its authored facade/roof atlas")
			gt(triangles, 1000, "district has actual modeled architectural detail")
			check(triangles <= 30000, "district triangle budget: %d" % triangles)

func le_surfaces(count: int, maximum: int) -> void:
	check(count <= maximum, "district draw-call budget: %d surfaces" % count)

func test_variants_share_cache_without_reactivating_old_city_layer() -> void:
	var library := MODELS.new()
	for style: String in MODELS.STYLES:
		var a: Dictionary = library.model_for(_city(style, 0))
		var b: Dictionary = library.model_for(_city(style, 1))
		if a.is_empty() or b.is_empty():
			fail("style variants missing: " + style)
			continue
		check(a["mesh"] != b["mesh"], "two district layouts per architectural style")
		check(a["mesh"] == library.model_for(_city(style, 2))["mesh"], "cities share cached district geometry")
	check(not CityLayer3D.SHOW_MODELS, "old large city/port/airbase layer stays disabled")
