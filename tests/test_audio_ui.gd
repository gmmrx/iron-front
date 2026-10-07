extends "res://tests/test_case.gd"
## Semantic UI cues: actual presses only; rebuild/synchronization is silent.

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _listen() -> Dictionary:
	var keys: Array[String] = []
	var callback := func(key: String) -> void: keys.append(key)
	Audio.cue_requested.connect(callback)
	Audio.test_mode = true
	Audio.reset_effect_state()
	return {"heard": keys, "callback": callback}

func _reset(log: Dictionary) -> void:
	(log.heard as Array).clear()
	Audio.reset_effect_state()

func _stop(log: Dictionary) -> void:
	Audio.cue_requested.disconnect(log.callback)
	Audio.reset_effect_state()
	Audio.test_mode = false

func _research_key(id: String, phase: String, log: Dictionary) -> String:
	_reset(log)
	Audio.research_cue(id, phase)
	var key := str(log.heard[0]) if log.heard.size() == 1 else ""
	check(key != "", "research %s resolves one actual semantic key" % phase)
	_reset(log)
	return key

func _button(parent: Node, meta: String, value: String) -> Button:
	for node: Node in parent.find_children("*", "Button", true, false):
		if str(node.get_meta(meta, "")) == value: return node as Button
	return null

func test_force_selection_surfaces_delegate_audio_to_actual_selection_owner() -> void:
	var card := ForceSelectionCard.new()
	card.configure("Army", "Selection, not an order", null, false)
	var calls: Array[int] = []
	card.selection_requested.connect(func() -> void: calls.append(1))
	_tree().root.add_child(card)
	var log := _listen()
	check(bool(card.select_button.get_meta("audio_silent", false)), "force header suppresses generic click/hover")
	check(bool(card.toggle_button.get_meta("audio_silent", false)), "checkbox suppresses generic click/hover")
	card.select_button.pressed.emit()
	card.toggle_button.pressed.emit()
	eq(calls.size(), 2, "selection callbacks still fire once per surface")
	card.set_selected(true)
	card.set_selected(false)
	eq(log.heard, [], "card painting and ownerless selection do not invent a second sound")
	_stop(log)
	card.free()

func test_research_refresh_is_silent_and_user_catalog_selection_has_one_cue() -> void:
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel.visible = true
	panel._set_branch("all")
	var log := _listen()
	panel.refresh()
	eq(log.heard, [], "catalog/slot rebuild and automatic initial dossier are silent")
	if not check(not panel._nodes.is_empty(), "real research cards exist"):
		_stop(log)
		panel.free()
		return
	var id: String = panel._nodes.keys()[0]
	var expected := _research_key(id, "select", log)
	var card: Button = panel._nodes[id]
	check(bool(card.get_meta("audio_silent", false)), "research card suppresses the generic click")
	card.pressed.emit()
	eq(log.heard, [expected], "one press emits exactly that project's select cue")
	_reset(log)
	panel.refresh()
	eq(log.heard, [], "preserving an already selected project during refresh is silent")
	_stop(log)
	panel.free()

func test_research_actions_use_only_accepted_core_start_and_cancel_cues() -> void:
	var c := player()
	var id := ""
	for candidate: String in Research.techs:
		if not Research.is_government_project(candidate) and not Research.is_repeat(candidate) and Research.can_start_reason(c, candidate) == "":
			id = candidate
			break
	if not check(id != "", "fixture has a startable normal project"): return
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel.visible = true
	panel._set_branch("all")
	panel._selected = id
	panel._refresh_detail()
	var log := _listen()
	var start_key := _research_key(id, "start", log)
	check(bool(panel._start_button.get_meta("audio_silent", false)), "start CTA waits for core acceptance")
	panel._start_button.pressed.emit()
	check(ResearchPanel._active(c, id), "actual project started")
	eq(log.heard, [start_key], "accepted start has one semantic cue, no generic press/watcher echo")
	var inspect := _button(panel._slots, "tech_id", id)
	if check(inspect != null, "active slot retains a project-specific inspection control"):
		var select_key := _research_key(id, "select", log)
		inspect.pressed.emit()
		eq(log.heard, [select_key], "slot inspection emits one project select cue despite rebuilding itself")
	var cancel_key := _research_key(id, "cancel", log)
	panel._start_button.pressed.emit()
	check(not ResearchPanel._active(c, id), "actual project cancelled")
	eq(log.heard, [cancel_key], "accepted cancellation has one semantic cue")
	_stop(log)
	panel.free()

