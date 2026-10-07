class_name FocusPanel
extends PanelContainer
## Milli odak ağacı (F): tam ekran grafik; odaklar önkoşul çizgileriyle bağlı. Harita gibi gezilir: tekerlek ya da
## trackpad sıkıştırmasıyla imlecin olduğu yere yakınlaşır/uzaklaşır, boş yerde sürükleyince kayar (bırakınca süzülüp
## durur), ok tuşları / WASD ile kayar; −, + ve Sığdır düğmeleri başlıkta. Her hareket yumuşak geçişle.

const CELL := Vector2(236, 168)
const NODE := Vector2(212, 140)
const ZOOM_MIN := 0.4
const ZOOM_MAX := 1.6
const ZOOM_STEP := 1.15
const EDGE := 80.0                   ## ağacın kenarı görünümün kenarından en çok bu kadar içeri kayar
const KEY_PAN := 900.0               ## ok tuşlarıyla kayma (piksel / sn)

var _canvas: Control
var _view: Control                   ## ağacın göründüğü kırpılmış alan
var _status: Label
var _buttons := {}
var _zoom := 1.0
var _zoom_t := 1.0                   ## hedef (gösterilen buna yumuşakça gelir)
var _pan := Vector2(EDGE, 0.0)
var _pan_t := Vector2(EDGE, 0.0)
var _vel := Vector2.ZERO             ## bırakınca süzülme hızı
var _drag := 0                       ## 0 yok, 1 basıldı, 2 sürükleniyor
var _drag_start := Vector2.ZERO
var _opened := false

class Lines extends Control:
	var owner_panel
	func _draw() -> void:
		owner_panel._draw_lines(self)

func _ready() -> void:
	if not Politics.FOCUS_ENABLED:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		set_process_input(false)
		return # Keep a cheap inert compatibility object for old HUD callers; no tree/atlas work.
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
	for z: Array in [["−", tr("TIP_FOCUS_ZOOM_OUT"), 1.0 / ZOOM_STEP], ["+", tr("TIP_FOCUS_ZOOM_IN"), ZOOM_STEP]]:
		var f: float = z[2]
		var zb := PanelLayout.small_button(z[0], func() -> void: _zoom_at(_view.size * 0.5, f * f), true, z[1])
		zb.custom_minimum_size = Vector2(36, 32)
		head.add_child(zb)
	head.add_child(PanelLayout.small_button(tr("FOCUS_FIT"), _fit, true, tr("TIP_FOCUS_FIT")))
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), close, 28))
	var help := UiTheme.make_label(tr("FOCUS_HELP"), 14, UiTheme.TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(_view)
	_canvas = Lines.new()
	_canvas.owner_panel = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(_canvas)
	Politics.politics_changed.connect(func(t: String) -> void:
		if visible and t == World.player_tag: refresh())
	Politics.focus_completed.connect(func(t: String, _f: String) -> void:
		if visible and t == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: _update_status())

func open() -> void:
	if not Politics.FOCUS_ENABLED:
		visible = false
		return
	visible = true
	Audio.panel(true)
	refresh()
	if not _opened:
		_opened = true
		_pan = _pan_t                       # ilk açılışta yerinde başlar (kayarak gelmez)

# ------------------------------------------------------------------ gezinme (yakınlaştırma, kaydırma)
func _input(event: InputEvent) -> void:
	if not visible or _view == null:
		return
	var r := _view.get_global_rect()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and mb.pressed:
			if r.has_point(mb.position):
				var f := mb.factor if mb.factor > 0.0 else 1.0
				_zoom_at(mb.position - r.position, pow(ZOOM_STEP, f if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -f))
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if r.has_point(mb.position) and not _over_node():
					_drag = 1
					_drag_start = mb.position
					_vel = Vector2.ZERO
			else:
				if _drag == 2:
					get_viewport().set_input_as_handled()
					Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				_drag = 0
	elif event is InputEventMouseMotion and _drag > 0:
		var mm := event as InputEventMouseMotion
		if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_drag = 0
			return
		if _drag == 1 and mm.position.distance_to(_drag_start) > 6.0:
			_drag = 2
		if _drag == 2:
			_pan_t += mm.relative
			_vel = _vel.lerp(mm.relative / maxf(get_process_delta_time(), 0.001), 0.5)
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		if r.has_point(mg.position):
			_zoom_at(mg.position - r.position, mg.factor)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		if r.has_point(pg.position):
			_pan_t -= pg.delta * 12.0
			get_viewport().set_input_as_handled()

func _over_node() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	while c != null and c != _view:
		if c is BaseButton:
			return true
		c = c.get_parent() as Control
	return false

## Görünümdeki bir noktanın (yerel) altındaki ağaç yeri sabit kalacak şekilde yakınlaş/uzaklaş
func _zoom_at(local: Vector2, factor: float) -> void:
	var nz := clampf(_zoom_t * factor, ZOOM_MIN, ZOOM_MAX)
	var w := (local - _pan_t) / _zoom_t
	_zoom_t = nz
	_pan_t = local - w * nz
	_vel = Vector2.ZERO

## Bütün ağaç görünüme sığar (en çok gerçek boy)
func _fit() -> void:
	var cs := _canvas.custom_minimum_size
	if cs.x <= 0.0 or cs.y <= 0.0:
		return
	_zoom_t = clampf(minf(minf(_view.size.x / cs.x, _view.size.y / cs.y), 1.0), ZOOM_MIN, ZOOM_MAX)
	_pan_t = Vector2((_view.size.x - cs.x * _zoom_t) * 0.5, 0.0)
	_vel = Vector2.ZERO

## Ağaç görünümden kaçmasın: görünümden küçükse ortalanır (yatay) / üste yaslanır, büyükse kenarı en çok EDGE içeri
func _clamp(p: Vector2, z: float) -> Vector2:
	var cs := _canvas.custom_minimum_size * z
	var vs := _view.size
	var out := p
	if cs.x + EDGE * 2.0 <= vs.x:
		out.x = (vs.x - cs.x) * 0.5
	else:
		out.x = clampf(p.x, vs.x - cs.x - EDGE, EDGE)
	if cs.y + EDGE <= vs.y:
		out.y = 0.0
	else:
		out.y = clampf(p.y, vs.y - cs.y - EDGE, 0.0)
	return out

func _process(delta: float) -> void:
	if not Politics.FOCUS_ENABLED:
		visible = false
		return
	if not visible or _view == null:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y -= 1.0
	if dir != Vector2.ZERO and get_viewport().gui_get_focus_owner() == null:
		_pan_t += dir * KEY_PAN * delta
		_vel = Vector2.ZERO
	if _drag == 0 and _vel.length() > 8.0:
		_pan_t += _vel * delta                  # bırakınca süzülür, sürtünmeyle durur
		_vel *= exp(-5.0 * delta)
	elif _drag == 0:
		_vel = Vector2.ZERO
	_pan_t = _clamp(_pan_t, _zoom_t)
	var k := 1.0 - exp(-(22.0 if _drag == 2 else 12.0) * delta)
	_zoom = lerpf(_zoom, _zoom_t, k)
	_pan = _pan.lerp(_pan_t, k)
	if absf(_zoom - _zoom_t) < 0.001:
		_zoom = _zoom_t
	if _pan.distance_to(_pan_t) < 0.3:
		_pan = _pan_t
	_canvas.scale = Vector2(_zoom, _zoom)
	_canvas.position = _pan

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
	if not Politics.FOCUS_ENABLED:
		visible = false
		return
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
	_canvas.size = _canvas.custom_minimum_size
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
