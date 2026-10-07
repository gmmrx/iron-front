extends "res://tests/test_case.gd"
## Construction selection remains map intent; queue controls act on project identity, not stale row indices.

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _panel(parent: Node = null) -> ConstructionPanel:
	var panel := ConstructionPanel.new()
	(parent if parent else _tree().root).add_child(panel)
	panel.open()
	return panel

func _dispose(panel: ConstructionPanel) -> void:
	if panel.is_inside_tree(): panel.get_parent().remove_child(panel)
	panel.free()

func _queue_projects(count: int = 3) -> Array:
	var c := player()
	for b: String in ["civilian_factory", "military_factory", "infrastructure", "air_base", "anti_air"]:
		for sid: int in World.states:
			var state: StateRegion = World.states[sid]
			if state.owner == c.tag and Economy.can_build(c, state, b) == "":
				Economy.queue_building(c, state, b)
				break
		if c.construction_queue.size() >= count: break
	check(c.construction_queue.size() >= count, "real economy supplies construction queue fixture")
	return c.construction_queue.duplicate()

func _action(card: Node, name: String) -> Button:
	for node: Node in card.find_children("*", "Button", true, false):
		if str(node.get_meta("queue_action", "")) == name: return node as Button
	return null

func test_all_current_buildable_definitions_are_readable_side_by_side_cards() -> void:
	var panel := _panel()
	eq(panel._building_grid.columns, 2, "two readable side-by-side cards replace four cramped tiles")
	var actual: Array = panel._buttons.keys()
	actual.sort()
	var expected: Array = Economy.defs.keys()
	expected.sort()
	eq(actual, expected, "every enabled building definition has a real selection card")
	check(not panel._buttons.has("dockyard") and not panel._buttons.has("synthetic_refinery"), "disabled ship-production/fuel mechanics are not reintroduced")
	for b: String in panel._buttons:
		var card: Button = panel._buttons[b]
		check(card.get_parent() == panel._building_grid, "all building surfaces belong to one actual grid")
		check(card.toggle_mode and card.focus_mode == Control.FOCUS_ALL, "building card supports mouse and keyboard selection")
		check(card.custom_minimum_size.x >= 190, "card has room for name and cost")
		eq((card.find_child("BuildingName", true, false) as Label).text, Economy.building_name(b), "correct building name")
		eq((card.find_child("BuildingCost", true, false) as Label).text, UiTheme.format_number(Economy.defs[b]["cost"]), "real economy cost is displayed")
		check(not card.tooltip_text.is_empty(), "card retains description and factory-day cost tooltip")
		check(card.get_theme_stylebox("pressed").get("surface") != null, "selected state retains existing black-gold CommandPanelSkin artwork")
	_dispose(panel)

func test_card_selection_is_single_clear_and_never_queues_a_building() -> void:
	var panel := _panel()
	var requests: Array[String] = []
	panel.building_selected.connect(func(b: String) -> void: requests.append(b))
	var before := player().construction_queue.duplicate()
	(panel._buttons["air_base"] as Button).pressed.emit()
	eq(panel.selected, "air_base", "click selects the intended building")
	check((panel._checks["air_base"] as Button).button_pressed, "selected card shows a real checkmark")
	check(bool((panel._buttons["air_base"] as Button).get_meta("construction_selected")), "selected card exposes a stable visual state")
	(panel._buttons["naval_base"] as Button).pressed.emit()
	eq(requests, ["air_base", "naval_base"], "switching selection emits no intermediate empty intent")
	check(not (panel._checks["air_base"] as Button).button_pressed, "old checkmark clears")
	panel.refresh()
	eq(panel.selected, "naval_base", "queue/summary refresh preserves selected building")
	check((panel._buttons["naval_base"] as Button).button_pressed, "refresh preserves the selected native button")
	(panel._buttons["naval_base"] as Button).pressed.emit()
	eq(panel.selected, "", "clicking checked building deselects")
	(panel._buttons["military_factory"] as Button).pressed.emit()
	panel.close()
	eq(panel.selected, "", "closing clears map construction mode")
	eq(requests.back(), "", "closing emits the existing empty building_selected contract")
	check(not (panel._checks["military_factory"] as Button).button_pressed, "closing clears visible check state")
	eq(player().construction_queue, before, "selection/deselection/close cannot issue construction orders")
	_dispose(panel)

