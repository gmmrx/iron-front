extends "res://tests/test_case.gd"

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func test_command_material_is_local_to_framed_panels() -> void:
	var global_theme := UiTheme.get_theme()
	var original := global_theme.get_stylebox("panel", "PanelContainer")
	var panel := PanelContainer.new()
	_tree().root.add_child(panel)
	PanelLayout.frame(panel, "Preview", "research", 480)
	check(panel.theme != global_theme, "panel theme is independent of the HUD/menu theme")
	eq(global_theme.get_stylebox("panel", "PanelContainer"), original, "global panel skin was not mutated")
	check(panel.has_meta("command_skin"), "framed panels opt into the reference surface")
	var style := panel.get_theme_stylebox("panel")
	check(style.get("surface") != null, "generated panel artwork is connected")
	check(style.get("surface").resource_path.ends_with("window_v3.png"), "window uses the actual ImageGen frame")
	eq(style.get("display_inset"), Vector4(16, 16, 16, 16), "corners retain their display size regardless of panel dimensions")
	panel.free()

func test_diplomacy_flag_uses_country_art_and_static_fabric_without_stretching() -> void:
	var panel := DiplomacyPanel.new()
	_tree().root.add_child(panel)
	panel.open_for("SOV")
	var flag := panel.find_child("DiplomacyCountryFlag", true, false) as TextureRect
	if check(flag != null, "selected-country flag has a dedicated plaque"):
		eq(flag.texture, FlagFactory.uniform(country("SOV"), 540), "country flag uses the shared high-resolution 3:2 format")
		eq(flag.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "flag aspect ratio is preserved")
		check(flag.material is ShaderMaterial, "neutral generated fabric supplies the material lighting")
		var fabric: Texture2D = (flag.material as ShaderMaterial).get_shader_parameter("cloth")
		check(fabric != null and fabric.resource_path.ends_with("flag_cloth_v1.png"), "saved ImageGen fabric is bound")
		check(not (flag.material as ShaderMaterial).shader.code.contains("TIME"), "diplomacy flag is static")
	panel.free()

func test_government_research_requires_explicit_confirmation() -> void:
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	var c := player()
	c.political_power = 500
	c.stability = 0.8
	panel.refresh()
	var candidate := "government_democratic_transition"
	if check(panel._nodes.has(candidate), "government projects are the initial research view"):
		(panel._nodes[candidate] as Button).pressed.emit()
		var before := c.political_power
		panel._start_button.pressed.emit()
		eq(c.political_power, before, "opening confirmation spends no political power")
		check(panel._confirmation.visible, "costly regime change asks for confirmation")
		panel._confirmation.confirmed.emit()
		eq(c.research_current.size(), 1, "confirmation starts the real national project")
		lt(c.political_power, before, "project cost is charged exactly at start")
		check(panel._start_button.get_parent() == panel._detail_actions, "primary research action remains outside the scrollable dossier")
	panel.free()

func test_command_sections_keep_clear_readable_heading() -> void:
	var parent := VBoxContainer.new()
	var body := CommandPanelSkin.section(parent, "Diplomacy", "diplomacy")
	check(body.get_parent() is MarginContainer, "section content has independent padding")
	var labels := parent.find_children("*", "Label", true, false)
	eq(labels.size(), 1, "one clear section heading")
	if labels.size() == 1:
		check((labels[0] as Label).get_theme_font_size("font_size") >= 20, "heading remains readable")
	parent.free()

func test_generated_panel_parts_and_transparent_emblems_are_used() -> void:
	for kind: String in ["panel", "card", "section", "button", "selected"]:
		var style := CommandPanelSkin.box(kind)
		var texture: Texture2D = style.get("surface")
		check(texture.resource_path.begins_with(CommandPanelSkin.ASSETS), "each layer uses a saved generated bitmap")
	var heading := CommandPanelSkin.box("section")
	eq(heading.get("region"), Rect2(2, 3, 2168, 154), "header atlas excludes the generated white gutters")
	for name: String in ["diplomacy", "research"]:
		var texture := CommandPanelSkin.icon(name)
		check(texture.resource_path.ends_with(name + "_v3.png"), "dossier emblem uses its generated transparent asset")
		var bitmap := texture.get_image()
		check(bitmap.get_pixel(0, 0).a < 0.01, "icon is really transparent, not black-backed")

func test_research_branch_filter_preserves_technology_identity() -> void:
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel._set_branch("all")
	panel.refresh()
	var total := panel._nodes.size()
	gt(total, 20, "all branches expose the actual technology tree")
	panel._set_branch("army")
	gt(panel._nodes.size(), 4, "army has selectable technologies")
	lt(panel._nodes.size(), total, "branch filtering actually reduces the tree")
	for id: String in panel._nodes:
		check(Research.techs[id]["cat"] in ["infantry", "artillery", "armor"], "army tab contains no unrelated branch")
		var card: Button = panel._nodes[id]
		eq(card.get_meta("tech_id"), id, "illustrated card retains the real technology ID")
		check(card.tooltip_text.contains(Research.tech_name(id)), "full title remains available even when caption ellipsizes")
		var illustrations := card.find_children("*", "TextureRect", true, false)
		if check(not illustrations.is_empty(), "technology card has real artwork"):
			var art := illustrations[0] as TextureRect
			eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "technology artwork is never cropped into an unrecognizable strip")
			eq(art.name, &"Thumbnail", "full artwork has a dedicated top plate")
			eq(art.custom_minimum_size.y, ResearchPanel.ProjectCard.THUMBNAIL_HEIGHT, "thumbnail occupies a compact full-width band")
	panel._set_branch("all")
	eq(panel._nodes.size(), total, "all branches restore without losing technologies")
	panel.free()

func test_research_dossier_action_starts_and_cancels_actual_research() -> void:
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel._set_branch("army")
	panel.refresh()
	var c := player()
	var candidate := ""
	for id: String in panel._nodes:
		if Research.can_research(c, id):
			candidate = id
			break
	if check(candidate != "", "fixture has an available technology"):
		var before := c.research_current.size()
		(panel._nodes[candidate] as Button).pressed.emit()
		eq(c.research_current.size(), before, "catalog selection never spends resources")
		panel._start_button.pressed.emit()
		eq(c.research_current.size(), before + 1, "explicit dossier action invokes Research.start")
		panel._selected = candidate
		panel._refresh_detail()
		panel._start_button.pressed.emit()
		eq(c.research_current.size(), before, "explicit running-project action cancels research")
	check(ResearchPanel.NODE.y >= 120, "card is no longer a compressed tiny icon row")
	panel.free()
