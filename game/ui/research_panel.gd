class_name ResearchPanel
extends PanelContainer
## Araştırma (I) — tam ekran zaman çizelgesi: sütunlar yıllar, satırlar araştırma dalları; her teknoloji bir kart
## (bitti yeşil, sürüyor altın + ilerleme, seçilebilir parlak, kilitli soluk), önkoşullar çizgiyle bağlı, bugünün
## tarihi dikey altın çizgi. Üstte araştırma yuvaları. Erken yılın teknolojisi her yıl için +%150 süre alır.

const LABEL_W := 176.0
const NODE := Vector2(212, 66)
const LANE_H := 78.0
const HEAD_H := 40.0
const ROW_PAD := 10.0
const CAT_ICON := {"infantry": "equipment_infantry_equipment", "artillery": "equipment_artillery_equipment",
	"armor": "equipment_medium_tank_equipment", "air": "equipment_fighter_equipment", "naval": "equipment_destroyer",
	"industry": "building_civilian_factory", "electronics": "research", "doctrine": "army"}

class Timeline extends Control:
	var panel: ResearchPanel
	func _draw() -> void:
		panel._draw_timeline(self)

var _slots: GridContainer
var _speed: Label
var _canvas: Timeline
var _nodes := {}              ## teknoloji -> Button
var _rows: Array = []         ## [kategori, y, yükseklik]
var _col_w := 230.0
var _y0 := 1936
var _y1 := 1942

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	var body := PanelLayout.frame(self, tr("RESEARCH_TITLE"), "research", -1.0)     # tam ekran
	var sc: ScrollContainer = get_meta("scroll")
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER           # dar ekranda yatay da sürüklenir
	var top := PanelLayout.fixed(self)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	top.add_child(head)
	var sec := PanelLayout.section(head, tr("RES_SLOTS"))
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed = UiTheme.make_label("", 14, UiTheme.TEXT_DIM)
	_speed.mouse_filter = Control.MOUSE_FILTER_STOP
	_speed.tooltip_text = tr("RES_SPEED_TIP")
	head.add_child(_speed)
	_slots = PanelLayout.grid(4)
	top.add_child(_slots)
	_canvas = Timeline.new()
	_canvas.panel = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(_canvas)
	for t: Dictionary in Research.techs.values():
		_y0 = mini(_y0, int(t["year"]))
		_y1 = maxi(_y1, int(t["year"]))
	Research.research_changed.connect(func(t: String) -> void:
		if visible and t == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible:
			_refresh_slots()
			_canvas.queue_redraw())

func open() -> void:
	visible = true
	refresh.call_deferred()

func close() -> void:
	visible = false

func refresh() -> void:
	_refresh_slots()
	var c := World.player()
	if c == null:
		return
	for ch in _canvas.get_children():
		ch.queue_free()
	_nodes.clear()
	_rows.clear()
	var years := _y1 - _y0 + 1
	var avail := maxf(size.x - 48.0, 900.0)
	_col_w = maxf((avail - LABEL_W) / years, NODE.x + 16.0)
	# satırlar: her dalda aynı yıldaki teknoloji sayısı kadar şerit
	var y := HEAD_H
	for cat: String in Research.categories:
		var per_year := {}
		for id: String in Research.techs:
			var t: Dictionary = Research.techs[id]
			if t["cat"] != cat:
				continue
			var yr := int(t["year"])
			if not per_year.has(yr):
				per_year[yr] = []
			per_year[yr].append(id)
		var lanes := 1
		for yr: int in per_year:
			lanes = maxi(lanes, (per_year[yr] as Array).size())
		var h := lanes * LANE_H + ROW_PAD
		_rows.append([cat, y, h])
		_row_label(cat, y, h)
		for yr: int in per_year:
			var ids: Array = per_year[yr]
			ids.sort()
			for lane in ids.size():
				var b := _tech_button(c, ids[lane])
				b.position = Vector2(LABEL_W + (yr - _y0) * _col_w + (_col_w - NODE.x) * 0.5, y + ROW_PAD * 0.5 + lane * LANE_H + (LANE_H - NODE.y) * 0.5)
				b.size = NODE
				_canvas.add_child(b)
				_nodes[ids[lane]] = b
		y += h
	_canvas.custom_minimum_size = Vector2(LABEL_W + years * _col_w + 8.0, y + 8.0)
	_canvas.queue_redraw()

