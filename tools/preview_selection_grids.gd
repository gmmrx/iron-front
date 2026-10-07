extends SceneTree
## Actual native UI, memory-only fixture. No gameplay saves, artwork, or production source is altered.
## Godot --path . -s tools/preview_selection_grids.gd [-- --include-land-details]
## Captures both 720p/1080p; optionally Army detail/template and right-hand Division pages too.

var _errors: Array[String] = []
var _cases: Array[Dictionary] = []
var _include_land_details := false

func _init() -> void:
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	await process_frame
	_include_land_details = "--include-land-details" in OS.get_cmdline_user_args()
	TranslationServer.set_locale("tr")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(1920, 1080)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 120000
	while (main._loading != null or not main.is_processing() or main.hud == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	if main.hud == null:
		_errors.append("Main scene did not become ready")
		_finish(catcher, "res://art/previews/selection_grids")
		return
	main._start_game("TUR")
	main.hud.feed.hide()
	main.hud.ui_tooltip.set_process(false)
	main.hud.ui_tooltip.hide()
	root.get_node("GameClock").set_paused(true)
	root.get_node("Audio").set_sfx_linear(0.0)
	main.camera.edge_pan_enabled = false
	main.camera.input_locked = true
	main.set_process_unhandled_input(false)
	var fixture := _fixture()
	var renderer := RenderingServer.get_current_rendering_method()
	var folder := "res://art/previews/selection_grids/" + renderer
	DirAccess.make_dir_recursive_absolute(folder)
	if fixture.is_empty() or not _errors.is_empty():
		_finish(catcher, folder)
		return
	var pages := ["construction", "navy", "air", "army"]
	if _include_land_details: pages.append_array(["army_detail", "army_templates", "divisions"])
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			var page := argument.trim_prefix("--only=")
			if page in pages: pages = [page]
			else: _errors.append("Unknown requested preview page: " + page)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.warp_mouse(Vector2(12, resolution.y - 12))
		for page: String in pages:
			main.hud.close_panels()
			main.hud.divisions.hide()
			main.units.clear_selection()
			var panel: Control
			match page:
				"construction":
					panel = main.hud.construction
					panel.open()
					panel._buttons["military_factory"].pressed.emit()
				"navy":
					panel = main.hud.navy
					panel.open()
					panel.select(fixture["fleets"][0])
				"air":
					panel = main.hud.air
					panel.set_target(0)
					panel.open()
					panel.select(fixture["wings"][0])
				"army":
					panel = main.hud.army
					panel._switch_tab(0)
					panel._sel = "free"
					main.units.select_divisions(fixture["free"].slice(0, 2), false)
					panel.open()
				"army_detail":
					panel = main.hud.army
					main.units.select_divisions(fixture["army_members"].slice(0, 2), false)
					panel.open_army(fixture["army"].id)
				"army_templates":
					panel = main.hud.army
					panel._switch_tab(1)
					panel.open()
				"divisions":
					panel = main.hud.divisions
					main.units.select_divisions(fixture["free"], false)
			await create_timer(0.65).timeout
			for i in 35: await process_frame
			# Each page is a fresh overview, not an inherited scroll position from the previous capture.
			if panel.has_meta("scroll"):
				(panel.get_meta("scroll") as ScrollContainer).scroll_vertical = 0
			if page == "construction":
				(panel.get("_catalog_scroll") as ScrollContainer).scroll_vertical = 0
				(panel.get("_queue_scroll") as ScrollContainer).scroll_vertical = 0
			for i in 8: await process_frame
			var cards := _cards(main, page)
			# Army rosters sit after their commander/orders. Ensure the actual first pair is visible.
			if page in ["army", "army_detail"] and not cards.is_empty():
				var scroll := _scroll_ancestor(cards[0])
				if scroll: scroll.ensure_control_visible(cards[0])
				for i in 8: await process_frame
			var report := _check_page(panel, page, resolution, cards)
			_capture(folder + "/%s_%d.png" % [page, resolution.x])
			if resolution.x == 1280 and page in ["navy", "air"]:
				var details: VBoxContainer = panel.get("_details")
				for child: Control in details.get_children():
					if not bool(child.get_meta("selection_detail", false)): continue
					var scroll := _scroll_ancestor(child)
					if scroll: scroll.ensure_control_visible(child)
					for i in 8: await process_frame
					report["operations_scrolled"] = _rect(child.get_global_rect())
					report["operations_viewport"] = _rect(scroll.get_global_rect()) if scroll else []
					_capture(folder + "/%s_operations_%d.png" % [page, resolution.x])
			_cases.append(report)
	_finish(catcher, folder)

func _fixture() -> Dictionary:
	var world: Node = root.get_node("World")
	var military: Node = root.get_node("Military")
	var navy: Node = root.get_node("Navy")
	var air: Node = root.get_node("Air")
	var economy: Node = root.get_node("Economy")
	var c: Object = world.player()
	if c == null:
		_errors.append("World.player is null; never capture a half-loaded fixture")
		return {}
	var own: Array = military.country_divisions(c.tag)
	while own.size() < 18:
		own.append(military._create(c, 0, world.capital_province(c.tag), 1.0, 0))
	for d: Object in own.slice(0, 6): military.set_division_army(d, 0)
	var army: Object = military.create_army(c.tag, own.slice(6, 12))
	military.create_army(c.tag, own.slice(12, 15))
	military.create_army(c.tag, own.slice(15, 18))
	var commanders: Array = military.free_commanders(c.tag)
	if not commanders.is_empty(): military.assign_army_commander(army, commanders[0].id)
	var fleets: Array = navy.fleets_of(c.tag)
	var ports: Array = navy.ports_of(c.tag)
	if ports.is_empty(): _errors.append("Fixture has no real Turkish naval port")
	while fleets.size() < 3 and not ports.is_empty():
		var number := fleets.size()
		fleets.append(navy._create(c.tag, {"cruiser": 1, "destroyer": 3}, ports[number % ports.size()], "Marmara Görev Grubu %d" % (number + 1)))
	var wings: Array = air.wings_of(c.tag)
	var bases: Array = air.bases_of(c.tag)
	if bases.is_empty(): _errors.append("Fixture has no real Turkish air base")
	while wings.size() < 3 and not bases.is_empty():
		var kind: String = ["fighter", "cas", "bomber"][wings.size() % 3]
		var equipment := str(air.TYPES[kind]["eq"])
		c.stockpile[equipment] = float(c.stockpile.get(equipment, 0.0)) + 80.0
		var wing: Object = air.deploy(c, kind, bases[wings.size() % bases.size()], 60)
		if wing == null: _errors.append("Could not deploy real fixture wing"); break
		wings.append(wing)
	c.construction_queue.clear()
	for building: String in ["military_factory", "civilian_factory", "infrastructure"]:
		var accepted := false
		for sid: int in c.states:
			if economy.queue_building(c, world.states[sid], building): accepted = true; break
		if not accepted: _errors.append("No legal construction fixture for " + building)
	for i in c.construction_queue.size():
		var project: Object = c.construction_queue[i]
		project.progress = project.cost * (0.32 - i * 0.10)
		project.last_daily = 8.0 + i * 3.0
	print("SELECTION_GRID_FIXTURE fleets=", fleets.size(), " wings=", wings.size(), " free=6 army=6 queue=", c.construction_queue.size())
	return {"free": own.slice(0, 6), "army": army, "army_members": own.slice(6, 12), "fleets": fleets, "wings": wings}

func _cards(main: Node, page: String) -> Array:
	match page:
		"construction": return main.hud.construction._buttons.values()
		"navy": return main.hud.navy._cards.values()
		"air": return main.hud.air._cards.values()
		"army", "army_detail":
			var cards := []
			for record: Dictionary in main.hud.army._selection_cards:
				if record.has("division"): cards.append(record["panel"])
			return cards
		"army_templates":
			var grid: GridContainer = main.hud.army.find_child("ArmyTemplateGrid", true, false)
			return grid.get_children() if grid else []
		"divisions": return main.hud.divisions._grid.get_children()
	return []

func _check_page(panel: Control, page: String, resolution: Vector2i, cards: Array) -> Dictionary:
	var bounds := panel.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
	if not viewport.grow(2).encloses(bounds): _errors.append("Panel overflow %s %s: %s" % [page, resolution, bounds])
	if not panel.is_visible_in_tree(): _errors.append("Page not visible: " + page)
	var report := {"page": page, "resolution": [resolution.x, resolution.y], "panel": _rect(bounds), "minimum": [panel.get_combined_minimum_size().x, panel.get_combined_minimum_size().y], "cards": []}
	var minimum := 3 if page in ["navy", "air"] else (6 if page in ["army", "army_detail", "divisions", "construction"] else 2)
	if cards.size() < minimum: _errors.append("Too few real %s cards: %d" % [page, cards.size()])
	if not cards.is_empty():
		var grid := _grid_ancestor(cards[0])
		if grid == null or grid.columns != 2: _errors.append("Roster is not a two-column GridContainer: " + page)
		report["grid_columns"] = grid.columns if grid else 0
		for card: Control in cards:
			var rect := card.get_global_rect()
			var card_grid := _grid_ancestor(card)
			report["cards"].append({"name": str(card.name), "rect": _rect(rect), "grid": str(card_grid.name) if card_grid else "", "selected": bool(card.get_meta("force_selected", card.get_meta("construction_selected", false)))})
			if card_grid == null or card_grid.columns != 2: _errors.append("Card is outside a two-column grid: %s/%s" % [page, card.name])
			if rect.position.x < bounds.position.x - 2 or rect.end.x > bounds.end.x + 2: _errors.append("Horizontal card overflow %s: %s" % [page, rect])
			_check_card_children(card, page)
		if cards.size() >= 2:
			var first: Rect2 = cards[0].get_global_rect()
			var second: Rect2 = cards[1].get_global_rect()
			if absf(first.position.y - second.position.y) > 1 or second.position.x < first.end.x - 1:
				_errors.append("First two cards are not side by side: " + page)
	if page == "construction":
		var catalog: Control = panel.get("_catalog_scroll")
		var queue: Control = panel.get("_queue_scroll")
		if catalog and queue:
			report["catalog_area"] = _rect(catalog.get_global_rect())
			report["queue_area"] = _rect(queue.get_global_rect())
			if queue.global_position.x < catalog.get_global_rect().end.x - 1: _errors.append("Construction queue is not beside its catalog")
			if not bounds.grow(2).encloses(catalog.get_global_rect()) or not bounds.grow(2).encloses(queue.get_global_rect()): _errors.append("Construction scroll areas escape panel")
		else: _errors.append("Construction independent scroll areas are missing")
	elif page in ["navy", "air"]:
		var details: VBoxContainer = panel.get("_details")
		var count := 0
		for child: Control in details.get_children():
			if bool(child.get_meta("selection_detail", false)):
				count += 1
				report["selected_detail"] = _rect(child.get_global_rect())
				if child.size.x < panel.get("_grid").size.x - 3: _errors.append("Selected operations are not full-width: " + page)
				if int(child.get_meta("selected_id", 0)) != int(panel.get("selected_id")): _errors.append("Selected detail belongs to a stale unit: " + page)
		if count != 1: _errors.append("Exactly one selected operations dossier expected: " + page)
	print("SELECTION_GRID_PAGE ", JSON.stringify(report))
	return report

func _check_card_children(card: Control, page: String) -> void:
	var bounds := card.get_global_rect()
	for node: Node in card.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.is_queued_for_deletion(): continue
		var rect := control.get_global_rect()
		if rect.position.x < bounds.position.x - 2 or rect.end.x > bounds.end.x + 2:
			_errors.append("Card child horizontal overflow %s/%s: %s" % [page, control.name, rect])

func _grid_ancestor(card: Control) -> GridContainer:
	var parent := card.get_parent()
	while parent:
		if parent is GridContainer: return parent
		parent = parent.get_parent()
	return null

func _scroll_ancestor(card: Control) -> ScrollContainer:
	var parent := card.get_parent()
	while parent:
		if parent is ScrollContainer: return parent
		parent = parent.get_parent()
	return null

func _rect(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.01), snappedf(rect.position.y, 0.01), snappedf(rect.size.x, 0.01), snappedf(rect.size.y, 0.01)]

func _capture(path: String) -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(path) != OK: _errors.append("Capture failed: " + path)

func _finish(catcher: Logger, folder: String) -> void:
	_errors.append_array(catcher.take())
	OS.remove_logger(catcher)
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder + "/report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "cases": _cases, "errors": _errors}, "\t"))
	else: _errors.append("Cannot save preview report")
	print("SELECTION_GRID_RESULT errors=", _errors)
	quit(0 if _errors.is_empty() else 1)
