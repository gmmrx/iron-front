extends "res://tests/test_case.gd"
## Public admission/event contract without a speaker; imported asset/playback QA is separate.

func _listen() -> Dictionary:
	var heard: Array[String] = []
	var callback := func(key: String) -> void: heard.append(key)
	var saved := {"mode": Audio.test_mode, "sfx": Audio.sfx_db, "ui": Audio.ui_db}
	Audio.test_mode = true
	Audio.set_sfx_linear(1.0)
	Audio.set_ui_linear(1.0)
	Audio.reset_effect_state()
	Audio.cue_requested.connect(callback)
	return {"heard": heard, "callback": callback, "saved": saved}

func _reset(log: Dictionary) -> void:
	(log.heard as Array).clear()
	Audio.reset_effect_state()

func _stop(log: Dictionary) -> void:
	Audio.cue_requested.disconnect(log.callback)
	Audio.reset_effect_state()
	Audio.test_mode = log.saved.mode
	Audio.sfx_db = log.saved.sfx
	Audio.ui_db = log.saved.ui
	Audio._refresh_effect_levels()

func test_default_cooldown_explicit_zero_hover_and_global_burst_limits() -> void:
	var log := _listen()
	Audio.play("law_change")
	Audio.play("law_change")
	eq(log.heard, ["law_change"], "catalog cooldown rejects an immediate duplicate")
	_reset(log)
	Audio.play("law_change", 0)
	Audio.play("law_change", 0)
	eq(log.heard, ["law_change", "law_change"], "explicit zero bypasses catalog key cooldown")
	_reset(log)
	Audio.play("ui_hover", 0)
	Audio.play("menu_hover", 0)
	Audio.hover_building("naval_base")
	eq(log.heard, ["ui_hover"], "all UI/menu/map hovers share one mandatory low-rate budget")
	_reset(log)
	for i in 40: Audio.play("law_change", 0)
	eq(log.heard.size(), Audio.BURST_MAX, "rapid immediate sounds have a fixed global burst budget")
	_stop(log)

func test_priority_queue_is_bounded_deduplicates_and_preserves_urgent_events() -> void:
	var log := _listen()
	Audio._ensure_catalog()
	var original: Dictionary = Audio._catalog
	Audio._catalog = original.duplicate(true)
	var base: Dictionary = Audio._catalog["sounds"]["notify_info"].duplicate(true)
	base["queue"] = true
	base["priority"] = 0
	base["cooldown_ms"] = 0
	for i in Audio.QUEUE_MAX + 4:
		Audio._catalog["sounds"]["qa_notice_%d" % i] = base.duplicate(true)
		Audio.play("qa_notice_%d" % i, 0)
	eq(Audio._queue.size(), Audio.QUEUE_MAX, "notifications never allocate an unbounded backlog")
	eq(log.heard.size(), Audio.QUEUE_MAX, "dropped requests emit no accepted-request signal")
	Audio.play("qa_notice_0", 0)
	eq(log.heard.size(), Audio.QUEUE_MAX, "same pending notification is deduplicated even with cooldown disabled")
	Audio.play("notify_urgent", 0)
	eq(Audio._queue.size(), Audio.QUEUE_MAX, "urgent event replaces one low-priority request without growth")
	eq(Audio._queue[0]["key"], "notify_urgent", "urgent notification is next rather than buried behind trivia")
	Audio._pump_queue()
	eq(Audio._notice_key, "notify_urgent", "dedicated notification voice receives the urgent request")
	var accepted: int = log.heard.size()
	Audio.play("notify_urgent", 0)
	eq(log.heard.size(), accepted, "currently playing notice also deduplicates")
	Audio.reset_effect_state()
	Audio.play("qa_notice_0", 0)
	Audio._pump_queue()
	Audio.play("notify_urgent", 0)
	Audio._pump_queue()
	eq(Audio._notice_key, "notify_urgent", "urgent event preempts the current low-priority notice")
	eq(Audio._pool.size(), Audio.POOL, "priority work uses no extra immediate voices")
	Audio._catalog = original
	_stop(log)

func test_research_resolution_repeat_fallback_and_success_events_are_specific() -> void:
	var log := _listen()
	var id: String = Research.techs.keys()[0]
	for phase: String in ["select", "start", "done", "cancel"]:
		var key := Audio.research_key(id, phase)
		check(key.begins_with("research_"), "base project has a specific " + phase + " cue")
		Audio.research_cue(id, phase)
	eq(log.heard.size(), 4, "all four phases resolve to independently accepted cues")
	var repeat := Research.repeat_id("industry", 27)
	eq(Audio.research_key(repeat, "start"), "research_category_industry_start", "new repeat level resolves category without changing research data")
	check(not Research.techs.has(repeat), "audio lookup does not materialize a future technology")
	eq(Audio.research_key("unregistered_future_tech", "done"), "research_done", "unknown project has safe legacy completion fallback")
	eq(Audio.research_key(id, "invalid"), "", "invalid phase is silent")
	_reset(log)
	Audio._watch_player()
	Research.research_started.emit(World.player_tag, id)
	Research.research_cancelled.emit(World.player_tag, id)
	Research.tech_completed.emit(World.player_tag, id)
	Audio._watch_player()
	eq(log.heard, [Audio.research_key(id, "start"), Audio.research_key(id, "cancel"), Audio.research_key(id, "done")], "authoritative player success signals each emit once with no snapshot echo")
	_reset(log)
	Research.research_started.emit("GER", id)
	eq(log.heard, [], "foreign project activity never plays a player success cue")
	_stop(log)

