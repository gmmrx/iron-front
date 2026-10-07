extends "res://tests/test_case.gd"
## Government projects use existing research/save records, but charge PP and advance by calendar days.

const FASCISM := "government_fascism_transition"
const DEMOCRACY := "government_democratic_transition"
const COMMUNISM := "government_communism_transition"
const NEUTRALITY := "government_neutrality_transition"

func _country() -> Country:
	var c := player()
	c.political_power = 500.0
	c.stability = 0.60
	c.war_support = 0.50
	c.research_current.clear()
	return c

func _record(c: Country, id: String) -> Dictionary:
	for r: Dictionary in c.research_current:
		if r["tech"] == id: return r
	return {}

func _finish(c: Country, id: String) -> void:
	var record := _record(c, id)
	if check(not record.is_empty(), "project is running before completion"):
		record["progress"] = 179.0
		Research._on_day_impl()

func test_start_has_real_temporary_drawbacks_and_charges_only_once() -> void:
	var c := _country()
	var raw_stability := c.stability
	var before_stability := Politics.stability(c)
	var before_support := Politics.war_support(c)
	var before_gain := c.daily_political_power_gain()
	var before_mod := c.mod("political_power_gain")
	check(Research.can_start_reason(c, FASCISM) == "", "eligible transition has no rejection reason")
	check(Research.start(c, FASCISM), "start explicit government project")
	near(c.political_power, 400.0, 0.0, "100 influence is charged at start")
	check(not Research.start(c, FASCISM), "duplicate start is rejected")
	check(not Research.start(c, COMMUNISM), "another ideology transition cannot run concurrently")
	near(c.political_power, 400.0, 0.0, "failed/repeated starts never double-charge")
	check(Research.GOVERNMENT_SPIRIT in c.spirits, "running project adds its temporary national spirit")
	near(Politics.stability(c), before_stability - 0.10, 0.00001, "effective stability loses ten points")
	near(Politics.war_support(c), before_support - 0.05, 0.00001, "home-front support loses five points")
	near(c.mod("political_power_gain"), before_mod - 0.15, 0.00001, "actual daily influence multiplier receives the advertised penalty")
	lt(c.daily_political_power_gain(), before_gain, "drawbacks affect real daily influence income")
	near(c.stability, raw_stability, 0.0, "temporary unrest does not permanently overwrite the stability base")
	check(Research.start(c, "motorization"), "normal military research can use a second slot")
	eq(c.research_current.size(), 2, "government project occupies just one existing slot")
	Research.cancel(c, FASCISM)
	near(c.political_power, 400.0, 0.0, "cancellation does not refund influence")
	check(not Research.GOVERNMENT_SPIRIT in c.spirits, "cancel removes the temporary penalty")
	near(Politics.stability(c), before_stability, 0.00001, "cancel restores the previous effective stability")
	near(Politics.war_support(c), before_support, 0.00001, "cancel restores the previous support")
	check(not _record(c, "motorization").is_empty(), "cancel does not touch the military slot")

func test_calendar_duration_ignores_speed_year_bonus_and_stored_days() -> void:
	var c := _country()
	c.research_stored = 60.0
	c.research_bonus = [{"category": "governance", "value": 10.0, "uses": 1}]
	c.tech_mods["research_speed"] = 4.0
	Game.scenario = {"research_speed": 20.0}
	GameClock.year = 1930
	check(Research.start(c, FASCISM), "government project accepts normal funding")
	near(_record(c, FASCISM)["progress"], 0.0, 0.0, "stored research days do not skip political transition work")
	near(c.research_stored, 60.0, 0.0, "unused stored days remain available for ordinary technology")
	eq(c.research_bonus[0]["uses"], 1, "project does not consume a technology bonus")
	near(Research.days_needed(c, FASCISM), 180.0, 0.0, "ahead-of-time year does not extend the calendar duration")
	for i in 7: Research._on_day_impl()
	near(_record(c, FASCISM)["progress"], 7.0, 0.0, "seven calendar updates mean seven days despite enormous science speed")
	near(Research.remaining_days(c, FASCISM), 173.0, 0.0, "remaining-days API follows actual calendar progress")
	near(Research.project_progress(c, FASCISM), 7.0 / 180.0, 0.00001, "normalized UI progress agrees with the record")
	Game.scenario = {}

