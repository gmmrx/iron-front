extends SceneTree
## Actual terrain, existing miniatures/aircraft and production combat-effect calls.
## --frames=/absolute/temp/folder additionally writes a 30fps animation sequence.
var _errors: Array[String] = []

func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	root.get_node("Game").new_game()
	var world: Node = root.get_node("World")
	world.start_game("TUR")
	root.get_node("Military").fog_enabled = false
	var clock: Node = root.get_node("GameClock")
	clock.set_paused(false)
	clock.set_process(false) # Visual fixture; do not advance the strategy simulation.
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
	camera.focus_on(home, 105.0)
	camera.make_current()
	camera.set_process(false)
	var lighting: Node = load("res://game/main.gd").new()
	lighting._setup_environment()
	for child: Node in lighting.get_children():
		lighting.remove_child(child)
		root.add_child(child)
	lighting.free()
	var fx: Node3D = load("res://game/map/combat_effects.gd").new()
	fx.configure(map, camera)
	root.add_child(fx)
	fx.set_process(false)
	fx._rng.seed = 19361006
	if not fx.textures_ready: _errors.append("Combat textures missing")
	var units: Node3D = load("res://game/map/unit_layer.gd").new()
	units.map = map
	units.camera = camera
	units.combat_effects = fx
	units._combat_rng.seed = 1940
	var figures: Script = load("res://game/map/unit_figures.gd")
	var tank: Node3D = figures.make(world.countries["TUR"], "tank")
	var soldier: Node3D = figures.make(world.countries["GER"], "soldier")
	var left := home + Vector2(-16, 6)
	var right := home + Vector2(15, -5)
	for spec: Array in [[tank, left, right, "tank"], [soldier, right, left, "soldier"]]:
		var fig: Node3D = spec[0]
		var pos: Vector2 = spec[1]
		var toward: Vector2 = spec[2] - pos
		fig.scale = Vector3.ONE * 10.0
		fig.position = Vector3(pos.x, 5.0, pos.y)
		root.add_child(fig)
		fig.get_node("t").rotation.y = -atan2(toward.y, toward.x) - figures.aim_yaw(spec[3])
	var air: Node3D = load("res://game/map/air_layer.gd").new()
	air.map = map
	air.camera = camera
	air.combat_effects = fx
	root.add_child(air)
	air.set_process(false)
	var plane: Node3D = load("res://game/map/plane_model.gd").make(world.countries["TUR"])
	plane.scale = Vector3.ONE * air._scale()
	root.add_child(plane)
	plane.rotation.y = -PI * 0.5
	var tank_state := {"yaw": tank.get_node("t").rotation.y}
	var infantry_state := {"yaw": soldier.get_node("t").rotation.y}
	var folder := "res://art/previews/combat/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	var frames := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): frames = arg.trim_prefix("--frames=")
	if frames != "": DirAccess.make_dir_recursive_absolute(frames)
	for i in 35: await process_frame
	_capture(folder + "/before.png")
	for frame in 240:
		var dt := 1.0 / 60.0
		var t := frame * dt
		plane.position = Vector3(home.x - 28.0 + t * 13.0, 18.0, home.y - 8.0)
		if frame in [12, 155]: units._fire(tank_state, tank, right)
		if frame in [24, 54, 84, 118, 150, 184, 218]: units._fire(infantry_state, soldier, left)
		if frame == 68:
			var pid: int = map.province_at(home)
			air._bombs.append([plane.position, Vector3(13, 0, 0), "TUR", pid])
		if frame == 92:
			air._fire_burst(plane.position + Vector3(2, 0, 0), Vector3(1, -0.55, 0).normalized(), true)
		air._update_projectiles(dt)
		units._pose(tank_state, tank, dt)
		units._pose(infantry_state, soldier, dt)
		fx.advance(dt)
		await process_frame
		if frame in [15, 30, 54, 105, 138, 182, 235]:
			_capture(folder + "/frame_%03d.png" % frame)
		if frames != "" and frame % 2 == 0:
			_capture(frames + "/%04d.png" % (frame / 2))
	var age_sum := 0.0
	for p in fx._particles: age_sum += p.age
	clock.set_paused(true)
	fx.advance(0.5)
	var frozen_sum := 0.0
	for p in fx._particles: frozen_sum += p.age
	if not is_equal_approx(age_sum, frozen_sum): _errors.append("Pause advanced particles")
	# Exercise the same impact API over real water, with no fireball/scorch.
	clock.set_paused(false)
	fx.clear_all()
	tank.hide()
	soldier.hide()
	plane.hide()
	var sea := home
	var sea_distance := INF
	for p in world.provinces:
		if p == null or p.is_land(): continue
		var distance: float = p.center.distance_squared_to(home)
		if distance < sea_distance:
			sea_distance = distance
			sea = p.center
	camera.focus_on(sea, 90.0)
	fx.impact(Vector3(sea.x, 0.0, sea.y), "water", 1.3)
	for frame in 55:
		fx.advance(1.0 / 60.0)
		await process_frame
		if frame in [5, 18, 45]: _capture(folder + "/water_%03d.png" % frame)
	camera.focus_on(home, 700.0)
	fx.advance(0.1)
	if int(fx.stats()["active"]) != 0: _errors.append("Far zoom retained effects")
	print("COMBAT_PREVIEW stats=", fx.stats())
	_errors.append_array(catcher.take())
	OS.remove_logger(catcher)
	print("COMBAT_PREVIEW errors=", _errors)
	units.free()
	quit(0 if _errors.is_empty() else 1)

func _capture(path: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK: _errors.append("Capture failed: " + path)
