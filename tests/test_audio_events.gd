extends "res://tests/test_case.gd"
## Accepted gameplay commands supply semantic SFX events; replay/bootstrap and rejected commands do not.
## Audio playback/filtering belongs to Audio, not the simulation. These spies do not modify music.

const GOVERNMENT := "government_fascism_transition"
var _events: Array = []
var _connections: Array[Dictionary] = []

func _record(tag: String, id: String, event: String) -> void:
	_events.append([event, tag, id])

func _record_diplomacy(actor: String, kind: String, target: String) -> void:
	_events.append(["diplomacy", actor, kind, target])

func _listen() -> void:
	_events.clear()
	for pair: Array in [[Research.research_started, "research_started"], [Research.research_cancelled, "research_cancelled"],
			[Research.tech_completed, "tech_completed"], [Politics.advisor_hired, "advisor_hired"],
			[Politics.advisor_dismissed, "advisor_dismissed"], [Politics.decision_taken, "decision_taken"],
			[Economy.law_changed, "law_changed"]]:
		var event: Signal = pair[0]
		var callback := _record.bind(pair[1])
		event.connect(callback)
		_connections.append({"event": event, "callback": callback})
	Diplomacy.action_completed.connect(_record_diplomacy)

func _stop() -> void:
	for connection: Dictionary in _connections:
		var event: Signal = connection["event"]
		event.disconnect(connection["callback"])
	_connections.clear()
	Diplomacy.action_completed.disconnect(_record_diplomacy)

func _prepared() -> Country:
	var c := player()
	c.political_power = 1000.0
	c.stability = 0.70
	c.research_current.clear()
	c.research_slots = 3
	return c

func _normal_research(c: Country) -> String:
	for id: String in Research.techs:
		if not Research.is_government_project(id) and Research.can_start_reason(c, id) == "": return id
	return ""

func test_research_start_and_cancel_emit_once_only_for_accepted_commands() -> void:
	var c := _prepared()
	var id := _normal_research(c)
	check(id != "", "real ordinary project available")
	_listen()
	check(not Research.start(null, id), "null country start rejected")
	check(not Research.start(c, "_unknown_audio_project"), "unknown project start rejected")
	c.research_slots = 0
	check(not Research.start(c, id), "full slots reject start")
	c.research_slots = 3
	check(Research.start(c, id), "ordinary project starts")
	check(not Research.start(c, id), "duplicate start rejected")
	Research.cancel(c, "_not_running")
	Research.cancel(c, id)
	Research.cancel(c, id)
	Research.cancel(null, id)
	eq(_events, [["research_started", "TUR", id], ["research_cancelled", "TUR", id]], "one exact event per accepted start/cancel")
	eq(c.research_current.size(), 0, "accepted cancellation really removes the record")
	_stop()

func test_government_project_uses_the_same_once_only_start_cancel_events() -> void:
	var c := _prepared()
	_listen()
	check(Research.start(c, GOVERNMENT), "government transition starts")
	var paid := c.political_power
	check(not Research.start(c, GOVERNMENT), "duplicate transition rejected")
	check(not Research.start(c, "government_communism_transition"), "parallel transition rejected")
	Research.cancel(c, GOVERNMENT)
	Research.cancel(c, GOVERNMENT)
	eq(_events, [["research_started", "TUR", GOVERNMENT], ["research_cancelled", "TUR", GOVERNMENT]], "governance uses normal accepted event contract")
	eq(c.political_power, paid, "events do not refund a cancelled transition")
	check(Research.GOVERNMENT_SPIRIT not in c.spirits, "temporary penalty is removed before cancellation is announced")
	_stop()

func test_actual_completion_uses_existing_tech_completed_once() -> void:
	var c := _prepared()
	var id := _normal_research(c)
	_listen()
	check(Research.start(c, id), "ordinary project starts")
	c.research_current[0]["progress"] = Research._work_needed(c, id) + 1.0
	Research._on_day_impl()
	Research._on_day_impl()
	Research._complete(c, id)
	eq(_events, [["research_started", "TUR", id], ["tech_completed", "TUR", id]], "normal completion is not a cancellation or duplicate completion")
	_events.clear()
	check(Research.start(c, GOVERNMENT), "government transition starts")
	c.research_current[0]["progress"] = 179.0
	Research._on_day_impl()
	Research._on_day_impl()
	Research._complete(c, GOVERNMENT)
	eq(_events, [["research_started", "TUR", GOVERNMENT], ["tech_completed", "TUR", GOVERNMENT]], "government completion announces actual regime change exactly once")
	eq(c.ideology, "fascism", "government event follows the actual state change")
	_stop()

func test_reset_and_restore_do_not_announce_research_or_political_commands() -> void:
	var c := _prepared()
	c.research_current.append({"tech": GOVERNMENT, "progress": 50.0})
	_listen()
	Research.restore_projects(c)
	Research._complete(c, "motorization", false)
	Research._complete(c, GOVERNMENT, false)
	Research.reset()
	Politics.reset()
	Economy.reset()
	Diplomacy.reset()
	Game.new_game()
	eq(_events, [], "bootstrap/reset and reconstructed completed/current projects are semantic-event silent")
	_stop()

