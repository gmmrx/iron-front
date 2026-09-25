class_name ArmyPanel
extends PanelContainer
## Ordu (U): tümen şablonları (türün klasiğindeki "Eğit ve Konuşlandır" gibi), şablon tasarımcısı (tabur dizilişi,
## +/- tabur, hesaplanan değerler), konuşlandırma şartları ipucunda.

var _cells: Array[Label] = []
var _body: VBoxContainer
var _edit := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_body = PanelLayout.frame(self, tr("ARMY_TITLE"), "army", 520.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["army", tr("ARM_CELL_DIVS"), tr("ARM_CELL_DIVS_TIP")],
		["manpower", tr("LOG_CELL_MANPOWER"), tr("LOG_CELL_MANPOWER_TIP")],
		["equipment_infantry_equipment", tr("ARM_CELL_INF"), tr("ARM_CELL_INF_TIP")],
		["air", tr("ARM_CELL_AIR"), tr("ARM_CELL_AIR_TIP")]])
	World.daily_update.connect(func() -> void:
		if visible: refresh())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

static func bat_icon(b: String) -> Texture2D:
	var eq: Dictionary = Military.battalions[b].get("equipment", {})
	var keys := eq.keys()
	return UiTheme.equipment_icon(keys[keys.size() - 1]) if not keys.is_empty() else UiTheme.icon("army")

func refresh() -> void:
	var c := World.player()
	if c == null or _cells.is_empty():
		return
	var divs := Military.country_divisions(c.tag)
	_cells[0].text = str(divs.size())
	_cells[1].text = UiTheme.format_number(c.available_manpower())
	_cells[2].text = UiTheme.format_number(c.stockpile.get("infantry_equipment", 0.0))
	_cells[3].text = UiTheme.format_number(Military.air_power(c))
	for ch in _body.get_children():
		ch.queue_free()
	PanelLayout.section(_body, tr("ARM_TEMPLATES") % c.templates.size())
	for i in c.templates.size():
		_template_row(c, i)
	var newb := Button.new()
	newb.text = tr("ARMY_NEW_TEMPLATE")
	newb.icon = UiTheme.icon("plus")
	newb.add_theme_constant_override("icon_max_width", 18)
	newb.tooltip_text = tr("TIP_NEW_TEMPLATE")
	newb.focus_mode = Control.FOCUS_NONE
	newb.custom_minimum_size.y = 36
	newb.pressed.connect(func() -> void:
		c.templates.append({"name": tr("ARMY_TEMPLATE_N") % (c.templates.size() + 1), "battalions": {"infantry": 6}})
		_edit = c.templates.size() - 1
		refresh())
	_body.add_child(newb)
	if _edit >= 0 and _edit < c.templates.size():
		_build_designer(c, _edit)

func _template_row(c: Country, i: int) -> void:
	var s := Military.stats(c, i)
	var t: Dictionary = c.templates[i]
	var main := "infantry"
	var best := -1
	for b: String in t["battalions"]:
		if int(t["battalions"][b]) > best:
			best = int(t["battalions"][b])
			main = b
	var col := PanelLayout.row(_body, bat_icon(main), t["name"],
		tr("ARMY_STATS") % [int(s["soft"]), int(s["hard"]), int(s["defense"]), int(s["breakthrough"]), int(s["org"]), snappedf(s["speed"], 0.1), int(s["width"])],
		"", "SlotGold" if i == _edit else "Row")
	# tabur dizilişi (küçük simgeler)
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 1)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b: String in t["battalions"]:
		for k in int(t["battalions"][b]):
			var ic := UiTheme.icon_texture(bat_icon(b), 16)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.add_child(ic)
	col.add_child(strip)
	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 4)
	ctl.add_child(UiTheme.icon_button("production", tr("TIP_EDIT_TEMPLATE"), func() -> void:
		_edit = -1 if _edit == i else i
		refresh(), 28))
	var short := Military.deploy_shortfall(c, i)
	var tip := tr("TIP_DEPLOY") % [UiTheme.format_number(s["manpower"])]
	for e: String in s["equipment"]:
		tip += "\n• %s: %d (%s: %s)" % [Economy.equipment_name(e), int(s["equipment"][e]), tr("ARMY_STOCK"), UiTheme.format_number(c.stockpile.get(e, 0.0))]
	if not short.is_empty():
		tip += "\n\n" + tr("ARMY_MISSING")
		for k: String in short:
			tip += "\n• %s" % (tr("UI_MANPOWER") if k == "manpower" else Economy.equipment_name(k))
	ctl.add_child(PanelLayout.small_button(tr("ARMY_DEPLOY"), func() -> void:
		if Military.deploy(c, i) != null:
			World.notify(tr("NOTE_DEPLOYED") % c.templates[i]["name"], "good")
		refresh(), short.is_empty(), tip))
	PanelLayout.row_action(col, ctl)

