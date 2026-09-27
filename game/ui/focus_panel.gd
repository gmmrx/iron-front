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
	# tam ekran: sol menünün sağından ekranın sağına, üst satırın altından alta
	offset_left = PanelLayout.SIDE_LEFT
	offset_top = PanelLayout.SIDE_TOP
	offset_right = -PanelLayout.SIDE_RIGHT
	offset_bottom = -PanelLayout.SIDE_BOTTOM
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
	DragScroll.attach(scroll, true)      # kaydırma çubuğu yok: basılı tutup sürükle
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
	Audio.panel(true)
	refresh()

func close() -> void:
	if visible:
		Audio.panel(false)
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
		var done := id in c.focus_done
		var current := id == c.focus_current
		var can := Politics.can_start_focus(c, id)
		var b := FocusNode.new()
		b.position = pos
		b.size = NODE
		b.focus_mode = Control.FOCUS_NONE
		b.tex = UiTheme.trimmed(UiTheme.focus_icon(id))
		b.state = 0 if done else (1 if current else (2 if can else 3))
		b.progress = c.focus_progress / maxf(float(fo["days"]), 1.0) if current else 0.0
		var fname := Politics.loc(fo["name"])
		var sub := "%d %s" % [int(fo["days"]), tr("UI_DAYS")]
		if done:
			fname = "✓ " + fname
			sub = ""
		elif current:
			sub = "%d / %d %s" % [int(c.focus_progress), int(fo["days"]), tr("UI_DAYS")]
		b.setup(fname, sub)
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

## Program düğümü: yuvarlak resim (arkaplan kartı yok), durum halkası, altında ad ve gün. Tıklanabilir düğme.
## state: 0 bitti (yeşil), 1 sürüyor (altın + ilerleme yayı), 2 seçilebilir (parlak), 3 kilitli (soluk)
class FocusNode extends Button:
	const D := 100.0                  ## daire çapı
	var tex: Texture2D
	var state := 3
	var progress := 0.0
	var _hover := false

	func _init() -> void:
		flat = true
		for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
		mouse_exited.connect(func() -> void: _hover = false; queue_redraw())

	func setup(title: String, sub: String) -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.position = Vector2(0, D + 12.0)
		v.size = Vector2(size.x, size.y - D - 12.0)
		add_child(v)
		var col: Color = [Color("b9e6a0"), UiTheme.ACCENT, Color("f3e7c4"), UiTheme.TEXT_DIM][state]
		var t := UiTheme.make_label(title, 14, col)
		t.add_theme_font_override("font", UiTheme.bold_font())
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.max_lines_visible = 2
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		if sub != "":
			var l := UiTheme.make_label(sub, 12, UiTheme.TEXT_DIM if state != 1 else UiTheme.ACCENT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)

	func center() -> Vector2:
		return Vector2(size.x * 0.5, D * 0.5 + 4.0)

	func _draw() -> void:
		var c := center()
		var r := D * 0.5
		var ring: Color = [Color("7fc35f"), UiTheme.ACCENT, Color("d9c38c"), Color(0.35, 0.34, 0.3)][state]
		if state == 2 and _hover:
			ring = Color("ffe7a8")
		# gölge + koyu zemin
		draw_circle(c + Vector2(0, 3), r + 3.0, Color(0, 0, 0, 0.45))
		draw_circle(c, r, Color(0.06, 0.065, 0.06))
		# resim: daireye kırpılmış (UV'ler resmin kırpma bölgesine)
		if tex:
			var base: Texture2D = tex
			var uvr := Rect2(0, 0, 1, 1)
			if tex is AtlasTexture:
				var at := tex as AtlasTexture
				base = at.atlas
				var bs := Vector2(base.get_width(), base.get_height())
				uvr = Rect2(at.region.position / bs, at.region.size / bs)
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			var tint := Color.WHITE if state != 3 else Color(0.5, 0.5, 0.5)
			if state == 0:
				tint = Color(0.85, 1.0, 0.85)
			var ri := r - 4.0
			for k in 40:
				var a := TAU * float(k) / 40.0
				var u := Vector2(cos(a), sin(a))
				pts.append(c + u * ri)
				uvs.append(uvr.position + (u * 0.5 + Vector2(0.5, 0.5)) * uvr.size)
				cols.append(tint)
			draw_polygon(pts, cols, uvs, base)
		# durum halkası; sürerken ilerleme yayı
		draw_arc(c, r - 1.5, 0.0, TAU, 64, ring.darkened(0.35) if state == 1 else ring, 4.0 if state != 3 else 2.5, true)
		if state == 1 and progress > 0.0:
			draw_arc(c, r - 1.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 64, UiTheme.ACCENT.lightened(0.2), 5.0, true)
		if _hover and state != 3:
			draw_arc(c, r + 3.0, 0.0, TAU, 64, Color(ring.r, ring.g, ring.b, 0.5), 2.0, true)

func _draw_lines(ctrl: Control) -> void:
	var c := World.player()
	var tree := Politics.tree_of(c)
	for id: String in tree:
		var fo: Dictionary = tree[id]
		if not _buttons.has(id):
			continue
		var to: FocusNode = _buttons[id]
		for p: String in fo["prereq"] + fo["any_prereq"]:
			if not _buttons.has(p):
				continue
			var from: FocusNode = _buttons[p]
			var a := from.position + Vector2(NODE.x * 0.5, NODE.y - 4.0)
			var b := to.position + to.center() - Vector2(0, FocusNode.D * 0.5 + 2.0)
			var col := UiTheme.ACCENT if p in c.focus_done else UiTheme.BORDER_DIM
			var mid := (a.y + b.y) * 0.5
			ctrl.draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b]), col, 3.0, true)
		for x: String in fo["exclusive"]:
			if _buttons.has(x) and id < x:
				var cy := (_buttons[x] as FocusNode).center().y
				var p1: Vector2 = to.position + Vector2(NODE.x * 0.5 + FocusNode.D * 0.5 + 4.0, cy)
				var p2: Vector2 = _buttons[x].position + Vector2(NODE.x * 0.5 - FocusNode.D * 0.5 - 4.0, cy)
				ctrl.draw_dashed_line(p1, p2, UiTheme.BAD, 2.0, 8.0)
