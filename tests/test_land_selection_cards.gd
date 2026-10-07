extends "res://tests/test_case.gd"
## Live military members and production card callbacks; selection is never a movement/composition command.

func _fixture() -> Dictionary:
	var own := Military.country_divisions(World.player_tag)
	while own.size() < 6:
		own.append(Military._create(player(), 0, World.capital_province(World.player_tag), 1.0, 0))
	own = own.slice(0, 6)
	var a: Army = Military.create_army(World.player_tag, [own[0], own[1]])
	var b: Army = Military.create_army(World.player_tag, [own[2], own[3]])
	var group: ArmyGroup = Military.create_group(World.player_tag)
	Military.set_army_group(a, group.id)
	Military.set_army_group(b, group.id)
	for d: Division in own.slice(4): Military.set_division_army(d, 0)
	for i in own.size():
		var d: Division = own[i]
		d.path = PackedInt32Array([d.province, World.capital_province(World.player_tag)])
		d.progress = i + 0.25
		d.manual = i % 2 == 0
	var root := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var units := UnitLayer.new()
	units.process_mode = Node.PROCESS_MODE_DISABLED # Ready is safe; no camera/map rendering or animation.
	root.add_child(units)
	var army := ArmyPanel.new()
	army.units = units
	root.add_child(army)
	army.set_process(false)
	var division := DivisionPanel.new()
	division.units = units
	root.add_child(division)
	division.set_process(false)
	army.open()
	return {"root": root, "units": units, "army": army, "division": division,
		"own": own, "a": a, "b": b, "group": group}

func _ids(members: Array) -> Array:
	var out: Array = []
	for d: Division in members: out.append(d.id)
	out.sort()
	return out

func _record(panel: ArmyPanel, key: String) -> Dictionary:
	for record: Dictionary in panel._selection_cards:
		if record.get("key", "") == key: return record
	return {}

func _orders(f: Dictionary) -> Array:
	var out: Array = []
	for d: Division in f.own:
		out.append([d.id, d.army, d.path.duplicate(), d.progress, d.attacking, d.manual, d.hold])
	for a: Army in [f.a, f.b]:
		out.append([a.id, a.group, a.commander, a.mode, a.enemy, _ids(Military.army_divisions(a))])
	return out

func _cleanup(f: Dictionary) -> void:
	(f.root as Control).free()

func test_army_solo_additive_and_toggle_use_map_selection_without_commands() -> void:
	var f := _fixture()
	var panel: ArmyPanel = f.army
	var units: UnitLayer = f.units
	var before := _orders(f)
	panel._select_node("a:%d" % f.a.id, false, false)
	eq(_ids(units.selected), _ids([f.own[0], f.own[1]]), "solo army card selects exactly its members")
	panel._select_node("a:%d" % f.b.id, true, false)
	eq(_ids(units.selected), _ids(f.own.slice(0, 4)), "additive army card retains previous selection")
	panel._toggle_node("a:%d" % f.a.id)
	eq(_ids(units.selected), _ids([f.own[2], f.own[3]]), "checked army toggles off only its members")
	panel._select_node("g:%d" % f.group.id, false, false)
	eq(_ids(units.selected), _ids(f.own.slice(0, 4)), "group card selects the attached armies' members")
	eq(_orders(f), before, "selection cannot change routes, progress, manual orders or army/group composition")
	_cleanup(f)

