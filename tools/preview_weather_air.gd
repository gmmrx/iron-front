extends SceneTree
## Actual map + production weather/air profiles; no Main/UI or strategy ticks.
var _errors: Array[String] = []

func _init() -> void:
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	root.get_node("Game").new_game()
	var world: Node = root.get_node("World")
	world.start_game("TUR")
	var clock: Node = root.get_node("GameClock")
	clock.set_paused(false)
	clock.set_process(false)
	root.get_node("Military").fog_enabled = false
	var map: Node3D = load("res://game/map/map_view_3d.gd").new()
	root.add_child(map)
	if not map.is_built: await map.built
	map.set_map_mode(1)
	map._cloud_mesh.hide()
	var home: Vector2 = world.capital_position("TUR")
	var camera: Camera3D = load("res://game/map/map_camera_3d.gd").new()
	camera.map = map
	camera.map_size = map.map_size
	camera.edge_pan_enabled = false
	camera.input_locked = true
	root.add_child(camera)
	camera.make_current()
	camera.set_process(false)
	var lights := _setup_lighting() # Main/UI is being edited in parallel; fixture has no UI dependencies.
	var weather: Node3D = load("res://game/map/weather_layer.gd").new()
	weather.map = map
	weather.camera = camera
	weather.force = 1
	root.add_child(weather)
	weather.set_process(false)
	var folder := "res://art/previews/weather_air/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	for distance: float in [55.0, 150.0, 350.0]:
		camera.focus_on(home, distance)
		weather._process(0.0)
		weather.rain.hide()
		for frame in 8: await process_frame
		_capture(folder + "/rain_%d_baseline.png" % int(distance))
		for frame in 90:
			weather._process(1.0 / 60.0)
			await process_frame
		_capture(folder + "/rain_%d.png" % int(distance))
		print("WEATHER_AIR rain distance=", distance, " visible=", weather.rain.multimesh.visible_instance_count,
			" allocation=", weather.rain.multimesh.instance_count, " clock=", weather._rain_time)
		if weather.rain.multimesh.instance_count != 384: _errors.append("Rain buffer grew")
	var frozen: float = weather._rain_time
	clock.set_paused(true)
	weather._process(0.5)
	if weather._rain_time != frozen: _errors.append("Paused rain clock advanced")
	camera.focus_on(home, 800.0)
	weather._process(0.0)
	if weather.rain.visible or weather.rain.multimesh.visible_instance_count > 0: _errors.append("Far rain remained visible")
	weather.force = 0
	weather._process(0.0)
	clock.set_paused(false)
	camera.focus_on(home, 150.0)
	var fx: Node3D = load("res://game/map/combat_effects.gd").new()
	fx.configure(map, camera)
	root.add_child(fx)
	fx.set_process(false)
	var air: Node3D = load("res://game/map/air_layer.gd").new()
	if not air.has_method("_blast"):
		_errors.append("AirLayer failed to compile/load")
		_errors.append_array(catcher.take())
		OS.remove_logger(catcher)
		print("WEATHER_AIR errors=", _errors)
		quit(1)
		return
	air.map = map
	air.camera = camera
	air.combat_effects = fx
	var plane: Node3D = load("res://game/map/plane_model.gd").make(world.countries["TUR"])
	plane.scale = Vector3.ONE * air._scale()
	plane.position = Vector3(home.x - 9.0, 18.0, home.y - 4.0)
	root.add_child(plane)
	for shot: Array in [["bomb_previous", "bomb", 1.25], ["bomb_new", "bomb", air.BOMB_IMPACT_SCALE],
			["crash_previous", "crash", 1.6], ["crash_new", "crash", air.CRASH_IMPACT_SCALE]]:
		fx.clear_all()
		fx._rng.seed = 19361006
		var point := Vector3(home.x, 0.0, home.y)
		if shot[0] == "bomb_new": air._blast(point, "TUR", map.province_at(home))
		elif shot[0] == "crash_new": air._crash_impact(point, "TUR", map.province_at(home))
		else: fx.impact(point, shot[1], shot[2])
		for frame in 18:
			fx.advance(1.0 / 60.0)
			await process_frame
		_capture(folder + "/" + shot[0] + ".png")
		print("WEATHER_AIR impact ", shot[0], " scale=", shot[2], " stats=", fx.stats())
	_errors.append_array(catcher.take())
	OS.remove_logger(catcher)
	print("WEATHER_AIR checks=", "PASS" if _errors.is_empty() else "FAIL", " errors=", _errors)
	air.free()
	plane.free()
	fx.free()
	weather.free()
	map.free()
	camera.free()
	for child: Node in lights: child.free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _capture(path: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_errors.append("Capture failed: " + path)

func _setup_lighting() -> Array[Node]:
	# Mirrors production lighting values without loading Main's changing panel graph.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.08, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	environment.glow_intensity = 0.18
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.15
	environment.adjustment_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	environment.adjustment_contrast = 1.09
	environment.adjustment_saturation = 0.96
	var we := WorldEnvironment.new()
	we.environment = environment
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.88
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = false
	root.add_child(sun)
	return [we, sun]
