class_name NavyPanel
extends PanelContainer
## Donanma (N): filolar, bileşim, organizasyon, görev ve görev bölgesi. Haritada filo seçimiyle eşgüdümlü.

signal fleet_selected(fleet: Fleet)
signal pick_zone_requested(fleet: Fleet)

const MISSION_ICONS := ["building_naval_base", "equipment_battleship", "equipment_submarine", "equipment_convoy"]

var selected_id := 0
var _summary: Label
var _list: VBoxContainer
var _pending := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(470, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("NAVY_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 16, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	v.add_child(scroll)
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
	_summary.text = tr("NAVY_SUMMARY") % [roundi(Navy.power(c.tag)), roundi(float(c.stockpile.get("convoy", 0.0)))]
	var cf := Economy.convoy_factor(c)
	if cf < 0.999:
		_summary.text += "\n" + tr("NAVY_CONVOY_FACTOR") % roundi(cf * 100.0)
	for ch in _list.get_children():
		ch.queue_free()
	var own := Navy.fleets_of(c.tag)
	if own.is_empty():
		var l := UiTheme.make_label(tr("NAVY_NO_FLEETS"), 16, UiTheme.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(l)
		return
	for f in own:
		_list.add_child(_card(f))

func _card(f: Fleet) -> Control:
	var sel := f.id == selected_id
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_style(Color(1, 1, 1, 0.08 if sel else 0.035), UiTheme.ACCENT if sel else UiTheme.BORDER_DIM, 2 if sel else 1)
	sb.shadow_size = 0
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = tr("TIP_FLEET_CARD")
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			selected_id = f.id
			fleet_selected.emit(f)
			refresh())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)

	# başlık: ad + durum
	var head := HBoxContainer.new()
	var name := UiTheme.make_label(f.name, 18, UiTheme.ACCENT)
	name.add_theme_font_override("font", UiTheme.bold_font())
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var status := UiTheme.make_label(_status(f), 14, UiTheme.BAD if f.in_combat or f.returning else UiTheme.TEXT_DIM)
	head.add_child(status)
	v.add_child(head)

	# bileşim
	var comp := HBoxContainer.new()
	comp.add_theme_constant_override("separation", 12)
	for t: String in Navy.SHIP_TYPES:
		var n := int(f.ships.get(t, 0))
		if n <= 0:
			continue
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		var st: Dictionary = Navy.SHIPS[t]
		box.tooltip_text = tr("TIP_SHIP_TYPE") % [tr("SHIPS_" + t), n, st["atk"], st["hp"], roundi(st["speed"])]
		var ic := UiTheme.icon_texture(UiTheme.equipment_icon(t), 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)
		var l := UiTheme.make_label("%d" % n, 16)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		comp.add_child(box)
	v.add_child(comp)

	# organizasyon
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = f.org
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	bar.tooltip_text = "%s: %d%%" % [tr("NAVY_ORG"), roundi(f.org * 100.0)]
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.85, 0.35) if f.org > 0.5 else UiTheme.BAD
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)

	# görevler
	var missions := HBoxContainer.new()
	missions.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for m in 4:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.icon = UiTheme.icon(MISSION_ICONS[m])
		b.add_theme_constant_override("icon_max_width", 20)
		b.text = tr("MISSION_%d" % m)
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = tr("TIP_MISSION_%d" % m)
		b.button_pressed = int(f.mission) == m
		b.custom_minimum_size = Vector2(0, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			f.returning = false
			Navy.set_mission(f, m as Fleet.Mission)
			selected_id = f.id
			fleet_selected.emit(f)
			refresh())
		missions.add_child(b)
	v.add_child(missions)

	# görev bölgesi
	var zrow := HBoxContainer.new()
	var zl := UiTheme.make_label(tr("NAVY_ZONE") % Navy.zone_name(f.zone_center), 15, UiTheme.TEXT)
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zrow.add_child(zl)
	var pick := Button.new()
	pick.text = tr("NAVY_PICK_ZONE")
	pick.focus_mode = Control.FOCUS_NONE
	pick.tooltip_text = tr("TIP_NAVY_PICK_ZONE")
	pick.add_theme_font_size_override("font_size", 14)
	pick.pressed.connect(func() -> void:
		selected_id = f.id
		fleet_selected.emit(f)
		pick_zone_requested.emit(f))
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
