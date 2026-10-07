extends "res://tests/test_case.gd"
## Country actions in the actual map selection panel, with core diplomacy restrictions and stale-confirm safeguards.
const ACTIONS := preload("res://game/ui/country_diplomacy_actions.gd")

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _panel(tag: String) -> StatePanel:
	var panel := StatePanel.new()
	_tree().root.add_child(panel)
	World.select_province(World.capital_province(tag))
	return panel

func _entry(actor: Country, target: Country, key: String) -> Dictionary:
	for entry: Dictionary in ACTIONS.entries(actor, target):
		if entry["key"] == key: return entry
	return {}

func test_foreign_country_actions_exist_without_buildings_or_exploration() -> void:
	Military.fog_enabled = true
	var pid := World.capital_province("GER")
	check(not Military.is_visible(pid), "foreign distant fixture genuinely unexplored")
	var explored := Military.fog_levels().duplicate()
	var panel := _panel("GER")
	check(panel.visible and panel._country_box != null, "normal selected province opens pinned country dossier")
	for key: String in ["justify", "declare", "guarantee", "access", "invite", "peace"]:
		check(panel._quick_actions.has(key), "country action is above the buildings/fog early return: " + key)
		var button: Button = panel._quick_actions.get(key)
		check(button != null and button.tooltip_text != "", "action explains its purpose or exact restriction")
	eq(Military.fog_levels(), explored, "country action availability does not reveal terrain/units")
	panel.free()

func test_own_setup_and_sea_selection_have_no_diplomatic_actions() -> void:
	var panel := _panel(World.player_tag)
	eq(panel._quick_actions.size(), 0, "self-target actions absent")
	check(not ACTIONS.execute(World.player_tag, World.player_tag, "declare"), "backend helper cannot create self-war")
	check(not ACTIONS.execute(World.player_tag, World.player_tag, "justify"), "backend helper cannot spend PP on self")
	var sea := 0
	for province: Object in World.provinces:
		if province != null and not province.is_land(): sea = province.id; break
	World.select_province(sea)
	check(not panel.visible and panel._quick_actions.is_empty(), "sea clears country selection/actions")
	World.in_game = false
	World.select_province(World.capital_province("IRQ"))
	check(panel._quick_actions.is_empty(), "setup cannot expose live diplomacy mutation controls")
	check(not ACTIONS.execute(World.player_tag, "IRQ", "justify"), "setup execution also rejected")
	panel.free()

func test_occupied_province_actions_target_original_country_not_occupier() -> void:
	var pid := World.capital_province("POL")
	var state := World.state_of_province(pid)
	World.set_controller(pid, World.player_tag)
	var panel := _panel("POL")
	eq(state.owner, "POL", "original owner retained by occupation")
	eq(World.controller_tag(pid), World.player_tag, "fixture has different occupier")
	var pp := player().political_power
	panel._request_quick_action("justify", World.player_tag, pid)
	eq(player().political_power, pp, "occupier/self tag cannot silently replace the displayed target")
	check(not player().justify_progress.has(World.player_tag), "no self justification")
	check(panel._quick_actions.has("justify"), "original foreign owner remains actionable")
	panel.free()

func test_justification_reuses_cost_tension_and_duplicate_rules_at_execution() -> void:
	var actor := player()
	var target := country("IRQ")
	actor.political_power = 100.0
	World.world_tension = 49.0
	eq(ACTIONS.blocked(actor, target, "justify"), Diplomacy.can_justify(actor, target), "same neutral ideology tension restriction")
	check(not ACTIONS.execute(actor.tag, target.tag, "justify"), "blocked low tension cannot execute")
	eq(actor.political_power, 100.0, "blocked action cannot spend PP")
	World.world_tension = 60.0
	var panel := _panel(target.tag)
	check(not panel._quick_actions["justify"].disabled, "ready action initially enabled")
	actor.political_power = 0.0 # Permission can change after a button was built.
	panel._request_quick_action("justify", target.tag, World.capital_province(target.tag))
	check(not actor.justify_progress.has(target.tag), "button's old enabled state never bypasses current PP restriction")
	actor.political_power = 100.0
	check(ACTIONS.execute(actor.tag, target.tag, "justify"), "valid core justification starts")
	near(actor.political_power, 100.0 - Diplomacy.JUSTIFY_COST, 0.000001, "actual core PP cost charged once")
	eq(int(actor.justify_progress[target.tag]), Diplomacy.JUSTIFY_DAYS, "actual duration preserved")
	check(not ACTIONS.execute(actor.tag, target.tag, "justify"), "duplicate request blocked")
	panel.free()

