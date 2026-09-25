class_name LogisticsPanel
extends PanelContainer
## Lojistik ekranı (türün klasiklerindeki gibi): ekipman envanteri — stok, tümenlerde kullanımda, günlük üretim,
## ihtiyaç (eksik + takviye), denge; kaynak üretimi/kullanımı; fabrika ve tersane kullanımı.

var _cells: Array[Label] = []
var _body: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_body = PanelLayout.frame(self, tr("LOG_TITLE"), "army", 560.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["military_factory", tr("PRO_CELL_MIL"), tr("PRO_CELL_MIL_TIP")],
		["building_dockyard", tr("PRO_CELL_DOCK"), tr("PRO_CELL_DOCK_TIP")],
		["resource_oil", tr("LOG_CELL_FUEL"), tr("LOG_CELL_FUEL_TIP")],
		["manpower", tr("LOG_CELL_MANPOWER"), tr("LOG_CELL_MANPOWER_TIP")]])
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	Economy.production_changed.connect(func(_t: String) -> void:
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
	_cells[0].text = "%d / %d" % [mil_used, Economy.count(c, "military_factory")]
	_cells[1].text = "%d / %d" % [dock_used, Economy.count(c, "dockyard")]
	_cells[2].text = UiTheme.format_number(maxf(c.fuel, 0.0))
	_cells[3].text = UiTheme.format_number(c.available_manpower())
	for ch in _body.get_children():
		ch.queue_free()
	# kullanımda: tümenlerin taşıdığı ekipman; ihtiyaç: eksik güç için gereken
	var in_use := {}
	var need := {}
	for d in Military.country_divisions(c.tag):
		var st := Military.div_stats(d)
		for e: String in st["equipment"]:
			var full := float(st["equipment"][e])
			in_use[e] = float(in_use.get(e, 0.0)) + full * d.strength
			need[e] = float(need.get(e, 0.0)) + full * (1.0 - d.strength)
	var daily := {}
	for l: ProductionLine in c.production_lines:
		daily[l.equipment] = float(daily.get(l.equipment, 0.0)) + l.last_output
	PanelLayout.section(_body, tr("LOG_EQUIPMENT"))
	var t := PanelLayout.table(_body, [tr("LOG_EQUIPMENT"), tr("LOG_STOCK"), tr("LOG_IN_USE"), tr("LOG_DAILY"), tr("LOG_NEED"), tr("LOG_BALANCE")],
		[150, 62, 70, 58, 62, 70])
	var any := false
	for e: String in Economy.equipment.keys():
		if not (float(c.stockpile.get(e, 0.0)) > 0.0 or in_use.has(e) or daily.has(e)):
			continue
		any = true
		var stock := float(c.stockpile.get(e, 0.0))
		var nd := float(need.get(e, 0.0))
		var bal := stock - nd
		var row := PanelLayout.table_row(t, [
			PanelLayout.icon_label(UiTheme.equipment_icon(e), Economy.equipment_name(e), 26),
			UiTheme.format_number(roundi(stock)),
			UiTheme.format_number(roundi(float(in_use.get(e, 0.0)))),
			["+%.1f" % float(daily.get(e, 0.0)) if daily.has(e) else "—", UiTheme.GOOD if daily.has(e) else UiTheme.TEXT_DIM],
			[UiTheme.format_number(roundi(nd)), UiTheme.BAD if nd > stock else UiTheme.TEXT],
			[("+" if bal >= 0 else "") + UiTheme.format_number(roundi(bal)), UiTheme.GOOD if bal >= 0 else UiTheme.BAD]],
			tr("LOG_ROW_TIP") % [Economy.equipment_name(e), roundi(stock), roundi(float(in_use.get(e, 0.0))), roundi(nd)])
		if bal < 0:
			row.theme_type_variation = "SlotBad"
	if not any:
		PanelLayout.empty(_body, "—")
	PanelLayout.section(_body, tr("LOG_RESOURCES"))
	var rt := PanelLayout.table(_body, [tr("LOG_RESOURCES"), tr("LOG_RES_PROD"), tr("LOG_RES_USE"), tr("LOG_BALANCE")], [180, 90, 90, 90])
	var avail := Economy.resource_available(c)
	var used := Economy.resource_need(c)
	for r: String in Economy.resource_names:
		var a := float(avail.get(r, 0.0))
		var u := float(used.get(r, 0.0))
		if a <= 0.0 and u <= 0.0:
			continue
		PanelLayout.table_row(rt, [PanelLayout.icon_label(UiTheme.resource_icon(r), tr("RES_" + r), 24),
			"%d" % roundi(a), "%d" % roundi(u),
			[("+" if a - u >= 0 else "") + "%d" % roundi(a - u), UiTheme.GOOD if a - u >= 0 else UiTheme.BAD]])