func test_save_load_retains_state_without_replaying_success_audio_events() -> void:
	var c := _prepared()
	check(Research.start(c, GOVERNMENT), "active project fixture")
	Politics.hire(c, "cabinet_secretary")
	Politics.take_decision(c, "propaganda_campaign")
	check(Economy.change_law(c, "conscription", "two_year_service"), "changed law fixture")
	Diplomacy.grant_access("GRE", "TUR")
	var pp := c.political_power
	var slot := "_test_audio_events_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(Game.save_game(slot), "write unique state fixture")
	_listen()
	check(Game.load_game(slot), "load gameplay state")
	eq(_events, [], "load never restarts research, re-hires advisors, re-takes decisions or re-grants access")
	c = player()
	eq(c.research_current.size(), 1, "active project retained")
	check("cabinet_secretary" in c.advisors and c.decisions_active.has("propaganda_campaign"), "political choices retained")
	eq(c.laws["conscription"], "two_year_service", "changed law retained")
	check("GRE" in c.access, "access retained")
	near(c.political_power, pp, 0.000001, "restoration charges no action again")
	_stop()
	DirAccess.remove_absolute(Game.SAVE_DIR + slot + ".json")

func test_advisor_hire_and_dismiss_semantics_reject_noops_and_failures() -> void:
	var c := _prepared()
	c.advisors.clear()
	_listen()
	Politics.hire(null, "cabinet_secretary")
	Politics.hire(c, "_unknown_audio_advisor")
	c.political_power = 0.0
	Politics.hire(c, "cabinet_secretary")
	c.political_power = 1000.0
	Politics.hire(c, "cabinet_secretary")
	Politics.hire(c, "cabinet_secretary")
	Politics.dismiss(c, "_not_hired")
	Politics.dismiss(c, "cabinet_secretary")
	Politics.dismiss(c, "cabinet_secretary")
	Politics.dismiss(null, "cabinet_secretary")
	eq(_events, [["advisor_hired", "TUR", "cabinet_secretary"], ["advisor_dismissed", "TUR", "cabinet_secretary"]], "actual hire/removal only")
	_stop()

func test_decision_event_is_paid_success_only_not_expiry_or_rejection() -> void:
	var c := _prepared()
	c.decisions_active.clear()
	_listen()
	Politics.take_decision(null, "propaganda_campaign")
	Politics.take_decision(c, "_unknown_audio_decision")
	Politics.take_decision(c, "war_bonds") # Requires war: TUR is at peace.
	c.political_power = 0.0
	Politics.take_decision(c, "propaganda_campaign")
	c.political_power = 1000.0
	Politics.take_decision(c, "propaganda_campaign")
	Politics.take_decision(c, "propaganda_campaign")
	eq(_events, [["decision_taken", "TUR", "propaganda_campaign"]], "paid accepted decision emits once")
	World.day_count = 1 # Not the weekly random event step.
	c.decisions_active["propaganda_campaign"] = World.day_count
	Politics._on_day_impl()
	eq(_events, [["decision_taken", "TUR", "propaganda_campaign"]], "expiry is not a second decision command")
	_stop()

func test_law_event_contains_the_real_law_id_and_only_accepted_change() -> void:
	var c := _prepared()
	_listen()
	check(not Economy.change_law(c, "conscription", "_unknown_audio_law"), "unknown law rejected")
	c.political_power = 0.0
	check(not Economy.change_law(c, "conscription", "two_year_service"), "unaffordable law rejected")
	c.political_power = 1000.0
	check(Economy.change_law(c, "conscription", "two_year_service"), "actual law change accepted")
	check(not Economy.change_law(c, "conscription", "two_year_service"), "same law rejected")
	eq(_events, [["law_changed", "TUR", "two_year_service"]], "group-independent real law id emitted once")
	_stop()

func test_unlogged_diplomacy_actions_emit_once_and_logged_actions_do_not_duplicate() -> void:
	var c := _prepared()
	var target := country("GRE")
	World.world_tension = 100.0
	_listen()
	check(Diplomacy.justify(c, target), "justification accepted")
	check(not Diplomacy.justify(c, target), "duplicate justification rejected")
	check(not Diplomacy.justify(c, c), "self justification rejected")
	Diplomacy.grant_access("GRE", "TUR")
	Diplomacy.grant_access("GRE", "TUR")
	Diplomacy.grant_access("GRE", "_unknown_audio_receiver")
	eq(_events, [["diplomacy", "TUR", "war_justification", "GRE"], ["diplomacy", "TUR", "access_granted", "GRE"]], "action actor is paying/requesting country; access target is the giver")
	_events.clear()
	Diplomacy.guarantee("TUR", "BUL")
	Diplomacy.join_faction("GRE", "ENG")
	var iraq := country("IRQ")
	c.war_goals[iraq.tag] = true
	check(Diplomacy.declare_war(c.tag, iraq.tag), "logged war accepted")
	Diplomacy.white_peace(c.tag, iraq.tag)
	eq(_events, [], "guarantee/faction/war/peace use World log alone, not action_completed too")
	_stop()

func test_world_logged_payload_and_notification_order_are_explicit() -> void:
	var sequence: Array = []
	var feed := func(_text: String, _kind: String) -> void: sequence.append("notification")
	var logged := func(record: Dictionary) -> void: sequence.append(["world_logged", record.duplicate(true)])
	World.notification.connect(feed)
	World.world_logged.connect(logged)
	var args := ["@TUR", "@GRE"]
	var tags := ["TUR", "GRE"]
	var pid := World.capital_province("GRE")
	var record := World.world_event("diplomacy", "NOTE_GUARANTEE", args, tags, pid)
	eq(sequence, ["notification", ["world_logged", record]], "Audio must account for notification being emitted before its semantic World record")
	eq(record, {"day": World.day_count, "date": World.date_value(), "kind": "diplomacy", "key": "NOTE_GUARANTEE", "args": args, "tags": tags, "pid": pid}, "stable structured record, not translated-text parsing")
	sequence.clear()
	var foreign := World.world_event("diplomacy", "NOTE_GUARANTEE", ["@LIT", "@LAT"], ["LIT", "LAT"])
	eq(sequence, [["world_logged", foreign]], "irrelevant foreign action logs without a local notification")
	World.notification.disconnect(feed)
	World.world_logged.disconnect(logged)