func test_group_checkboxes_distinguish_none_partial_all_and_preserve_outsiders() -> void:
	var f := _fixture()
	var panel: ArmyPanel = f.army
	var units: UnitLayer = f.units
	var key := "g:%d" % f.group.id
	panel._sync_selection_cards()
	var record := _record(panel, key)
	if not check(not record.is_empty(), "group has a real selection card"):
		_cleanup(f)
		return
	check(not record.checkbox.button_pressed and not record.checkbox.partial, "none selected")
	units.select_divisions([f.own[0], f.own[5]], false)
	panel._sync_selection_cards()
	record = _record(panel, key)
	check(not record.checkbox.button_pressed and record.checkbox.partial, "partial group has indeterminate checkbox")
	check(record.panel.get_meta("force_partial") and not record.panel.get_meta("force_selected"), "partial styling matches actual map selection")
	panel._toggle_node(key)
	record = _record(panel, key)
	check(record.checkbox.button_pressed and not record.checkbox.partial, "partial toggle selects all group members")
	check(f.own[5] in units.selected, "group toggle keeps outside selected division")
	panel._toggle_node(key)
	record = _record(panel, key)
	check(not record.checkbox.button_pressed and not record.checkbox.partial, "second toggle deselects group")
	eq(_ids(units.selected), _ids([f.own[5]]), "deselecting group never clears unrelated selection")
	_cleanup(f)

func test_free_card_selects_only_live_unattached_members_without_assigning_them() -> void:
	var f := _fixture()
	var panel: ArmyPanel = f.army
	var units: UnitLayer = f.units
	var before := _orders(f)
	var free := panel._node_members("free")
	check(f.own[4] in free and f.own[5] in free, "unattached fixture divisions included")
	for d: Division in free: check(d.army == 0 and d.owner == World.player_tag, "free is not a hidden regroup command")
	units.select_divisions([f.own[0]], false)
	panel._select_node("free", true, false)
	var expected: Array = free.duplicate()
	expected.append(f.own[0])
	eq(_ids(units.selected), _ids(expected), "free card adds its members to selection")
	panel._toggle_node("free")
	eq(_ids(units.selected), _ids([f.own[0]]), "free checkbox removes only unattached members")
	eq(_orders(f), before, "free selection preserves assignments and movement")
	_cleanup(f)

func test_individual_cards_checkbox_solo_add_toggle_and_remove_preserve_orders() -> void:
	var f := _fixture()
	var panel: DivisionPanel = f.division
	var units: UnitLayer = f.units
	var before := _orders(f)
	units.select_divisions(f.own.slice(0, 3), false)
	panel._build_grid(units.selected)
	var tile: Control = panel._grid.get_child(1)
	eq(tile.get_meta("division_id"), f.own[1].id, "tile retains real division identity")
	var checkbox := tile.find_child("SelectionCheckbox", true, false) as Button
	check(checkbox != null and checkbox.button_pressed, "selected tile has explicit checked control")
	checkbox.pressed.emit()
	eq(_ids(units.selected), _ids([f.own[0], f.own[2]]), "checkbox toggles one division off")
	panel._select_tile(f.own[2], false, false)
	eq(_ids(units.selected), _ids([f.own[2]]), "plain card selects only that division")
	panel._select_tile(f.own[3], true, false)
	eq(_ids(units.selected), _ids([f.own[2], f.own[3]]), "modifier adds the card to selection")
	panel._select_tile(f.own[3], true, true)
	eq(_ids(units.selected), _ids([f.own[2]]), "modifier toggle removes only that card")
	panel._remove_tile(f.own[2])
	check(units.selected.is_empty(), "remove acts on selection, not division lifecycle")
	check(f.own[2] in Military.divisions, "remove never disbands a division")
	eq(_orders(f), before, "individual card callbacks do not alter movement or composition")
	_cleanup(f)

func test_stale_dead_foreign_and_changed_player_callbacks_are_rejected() -> void:
	var f := _fixture()
	var army: ArmyPanel = f.army
	var division: DivisionPanel = f.division
	var units: UnitLayer = f.units
	var foreign: Division = Military.country_divisions("GER")[0]
	var dead: Division = f.own[0]
	units.select_divisions([f.own[1]], false)
	Military.divisions.erase(dead)
	army._select_members([dead, foreign], false, false)
	eq(_ids(units.selected), _ids([f.own[1]]), "invalid captured army members cannot clear or replace live selection")
	division._select_tile(dead, false, false)
	division._select_tile(foreign, false, false)
	division._remove_tile(foreign)
	eq(_ids(units.selected), _ids([f.own[1]]), "dead/foreign individual callbacks are inert")
	var dead_tile: Control = division._tile(dead)
	var foreign_tile: Control = division._tile(foreign)
	check((dead_tile.find_child("SelectionCheckbox", true, false) as Button).disabled, "stale dead checkbox disabled")
	check((foreign_tile.find_child("SelectionCheckbox", true, false) as Button).disabled, "foreign checkbox disabled")
	dead_tile.free()
	foreign_tile.free()
	units.select_divisions([foreign], true)
	eq(_ids(units.selected), _ids([f.own[1]]), "map selection API also filters foreign membership")
	World.set_player("GER")
	check(units.selected.is_empty(), "player switch clears old country selection")
	army._select_members([f.own[1]], false, false)
	division._select_tile(f.own[1], false, false)
	check(units.selected.is_empty(), "old player's UI closure cannot reselect a now-foreign division")
	_cleanup(f)

