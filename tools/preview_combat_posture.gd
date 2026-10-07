extends SceneTree
## Isolated in-memory GER/POL battle in the real Main scene; no saves are written.
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
	main._start_game("GER")
	var world: Node = root.get_node("World")
	var military: Node = root.get_node("Military")
	var game: Node = root.get_node("Game")
	var clock: Node = root.get_node("GameClock")
	root.get_node("AI").enabled = false
	clock.set_process(false)
	clock.set_paused(false)
	root.get_node("Audio").set_sfx_linear(0.0)
	world.countries["GER"].war_goals["POL"] = true
	root.get_node("Diplomacy").declare_war("GER", "POL")
	var pair: Array = []
	for p: Object in world.provinces:
		if p == null or not p.is_land() or world.controller_tag(p.id) != "GER": continue
		for q: int in world.land_neighbors(p.id):
			if world.controller_tag(q) == "POL":
				pair = [p.id, q]
				break
		if not pair.is_empty(): break
	if pair.is_empty():
		quit(1)
		return
	for d: Object in military.divisions.duplicate(): military._remove(d)
	military._rebuild_index()
	var attacker: Object = military._create(world.countries["GER"], 0, pair[0], 1.0, 0)
	var defender: Object = military._create(world.countries["POL"], 0, pair[1], 1.0, 0)
	defender.hold = true
	military.order_attack(attacker, pair[1])
	attacker.attacking = pair[1]
	military._combat()
	main.units._dirty = true
	main.hud.feed.hide()
	main.hud.close_panels()
	main.camera.edge_pan_enabled = false
	main.camera.input_locked = true
	var centre: Vector2 = (world.province(pair[0]).center + world.province(pair[1]).center) * 0.5
	main.camera.focus_on(centre, 140.0)
	var folder := "res://art/previews/combat_posture/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	for observer: bool in [false, true]:
		game.observer = observer
		main.units._dirty = true
		for frame in 150: await process_frame
		var before := {}
		for key: String in main.units._counters:
			var c: Dictionary = main.units._counters[key]
			if c.has("post_pid") and c.get("settled", false): before[key] = c["root"].position
		for frame in 90: await process_frame
		for key: String in before:
			if main.units._counters.has(key) and main.units._counters[key]["root"].position.distance_to(before[key]) > 0.001:
				errors.append("Stationary combat post moved: " + key)
		if before.is_empty(): errors.append("No settled combat posts measured")
		RenderingServer.force_draw(false)
		var name := "observer" if observer else "normal"
		if root.get_texture().get_image().save_png(folder + "/" + name + ".png") != OK: errors.append("Screenshot failed")
		print("COMBAT_POSTURE ", name, " settled=", before.size())
	for error: String in catcher.take(): errors.append(error)
	OS.remove_logger(catcher)
	print("COMBAT_POSTURE errors=", errors)
	main.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
