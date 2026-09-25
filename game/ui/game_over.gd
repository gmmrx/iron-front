class_name GameOverScreen
extends Control
## Oyun sonu: zafer/yenilgi, zafer puanı sıralaması.

signal to_main_menu
signal continue_pressed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	Game.game_over.connect(_show)

func _show(victory: bool, reason: String) -> void:
	for ch in get_children():
		ch.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(520, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := UiTheme.make_label(tr("GAMEOVER_VICTORY") if victory else tr("GAMEOVER_LOST"), 40, UiTheme.ACCENT if victory else UiTheme.BAD)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := UiTheme.make_label(tr(reason), 19)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.make_label(tr("GAMEOVER_RANKING"), 17, UiTheme.TEXT_DIM))
	var rows := []
	for c: Country in World.countries.values():
		if c.exists():
			rows.append([Game.score(c.tag), c])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in mini(rows.size(), 8):
		var c: Country = rows[i][1]
		var l := UiTheme.make_label("%d. %s — %d %s" % [i + 1, c.display_name(), rows[i][0], tr("UI_VICTORY_POINTS")], 17, UiTheme.ACCENT if c.tag == World.player_tag else UiTheme.TEXT)
		v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	if victory:
		var cont := Button.new()
		cont.text = tr("GAMEOVER_CONTINUE")
		cont.pressed.connect(func() -> void:
			visible = false
			Game.over = false
			continue_pressed.emit())
		h.add_child(cont)
	var menu := Button.new()
	menu.text = tr("PAUSE_MAIN_MENU")
	menu.pressed.connect(func() -> void:
		visible = false
		to_main_menu.emit())
	h.add_child(menu)
	v.add_child(h)
	visible = true
