extends SceneTree
## Actual game UI capture and viewport checks. All fixtures are memory-only.
var _errors: Array[String] = []

func _init() -> void:
	await process_frame
	TranslationServer.set_locale("tr")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(1920, 1080)
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 120000
	while (main._loading != null or not main.is_processing() or main.hud == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	if main.hud == null:
		quit(1)
		return
	main._start_game("TUR")
	main.hud.feed.hide()
	main.hud.ui_tooltip.set_process(false)
	main.hud.ui_tooltip.hide()
	root.get_node("GameClock").set_paused(true)
	main.camera.edge_pan_enabled = false
	main.camera.input_locked = true
	main.set_process_unhandled_input(false)
	var world: Node = root.get_node("World")
	var military: Node = root.get_node("Military")
	var navy: Node = root.get_node("Navy")
	var air: Node = root.get_node("Air")
	var player: Object = world.player()
	player.war_goals["IRQ"] = true
	var own_divisions: Array = military.country_divisions(player.tag)
	var panels: Array = [["navy", main.hud.navy], ["air", main.hud.air], ["army", main.hud.army], ["country", main.hud.state_panel]]
	var folder := "res://art/previews/force_selection"
	if RenderingServer.get_current_rendering_method() == "gl_compatibility": folder += "/gl_compatibility"
	DirAccess.make_dir_recursive_absolute(folder)
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.warp_mouse(Vector2(12, resolution.y - 12))
		for spec: Array in panels:
			for entry: Array in panels: entry[1].close()
			main.units.clear_selection()
			var panel: Control = spec[1]
			match spec[0]:
				"country": world.select_province(world.capital_province("IRQ"))
				"army":
					main.units.select_divisions(own_divisions.slice(0, 2), false)
					panel.open()
				"navy":
					panel.open()
					for fleet: Object in navy.fleets:
						if fleet.owner == player.tag:
							panel.select(fleet)
							panel.clear_selection() # Exercise Main's deselection signal with a null fleet.
							panel.select(fleet)
							break
				"air":
					panel.open()
					for wing: Object in air.wings:
						if wing.owner == player.tag:
							panel.select(wing)
							break
			await create_timer(0.65).timeout # Include panel polling and its real-time entrance tween.
			for i in 8: await process_frame
			_capture(folder + "/%s_%d.png" % [spec[0], resolution.x])
			_check(panel, resolution, spec[0])
			if spec[0] == "air":
				panel.set_target(world.capital_province(player.tag))
				for i in 8: await process_frame
				_capture(folder + "/air_target_%d.png" % resolution.x)
				_check(panel, resolution, "air_target")
				panel.set_target(0)
			if spec[0] == "country":
				for button: Button in panel._quick_actions.values():
					if not panel.get_global_rect().encloses(button.get_global_rect()): _errors.append("Country action outside box")
				panel._request_quick_action("declare", "IRQ", world.capital_province("IRQ"))
				for i in 8: await process_frame
				_capture(folder + "/war_confirmation_%d.png" % resolution.x)
				panel._cancel_war()
				var occupied_pid: int = world.capital_province("SOV")
				var old_controller: String = world.controller_tag(occupied_pid)
				player.war_goals["SOV"] = true
				world.set_controller(occupied_pid, player.tag)
				world.select_province(occupied_pid)
				for i in 8: await process_frame
				_capture(folder + "/country_occupied_%d.png" % resolution.x)
				_check(panel, resolution, "country_occupied")
				world.set_controller(occupied_pid, old_controller)
				player.war_goals.erase("SOV")
		for entry: Array in panels: entry[1].close()
		main.units.select_divisions(own_divisions.slice(0, 4), false)
		await create_timer(0.65).timeout
		for i in 8: await process_frame
		_capture(folder + "/divisions_%d.png" % resolution.x)
		_check(main.hud.divisions, resolution, "divisions")
	_errors.append_array(catcher.take())
	OS.remove_logger(catcher)
	print("FORCE_SELECTION errors=", _errors)
	quit(0 if _errors.is_empty() else 1)

func _check(panel: Control, resolution: Vector2i, label: String) -> void:
	var rect := panel.get_global_rect()
	print("FORCE_PANEL ", label, " ", resolution, " rect=", rect)
	if rect.end.x > resolution.x + 2 or rect.end.y > resolution.y + 2 or rect.position.x < 0:
		_errors.append("Panel overflow " + label + ": " + str(rect))

func _capture(path: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(path) != OK: _errors.append("Capture failed: " + path)
