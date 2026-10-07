class_name NavyPanel
extends PanelContainer
## Donanma (N): filolar, bileşim, organizasyon, görev ve görev bölgesi. Haritada filo seçimiyle eşgüdümlü.

signal fleet_selected(fleet: Fleet)
signal pick_zone_requested(fleet: Fleet)
## Yeni gemileri konuşlandır: panel kapanır, haritada limanlı eyaletler vurgulanır, oyuncu limanı seçer
signal deploy_requested

const MISSION_ICONS := ["building_naval_base", "equipment_battleship", "equipment_submarine", "equipment_convoy"]
const SelectionCard := preload("res://game/ui/force_selection_card.gd")

var selected_id := 0
var _cells: Array[Label] = []
var _list: VBoxContainer
var _pending := false
var _cards := {}               ## live own fleet id -> explicit selection card
var _clear_selection_button: Button
var _grid: GridContainer
var _details: VBoxContainer

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
	_clear_selection_button = PanelLayout.small_button(tr("FORCE_CLEAR_SELECTION"), clear_selection, false)
	_clear_selection_button.set_meta("audio_silent", true)
	_clear_selection_button.name = "ClearFleetSelection"
	_clear_selection_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(_clear_selection_button)
	Navy.fleets_changed.connect(_queue_refresh)
	Navy.naval_battles_changed.connect(_queue_refresh)
	World.daily_update.connect(_queue_refresh)
	World.player_changed.connect(func(_tag: String) -> void:
		_prune_selection()
		_queue_refresh())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func select(f: Fleet) -> void:
	selected_id = f.id if f != null and _owned_fleet(f.id) == f else 0
	_sync_cards() # Map selection is synchronization only, never an order or a second selection signal.

func clear_selection(audible := true) -> void:
	if selected_id == 0: return
	selected_id = 0
	_sync_cards()
	fleet_selected.emit(null)
	if audible: Audio.play("unit_deselect")

func _owned_fleet(id: int) -> Fleet:
	var c := World.player()
	if c == null: return null
	for f: Fleet in Navy.fleets:
		if f.id == id and f.owner == c.tag: return f
	return null

func _toggle_fleet(id: int) -> void:
	var f := _owned_fleet(id)
	if f == null:
		_prune_selection()
		return
	selected_id = 0 if selected_id == id else id
	_sync_cards()
	fleet_selected.emit(f if selected_id != 0 else null)
	# FleetLayer.select emits the selection cue; clearing has no map cue.
	if selected_id == 0: Audio.play("unit_deselect")

func _sync_cards() -> void:
	for id: int in _cards:
		var card: SelectionCard = _cards[id]
		if is_instance_valid(card): card.set_selected(id == selected_id)
	if is_instance_valid(_clear_selection_button): _clear_selection_button.disabled = selected_id == 0
	_rebuild_details()

func _prune_selection() -> void:
	if selected_id != 0 and _owned_fleet(selected_id) == null:
		clear_selection(false)

func _queue_refresh() -> void:
	_prune_selection() # Destroyed/transferred fleets cannot remain selected while the panel is closed.
	if visible and not _pending:
		_pending = true
		refresh.call_deferred()

func refresh() -> void:
	_pending = false
	_prune_selection()
	var c := World.player()
	if c == null:
		return
	if _cells.is_empty():
		return
	_remember_scroll()
	var own := Navy.fleets_of(c.tag)
	_cells[0].text = str(roundi(Navy.power(c.tag)))
	_cells[1].text = str(own.size())
	_cells[2].text = str(roundi(float(c.stockpile.get("convoy", 0.0))))
	var cf := Economy.convoy_factor(c)
	_cells[3].text = "%d%%" % roundi(cf * 100.0)
	_cells[3].add_theme_color_override("font_color", UiTheme.GOOD if cf >= 0.999 else UiTheme.BAD)
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	_cards.clear()
	_grid = null
	_details = null
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
		_restore_list_scroll()
		return
	_grid = PanelLayout.grid(2)
	_grid.name = "NavyRosterGrid"
	_list.add_child(_grid)
	for f in own:
		_grid.add_child(_card(f))
	_details = VBoxContainer.new()
	_details.name = "SelectedFleetDetails"
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_details)
	_sync_cards()
	_restore_list_scroll()
	PanelLayout.queue_fit(self)