func test_menu_country_and_notification_buttons_bind_distinct_semantic_keys() -> void:
	var menu := MainMenu.new()
	_tree().root.add_child(menu)
	for key: String in ["menu_new_game", "menu_tutorial", "menu_continue", "menu_settings", "menu_quit"]:
		check(_button(menu, "audio_cue", key) != null, "main menu has a distinct " + key + " binding")
	var log := _listen()
	var new_game := _button(menu, "audio_cue", "menu_new_game")
	if not check(new_game != null, "new-game button is actually bound"):
		_stop(log)
		menu.free()
		return
	var calls: Array[int] = []
	menu.new_game_pressed.connect(func() -> void: calls.append(1))
	new_game.pressed.emit()
	eq(calls.size(), 1, "menu's actual new-game callback remains intact")
	eq(log.heard, ["menu_new_game"], "new game uses its semantic key without generic click")
	menu.free()
	var selection := CountrySelect.new()
	_tree().root.add_child(selection)
	_reset(log)
	selection.select("TUR")
	eq(log.heard, [], "programmatic country preview is silent")
	(selection._cards["GER"] as Button).pressed.emit()
	eq(log.heard, ["country_select"], "actual country card press has one selection cue")
	eq(str(selection._start.get_meta("audio_cue", "")), "game_start", "start confirmation has its own cue")
	check(_button(selection, "audio_cue", "menu_close") != null, "country-screen back uses close cue")
	selection.free()
	var alerts := AlertBar.new()
	# Actual alert actions call Hud._toggle -> Audio.panel(true). That default
	# panel cue must not stack with the button's semantic notification cue.
	var tile := alerts._tile(["research", "research", "warn", "Research", "Details", func() -> void:
		Audio.panel(true)
		calls.append(1)])
	_tree().root.add_child(tile)
	_reset(log)
	tile.pressed.emit()
	eq(log.heard, ["notification_open"], "opening an alert is distinct from spawning a notification")
	eq(calls.size(), 2, "actual alert callback still executes once")
	_stop(log)
	tile.free()
	alerts.free()

func test_government_confirmation_open_and_abandon_are_ui_cues_not_false_research_success() -> void:
	var c := player()
	c.political_power = 500.0
	var id := ""
	for candidate: String in Research.techs:
		if Research.is_government_project(candidate) and Research.can_start_reason(c, candidate) == "":
			id = candidate
			break
	if not check(id != "", "fixture has an available actual government project"): return
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel.visible = true
	panel.refresh()
	panel._selected = id
	panel._refresh_detail()
	var power := c.political_power
	var log := _listen()
	panel._start_button.pressed.emit()
	eq(log.heard, ["ui_open"], "opening the real confirmation emits only its modal-open cue")
	check(not ResearchPanel._active(c, id), "opening the dialog does not start the government project")
	_reset(log)
	panel._confirmation.get_cancel_button().pressed.emit()
	eq(log.heard, ["ui_close"], "abandoning confirmation closes once, with no research cancel/success cue")
	check(not ResearchPanel._active(c, id), "abandoned confirmation cannot start a project")
	eq(c.political_power, power, "confirmation preview/abandon does not charge influence")
	_stop(log)
	panel.free()

func test_air_user_selection_and_clear_are_single_cues_but_refresh_and_prune_are_silent() -> void:
	var c := player()
	c.stockpile[Air.TYPES["fighter"]["eq"]] = 1000.0
	var w := Air.deploy(c, "fighter", Air._home_base(c.tag))
	if not check(w != null, "fixture creates a valid owned wing"): return
	var panel := AirPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	var log := _listen()
	panel.select(w)
	panel.refresh()
	eq(log.heard, [], "map-sync selection and rebuilding cards never emit user cues")
	panel.select(null)
	(panel._cards[w.id] as ForceSelectionCard).select_button.pressed.emit()
	eq(log.heard, ["select_air"], "valid wing header emits one aircraft selection cue")
	_reset(log)
	(panel._cards[w.id] as ForceSelectionCard).toggle_button.pressed.emit()
	eq(log.heard, ["unit_deselect"], "checked wing emits one deselect cue")
	panel.select(w)
	_reset(log)
	panel._clear_selection_button.pressed.emit()
	eq(log.heard, ["unit_deselect"], "explicit clear suppresses generic click")
	panel.select(w)
	Air.wings.erase(w)
	_reset(log)
	panel._prune_selection()
	eq(panel.selected_id, 0, "destroyed wing selection is pruned")
	eq(log.heard, [], "automatic prune is silent")
	panel._toggle_wing(w.id)
	eq(log.heard, [], "stale wing callback is silent")
	_stop(log)
	panel.free()

func test_navy_header_uses_existing_map_cue_once_and_deselect_is_distinct() -> void:
	var own := Navy.fleets_of(World.player_tag)
	if not check(not own.is_empty(), "fixture has an owned fleet"): return
	var f: Fleet = own[0]
	var panel := NavyPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	var layer := FleetLayer.new()
	panel.fleet_selected.connect(layer.select)
	var log := _listen()
	panel.select(f)
	panel.refresh()
	eq(log.heard, [], "naval map synchronization/rebuild is silent")
	panel.select(null)
	(panel._cards[f.id] as ForceSelectionCard).select_button.pressed.emit()
	eq(log.heard, ["select_fleet"], "native fleet selection remains the single cue authority")
	_reset(log)
	(panel._cards[f.id] as ForceSelectionCard).toggle_button.pressed.emit()
	eq(log.heard, ["unit_deselect"], "naval checkbox clear emits only deselection")
	panel.select(f)
	Navy.fleets.erase(f)
	_reset(log)
	panel._prune_selection()
	eq(log.heard, [], "destroyed/transferred fleet prune is silent")
	_stop(log)
	panel.free()
	layer.free()

func test_politics_refresh_and_inert_action_ctas_do_not_play_generic_click() -> void:
	var panel := PoliticsPanel.new()
	_tree().root.add_child(panel)
	panel.open_country("GER")
	var log := _listen()
	panel.refresh()
	eq(log.heard, [], "foreign politics refresh is silent")
	for node: Node in panel.find_children("*", "Button", true, false):
		if node.has_meta("law_control"):
			check(bool(node.get_meta("audio_silent", false)), "law CTA leaves confirmation to successful core action")
			(node as Button).pressed.emit()
	eq(log.heard, [], "foreign/blocked law controls never emit a false success or generic press cue")
	_stop(log)
	panel.free()
