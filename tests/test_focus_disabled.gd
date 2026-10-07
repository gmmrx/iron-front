extends "res://tests/test_case.gd"
## Devlet Programı has no simulation or UI path; Research and source-agnostic legacy data remain intact.

func _first_focus(c: Country) -> String:
	return Politics.tree_of(c).keys()[0]

func test_focus_entrypoints_do_not_apply_effects_history_or_notifications() -> void:
	var c := player()
	var id := _first_focus(c)
	var before := [c.political_power, c.stability, c.war_support, c.research_slots,
		c.spirits.duplicate(), c.research_bonus.duplicate(true), c.stockpile.duplicate(true)]
	var completed := [0]
	var listener := func(_tag: String, _id: String) -> void: completed[0] += 1
	Politics.focus_completed.connect(listener)
	var log_before := World.world_log.size()
	check(not Politics.FOCUS_ENABLED, "feature disabled centrally")
	check(not Politics.can_start_focus(c, id), "player and AI cannot select a program")
	check(not Politics.start_focus(c, id), "start cannot create active program")
	Politics.complete_focus_now(c, id)
	Politics.complete_focus_now(c, id, false)
	Politics._program_news(c, id)
	eq(c.focus_current, "", "no current program")
	eq(c.focus_progress, 0.0, "no progress")
	check(not id in c.focus_done, "direct completion cannot mark legacy done history")
	eq([c.political_power, c.stability, c.war_support, c.research_slots,
		c.spirits.duplicate(), c.research_bonus.duplicate(true), c.stockpile.duplicate(true)], before, "no Focus bonus or PP/stat mutation")
	eq(completed[0], 0, "no completion signal/audio route")
	eq(World.world_log.size(), log_before, "no program news/notification")
	Politics.focus_completed.disconnect(listener)

func test_daily_progress_and_legacy_focus_conditions_are_inert() -> void:
	var c := player()
	var id := _first_focus(c)
	c.focus_current = id
	c.focus_progress = float(Politics.focus_def(c, id)["days"]) + 10.0
	c.focus_done.append("legacy_archive_id")
	World.day_count = 1 # No weekly random event step; this tests the actual daily Focus gate.
	Politics._on_day_impl()
	eq(c.focus_current, "", "daily gate deactivates even a manually restored program")
	eq(c.focus_progress, 0.0, "legacy progress never resumes or completes")
	check(not id in c.focus_done, "day tick cannot complete program")
	check("legacy_archive_id" in c.focus_done, "save-compatible historical IDs are retained")
	c.focus_done.append(id)
	check(not Politics.check(c, {"has_focus": id}), "archived Focus history cannot unlock new effects/events")

func test_ai_focus_and_focus_derived_history_are_inert_but_direct_events_survive() -> void:
	var ger := country("GER")
	var pp := ger.political_power
	AI._focus(ger)
	eq(ger.focus_current, "", "AI cannot pick a program")
	check(AI.apply_history({"tag": "GER", "day": 19360102, "focus": "ger_rhineland", "mark_focus": ["ger_pact_steel"]}),
		"historical entry remains readable")
	eq(ger.focus_done.size(), 0, "historical Focus/mark fields have no completion path")
	eq(ger.political_power, pp, "Focus history cannot grant political power")
	check(AI.apply_history({"tag": "GER", "day": 19360102, "effects": [{"pp": 17}]}), "non-Focus historical effects still apply")
	eq(ger.political_power, pp + 17, "ordinary events/research shared effects are not globally disabled")

func test_focus_ui_and_legacy_hud_navigation_cannot_open_or_interrupt_research() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var panel := FocusPanel.new()
	tree.root.add_child(panel)
	panel.open()
	check(not panel.visible and panel.get_child_count() == 0, "inert panel allocates no tree, buttons or artwork")
	check(not panel.is_processing() and not panel.is_processing_input(), "inert panel cannot consume input or animate")
	var hud := Hud.new()
	var research := ResearchPanel.new()
	hud.focus = panel
	hud.research = research
	research.visible = true
	hud.toggle_focus()
	check(not panel.visible and research.visible, "legacy F/notification call cannot open Focus or close Research")
	panel.visible = true
	panel.refresh()
	check(not panel.visible, "direct stale refresh cannot expose UI")
	research.free()
	hud.free()
	panel.free()

