extends SceneTree
## Real menu/play/recon transitions; fixture state lives only in memory.
var errors: Array[String] = []

func _init() -> void:
	await process_frame
	var catcher: Logger = load("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 120000
	while (main._loading != null or main.hud == null or not main.is_processing()) and Time.get_ticks_msec() < deadline:
		await process_frame
	if main.hud == null:
		quit(1)
		return
	var folder := "res://art/previews/map_ui_polish/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	main._enter_setup()
	for frame in 15: await process_frame
	if main.day_night.enabled or main.day_night._strength != 0.0: errors.append("Country picker is shaded by night")
	await capture(folder + "/country_select_daylight.png")
	main._start_game("TUR")
	if not main.day_night.enabled: errors.append("Game start did not enable night cycle")
	root.get_node("GameClock").set_paused(true)
	root.get_node("Audio").set_sfx_linear(0.0)
	main.hud.feed.hide()
	main.camera.edge_pan_enabled = false
	main.camera.input_locked = true
	var world: Node = root.get_node("World")
	var air: Node = root.get_node("Air")
	var c: Object = world.player()
	c.sp = 1000
	c.stockpile[air.TYPES["fighter"]["eq"]] = 1000.0
	air.deploy(c, "fighter", air._home_base(c.tag))
	main.camera.focus_on(world.capital_position("TUR"), 1600.0)
	main._begin_recon()
	for frame in 15: await process_frame
	if not main.map_view._material.get_shader_parameter("recon_enabled"): errors.append("Recon mask not enabled by real action")
	await capture(folder + "/recon_targets.png")
	main._recon_pick = false
	main._update_recon_preview()
	if main.map_view._material.get_shader_parameter("recon_enabled"): errors.append("Recon mask persists after exit")
	await capture(folder + "/recon_cleared.png")
	for error: String in catcher.take(): errors.append(error)
	OS.remove_logger(catcher)
	print("MAP_UI_POLISH errors=", errors)
	main.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)

func capture(path: String) -> void:
	for frame in 8: await process_frame
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(path) != OK: errors.append("Screenshot failed: " + path)
