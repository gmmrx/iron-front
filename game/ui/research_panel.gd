class_name ResearchPanel
extends PanelContainer
## Araştırma (I): slotlar ve teknoloji ağacı (kategoriye göre).

var _slots: VBoxContainer
var _tree: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(720, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("RESEARCH_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	v.add_child(_slots)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(700, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tree = VBoxContainer.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.add_theme_constant_override("separation", 12)
	scroll.add_child(_tree)
	v.add_child(scroll)
	Research.research_changed.connect(func(t: String) -> void:
		if visible and t == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: _refresh_slots())
	get_viewport().size_changed.connect(_fit)

func open() -> void:
	visible = true
	refresh()
	_fit.call_deferred()

func _fit() -> void:
	PanelLayout.fit_scroll(self, _scroll, 620)

func close() -> void:
	visible = false

func refresh() -> void:
	_refresh_slots()
	var c := World.player()
	for ch in _tree.get_children():
		ch.queue_free()
	for cat: String in Research.categories:
		PanelLayout.section(_tree, Research.category_name(cat).to_upper())
		var flow := PanelLayout.grid()
		for id: String in Research.techs:
			var t: Dictionary = Research.techs[id]
			if t["cat"] != cat:
				continue
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			PanelLayout.card(b, 324, 92)
			b.icon = UiTheme.technology_icon(id)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_constant_override("icon_max_width", 68)
			var done := id in c.research_done
			var ahead := maxi(int(t["year"]) - GameClock.year, 0)
			b.text = "%s\n%d%s" % [Research.tech_name(id), int(t["year"]), ("  ✓" if done else "  ·  %d %s" % [roundi(Research.days_needed(c, id)), tr("UI_DAYS")])]
			b.disabled = not Research.can_research(c, id) or c.research_current.size() >= c.research_slots
			if done:
				b.modulate = Color(1.0, 0.9, 0.6)
			var tip := Research.tech_name(id)
			var eff: Dictionary = t.get("effects", {})
			if not eff.is_empty():
				tip += "\n" + Politics.describe_mods(eff)
			for u: String in t.get("unlock", []):
				tip += "\n• " + tr("RESEARCH_UNLOCK") % Economy.equipment_name(u)
			if not t["req"].is_empty():
				tip += "\n\n" + tr("RESEARCH_REQ") % ", ".join(t["req"].map(func(r: String) -> String: return Research.tech_name(r)))
			if ahead > 0:
				tip += "\n" + tr("RESEARCH_AHEAD") % [ahead, roundi(ahead * Research.AHEAD_PENALTY * 100)]
			b.tooltip_text = tip
			b.pressed.connect(func() -> void: Research.start(c, id))
			flow.add_child(b)
		_tree.add_child(flow)
	_fit.call_deferred()

func _refresh_slots() -> void:
	var c := World.player()
	for ch in _slots.get_children():
		ch.queue_free()
	for i in c.research_slots:
		var slot := PanelContainer.new()
		var style := UiTheme.panel_style(Color(1, 1, 1, 0.035), UiTheme.BORDER_DIM)
		style.shadow_size = 0
		style.set_content_margin_all(10)
		slot.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slot.add_child(row)
		if i < c.research_current.size():
			var r: Dictionary = c.research_current[i]
			var id: String = r["tech"]
			var t: Dictionary = Research.techs[id]
			var ahead := maxi(int(t["year"]) - GameClock.year, 0)
			var cost := float(t["cost"]) * (1.0 + Research.AHEAD_PENALTY * ahead)
			var l := UiTheme.make_label(Research.tech_name(id), 17, UiTheme.ACCENT)
			l.custom_minimum_size.x = 230
			row.add_child(UiTheme.icon_texture(UiTheme.technology_icon(id), 48))
			row.add_child(l)
			var bar := ProgressBar.new()
			bar.max_value = cost
			bar.value = float(r["progress"])
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(220, 10)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var f := StyleBoxFlat.new()
			f.bg_color = Color("7fb0d9")
			bar.add_theme_stylebox_override("fill", f)
			row.add_child(bar)
			var left := (cost - float(r["progress"])) / (Research.speed(c) * (1.0 + float(r.get("bonus", 0.0))))
			row.add_child(UiTheme.make_label("%d %s" % [ceili(left), tr("UI_DAYS")], 15, UiTheme.TEXT_DIM))
			row.add_child(UiTheme.icon_button("close", tr("TIP_RESEARCH_CANCEL"), func() -> void: Research.cancel(c, id), 26))
		else:
			row.add_child(UiTheme.icon_texture(UiTheme.icon("research"), 38))
			var empty := UiTheme.make_label(tr("RESEARCH_EMPTY_SLOT") % (i + 1), 18, UiTheme.ACCENT)
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(empty)
		_slots.add_child(slot)
	_fit.call_deferred()