func test_world_notifications_coalesce_with_semantic_events_in_both_orders() -> void:
	var log := _listen()
	World.world_event("war", "NOTE_WAR_DECLARED", [], [World.player_tag, "GER"], 0, "bad")
	Audio._flush_notifications()
	eq(log.heard, ["war_declare"], "notification-before-world-log emits only the player-declaration cue")
	_reset(log)
	World.world_event("war", "NOTE_WAR_DECLARED", [], ["GER", World.player_tag], 0, "war")
	Audio._flush_notifications()
	eq(log.heard, ["war_declared_on"], "incoming war uses a distinct critical cue")
	_reset(log)
	Diplomacy.action_completed.emit(World.player_tag, "access_granted", "GER")
	World.notify("Access granted", "good")
	Audio._flush_notifications()
	eq(log.heard, ["access_granted"], "semantic-success-before-notification also emits once")
	_reset(log)
	World.notify("Independent warning", "warning")
	Audio._flush_notifications()
	eq(log.heard, ["notify_warning"], "standalone notifications retain their importance cue")
	_stop(log)

func test_button_override_silent_disabled_and_same_frame_panel_coalescing() -> void:
	var log := _listen()
	var tree := Engine.get_main_loop() as SceneTree
	var button := Button.new()
	Audio.ui_bind(button, "notification_open", "menu_hover")
	button.pressed.connect(func() -> void: Audio.panel(true))
	tree.root.add_child(button)
	button.pressed.emit()
	Audio._flush_panel()
	eq(log.heard, ["notification_open"], "explicit alert cue suppresses the default opened-panel echo")
	_reset(log)
	button.mouse_entered.emit()
	eq(log.heard, ["menu_hover"], "hover override replaces the generic hover rather than adding to it")
	_reset(log)
	button.set_meta("audio_silent", true)
	button.mouse_entered.emit()
	button.pressed.emit()
	eq(log.heard, [], "silent metadata suppresses generic click and hover")
	_reset(log)
	button.set_meta("audio_silent", false)
	button.disabled = true
	button.mouse_entered.emit()
	button.pressed.emit()
	eq(log.heard, [], "disabled button cannot request its explicit sound")
	button.free()
	# A delayed/stored handler remains safe after its sender has been destroyed.
	var ephemeral := Button.new()
	Audio.ui_bind(ephemeral, "ui_click")
	var stale: Callable = ephemeral.pressed.get_connections()[0]["callable"]
	ephemeral.free()
	stale.call()
	Audio.reset_effect_state()
	_stop(log)

func test_generic_action_click_yields_to_success_cue_regardless_of_connection_order() -> void:
	var log := _listen()
	var tree := Engine.get_main_loop() as SceneTree
	for audio_first: bool in [true, false]:
		var button := Button.new()
		var action := func() -> void: Diplomacy.action_completed.emit(World.player_tag, "war_justification", "GER")
		if audio_first: Audio._hook_button(button)
		button.pressed.connect(action)
		if not audio_first: Audio._hook_button(button)
		tree.root.add_child(button)
		_reset(log)
		button.pressed.emit()
		Audio._flush_generic_ui()
		eq(log.heard, ["war_justification"], "successful action replaces generic click with either signal order")
		button.free()
	var plain := Button.new()
	tree.root.add_child(plain)
	_reset(log)
	plain.pressed.emit()
	Audio._flush_generic_ui()
	eq(log.heard, ["ui_click"], "plain inert/game control still gets its tactile click")
	plain.free()
	_stop(log)

func test_effect_rng_is_private_and_typed_selection_distinguishes_anti_tank() -> void:
	var log := _listen()
	seed(740231)
	var expected := randi()
	seed(740231)
	for i in 12:
		Audio.effect_stream("ui_click")
		Audio.play("law_change", 0)
	eq(randi(), expected, "bank variations and effect pitch never advance the gameplay RNG")
	var c := player()
	var template_count := c.templates.size()
	var d := Division.new()
	d.owner = c.tag
	d.template = template_count
	for definition: Dictionary in [
		{"battalions": {"infantry": 8}}, {"battalions": {"light_tank": 4}},
		{"battalions": {"motorized": 6}}, {"battalions": {"artillery": 4}}, {"battalions": {"anti_tank": 4}}]:
		c.templates.append(definition)
		_reset(log)
		Audio.unit_selection([null, d])
		var type: String = definition.battalions.keys()[0]
		var expected_key: String = {"infantry": "select_infantry", "light_tank": "select_armor", "motorized": "select_motorized",
			"artillery": "select_artillery", "anti_tank": "select_artillery"}[type]
		eq(log.heard, [expected_key], "typed template cue for " + type)
		c.templates.pop_back()
	c.templates.append({"battalions": {"infantry": 8, "artillery": 2}})
	_reset(log)
	Audio.unit_selection([d])
	eq(log.heard, ["select_infantry"], "support artillery does not turn an infantry formation's selection into artillery")
	c.templates.pop_back()
	eq(c.templates.size(), template_count, "cue classification leaves military templates untouched")
	_stop(log)

func test_game_reset_clears_pending_effects_without_touching_music() -> void:
	var log := _listen()
	var music := [Audio.music_db, Audio.forced_track, Audio._track, Audio._state, Audio._active]
	Audio.play("notify_warning", 0)
	World.notify("old save notification", "good")
	Audio.panel(true)
	World.player_changed.emit(World.player_tag)
	Audio._flush_notifications()
	Audio._flush_panel()
	eq(Audio._queue, [], "player change removes old queued/transient effects")
	eq(Audio._notice_key, "", "old active notification identity is cleared")
	eq([Audio.music_db, Audio.forced_track, Audio._track, Audio._state, Audio._active], music, "effect reset preserves every music-selection field")
	Audio.play("notify_warning", 0)
	World.game_started.emit()
	eq(Audio._queue, [], "new game also drops the previous notification backlog")
	_stop(log)
