extends SceneTree
## Actual map, actual discovery mask; far / border / cloud interior / below, both renderers.
func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	root.get_node("Game").new_game()
	root.get_node("World").start_game("TUR")
	var map_script: Script = load("res://game/map/map_view_3d.gd")
	var map: Node3D = map_script.new()
	root.add_child(map)
	var camera_script: Script = load("res://game/map/map_camera_3d.gd")
	var camera: Camera3D = camera_script.new()
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
	root.add_child(sun)
	var military: Node = root.get_node("Military")
	military.fog_enabled = true
	map.set_fog(military.fog_levels(), military.fog_version)
	var world: Node = root.get_node("World")
	var home: Vector2 = world.capital_position("TUR")
	var hidden: Vector2 = world.capital_position("POL")
	var method := RenderingServer.get_current_rendering_method()
	var folder := "res://art/previews/fog_volume/" + method
	DirAccess.make_dir_recursive_absolute(folder)
	for shot in [["far", home, 14000.0], ["region", home, 4200.0], ["border", home, 1600.0], ["close", hidden, 420.0], ["inside", hidden, 160.0], ["below", hidden, 55.0]]:
		camera.focus_on(shot[1], shot[2])
		map.set_camera_distance(camera.distance)
		for f in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/" + shot[0] + ".png")
		print("CLOUD_PREVIEW ", shot[0], " camera=", camera.position, " distance=", camera.distance)
	quit()
