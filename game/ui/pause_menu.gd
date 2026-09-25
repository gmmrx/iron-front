class_name PauseMenu
extends Control
## Esc menüsü: devam, kaydet, yükle, ayarlar, ana menü, çıkış.

signal to_main_menu
signal load_requested(slot: String)

var _box: VBoxContainer
var _was_paused := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)

func toggle() -> void:
	if visible:
		close()
	else:
		_was_paused = GameClock.paused
		GameClock.set_paused(true)
		visible = true
		_main()

func close() -> void:
	visible = false
	GameClock.set_paused(_was_paused)

func _clear(title: String) -> void:
	for ch in _box.get_children():
		ch.queue_free()
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	var t := UiTheme.make_label(title.to_upper(), 22, UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(t)
	_box.add_child(hp)

func _btn(text: String, fn: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(fn)
	_box.add_child(b)
	return b

func _main() -> void:
	_clear(tr("PAUSE_TITLE"))
	_btn(tr("PAUSE_RESUME"), close)
	_btn(tr("PAUSE_SAVE"), func() -> void:
		var slot := "%s_%d_%02d_%02d" % [World.player_tag, GameClock.year, GameClock.month, GameClock.day]
		Game.save_game(slot)
		close(), tr("TIP_SAVE"))
	_btn(tr("PAUSE_LOAD"), _load_list)
	_btn(tr("PAUSE_SETTINGS"), _settings)
	_btn(tr("PAUSE_MAIN_MENU"), func() -> void:
		visible = false
		to_main_menu.emit())
	_btn(tr("MENU_QUIT"), func() -> void: get_tree().quit())

func _load_list() -> void:
	_clear(tr("PAUSE_LOAD"))
	var saves := Game.list_saves()
	if saves.is_empty():
		_box.add_child(UiTheme.make_label(tr("LOAD_NONE"), 16, UiTheme.TEXT_DIM))
	for s in saves.slice(0, 10):
		_btn(s, func() -> void:
			visible = false
			load_requested.emit(s))
	_btn(tr("SELECT_BACK"), _main)

func _settings() -> void:
	_clear(tr("PAUSE_SETTINGS"))
	var fs := CheckButton.new()
	fs.text = tr("SET_FULLSCREEN")
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	_box.add_child(fs)
	var lang := CheckButton.new()
	lang.text = tr("SET_ENGLISH")
	lang.button_pressed = TranslationServer.get_locale().begins_with("en")
	lang.toggled.connect(func(on: bool) -> void:
		TranslationServer.set_locale("en" if on else "tr")
		World.notify(tr("SET_LANG_NOTE"), "info"))
	_box.add_child(lang)
	var edge := CheckButton.new()
	edge.text = tr("SET_EDGE_PAN")
	var cam := get_viewport().get_camera_3d()
	edge.button_pressed = cam.edge_pan_enabled if cam and "edge_pan_enabled" in cam else true
	edge.toggled.connect(func(on: bool) -> void:
		if cam and "edge_pan_enabled" in cam: cam.edge_pan_enabled = on)
	_box.add_child(edge)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol.custom_minimum_size.x = 300
	vol.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001))))
	_box.add_child(UiTheme.make_label(tr("SET_VOLUME"), 16))
	_box.add_child(vol)
	for pair in [["SET_MUSIC", Audio.music_linear(), Audio.set_music_linear], ["SET_SFX", Audio.sfx_linear(), Audio.set_sfx_linear]]:
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = pair[1]
		sl.custom_minimum_size.x = 300
		sl.value_changed.connect(pair[2])
		_box.add_child(UiTheme.make_label(tr(pair[0]), 16))
		_box.add_child(sl)
	var ai := CheckButton.new()
	ai.text = tr("SET_AI")
	ai.button_pressed = AI.enabled
	ai.toggled.connect(func(on: bool) -> void: AI.enabled = on)
	_box.add_child(ai)
	_btn(tr("SELECT_BACK"), _main)
