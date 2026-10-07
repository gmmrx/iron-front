extends "res://tests/test_case.gd"
## Run with a real renderer: --path . -s tests/run.gd -- --file=test_render_lod
const GRID := preload("res://game/map/terrain_grid.gd")

func test_terrain_grids_and_hysteresis() -> void:
	var grid := GRID.new()
	var meshes := grid.meshes(Vector2(1024, 1024))
	var expected := [131072, 32768, 8192, 2048]
	for i in meshes.size():
		var mesh: PlaneMesh = meshes[i]
		eq(mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3, expected[i], "terrain triangles LOD %d" % i)
		eq(mesh.size, Vector2(1024, 1024), "LOD preserves chunk footprint")
		check(mesh == grid.meshes(Vector2(1024, 1024))[i], "chunks share cached mesh")
		var edge: PlaneMesh = grid.meshes(Vector2(1024, 944))[i]
		eq(edge.subdivide_width, mesh.subdivide_width, "partial chunk shares horizontal edge sampling")
	eq(GRID.level_for(600), 0, "close detail unchanged")
	eq(GRID.level_for(1600), 1, "regional LOD")
	eq(GRID.level_for(2800), 2, "far LOD")
	eq(GRID.level_for(4200), 3, "strategic LOD")
	eq(GRID.level_for(3950, 3), 3, "threshold jitter does not change mesh")
	eq(GRID.level_for(600, 3), 0, "zoom in restores full detail")

func test_regional_zoom_cap() -> void:
	var camera := MapCamera3D.new()
	Engine.get_main_loop().root.add_child(camera)
	camera.edge_pan_enabled = false
	camera.map_size = Vector2(16384, 8112)
	for vp: Vector2 in [Vector2(1920, 1080), Vector2(3440, 1440), Vector2(900, 1400)]:
		camera.distance = 14000
		camera._target_distance = 14000
		camera._update_max_dist(vp)
		check(camera.MAX_DIST <= 5200, "aspect ratio cannot bypass zoom cap")
		check(camera.distance <= camera.MAX_DIST and camera._target_distance <= camera.MAX_DIST, "both actual and target clamped")
	camera.focus_on(Vector2(8000, 4000), 14000)
	check(camera.distance <= 5200, "scripted focus obeys cap")
	camera.zoom_at(Vector2(500, 500), -100)
	check(camera._target_distance <= 5200, "wheel obeys cap")
	camera.map_size = Vector2(1000, 1000)
	camera._update_max_dist(Vector2(1920, 1080))
	lt(camera.MAX_DIST, 5200, "small map retains fit constraint")
	camera.free()

func _check_lods(mesh: ArrayMesh, label: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var base: int = arrays[Mesh.ARRAY_INDEX].size()
	var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var lods: Array = surface.get("lods", [])
	if not check(not lods.is_empty(), label + ": LODs survived mesh split (requires real renderer)"):
		return
	var smallest := base
	for lod: Dictionary in lods:
		var indices := PlaneModel._indices(lod["index_data"], count > 65535)
		check(indices.size() > 0 and indices.size() % 3 == 0, label + ": non-empty triangle list")
		check(indices.size() <= base, label + ": LOD never adds triangles")
		var valid := true
		for index in indices:
			if index < 0 or index >= count:
				valid = false
		check(valid, label + ": all indices in vertex range")
		gt(float(lod["edge_length"]), 0, label + ": positive screen-space error")
		smallest = mini(smallest, indices.size())
	lt(smallest, base / 2, label + ": useful reduction")
	print("LOD ", label, " triangles=", base / 3, " -> ", smallest / 3, " levels=", lods.size())

func test_soldier_tank_and_plane_lods() -> void:
	if DisplayServer.get_name() == "headless":
		warn("LOD GPU surface checks require a real renderer; run without --headless")
		return
	for kind: String in ["soldier", "tank"]:
		var prepared := UnitFigures._prepare(kind)
		_check_lods(prepared["top"], kind + " top")
		_check_lods(prepared["base"], kind + " base")
	_check_lods(PlaneModel.body(), "plane body")
	_check_lods(PlaneModel.prop(), "plane propeller")
	var full := PlaneModel.batch_mesh("body", 100, 1080)
	var medium := PlaneModel.batch_mesh("body", 250, 1080)
	var far_mesh := PlaneModel.batch_mesh("body", 600, 1080)
	check(full == PlaneModel.body(), "batch keeps full close model")
	lt(medium.surface_get_array_index_len(0), full.surface_get_array_index_len(0), "batch medium reduction")
	lt(far_mesh.surface_get_array_index_len(0), medium.surface_get_array_index_len(0), "batch far reduction")
	check(far_mesh == PlaneModel.batch_mesh("body", 650, 1080), "batch mesh cached")
	check(full == PlaneModel.batch_mesh("body", 250, 2160), "high resolution retains more detail")
