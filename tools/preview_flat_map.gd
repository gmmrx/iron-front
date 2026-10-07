extends SceneTree
## Actual terrain shader/rasters, with existing 3D figures placed on the flat surface.
func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	root.get_node("Game").new_game()
	var world: Node = root.get_node("World")
	world.start_game("TUR")
	var map: Node3D = load("res://game/map/map_view_3d.gd").new()
	root.add_child(map)
	if not map.is_built: await map.built
	var debug_ground := "--debug-ground" in OS.get_cmdline_user_args()
	if debug_ground:
		var debug_material := StandardMaterial3D.new()
		debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debug_material.albedo_color = Color("56784a")
		for child in map.get_children():
			if child is MeshInstance3D: child.material_override = debug_material
	var camera: Camera3D = load("res://game/map/map_camera_3d.gd").new()
	camera.map = map
	camera.map_size = map.map_size
	camera.edge_pan_enabled = false
	root.add_child(camera)
	camera.make_current()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("5a6875")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	root.add_child(sun)
	var home: Vector2 = world.capital_position("TUR")
	var figures: Script = load("res://game/map/unit_figures.gd")
	var demos: Array[Node3D] = []
	for spec: Array in [["soldier", Vector2(-16, 4)], ["tank", Vector2(16, 4)]]:
		var fig: Node3D = figures.make(world.player(), spec[0])
		fig.scale = Vector3.ONE * 10.0
		fig.position = Vector3(home.x + spec[1].x, map.height_at(home), home.y + spec[1].y)
		map.add_child(fig)
		demos.append(fig)
	var method := RenderingServer.get_current_rendering_method()
	var folder := "res://art/previews/flat_map/" + method
	if debug_ground: folder += "_debug"
	DirAccess.make_dir_recursive_absolute(folder)
	for shot: Array in [["political_close", 0, 150.0], ["terrain_close", 1, 150.0], ["political_region", 0, 1400.0]]:
		map.set_map_mode(shot[1])
		camera.focus_on(home, shot[2])
		map.set_camera_distance(camera.distance)
		for fig in demos: fig.visible = camera.distance < 380.0
		# Compatibility can compile this large terrain shader asynchronously; wait past first-use warmup.
		for frame in 120: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/" + shot[0] + ".png")
		print("FLAT_MAP ", shot[0], " ground=", map.height_at(home), " chunk triangles=", map._terrain_grid.flat_mesh(Vector2(1024, 1024)).get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3)
	map.free()
	camera.free()
	sun.free()
	env.free()
	await process_frame
	quit()
