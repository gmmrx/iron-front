extends "res://tests/test_case.gd"
## Naval/air selection is an explicit visual state, never an operational order.

func player_tag() -> String: return "GER"

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _dispose(panel: Control) -> void:
	if panel.is_inside_tree(): panel.get_parent().remove_child(panel)
	panel.free()

func _navy() -> NavyPanel:
	var panel := NavyPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	return panel

func _air() -> AirPanel:
	var c := player()
	var own := Air.wings_of(c.tag)
	while own.size() < 2:
		c.stockpile[Air.TYPES["fighter"]["eq"]] = 1000.0
		if Air.deploy(c, "fighter", Air._home_base(c.tag)) == null: break
		own = Air.wings_of(c.tag)
	var panel := AirPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	return panel

func _button(parent: Node, caption: String) -> Button:
	for node: Node in parent.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == caption: return node as Button
	return null

func _fleet_orders(f: Fleet) -> Dictionary:
	return {"mission": f.mission, "zone": f.zone_center, "path": Array(f.path), "progress": f.progress, "returning": f.returning}

func _wing_orders(w: AirWing) -> Dictionary:
	return {"mission": w.mission, "zone": w.zone, "base": w.base, "planes": w.planes, "auto": w.auto}

func _assert_card(card: ForceSelectionCard, selected: bool, context: String) -> void:
	eq(bool(card.get_meta("force_selected")), selected, context + ": selected surface state")
	eq(card.toggle_button.button_pressed, selected, context + ": checkbox/checkmark state")
	check(not bool(card.get_meta("force_partial")), context + ": fleet/wing is a single, not partial selection")
	check(card.get_theme_stylebox("panel").get("surface") != null, context + ": existing CommandPanelSkin artwork remains in use")

func test_navy_map_sync_click_toggle_and_clear_never_issue_orders() -> void:
	var panel := _navy()
	var own := Navy.fleets_of(player_tag())
	if not check(own.size() >= 2, "fixture has two own fleets"):
		_dispose(panel)
		return
	var first: Fleet = own[0]
	var second: Fleet = own[1]
	var before_first := _fleet_orders(first)
	var before_second := _fleet_orders(second)
	var selected: Array = []
	panel.fleet_selected.connect(func(f: Fleet) -> void: selected.append(f))
	panel.select(first)
	eq(selected.size(), 0, "map synchronization never emits a second selection command")
	_assert_card(panel._cards[first.id], true, "map-selected fleet")
	_assert_card(panel._cards[second.id], false, "unselected fleet")
	(panel._cards[second.id] as ForceSelectionCard).select_button.pressed.emit()
	eq(panel.selected_id, second.id, "clicking a header selects exactly that fleet")
	_assert_card(panel._cards[first.id], false, "old fleet")
	_assert_card(panel._cards[second.id], true, "new fleet")
	eq(selected.size(), 1, "one click emits exactly one map selection signal")
	(panel._cards[second.id] as ForceSelectionCard).toggle_button.pressed.emit()
	eq(panel.selected_id, 0, "clicking a selected checkbox deselects")
	check(selected.size() == 2 and selected[1] == null, "deselect synchronizes the map with a null fleet")
	_assert_card(panel._cards[second.id], false, "cleared checkbox")
	panel.select(first)
	panel._clear_selection_button.pressed.emit()
	eq(panel.selected_id, 0, "explicit clear-selection button works")
	check(panel._clear_selection_button.disabled, "empty selection disables redundant clear action")
	eq(_fleet_orders(first), before_first, "select/deselect/map sync does not issue a fleet order")
	eq(_fleet_orders(second), before_second, "selection never changes another fleet's mission/path")
	_dispose(panel)

