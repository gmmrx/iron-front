class_name ProductionPanel
extends PanelContainer
## Üretim ekranı (türün klasikleri "Production"): hatlar, fabrika atama, verimlilik, stok.

var _cells: Array[Label] = []
var _lines_box: VBoxContainer
var _add: MenuButton

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_lines_box = PanelLayout.frame(self, tr("PRODUCTION_TITLE"), "production", 500.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["military_factory", tr("PRO_CELL_MIL"), tr("PRO_CELL_MIL_TIP")],
		["building_dockyard", tr("PRO_CELL_DOCK"), tr("PRO_CELL_DOCK_TIP")],
		["factory", tr("PRO_CELL_OUTPUT"), tr("PRO_CELL_OUTPUT_TIP")]])
	_add = MenuButton.new()
	_add.text = tr("PRODUCTION_ADD")
	_add.icon = UiTheme.icon("plus")
	_add.expand_icon = false
	_add.add_theme_constant_override("icon_max_width", 20)
	_add.tooltip_text = tr("TIP_LINE_ADD")
	_add.flat = false
	_add.focus_mode = Control.FOCUS_NONE
	_add.custom_minimum_size.y = 38
	var pm := _add.get_popup()
	var i := 0
	for eq: String in Economy.equipment:
		pm.add_icon_item(UiTheme.equipment_icon(eq), "%s  (%s IC)" % [Economy.equipment_name(eq), str(Economy.equipment[eq]["cost"])], i)
		pm.set_item_icon_max_width(i, 28)
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
	top.add_child(_add)
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
	if c == null or _cells.is_empty():
		return
	var mil_used := 0
	var dock_used := 0
	for l: ProductionLine in c.production_lines:
		if Economy.is_naval(l.equipment):
			dock_used += l.factories
		else:
			mil_used += l.factories
	var mil := Economy.count(c, "military_factory")
	var dock := Economy.count(c, "dockyard")
	_cells[0].text = "%d / %d" % [mil_used, mil]
	_cells[0].add_theme_color_override("font_color", UiTheme.BAD if mil_used < mil else UiTheme.TEXT)
	_cells[1].text = "%d / %d" % [dock_used, dock]
	_cells[1].add_theme_color_override("font_color", UiTheme.BAD if dock_used < dock else UiTheme.TEXT)
	var out := c.mod("factory_output") + Politics.stability_factory_mod(c)
	_cells[2].text = ("+" if out >= 0 else "") + "%d%%" % roundi(out * 100)
	_cells[2].add_theme_color_override("font_color", UiTheme.GOOD if out >= 0 else UiTheme.BAD)
	for ch in _lines_box.get_children():
		ch.queue_free()
	PanelLayout.section(_lines_box, tr("PRO_LINES") % c.production_lines.size())
	if c.production_lines.is_empty():
		PanelLayout.empty(_lines_box, tr("PRO_NO_LINES"))
	for i in c.production_lines.size():
		_row(c, i)
	PanelLayout.section(_lines_box, tr("PRODUCTION_STOCKPILE"))
	var grid := PanelLayout.grid(2)
	var any_stock := false
	for eq: String in Economy.equipment:
		var n := int(c.stockpile.get(eq, 0.0))
		if n <= 0:
			continue
		any_stock = true
		var cell := PanelContainer.new()
		cell.theme_type_variation = "Slot"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		cell.add_child(hb)
		hb.add_child(UiTheme.icon_texture(UiTheme.equipment_icon(eq), 30))
		var nm := UiTheme.make_label(Economy.equipment_name(eq), 14)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size.x = 60
		hb.add_child(nm)
		var amount := UiTheme.make_label(UiTheme.format_number(n), 15, UiTheme.ACCENT)
		amount.add_theme_font_override("font", UiTheme.bold_font())
		hb.add_child(amount)
		cell.tooltip_text = "%s: %s" % [Economy.equipment_name(eq), UiTheme.format_number(n)]
		grid.add_child(cell)
	_lines_box.add_child(grid)
	if not any_stock:
		PanelLayout.empty(_lines_box, "—")

func _row(c: Country, i: int) -> void:
	var l: ProductionLine = c.production_lines[i]
	var eqd: Dictionary = Economy.equipment[l.equipment]
	var res := []
	for r: String in eqd["resources"]:
		res.append("%s %d" % [tr("RES_" + r), eqd["resources"][r]])
	var tip := tr("TIP_LINE") % [Economy.equipment_name(l.equipment), str(eqd["cost"]), ", ".join(res), roundi(l.efficiency * 100)]
	var short := l.factories > 0 and l.resource_fraction < 0.999
	var col := PanelLayout.row(_lines_box, UiTheme.equipment_icon(l.equipment), Economy.equipment_name(l.equipment),
		tr("PRODUCTION_ROW") % [roundi(l.efficiency * 100), "%.2f" % l.last_output, UiTheme.format_number(c.stockpile.get(l.equipment, 0.0))],
		tip, "SlotBad" if short else "Row")
	# fabrika simgeleri (türün klasiğindeki gibi hattaki her fabrika bir simge)
	var fac := HBoxContainer.new()
	fac.add_theme_constant_override("separation", 1)
	fac.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ftex := UiTheme.building_icon("dockyard" if Economy.is_naval(l.equipment) else "military_factory")
	for k in mini(l.factories, 15):
		var d := UiTheme.icon_texture(ftex, 15)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fac.add_child(d)
	if not eqd["resources"].is_empty():
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fac.add_child(sp)
		for r: String in eqd["resources"]:
			var ri := UiTheme.icon_texture(UiTheme.resource_icon(r), 16)
			ri.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fac.add_child(ri)
			var rl := UiTheme.make_label(str(eqd["resources"][r]), 12, UiTheme.BAD if short else UiTheme.TEXT_DIM)
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fac.add_child(rl)
	col.add_child(fac)
	col.add_child(PanelLayout.progress(l.efficiency / float(Economy.prod["efficiency_cap"]), Color("7fb0d9"), 6.0))
	if short:
		var need := Economy.line_resource_need(l)
		var names := []
		for r: String in need:
			names.append(tr("RES_" + r))
		var warn := UiTheme.make_label(tr("PRODUCTION_SHORTAGE") % [roundi(l.resource_fraction * 100), ", ".join(names)], 13, UiTheme.BAD)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(warn)
	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 0)
	ctl.add_child(UiTheme.icon_button("minus", tr("TIP_LINE_MINUS"), func() -> void: Economy.set_line_factories(c, i, l.factories - 1), 26))
	var n := UiTheme.make_label("%d" % l.factories, 18)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.custom_minimum_size.x = 26
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.tooltip_text = tr("TIP_LINE_FACTORIES")
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	ctl.add_child(n)
	ctl.add_child(UiTheme.icon_button("plus", tr("TIP_LINE_PLUS"), func() -> void: Economy.set_line_factories(c, i, l.factories + 1), 26))
	ctl.add_child(UiTheme.icon_button("close", tr("TIP_LINE_REMOVE"), func() -> void: Economy.remove_line(c, i), 26))
	PanelLayout.row_action(col, ctl)
