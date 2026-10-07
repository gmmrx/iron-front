extends SceneTree
## Actual flat map, city marker layer and materials. No mocked city image.
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
	var cities: Node3D = load("res://game/map/city_layer_3d.gd").new()
	cities.map = map
	root.add_child(cities)
	if not cities.is_built: await cities.built
	var camera: Camera3D = load("res://game/map/map_camera_3d.gd").new()
	camera.map = map
	camera.map_size = map.map_size
	camera.edge_pan_enabled = false
	root.add_child(camera)
	camera.make_current()
	var pins: Node3D = load("res://game/map/pin_layer.gd").new()
	pins.map = map
	pins.camera = camera
	pins.cities = cities
	root.add_child(pins)
	# Reuse the real game's lighting without running its UI/loading _ready().
	var lighting: Node = load("res://game/main.gd").new()
	lighting._setup_environment()
	var env: WorldEnvironment
	var sun: DirectionalLight3D
	for child: Node in lighting.get_children():
		lighting.remove_child(child)
		root.add_child(child)
		if child is WorldEnvironment: env = child
		if child is DirectionalLight3D: sun = child
	lighting.free()
	var folder := "res://art/previews/mini_city/map_" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	for shot: Array in [["ankara", "TUR", 100.0], ["paris", "FRA", 150.0], ["moscow", "SOV", 150.0], ["stockholm", "SWE", 150.0], ["region", "TUR", 650.0]]:
		var home: Vector2 = world.capital_position(shot[1])
		# SceneTree scripts compile before autoloads; use native Object annotations
		# rather than eagerly compiling Country/StateRegion autoload dependencies.
		var country: Object = world.countries[shot[1]]
		var state: Object = world.states[country.capital_state]
		var capital: Object = state.largest_city()
		if capital != null:
			home = cities._visual_positions.get(capital.id, capital.position)
		camera.focus_on(home, shot[2])
		map.set_camera_distance(camera.distance)
		for frame in 120: await process_frame
		# macOS may stop presenting an unfocused diagnostic window. Force this
		# capture instead of awaiting a presentation signal that can be suspended.
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder + "/" + shot[0] + ".png")
		var visible_models := 0
		for model: MeshInstance3D in pins._halls.values():
			if model.visible: visible_models += 1
		print("MINI_CITY_MAP ", shot[0], " visible=", visible_models, " cached=", pins._halls.size())
		if shot[0] == "region" and visible_models != 0:
			push_error("City miniatures remain visible outside their near-zoom range")
			quit(1)
			return
	pins.free()
	cities.free()
	map.free()
	camera.free()
	sun.free()
	env.free()
	await process_frame
	quit()