func test_navy_action_buttons_do_not_change_selection_or_bubble_to_header() -> void:
	var panel := _navy()
	var own := Navy.fleets_of(player_tag())
	if not check(own.size() >= 2, "two naval cards exist"):
		_dispose(panel)
		return
	panel.select(own[0])
	var card: ForceSelectionCard = panel._cards[own[1].id]
	var selection_signals: Array = []
	var pick_requests: Array = []
	panel.fleet_selected.connect(func(f: Fleet) -> void: selection_signals.append(f))
	panel.pick_zone_requested.connect(func(f: Fleet) -> void: pick_requests.append(f))
	check(_button(card, tr("MISSION_0")) == null, "small fleet cards carry no operational commands")
	var mission := _button(panel._details, tr("MISSION_0"))
	if check(mission != null, "selected fleet retains its port mission in the full-width detail"):
		eq(mission.mouse_filter, Control.MOUSE_FILTER_STOP, "operation button consumes its own input")
		mission.pressed.emit()
	eq(panel.selected_id, own[0].id, "selected-detail mission leaves explicit selection alone")
	eq(selection_signals.size(), 0, "mission action does not emit a selection signal")
	card = panel._cards[own[1].id]
	var pick := _button(panel._details, tr("NAVY_PICK_ZONE"))
	if check(pick != null, "fleet retains its zone picker"):
		pick.pressed.emit()
	eq(panel.selected_id, own[0].id, "zone-picker action does not hijack selection")
	check(pick_requests.size() == 1 and pick_requests[0] == own[0], "zone picker refers to the actual selected fleet")
	eq(card.get_signal_connection_list("gui_input").size(), 0, "card body has no bubbling selection listener")
	_dispose(panel)

func test_navy_refresh_persists_selection_and_closed_panel_prunes_dead_or_foreign_ids() -> void:
	var panel := _navy()
	var own := Navy.fleets_of(player_tag())
	if not check(not own.is_empty(), "naval card exists"):
		_dispose(panel)
		return
	var chosen: Fleet = own[0]
	panel.select(chosen)
	panel.refresh()
	eq(panel.selected_id, chosen.id, "refresh preserves a live selection ID")
	_assert_card(panel._cards[chosen.id], true, "refreshed selected fleet")
	var other := Navy.fleets_of("ENG")
	if not other.is_empty():
		panel.select(other[0])
		eq(panel.selected_id, 0, "programmatic sync refuses a foreign fleet")
	panel.select(chosen)
	panel.close()
	var index := Navy.fleets.find(chosen)
	Navy.fleets.erase(chosen)
	Navy.fleets_changed.emit()
	eq(panel.selected_id, 0, "destroyed fleet is pruned even while the panel is closed")
	panel.open()
	check(not panel._cards.has(chosen.id), "refreshed list contains no destroyed selection surface")
	Navy.fleets.insert(index, chosen)
	_dispose(panel)

func test_air_header_toggle_and_clear_are_order_free_and_single_selection() -> void:
	var panel := _air()
	var own := Air.wings_of(player_tag())
	if not check(own.size() >= 2, "fixture has two own wings"):
		_dispose(panel)
		return
	var before: Array = [_wing_orders(own[0]), _wing_orders(own[1])]
	var signals: Array = []
	panel.wing_selected.connect(func(w: AirWing) -> void: signals.append(w))
	panel.select(own[0])
	eq(signals.size(), 0, "external wing sync has no order/selection side effect")
	_assert_card(panel._cards[own[0].id], true, "selected wing")
	(panel._cards[own[1].id] as ForceSelectionCard).select_button.pressed.emit()
	eq(panel.selected_id, own[1].id, "wing header selects its actual ID")
	_assert_card(panel._cards[own[0].id], false, "other wing deselected")
	_assert_card(panel._cards[own[1].id], true, "wing selected by click")
	(panel._cards[own[1].id] as ForceSelectionCard).toggle_button.pressed.emit()
	eq(panel.selected_id, 0, "selected wing checkbox can be cleared")
	panel.select(own[0])
	panel._clear_selection_button.pressed.emit()
	eq(panel.selected_id, 0, "wing clear-selection action works")
	eq(_wing_orders(own[0]), before[0], "selection changes no mission/base/planes/AI state")
	eq(_wing_orders(own[1]), before[1], "selection does not mutate another wing")
	_dispose(panel)

