class_name ArmyPanel
extends PanelContainer
## Ordu (U): tümen şablonları, şablon tasarımcısı, konuşlandırma.

var _summary: Label
var _list: VBoxContainer
var _designer: VBoxContainer
var _edit := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(500, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("ARMY_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 16, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	v.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	v.add_child(_list)
	var newb := Button.new()
	newb.text = tr("ARMY_NEW_TEMPLATE")
	newb.icon = UiTheme.icon("add_line")
	newb.add_theme_constant_override("icon_max_width", 18)
	newb.tooltip_text = tr("TIP_NEW_TEMPLATE")
	newb.focus_mode = Control.FOCUS_NONE
	newb.pressed.connect(func() -> void:
		var c := World.player()
		c.templates.append({"name": tr("ARMY_TEMPLATE_N") % (c.templates.size() + 1), "battalions": {"infantry": 6}})
		_edit = c.templates.size() - 1
		refresh())
	v.add_child(newb)
	v.add_child(HSeparator.new())
	_designer = VBoxContainer.new()
	v.add_child(_designer)
	World.daily_update.connect(func() -> void:
		if visible: refresh())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func refresh() -> void:
	var c := World.player()
	if c == null:
		return
	var divs := Military.country_divisions(c.tag)
	_summary.text = tr("ARMY_SUMMARY") % [divs.size(), UiTheme.format_number(c.available_manpower()),
		UiTheme.format_number(c.stockpile.get("infantry_equipment", 0.0)), UiTheme.format_number(Military.air_power(c)), UiTheme.format_number(Military.compute_naval_power(c))]
	for ch in _list.get_children():
		ch.queue_free()
	for i in c.templates.size():
		_list.add_child(_template_row(c, i))
	for ch in _designer.get_children():
		ch.queue_free()
	if _edit >= 0 and _edit < c.templates.size():
		_build_designer(c, _edit)

func _template_row(c: Country, i: int) -> Control:
	var s := Military.stats(c, i)
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_style(Color(1, 1, 1, 0.04), UiTheme.BORDER_DIM)
	sb.shadow_size = 0
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	panel.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := UiTheme.make_label(c.templates[i]["name"], 18, UiTheme.ACCENT)
	name.add_theme_font_override("font", UiTheme.bold_font())
	info.add_child(name)
	info.add_child(UiTheme.make_label(tr("ARMY_STATS") % [int(s["soft"]), int(s["hard"]), int(s["defense"]), int(s["breakthrough"]), int(s["org"]), snappedf(s["speed"], 0.1), int(s["width"])], 14, UiTheme.TEXT_DIM))
	h.add_child(info)
	var edit := UiTheme.icon_button("production", tr("TIP_EDIT_TEMPLATE"), func() -> void:
		_edit = i
		refresh(), 30)
	h.add_child(edit)
	var dep := Button.new()
	dep.text = tr("ARMY_DEPLOY")
	dep.focus_mode = Control.FOCUS_NONE
	var short := Military.deploy_shortfall(c, i)
	dep.disabled = not short.is_empty()
	var tip := tr("TIP_DEPLOY") % [UiTheme.format_number(s["manpower"])]
	for e: String in s["equipment"]:
		tip += "\n• %s: %d (%s: %s)" % [Economy.equipment_name(e), int(s["equipment"][e]), tr("ARMY_STOCK"), UiTheme.format_number(c.stockpile.get(e, 0.0))]
	if not short.is_empty():
		tip += "\n\n" + tr("ARMY_MISSING")
		for k: String in short:
			tip += "\n• %s" % (tr("UI_MANPOWER") if k == "manpower" else Economy.equipment_name(k))
	dep.tooltip_text = tip
	dep.pressed.connect(func() -> void:
		if Military.deploy(c, i) != null:
			World.notify(tr("NOTE_DEPLOYED") % c.templates[i]["name"], "good")
		refresh())
	h.add_child(dep)
	return panel

func _build_designer(c: Country, i: int) -> void:
	var t: Dictionary = c.templates[i]
	_designer.add_child(UiTheme.make_label(tr("ARMY_DESIGNER") % t["name"], 17, UiTheme.ACCENT))
	for b: String in Military.battalions:
		var bd: Dictionary = Military.battalions[b]
		if bd.has("requires") and not Research.is_unlocked(c, bd["requires"]):
			continue
		var row := HBoxContainer.new()
		var l := UiTheme.make_label(Politics.loc(bd["name"]), 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = tr("TIP_BATTALION") % [bd["soft"], bd["hard"], bd["defense"], bd["breakthrough"], bd["hp"], bd["org"], bd["speed"], bd["width"]]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(l)
		row.add_child(UiTheme.icon_button("minus", tr("TIP_BAT_MINUS"), func() -> void: _change(c, i, b, -1), 26))
		row.add_child(UiTheme.make_label(" %d " % int(t["battalions"].get(b, 0)), 17))
		row.add_child(UiTheme.icon_button("plus", tr("TIP_BAT_PLUS"), func() -> void: _change(c, i, b, 1), 26))
		_designer.add_child(row)

func _change(c: Country, i: int, b: String, d: int) -> void:
	var bats: Dictionary = c.templates[i]["battalions"]
	var n := clampi(int(bats.get(b, 0)) + d, 0, 12)
	var total := 0
	for k: String in bats:
		total += int(bats[k]) if k != b else n
	if total < 1:
		return
	bats[b] = n
	Military.invalidate_stats(c.tag)
	refresh()