## Filo kartı: başlık (yuva, ad, durum; sağda bileşim), bütünlük çubuğu, görev şeridi, görev bölgesi. Seçili kart altın
## çerçeveli, adı altın; tıklayınca seçilir (haritada da)
func _card(f: Fleet) -> Control:
	var sel := f.id == selected_id
	var panel := SelectionCard.new()
	panel.set_compact()
	panel.name = "FleetSelection_%d" % f.id
	panel.set_meta("fleet_id", f.id)
	panel.configure(f.name, _status(f), UiTheme.icon("navy"), sel)
	panel.subtitle_label.add_theme_color_override("font_color", UiTheme.BAD if f.in_combat or f.returning else UiTheme.TEXT_DIM)
	panel.select_button.tooltip_text += "\n" + tr("TIP_FLEET_CARD")
	panel.selection_requested.connect(func() -> void: _toggle_fleet(f.id))
	_cards[f.id] = panel
	var count := UiTheme.make_label("%d %s · %d%% %s" % [f.total(), tr("SEA_SHIPS"), roundi(f.org * 100.0), tr("NAVY_ORG")], 13, UiTheme.TEXT)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.content.add_child(count)
	panel.content.add_child(PanelLayout.progress(f.org, UiTheme.GOOD if f.org > 0.5 else UiTheme.BAD, 4))
	return panel

func _rebuild_details() -> void:
	if not is_instance_valid(_details): return
	_remember_scroll()
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var f := _owned_fleet(selected_id)
	if f == null:
		PanelLayout.empty(_details, tr("FORCE_SELECT_HINT"))
	else:
		var panel := PanelContainer.new()
		panel.name = "SelectedFleetOperations"
		panel.set_meta("selection_detail", true)
		panel.set_meta("selected_id", f.id)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 10))
		_details.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		panel.add_child(v)
		var title := UiTheme.make_label(f.name + " · " + tr("FORCE_OPERATIONS"), 17, UiTheme.ACCENT)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(title)
		_build_operations(v, f)
	_restore_list_scroll()
	PanelLayout.queue_fit(self)

func _build_operations(v: VBoxContainer, f: Fleet) -> void:

	# başlık: yuva + ad + durum; sağda bileşim (gemi türü ve sayısı)
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
	v.add_child(comp) # Keep the explicit checkbox/header readable even for mixed large fleets.

	PanelLayout.bar_row(v, tr("NAVY_ORG"), f.org, "%d%%" % roundi(f.org * 100.0),
		Color(0.45, 0.85, 0.35) if f.org > 0.5 else UiTheme.BAD, "%s: %d%%" % [tr("NAVY_ORG"), roundi(f.org * 100.0)])

	# görev
	var items: Array = []
	for m in 4:
		items.append([MISSION_ICONS[m], tr("MISSION_%d" % m), tr("TIP_MISSION_%d" % m)])
	PanelLayout.choice_row(v, items, int(f.mission), func(m: int) -> void:
		if _owned_fleet(f.id) != f or selected_id != f.id: return
		f.returning = false
		Navy.set_mission(f, m as Fleet.Mission)
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
		if _owned_fleet(f.id) != f or selected_id != f.id: return
		pick_zone_requested.emit(f), true, tr("TIP_NAVY_PICK_ZONE"))
	pick.custom_minimum_size = Vector2(120, 36)
	zrow.add_child(pick)
	v.add_child(zrow)

func _remember_scroll() -> void:
	var scroll := get_meta("scroll") as ScrollContainer
	if not scroll.has_meta("force_scroll_restore"):
		scroll.set_meta("force_scroll_restore", scroll.scroll_vertical)

func _restore_list_scroll() -> void:
	var scroll := get_meta("scroll") as ScrollContainer
	if scroll.has_meta("force_scroll_restore"):
		_restore_scroll.call_deferred(weakref(scroll), int(scroll.get_meta("force_scroll_restore")))

static func _restore_scroll(reference: WeakRef, value: int, after_layout := false) -> void:
	var scroll := reference.get_ref() as ScrollContainer
	if not is_instance_valid(scroll): return
	if int(scroll.get_meta("force_scroll_restore", -1)) != value: return
	scroll.scroll_vertical = value
	if not after_layout:
		_restore_scroll.call_deferred(reference, value, true)
	else:
		scroll.remove_meta("force_scroll_restore")

func _status(f: Fleet) -> String:
	if f.in_combat:
		return tr("NAVY_IN_COMBAT")
	if f.returning:
		return tr("NAVY_RETURNING")
	var p := World.province(f.location)
	if p.is_land():
		return tr("NAVY_LOCATION_PORT") % (p.city.display_name() if p.city else "#%d" % p.id)
	return tr("NAVY_LOCATION_SEA") % Navy.zone_name(Navy.sea_for(f.location))
