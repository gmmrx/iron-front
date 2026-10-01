class_name AirPanel
extends PanelContainer
## Hava Kuvvetleri (H): önce bölge, sonra görev — panel açıkken haritada bir bölgeye tıklanır, panelin başındaki
## "Hedef" bölümünde menzildeki her kanada oradan görev verilir (üstünlük, yakın destek, bombardıman; kanadın üssü
## yetmiyorsa bölgeye en yakın, menzili yeten kendi üssüne geçer). Altta kanat kartları: görev, bölge seçimi, otomatik
## (AI) mod, takviye, dağıtma. Konuşlandırma stoktaki uçakları başkente en yakın hava üssünde kanat yapar.

signal pick_zone_requested(wing: AirWing)
## Konuşlandır: panel kapanır, haritada hava üslü eyaletler vurgulanır, oyuncu üssü seçer (main._begin_place)
signal deploy_requested(type: String)

const TYPE_ICON := {"fighter": "equipment_fighter_equipment", "cas": "equipment_cas_equipment", "bomber": "equipment_tactical_bomber_equipment"}
const MISSION_ICON := ["building_air_base", "equipment_fighter_equipment", "equipment_cas_equipment", "building_naval_base",
	"building_military_factory", "tech_radar_1"]
## Hedef bölümünde verilen görevler (sıra düğme sırası)
const TARGET_MISSIONS: Array[AirWing.Mission] = [AirWing.Mission.SUPERIORITY, AirWing.Mission.CAS, AirWing.Mission.BOMBING,
	AirWing.Mission.RECON]

var selected_id := 0
var target_zone := 0                ## haritada seçilen hedef bölge (0: yok)
var _cells: Array[Label] = []
var _deploy_type: OptionButton
var _deploy_btn: Button
var _list: VBoxContainer
var _pending := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_list = PanelLayout.frame(self, tr("AIR_TITLE"), "air", 500.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["equipment_fighter_equipment", tr("WING_TYPE_fighter"), tr("AIR_CELL_TIP")],
		["equipment_cas_equipment", tr("WING_TYPE_cas"), tr("AIR_CELL_TIP")],
		["equipment_tactical_bomber_equipment", tr("WING_TYPE_bomber"), tr("AIR_CELL_TIP")]])
	PanelLayout.section(top, tr("AIR_DEPLOY_HEAD"))
	# konuşlandırma satırı
	var dep := HBoxContainer.new()
	dep.add_theme_constant_override("separation", 6)
	_deploy_type = OptionButton.new()
	_deploy_type.tooltip_text = tr("TIP_AIR_DEPLOY_TYPE")
	_deploy_type.focus_mode = Control.FOCUS_NONE
	_deploy_type.custom_minimum_size.x = 150
	_deploy_type.add_theme_constant_override("icon_max_width", 22)
	_deploy_type.expand_icon = true
	_deploy_type.clip_text = true
	dep.add_child(_deploy_type)
	_deploy_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_btn = Button.new()
	_deploy_btn.text = tr("AIR_DEPLOY")
	_deploy_btn.tooltip_text = tr("TIP_AIR_DEPLOY")
	_deploy_btn.focus_mode = Control.FOCUS_NONE
	_deploy_btn.pressed.connect(_on_deploy)
	dep.add_child(_deploy_btn)
	top.add_child(dep)
	Air.wings_changed.connect(_queue_refresh)
	World.daily_update.connect(_queue_refresh)

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

