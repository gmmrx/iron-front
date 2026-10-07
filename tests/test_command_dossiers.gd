extends "res://tests/test_case.gd"
## Government/diplomatic dossier hierarchy, real data, read-only safety and small-window minimums.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _labels(panel: Control) -> Array[String]:
	var texts: Array[String] = []
	for child: Node in panel.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	return texts

func _buttons(panel: Control, marker: String) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in panel.find_children("*", "Button", true, false):
		if child.has_meta(marker): result.append(child as Button)
	return result

func test_politics_three_columns_and_actual_country_identity() -> void:
	var panel := PoliticsPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	var columns := panel._root.get_node("PoliticsColumns")
	eq(columns.get_child_count(), 3, "government has three independent dossier columns")
	for child: Node in columns.get_children():
		check(child is ScrollContainer, "each government column scrolls independently")
		if child is ScrollContainer:
			eq((child as ScrollContainer).horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "no sideways dossier scroll")
	var country := World.player()
	var texts := _labels(panel)
	check(country.leader_name() in texts, "real current leader is displayed")
	check(country.party_name() in texts or tr("POL_NO_PARTY") in texts, "real ruling party or honest empty state is displayed")
	check(tr("POL_POPULARITY") in texts, "ideology popularity has its own readable block")
	var focus_buttons := 0
	for child: Node in panel.find_children("*", "Button", true, false):
		if (child as Button).text == tr("POL_OPEN_FOCUS"):
			focus_buttons += 1
	eq(focus_buttons, 0, "government no longer exposes the removed state-program CTA")
	check(not tr("POL_THEIR_FOCUS") in texts, "no state-program section remains")
	var left := columns.get_child(0) as ScrollContainer
	var middle := columns.get_child(1) as ScrollContainer
	check(left.find_child("NationalConditions", true, false) == null, "national conditions no longer crowd the leader column")
	var first_section := middle.get_node("PoliticsColumnBody1").get_child(0)
	check(first_section.find_child("NationalConditions", true, false) != null, "national conditions occupy the top of the middle column")
	var cards := middle.find_child("NationalConditionCards", true, false) as GridContainer
	if check(cards != null, "illustrated national-condition grid is present"):
		eq(cards.columns, 2, "national conditions use two clearly separated card columns")
		var valid := 0
		for id: String in country.spirits:
			if Politics.spirits.has(id) or Politics.decisions.has(id): valid += 1
		eq(cards.get_child_count(), valid, "cards represent actual country conditions only")
		for card: Node in cards.get_children():
			var id: String = card.get_meta("national_spirit")
			var definition: Dictionary = Politics.spirits.get(id, Politics.decisions.get(id, {}))
			check((card as Control).tooltip_text.contains(Politics.describe_mods(definition.get("mods", {}))), "full actual effects remain in each tooltip")
			var illustration := card.find_child("Illustration", true, false) as TextureRect
			check(illustration != null and illustration.texture != null and illustration.custom_minimum_size.x >= 84.0, "condition art is large and actually loaded")
			if id == "army_in_reorganization":
				eq(illustration.texture, CommandPanelSkin.illustration("spirit_military_modernization"), "army condition uses the period military illustration, not the red HUD symbol")
			if id in ["kemalist_officers", "first_five_year_plan"] and illustration.texture is AtlasTexture:
				lt(float(illustration.texture.get_width()), 512.0, "transparent icon gutters are cropped within the unchanged 84/96 px art slot")
			var name := card.find_children("*", "Label", true, false)[0] as Label
			eq(name.get_theme_color("font_color"), UiTheme.TEXT, "negative conditions retain readable warm-ivory names")
	panel.free()

