extends "res://tests/test_case.gd"
## The map surface is flat geometry; elevation remains only as painted terrain data.

const GRID := preload("res://game/map/terrain_grid.gd")

func _map_with_relief() -> MapView3D:
	var map := MapView3D.new()
	map.map_size = Vector2(128, 64)
	map._height_image = Image.create(3, 3, false, Image.FORMAT_RF)
	for y in 3:
		for x in 3:
			map._height_image.set_pixel(x, y, Color(float(x * 1600 + y * 450 - 200), 0, 0))
	return map

func test_ground_height_is_flat_independent_of_relief_and_wrap() -> void:
	var map := _map_with_relief()
	var was_wrapping: bool = World.wraps
	var samples: Array[Vector2] = [Vector2.ZERO, Vector2(32, 16), Vector2(90, 48),
		Vector2(128, 64), Vector2(-128, -64), Vector2(384, 32), Vector2(100000, -100000)]
	for wrapping: bool in [false, true]:
		World.wraps = wrapping
		for p: Vector2 in samples:
			eq(map.height_at(p), 0.0, "all model, road and picking positions use the flat ground")
	World.wraps = was_wrapping
	gt(map._height_image.get_pixel(2, 2).r, 3000.0, "raw mountain elevation was not removed")
	map.free()

func test_model_site_flattening_preserves_painted_relief() -> void:
	var map := _map_with_relief()
	var before := map._height_image.get_data()
	map.flatten_site(Vector2(64, 32), 20.0)
	eq(map._height_image.get_data(), before, "construction does not erase painted mountain detail")
	map._flatten_disc(Vector2(1, 1), 1.0, 2.0, 1.0)
	eq(map._height_image.get_data(), before, "city and airbase flattening leave elevation texture intact")
	check(not map._height_dirty, "flat sites do not request an unnecessary relief texture upload")
	map.free()

func test_flat_chunk_mesh_has_two_triangles_and_preserves_footprint() -> void:
	var grid := GRID.new()
	for footprint: Vector2 in [Vector2(1024, 1024), Vector2(1024, 944), Vector2(128, 64)]:
		var mesh: PlaneMesh = grid.flat_mesh(footprint)
		eq(mesh.size, footprint, "flat chunk keeps its full or partial map footprint")
		eq(mesh.subdivide_width, 0, "no horizontal relief subdivisions")
		eq(mesh.subdivide_depth, 0, "no vertical relief subdivisions")
		var arrays := mesh.get_mesh_arrays()
		eq(arrays[Mesh.ARRAY_INDEX].size() / 3, 2, "each flat chunk is exactly two triangles")
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			eq(p.y, 0.0, "terrain vertex lies on the common ground plane")
			minimum = minimum.min(Vector2(p.x, p.z))
			maximum = maximum.max(Vector2(p.x, p.z))
		eq(maximum - minimum, footprint, "vertex footprint spans the chunk without gaps")
		check(mesh == grid.flat_mesh(footprint), "equal chunk sizes share the cached flat mesh")
	check(grid.flat_mesh(Vector2(1024, 1024)) != grid.flat_mesh(Vector2(1024, 944)),
		"partial edge chunks do not reuse a mismatched footprint")

func test_geometric_and_painted_height_scales_are_separate() -> void:
	eq(MapView3D.HEIGHT_SCALE, 0.0, "model and road GPU conforming use zero terrain displacement")
	gt(MapView3D.RELIEF_SCALE, 0.0, "mountain, forest and snow shading retain nonzero relief data")