func test_war_alliance_neutral_and_truce_permissions_cannot_be_bypassed() -> void:
	var actor := player()
	var target := country("IRQ")
	eq(ACTIONS.blocked(actor, target, "declare"), Diplomacy.can_declare(actor, target), "war-goal rule preserved")
	check(not ACTIONS.execute(actor.tag, target.tag, "declare"), "no-goal cannot start war")
	actor.war_goals[target.tag] = true
	actor.truce_until = World.day_count + 10
	eq(ACTIONS.blocked(actor, target, "declare"), "DIPLO_ERR_TRUCE", "truce restriction preserved")
	check(not ACTIONS.execute(actor.tag, target.tag, "declare"), "active truce cannot execute")
	actor.truce_until = 0
	var england := country("ENG")
	var france := country("FRA")
	check(ACTIONS.blocked(england, france, "declare") != "", "allied/non-player context not actionable")
	actor.war_goals["SWE"] = true
	check(not World.is_active("SWE"), "neutral nonparticipant fixture")
	check(ACTIONS.blocked(actor, country("SWE"), "declare") != "", "neutral war protected")
	check(not ACTIONS.execute(actor.tag, "SWE", "declare"), "neutral cannot be attacked by quick UI")
	check(not ACTIONS.execute(actor.tag, "MISSING", "justify"), "missing target rejected safely")
	check(not ACTIONS.execute("GER", target.tag, "declare"), "NPC actor cannot substitute for current human player")

func test_declare_requires_confirmation_and_then_calls_real_diplomacy() -> void:
	var actor := player()
	actor.war_goals["IRQ"] = true
	var panel := _panel("IRQ")
	var pid := World.capital_province("IRQ")
	var goal_before := actor.war_goals.duplicate(true)
	panel._request_quick_action("declare", "IRQ", pid)
	check(not panel._pending_war.is_empty(), "ready war opens confirmation intent")
	eq(panel._pending_war.get("player"), actor.tag, "confirmation remembers actor")
	eq(panel._pending_war.get("target"), "IRQ", "confirmation remembers intended country")
	eq(panel._pending_war.get("province"), pid, "confirmation remembers map selection")
	check(not Diplomacy.are_enemies(actor.tag, "IRQ"), "request alone cannot declare")
	eq(actor.war_goals, goal_before, "request cannot consume goal")
	panel._confirm_war()
	check(Diplomacy.are_enemies(actor.tag, "IRQ"), "confirmed action runs actual war gameplay")
	check(not actor.war_goals.has("IRQ"), "real core declaration consumes war goal")
	check(panel._pending_war.is_empty(), "intent consumed exactly once")
	var wars := Diplomacy.wars.size()
	panel._confirm_war()
	eq(Diplomacy.wars.size(), wars, "second confirmation cannot duplicate war")
	panel.free()

func test_confirmation_revalidates_permission_selection_owner_and_player() -> void:
	var actor := player()
	actor.war_goals["IRQ"] = true
	var panel := _panel("IRQ")
	var pid := World.capital_province("IRQ")
	panel._request_quick_action("declare", "IRQ", pid)
	actor.war_goals.erase("IRQ")
	panel._refresh()
	check(panel._pending_war.is_empty(), "refresh cancels a now-blocked declaration, not just its eventual confirmation")
	panel._confirm_war()
	check(not Diplomacy.are_enemies(actor.tag, "IRQ"), "revoked permission checked at confirm")
	actor.war_goals["IRQ"] = true
	panel._request_quick_action("declare", "IRQ", pid)
	World.select_province(World.capital_province("PER"))
	check(panel._pending_war.is_empty(), "new map selection cancels previous confirmation")
	panel._confirm_war()
	check(not Diplomacy.are_enemies(actor.tag, "IRQ") and not Diplomacy.are_enemies(actor.tag, "PER"), "stale selection never retargets/executes")
	World.select_province(pid)
	panel._request_quick_action("declare", "IRQ", pid)
	World.transfer_state(World.province(pid).state_id, "PER")
	World.flush_ownership()
	panel._confirm_war()
	check(not Diplomacy.are_enemies(actor.tag, "IRQ"), "changed province owner invalidates intent")
	panel._request_quick_action("declare", "IRQ", pid)
	check(panel._pending_war.is_empty(), "old owner callback cannot requeue against fresh selection")
	World.select_province(World.capital_province("GRE"))
	actor.war_goals["GRE"] = true
	panel._request_quick_action("declare", "GRE", World.capital_province("GRE"))
	World.set_player("GER")
	panel._confirm_war()
	check(not Diplomacy.are_enemies(actor.tag, "GRE") and not Diplomacy.are_enemies("GER", "GRE"), "player switch cannot mutate from captured old actor")
	panel.free()

