class_name FocusPanel
extends PanelContainer
## Milli odak ağacı (F): tam ekran, kaydırılabilir grafik; odaklar önkoşul çizgileriyle bağlı.

const CELL := Vector2(236, 168)
const NODE := Vector2(212, 140)

var _canvas: Control
var _status: Label
var _buttons := {}

class Lines extends Control:
	var owner_panel
	func _draw() -> void:
		owner_panel._draw_lines(self)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 40
	offset_top = 120
	offset_right = -40
	offset_bottom = -40
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	v.add_child(hp)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	hp.add_child(head)
	head.add_child(UiTheme.icon_texture(UiTheme.icon("focus_g_unity"), 30))
	var title := UiTheme.make_label(tr("FOCUS_TITLE").to_upper(), 22, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_status = UiTheme.make_label("", 17)
	_status.add_theme_font_override("font", UiTheme.bold_font())
	head.add_child(_status)
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), close, 28))
	var help := UiTheme.make_label(tr("FOCUS_HELP"), 14, UiTheme.TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_canvas = Lines.new()
	_canvas.owner_panel = self
	scroll.add_child(_canvas)
	Politics.politics_changed.connect(func(t: String) -> void:
		if visible and t == World.player_tag: refresh())
	Politics.focus_completed.connect(func(t: String, _f: String) -> void:
		if visible and t == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: _update_status())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func _update_status() -> void:
	var c := World.player()
	if c.focus_current == "":
		_status.text = tr("FOCUS_NONE")
		_status.add_theme_color_override("font_color", UiTheme.BAD)
	else:
		var fo := Politics.focus_def(c, c.focus_current)
		_status.text = tr("FOCUS_CURRENT") % [Politics.loc(fo["name"]), int(float(fo["days"]) - c.focus_progress)]
		_status.add_theme_color_override("font_color", UiTheme.ACCENT)

func refresh() -> void:
	_update_status()
	for ch in _canvas.get_children():
		ch.queue_free()
	_buttons.clear()
	var c := World.player()
	var tree := Politics.tree_of(c)
	var maxp := Vector2.ZERO
	for id: String in tree:
		var fo: Dictionary = tree[id]
		var pos := Vector2(float(fo["x"]) * CELL.x + 20, float(fo["y"]) * CELL.y + 20)
		maxp = maxp.max(pos + NODE)
		var b := Button.new()
		b.position = pos
		b.size = NODE
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.icon = UiTheme.focus_icon(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 74)
		var done := id in c.focus_done
		var current := id == c.focus_current
		var can := Politics.can_start_focus(c, id)
		b.text = "%s\n%d %s" % [Politics.loc(fo["name"]), int(fo["days"]), tr("UI_DAYS")]
		# durum: bitti (yeşil), yürüyor (altın + ilerleme), seçilebilir (parlak), kilitli (soluk)
		var style := "card"
		if done:
			style = "slot_good"
			b.text = "✓ " + Politics.loc(fo["name"])
			b.add_theme_color_override("font_color", Color("b9e6a0"))
		elif current:
			style = "slot_gold"
			b.text = "%s\n%d / %d %s" % [Politics.loc(fo["name"]), int(c.focus_progress), int(fo["days"]), tr("UI_DAYS")]
			b.add_theme_color_override("font_color", UiTheme.ACCENT)
			var pb := PanelLayout.progress(c.focus_progress / maxf(float(fo["days"]), 1.0), UiTheme.ACCENT, 6.0)
			pb.position = Vector2(10, NODE.y - 12)
			pb.size = Vector2(NODE.x - 20, 6)
			b.add_child(pb)
		elif can:
			style = "card_hover"
			b.add_theme_color_override("font_color", Color("f3e7c4"))
		else:
			style = "slot"
			b.self_modulate = Color(0.75, 0.75, 0.75)
			b.add_theme_color_override("icon_normal_color", Color(0.55, 0.55, 0.55))
			b.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		for st: String in ["normal", "hover", "pressed", "disabled"]:
			var sb := UiTheme.skin(style if st != "hover" or not can else "card_selected", 8, 6)
			sb.content_margin_top = 8
			b.add_theme_stylebox_override(st, sb)
		var tip := Politics.loc(fo["name"])
		var desc := Politics.loc(fo.get("desc", {}))
		if desc != "":
			tip += "\n" + desc
		var eff := Politics.describe_effects(fo["effects"])
		if eff != "":
			tip += "\n\n" + tr("FOCUS_EFFECTS") + "\n" + eff
		if not fo["available"].is_empty() and not Politics.check_all(c, fo["available"]):
			tip += "\n\n" + tr("FOCUS_NOT_AVAILABLE")
			for cond: Dictionary in fo["available"]:
				if cond.has("date"):
					tip += "\n• " + tr("FOCUS_DATE") % cond["date"]
		if not fo["exclusive"].is_empty():
			tip += "\n" + tr("FOCUS_EXCLUSIVE")
		b.tooltip_text = tip
		b.pressed.connect(func() -> void:
			if can:
				Politics.start_focus(c, id)
			elif current:
				Politics.cancel_focus(c))
		_canvas.add_child(b)
		_buttons[id] = b
	_canvas.custom_minimum_size = maxp + Vector2(40, 40)
	_canvas.queue_redraw()

func _draw_lines(ctrl: Control) -> void:
	var c := World.player()
	var tree := Politics.tree_of(c)
	for id: String in tree:
		var fo: Dictionary = tree[id]
		if not _buttons.has(id):
			continue
		var to: Button = _buttons[id]
		for p: String in fo["prereq"] + fo["any_prereq"]:
			if not _buttons.has(p):
				continue
			var from: Button = _buttons[p]
			var a := from.position + Vector2(NODE.x * 0.5, NODE.y)
			var b := to.position + Vector2(NODE.x * 0.5, 0)
			var col := UiTheme.ACCENT if p in c.focus_done else UiTheme.BORDER_DIM
			var mid := (a.y + b.y) * 0.5
			ctrl.draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b]), col, 3.0, true)
		for x: String in fo["exclusive"]:
			if _buttons.has(x) and id < x:
				var p1: Vector2 = to.position + Vector2(NODE.x, NODE.y * 0.5)
				var p2: Vector2 = _buttons[x].position + Vector2(0, NODE.y * 0.5)
				ctrl.draw_dashed_line(p1, p2, UiTheme.BAD, 2.0, 8.0)
