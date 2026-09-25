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
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	var t := UiTheme.make_label((tr("GAMEOVER_VICTORY") if victory else tr("GAMEOVER_LOST")).to_upper(), 34, UiTheme.ACCENT if victory else UiTheme.BAD)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(t)
	v.add_child(hp)
	var r := UiTheme.make_label(tr(reason), 19)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	PanelLayout.section(v, tr("GAMEOVER_RANKING"))
	var rows := []
	for c: Country in World.countries.values():
		if c.exists():
			rows.append([Game.score(c.tag), c])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in mini(rows.size(), 8):
		var c: Country = rows[i][1]
		var col := PanelLayout.row(v, FlagFactory.get_flag(c), "%d. %s" % [i + 1, c.display_name()], "%d %s" % [rows[i][0], tr("UI_VICTORY_POINTS")], "",
			"SlotGold" if c.tag == World.player_tag else "Row")
		col.get_child(0).add_theme_color_override("font_color", UiTheme.ACCENT if c.tag == World.player_tag else UiTheme.TEXT)
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