func test_cancel_and_disappearing_target_have_no_mutation() -> void:
	var actor := player()
	actor.war_goals["IRQ"] = true
	var panel := _panel("IRQ")
	var pid := World.capital_province("IRQ")
	panel._request_quick_action("declare", "IRQ", pid)
	panel._war_confirmation.canceled.emit()
	check(panel._pending_war.is_empty(), "cancel drops pending intent")
	check(actor.war_goals.has("IRQ") and not Diplomacy.are_enemies(actor.tag, "IRQ"), "cancel preserves goal and peace")
	panel._request_quick_action("declare", "IRQ", pid)
	country("IRQ").states.clear()
	panel._confirm_war()
	check(not Diplomacy.are_enemies(actor.tag, "IRQ"), "removed country cannot be attacked by stale dialog")
	panel.free()

func test_other_direct_actions_preserve_full_diplomacy_rules_and_recheck() -> void:
	var actor := player()
	var target := country("IRQ")
	World.world_tension = 0.0
	eq(ACTIONS.blocked(actor, target, "guarantee"), Diplomacy.guarantee_block(actor), "guarantee uses core ideology/tension gate")
	check(not ACTIONS.execute(actor.tag, target.tag, "guarantee"), "raw guarantee cannot bypass current restriction")
	check(not target.tag in actor.guarantees, "blocked guarantee cannot mutate promises")
	World.world_tension = 60.0
	check(ACTIONS.execute(actor.tag, target.tag, "guarantee"), "legal guarantee reaches core action")
	check(target.tag in actor.guarantees, "guarantee recorded on the acting country")
	check(not ACTIONS.execute(actor.tag, target.tag, "guarantee"), "duplicate guarantee blocked")
	var access := country("PER")
	access.ideology = actor.ideology # Deterministic acceptance under the existing full-panel rule.
	check(ACTIONS.execute(actor.tag, access.tag, "access"), "same-ideology access request accepted")
	check(access.tag in actor.access and not actor.tag in access.access, "access direction matches original giver/receiver rule")
	actor.war_goals[access.tag] = true
	check(Diplomacy.declare_war(actor.tag, access.tag), "enemy access fixture")
	check(not ACTIONS.execute(actor.tag, access.tag, "access"), "wartime access request rejected")
	eq(ACTIONS.blocked(actor, target, "invite"), "DIPLO_ERR_NO_FACTION", "only an existing faction leader can invite")
	check(not ACTIONS.execute(actor.tag, target.tag, "invite"), "raw faction join cannot bypass leader restriction")
	actor.faction = actor.tag
	Politics.factions[actor.tag] = [actor.tag]
	target.ideology = actor.ideology
	check(ACTIONS.execute(actor.tag, target.tag, "invite"), "legal same-ideology invite accepted")
	eq(target.faction, actor.tag, "core faction membership actually changes")
	check(not ACTIONS.execute(actor.tag, target.tag, "invite"), "already-affiliated target cannot be invited again")
	check(ACTIONS.blocked(actor, target, "peace") != "" and not ACTIONS.execute(actor.tag, target.tag, "peace"),
		"peace action cannot execute unless the two countries are enemies")

func test_selection_and_diplomacy_refresh_update_pinned_controls_before_hidden_buildings() -> void:
	Military.fog_enabled = true
	var actor := player()
	var panel := _panel("GER")
	check(panel._diplo_btn.visible, "foreign diplomacy navigation updates despite buildings/fog return")
	check(panel._quick_actions["justify"].disabled, "initial neutral low-tension restriction is visible")
	actor.political_power = 100.0
	World.world_tension = 60.0
	Diplomacy.diplomacy_changed.emit(actor.tag)
	check(panel._refresh_pending, "diplomatic state change schedules fresh controls")
	panel._refresh() # Synchronous runner drives the deferred redraw explicitly.
	check(not panel._quick_actions["justify"].disabled, "scheduled refresh recomputes current permission")
	World.select_province(World.capital_province(actor.tag))
	check(not panel._diplo_btn.visible and not panel._play_btn.visible, "own selection immediately clears stale foreign bottom controls")
	check(panel._quick_actions.is_empty(), "own selection has no old foreign action callbacks")
	panel.free()