func _build_designer(c: Country, i: int) -> void:
	var t: Dictionary = c.templates[i]
	PanelLayout.section(_body, tr("ARMY_DESIGNER") % t["name"])
	# tabur ızgarası (türün klasiğindeki 5x5 düzenin sade hali)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	var n := 0
	for b: String in t["battalions"]:
		for k in int(t["battalions"][b]):
			grid.add_child(PanelLayout.slot(bat_icon(b), 40, Politics.loc(Military.battalions[b]["name"]), "SlotGold"))
			n += 1
	for k in maxi(0, 10 - n % 10) if n % 10 != 0 or n == 0 else 0:
		grid.add_child(PanelLayout.slot(null, 40))
	_body.add_child(grid)
	for b: String in Military.battalions:
		var bd: Dictionary = Military.battalions[b]
		if bd.has("requires") and not Research.is_unlocked(c, bd["requires"]):
			continue
		var tip := tr("TIP_BATTALION") % [bd["soft"], bd["hard"], bd["defense"], bd["breakthrough"], bd["hp"], bd["org"], bd["speed"], bd["width"]]
		var col := PanelLayout.row(_body, bat_icon(b), Politics.loc(bd["name"]),
			tr("ARM_BAT_SUB") % [bd["soft"], bd["hard"], bd["defense"], bd["width"]], tip)
		var ctl := HBoxContainer.new()
		ctl.add_theme_constant_override("separation", 0)
		ctl.add_child(UiTheme.icon_button("minus", tr("TIP_BAT_MINUS"), func() -> void: _change(c, i, b, -1), 26))
		var cnt := UiTheme.make_label("%d" % int(t["battalions"].get(b, 0)), 18)
		cnt.add_theme_font_override("font", UiTheme.bold_font())
		cnt.custom_minimum_size.x = 26
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ctl.add_child(cnt)
		ctl.add_child(UiTheme.icon_button("plus", tr("TIP_BAT_PLUS"), func() -> void: _change(c, i, b, 1), 26))
		PanelLayout.row_action(col, ctl)
	# hesaplanan değerler
	var s := Military.stats(c, i)
	PanelLayout.section(_body, tr("ARM_STATS"))
	var g := PanelLayout.grid(2)
	g.add_theme_constant_override("h_separation", 18)
	_body.add_child(g)
	for pair: Array in [["ARM_SOFT", int(s["soft"])], ["ARM_HARD", int(s["hard"])], ["ARM_DEF", int(s["defense"])],
			["ARM_BRK", int(s["breakthrough"])], ["ARM_ORG", int(s["org"])], ["ARM_SPEED", "%s km/s" % snappedf(s["speed"], 0.1)],
			["ARM_WIDTH", int(s["width"])], ["ARM_MANPOWER", UiTheme.format_number(s["manpower"])]]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(box)
		PanelLayout.stat(box, tr(pair[0]), str(pair[1]), tr(pair[0] + "_TIP"))

func _change(c: Country, i: int, b: String, d: int) -> void:
	var bats: Dictionary = c.templates[i]["battalions"]
	var n := clampi(int(bats.get(b, 0)) + d, 0, 12)
	var total := 0
	for k: String in bats:
		total += int(bats[k]) if k != b else n
	if b not in bats:
		total += n
	if total < 1 or total > 25:
		return
	bats[b] = n
	if n == 0:
		bats.erase(b)
	Military.invalidate_stats(c.tag)
	refresh()
