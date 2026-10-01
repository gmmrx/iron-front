class_name NavyPanel
extends PanelContainer
## Donanma (N): filolar, bileşim, organizasyon, görev ve görev bölgesi. Haritada filo seçimiyle eşgüdümlü.

signal fleet_selected(fleet: Fleet)
signal pick_zone_requested(fleet: Fleet)
## Yeni gemileri konuşlandır: panel kapanır, haritada limanlı eyaletler vurgulanır, oyuncu limanı seçer
signal deploy_requested

const MISSION_ICONS := ["building_naval_base", "equipment_battleship", "equipment_submarine", "equipment_convoy"]

var selected_id := 0
var _cells: Array[Label] = []
var _list: VBoxContainer
var _pending := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_list = PanelLayout.frame(self, tr("NAVY_TITLE"), "navy", 500.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["navy", tr("NAV_CELL_POWER"), tr("NAV_CELL_POWER_TIP")],
		["equipment_destroyer", tr("NAV_CELL_FLEETS"), tr("NAV_CELL_FLEETS_TIP")],
		["equipment_convoy", tr("NAV_CELL_CONVOY"), tr("NAV_CELL_CONVOY_TIP")],
		["trade", tr("TRD_CELL_CONVOY"), tr("TRD_CELL_CONVOY_TIP")]])
	Navy.fleets_changed.connect(_queue_refresh)
	Navy.naval_battles_changed.connect(_queue_refresh)
	World.daily_update.connect(_queue_refresh)

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func select(f: Fleet) -> void:
	selected_id = f.id if f else 0
	if visible:
		refresh()

func _queue_refresh() -> void:
	if visible and not _pending:
		_pending = true
		refresh.call_deferred()

func refresh() -> void:
	_pending = false
	var c := World.player()
	if c == null:
		return
	if _cells.is_empty():
		return
	var own := Navy.fleets_of(c.tag)
	_cells[0].text = str(roundi(Navy.power(c.tag)))
	_cells[1].text = str(own.size())
	_cells[2].text = str(roundi(float(c.stockpile.get("convoy", 0.0))))
	var cf := Economy.convoy_factor(c)
	_cells[3].text = "%d%%" % roundi(cf * 100.0)
	_cells[3].add_theme_color_override("font_color", UiTheme.GOOD if cf >= 0.999 else UiTheme.BAD)
	for ch in _list.get_children():
		ch.queue_free()
	# tersaneden çıkıp limanı bekleyen gemiler
	var fresh := Navy.new_ships(c)
	if not fresh.is_empty():
		PanelLayout.section(_list, tr("NAVY_NEW_SHIPS"))
		var parts: Array[String] = []
		for t: String in fresh:
			parts.append("%d %s" % [int(fresh[t]), Economy.equipment_name(t)])
		var col := PanelLayout.row(_list, UiTheme.icon("equipment_destroyer"), tr("NAVY_NEW_SHIPS_ROW"), ", ".join(parts),
			tr("TIP_NAVY_DEPLOY_SHIPS"))
		PanelLayout.row_action(col, PanelLayout.small_button(tr("NAVY_DEPLOY_SHIPS"), func() -> void:
			deploy_requested.emit(), not Navy.ports_of(c.tag).is_empty(), tr("TIP_NAVY_DEPLOY_SHIPS")))
	PanelLayout.section(_list, tr("NAV_FLEETS") % own.size())
	if own.is_empty():
		PanelLayout.empty(_list, tr("NAVY_NO_FLEETS"))
		return
	for f in own:
		_list.add_child(_card(f))

## Filo kartı: başlık (yuva, ad, durum; sağda bileşim), bütünlük çubuğu, görev şeridi, görev bölgesi. Seçili kart altın
## çerçeveli, adı altın; tıklayınca seçilir (haritada da)
func _card(f: Fleet) -> Control:
	var sel := f.id == selected_id
	var panel := PanelContainer.new()
	panel.theme_type_variation = "SlotGold" if sel else "Row"
	UiTheme.pad(panel, 14, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = tr("TIP_FLEET_CARD")
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			selected_id = f.id
			fleet_selected.emit(f)
			refresh())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	# başlık: yuva + ad + durum; sağda bileşim (gemi türü ve sayısı)
	var head := PanelLayout.card_head(v, UiTheme.icon("navy"), f.name, _status(f), sel,
		UiTheme.BAD if f.in_combat or f.returning else UiTheme.TEXT_DIM)
	var comp := HBoxContainer.new()
	comp.add_theme_constant_override("separation", 10)
	comp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for t: String in Navy.SHIP_TYPES:
		var n := int(f.ships.get(t, 0))
		if n <= 0:
			continue
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		var st: Dictionary = Navy.SHIPS[t]
		box.tooltip_text = tr("TIP_SHIP_TYPE") % [tr("SHIPS_" + t), n, st["atk"], st["hp"], roundi(st["speed"])]
		var ic := UiTheme.icon_texture(UiTheme.equipment_icon(t), 30)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)
		var l := UiTheme.make_label("%d" % n, 17)
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		comp.add_child(box)
	head.add_child(comp)

	PanelLayout.bar_row(v, tr("NAVY_ORG"), f.org, "%d%%" % roundi(f.org * 100.0),
		Color(0.45, 0.85, 0.35) if f.org > 0.5 else UiTheme.BAD, "%s: %d%%" % [tr("NAVY_ORG"), roundi(f.org * 100.0)])

	# görev
	var items: Array = []
	for m in 4:
		items.append([MISSION_ICONS[m], tr("MISSION_%d" % m), tr("TIP_MISSION_%d" % m)])
	PanelLayout.choice_row(v, items, int(f.mission), func(m: int) -> void:
		f.returning = false
		Navy.set_mission(f, m as Fleet.Mission)
		selected_id = f.id
		fleet_selected.emit(f)
		refresh())

	# görev bölgesi
	var zrow := HBoxContainer.new()
	zrow.add_theme_constant_override("separation", 10)
	var zl := UiTheme.make_label(tr("NAVY_ZONE") % Navy.zone_name(f.zone_center), 15, UiTheme.TEXT)
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	zl.custom_minimum_size.x = 1
	zrow.add_child(zl)
	var pick := PanelLayout.small_button(tr("NAVY_PICK_ZONE"), func() -> void:
		selected_id = f.id
		fleet_selected.emit(f)
		pick_zone_requested.emit(f), true, tr("TIP_NAVY_PICK_ZONE"))
	pick.custom_minimum_size = Vector2(120, 36)
	zrow.add_child(pick)
	v.add_child(zrow)
	return panel

func _status(f: Fleet) -> String:
	if f.in_combat:
		return tr("NAVY_IN_COMBAT")
	if f.returning:
		return tr("NAVY_RETURNING")
	var p := World.province(f.location)
	if p.is_land():
		return tr("NAVY_LOCATION_PORT") % (p.city.display_name() if p.city else "#%d" % p.id)
	return tr("NAVY_LOCATION_SEA") % Navy.zone_name(Navy.sea_for(f.location))
