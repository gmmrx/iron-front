class_name TradePanel
extends PanelContainer
## Ticaret ekranı (türün klasiği düzeni): kaynak tablosu (üretim, ihtiyaç, ithalat, ihracat, denge), açığı olan
## kaynağa satıcı seçip anlaşma yapma, anlaşma listesi (+/- miktar, iptal). Otomatik ticaret yalnız oyuncu açarsa.

const STEP := 8.0          ## bir sivil fabrikanın karşıladığı kaynak

var _cells: Array[Label] = []
var _auto: CheckButton
var _body: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_body = PanelLayout.frame(self, tr("TRADE_TITLE"), "trade", 520.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["trade", tr("TRD_CELL_LAW"), tr("TRD_CELL_LAW_TIP")],
		["building_civilian_factory", tr("TRD_CELL_PAID"), tr("TRD_CELL_PAID_TIP")],
		["factory", tr("TRD_CELL_EARNED"), tr("TRD_CELL_EARNED_TIP")],
		["equipment_convoy", tr("TRD_CELL_CONVOY"), tr("TRD_CELL_CONVOY_TIP")]])
	_auto = CheckButton.new()
	_auto.text = tr("TRD_AUTO")
	_auto.tooltip_text = tr("TRD_AUTO_TIP")
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.add_theme_font_size_override("font_size", 15)
	_auto.toggled.connect(func(on: bool) -> void:
		var c := World.player()
		if c and c.auto_trade != on:
			Economy.set_auto_trade(c, on))
	top.add_child(_auto)
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
	if c == null or _cells.is_empty():
		return
	_cells[0].text = Economy.law_name("trade", c.laws["trade"])
	_cells[1].text = str(c.trade_factories_paid)
	_cells[2].text = str(c.trade_factories_earned)
	var cf := Economy.convoy_factor(c)
	_cells[3].text = "%d%%" % roundi(cf * 100)
	_cells[3].add_theme_color_override("font_color", UiTheme.GOOD if cf >= 0.999 else UiTheme.BAD)
	_auto.set_pressed_no_signal(c.auto_trade)
	for ch in _body.get_children():
		ch.queue_free()
	PanelLayout.section(_body, tr("TRD_RESOURCES"))
	var t := PanelLayout.table(_body, [tr("TRADE_RES"), tr("TRADE_PROD"), tr("TRADE_NEED"), tr("TRADE_IMPORT"), tr("TRADE_EXPORT"), tr("TRADE_BALANCE"), ""],
		[120, 50, 50, 50, 50, 54, 66])
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
		var buy: Control = Control.new()
		if not c.auto_trade:
			buy = _buy_button(c, r, maxf(-bal, 0.0))
		var row := PanelLayout.table_row(t, [
			PanelLayout.icon_label(UiTheme.resource_icon(r), tr("RES_" + r), 26),
			str(int(prod_.get(r, 0))), str(int(need.get(r, 0.0))),
			[("+%d" % int(imp)) if imp > 0 else "—", UiTheme.GOOD if imp > 0 else UiTheme.TEXT_DIM],
			[("-%d" % int(exp)) if exp > 0 else "—", UiTheme.ACCENT if exp > 0 else UiTheme.TEXT_DIM],
			["%+d" % int(bal), UiTheme.BAD if bal < -0.5 else UiTheme.GOOD], buy],
			tr("TRD_ROW_TIP") % [tr("RES_" + r), int(prod_.get(r, 0)), int(need.get(r, 0.0)), int(imp), int(exp), int(bal)])
		buy.mouse_filter = Control.MOUSE_FILTER_STOP
		if bal < -0.5:
			row.theme_type_variation = "SlotBad"
	# anlaşmalar
	PanelLayout.section(_body, tr("TRD_DEALS_MANUAL") if not c.auto_trade else tr("TRD_DEALS_AUTO"))
	if c.imports.is_empty() and c.trade_orders.is_empty():
		PanelLayout.empty(_body, tr("TRD_NO_IMPORTS"))
	if not c.auto_trade:
		for idx in c.trade_orders.size():
			var o: Dictionary = c.trade_orders[idx]
			var got := 0.0
			for i: Dictionary in c.imports:
				if i["res"] == o["res"] and i["from"] == o["from"]:
					got += float(i["amount"])
			var seller: Country = World.countries.get(o["from"])
			var sub := tr("TRD_DEAL_SUB") % [int(got), int(o["amount"]), int(ceil(float(o["amount"]) / STEP))]
			if got < float(o["amount"]) - 0.5:
				sub += "  ·  " + tr("TRD_DEAL_SHORT")
			var col := PanelLayout.row(_body, FlagFactory.get_flag(seller) if seller else null,
				"%s  ←  %s" % [tr("RES_" + o["res"]), seller.display_name() if seller else o["from"]], sub, "", "Row")
			var ctl := HBoxContainer.new()
			ctl.add_theme_constant_override("separation", 0)
			ctl.add_child(UiTheme.icon_button("minus", tr("TRD_LESS"), func() -> void: Economy.change_trade(c, idx, -STEP), 26))
			var more := UiTheme.icon_button("plus", tr("TRD_MORE"), func() -> void: Economy.change_trade(c, idx, STEP), 26)
			more.disabled = not Economy.trade_affordable(c, STEP)
			if more.disabled:
				more.tooltip_text = tr("TRD_CANT_PAY")
			ctl.add_child(more)
			ctl.add_child(UiTheme.icon_button("close", tr("TRD_CANCEL"), func() -> void: Economy.change_trade(c, idx, -99999.0), 26))
			PanelLayout.row_action(col, ctl)
	else:
		for i: Dictionary in c.imports:
			var seller: Country = World.countries.get(i["from"])
			PanelLayout.row(_body, FlagFactory.get_flag(seller) if seller else null,
				"+%d %s  ←  %s" % [int(i["amount"]), tr("RES_" + i["res"]), seller.display_name() if seller else i["from"]], "")
	if not c.exports.is_empty():
		PanelLayout.section(_body, tr("TRD_EXPORTS"))
		for e: Dictionary in c.exports:
			var buyer: Country = World.countries.get(e["to"])
			PanelLayout.row(_body, FlagFactory.get_flag(buyer) if buyer else null,
				"-%d %s  →  %s" % [int(e["amount"]), tr("RES_" + e["res"]), buyer.display_name() if buyer else e["to"]], "")

