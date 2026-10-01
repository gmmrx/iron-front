extends "res://tests/test_case.gd"

func test_material_panels_preserve_original_frames_and_layout() -> void:
	for flat in [false, true]:
		var original := UiTheme.legacy_skin("panel_flat" if flat else "panel", 14 if flat else 16, 12 if flat else 14)
		var material := UiTheme.material_panel(flat)
		var frame: StyleBoxTexture = material.get("frame")
		eq(frame.texture, original.texture, "özgün çerçeve korunur")
		check(not frame.draw_center, "eski doku yeni yüzeyi örtmez")
		eq(material.get_minimum_size(), original.get_minimum_size(), "panel en küçük boyutu değişmez")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			near(material.get_content_margin(side), original.get_content_margin(side), 0.001, "içerik payı korunur")
		var surface: Texture2D = material.get("surface")
		eq(surface.get_size(), Vector2(1254, 1254), "gerçek üretilen doku boyutu")
		check(surface.get_image().detect_alpha() == Image.ALPHA_NONE, "arka plan opak")
	var theme := UiTheme.get_theme()
	eq(theme.get_stylebox("panel", "Panel").get_script(), UiTheme.material_panel().get_script(), "yüzey ana panellere bağlı")
	eq(theme.get_stylebox("panel", "PanelFlat").get_script(), UiTheme.material_panel(true).get_script(), "yüzey iç panellere bağlı")
	var button := theme.get_stylebox("normal", "Button")
	check(button.get("surface") != null, "buton yeni malzemeyi kullanır")
	var button_frame: StyleBoxTexture = button.get("frame")
	eq(button_frame.texture.resource_path, "res://assets/ui/skin/button.png", "buton özgün kenarı korunur")

func test_large_panel_grain_tiles_without_changing_layout() -> void:
	for name: String in ["panel", "panel_flat", "strip"]:
		var sb := UiTheme.legacy_skin(name, 16, 14)
		eq(sb.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, name + " yatay doku gerilmez")
		eq(sb.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, name + " dikey doku gerilmez")
		eq(sb.texture.resource_path, "res://assets/ui/skin/%s.png" % name, "özgün doku ve palet korunur")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			near(sb.get_texture_margin(side), 16, 0.001, "kenar payı değişmez")
			near(sb.get_content_margin(side), 14, 0.001, "içerik yerleşimi değişmez")

func test_header_gradient_and_controls_are_unchanged() -> void:
	var strip := UiTheme.legacy_skin("strip", 12, 6)
	near(strip.get_texture_margin(SIDE_LEFT), 14, 0.001, "perçin tekrar alanına girmez")
	near(strip.get_content_margin(SIDE_LEFT), 6, 0.001, "şerit içerik payı korunur")
	for name: String in ["header", "section"]:
		var sb := UiTheme.legacy_skin(name)
		eq(sb.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "başlık yatay doku ölçeği")
		eq(sb.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH, "dikey ışık geçişi korunur")
	for name: String in ["button", "button_hover", "card", "slot", "tooltip"]:
		var sb := UiTheme.legacy_skin(name)
		eq(sb.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH, "kontrol stili değişmez: " + name)
		eq(sb.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH, "kontrol stili değişmez: " + name)

func test_control_materials_keep_states_margins_and_duplicates() -> void:
	for name: String in ["header", "section", "button", "button_hover", "button_pressed", "button_disabled", "card", "card_hover", "card_selected", "tab", "tab_active", "slot", "slot_good", "slot_gold", "cell", "tooltip"]:
		var original := UiTheme.legacy_skin(name, 8, 5)
		var updated := UiTheme.skin(name, 8, 5)
		eq(updated.get_minimum_size(), original.get_minimum_size(), "boyut korunur: " + name)
		var copy := updated.duplicate() as StyleBox
		check(copy.get("surface") != null and copy.get("frame") != null, "kopyada malzeme korunur: " + name)
		copy.set("draw_center", false)
		check(updated.get("draw_center"), "araştırma dolgusu kopyası asıl stili değiştirmez")
		copy.set_content_margin_all(1)
		original.set_content_margin_all(1)
		eq(copy.get_minimum_size(), original.get_minimum_size(), "ikon butonu boyutu korunur: " + name)
	var normal: Color = UiTheme.skin("button").get("surface_tint")
	var hover: Color = UiTheme.skin("button_hover").get("surface_tint")
	var disabled: Color = UiTheme.skin("button_disabled").get("surface_tint")
	gt(hover.get_luminance(), normal.get_luminance(), "hover daha açık")
	lt(disabled.get_luminance(), normal.get_luminance(), "disabled daha koyu")