func test_national_condition_accents_preserve_honest_tradeoffs() -> void:
	eq(PoliticsPanel._spirit_state({"research_speed": 0.05}), 1, "pure research bonus has a restrained positive accent")
	eq(PoliticsPanel._spirit_state({"org": -0.15}), -1, "pure cohesion penalty has a restrained negative accent")
	eq(PoliticsPanel._spirit_state({"defense": 0.1, "war_support": -0.05}), 0, "mixed benefits and drawbacks stay neutral rather than claiming an unconditional bonus")
	eq(PoliticsPanel._spirit_state({"consumer_goods_mod": -0.05}), 1, "lower consumer-goods burden is beneficial")
	eq(PoliticsPanel._spirit_state({"training_time": 0.1}), -1, "longer training is a drawback")
	eq(PoliticsPanel._spirit_state({}), 0, "empty modifiers have a neutral accent")
	eq(PoliticsPanel._national_illustration(Research.GOVERNMENT_SPIRIT), load("res://assets/ui/command_panels/statecraft_v1.png"), "temporary government transition uses the generated statecraft illustration, not a military/status fallback")

func test_foreign_government_laws_are_read_only() -> void:
	var panel := PoliticsPanel.new()
	_tree().root.add_child(panel)
	var foreign: Country = World.countries["GER"]
	var laws := foreign.laws.duplicate(true)
	var power := foreign.political_power
	panel.open_country("GER")
	check(panel._foreign(), "foreign-government mode is retained")
	check(foreign.leader_name() in _labels(panel), "foreign identity uses real selected-country data")
	var choices := _buttons(panel, "law_control")
	gt(choices.size(), 0, "foreign laws remain inspectable")
	for button: Button in choices:
		check(button.disabled, "all foreign law-changing controls are disabled, including current law")
		check(button.tooltip_text != "", "requirements/effects remain in the law tooltip")
	var selectors := _buttons(panel, "law_selector")
	eq(selectors.size(), Economy.law_groups.size(), "all current law groups remain visible")
	for button: Button in selectors:
		eq(button.custom_minimum_size.y, 56.0, "law group selectors do not consume a tall card before the choices")
		eq(button.get_theme_font_size("font_size"), UiTheme.fs(17), "compact law selectors preserve readable type")
		check(button.tooltip_text.contains(Economy.group_name(button.get_meta("law_selector"))), "clipped group name remains complete in its tooltip")
	if not selectors.is_empty(): selectors[-1].pressed.emit()
	eq(foreign.laws, laws, "switching the displayed law group does not change foreign laws")
	eq(foreign.political_power, power, "foreign viewing never spends political power")
	panel.free()

func test_diplomacy_keeps_search_object_and_real_actions() -> void:
	var panel := DiplomacyPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	var search_id := panel._search.get_instance_id()
	panel._search.text = "SOV"
	panel._filter()
	panel.open_for("GER")
	eq(panel._search.get_instance_id(), search_id, "country selection does not recreate the search field")
	eq(panel._search.text, "SOV", "country selection preserves the active search query")
	var found := false
	for item: Array in panel._list:
		if item[2] == "SOV": found = (item[0] as Button).visible
	check(found, "existing country-code search still filters the list")
	eq(_buttons(panel, "diplomatic_action").size(), 6, "the six actual diplomatic actions are retained")
	for button: Button in _buttons(panel, "diplomatic_action"):
		check(button.tooltip_text != "", "action explanation/blocking reason remains available")
		check(button.get_parent() is HBoxContainer, "action CTA stays inline even on narrow windows")
		check(button.tooltip_text.contains(str(button.get_meta("diplomatic_action"))), "full diplomatic action name remains in the tooltip")
	check(World.countries["GER"].leader_name() in _labels(panel), "dossier shows the real selected leader")
	panel._search.text_submitted.emit("SOV")
	eq(panel.target, "SOV", "Enter selects the first visible country")
	panel.free()

func test_diplomacy_agreements_use_existing_country_data() -> void:
	var country := World.player()
	country.guarantees = ["ENG"]
	country.access = ["FRA"]
	var panel := DiplomacyPanel.new()
	_tree().root.add_child(panel)
	panel.open()
	var texts := _labels(panel)
	check(tr("DIP_GUARANTEES") in texts, "real guarantee status is shown")
	check(tr("DIP_ACCESS_RIGHTS") in texts, "real military-access status is shown")
	var flags := panel.find_children("*", "TextureRect", true, false)
	check(flags.any(func(node: Node) -> bool: return (node as TextureRect).tooltip_text == World.countries["ENG"].display_name()), "guarantee country has an actual flag and identity tooltip")
	check(flags.any(func(node: Node) -> bool: return (node as TextureRect).tooltip_text == World.countries["FRA"].display_name()), "access country has an actual flag and identity tooltip")
	eq(country.guarantees, ["ENG"], "rendering agreements is read-only")
	eq(country.access, ["FRA"], "rendering access is read-only")
	panel.free()

