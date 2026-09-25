class_name StatePanel
extends PanelContainer
## Seçili eyalet (türün klasiği "eyalet görünümü"): sahibi, nüfus/insan gücü/zafer puanı, bina yuvaları (ortak yuvalar
## simgelerle, bölge binaları seviye çubuğuyla), kaynaklar; oyuncunun eyaletinde doğrudan inşa düğmeleri.

signal diplomacy_requested(tag: String)

const SHARED := ["civilian_factory", "military_factory", "dockyard", "synthetic_refinery"]
const PROVINCIAL := ["infrastructure", "air_base", "naval_base", "anti_air"]

var _body: VBoxContainer
var _play_btn: Button
var _diplo_btn: Button
var _state_id := 0
var _province_id := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, PanelLayout.SIDE_TOP)
	visible = false
	_body = PanelLayout.frame(self, "", "construction", 400.0)
	_play_btn = Button.new()
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.custom_minimum_size.y = 40
	_play_btn.pressed.connect(_on_play_pressed)
	_diplo_btn = Button.new()
	_diplo_btn.text = tr("UI_DIPLOMACY_BTN")
	_diplo_btn.icon = UiTheme.icon("diplomacy")
	_diplo_btn.add_theme_constant_override("icon_max_width", 22)
	_diplo_btn.focus_mode = Control.FOCUS_NONE
	_diplo_btn.custom_minimum_size.y = 40
	_diplo_btn.pressed.connect(func() -> void: diplomacy_requested.emit(World.states[_state_id].owner))
	var bottom := VBoxContainer.new()
	bottom.add_child(_play_btn)
	bottom.add_child(_diplo_btn)
	get_child(0).add_child(bottom)
	World.selection_changed.connect(_on_selection)
	World.daily_update.connect(_refresh)
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _refresh())
	Economy.construction_changed.connect(func(_t: String) -> void: _refresh())
	World.player_changed.connect(func(_t: String) -> void: _refresh())

func close() -> void:
	World.select_province(0)

func _on_selection(pid: int) -> void:
	var p := World.province(pid)
	_province_id = pid
	_state_id = p.state_id if p else 0
	visible = _state_id > 0
	if visible:
		for p2 in get_parent().get_children():
			if p2 != self and (p2 is ConstructionPanel or p2 is ProductionPanel or p2 is PoliticsPanel or p2 is TradePanel or p2 is ArmyPanel \
					or p2 is ResearchPanel or p2 is DiplomacyPanel or p2 is NavyPanel or p2 is AirPanel or p2 is LogisticsPanel) and p2.visible:
				p2.close()
		_refresh()

