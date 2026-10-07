class_name MainMenu
extends Control
## Ana menü: arka plan resmi (assets/ui/menu-bg.png, yükleme ekranıyla aynı), üstte logo, altında ortalı menü.
## intro: açılış yükleme ekranından gelindi — arka plan ve logo yükleme ekranındakiyle aynı yerde hazır, yalnız
## düğmeler sırayla belirir (logo yükleme ekranında küçülüp buraya gelmişti).

signal new_game_pressed
signal tutorial_pressed
signal quit_pressed
signal load_pressed(slot: String)
signal dev_war_pressed
signal scenarios_pressed

const LOGO_W := 560.0                  ## menüdeki logo genişliği
const LOGO_TOP := 0.07                 ## logonun üst kenarı (ekran yüksekliğinin payı)

var intro := false

## Menü ve yükleme ekranının ortak arka planı: resim ekranı doldurur (oran korunur, taşan kırpılır)
static func background() -> TextureRect:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu-bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

## Menüde logonun yeri (yükleme ekranındaki logo buraya küçülür)
static func logo_rect(vp: Vector2) -> Rect2:
	var tex: Texture2D = load("res://assets/ui/logo.png")
	var w := minf(LOGO_W, vp.x * 0.5)
	var ls := Vector2(w, w * tex.get_height() / tex.get_width())
	return Rect2(Vector2((vp.x - ls.x) * 0.5, vp.y * LOGO_TOP), ls)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background())
	add_child(_vignette())
	var vp := get_viewport_rect().size
	var lr := logo_rect(vp)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = lr.position
	logo.size = lr.size
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.position = Vector2((vp.x - 420.0) * 0.5, lr.end.y + 40.0)
	col.custom_minimum_size.x = 420
	add_child(col)
	var buttons: Array[Button] = []
	# senaryolar oynanmaz (docs/DESIGN.md: oyun 1936'dan serbest oyun); senaryo sistemi kodda durur
	buttons.append(_menu_button(tr("MENU_NEW_GAME"), true, func() -> void: new_game_pressed.emit(), "menu_new_game"))
	var tut := _menu_button(tr("MENU_TUTORIAL"), true, func() -> void: tutorial_pressed.emit(), "menu_tutorial")
	tut.tooltip_text = tr("TIP_MENU_TUTORIAL")
	buttons.append(tut)
	var saves := Game.list_saves()
	buttons.append(_menu_button(tr("MENU_CONTINUE"), not saves.is_empty(), func() -> void: load_pressed.emit(saves[0]), "menu_continue"))
	buttons.append(_menu_button(tr("MENU_SETTINGS"), true, open_settings, "menu_settings"))
	if OS.is_debug_build():
		# yalnız geliştirici sürümünde (editör / yerel çalıştırma; web yayını release): savaş demosu kaydıyla doğrudan
		# cephenin ortasına (game/dev/war_demo.gd yazar)
		var has_demo := FileAccess.file_exists(Game.SAVE_DIR + "war_demo_watch.json") or FileAccess.file_exists(Game.SAVE_DIR + "war_demo.json")
		var dev := _menu_button(tr("MENU_DEV_WAR"), has_demo, func() -> void: dev_war_pressed.emit(), "menu_continue")
		dev.tooltip_text = tr("TIP_DEV_WAR") if has_demo else tr("TIP_DEV_WAR_MISSING")
		buttons.append(dev)
	buttons.append(_menu_button(tr("MENU_QUIT"), true, func() -> void: quit_pressed.emit(), "menu_quit"))
	for b in buttons:
		col.add_child(b)

	var ver := UiTheme.make_label("v0.3 — Faz 1-9", 15, UiTheme.TEXT_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 24
	ver.offset_top = -36
	add_child(ver)

	if intro:
		# düğmeler sırayla, hafif aşağıdan belirir
		for i in buttons.size():
			var b := buttons[i]
			b.modulate.a = 0.0
			var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "modulate:a", 1.0, 0.35).set_delay(0.07 * i)
		ver.modulate.a = 0.0
		create_tween().tween_property(ver, "modulate:a", 1.0, 0.6)
	else:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

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

func _menu_button(text: String, enabled: bool, action: Callable, cue := "menu_click") -> Button:
	var b := Button.new()
	Audio.ui_bind(b, cue, "menu_hover")
	b.text = CountrySelect.upper(text)             # Türkçede i → İ (to_upper noktasız yapıyordu)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(420, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	f.spacing_glyph = 3
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", UiTheme.fs(28))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0, 0, 0, 0.38)
	hover.border_color = Color(UiTheme.ACCENT, 0.8)
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0, 0, 0, 0.5)
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_color_override("font_color", UiTheme.TEXT)
	b.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(UiTheme.TEXT_DIM, 0.55))
	if enabled and action.is_valid():
		b.pressed.connect(action)
	return b

func open_settings() -> void:
	add_child(SettingsPanel.new())