func test_air_actions_refresh_and_destroyed_wing_keep_explicit_selection_contract() -> void:
	var panel := _air()
	var own := Air.wings_of(player_tag())
	if not check(own.size() >= 2, "two wing cards exist"):
		_dispose(panel)
		return
	panel.select(own[0])
	var selections: Array = []
	var picks: Array = []
	panel.wing_selected.connect(func(w: AirWing) -> void: selections.append(w))
	panel.pick_zone_requested.connect(func(w: AirWing) -> void: picks.append(w))
	var card: ForceSelectionCard = panel._cards[own[1].id]
	check(_button(card, tr("AIR_MISSION_0")) == null, "small wing cards carry no operational commands")
	var mission := _button(panel._details, tr("AIR_MISSION_0"))
	if check(mission != null, "selected wing retains its idle mission control"): mission.pressed.emit()
	eq(panel.selected_id, own[0].id, "selected-detail mission does not change selection")
	eq(selections.size(), 0, "mission emits no selection signal")
	card = panel._cards[own[1].id]
	var pick := _button(panel._details, tr("AIR_PICK_ZONE"))
	if check(pick != null, "wing retains zone picker"): pick.pressed.emit()
	check(picks.size() == 1 and picks[0] == own[0], "wing picker targets the actual selected wing")
	eq(panel.selected_id, own[0].id, "picker leaves current wing selected")
	panel.refresh()
	_assert_card(panel._cards[own[0].id], true, "wing selection persists through refresh")
	panel.close()
	var index := Air.wings.find(own[0])
	Air.wings.erase(own[0])
	Air.wings_changed.emit()
	eq(panel.selected_id, 0, "destroyed wing is pruned even from a closed panel")
	panel.open()
	check(not panel._cards.has(own[0].id), "destroyed wing no longer has a card")
	Air.wings.insert(index, own[0])
	_dispose(panel)

func test_target_wing_cards_mirror_roster_selection_without_issuing_target_orders() -> void:
	var panel := _air()
	var own := Air.wings_of(player_tag())
	if not check(own.size() >= 2, "target fixture has two wings"):
		_dispose(panel)
		return
	panel.set_target(World.capital_province(player_tag()))
	eq(panel._target_cards.size(), own.size(), "every target-order wing has the same explicit selection card")
	panel.select(own[0])
	_assert_card(panel._target_cards[own[0].id], true, "selected target row")
	_assert_card(panel._cards[own[0].id], true, "selected roster row")
	var before := _wing_orders(own[1])
	(panel._target_cards[own[1].id] as ForceSelectionCard).select_button.pressed.emit()
	eq(panel.selected_id, own[1].id, "target header changes only the shared single-wing selection")
	_assert_card(panel._target_cards[own[0].id], false, "old target row unchecked")
	_assert_card(panel._cards[own[1].id], true, "target selection mirrored in roster")
	eq(_wing_orders(own[1]), before, "target-row selection never assigns the highlighted mission zone")
	var target: ForceSelectionCard = panel._target_cards[own[0].id]
	check(_button(target, tr("AIR_MISSION_1")) == null, "target cards are selection-only, not crowded with orders")
	var mission := _button(panel._target_details, tr("AIR_MISSION_1"))
	if check(mission != null, "selected target detail retains its superiority mission action"):
		mission.pressed.emit()
	eq(panel.selected_id, own[1].id, "explicit target mission action does not hijack the selected wing")
	_assert_card(panel._target_cards[own[1].id], true, "target selection survives order-triggered refresh")
	panel.clear_selection()
	for card: ForceSelectionCard in panel._target_cards.values():
		_assert_card(card, false, "cleared target section")
	panel.set_target(0)
	eq(panel._target_cards.size(), 0, "clearing the target removes its stale mirrored card collection")
	_dispose(panel)
