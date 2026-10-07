extends "res://tests/test_case.gd"
## Compact selection grids contain real units; only the selected dossier issues orders.

func player_tag() -> String: return "GER"
func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _air() -> AirPanel:
	var c := player()
	while Air.wings_of(c.tag).size() < 3:
		c.stockpile[Air.TYPES["fighter"]["eq"]] = 1000.0
		if Air.deploy(c, "fighter", Air._home_base(c.tag)) == null: break
	var panel := AirPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	return panel

func _navy() -> NavyPanel:
	var panel := NavyPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	return panel

func _button(parent: Node, caption: String) -> Button:
	for child: Node in parent.find_children("*", "Button", true, false):
		if (child as Button).text == caption: return child as Button
	return null

func _detail(parent: Node) -> PanelContainer:
	for child: Node in parent.get_children():
		if child.get_meta("selection_detail", false): return child as PanelContainer
	return null

func _wing_orders(w: AirWing) -> Array:
	return [w.mission, w.zone, w.base, w.planes, w.auto]

func _fleet_orders(f: Fleet) -> Array:
	return [f.mission, f.zone_center, Array(f.path), f.progress, f.returning]

func _assert_grid(grid: GridContainer, cards: Dictionary) -> void:
	eq(grid.columns, 2, "roster always has two side-by-side columns")
	eq(grid.get_child_count(), cards.size(), "each real unit has exactly one roster cell")
	for card: ForceSelectionCard in cards.values():
		eq(card.get_parent(), grid, "all cards share the actual GridContainer")
		check(bool(card.get_meta("force_compact", false)), "roster cell uses compact mode")
		eq(card.find_children("*", "Button", true, false).size(), 2, "only header and checkbox are inside a compact cell")
		eq(card.title_label.get_theme_font_size("font_size"), UiTheme.fs(16), "compact names remain readable, not miniature type")
		check(card.select_button.tooltip_text.contains(card.title_label.text), "full real unit name survives clipping in tooltip")

func test_compact_mode_keeps_skin_selection_audio_and_default_mode_contract() -> void:
	var card := ForceSelectionCard.new()
	card.configure("A deliberately long unit name", "Real unit status", null, true)
	card.set_compact()
	var art := card.find_child("ForceThumbnail", true, false) as TextureRect
	check(art.get_parent() is VBoxContainer, "unit image and labels stack vertically")
	eq(art.get_index(), 0, "unit image precedes name and status")
	eq(art.custom_minimum_size.y, 60.0, "compact illustration does not inflate roster cards")
	eq(card.custom_minimum_size.y, 116.0, "compact cells have a bounded overview height")
	check(card.get_meta("force_selected") and card.toggle_button.button_pressed, "compact conversion preserves selection")
	check(card.get_theme_stylebox("panel").get("surface") != null, "existing generated gunmetal/gold skin remains")
	check(card.select_button.get_meta("audio_silent") and card.toggle_button.get_meta("audio_silent"), "compact surfaces retain single-owner selection audio")
	card.set_selected(false)
	check(not card.toggle_button.button_pressed, "deselection remains available")
	card.set_compact(false)
	eq(card.select_button.custom_minimum_size.y, 158.0, "noncompact header reserves image above labels")
	card.free()

func test_navy_cells_are_selection_only_and_one_selected_dossier_retains_actions() -> void:
	var panel := _navy()
	var own := Navy.fleets_of(player_tag())
	if not check(own.size() >= 2, "fixture has multiple real own fleets"):
		panel.free()
		return
	_assert_grid(panel._grid, panel._cards)
	check(_detail(panel._details) == null, "no operations dossier is invented before selection")
	var before := _fleet_orders(own[0])
	var card: ForceSelectionCard = panel._cards[own[0].id]
	var instance := card.get_instance_id()
	card.select_button.pressed.emit()
	eq((panel._cards[own[0].id] as ForceSelectionCard).get_instance_id(), instance, "selection paints in place, not by rebuilding the entire grid")
	eq(_fleet_orders(own[0]), before, "choosing a compact cell does not issue any order")
	var detail := _detail(panel._details)
	if check(detail != null, "one full-width selected-fleet dossier exists"):
		eq(int(detail.get_meta("selected_id")), own[0].id, "operations belong to the actual selected fleet")
		check(_button(detail, tr("NAVY_PICK_ZONE")) != null, "zone picker is preserved below the grid")
		for i in 4: check(_button(detail, tr("MISSION_%d" % i)) != null, "all four actual fleet missions remain available")
	panel.clear_selection(false)
	check(_detail(panel._details) == null, "clear selection removes operational commands")
	panel.free()