func test_save_load_sanitizes_only_active_focus_and_roundtrips_legacy_data() -> void:
	var c := player()
	var slot := "_test_focus_disabled_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var id := _first_focus(c)
	c.focus_done.append(id)
	c.focus_current = id
	c.focus_progress = 99.0
	c.political_power = 321.0
	c.research_bonus = [{"category": "industry", "value": 0.5, "uses": 2}]
	Politics.change_ideology(c, "democratic")
	var done := c.focus_done.duplicate()
	var bonuses := c.research_bonus.duplicate(true)
	var elections := c.next_election
	if not check(Game.save_game(slot), "write unique compatibility fixture"): return
	var path := Game.SAVE_DIR + slot + ".json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var saved: Dictionary = data["countries"][c.tag]
	check(saved.has("focus_current") and saved.has("focus_progress") and saved.has("focus_done"), "old save field names remain")
	eq(saved["election_months"], 48, "new government election interval is serialized")
	check(Game.load_game(slot), "legacy-shaped save loads")
	c = player()
	eq(c.focus_current, "", "loaded program is inactive before gameplay/UI")
	eq(c.focus_progress, 0.0, "loaded progress cannot resume")
	eq(c.focus_done, done, "completed history preserved")
	eq(c.research_bonus.size(), bonuses.size(), "untagged bonus entries preserved")
	for i in mini(c.research_bonus.size(), bonuses.size()):
		eq(c.research_bonus[i]["category"], bonuses[i]["category"], "legacy bonus category preserved")
		near(float(c.research_bonus[i]["value"]), float(bonuses[i]["value"]), 0.000001, "legacy bonus value preserved")
		eq(c.research_bonus[i]["uses"], bonuses[i]["uses"], "legacy bonus uses preserved through JSON numeric conversion")
	eq(c.political_power, 321.0, "load does not charge/refund gameplay cost")
	eq(c.election_months, 48, "election interval roundtrip")
	eq(c.next_election, elections, "save restore does not reschedule/change government")
	DirAccess.remove_absolute(path)

func test_change_ideology_validates_normalizes_and_changes_only_government_state() -> void:
	var c := player()
	var before := [c.ideology, c.popularity.duplicate(true), c.election_months, c.next_election]
	check(not Politics.change_ideology(c, "invalid"), "invalid ideology rejected")
	check(not Politics.change_ideology(c, c.ideology), "same government is a no-op")
	eq([c.ideology, c.popularity, c.election_months, c.next_election], before, "invalid/no-op cannot alter government data")
	var context := [c.leader, c.party.duplicate(true), c.faction, c.states.duplicate(), World.controller.duplicate(),
		Diplomacy.wars.duplicate(true), World.world_tension, c.political_power]
	var changed := [0]
	var listener := func(_tag: String) -> void: changed[0] += 1
	Politics.politics_changed.connect(listener)
	for ideology: String in ["democratic", "fascism", "communism", "neutrality"]:
		check(Politics.change_ideology(c, ideology), "valid researched government change: " + ideology)
		eq(c.ideology, ideology, "actual regime changes")
		ge(float(c.popularity[ideology]), 0.55, "new ruling party has majority")
		var sum := 0.0
		for value: float in c.popularity.values():
			check(is_finite(value) and value >= 0.0 and value <= 1.0, "valid normalized shares")
			sum += value
		near(sum, 1.0, 0.000001, "popularity normalized to one")
		eq(c.election_months, 48 if ideology == "democratic" else 0, "democratic elections only after government transition")
		check(c.next_election > World.date_value() if ideology == "democratic" else c.next_election == 0, "election date consistent")
	eq(changed[0], 4, "one UI/state signal per actual change")
	eq([c.leader, c.party, c.faction, c.states, World.controller, Diplomacy.wars, World.world_tension, c.political_power],
		context, "no invented identity, war, ownership, tension or PP effect")
	Politics.politics_changed.disconnect(listener)

func test_research_and_normal_politics_remain_live() -> void:
	var c := player()
	var chosen := ""
	for id: String in Research.techs:
		if not Research.is_government_project(id) and Research.can_research(c, id): chosen = id; break
	check(chosen != "" and Research.start(c, chosen), "normal Research still starts with Focus disabled")
	var pp := c.political_power
	Politics.apply_effects(c, [{"pp": 11}])
	eq(c.political_power, pp + 11, "shared event/decision effect interpreter stays live")
	var other := country("GER")
	other.political_power = 1000.0
	AI._research(other)
	gt(other.research_current.size(), 0, "AI still researches ordinary technology")
	for record: Dictionary in other.research_current:
		check(not Research.is_government_project(record["tech"]), "AI never randomly changes regime through a government project")