func _refresh() -> void:
	if _state_id == 0 or not visible:
		return
	var st: StateRegion = World.states[_state_id]
	var c: Country = World.countries[st.owner]
	var p := World.province(_province_id)
	PanelLayout.set_title(self, st.display_name())
	for ch in _body.get_children():
		ch.queue_free()
	# sahibi
	var own := HBoxContainer.new()
	own.add_theme_constant_override("separation", 10)
	_body.add_child(own)
	var flag := PanelContainer.new()
	flag.theme_type_variation = "SlotGold"
	var ft := TextureRect.new()
	ft.texture = FlagFactory.get_flag(c)
	ft.custom_minimum_size = Vector2(60, 40)
	ft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ft.stretch_mode = TextureRect.STRETCH_SCALE
	flag.add_child(ft)
	own.add_child(flag)
	var oc := VBoxContainer.new()
	oc.add_theme_constant_override("separation", -2)
	own.add_child(oc)
	var on := UiTheme.make_label(c.display_name(), 19, UiTheme.ACCENT)
	on.add_theme_font_override("font", UiTheme.bold_font())
	oc.add_child(on)
	var sub := tr("CAT_" + st.category)
	var ctl := World.controller_of(_province_id)
	if ctl and ctl.tag != st.owner:
		sub += "  ·  " + tr("UI_OCCUPIED") % ctl.display_name()
	oc.add_child(UiTheme.make_label(sub, 14, UiTheme.BAD if ctl and ctl.tag != st.owner else UiTheme.TEXT_DIM))
	# temel bilgiler
	var cells := PanelLayout.info_cells(_body, [["manpower", tr("UI_POPULATION"), ""], ["army", tr("UI_MANPOWER"), ""], ["political_power", tr("UI_VICTORY_POINTS"), ""]])
	cells[0].text = UiTheme.format_number(st.population)
	cells[1].text = UiTheme.format_number(int(st.population * 0.015))
	cells[2].text = str(st.victory_points())
	var big := st.largest_city()
	PanelLayout.stat(_body, tr("UI_LARGEST_CITY"), big.display_name() if big else "—")
	PanelLayout.stat(_body, tr("UI_AREA"), "%s km²  ·  %d %s" % [UiTheme.format_number(st.area_km2), st.provinces.size(), tr("UI_PROVINCES")])
	PanelLayout.stat(_body, tr("UI_TERRAIN"), "%s%s" % [tr("TERRAIN_" + p.terrain), ("  ·  " + tr("UI_COASTAL")) if p.coastal else ""])
	if p.city:
		PanelLayout.stat(_body, tr("UI_CITY"), p.city.display_name() + (" (%s)" % tr("UI_PORT") if p.city.is_port else ""))
	# ortak bina yuvaları
	var mine := st.owner == World.player_tag and World.in_game
	var player := World.player()
	var queued := {}
	if player:
		for q in player.construction_queue:
			if q.state_id == st.id:
				queued[q.building] = int(queued.get(q.building, 0)) + 1
	PanelLayout.section(_body, tr("ST_SLOTS") % [st.used_slots(), st.building_slots])
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override("h_separation", 3)
	slots.add_theme_constant_override("v_separation", 3)
	_body.add_child(slots)
	var used := 0
	for b: String in SHARED:
		for k in st.building_level(b):
			slots.add_child(PanelLayout.slot(UiTheme.building_icon(b), 38, Economy.building_name(b), "SlotGold"))
			used += 1
	for b: String in SHARED:
		for k in int(queued.get(b, 0)):
			var s := PanelLayout.slot(UiTheme.building_icon(b), 38, Economy.building_name(b) + " — " + tr("ST_QUEUED"), "Slot")
			s.modulate = Color(1, 1, 1, 0.55)
			slots.add_child(s)
			used += 1
	for k in maxi(st.building_slots - used, 0):
		slots.add_child(PanelLayout.slot(null, 38, tr("ST_FREE_SLOT")))
	# bölge binaları (seviye çubukları)
	PanelLayout.section(_body, tr("ST_PROVINCIAL"))
	for b: String in PROVINCIAL:
		var lv := st.building_level(b)
		var mx := int(Economy.defs[b]["max"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = "%s: %d / %d" % [Economy.building_name(b), lv, mx]
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var ic := UiTheme.icon_texture(UiTheme.building_icon(b), 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var nl := UiTheme.make_label(Economy.building_name(b), 15)
		nl.custom_minimum_size.x = 130
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in mini(mx, 10):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(14, 10)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = UiTheme.ACCENT if k < lv else (Color(0.55, 0.45, 0.25, 0.6) if k < lv + int(queued.get(b, 0)) else Color(0, 0, 0, 0.55))
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
		row.add_child(pips)
		var lvl := UiTheme.make_label("%d" % lv, 15, UiTheme.ACCENT)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lvl)
		_body.add_child(row)
	# kaynaklar
	if not st.resources.is_empty():
		PanelLayout.section(_body, tr("ST_RESOURCES"))
		var rr := HFlowContainer.new()
		rr.add_theme_constant_override("h_separation", 6)
		_body.add_child(rr)
		for r: String in st.resources:
			var cell := PanelContainer.new()
			cell.theme_type_variation = "Slot"
			cell.tooltip_text = "%s: %d" % [tr("RES_" + r), st.resources[r]]
			cell.add_child(PanelLayout.icon_label(UiTheme.resource_icon(r), "%s %d" % [tr("RES_" + r), st.resources[r]], 24, 14))
			rr.add_child(cell)
	# doğrudan inşa (yalnız oyuncunun eyaleti)
	if mine:
		PanelLayout.section(_body, tr("ST_BUILD_HERE"))
		var g := PanelLayout.grid(4)
		_body.add_child(g)
		for b: String in SHARED + PROVINCIAL:
			var err := Economy.can_build(player, st, b)
			var t := PanelLayout.tile(UiTheme.building_icon(b), Economy.building_name(b), UiTheme.format_number(Economy.defs[b]["cost"]),
				"%s\n%s\n\n%s" % [Economy.building_name(b), tr("BDESC_" + b), tr("TIP_BUILD_COST") % UiTheme.format_number(Economy.defs[b]["cost"])] + ("" if err == "" else "\n\n⚠ " + tr(err)), 80, 84)
			t.add_theme_constant_override("icon_max_width", 36)
			t.add_theme_font_size_override("font_size", 12)
			t.disabled = err != ""
			t.pressed.connect(func() -> void:
				if Economy.queue_building(player, st, b):
					World.notify(tr("ST_QUEUED_NOTE") % [Economy.building_name(b), st.display_name()], "good")
				_refresh())
			g.add_child(t)
	_play_btn.text = tr("UI_PLAY_AS") % c.display_name()
	_play_btn.visible = st.owner != World.player_tag and not World.in_game
	_diplo_btn.visible = st.owner != World.player_tag and World.in_game

func _on_play_pressed() -> void:
	if _state_id > 0:
		World.set_player(World.states[_state_id].owner)
