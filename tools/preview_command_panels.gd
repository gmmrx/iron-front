extends SceneTree
## Capture actual gameplay UI, not a mock-up. No saves or settings are written.
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
		push_error("Main UI startup timeout")
		quit(1)
		return
	main._start_game("TUR")
	main.hud.feed.visible = false # Only the capture fixture: don't obscure the panels with its welcome toast.
	main.hud.ui_tooltip.set_process(false)
	main.hud.ui_tooltip.hide()
	root.get_node("GameClock").set_paused(true)
	main.camera.edge_pan_enabled = false
	main.camera.input_locked = true
	main.set_process_unhandled_input(false)
	var c: Object = root.get_node("World").player()
	var research: Node = root.get_node("Research")
	for id: String in research.techs:
		if c.research_current.size() >= c.research_slots: break
		if research.can_research(c, id): research.start(c, id)
	for i in c.research_current.size():
		var id: String = c.research_current[i]["tech"]
		c.research_current[i]["progress"] = float(research.techs[id]["cost"]) * (0.25 + i * 0.15)
	var panels: Array = [["politics", main.hud.politics], ["diplomacy", main.hud.diplomacy], ["research", main.hud.research]]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--panels="):
			var selected := arg.trim_prefix("--panels=").split(",")
			panels = panels.filter(func(entry: Array) -> bool: return entry[0] in selected)
	var folder := "res://art/previews/command_panels"
	if RenderingServer.get_current_rendering_method() == "gl_compatibility": folder += "/gl_compatibility"
	DirAccess.make_dir_recursive_absolute(folder)
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.warp_mouse(Vector2(12, resolution.y - 12))
		for spec: Array in panels:
			for entry: Array in panels: entry[1].close()
			var panel: Control = spec[1]
			if spec[0] == "diplomacy": panel.open_for("SOV")
			else: panel.open()
			for i in 35: await process_frame
			_capture(folder + "/%s_%d.png" % [spec[0], resolution.x])
			var rect := panel.get_global_rect()
			if rect.end.x > resolution.x + 2 or rect.end.y > resolution.y + 2:
				_errors.append("Panel overflow %s %s: %s" % [spec[0], resolution, rect])
			if spec[0] == "research":
				for card: Button in panel._nodes.values():
					for child: Node in card.find_children("*", "Label", true, false):
						if child.get_global_rect().end.x > card.get_global_rect().end.x + 1:
							_errors.append("Technology caption overflow: " + child.text)
				if panel._start_button != null and not rect.encloses(panel._start_button.get_global_rect()):
					_errors.append("Research primary action is not visible inside the panel")
			print("COMMAND_PANEL ", spec[0], " ", resolution, " rect=", rect)
			await _check_scroll_preservation(panel)
			if spec[0] == "research":
				panel._set_branch("army")
				for i in 8: await process_frame
				_capture(folder + "/research_army_%d.png" % resolution.x)
				await _check_scroll_preservation(panel)
				# Memory-only fixture for the costly-project confirmation; no save writes.
				var previous_power: float = c.political_power
				var previous_slots: int = c.research_slots
				c.political_power = 500
				c.research_slots += 1
				panel._set_branch("governance")
				panel._selected = "government_democratic_transition"
				panel._refresh_detail()
				panel._activate_selected()
				for i in 8: await process_frame
				_capture(folder + "/research_confirmation_%d.png" % resolution.x)
				if panel._confirmation.size.x > resolution.x or panel._confirmation.size.y > resolution.y:
					_errors.append("Research confirmation exceeds the viewport")
				panel._confirmation.hide()
				panel._pending_project = ""
				c.political_power = previous_power
				c.research_slots = previous_slots
	_errors.append_array(catcher.take())
	OS.remove_logger(catcher)
	print("COMMAND_PANELS errors=", _errors)
	quit(0 if _errors.is_empty() else 1)

func _check_scroll_preservation(panel: Control) -> void:
	var expected := {}
	for node: Node in panel.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		var key := String(scroll.name)
		if not (key.begins_with("PoliticsColumn") or key.begins_with("DiplomacyColumn") or key in ["DiplomacyCountryScroll", "ResearchCatalog", "ResearchDossier"]): continue
		var bar := scroll.get_v_scroll_bar()
		if bar.max_value - bar.page > 20:
			scroll.scroll_vertical = mini(80, int(bar.max_value - bar.page))
			expected[key] = scroll.scroll_vertical
	panel.refresh()
	panel.refresh() # Rapid daily/research-changed notifications must preserve the pending position too.
	for i in 6: await process_frame
	for node: Node in panel.find_children("*", "ScrollContainer", true, false):
		var key := String(node.name)
		if expected.has(key) and absi(node.scroll_vertical - int(expected[key])) > 1:
			_errors.append("Refresh reset scroll " + key + ": " + str(node.scroll_vertical) + " expected " + str(expected[key]))

func _capture(path: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK: _errors.append("Capture failed: " + path)
