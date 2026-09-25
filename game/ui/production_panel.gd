class_name ProductionPanel
extends PanelContainer
## Üretim ekranı (türün klasikleri "Production"): hatlar, fabrika atama, verimlilik, stok.

var _summary: Label
var _lines_box: VBoxContainer
var _stock: VBoxContainer
var _add: MenuButton

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(470, 0)
	size = Vector2(470, 760)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("PRODUCTION_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 16, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	_add = MenuButton.new()
	_add.text = tr("PRODUCTION_ADD")
	_add.icon = UiTheme.icon("add_line")
	_add.expand_icon = false
	_add.add_theme_constant_override("icon_max_width", 20)
	_add.tooltip_text = tr("TIP_LINE_ADD")
	_add.flat = false
	_add.focus_mode = Control.FOCUS_NONE
	var pm := _add.get_popup()
	var i := 0
	for eq: String in Economy.equipment:
		pm.add_icon_item(UiTheme.equipment_icon(eq), "%s  (%s IC)" % [Economy.equipment_name(eq), str(Economy.equipment[eq]["cost"])], i)
		pm.set_item_metadata(i, eq)
		i += 1
	pm.id_pressed.connect(func(id: int) -> void:
		var eq: String = pm.get_item_metadata(pm.get_item_index(id))
		if Economy.can_produce(World.player(), eq):
			Economy.add_line(World.player(), eq))
	# araştırılmamış tipler kilitli (menü her açılışta güncellenir)
	pm.about_to_popup.connect(func() -> void:
		for k in pm.item_count:
			var eq: String = pm.get_item_metadata(k)
			var ok := Economy.can_produce(World.player(), eq)
			pm.set_item_disabled(k, not ok)
			pm.set_item_tooltip(k, "" if ok else tr("PRODUCTION_LOCKED") % Research.tech_name(Research.unlocking_tech(eq))))
	v.add_child(_add)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 420
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lines_box = VBoxContainer.new()
	_lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_lines_box)
	v.add_child(scroll)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.make_label(tr("PRODUCTION_STOCKPILE"), 17, UiTheme.TEXT_DIM))
	_stock = VBoxContainer.new()
	_stock.add_theme_constant_override("separation", 3)
	v.add_child(_stock)
	Economy.production_changed.connect(func(tag: String) -> void:
		if tag == World.player_tag and visible: refresh())
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
	var out := Economy.law_sum(c, "factory_output") * 100.0
	_summary.text = tr("PRODUCTION_SUMMARY") % [Economy.count(c, "military_factory"), Economy.free_military(c), ("+" if out >= 0 else "") + str(roundi(out))]
	for ch in _lines_box.get_children():
		ch.queue_free()
	for i in c.production_lines.size():
		_lines_box.add_child(_row(c, i))
	for child in _stock.get_children():
		child.queue_free()
	var any_stock := false
	for eq: String in Economy.equipment:
		var n := int(c.stockpile.get(eq, 0.0))
		if n > 0:
			any_stock = true
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 7)
			row.add_child(UiTheme.icon_texture(UiTheme.equipment_icon(eq), 34))
			var stock_name := UiTheme.make_label(Economy.equipment_name(eq), 16)
			stock_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(stock_name)
			var amount := UiTheme.make_label(UiTheme.format_number(n), 16, UiTheme.ACCENT)
			amount.add_theme_font_override("font", UiTheme.bold_font())
			row.add_child(amount)
			_stock.add_child(row)
	if not any_stock:
		_stock.add_child(UiTheme.make_label("—", 16, UiTheme.TEXT_DIM))

func _row(c: Country, i: int) -> Control:
	var l: ProductionLine = c.production_lines[i]
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_style(Color(1, 1, 1, 0.04), UiTheme.BORDER_DIM)
	sb.shadow_size = 0
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	head.add_child(UiTheme.icon_texture(UiTheme.equipment_icon(l.equipment), 48))
	var name := UiTheme.make_label(Economy.equipment_name(l.equipment), 17, UiTheme.ACCENT)
	name.add_theme_font_override("font", UiTheme.bold_font())
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiTheme.icon_button("minus", tr("TIP_LINE_MINUS"), func() -> void: Economy.set_line_factories(c, i, l.factories - 1), 28))
	var n := UiTheme.make_label(" %d " % l.factories, 18)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.tooltip_text = tr("TIP_LINE_FACTORIES")
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(n)
	head.add_child(UiTheme.icon_button("plus", tr("TIP_LINE_PLUS"), func() -> void: Economy.set_line_factories(c, i, l.factories + 1), 28))
	head.add_child(UiTheme.icon_button("close", tr("TIP_LINE_REMOVE"), func() -> void: Economy.remove_line(c, i), 28))
	var eqd: Dictionary = Economy.equipment[l.equipment]
	var res := []
	for r: String in eqd["resources"]:
		res.append("%s %d" % [tr("RES_" + r), eqd["resources"][r]])
	panel.tooltip_text = tr("TIP_LINE") % [Economy.equipment_name(l.equipment), str(eqd["cost"]), ", ".join(res), roundi(l.efficiency * 100)]
	v.add_child(head)
	if not eqd["resources"].is_empty():
		var resources := HBoxContainer.new()
		resources.add_theme_constant_override("separation", 5)
		for r: String in eqd["resources"]:
			resources.add_child(UiTheme.icon_texture(UiTheme.resource_icon(r), 19))
			resources.add_child(UiTheme.make_label(str(eqd["resources"][r]), 13, UiTheme.TEXT_DIM))
		v.add_child(resources)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = l.efficiency / float(Economy.prod["efficiency_cap"])
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7fb0d9")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)
	var info := tr("PRODUCTION_ROW") % [roundi(l.efficiency * 100), "%.2f" % l.last_output, UiTheme.format_number(c.stockpile.get(l.equipment, 0.0))]
	var il := UiTheme.make_label(info, 14, UiTheme.TEXT_DIM)
	v.add_child(il)
	if l.factories > 0 and l.resource_fraction < 0.999:
		var need := Economy.line_resource_need(l)
		var names := []
		for r: String in need:
			names.append(tr("RES_" + r))
		var warn := UiTheme.make_label(tr("PRODUCTION_SHORTAGE") % [roundi(l.resource_fraction * 100), ", ".join(names)], 14, UiTheme.BAD)
		v.add_child(warn)
	return panel
