extends "res://tests/test_case.gd"
## Research presentation only: original art in a compact top band, fixed caption, real catalog identity.

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _panel(branch := "all") -> ResearchPanel:
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel._set_branch(branch)
	return panel

func _thumbnail(card: Button) -> TextureRect:
	return card.find_child("Thumbnail", true, false) as TextureRect

func test_all_catalog_cards_keep_original_full_art_above_real_title_and_status() -> void:
	var panel := _panel()
	var c := player()
	for id: String in panel._nodes:
		var card: Button = panel._nodes[id]
		var art := _thumbnail(card)
		var title := card.find_child("ProjectTitle", true, false) as Label
		var status := card.find_child("ProjectStatus", true, false) as Label
		if not check(art != null and title != null and status != null, "named thumbnail/title/status exist for " + id): continue
		eq(art.texture, ResearchPanel._tech_icon(id), "card uses the exact existing research image, not a new crop/cutout: " + id)
		eq(art.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "source dimensions never force a 512/1254 px UI minimum")
		eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "complete rifles, wings and ship masts are never cropped or stretched")
		eq(art.custom_minimum_size.x, 0.0, "thumbnail expands to the card width instead of a fixed small square")
		eq(art.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "top illustration occupies the full card width")
		eq(art.get_parent().get_child(0), art, "art is the first block of the vertical card, not beside its caption")
		check(art.get_parent() != title.get_parent(), "caption has its own lower block")
		eq(title.get_parent(), status.get_parent(), "actual title and status share the caption block")
		check(title.get_index() < status.get_index(), "title precedes the actual status")
		eq(card.get_meta("tech_id"), id, "real technology identity is preserved")
		eq(title.text, Research.tech_name(id), "caption uses the real localized project name")
		var expected := tr("RES_DONE") if id in c.research_done else (tr("RES_RUNNING") if ResearchPanel._active(c, id) else "%d %s" % [ceili(Research.days_needed(c, id)), tr("UI_DAYS")])
		if ResearchPanel._current_government(c, id): expected = tr("RES_CURRENT_GOVERNMENT")
		eq(status.text, expected, "status is computed from the real country state")
		check(card.tooltip_text.contains(Research.tech_name(id)), "complete real title remains in the tooltip")
	panel.free()

func test_thumbnail_height_is_capped_with_fixed_caption_space() -> void:
	var panel := _panel("army")
	var id: String = panel._nodes.keys()[0]
	var card := panel._project_card(player(), id) as ResearchPanel.ProjectCard
	_tree().root.add_child(card) # No GridContainer competes with synchronous resize checks.
	var art := _thumbnail(card)
	var title := card.find_child("ProjectTitle", true, false) as Label
	for width: float in [ResearchPanel.NODE.x, maxf(ResearchPanel.NODE.x, 290.0), maxf(ResearchPanel.NODE.x, 360.0)]:
		card.size = Vector2(width, width + ResearchPanel.ProjectCard.CAPTION_HEIGHT)
		card._fit_thumbnail()
		near(art.custom_minimum_size.y, ResearchPanel.ProjectCard.THUMBNAIL_HEIGHT, 0.01, "thumbnail height stays compact at every card width")
		near(card.custom_minimum_size.y, ResearchPanel.ProjectCard.THUMBNAIL_HEIGHT + ResearchPanel.ProjectCard.CAPTION_HEIGHT + ResearchPanel.ProjectCard.FRAME * 2, 0.01, "caption reserve remains readable without oversized cards")
		eq(title.get_theme_font_size("font_size"), UiTheme.fs(18), "resizing keeps large readable project text")
		eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "resizing cannot turn the image into a cropped strip")
	card.free()
	panel.free()

func test_seven_large_filter_tabs_are_mutually_exclusive_and_keep_catalog_semantics() -> void:
	var panel := _panel("all")
	var before := player().research_current.duplicate(true)
	eq(panel._tabs.size(), 7, "all seven real branches remain available")
	var group := panel._tabs[0].button_group
	if check(group != null, "research filters use one actual native ButtonGroup"):
		check(not group.allow_unpress, "the selected branch cannot disappear into no active filter")
	for i in panel._tabs.size():
		var tab: Button = panel._tabs[i]
		var branch: String = ResearchPanel.BRANCHES.keys()[i]
		eq(tab.button_group, group, "every branch shares the mutual-exclusion group")
		eq(tab.custom_minimum_size.y, 56.0, "filter is a readable large tab")
		eq(tab.get_theme_font_size("font_size"), UiTheme.fs(18), "filter text is not reduced to miniature labels")
		tab.pressed.emit()
		eq(panel._branch, branch, "actual tab callback chooses the correct catalog branch")
		eq(panel._tabs.filter(func(button: Button) -> bool: return button.button_pressed).size(), 1, "exactly one visible tab is selected")
		if branch != "all":
			for id: String in panel._nodes:
				check(Research.techs[id]["cat"] in ResearchPanel.BRANCHES[branch], "branch filter retains its real categories")
	eq(player().research_current, before, "filter navigation never starts or cancels any project")
	panel.free()