func test_dossiers_fit_1280_and_1920_without_smaller_text() -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.disable_3d = true
		_tree().root.add_child(viewport)
		for script: Script in [preload("res://game/ui/politics_panel.gd"), preload("res://game/ui/diplomacy_panel.gd")]:
			var panel: PanelContainer = script.new()
			viewport.add_child(panel)
			panel.open()
			PanelLayout.fit_full(panel)
			var available := float(dimensions.x) - PanelLayout.SIDE_LEFT - PanelLayout.SIDE_RIGHT
			check(panel.get_combined_minimum_size().x <= available + 2.0,
				"%s minimum width %.1f fits %d px viewport (available %.1f)" % [script.resource_path, panel.get_combined_minimum_size().x, dimensions.x, available])
			check(panel.has_meta("command_skin"), "dossier inherits the new scoped command skin")
			var outer: ScrollContainer = panel.get_meta("scroll")
			eq(outer.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "column scrolling replaces a whole-page scrolling stack")
			panel.free()
		viewport.free()

func _set_scroll_range(scroll: ScrollContainer, value: int) -> void:
	# The synchronous test runner cannot await layout; give the native scrollbar
	# a real range and exercise the same deferred restoration's final phase.
	var bar := scroll.get_v_scroll_bar()
	bar.max_value = 1000.0
	bar.page = 100.0
	scroll.scroll_vertical = value

func test_refresh_preserves_column_and_country_list_scroll_positions() -> void:
	var politics := PoliticsPanel.new()
	_tree().root.add_child(politics)
	politics.open()
	for i in 3:
		_set_scroll_range(politics._root.get_node("PoliticsColumns/PoliticsColumn%d" % i), 40 + i * 30)
	politics.refresh()
	politics.refresh() # A game signal plus its action callback may refresh twice in one frame.
	for i in 3:
		var name := "PoliticsColumn%d" % i
		eq(politics._scroll_positions[name], 40 + i * 30, "rapid government refresh retains the prior column position")
		var scroll: ScrollContainer = politics._root.get_node("PoliticsColumns/" + name)
		_set_scroll_range(scroll, 0)
		PoliticsPanel._restore_column_scroll(weakref(scroll), politics._scroll_positions[name], true)
		eq(scroll.scroll_vertical, 40 + i * 30, "government scroll is restored after layout")
	politics.open_country("GER")
	check(politics._scroll_positions.is_empty(), "switching government country starts a new dossier at the top")
	politics.free()
	var diplomacy := DiplomacyPanel.new()
	_tree().root.add_child(diplomacy)
	diplomacy.open_for("GER")
	var list_scroll := diplomacy.find_child("DiplomacyCountryScroll", true, false) as ScrollContainer
	_set_scroll_range(list_scroll, 160)
	_set_scroll_range(diplomacy._root.get_node("DiplomacyColumns/DiplomacyColumn1"), 80)
	diplomacy.open_for("SOV")
	diplomacy.refresh()
	eq(diplomacy._scroll_positions["DiplomacyCountryScroll"], 160, "country selection does not reset the country list")
	eq(diplomacy._scroll_positions["DiplomacyColumn1"], 80, "diplomatic refresh keeps the action column position")
	list_scroll = diplomacy.find_child("DiplomacyCountryScroll", true, false) as ScrollContainer
	_set_scroll_range(list_scroll, 0)
	DiplomacyPanel._restore_column_scroll(weakref(list_scroll), 160, true)
	eq(list_scroll.scroll_vertical, 160, "country-list restoration uses the native scrollbar")
	diplomacy.close()
	diplomacy.open()
	check(diplomacy._scroll_positions.is_empty(), "closing and reopening starts a fresh diplomatic view")
	var freed := ScrollContainer.new()
	var reference: WeakRef = weakref(freed)
	freed.free()
	PoliticsPanel._restore_column_scroll(reference, 99, true)
	DiplomacyPanel._restore_column_scroll(reference, 99, true)
	diplomacy.free()