func test_air_target_and_roster_grids_mirror_one_selection_with_orders_outside_cells() -> void:
	var panel := _air()
	var own := Air.wings_of(player_tag())
	panel.set_target(World.capital_province(player_tag()))
	_assert_grid(panel._grid, panel._cards)
	_assert_grid(panel._target_grid, panel._target_cards)
	var w: AirWing = own[1]
	var before := _wing_orders(w)
	(panel._target_cards[w.id] as ForceSelectionCard).toggle_button.pressed.emit()
	eq(panel.selected_id, w.id, "target cell and main roster share the same selected ID")
	check(panel._cards[w.id].get_meta("force_selected") and panel._target_cards[w.id].get_meta("force_selected"), "both visual copies show the same selection")
	eq(_wing_orders(w), before, "selection cannot assign the currently highlighted target")
	var detail := _detail(panel._details)
	var target_detail := _detail(panel._target_details)
	if check(detail != null and target_detail != null, "selected operations exist below both grids"):
		eq(int(detail.get_meta("selected_id")), w.id, "main operations refer to selected wing")
		eq(int(target_detail.get_meta("selected_id")), w.id, "target operations refer to that same selected wing")
		var missions := detail.find_child("WingMissionChoices", true, false) as GridContainer
		check(missions != null and missions.columns == 2 and missions.get_child_count() == 6, "six actual wing missions remain readable in a 2x3 detail grid")
		for m: AirWing.Mission in AirPanel.TARGET_MISSIONS:
			check(_button(target_detail, tr("AIR_MISSION_%d" % int(m))) != null, "selected target retains its actual mission action")
	panel.clear_selection(false)
	check(_detail(panel._details) == null and _detail(panel._target_details) == null, "clearing selection removes both mirrored operation dossiers")
	panel.free()

func test_old_operation_callbacks_cannot_issue_orders_after_selection_changes() -> void:
	var air := _air()
	var wings := Air.wings_of(player_tag())
	air.set_target(World.capital_province(player_tag()))
	air.select(wings[0])
	var old_pick := _button(air._details, tr("AIR_PICK_ZONE"))
	var old_mission := _button(air._target_details, tr("AIR_MISSION_1"))
	var picks: Array = []
	air.pick_zone_requested.connect(func(w: AirWing) -> void: picks.append(w))
	var before := _wing_orders(wings[0])
	air.select(wings[1])
	old_pick.pressed.emit()
	old_mission.pressed.emit()
	eq(picks, [], "captured old wing controls cannot target an unselected wing")
	eq(_wing_orders(wings[0]), before, "captured old target mission cannot mutate an unselected wing")
	air.free()
	var navy := _navy()
	var fleets := Navy.fleets_of(player_tag())
	navy.select(fleets[0])
	old_pick = _button(navy._details, tr("NAVY_PICK_ZONE"))
	old_mission = _button(navy._details, tr("MISSION_1"))
	navy.pick_zone_requested.connect(func(f: Fleet) -> void: picks.append(f))
	var fleet_before := _fleet_orders(fleets[0])
	navy.select(fleets[1])
	old_pick.pressed.emit()
	old_mission.pressed.emit()
	eq(picks, [], "captured old fleet picker cannot target an unselected fleet")
	eq(_fleet_orders(fleets[0]), fleet_before, "captured old fleet mission leaves its orders untouched")
	navy.free()

func test_grid_minimums_fit_side_panel_at_720_and_1080_without_font_shrink() -> void:
	var air := _air()
	var navy := _navy()
	var previous := _tree().root.size
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		_tree().root.size = size
		for panel: PanelContainer in [air, navy]:
			panel.refresh()
			PanelLayout.fit_full(panel)
			var grid: GridContainer = panel._grid
			le_grid_width(grid, panel)
			lt(panel.get_combined_minimum_size().x, 650.0, "two columns cannot force a full-width window or overflow the intended 625 px sidebar")
			for card: ForceSelectionCard in panel._cards.values():
				eq(card.title_label.get_theme_font_size("font_size"), UiTheme.fs(16), "same readable card typography at both viewport sizes")
	_tree().root.size = previous
	air.free()
	navy.free()

func le_grid_width(grid: GridContainer, panel: PanelContainer) -> void:
	check(grid.get_combined_minimum_size().x <= panel.custom_minimum_size.x - 30.0, "compact grid minimum width fits its native scroll body")
