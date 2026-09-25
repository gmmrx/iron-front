class_name TradePanel
extends PanelContainer
## Ticaret ekranı: kaynak dengesi ve otomatik ithalat/ihracat.

var _summary: Label
var _grid: GridContainer
var _deals: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(500, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("TRADE_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 16, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	v.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(_grid)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.make_label(tr("TRADE_DEALS"), 16, UiTheme.TEXT_DIM))
	_deals = UiTheme.make_label("", 15)
	_deals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_deals)
	Economy.trade_changed.connect(func() -> void:
		if visible: refresh())
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
	_summary.text = tr("TRADE_SUMMARY") % [Economy.law_name("trade", c.laws["trade"]), c.trade_factories_paid, c.trade_factories_earned]
	for ch in _grid.get_children():
		ch.queue_free()
	for h in ["TRADE_RES", "TRADE_PROD", "TRADE_NEED", "TRADE_IMPORT", "TRADE_EXPORT", "TRADE_BALANCE"]:
		_grid.add_child(UiTheme.make_label(tr(h), 15, UiTheme.TEXT_DIM))
	var prod_ := Economy.resource_production(c)
	var need := Economy.resource_need(c)
	var avail := Economy.resource_available(c)
	for r: String in Economy.resource_names:
		var imp := 0.0
		var exp := 0.0
		for i: Dictionary in c.imports:
			if i["res"] == r: imp += float(i["amount"])
		for e: Dictionary in c.exports:
			if e["res"] == r: exp += float(e["amount"])
		var bal := float(avail.get(r, 0)) - float(need.get(r, 0.0))
		var resource_cell := HBoxContainer.new()
		resource_cell.add_theme_constant_override("separation", 5)
		resource_cell.add_child(UiTheme.icon_texture(UiTheme.resource_icon(r), 34))
		resource_cell.add_child(UiTheme.make_label(tr("RES_" + r), 16))
		_grid.add_child(resource_cell)
		_grid.add_child(UiTheme.make_label(str(int(prod_.get(r, 0))), 16))
		_grid.add_child(UiTheme.make_label(str(int(need.get(r, 0.0))), 16))
		_grid.add_child(UiTheme.make_label(("+%d" % int(imp)) if imp > 0 else "—", 16, UiTheme.GOOD if imp > 0 else UiTheme.TEXT_DIM))
		_grid.add_child(UiTheme.make_label(("-%d" % int(exp)) if exp > 0 else "—", 16, UiTheme.ACCENT if exp > 0 else UiTheme.TEXT_DIM))
		_grid.add_child(UiTheme.make_label("%+d" % int(bal), 16, UiTheme.BAD if bal < -0.5 else UiTheme.GOOD))
	var lines := []
	for i: Dictionary in c.imports:
		lines.append(tr("TRADE_IMPORT_LINE") % [int(i["amount"]), tr("RES_" + i["res"]), World.countries[i["from"]].display_name()])
	for e: Dictionary in c.exports:
		lines.append(tr("TRADE_EXPORT_LINE") % [int(e["amount"]), tr("RES_" + e["res"]), World.countries[e["to"]].display_name()])
	_deals.text = "\n".join(lines) if not lines.is_empty() else "—"
