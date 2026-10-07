extends SceneTree
## Actual ResearchPanel in Main's HUD; all fixture changes are in memory, never saved.
## Godot --path . -s tools/preview_research_cards.gd [-- --essential]
## Six GL cases cover TR/EN, 720p/1080p and government/army/industry. --essential captures four.

const BRANCHES := ["governance", "all", "army", "navy", "air", "industry", "doctrine"]
var _errors: Array[String] = []
var _cases: Array[Dictionary] = []
var _started: Array = []

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
	var renderer := RenderingServer.get_current_rendering_method()
	var folder := "res://art/previews/research_cards/" + renderer
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
	root.get_node("GameClock").set_paused(true)
	root.get_node("Audio").set_sfx_linear(0.0)
	var world: Node = root.get_node("World")
	var research: Node = root.get_node("Research")
	var c: Object = world.player()
	if c == null:
		_errors.append("Null player; never capture partially loaded UI")
		_finish(catcher, folder)
		return
	c.political_power = 1000.0
	c.stability = 0.70
	c.research_slots = 3
	c.research_current.clear()
	if research.start(c, "motorization"):
		c.research_current[0]["progress"] = float(research.techs["motorization"]["cost"]) * 0.35
	var started_callback := func(tag: String, id: String) -> void: _started.append([tag, id])
	research.research_started.connect(started_callback)
	var specs := [
		["tr", Vector2i(1280, 720), "governance", "government_democratic_transition"],
		["en", Vector2i(1280, 720), "army", "infantry_weapons_2"],
		["tr", Vector2i(1280, 720), "industry", "construction_1"],
		["en", Vector2i(1920, 1080), "governance", "government_democratic_transition"],
		["tr", Vector2i(1920, 1080), "army", "infantry_weapons_2"],
		["en", Vector2i(1920, 1080), "industry", "construction_1"]]
	if "--essential" in OS.get_cmdline_user_args(): specs = [specs[0], specs[1], specs[4], specs[5]]
	for spec: Array in specs:
		var locale: String = spec[0]
		var resolution: Vector2i = spec[1]
		var branch: String = spec[2]
		var id: String = spec[3]
		main.hud.close_panels()
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.warp_mouse(Vector2(12, resolution.y - 12))
		TranslationServer.set_locale(locale)
		# Ready-time tab/header translations must use the actual requested locale.
		# Reinstantiate only the real panel, in its actual HUD parent and decoration.
		var old: Node = main.hud.research
		old.get_parent().remove_child(old)
		old.free()
		var panel: Control = load("res://game/ui/research_panel.gd").new()
		main.hud.research = panel
		main.hud.root.add_child(panel)
		main.hud._decorate_side_panel(panel)
		panel.open()
		await create_timer(0.35).timeout
		for i in 20: await process_frame
		var before := _research_state(c)
		(panel._tabs[BRANCHES.find(branch)] as Button).pressed.emit()
		for i in 12: await process_frame
		if not panel._nodes.has(id):
			_errors.append("Expected real project absent: " + id)
			continue
		(panel._nodes[id] as Button).pressed.emit()
		for i in 35: await process_frame
		if _research_state(c) != before or not _started.is_empty(): _errors.append("Branch/card selection started, cancelled or charged for a project")
		if panel._selected != id or not (panel._nodes[id] as Button).button_pressed: _errors.append("Real project click does not retain one selected project")
		var name := "%s_%s_%d" % [locale, branch, resolution.x]
		var report := _measure(panel, locale, branch, resolution)
		_capture(folder + "/" + name + ".png")
		await _preservation(panel, report)
		_cases.append(report)
	research.research_started.disconnect(started_callback)
	_finish(catcher, folder)

func _research_state(c: Object) -> Array:
	return [c.political_power, c.ideology, c.research_done.duplicate(), c.research_current.duplicate(true), c.research_bonus.duplicate(true)]