func test_completion_changes_actual_regime_without_war_or_permanent_tech_mods() -> void:
	var c := _country()
	var wars := Diplomacy.wars.duplicate(true)
	var factions := Politics.factions.duplicate(true)
	var tension := World.world_tension
	var mods := c.tech_mods.duplicate(true)
	var leader := c.leader
	var party := c.party.duplicate(true)
	check(Research.start(c, DEMOCRACY), "democratic transition starts")
	_finish(c, DEMOCRACY)
	eq(c.ideology, "democratic", "finite completion changes the actual country's ideology")
	eq(c.election_months, 48, "new democracy has real scheduled elections")
	gt(c.next_election, World.date_value(), "first election is in the future")
	check(float(c.popularity["democratic"]) >= 0.55, "new ruling support is sufficient to sustain the transition")
	var sum := 0.0
	for value in c.popularity.values(): sum += float(value)
	near(sum, 1.0, 0.00001, "party support remains normalized")
	check(_record(c, DEMOCRACY).is_empty() and not Research.GOVERNMENT_SPIRIT in c.spirits, "completion frees the slot and removes unrest")
	check(not DEMOCRACY in c.research_done, "government choice is not permanently locked by technology history")
	eq(c.tech_mods, mods, "transition grants no permanent military/industrial technology modifier")
	eq(Diplomacy.wars, wars, "completion does not declare or join a war")
	eq(Politics.factions, factions, "completion does not change alliances")
	near(World.world_tension, tension, 0.0, "completion does not manufacture world tension")
	eq(c.leader, leader, "transition does not invent a historical leader")
	eq(c.party, party, "country identity/party history is preserved")
	near(c.political_power, 400.0, 0.0, "completion performs no second charge")
	check(not Research.start(c, DEMOCRACY), "already-current regime cannot be researched again immediately")

func test_projects_can_be_repeated_after_changing_to_another_regime() -> void:
	var c := _country()
	for id: String in [FASCISM, NEUTRALITY, FASCISM]:
		check(Research.start(c, id), "transition available again after changing away")
		_finish(c, id)
	eq(c.ideology, "fascism", "third finite project changes back to the earlier chosen regime")
	near(c.political_power, 200.0, 0.0, "each genuine new transition pays exactly once")
	eq(c.election_months, 0, "non-democratic target removes scheduled elections")
	check(not Research.ensure("rep_governance_1"), "national choices do not create endless empty refinement techs")
	eq(Research.next_repeat(c, "governance"), "", "governance advertises no refinement follow-up")

func test_invalid_unfunded_unstable_wartime_and_full_slot_transitions_are_rejected() -> void:
	var c := _country()
	check(not Research.start(c, "government_invalid_transition"), "unknown transition safely returns false")
	check(not Research.start(c, NEUTRALITY), "same-government transition is invalid")
	near(c.political_power, 500.0, 0.0, "invalid target consumes no PP")
	c.political_power = 99.0
	check(not Research.start(c, FASCISM), "funding below 100 is rejected")
	c.political_power = 500.0
	c.stability = 0.0
	check(not Research.start(c, FASCISM), "insufficient effective stability is rejected")
	c.stability = 0.60
	c.research_slots = 0
	check(not Research.start(c, FASCISM), "a free research slot is required")
	check(Research.can_start_reason(c, "motorization") != "", "ordinary-tech UI also gets a full-slot reason")
	c.research_slots = 2
	World.world_tension = 100.0
	c.war_goals["IRQ"] = true
	Diplomacy.declare_war(c.tag, "IRQ")
	check(Diplomacy.at_war(c.tag), "wartime test has a real declared war")
	var pp := c.political_power
	check(not Research.start(c, FASCISM), "regime project cannot begin during war")
	near(c.political_power, pp, 0.0, "wartime rejection consumes no PP")