## Açığı olan kaynak için satıcı menüsü
func _buy_button(c: Country, r: String, deficit: float) -> Control:
	var mb := MenuButton.new()
	mb.text = tr("TRD_BUY")
	mb.flat = false
	mb.focus_mode = Control.FOCUS_NONE
	mb.add_theme_font_size_override("font_size", 13)
	mb.tooltip_text = tr("TRD_BUY_TIP") % tr("RES_" + r)
	if deficit > 0.5:
		mb.add_theme_color_override("font_color", UiTheme.ACCENT)
	var pm := mb.get_popup()
	pm.about_to_popup.connect(func() -> void:
		pm.clear()
		var sellers := Economy.trade_sellers(c, r)
		if sellers.is_empty():
			pm.add_item(tr("TRD_NO_SELLERS"), 0)
			pm.set_item_disabled(0, true)
			return
		var can_pay := Economy.trade_affordable(c, STEP)
		for k in mini(sellers.size(), 12):
			var s: Country = World.countries[sellers[k][0]]
			pm.add_icon_item(FlagFactory.get_flag(s), tr("TRD_SELLER") % [s.display_name(), int(sellers[k][1])], k)
			pm.set_item_icon_max_width(k, 30)
			pm.set_item_metadata(k, sellers[k])
			if not can_pay:
				pm.set_item_disabled(k, true)
				pm.set_item_tooltip(k, tr("TRD_CANT_PAY"))
		)
	pm.id_pressed.connect(func(id: int) -> void:
		var sel: Array = pm.get_item_metadata(pm.get_item_index(id))
		var want := maxf(ceilf(maxf(deficit, 1.0) / STEP) * STEP, STEP)
		# ödenebildiği kadar (8'lik adımlarla)
		var amt := minf(want, floorf(float(sel[1])))
		while amt > STEP and not Economy.trade_affordable(c, amt):
			amt -= STEP
		if not Economy.add_trade(c, r, sel[0], amt):
			World.notify(tr("TRD_CANT_PAY"), "bad"))
	return mb