func _measure(panel: Control, locale: String, branch: String, resolution: Vector2i) -> Dictionary:
	var bounds := panel.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
	if not viewport.grow(2).encloses(bounds): _errors.append("Panel overflow %s %s %s" % [locale, branch, bounds])
	var report := {"locale": locale, "branch": branch, "resolution": [resolution.x, resolution.y], "panel": _rect(bounds), "cards": [], "tabs": []}
	var catalog_view: Rect2 = (panel.get("_catalog_scroll") as ScrollContainer).get_global_rect()
	report["catalog_viewport"] = _rect(catalog_view)
	var complete := 0
	var visible_titles := 0
	var cards: Dictionary = panel.get("_nodes")
	if cards.is_empty(): _errors.append("Empty research catalog: " + branch)
	for id: String in cards:
		var card: Button = cards[id]
		var art := card.find_child("Thumbnail", true, false) as TextureRect
		var title := card.find_child("ProjectTitle", true, false) as Label
		var status := card.find_child("ProjectStatus", true, false) as Label
		if art == null or title == null or status == null:
			_errors.append("Thumbnail/title/status contract missing: " + id)
			continue
		var rect := card.get_global_rect()
		if catalog_view.grow(1).encloses(rect): complete += 1
		if catalog_view.grow(1).encloses(title.get_global_rect()): visible_titles += 1
		var image_rect := art.get_global_rect()
		var left := image_rect.position.x - rect.position.x
		var right := rect.end.x - image_rect.end.x
		var top := image_rect.position.y - rect.position.y
		if left < -1 or right < -1 or left > 6 or right > 6: _errors.append("Thumbnail is not full-width (<=6px frame gutters): %s left=%s right=%s" % [id, left, right])
		if top < -1 or top > 6: _errors.append("Thumbnail is not at card top: " + id)
		if image_rect.end.y > title.get_global_rect().position.y + 1: _errors.append("Thumbnail overlaps or follows title: " + id)
		# Existing illustrations stay uncropped inside a compact full-width top band.
		if image_rect.size.y > 110: _errors.append("Thumbnail exceeds compact height cap: " + id)
		if art.texture == null or art.texture.get_width() <= 0: _errors.append("Missing actual illustration texture: " + id)
		for text: Label in [title, status]:
			if not rect.grow(1).encloses(text.get_global_rect()): _errors.append("Title/status escapes card: %s/%s" % [id, text.name])
		if rect.position.x < bounds.position.x - 1 or rect.end.x > bounds.end.x + 1: _errors.append("Catalog card horizontal overflow: " + id)
		report["cards"].append({"id": id, "rect": _rect(rect), "thumbnail": _rect(image_rect), "gutters": [left, right, top], "title": _rect(title.get_global_rect()), "status": _rect(status.get_global_rect()), "selected": card.button_pressed})
	report["complete_visible_cards"] = complete
	report["visible_card_titles"] = visible_titles
	if complete == 0: _errors.append("Initial catalog cannot show even one whole illustration/title/status card: " + branch)
	if visible_titles == 0: _errors.append("Initial catalog shows no complete project title below its artwork: " + branch)
	var tabs: Array = panel.get("_tabs")
	if tabs.size() != 7: _errors.append("Seven branch tabs expected")
	var active := 0
	var first_y := 0.0
	for i in tabs.size():
		var tab: Button = tabs[i]
		var rect := tab.get_global_rect()
		if i == 0: first_y = rect.position.y
		if not bounds.grow(1).encloses(rect) or absf(rect.position.y - first_y) > 1: _errors.append("Branch tabs escape their single row")
		if rect.size.y < 52 or tab.get_theme_font_size("font_size") < 18: _errors.append("Branch tabs were not enlarged")
		if tab.button_pressed:
			active += 1
			if BRANCHES[i] != branch: _errors.append("Wrong branch has active styling")
		var normal := tab.get_theme_stylebox("normal")
		var pressed := tab.get_theme_stylebox("pressed")
		if normal == pressed: _errors.append("Selected and idle tab surfaces are identical")
		var underline: Variant = pressed.get("underline_height")
		var fill: Variant = pressed.get("fill")
		if not underline is float or float(underline) < 3: _errors.append("Selected tab has no strong underline")
		if not fill is Color or (fill as Color).a < 0.5: _errors.append("Selected tab has no legible state wash")
		report["tabs"].append({"branch": BRANCHES[i], "rect": _rect(rect), "font_size": tab.get_theme_font_size("font_size"), "active": tab.button_pressed, "underline": underline, "fill": str(fill)})
	if active != 1: _errors.append("Exactly one selected branch tab expected")
	var selected := 0
	for card: Button in cards.values(): if card.button_pressed: selected += 1
	if selected != 1: _errors.append("Exactly one selected project expected")
	var start: Button = panel.get("_start_button")
	if start == null or not start.is_visible_in_tree() or not viewport.encloses(start.get_global_rect()) or not bounds.encloses(start.get_global_rect()):
		_errors.append("Pinned research action is outside viewport/panel")
	elif start.disabled: _errors.append("Eligible selected project unexpectedly has a disabled Start CTA")
	else: report["start_action"] = {"rect": _rect(start.get_global_rect()), "text": start.text}
	print("RESEARCH_CARD_PAGE ", locale, " ", branch, " ", resolution, " panel=", bounds, " catalog=", catalog_view, " complete=", complete, " visible_titles=", visible_titles, " first=", report["cards"][0] if not report["cards"].is_empty() else {})
	return report

func _preservation(panel: Control, report: Dictionary) -> void:
	var selected := str(panel.get("_selected"))
	var expected := {}
	for scroll: ScrollContainer in [panel.get("_catalog_scroll"), panel.get("_detail_scroll")]:
		var maximum := int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
		if maximum > 20:
			scroll.scroll_vertical = mini(80, maximum)
			expected[str(scroll.name)] = scroll.scroll_vertical
	panel.refresh()
	panel.refresh() # Rapid real research/daily refreshes must retain the pending positions too.
	for i in 12: await process_frame
	for scroll: ScrollContainer in [panel.get("_catalog_scroll"), panel.get("_detail_scroll")]:
		var key := str(scroll.name)
		if expected.has(key) and absi(scroll.scroll_vertical - int(expected[key])) > 1: _errors.append("Refresh lost scroll: " + key)
	if str(panel.get("_selected")) != selected or not (panel._nodes[selected] as Button).button_pressed: _errors.append("Refresh lost the selected project")
	if not _started.is_empty(): _errors.append("Refresh unexpectedly emits research_started")
	report["preserved_scrolls"] = expected
	report["preserved_project"] = selected

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
	else: _errors.append("Cannot save Research QA report")
	print("RESEARCH_CARDS_RESULT errors=", _errors)
	quit(0 if _errors.is_empty() else 1)