func test_selected_hover_stays_gold_and_refresh_does_not_invent_project_state_or_cues() -> void:
	var panel := _panel()
	var c := player()
	var id: String = panel._nodes.keys()[0]
	var card: Button = panel._nodes[id]
	check(card.has_theme_stylebox_override("hover_pressed"), "selected card has an explicit hovered-selected style")
	var pressed := card.get_theme_stylebox("pressed")
	var hovered := card.get_theme_stylebox("hover_pressed")
	eq(hovered.get("surface"), pressed.get("surface"), "hovering a selected card retains the same generated gold selected plate")
	check(bool(card.get_meta("audio_silent", false)), "card leaves its single semantic select cue to the real callback")
	var before := c.research_current.duplicate(true)
	var done := c.research_done.duplicate()
	var power := c.political_power
	card.pressed.emit()
	eq(panel._selected, id, "card press chooses its real dossier")
	check(card.button_pressed, "clicked catalog card visibly remains selected")
	eq(c.research_current, before, "catalog click is inspection, not fake automatic research")
	eq(c.research_done, done, "catalog click cannot invent completion")
	eq(c.political_power, power, "catalog click does not charge influence")
	var heard: Array[String] = []
	var callback := func(key: String) -> void: heard.append(key)
	var test_mode_before := Audio.test_mode
	Audio.test_mode = true
	Audio.reset_effect_state()
	Audio.cue_requested.connect(callback)
	panel.refresh()
	eq(heard, [], "rebuilding large illustration cards emits no user-click/start/cancel cue")
	eq(panel._selected, id, "refresh preserves the inspected real project")
	eq(c.research_current, before, "refresh remains read-only for running projects")
	Audio.cue_requested.disconnect(callback)
	Audio.reset_effect_state()
	Audio.test_mode = test_mode_before
	panel.free()

func test_keyboard_project_focus_survives_daily_and_rapid_refresh_without_cues() -> void:
	var panel := _panel("army")
	panel.visible = true
	var id: String = panel._nodes.keys()[0]
	var old_card: Button = panel._nodes[id]
	old_card.grab_focus()
	eq(panel.get_viewport().gui_get_focus_owner(), old_card, "fixture has actual keyboard focus on a catalog project")
	var before := player().research_current.duplicate(true)
	var heard: Array[String] = []
	var callback := func(key: String) -> void: heard.append(key)
	var old_mode := Audio.test_mode
	Audio.test_mode = true
	Audio.reset_effect_state()
	Audio.cue_requested.connect(callback)
	World.daily_update.emit()
	var first: Button = panel._nodes[id]
	check(first != old_card, "real daily refresh rebuilt the focused catalog card")
	var stale: WeakRef = weakref(first)
	panel.refresh()
	var current: Button = panel._nodes[id]
	panel._restore_project_focus(stale, id)
	check(panel.get_viewport().gui_get_focus_owner() == null, "obsolete queued card cannot receive focus")
	panel._restore_project_focus(weakref(current), id)
	eq(panel.get_viewport().gui_get_focus_owner(), current, "rapid refresh restores the same actual project on the final live card")
	eq(heard, [], "focus restoration emits no select/start/cancel sound")
	eq(player().research_current, before, "focus restoration is not project activation")
	Audio.cue_requested.disconnect(callback)
	Audio.reset_effect_state()
	Audio.test_mode = old_mode
	panel.free()

func test_pending_project_focus_never_steals_tabs_dossier_or_closed_panel_focus() -> void:
	player().political_power = 500
	var panel := _panel("all")
	panel.visible = true
	var id: String = panel._nodes.keys()[0]
	(panel._nodes[id] as Button).grab_focus()
	panel.refresh()
	var pending: WeakRef = weakref(panel._nodes[id])
	var tab: Button = panel._tabs[2]
	tab.grab_focus()
	panel._restore_project_focus(pending, id)
	eq(panel.get_viewport().gui_get_focus_owner(), tab, "newer branch-tab focus is never stolen")
	panel.refresh()
	eq(panel.get_viewport().gui_get_focus_owner(), tab, "refresh with tab focus does not create a project-focus promise")
	check(panel._pending_project_focus == "", "tab-focused refresh cancels old catalog focus intent")
	var action: Button = panel._start_button
	check(not action.disabled, "fixture has a focusable real dossier action")
	action.grab_focus()
	eq(panel.get_viewport().gui_get_focus_owner(), action, "fixture has actual dossier focus")
	panel.refresh()
	panel._restore_project_focus(weakref(panel._nodes[id]), id)
	check(not panel.get_viewport().gui_get_focus_owner() is ResearchPanel.ProjectCard, "dossier-focused refresh cannot redirect focus into the catalog")
	(panel._nodes[id] as Button).grab_focus()
	panel.refresh()
	pending = weakref(panel._nodes[id])
	panel.close()
	panel._restore_project_focus(pending, id)
	check(panel.get_viewport().gui_get_focus_owner() == null, "closing while layout is pending cannot refocus a hidden project")
	panel.free()
