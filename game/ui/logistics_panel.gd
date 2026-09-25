class_name LogisticsPanel
extends PanelContainer
## Lojistik ekranı (türün klasiklerindeki gibi): ekipman envanteri — stok, tümenlerde kullanımda, günlük üretim,
## ihtiyaç (eksik + takviye), denge; kaynak üretimi/kullanımı; fabrika ve tersane kullanımı.

var _summary: Label
var _grid: GridContainer
var _res_grid: GridContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("LOG_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 15, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.make_label(tr("LOG_EQUIPMENT"), 16, UiTheme.TEXT_DIM))
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 3)
	v.add_child(_grid)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.make_label(tr("LOG_RESOURCES"), 16, UiTheme.TEXT_DIM))
	_res_grid = GridContainer.new()
	_res_grid.columns = 4
	_res_grid.add_theme_constant_override("h_separation", 14)
	_res_grid.add_theme_constant_override("v_separation", 3)
	v.add_child(_res_grid)
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	Economy.production_changed.connect(func(_t: String) -> void:
		if visible: refresh())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func _cell(text: String, color: Color = UiTheme.TEXT, grid: GridContainer = null) -> void:
	var l := UiTheme.make_label(text, 15, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if grid != _res_grid or true else HORIZONTAL_ALIGNMENT_LEFT
	(grid if grid else _grid).add_child(l)

func refresh() -> void:
	var c := World.player()
	if c == null:
		return
	# fabrika / tersane kullanımı
	var mil_used := 0
	var dock_used := 0
	for l: ProductionLine in c.production_lines:
		if Economy.is_naval(l.equipment):
			dock_used += l.factories
		else:
			mil_used += l.factories
	_summary.text = tr("LOG_SUMMARY") % [mil_used, Economy.count(c, "military_factory"), dock_used, Economy.count(c, "dockyard")]
	for ch in _grid.get_children():
		ch.queue_free()
	for h in ["LOG_EQUIPMENT", "LOG_STOCK", "LOG_IN_USE", "LOG_DAILY", "LOG_NEED", "LOG_BALANCE"]:
		var l := UiTheme.make_label(tr(h), 15, UiTheme.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if h == "LOG_EQUIPMENT" else HORIZONTAL_ALIGNMENT_RIGHT
		_grid.add_child(l)
	# kullanımda: tümenlerin taşıdığı ekipman; ihtiyaç: eksik güç için gereken + kuyruktaki eksikler
	var in_use := {}
	var need := {}
	for d in Military.country_divisions(c.tag):
		var s := Military.div_stats(d)
		for e: String in s["equipment"]:
			var full := float(s["equipment"][e])
			in_use[e] = float(in_use.get(e, 0.0)) + full * d.strength
			need[e] = float(need.get(e, 0.0)) + full * (1.0 - d.strength)
	var daily := {}
	for l: ProductionLine in c.production_lines:
		daily[l.equipment] = float(daily.get(l.equipment, 0.0)) + l.last_output
	var names: Array = []
	for e: String in Economy.equipment.keys():
		if float(c.stockpile.get(e, 0.0)) > 0.0 or in_use.has(e) or daily.has(e):
			names.append(e)
	for e: String in names:
		var stock := float(c.stockpile.get(e, 0.0))
		var nd := float(need.get(e, 0.0))
		var bal := stock - nd
		var nl := UiTheme.make_label(Economy.equipment_name(e), 15)
		_grid.add_child(nl)
		_cell(UiTheme.format_number(roundi(stock)))
		_cell(UiTheme.format_number(roundi(float(in_use.get(e, 0.0)))))
		_cell("+%.1f" % float(daily.get(e, 0.0)) if daily.has(e) else "—", UiTheme.GOOD if daily.has(e) else UiTheme.TEXT_DIM)
		_cell(UiTheme.format_number(roundi(nd)), UiTheme.BAD if nd > stock else UiTheme.TEXT)
		_cell(("+" if bal >= 0 else "") + UiTheme.format_number(roundi(bal)), UiTheme.GOOD if bal >= 0 else UiTheme.BAD)
	# kaynaklar
	for ch in _res_grid.get_children():
		ch.queue_free()
	for h in ["LOG_RESOURCES", "LOG_RES_PROD", "LOG_RES_USE", "LOG_BALANCE"]:
		var l := UiTheme.make_label(tr(h), 15, UiTheme.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if h == "LOG_RESOURCES" else HORIZONTAL_ALIGNMENT_RIGHT
		_res_grid.add_child(l)
	var avail := Economy.resource_available(c)
	var used := Economy.resource_need(c)
	for r: String in Economy.resource_names:
		var a := float(avail.get(r, 0.0))
		var u := float(used.get(r, 0.0))
		if a <= 0.0 and u <= 0.0:
			continue
		_res_grid.add_child(UiTheme.make_label(tr("RES_" + r), 15))
		_cell("%d" % roundi(a), UiTheme.TEXT, _res_grid)
		_cell("%d" % roundi(u), UiTheme.TEXT, _res_grid)
		_cell(("+" if a - u >= 0 else "") + "%d" % roundi(a - u), UiTheme.GOOD if a - u >= 0 else UiTheme.BAD, _res_grid)