func test_division_overlay_hides_while_army_panel_is_open_without_clearing_selection() -> void:
	var f := _fixture()
	var army: ArmyPanel = f.army
	var division: DivisionPanel = f.division
	var units: UnitLayer = f.units
	units.select_divisions(f.own.slice(0, 2), false)
	var selected := _ids(units.selected)
	check(army.visible and division._army_panel_open(), "command panel is an explicit sibling visibility gate")
	division._process(0.26)
	check(not division.visible, "right-hand division overlay cannot cover open command cards")
	eq(_ids(units.selected), selected, "hiding overlay preserves actual selected divisions")
	army.close()
	division._process(0.26)
	check(division.visible and not division._army_panel_open(), "closing army panel restores selected-division overlay")
	eq(_ids(units.selected), selected, "restore is not a selection reset")
	_cleanup(f)

func test_army_and_free_divisions_are_real_two_column_selection_grids() -> void:
	var f := _fixture()
	var panel: ArmyPanel = f.army
	var before := _orders(f)
	panel._sel = "a:%d" % f.a.id
	panel.refresh()
	var grid := panel.find_child("ArmyDivisionGrid", true, false) as GridContainer
	if check(grid != null, "attached divisions use a real grid container"):
		eq(grid.columns, 2, "army divisions are side by side")
		eq(grid.get_child_count(), 2, "one card per attached division")
		for tile: Control in grid.get_children():
			check(tile.has_meta("division_id"), "grid tiles retain live division identity")
			check(tile.find_child("SelectionCheckbox", true, false) is Button, "selection is explicit on every tile")
	panel._sel = "free"
	panel.refresh()
	grid = panel.find_child("FreeDivisionGrid", true, false) as GridContainer
	if check(grid != null, "unattached divisions also use a grid"):
		eq(grid.columns, 2, "unattached divisions are side by side")
		eq(grid.get_child_count(), panel._free_divisions(player()).size(), "unattached roster is complete")
	eq(_orders(f), before, "rendering a grid cannot issue orders or regroup troops")
	_cleanup(f)

func test_template_cards_select_the_designer_without_deploying_or_editing() -> void:
	var f := _fixture()
	var panel: ArmyPanel = f.army
	var c := player()
	var templates := c.templates.duplicate(true)
	var count := Military.country_divisions(c.tag).size()
	panel._switch_tab(1)
	var grid := panel.find_child("ArmyTemplateGrid", true, false) as GridContainer
	if check(grid != null, "templates share the two-column card layout"):
		eq(grid.columns, 2, "template grid is not a vertical list")
		eq(grid.get_child_count(), c.templates.size(), "all templates have a card")
		var index := c.templates.size() - 1
		var tile := grid.get_child(index) as Control
		var button := tile.find_child("TemplateSelectButton", true, false) as Button
		if check(button != null, "card header is a keyboard-accessible selection button"):
			button.pressed.emit()
			eq(panel._edit, index, "header changes the inspected template")
			var selected := panel.find_child("TemplateSelection_%d" % index, true, false) as Control
			check(selected != null and selected.get_meta("force_selected", false), "active template has selected styling")
	eq(c.templates, templates, "card selection is not a template edit")
	eq(Military.country_divisions(c.tag).size(), count, "card selection is not a deployment")
	_cleanup(f)
