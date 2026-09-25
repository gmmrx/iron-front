class_name AirPanel
extends PanelContainer
## Hava Kuvvetleri (H): stoktaki uçakları üslere kanat olarak konuşlandırma (türün klasiklerindeki gibi elle), kanat görevleri,
## görev bölgesi seçimi, otomatik (AI) mod, takviye ve dağıtma.

signal pick_zone_requested(wing: AirWing)

const TYPE_ICON := {"fighter": "equipment_fighter_equipment", "cas": "equipment_cas_equipment", "bomber": "equipment_tactical_bomber_equipment"}
const MISSION_ICON := ["building_air_base", "equipment_fighter_equipment", "equipment_cas_equipment", "building_naval_base"]

var selected_id := 0
var _summary: Label
var _deploy_type: OptionButton
var _deploy_base: OptionButton
var _deploy_btn: Button
var _list: VBoxContainer
var _pending := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(480, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("AIR_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 16, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	# konuşlandırma satırı
	var dep := HBoxContainer.new()
	dep.add_theme_constant_override("separation", 6)
	_deploy_type = OptionButton.new()
	_deploy_type.tooltip_text = tr("TIP_AIR_DEPLOY_TYPE")
	_deploy_type.focus_mode = Control.FOCUS_NONE
	_deploy_type.custom_minimum_size.x = 150
	dep.add_child(_deploy_type)
	_deploy_base = OptionButton.new()
	_deploy_base.tooltip_text = tr("TIP_AIR_DEPLOY_BASE")
	_deploy_base.focus_mode = Control.FOCUS_NONE
	_deploy_base.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_base.clip_text = true
	dep.add_child(_deploy_base)
	_deploy_btn = Button.new()
	_deploy_btn.text = tr("AIR_DEPLOY")
	_deploy_btn.tooltip_text = tr("TIP_AIR_DEPLOY")
	_deploy_btn.focus_mode = Control.FOCUS_NONE
	_deploy_btn.pressed.connect(_on_deploy)
	dep.add_child(_deploy_btn)
	v.add_child(dep)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	v.add_child(scroll)
	Air.wings_changed.connect(_queue_refresh)
	World.daily_update.connect(_queue_refresh)

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func _queue_refresh() -> void:
	if visible and not _pending:
		_pending = true
		refresh.call_deferred()

func refresh() -> void:
	_pending = false
	var c := World.player()
	if c == null:
		return
	_summary.text = tr("AIR_SUMMARY") % [Air.planes(c.tag, "fighter"), Air.planes(c.tag, "cas"), Air.planes(c.tag, "bomber")]
	_summary.text += "\n" + tr("AIR_STOCK") % [int(c.stockpile.get("fighter_equipment", 0.0)), int(c.stockpile.get("cas_equipment", 0.0)), int(c.stockpile.get("tactical_bomber_equipment", 0.0))]
	# konuşlandırma seçenekleri
	var prev_t: Variant = _deploy_type.get_selected_metadata() if _deploy_type.item_count > 0 else null
	_deploy_type.clear()
	for t: String in Air.TYPES:
		var n := int(c.stockpile.get(Air.TYPES[t]["eq"], 0.0))
		_deploy_type.add_icon_item(UiTheme.icon(TYPE_ICON[t]), "%s (%d)" % [tr("WING_TYPE_" + t), n])
		_deploy_type.set_item_metadata(_deploy_type.item_count - 1, t)
		if prev_t == t:
			_deploy_type.select(_deploy_type.item_count - 1)
	var prev_b: Variant = _deploy_base.get_selected_metadata() if _deploy_base.item_count > 0 else null
	_deploy_base.clear()
	for sid in Air.bases_of(c.tag):
		var st: StateRegion = World.states[sid]
		_deploy_base.add_item("%s (%d)" % [st.display_name(), st.building_level("air_base")])
		_deploy_base.set_item_metadata(_deploy_base.item_count - 1, sid)
		if prev_b == sid:
			_deploy_base.select(_deploy_base.item_count - 1)
	var t_sel: String = _deploy_type.get_selected_metadata() if _deploy_type.item_count > 0 else ""
	_deploy_btn.disabled = _deploy_base.item_count == 0 or t_sel == "" or int(c.stockpile.get(Air.TYPES[t_sel]["eq"], 0.0)) <= 0
	for ch in _list.get_children():
		ch.queue_free()
	var own := Air.wings_of(c.tag)
	if own.is_empty():
		var l := UiTheme.make_label(tr("AIR_NO_WINGS"), 16, UiTheme.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(l)
		return
	for w in own:
		_list.add_child(_card(w))

func _on_deploy() -> void:
	var c := World.player()
	if _deploy_type.item_count == 0 or _deploy_base.item_count == 0:
		return
	var w := Air.deploy(c, _deploy_type.get_selected_metadata(), _deploy_base.get_selected_metadata())
	if w:
		selected_id = w.id
	refresh()

func _card(w: AirWing) -> Control:
	var sel := w.id == selected_id
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_style(Color(1, 1, 1, 0.08 if sel else 0.035), UiTheme.ACCENT if sel else UiTheme.BORDER_DIM, 2 if sel else 1)
	sb.shadow_size = 0
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var ic := UiTheme.icon_texture(UiTheme.icon(TYPE_ICON[w.type]), 26)
	head.add_child(ic)
	var name := UiTheme.make_label(w.name, 18, UiTheme.ACCENT)
	name.add_theme_font_override("font", UiTheme.bold_font())
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.mouse_filter = Control.MOUSE_FILTER_STOP
	name.tooltip_text = tr("TIP_WING_STATS") % [tr("WING_TYPE_" + w.type), w.planes, Air.WING_SIZE, roundi(Air.TYPES[w.type]["range"]), roundi(w.losses_today)]
	head.add_child(name)
	var count := UiTheme.make_label("%d / %d" % [w.planes, Air.WING_SIZE], 16, UiTheme.TEXT if w.planes >= Air.WING_SIZE * 0.7 else UiTheme.BAD)
	head.add_child(count)
	v.add_child(head)
	var st: StateRegion = World.states.get(w.base)
	var info := UiTheme.make_label(tr("AIR_BASE") % (st.display_name() if st else "—") + "   ·   " + tr("AIR_ZONE") % Air.zone_name(w.zone), 14, UiTheme.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	# görevler
	var ms := HBoxContainer.new()
	ms.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for m in 4:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.icon = UiTheme.icon(MISSION_ICON[m])
		b.add_theme_constant_override("icon_max_width", 18)
		b.text = tr("AIR_MISSION_%d" % m)
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = tr("TIP_AIR_MISSION_%d" % m)
		b.button_pressed = int(w.mission) == m
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			w.auto = false
			selected_id = w.id
			if m == 0:
				Air.set_mission(w, AirWing.Mission.IDLE)
			elif w.zone > 0:
				Air.set_mission(w, m as AirWing.Mission, w.zone)
			else:
				w.mission = m as AirWing.Mission
				pick_zone_requested.emit(w)
			refresh())
		ms.add_child(b)
	v.add_child(ms)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var auto := CheckBox.new()
	auto.text = tr("AIR_AUTO")
	auto.tooltip_text = tr("TIP_AIR_AUTO")
	auto.focus_mode = Control.FOCUS_NONE
	auto.button_pressed = w.auto
	auto.toggled.connect(func(on: bool) -> void: w.auto = on)
	row.add_child(auto)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	for spec: Array in [["AIR_PICK_ZONE", "TIP_AIR_PICK_ZONE", func() -> void:
			selected_id = w.id
			pick_zone_requested.emit(w)],
			["AIR_REINFORCE", "TIP_AIR_REINFORCE", func() -> void: Air.reinforce(w)],
			["AIR_DISBAND", "TIP_AIR_DISBAND", func() -> void: Air.disband(w)]]:
		var b := Button.new()
		b.text = tr(spec[0])
		b.tooltip_text = tr(spec[1])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(spec[2])
		row.add_child(b)
	v.add_child(row)
	return panel