func test_outside_regime_change_invalidates_running_project_without_reapplying_it() -> void:
	var c := _country()
	check(Research.start(c, FASCISM), "project starts before external regime change")
	_record(c, FASCISM)["progress"] = 179.0
	Politics.change_ideology(c, "communism")
	Research._on_day_impl()
	eq(c.ideology, "communism", "external legitimate regime change is not overwritten by an old project")
	check(_record(c, FASCISM).is_empty(), "obsolete project no longer blocks a slot")
	check(not Research.GOVERNMENT_SPIRIT in c.spirits, "obsolete project's penalty is removed")
	near(c.political_power, 400.0, 0.0, "invalidation neither refunds nor double-charges")

func test_save_load_preserves_running_progress_penalty_and_paid_cost_once() -> void:
	var c := _country()
	check(Research.start(c, FASCISM), "project starts before saving")
	_record(c, FASCISM)["progress"] = 37.5
	var pp := c.political_power
	var modifier := c.mod("stability")
	var slot := "_test_government_running_%d" % Time.get_ticks_usec()
	if not check(Game.save_game(slot), "save running project"): return
	if not check(Game.load_game(slot), "load running project"): return
	World.resume_game(World.player_tag)
	c = player()
	near(_record(c, FASCISM)["progress"], 37.5, 0.0, "save keeps fractional calendar progress")
	near(_record(c, FASCISM)["project_paid_pp"], 100.0, 0.0, "save keeps paid startup cost metadata")
	near(c.political_power, pp, 0.0, "load does not charge startup cost again")
	near(c.mod("stability"), modifier, 0.00001, "loaded project applies the same temporary modifier, not twice")
	Research.restore_projects(c)
	Research.restore_projects(c)
	near(c.political_power, pp, 0.0, "project restoration is idempotent for influence")
	eq(c.spirits.count(Research.GOVERNMENT_SPIRIT), 1, "loaded unrest spirit is not duplicated")
	Research._on_day_impl()
	near(_record(c, FASCISM)["progress"], 38.5, 0.0, "loaded record continues from its existing progress")
	DirAccess.remove_absolute(Game.SAVE_DIR + slot + ".json")

func test_save_of_completed_democracy_and_legacy_tech_reconstruction_is_safe() -> void:
	var c := _country()
	check(Research.start(c, DEMOCRACY), "democracy project starts")
	_finish(c, DEMOCRACY)
	var next := c.next_election
	var pp := c.political_power
	var slot := "_test_government_complete_%d" % Time.get_ticks_usec()
	if not check(Game.save_game(slot), "save completed democratic regime"): return
	if not check(Game.load_game(slot), "load completed democratic regime"): return
	World.resume_game(World.player_tag)
	c = player()
	eq(c.ideology, "democratic", "completed ideology survives save/load")
	eq(c.election_months, 48, "new election period survives optional save field")
	eq(c.next_election, next, "saved election schedule remains intact")
	near(c.political_power, pp, 0.0, "completed load does not consume PP")
	Research._complete(c, FASCISM, false)
	eq(c.ideology, "democratic", "legacy completed-tech reconstruction never executes a government transition")
	check(not Research.GOVERNMENT_SPIRIT in c.spirits, "no running project means no leftover temporary penalty")
	check("radio" in c.research_done, "old military/electronics researched state remains intact")
	DirAccess.remove_absolute(Game.SAVE_DIR + slot + ".json")

func test_ui_contract_exposes_exact_costs_duration_effects_and_target() -> void:
	var c := _country()
	var summary := Research.project_summary(c, FASCISM)
	eq(summary["target_ideology"], "fascism", "UI uses the real enum key")
	near(summary["duration_days"], 180.0, 0.0, "duration API exposes calendar duration")
	near(summary["political_power_cost"], 100.0, 0.0, "funding API exposes the exact cost")
	near(summary["temporary_mods"]["stability"], -0.10, 0.0, "temporary stability drawback is machine-readable")
	check(not summary["refund_on_cancel"] and summary["can_start"], "UI knows no-refund policy and eligibility")
	var text := Research.project_costs_text(c, FASCISM)
	for value: String in ["180", "100", "-10", "-5", "-15", "35"]:
		check(value in text, "plain-language details include " + value)
	check(Research.can_start_reason(c, "motorization") == "", "ordinary eligible technology uses the same empty-reason contract")
