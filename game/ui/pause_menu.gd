class_name PauseMenu
extends Control
## Esc menüsü: devam, kaydet, yükle, ayarlar, ana menü, çıkış.

signal to_main_menu
signal load_requested(slot: String)

var _box: VBoxContainer
var _panel: PanelContainer
var _settings_panel: SettingsPanel
var _was_paused := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CommandPanelSkin.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.023, 0.025, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "PauseWindow"
	CommandPanelSkin.apply(_panel)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	resized.connect(_fit_window)
	_fit_window()

func _fit_window() -> void:
	_panel.custom_minimum_size.x = minf(480.0, maxf(280.0, get_viewport_rect().size.x - 48.0))

func toggle() -> void:
	if visible:
		close()
	else:
		_was_paused = GameClock.paused
		GameClock.set_paused(true)
		visible = true
		_main()

func close() -> void:
	if is_instance_valid(_settings_panel):
		remove_child(_settings_panel)
		_settings_panel.queue_free()
		_settings_panel = null
	_panel.show()
	visible = false
	GameClock.set_paused(_was_paused)

func _clear(title: String) -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	hp.add_child(row)
	row.add_child(UiTheme.icon_texture(CommandPanelSkin.icon("politics"), 30))
	var t := UiTheme.make_label(title.to_upper(), 22, UiTheme.ACCENT)
	t.name = "PauseTitle"
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var key := UiTheme.make_label("ESC", 13, UiTheme.TEXT_DIM)
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)
	_box.add_child(hp)
	var c := World.player()
	if c != null:
		var identity := PanelContainer.new()
		identity.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 10))
		_box.add_child(identity)
		var country := HBoxContainer.new()
		country.add_theme_constant_override("separation", 12)
		identity.add_child(country)
		var flag := UiTheme.icon_texture(FlagFactory.get_flag(c), 48)
		flag.custom_minimum_size = Vector2(64, 44)
		country.add_child(flag)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		country.add_child(info)
		var name_label := UiTheme.make_label(c.display_name(), 18, UiTheme.TEXT)
		name_label.name = "PauseCountry"
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(name_label)
		var date := UiTheme.make_label(GameClock.date_string(), 14, UiTheme.TEXT_DIM)
		date.name = "PauseDate"
		info.add_child(date)

func _btn(text: String, fn: Callable, tip := "", parent: Container = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 54
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_font_size_override("font_size", UiTheme.fs(20))
	b.add_theme_stylebox_override("focus", CommandPanelSkin.tab_box("focus"))
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text = tip
	b.pressed.connect(fn)
	(parent if parent != null else _box).add_child(b)
	return b

func _main() -> void:
	_clear(tr("PAUSE_TITLE"))
	var resume := _btn(tr("PAUSE_RESUME"), close)
	resume.name = "PauseResume"
	resume.add_theme_stylebox_override("normal", CommandPanelSkin.box("selected", 10))
	resume.add_theme_stylebox_override("hover", CommandPanelSkin.box("selected", 10))
	resume.add_theme_color_override("font_color", UiTheme.ACCENT)
	resume.icon = UiTheme.icon("play")
	resume.expand_icon = true
	resume.add_theme_constant_override("icon_max_width", 24)
	var save := _btn(tr("PAUSE_SAVE"), func() -> void:
		var slot := "%s_%d_%02d_%02d" % [World.player_tag, GameClock.year, GameClock.month, GameClock.day]
		Game.save_game(slot)
		close(), tr("TIP_SAVE"))
	save.name = "PauseSave"
	_btn(tr("PAUSE_LOAD"), _load_list).name = "PauseLoad"
	_btn(tr("PAUSE_SETTINGS"), _settings).name = "PauseSettings"
	var divider := HSeparator.new()
	_box.add_child(divider)
	_btn(tr("PAUSE_MAIN_MENU"), func() -> void:
		visible = false
		to_main_menu.emit()).name = "PauseMainMenu"
	var quit := _btn(tr("MENU_QUIT"), func() -> void: get_tree().quit())
	quit.name = "PauseQuit"
	quit.add_theme_color_override("font_color", Color("cdb6a5"))
	resume.grab_focus()

func _load_list() -> void:
	_show_saves(Game.list_saves())

func _show_saves(saves: Array[String]) -> void:
	_clear(tr("PAUSE_LOAD"))
	var scroll := ScrollContainer.new()
	scroll.name = "PauseSaves"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(280.0, maxf(140.0, get_viewport_rect().size.y - 350.0))
	scroll.follow_focus = true
	_box.add_child(scroll)
	DragScroll.attach(scroll)
	var list := VBoxContainer.new()
	list.name = "PauseSaveList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if saves.is_empty():
		var empty := UiTheme.make_label(tr("LOAD_NONE"), 18, UiTheme.TEXT_DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty)
	for s in saves.slice(0, 10):
		_btn(s, func() -> void:
			visible = false
			load_requested.emit(s), s, list)
	var back := _btn(tr("SELECT_BACK"), _main)
	back.name = "PauseBack"
	back.grab_focus()

func _settings() -> void:
	if is_instance_valid(_settings_panel): return
	_panel.hide()
	_settings_panel = SettingsPanel.new()
	_settings_panel.command_style = true
	_settings_panel.closed.connect(_settings_closed)
	add_child(_settings_panel)

func _settings_closed() -> void:
	_settings_panel = null
	_panel.show()
	_main()
