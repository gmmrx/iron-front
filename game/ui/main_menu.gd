class_name MainMenu
extends Control
## Ana menü: arkada 3D harita süzülür; solda başlık ve menü.

signal new_game_pressed
signal quit_pressed
signal load_pressed(slot: String)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_vignette())

	# sol şerit: menünün okunur olması için koyu geçiş
	var band := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.025, 0.03, 0.92))
	g.set_color(1, Color(0.02, 0.025, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	band.texture = gt
	band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 900
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 110
	col.offset_top = -300
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var title := UiTheme.make_label("IRON FRONT", 104, UiTheme.ACCENT)
	var tf := FontVariation.new()
	tf.base_font = load("res://assets/fonts/CinzelVariable.ttf")
	tf.variation_opentype = {"wght": 900}
	tf.spacing_glyph = 6
	title.add_theme_font_override("font", tf)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	col.add_child(title)
	var sub := UiTheme.make_label(tr("MENU_SUBTITLE"), 24, UiTheme.TEXT)
	var sf := FontVariation.new()
	sf.base_font = UiTheme.bold_font()
	sf.spacing_glyph = 5
	sub.add_theme_font_override("font", sf)
	col.add_child(sub)

	var line := ColorRect.new()
	line.color = Color(UiTheme.ACCENT, 0.7)
	line.custom_minimum_size = Vector2(420, 2)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26
	col.add_child(spacer)
	col.add_child(line)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 18
	col.add_child(spacer2)

	col.add_child(_menu_button(tr("MENU_NEW_GAME"), true, func() -> void: new_game_pressed.emit()))
	var saves := Game.list_saves()
	col.add_child(_menu_button(tr("MENU_CONTINUE"), not saves.is_empty(), func() -> void: load_pressed.emit(saves[0])))
	col.add_child(_menu_button(tr("MENU_SETTINGS"), false, Callable()))
	col.add_child(_menu_button(tr("MENU_QUIT"), true, func() -> void: quit_pressed.emit()))

	var ver := UiTheme.make_label("v0.3 — Faz 1-9", 15, UiTheme.TEXT_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 24
	ver.offset_top = -36
	add_child(ver)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.9)

static func _vignette() -> TextureRect:
	var v := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	g.add_point(0.55, Color(0, 0, 0, 0.1))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	v.texture = gt
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func _menu_button(text: String, enabled: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(420, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	f.spacing_glyph = 3
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 28)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 18
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 0.85, 0.5, 0.08)
	hover.border_color = UiTheme.ACCENT
	hover.border_width_left = 4
	hover.content_margin_left = 26
	var pressed := hover.duplicate()
	pressed.bg_color = Color(1, 0.85, 0.5, 0.16)
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_color_override("font_color", UiTheme.TEXT)
	b.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(UiTheme.TEXT_DIM, 0.45))
	if enabled and action.is_valid():
		b.pressed.connect(action)
	return b