## Haritada tıklanan bölge hedef olur (main: hava paneli açıkken sol tık)
func set_target(pid: int) -> void:
	var p := World.province(pid)
	target_zone = pid if p != null and p.type != Province.Type.LAKE else 0
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
	for k in 3:
		var t: String = ["fighter", "cas", "bomber"][k]
		_cells[k].text = "%d  ·  %s %d" % [Air.planes(c.tag, t), tr("AIR_IN_STOCK"), int(c.stockpile.get(Air.TYPES[t]["eq"], 0.0))]
	# konuşlandırma seçenekleri
	var prev_t: Variant = _deploy_type.get_selected_metadata() if _deploy_type.item_count > 0 else null
	_deploy_type.clear()
	for t: String in Air.TYPES:
		var n := int(c.stockpile.get(Air.TYPES[t]["eq"], 0.0))
		_deploy_type.add_icon_item(UiTheme.icon(TYPE_ICON[t]), "%s (%d)" % [tr("WING_TYPE_" + t), n])
		_deploy_type.set_item_metadata(_deploy_type.item_count - 1, t)
		_deploy_type.get_popup().set_item_icon_max_width(_deploy_type.item_count - 1, 24)
		if prev_t == t:
			_deploy_type.select(_deploy_type.item_count - 1)
	var t_sel: String = _deploy_type.get_selected_metadata() if _deploy_type.item_count > 0 else ""
	_deploy_btn.disabled = Air.bases_of(c.tag).is_empty() or t_sel == "" or int(c.stockpile.get(Air.TYPES[t_sel]["eq"], 0.0)) <= 0
	for ch in _list.get_children():
		ch.queue_free()
	var own := Air.wings_of(c.tag)
	_build_target(c, own)
	PanelLayout.section(_list, tr("AIR_WINGS") % own.size())
	if own.is_empty():
		PanelLayout.empty(_list, tr("AIR_NO_WINGS"))
		return
	for w in own:
		_list.add_child(_card(w))

## Konuşlandır: stoktaki uçaklar başkente en yakın hava üssünde kanat olur (üs haritada seçilmez; görev verilince kanat
## menzile göre üs değiştirir)
func _on_deploy() -> void:
	if _deploy_type.item_count == 0:
		return
	var c := World.player()
	var base := Air._home_base(c.tag)
	var w := Air.deploy(c, String(_deploy_type.get_selected_metadata()), base)
	if w == null:
		World.notify(tr("PLACE_NONE"), "bad")
		return
	selected_id = w.id
	var st: StateRegion = World.states.get(base)
	World.notify(tr("AIR_DEPLOYED") % [w.name, st.display_name() if st else "—"], "info")
	refresh()

## Hedef bölümü: seçilen bölge, oradaki hava üstünlüğümüz ve (düşman eyaletiyse) bombardıman hasarı; her kanat için
## görev düğmeleri. Bölge seçilmemişse ne yapılacağını söyleyen tek satır.
func _build_target(c: Country, own: Array[AirWing]) -> void:
	if target_zone == 0:
		PanelLayout.empty(_list, tr("AIR_TARGET_HINT"))
		return
	PanelLayout.section(_list, tr("AIR_TARGET") % Air.zone_name(target_zone))
	var info := tr("AIR_TARGET_SUP") % roundi(Air.superiority(target_zone, c.tag) * 100.0)
	var st := World.state_of_province(target_zone)
	if st and Diplomacy.are_enemies(st.owner, c.tag):
		info += "   ·   " + tr("AIR_TARGET_DAMAGE") % roundi(st.damage * 100.0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var il := UiTheme.make_label(info, 14, UiTheme.TEXT_DIM)
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(il)
	head.add_child(PanelLayout.small_button(tr("AIR_TARGET_CLEAR"), func() -> void: set_target(0), true, tr("TIP_AIR_TARGET_CLEAR")))
	_list.add_child(head)
	if own.is_empty():
		PanelLayout.empty(_list, tr("AIR_NO_WINGS"))
		return
	for w in own:
		var here := w.on_mission() and w.zone == target_zone
		var reach := Air.in_range(w, target_zone) or Air.base_for(w, target_zone) != 0
		var sub := tr("AIR_TARGET_HERE") % tr("AIR_MISSION_%d" % int(w.mission)) if here else \
			(tr("AIR_TARGET_PLANES") % w.planes if reach else tr("AIR_ERR_RANGE"))
		var col := PanelLayout.row(_list, UiTheme.icon(TYPE_ICON[w.type]), w.name, sub, "", "SlotGold" if here else "Row")
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 4)
		for m: AirWing.Mission in TARGET_MISSIONS:
			var why := ""
			if not reach:
				why = tr("AIR_ERR_RANGE")
			elif m == AirWing.Mission.BOMBING:
				var err := Air.bomb_target_error(w, target_zone)
				why = tr(err) if err != "" else ""
			var b := PanelLayout.small_button(tr("AIR_MISSION_%d" % int(m)), func() -> void:
				var e := Air.assign(w, target_zone, m)
				if e == "":
					Audio.play("select_air", 150)
					World.notify(tr("AIR_ORDER_OK") % [w.name, tr("AIR_MISSION_%d" % int(m)), Air.zone_name(w.zone)], "info")
				else:
					World.notify(tr(e), "bad")
				selected_id = w.id
				refresh(), why == "", why if why != "" else tr("TIP_AIR_MISSION_%d" % int(m)))
			btns.add_child(b)
		PanelLayout.row_action(col, btns)

