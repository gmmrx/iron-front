extends "res://tests/test_case.gd"

const MODELS := preload("res://game/map/strait_models.gd")
const PROBE := preload("res://tests/map_probe.gd")

class CoastMap extends MapView3D:
	func province_at(p: Vector2) -> int:
		return PROBE.province_at(p)

func _layer() -> StraitLayer:
	var layer := StraitLayer.new()
	layer.map = CoastMap.new()
	return layer

func _release(layer: StraitLayer) -> void:
	var map := layer.map
	layer.free()
	map.free()

func test_real_blender_models_keep_axes_bounds_and_native_materials() -> void:
	var models := MODELS.new()
	for kind: String in MODELS.KINDS:
		var model := models.model(kind)
		if not check(not model.is_empty(), "Blender export exists: " + kind):
			continue
		var mesh: Mesh = model["mesh"]
		var bounds: AABB = model["bounds"]
		near(bounds.size.x, 1.0, 0.002, kind + " normalized +X dimension")
		check(mesh == models.model(kind)["mesh"], kind + " mesh is shared, not duplicated per crossing")
		check(model["path"].begins_with(MODELS.DIRECTORY), kind + " uses the new asset, not an old bridge fallback")
		check(model.has("imported_transform") and model.has("imported_bounds"), kind + " imported scene metadata preserved")
		gt(mesh.get_surface_count(), 0, kind + " has rendered surfaces")
		check(mesh.get_surface_count() <= 8, kind + " bounded material/draw-call count")
		var atlas_surfaces := 0
		var triangles := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			eq(arrays[Mesh.ARRAY_NORMAL].size(), vertices.size(), kind + " native geometric normals on every vertex")
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if check(material != null, kind + " native PBR material preserved"):
				if material.albedo_texture != null:
					atlas_surfaces += 1
					eq(arrays[Mesh.ARRAY_TEX_UV].size(), arrays[Mesh.ARRAY_VERTEX].size(), kind + " atlas surface UVs preserved")
					eq(arrays[Mesh.ARRAY_NORMAL].size(), arrays[Mesh.ARRAY_VERTEX].size(), kind + " imported surface normals preserved")
					check(material.normal_enabled and material.normal_texture != null, kind + " native normal atlas remains enabled")
		gt(atlas_surfaces, 0, kind + " has at least one preserved Blender atlas surface")
		gt(triangles, 1000, kind + " is genuinely modeled architectural/maritime geometry")
		check(triangles <= 20000, kind + " bounded triangle budget: %d" % triangles)
		near(bounds.position.x, 0.0, 0.03, "bridge starts at local +X zero")
		near(bounds.end.x, 1.0, 0.03, "bridge ends at local +X one")

func test_all_straits_have_true_opposite_banks_and_water_midpoints() -> void:
	PROBE.ensure()
	var layer := _layer()
	var original := World.straits.duplicate(true)
	for strait: Dictionary in World.straits:
		var actor: String = strait["name"]["en"]
		var a := Vector2(strait["from"][0], strait["from"][1])
		var b := Vector2(strait["to"][0], strait["to"][1])
		var banks := layer.bridge_banks(a, b, actor)
		if not check(not banks.is_empty(), actor + " has actual opposite banks"): continue
		var start: Vector2 = banks["start"]
		var finish: Vector2 = banks["end"]
		var direction := (finish - start).normalized()
		check(layer._bridge_bank_fits(start, -direction), actor + " first full end footprint on land")
		check(layer._bridge_bank_fits(finish, direction), actor + " opposite full end footprint on land")
		check(PROBE.is_water(start.lerp(finish, 0.5)), actor + " bridge midpoint is real water")
		near(banks["length_world"], start.distance_to(finish), 0.00001, actor + " actual world span metadata")
		ge(banks["search_world"], 12.0, actor + " minimum ray reach")
		check(banks["search_world"] <= 64.0, actor + " bounded adaptive search")
		if actor == "Little Belt":
			gt(absf(direction.x), absf(direction.y), "Little Belt crosses banks rather than following the channel")
		if actor == "Strait of Dover": gt(banks["search_world"], 12.0, "long crossing uses adaptive search")
		print("STRAIT_BRIDGE_BANKS ", actor, " ", start, " -> ", finish, " span=", banks["length_world"])
	eq(World.straits, original, "visual fitting leaves all gameplay coordinates and rules unchanged")
	_release(layer)

