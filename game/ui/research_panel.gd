class_name ResearchPanel
extends PanelContainer
## Araştırma (I) — türün klasiği düzeni: üstte araştırma yuvaları (ilerleme, kalan gün, iptal), kategori sekmeleri,
## altında seçili kategorinin teknolojileri yıllara göre sıralı (yıl şeridi solda). Erken araştırma ceza alır.

var _slots: GridContainer
var _tree: VBoxContainer
var _tabs: HBoxContainer
var _speed: Label
var _cat := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_tree = PanelLayout.frame(self, tr("RESEARCH_TITLE"), "research", 720.0)
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
	_slots = PanelLayout.grid(2)
	top.add_child(_slots)
	var names := []
	for cat: String in Research.categories:
		names.append(Research.category_name(cat))
		if _cat == "":
			_cat = cat
	_tabs = PanelLayout.tabs(top, names, func(i: int) -> void:
		_cat = Research.categories.keys()[i]
		refresh(), 0)
	for b: Button in _tabs.get_children():
		b.add_theme_font_size_override("font_size", 13)
		b.clip_text = true
	Research.research_changed.connect(func(t: String) -> void:
		if visible and t == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: _refresh_slots())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func refresh() -> void:
	_refresh_slots()
	var c := World.player()
	if c == null:
		return
	for ch in _tree.get_children():
		ch.queue_free()
	var by_year := {}
	for id: String in Research.techs:
		var t: Dictionary = Research.techs[id]
		if t["cat"] != _cat:
			continue
		var y := int(t["year"])
		if not by_year.has(y):
			by_year[y] = []
		by_year[y].append(id)
	var years := by_year.keys()
	years.sort()
	for y: int in years:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_tree.add_child(row)
		var yl := PanelContainer.new()
		yl.theme_type_variation = "SlotGold" if y <= GameClock.year else "Slot"
		yl.custom_minimum_size = Vector2(64, 0)
		var ylab := UiTheme.make_label(str(y), 17, UiTheme.ACCENT if y <= GameClock.year else UiTheme.TEXT_DIM)
		ylab.add_theme_font_override("font", UiTheme.title_font())
		ylab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ylab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		yl.add_child(ylab)
		row.add_child(yl)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		row.add_child(flow)
		for id: String in by_year[y]:
			flow.add_child(_tech_button(c, id))

func _tech_button(c: Country, id: String) -> Button:
	var t: Dictionary = Research.techs[id]
	var b := Button.new()
	b.theme_type_variation = "Card"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 64)
	b.icon = UiTheme.technology_icon(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 48)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_font_size_override("font_size", 14)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var done := id in c.research_done
	var running := false
	for r: Dictionary in c.research_current:
		if r["tech"] == id:
			running = true
	var ahead := maxi(int(t["year"]) - GameClock.year, 0)
	var status := tr("RES_DONE") if done else (tr("RES_RUNNING") if running else "%d %s" % [roundi(Research.days_needed(c, id)), tr("UI_DAYS")])
	if ahead > 0 and not done:
		status += "  ·  " + tr("RES_AHEAD_SHORT") % ahead
	b.text = "%s\n%s" % [Research.tech_name(id), status]
	b.toggle_mode = true
	b.set_pressed_no_signal(done or running)
	b.disabled = not done and not running and (not Research.can_research(c, id) or c.research_current.size() >= c.research_slots)
	if done:
		b.add_theme_color_override("font_pressed_color", UiTheme.GOOD)
		b.add_theme_color_override("font_hover_pressed_color", UiTheme.GOOD)
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
		tip += "\n\n" + tr("RES_SLOTS_FULL")
	b.tooltip_text = tip
	b.pressed.connect(func() -> void:
		if not done and not running:
			Research.start(c, id)
		refresh())
	return b

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
			row.add_child(UiTheme.icon_texture(UiTheme.technology_icon(id), 40))
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 2)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var l := UiTheme.make_label(Research.tech_name(id), 15, UiTheme.ACCENT)
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
			row.add_child(UiTheme.icon_texture(UiTheme.icon("research"), 34))
			var empty := UiTheme.make_label(tr("RESEARCH_EMPTY_SLOT") % (i + 1), 14, UiTheme.ACCENT)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(empty)
		_slots.add_child(slot)