## Kanat kartı (filo kartıyla aynı düzen): başlık (yuva, ad, üs · bölge), uçak çubuğu, görev şeridi, altta otomatik ve
## eylemler. Seçili kart altın çerçeveli, adı altın; tıklayınca seçilir
func _card(w: AirWing) -> Control:
	var sel := w.id == selected_id
	var panel := PanelContainer.new()
	panel.theme_type_variation = "SlotGold" if sel else "Row"
	UiTheme.pad(panel, 14, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			selected_id = w.id
			refresh())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var st: StateRegion = World.states.get(w.base)
	var head := PanelLayout.card_head(v, UiTheme.icon(TYPE_ICON[w.type]), w.name,
		tr("AIR_BASE") % (st.display_name() if st else "—") + "   ·   " + tr("AIR_ZONE") % Air.zone_name(w.zone), sel)
	head.tooltip_text = tr("TIP_WING_STATS") % [tr("WING_TYPE_" + w.type), w.planes, Air.WING_SIZE, roundi(Air.TYPES[w.type]["range"]), roundi(w.losses_today)]
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	var full := float(w.planes) / float(Air.WING_SIZE)
	PanelLayout.bar_row(v, tr("WING_TYPE_" + w.type), full, "%d / %d" % [w.planes, Air.WING_SIZE],
		Color(0.45, 0.85, 0.35) if full >= 0.7 else UiTheme.BAD, head.tooltip_text)
	# görev
	var items: Array = []
	for m in MISSION_ICON.size():
		items.append([MISSION_ICON[m], tr("AIR_MISSION_%d" % m), tr("TIP_AIR_MISSION_%d" % m)])
	PanelLayout.choice_row(v, items, int(w.mission), func(m: int) -> void:
		w.auto = false
		selected_id = w.id
		if m == 0:
			Air.set_mission(w, AirWing.Mission.IDLE)
		elif w.zone > 0:
			if not Air.set_mission(w, m as AirWing.Mission, w.zone):
				var err := Air.bomb_target_error(w, w.zone) if m == AirWing.Mission.BOMBING else "AIR_ERR_RANGE"
				World.notify(tr(err if err != "" else "AIR_ERR_RANGE"), "bad")
		else:
			w.mission = m as AirWing.Mission
			pick_zone_requested.emit(w)
		refresh())
	# alt satır: otomatik (oyuncu açarsa) · bölge seç · takviye · (ayrı) dağıt
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var auto := CheckBox.new()
	auto.text = tr("AIR_AUTO")
	auto.tooltip_text = tr("TIP_AIR_AUTO")
	auto.focus_mode = Control.FOCUS_NONE
	auto.button_pressed = w.auto
	auto.add_theme_font_size_override("font_size", UiTheme.fs(14))
	auto.toggled.connect(func(on: bool) -> void: w.auto = on)
	row.add_child(auto)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var pick := PanelLayout.small_button(tr("AIR_PICK_ZONE"), func() -> void:
		selected_id = w.id
		pick_zone_requested.emit(w), true, tr("TIP_AIR_PICK_ZONE"))
	var rein := PanelLayout.small_button(tr("AIR_REINFORCE"), func() -> void: Air.reinforce(w), true, tr("TIP_AIR_REINFORCE"))
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	var dis := PanelLayout.small_button(tr("AIR_DISBAND"), func() -> void: Air.disband(w), true, tr("TIP_AIR_DISBAND"))
	dis.add_theme_color_override("font_color", UiTheme.BAD.lightened(0.25))
	for b: Control in [pick, rein, gap, dis]:
		if b is Button:
			b.custom_minimum_size = Vector2(0, 36)
		row.add_child(b)
	v.add_child(row)
	return panel
