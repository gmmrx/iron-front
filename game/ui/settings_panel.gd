class_name SettingsPanel
extends Control
## Ayarlar (ana menü ve oyun içi menü): ses düzeyleri (genel, müzik, efekt, arayüz), müzik seçimi (oyun durumuna göre
## ya da dilediğin parça sürekli), dil (anında: oyun içinde durum korunarak arayüz yeni dilde kurulur), tam ekran,
## kenar kaydırma. Her değişiklik GameSettings ile kaydedilir.

signal closed

const TRACKS := ["main_theme", "peace_1", "peace_2", "tension", "war_world", "war_front", "war_hold"]

var _music_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(980, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	v.add_child(hp)
	var hb := HBoxContainer.new()
	hp.add_child(hb)
	var t := UiTheme.make_label(tr("PAUSE_SETTINGS").to_upper(), 24, UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	hb.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), _close, 30))
	var cols := PanelLayout.columns(v, [1.0, 1.0], 20)
	# --- ses
	var left := cols[0]
	PanelLayout.section(left, tr("SET_SECTION_SOUND"))
	_slider(left, tr("SET_VOLUME"), GameSettings.master, func(x: float) -> void:
		GameSettings.master = x
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(x, 0.0001))))
	_slider(left, tr("SET_MUSIC"), GameSettings.music, func(x: float) -> void:
		GameSettings.music = x
		Audio.set_music_linear(x))
	_slider(left, tr("SET_SFX"), GameSettings.sfx, func(x: float) -> void:
		GameSettings.sfx = x
		Audio.set_sfx_linear(x)
		Audio.play("notify_good", 250))
	_slider(left, tr("SET_UI_SOUNDS"), GameSettings.ui, func(x: float) -> void:
		GameSettings.ui = x
		Audio.set_ui_linear(x)
		Audio.play("ui_click", 120))
	# --- görüntü ve oyun
	PanelLayout.section(left, tr("SET_SECTION_DISPLAY"))
	if not OS.has_feature("web"):
		_check(left, tr("SET_FULLSCREEN"), GameSettings.fullscreen, func(on: bool) -> void:
			GameSettings.fullscreen = on
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	_check(left, tr("SET_EDGE_PAN"), GameSettings.edge_pan, func(on: bool) -> void: GameSettings.edge_pan = on)
	if World.in_game:
		_check(left, tr("SET_AI"), AI.enabled, func(on: bool) -> void: AI.enabled = on)
	# --- dil
	var right := cols[1]
	PanelLayout.section(right, tr("SET_SECTION_LANG"))
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 8)
	right.add_child(lr)
	var cur := TranslationServer.get_locale().substr(0, 2)
	for pair: Array in [["tr", tr("SET_LANG_TR")], ["en", tr("SET_LANG_EN")]]:
		var b := Button.new()
		b.theme_type_variation = "Card"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_pressed_no_signal(cur == pair[0])
		b.text = pair[1]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiTheme.fs(17))
		b.pressed.connect(func() -> void: _set_lang(pair[0]))
		lr.add_child(b)
	PanelLayout.empty(right, tr("SET_LANG_HINT"))
	# --- müzik
	PanelLayout.section(right, tr("SET_SECTION_MUSIC"))
	_music_box = VBoxContainer.new()
	_music_box.add_theme_constant_override("separation", 3)
	right.add_child(_music_box)
	_build_music()
	var done := PanelLayout.small_button(tr("SET_DONE"), _close)
	done.custom_minimum_size = Vector2(220, 42)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(done)

func _slider(parent: Container, label: String, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := UiTheme.make_label(label, 16)
	l.custom_minimum_size.x = 150
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	row.add_child(sl)
	var pct := UiTheme.make_label("%d%%" % roundi(value * 100), 16, UiTheme.ACCENT)
	pct.add_theme_font_override("font", UiTheme.bold_font())
	pct.custom_minimum_size.x = 56
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	sl.value_changed.connect(func(x: float) -> void:
		pct.text = "%d%%" % roundi(x * 100)
		cb.call(x)
		GameSettings.save())

func _check(parent: Container, label: String, on: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = label
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", UiTheme.fs(16))
	c.toggled.connect(func(x: bool) -> void:
		cb.call(x)
		GameSettings.save())
	parent.add_child(c)

## Müzik: "Otomatik" (oyun durumuna göre) ya da bir parça seç (sürekli çalar); süreleriyle
func _build_music() -> void:
	for ch in _music_box.get_children():
		ch.queue_free()
	var items: Array = [["", tr("SET_MUSIC_AUTO"), tr("SET_MUSIC_AUTO_TIP")]]
	for n: String in TRACKS:
		var st: AudioStream = Audio._music_stream(n)
		var len_txt := ""
		if st:
			var sec := int(st.get_length())
			len_txt = "%d:%02d" % [sec / 60, sec % 60]
		items.append([n, tr("MUSIC_" + n), len_txt])
	for it: Array in items:
		var b := Button.new()
		b.theme_type_variation = "Card"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_pressed_no_signal(Audio.forced_track == it[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = UiTheme.trimmed(UiTheme.icon("play"))
		b.add_theme_constant_override("icon_max_width", 18)
		b.text = "%s%s" % [it[1], ("   " + it[2]) if it[0] != "" and it[2] != "" else ""]
		b.tooltip_text = it[1] + ("\n" + it[2] if it[0] == "" else "")
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", UiTheme.fs(15))
		if Audio._track == it[0] and it[0] != "":
			b.add_theme_color_override("font_color", UiTheme.ACCENT)
		var key: String = it[0]
		b.pressed.connect(func() -> void:
			GameSettings.music_track = key
			Audio.set_forced_track(key)
			GameSettings.save()
			_build_music.call_deferred())
		_music_box.add_child(b)

## Dil: kaydet ve arayüzü yeni dilde yeniden kur. Oyun içindeysek oyun durumu korunur (sahne yeniden kurulunca
## Game.loaded ile kaldığı yerden devam eder).
func _set_lang(code: String) -> void:
	if TranslationServer.get_locale().begins_with(code):
		return
	GameSettings.lang = code
	GameSettings.save()
	TranslationServer.set_locale(code)
	Game.reopen_settings = true
	if World.in_game:
		Game.loaded = true
		var main := get_tree().current_scene
		if main and "camera" in main and main.camera:
			Game.resume_view = Vector3(main.camera.target.x, main.camera.target.z, main.camera.distance)
		if main and "hud" in main and main.hud:
			Game.resume_was_paused = main.hud.pause_menu._was_paused
	get_tree().reload_current_scene()

func _close() -> void:
	closed.emit()
	queue_free()