func test_queue_cards_show_real_progress_allocation_days_and_accessible_controls() -> void:
	var projects := _queue_projects()
	var p: ConstructionProject = projects[0]
	p.progress = p.cost * 0.45
	p.last_daily = 12.0
	var panel := _panel()
	eq(panel._queue_box.get_child_count(), player().construction_queue.size(), "one queue card per real construction project")
	for i in player().construction_queue.size():
		var card := panel._queue_box.get_child(i)
		var project: ConstructionProject = player().construction_queue[i]
		eq(card.get_meta("construction_project"), project, "card retains exact project identity")
		eq(card.get_meta("project_index"), i, "priority index is explicit")
		var progress := card.find_child("ProjectProgress", true, false) as Label
		eq(progress.text, "%d%%" % roundi(project.fraction() * 100), "visible percentage matches actual project progress")
		var info := card.find_child("ProjectAllocation", true, false) as Label
		var days := project.days_left() if project.assigned_factories > 0 else -1
		eq(info.text, tr("CONSTRUCTION_ROW") % [project.assigned_factories, str(days) if days >= 0 else "—"], "real factory allocation and finite/waiting days are visible")
		for action: String in ["up", "down", "close"]:
			var button := _action(card, action)
			if check(button != null, "queue retains " + action + " action"):
				check(button.custom_minimum_size.x >= 36 and button.custom_minimum_size.y >= 36, "queue control has an accessible hit target")
				eq(button.focus_mode, Control.FOCUS_ALL, "queue control is keyboard focusable")
				check(not button.tooltip_text.is_empty(), "queue control explains its action")
		check(_action(card, "up").disabled == (i == 0), "first queue item cannot move above first")
		check(_action(card, "down").disabled == (i + 1 == player().construction_queue.size()), "last queue item cannot move below last")
	_dispose(panel)

func test_queue_controls_follow_identity_after_refresh_and_do_not_change_building_selection() -> void:
	var projects := _queue_projects()
	var c := player()
	var p: ConstructionProject = projects[0]
	var panel := _panel()
	(panel._buttons["anti_air"] as Button).pressed.emit()
	var requests: Array[String] = []
	panel.building_selected.connect(func(b: String) -> void: requests.append(b))
	var old_card := panel._queue_box.get_child(0)
	var down := _action(old_card, "down")
	var remove := _action(old_card, "close")
	down.pressed.emit()
	eq(c.construction_queue.find(p), 1, "first click moves the actual project down")
	down.pressed.emit()
	eq(c.construction_queue.find(p), 2, "old queued-for-deletion callback still follows the same project, not a new occupant of its index")
	remove.pressed.emit()
	check(p not in c.construction_queue, "cancel removes the intended project")
	var remaining := c.construction_queue.duplicate()
	remove.pressed.emit()
	eq(c.construction_queue, remaining, "stale cancel cannot remove a different project")
	eq(panel.selected, "anti_air", "queue actions never hijack map building selection")
	eq(requests, [], "queue controls never emit building-selection input")
	panel.refresh()
	panel.refresh()
	eq(panel._queue_box.get_child_count(), remaining.size(), "rapid refresh immediately detaches stale cards instead of accumulating them")
	_dispose(panel)

func test_720p_keeps_only_summary_fixed_and_independently_scrolls_catalog_and_queue() -> void:
	_queue_projects()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	_tree().root.add_child(viewport)
	var panel := _panel(viewport)
	panel.position = Vector2(PanelLayout.SIDE_LEFT, PanelLayout.SIDE_TOP)
	# The synchronous runner has no layout frame: settle native containers in the
	# same parent-before-child order as the renderer before checking wrapped text.
	for i in 6:
		panel.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)
		PanelLayout.fit_full(panel)
	PanelLayout.fit_full(panel)
	var rect := panel.get_global_rect()
	if rect.end.y > 720:
		for node: Node in panel.find_children("*", "Container", true, false):
			if node is ScrollContainer or node == panel.get_meta("body") or node == panel.get_meta("fixed"):
				print("CON_LAYOUT ", node.name, " min=", (node as Control).get_combined_minimum_size(), " size=", (node as Control).size)
	check(rect.end.x <= 1280 and rect.end.y <= 720, "construction panel stays inside1280×720: rect=%s viewport=%s min=%s" % [rect, panel.get_viewport_rect(), panel.get_combined_minimum_size()])
	check(panel.get_meta("fixed") is VBoxContainer, "summary remains a fixed top row")
	check(not (panel.get_meta("fixed") as Node).is_ancestor_of(panel._building_grid), "large building catalog cannot enlarge the fixed header")
	check(not (panel.get_meta("fixed") as Node).is_ancestor_of(panel._queue_box), "queue length cannot enlarge the fixed header")
	check(panel._catalog_scroll != panel._queue_scroll, "catalog and queue have independent scrolling")
	check(panel._catalog_scroll.is_ancestor_of(panel._building_grid), "building grid is inside the catalog scroll")
	check(panel._queue_scroll.is_ancestor_of(panel._queue_box), "queue cards are inside the queue scroll")
	panel._queue_scroll.set_meta("scroll_restore_value", 83)
	panel.refresh()
	panel.refresh()
	eq(panel._queue_scroll.get_meta("scroll_restore_value"), 83, "daily/reentrant refresh preserves pending queue scroll position")
	_dispose(panel)
	viewport.free()
