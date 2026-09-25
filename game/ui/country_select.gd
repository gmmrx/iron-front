class_name CountrySelect
extends Control
## Ülke seçim ekranı: üstte büyük güç kartları, sağda seçili ülkenin detayları.
## Haritadan herhangi bir ülkeye tıklayarak da seçim yapılır (main.gd yönlendirir).

signal start_pressed(tag: String)
signal back_pressed
signal selection_changed(tag: String)

const FEATURED := ["GER", "ENG", "FRA", "ITA", "SOV", "TUR", "POL", "SPR"]

var selected := ""
var _cards := {}
var _flag: TextureRect
var _name: Label
var _leader: Label
var _rows := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- üst: öne çıkan ülkeler
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 18
	var tsb := UiTheme.panel_style(Color(0.05, 0.06, 0.06, 0.88), UiTheme.BORDER)
	tsb.set_content_margin_all(14)
	top.add_theme_stylebox_override("panel", tsb)
	add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	top.add_child(tv)
	var head := UiTheme.make_label(tr("SELECT_TITLE"), 26, UiTheme.ACCENT)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	tv.add_child(row)
	for tag in FEATURED:
		var c: Country = World.countries.get(tag)
		if c:
			row.add_child(_card(c))
	var hint := UiTheme.make_label(tr("SELECT_HINT"), 15, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(hint)

	# --- sağ: detay paneli
	var side := PanelContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -430
	side.offset_right = -18
	side.offset_top = 250
	side.offset_bottom = -18
	var ssb := UiTheme.panel_style(Color(0.05, 0.06, 0.06, 0.92), UiTheme.BORDER)
	ssb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", ssb)
	add_child(side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	side.add_child(v)
	var frame := PanelContainer.new()
	var fsb := UiTheme.panel_style(Color.BLACK, UiTheme.ACCENT)
	fsb.set_content_margin_all(2)
	fsb.shadow_size = 10
	frame.add_theme_stylebox_override("panel", fsb)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(240, 160)
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	frame.add_child(_flag)
	v.add_child(frame)
	_name = UiTheme.make_label("", 32, UiTheme.ACCENT)
	_name.add_theme_font_override("font", UiTheme.title_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_name)
	_leader = UiTheme.make_label("", 18, UiTheme.TEXT_DIM)
	_leader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_leader)
	v.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for key in ["UI_POPULATION", "UI_MANPOWER", "SELECT_STATES", "UI_VICTORY_POINTS", "UI_STABILITY_TIP", "UI_WAR_SUPPORT_TIP"]:
		grid.add_child(UiTheme.make_label(tr(key), 19, UiTheme.TEXT_DIM))
		var val := UiTheme.make_label("", 19)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
		_rows[key] = val
	v.add_child(grid)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)

	var start := Button.new()
	start.text = tr("SELECT_START").to_upper()
	start.custom_minimum_size = Vector2(0, 58)
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font_size", 26)
	start.add_theme_font_override("font", UiTheme.bold_font())
	var sn := UiTheme.panel_style(Color("5a4a22"), UiTheme.ACCENT, 2)
	var sh := UiTheme.panel_style(Color("73602c"), Color("f5d78a"), 2)
	start.add_theme_stylebox_override("normal", sn)
	start.add_theme_stylebox_override("hover", sh)
	start.add_theme_stylebox_override("pressed", sh)
	start.add_theme_color_override("font_color", Color("f5e6c0"))
	start.pressed.connect(func() -> void: start_pressed.emit(selected))
	v.add_child(start)
	var back := Button.new()
	back.text = tr("SELECT_BACK")
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: back_pressed.emit())
	v.add_child(back)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

func _card(c: Country) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(128, 122)
	b.icon = FlagFactory.get_flag(c)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = c.map_name()
	b.clip_text = true
	b.add_theme_constant_override("icon_max_width", 104)
	b.add_theme_font_size_override("font_size", 17)
	var n := UiTheme.panel_style(Color(0.1, 0.11, 0.1, 0.9), UiTheme.BORDER_DIM)
	n.set_content_margin_all(8)
	var h := UiTheme.panel_style(Color(0.16, 0.17, 0.15, 0.95), UiTheme.BORDER)
	h.set_content_margin_all(8)
	var p := UiTheme.panel_style(Color(0.28, 0.24, 0.12, 0.95), UiTheme.ACCENT, 2)
	p.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.pressed.connect(func() -> void: select(c.tag))
	_cards[c.tag] = b
	return b

func select(tag: String) -> void:
	var c: Country = World.countries.get(tag)
	if c == null or c.states.is_empty():
		return
	selected = tag
	for t: String in _cards:
		_cards[t].set_pressed_no_signal(t == tag)
	_flag.texture = FlagFactory.get_flag(c)
	_name.text = c.display_name()
	_leader.text = "%s\n%s" % [c.leader, tr("IDEOLOGY_" + c.ideology)]
	var vp := 0
	for sid in c.states:
		vp += World.states[sid].victory_points()
	_rows["UI_POPULATION"].text = UiTheme.format_number(c.population)
	_rows["UI_MANPOWER"].text = UiTheme.format_number(c.recruitable_manpower())
	_rows["SELECT_STATES"].text = str(c.states.size())
	_rows["UI_VICTORY_POINTS"].text = str(vp)
	_rows["UI_STABILITY_TIP"].text = "%d%%" % roundi(c.stability * 100)
	_rows["UI_WAR_SUPPORT_TIP"].text = "%d%%" % roundi(c.war_support * 100)
	selection_changed.emit(tag)