func test_bridge_only_runtime_is_grounded_with_fixed_world_scale() -> void:
	PROBE.ensure()
	var layer := _layer()
	layer._ready()
	eq(layer.bridge_endpoints.size(), World.straits.size(), "every crossing has a modeled bridge")
	eq(layer._models._cache.size(), 2, "only two shared bridge assets loaded")
	for kind: String in layer._models._cache:
		check(kind in ["little_belt_span", "little_belt_end"], "no port or civilian vessel loaded")
	var ends := {}
	var spans := {}
	for record: Dictionary in layer.placements:
		var placement: Transform3D = record["placement"]
		var node: MeshInstance3D = record["node"]
		var actor: String = record["actor"]
		check(record["kind"] in ["bridge_span", "bridge_end"], "runtime contains only bridge models")
		check(not record["path"].contains("terminal") and not record["path"].contains("ferry"), "no civilian model instantiated")
		check(node.material_override == null, "native PBR and atlas remain intact")
		eq(node.visibility_range_end, 380.0, "existing near-zoom visibility gate")
		near(placement.basis.z.length(), StraitLayer.BRIDGE_WIDTH_SCALE, 0.00001, actor + " fixed world width")
		near(placement.basis.y.length(), 1.0, 0.00001, actor + " fixed height scale")
		if record["kind"] == "bridge_span":
			spans[actor] = int(spans.get(actor, 0)) + 1
			check(placement.basis.x.length() <= StraitLayer.BRIDGE_SPAN_LENGTH + 0.00001, "bounded nominal segment length")
			continue
		ends[actor] = int(ends.get(actor, 0)) + 1
		near(placement.basis.x.length(), StraitLayer.BRIDGE_END_LENGTH, 0.00001, actor + " fixed end length")
		var grounded: AABB = node.transform * node.mesh.get_aabb()
		near(grounded.position.y, 0.0, 0.002, actor + " native end bottom touches ground")
		var total := 0
		var dry := 0
		for surface in node.mesh.get_surface_count():
			for vertex: Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var world := node.transform * vertex
				total += 1
				if layer._is_land(Vector2(world.x, world.z)): dry += 1
		ge(dry / float(total), 0.99, actor + " actual native end vertices are on land")
	for strait: Dictionary in World.straits:
		var actor: String = strait["name"]["en"]
		eq(ends.get(actor, 0), 2, actor + " exactly two land abutments")
		gt(spans.get(actor, 0), 0, actor + " actual bridge span exists")
	for child in layer.get_children():
		check(child is Label3D or child is MeshInstance3D, "no ship or terminal actor")
		if child is MeshInstance3D:
			check(child.mesh is not ImmediateMesh, "no dashed fallback route")
	_release(layer)

func test_bridge_labels_keep_normal_fixed_city_style() -> void:
	PROBE.ensure()
	var layer := _layer()
	layer._ready()
	var labels := 0
	for node in layer.get_children():
		if node is not Label3D: continue
		labels += 1
		eq(node.font_size, 20, "constant sans font size")
		eq(node.font.resource_path, "res://assets/fonts/BarlowCondensed-SemiBold.ttf", "normal city-compatible font")
		eq(node.scale, Vector3.ONE, "no zoom scale multiplier")
		near(node.pixel_size, 0.0005, 0.000000001, "constant screen-label pixel size")
		check(node.offset.length() >= 30.0, "one-time perpendicular offset clears the bridge")
		check(node.offset.y <= 0.0, "normal name stays below or beside the bridge")
		check(node.fixed_size and node.no_depth_test, "normal cartographic label contract")
	eq(labels, World.straits.size(), "one ordinary name per bridge")
	_release(layer)
