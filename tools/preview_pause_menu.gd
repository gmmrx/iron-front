extends SceneTree
## Real ESC/settings UI in Main. Never presses save/load/main-menu/quit or any settings-changing control.
## The load page is fed synthetic names directly; no user save file is read or loaded.
## Godot --path . -s tools/preview_pause_menu.gd [-- --essential]

const ACTIONS := ["PauseResume", "PauseSave", "PauseLoad", "PauseSettings", "PauseMainMenu", "PauseQuit"]
var _errors: Array[String] = []
var _cases: Array[Dictionary] = []

func _init() -> void:
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	await process_frame
	TranslationServer.set_locale("tr")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 120000
	while (main._loading != null or not main.is_processing() or main.hud == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	var folder := "res://art/previews/pause_menu/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	if main.hud == null:
		_errors.append("Main did not become ready")
		_finish(catcher, folder)
		return
	main._start_game("TUR")
	main.hud.close_panels()
	main.hud.feed.hide()
	main.hud.ui_tooltip.set_process(false)
	main.hud.ui_tooltip.hide()
	main.camera.edge_pan_enabled = false
	main.camera.input_locked = true
	main.set_process_unhandled_input(false)
	var clock: Node = root.get_node("GameClock")
	clock.set_paused(true)
	root.get_node("Audio").set_sfx_linear(0.0)
	var c: Object = root.get_node("World").player()
	if c == null:
		_errors.append("No player; refuse to capture half-loaded UI")
		_finish(catcher, folder)
		return
	var unchanged := [c.political_power, c.research_current.duplicate(true), c.states.duplicate(), clock.year, clock.month, clock.day]
	var specs := [["tr", Vector2i(1280, 720), "main"], ["en", Vector2i(1920, 1080), "main"]]
	if not "--essential" in OS.get_cmdline_user_args(): specs.append_array([["tr", Vector2i(1280, 720), "loads"], ["tr", Vector2i(1280, 720), "settings"]])
	for spec: Array in specs:
		var locale: String = spec[0]
		var resolution: Vector2i = spec[1]
		var page: String = spec[2]
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.warp_mouse(Vector2(12, resolution.y - 12))
		TranslationServer.set_locale(locale)
		var old: Node = main.hud.pause_menu
		old.get_parent().remove_child(old)
		old.free()
		# Use the real implementation/parent/signals, rebuilt for each locale.
		var menu: Control = load("res://game/ui/pause_menu.gd").new()
		main.hud.pause_menu = menu
		main.hud.root.add_child(menu)
		menu.connect("to_main_menu", Callable(main, "_back_to_menu"))
		menu.connect("load_requested", Callable(main, "_load_slot"))
		menu.toggle()
		for i in 35: await process_frame
		var report := _check_main(menu, locale, resolution, page)
		match page:
			"loads":
				var slots: Array[String] = []
				for i in 18: slots.append("TUR_1936_01_%02d — Ankara harekâtı, yalnız önizleme %02d" % [i + 1, i + 1])
				menu._show_saves(slots)
				for i in 20: await process_frame
				_check_loads(menu, resolution, report)
			"settings":
				menu._settings()
				menu._settings() # Repeated open must not stack a second settings panel.
				for i in 35: await process_frame
				_check_settings(menu, resolution, report)
		_capture(folder + "/%s_%s_%d.png" % [locale, page, resolution.x])
		if page == "settings": await _check_settings_teardown(menu, report)
		if [c.political_power, c.research_current, c.states, clock.year, clock.month, clock.day] != unchanged: _errors.append("UI-only QA changed gameplay state")
		if not clock.paused: _errors.append("QA must remain paused throughout")
		_cases.append(report)
	_finish(catcher, folder)

func _check_main(menu: Control, locale: String, resolution: Vector2i, page: String) -> Dictionary:
	var panel: Control = menu.get("_panel")
	var rect := panel.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
	if not viewport.grow(1).encloses(rect): _errors.append("Pause window overflows viewport: " + str(rect))
	if rect.size.x < 479 or rect.size.x > 485: _errors.append("Pause window is not the intended 480px command window")
	if rect.get_center().distance_to(Vector2(resolution) * 0.5) > 2: _errors.append("Pause window is not centered")
	var report := {"locale": locale, "resolution": [resolution.x, resolution.y], "page": page, "window": _rect(rect), "buttons": []}
	var previous_end := 0.0
	for name: String in ACTIONS:
		var button := menu.find_child(name, true, false) as Button
		if button == null:
			_errors.append("Missing real menu action: " + name)
			continue
		var bounds := button.get_global_rect()
		if not rect.encloses(bounds) or not viewport.encloses(bounds): _errors.append("Menu action is clipped/outside its window: " + name)
		if bounds.position.y < previous_end - 1: _errors.append("Overlapping menu actions")
		previous_end = bounds.end.y
		if bounds.size.y < 54: _errors.append("Menu action did not retain its 54px target: " + name)
		if button.disabled or not button.is_visible_in_tree() or button.mouse_filter == Control.MOUSE_FILTER_IGNORE or button.pressed.get_connections().is_empty(): _errors.append("Menu action is not wired/clickable: " + name)
		report["buttons"].append({"name": name, "text": button.text, "rect": _rect(bounds), "wired": not button.pressed.get_connections().is_empty()})
	for name: String in ["PauseTitle", "PauseCountry", "PauseDate"]:
		var label := menu.find_child(name, true, false) as Label
		if label == null or label.text.is_empty(): _errors.append("Menu identity/date/header missing: " + name)
		elif not rect.encloses(label.get_global_rect()): _errors.append("Menu identity caption clipped: " + name)
	print("PAUSE_QA_PAGE ", locale, " ", page, " ", resolution, " window=", rect)
	return report

func _check_loads(menu: Control, resolution: Vector2i, report: Dictionary) -> void:
	var panel: Control = menu.get("_panel")
	var bounds := panel.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
	var scroll := menu.find_child("PauseSaves", true, false) as ScrollContainer
	if scroll == null:
		_errors.append("Synthetic saves have no bounded scroll container")
		return
	var rect := scroll.get_global_rect()
	if not viewport.encloses(bounds) or not bounds.encloses(rect): _errors.append("Load list window/scroll escapes the viewport")
	if rect.size.y > 282 or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: _errors.append("Save-list scroll is unbounded or scrolls horizontally")
	var list: VBoxContainer = null
	for child: Node in scroll.get_children():
		if child is VBoxContainer: list = child; break
	if list == null:
		_errors.append("Synthetic save entry container is missing")
		return
	if list.get_child_count() != 10: _errors.append("Only the intended first ten synthetic save entries should be displayed")
	for button: Button in list.get_children():
		if button.disabled or button.pressed.get_connections().is_empty(): _errors.append("Save-list entry is not inspectable/clickable")
		if button.get_global_rect().size.x > rect.size.x + 1: _errors.append("Long synthetic save name expands the list horizontally")
	if scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page: _errors.append("Long synthetic list is not actually scrollable")
	var back := menu.find_child("PauseBack", true, false) as Button
	if back == null or not bounds.encloses(back.get_global_rect()): _errors.append("Load-list Back control is outside the bounded menu")
	report["load_window"] = _rect(bounds)
	report["save_scroll"] = _rect(rect)
	report["synthetic_entries"] = list.get_child_count()

func _check_settings(menu: Control, resolution: Vector2i, report: Dictionary) -> void:
	var settings: Control = menu.get("_settings_panel")
	var panels := _settings_nodes(menu)
	if settings == null or panels.size() != 1:
		_errors.append("Opening Settings twice stacks or loses its real panel")
		return
	var window := settings.find_child("SettingsWindow", true, false) as Control
	if window == null:
		_errors.append("No real Settings window")
		return
	var rect := window.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
	if not viewport.grow(1).encloses(rect): _errors.append("Settings window overflows viewport: " + str(rect))
	if rect.get_center().distance_to(Vector2(resolution) * 0.5) > 2: _errors.append("Settings window is not centered")
	if not bool(settings.get("command_style")): _errors.append("In-game Settings did not inherit the command skin")
	if settings.get_theme_stylebox("normal", "Button") != menu.get_theme_stylebox("normal", "Button"): _errors.append("Settings buttons use a different theme from ESC")
	var panel: Control = menu.get("_panel")
	if panel.visible: _errors.append("ESC window remains stacked behind the open Settings panel")
	var music_scroll := settings.find_child("SettingsMusicScroll", true, false) as ScrollContainer
	if music_scroll == null or not rect.encloses(music_scroll.get_global_rect()) or music_scroll.size.y > 302:
		_errors.append("In-game Settings music list does not have a bounded internal viewport")
	else: report["music_scroll"] = _rect(music_scroll.get_global_rect())
	for button: BaseButton in window.find_children("*", "BaseButton", true, false):
		if not button.is_visible_in_tree(): continue
		var button_rect := button.get_global_rect()
		if button_rect.position.x < rect.position.x - 1 or button_rect.end.x > rect.end.x + 1: _errors.append("Settings control escapes window horizontally: " + str(button.name))
		# Track entries may intentionally extend below their bounded, clipped music viewport.
		if not _has_scroll_ancestor(button, window) and not rect.grow(1).encloses(button_rect): _errors.append("Fixed Settings control escapes window: " + str(button.name))
	report["settings_window"] = _rect(rect)
	report["settings_count"] = panels.size()

func _check_settings_teardown(menu: Control, report: Dictionary) -> void:
	var settings: Control = menu.get("_settings_panel")
	if settings == null: return
	settings._close() # Close only: never invokes sliders, language, music, or GameSettings.save().
	for i in 12: await process_frame
	if not (menu.get("_panel") as Control).visible or not menu.visible or menu.get("_settings_panel") != null: _errors.append("Closing Settings does not restore the single ESC window")
	if not _settings_nodes(menu).is_empty(): _errors.append("Closed Settings node remains stacked")
	menu._settings()
	for i in 8: await process_frame
	menu.close() # Keep paused; _was_paused is true in this memory-only QA fixture.
	for i in 12: await process_frame
	if menu.visible or menu.get("_settings_panel") != null or not _settings_nodes(menu).is_empty(): _errors.append("Closing ESC with Settings open leaves an orphan overlay")
	menu.toggle()
	for i in 12: await process_frame
	if not menu.visible or not (menu.get("_panel") as Control).visible or not _settings_nodes(menu).is_empty(): _errors.append("Reopening ESC stacks old Settings")
	report["settings_close_and_reopen"] = "checked_without_writing_settings"

func _settings_nodes(menu: Control) -> Array:
	var script: Script = load("res://game/ui/settings_panel.gd")
	return menu.get_children().filter(func(child: Node) -> bool: return child.get_script() == script)

func _has_scroll_ancestor(control: Control, window: Control) -> bool:
	var parent := control.get_parent()
	while parent and parent != window:
		if parent is ScrollContainer: return true
		parent = parent.get_parent()
	return false

func _rect(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.01), snappedf(rect.position.y, 0.01), snappedf(rect.size.x, 0.01), snappedf(rect.size.y, 0.01)]

func _capture(path: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(path) != OK: _errors.append("Cannot capture " + path)

func _finish(catcher: Logger, folder: String) -> void:
	_errors.append_array(catcher.take())
	OS.remove_logger(catcher)
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "cases": _cases, "errors": _errors}, "\t"))
	else: _errors.append("Cannot save pause-menu QA report")
	print("PAUSE_QA_RESULT errors=", _errors)
	quit(0 if _errors.is_empty() else 1)