func _row_label(cat: String, y: float, h: float) -> void:
	var box := HBoxContainer.new()
	box.position = Vector2(8, y)
	box.size = Vector2(LABEL_W - 16, h)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiTheme.icon_texture(UiTheme.icon(CAT_ICON.get(cat, "research")), 40)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var l := UiTheme.make_label(Research.category_name(cat), 16, UiTheme.ACCENT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	_canvas.add_child(box)

func _tech_button(c: Country, id: String) -> Button:
	var t: Dictionary = Research.techs[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.icon = UiTheme.technology_icon(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 50)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_font_size_override("font_size", 14)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	var done := id in c.research_done
	var running := false
	var progress := 0.0
	for r: Dictionary in c.research_current:
		if r["tech"] == id:
			running = true
			var ahead0 := maxi(int(t["year"]) - GameClock.year, 0)
			progress = float(r["progress"]) / maxf(float(t["cost"]) * (1.0 + Research.AHEAD_PENALTY * ahead0), 0.001)
	var ahead := maxi(int(t["year"]) - GameClock.year, 0)
	var can := not done and not running and Research.can_research(c, id) and c.research_current.size() < c.research_slots
	var status := tr("RES_DONE") if done else (tr("RES_RUNNING") if running else "%d %s" % [roundi(Research.days_needed(c, id)), tr("UI_DAYS")])
	if ahead > 0 and not done:
		status += " · " + tr("RES_AHEAD_SHORT") % ahead
	b.text = "%s\n%s" % [Research.tech_name(id), status]
	var style := "card"
	if done:
		style = "slot_good"
		b.add_theme_color_override("font_color", Color("b9e6a0"))
	elif running:
		style = "slot_gold"
		b.add_theme_color_override("font_color", UiTheme.ACCENT)
	elif can:
		style = "card_hover"
		b.add_theme_color_override("font_color", Color("f3e7c4"))
	else:
		style = "slot"
		b.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		b.add_theme_color_override("icon_normal_color", Color(0.6, 0.6, 0.6))
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		var sb := UiTheme.skin(style if st != "hover" or not can else "card_selected", 8, 5)
		b.add_theme_stylebox_override(st, sb)
	if running:
		var pb := PanelLayout.progress(progress, UiTheme.ACCENT, 5.0)
		pb.position = Vector2(8, NODE.y - 10)
		pb.size = Vector2(NODE.x - 16, 5)
		b.add_child(pb)
	var tip := Research.tech_name(id) + "  (%d)" % int(t["year"])
	var eff: Dictionary = t.get("effects", {})
	if not eff.is_empty():
		tip += "\n" + Politics.describe_mods(eff)
	for u: String in t.get("unlock", []):
		tip += "\n• " + tr("RESEARCH_UNLOCK") % Economy.equipment_name(u)
	if not t["req"].is_empty():
		tip += "\n\n" + tr("RESEARCH_REQ") % ", ".join(t["req"].map(func(r: String) -> String: return Research.tech_name(r)))
	if ahead > 0:
		tip += "\n" + tr("RESEARCH_AHEAD") % [ahead, roundi(ahead * Research.AHEAD_PENALTY * 100)]
	if not done and not running and c.research_current.size() >= c.research_slots:
		tip += "\n\n⚠ " + tr("RES_SLOTS_FULL")
	b.tooltip_text = tip
	b.pressed.connect(func() -> void:
		if can:
			Research.start(c, id)
		elif running:
			Research.cancel(c, id)
		refresh())
	return b

func _draw_timeline(ctrl: Control) -> void:
	var c := World.player()
	var years := _y1 - _y0 + 1
	var w := LABEL_W + years * _col_w
	var font := UiTheme.title_font()
	# satır bantları
	for i in _rows.size():
		var r: Array = _rows[i]
		ctrl.draw_rect(Rect2(0, r[1], w, r[2]), Color(1, 1, 1, 0.035 if i % 2 == 0 else 0.0))
		ctrl.draw_line(Vector2(0, r[1]), Vector2(w, r[1]), Color(0.55, 0.47, 0.3, 0.25), 1.0)
	# yıl başlıkları ve sütun çizgileri
	for k in years:
		var x := LABEL_W + k * _col_w
		ctrl.draw_line(Vector2(x, HEAD_H - 6), Vector2(x, ctrl.size.y), Color(0.55, 0.47, 0.3, 0.3), 1.0)
		var past := _y0 + k <= GameClock.year
		ctrl.draw_string(font, Vector2(x, 28), str(_y0 + k), HORIZONTAL_ALIGNMENT_CENTER, _col_w, 24, UiTheme.ACCENT if past else UiTheme.TEXT_DIM)
	# önkoşul çizgileri
	for id: String in _nodes:
		var to: Button = _nodes[id]
		for req: String in Research.techs[id]["req"]:
			if not _nodes.has(req):
				continue
			var from: Button = _nodes[req]
			var a := from.position + Vector2(NODE.x, NODE.y * 0.5)
			var b := to.position + Vector2(0, NODE.y * 0.5)
			var col := UiTheme.ACCENT if c and req in c.research_done else Color(0.5, 0.45, 0.35, 0.8)
			if b.x <= a.x + 4:
				a = from.position + Vector2(NODE.x * 0.5, NODE.y)
				b = to.position + Vector2(NODE.x * 0.5, 0)
				ctrl.draw_polyline(PackedVector2Array([a, Vector2(a.x, (a.y + b.y) * 0.5), Vector2(b.x, (a.y + b.y) * 0.5), b]), col, 2.0, true)
			else:
				var mid := (a.x + b.x) * 0.5
				ctrl.draw_polyline(PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b]), col, 2.0, true)
	# bugünün çizgisi
	var frac := ((GameClock.month - 1) * 30.44 + GameClock.day) / 365.25
	var tx := LABEL_W + (GameClock.year - _y0 + frac) * _col_w
	if tx >= LABEL_W and tx <= w:
		ctrl.draw_line(Vector2(tx, HEAD_H - 4), Vector2(tx, ctrl.size.y), Color(0.95, 0.78, 0.35, 0.85), 2.0)
		ctrl.draw_string(font, Vector2(tx + 4, HEAD_H + 2), tr("RES_TODAY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.78, 0.35))

func _refresh_slots() -> void:
	var c := World.player()
	if c == null:
		return
	_speed.text = tr("RES_SPEED") % roundi((Research.speed(c) - 1.0) * 100)
	for ch in _slots.get_children():
		ch.queue_free()
	for i in c.research_slots:
		var slot := PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slot.add_child(row)
		if i < c.research_current.size():
			slot.theme_type_variation = "SlotGold"
			var r: Dictionary = c.research_current[i]
			var id: String = r["tech"]
			var t: Dictionary = Research.techs[id]
			var ahead := maxi(int(t["year"]) - GameClock.year, 0)
			var cost := float(t["cost"]) * (1.0 + Research.AHEAD_PENALTY * ahead)
			row.add_child(UiTheme.icon_texture(UiTheme.technology_icon(id), 44))
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 2)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var l := UiTheme.make_label(Research.tech_name(id), 16, UiTheme.ACCENT)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size.x = 120
			col.add_child(l)
			col.add_child(PanelLayout.progress(float(r["progress"]) / maxf(cost, 0.001), Color("7fb0d9"), 7.0))
			var left := (cost - float(r["progress"])) / (Research.speed(c) * (1.0 + float(r.get("bonus", 0.0))))
			col.add_child(UiTheme.make_label("%d %s" % [ceili(left), tr("UI_DAYS")], 13, UiTheme.TEXT_DIM))
			var x := UiTheme.icon_button("close", tr("TIP_RESEARCH_CANCEL"), func() -> void: Research.cancel(c, id), 24)
			x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(x)
		else:
			slot.theme_type_variation = "SlotBad"
			row.add_child(UiTheme.icon_texture(UiTheme.icon("research"), 38))
			var empty := UiTheme.make_label(tr("RESEARCH_EMPTY_SLOT") % (i + 1), 14, UiTheme.ACCENT)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(empty)
		_slots.add_child(slot)
