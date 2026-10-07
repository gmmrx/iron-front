class_name AirPanel
extends PanelContainer
## Hava Kuvvetleri (H): önce bölge, sonra görev — panel açıkken haritada bir bölgeye tıklanır, panelin başındaki
## "Hedef" bölümünde menzildeki her kanada oradan görev verilir (üstünlük, yakın destek, bombardıman; kanadın üssü
## yetmiyorsa bölgeye en yakın, menzili yeten kendi üssüne geçer). Altta kanat kartları: görev, bölge seçimi, otomatik
## (AI) mod, takviye, dağıtma. Konuşlandırma stoktaki uçakları başkente en yakın hava üssünde kanat yapar.

signal pick_zone_requested(wing: AirWing)
signal wing_selected(wing: AirWing) ## UI selection only; never a mission/transfer request.
## Konuşlandır: panel kapanır, haritada hava üslü eyaletler vurgulanır, oyuncu üssü seçer (main._begin_place)
signal deploy_requested(type: String)

const TYPE_ICON := {"fighter": "equipment_fighter_equipment", "cas": "equipment_cas_equipment", "bomber": "equipment_tactical_bomber_equipment"}
const SelectionCard := preload("res://game/ui/force_selection_card.gd")
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
var _cards := {}                ## live own wing id -> explicit selection card
var _target_cards := {}         ## same wing selection mirrored in the target-order section
var _clear_selection_button: Button
var _grid: GridContainer
var _target_grid: GridContainer
var _details: VBoxContainer
var _target_details: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_list = PanelLayout.frame(self, tr("AIR_TITLE"), "air", 500.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["equipment_fighter_equipment", tr("WING_TYPE_fighter"), tr("AIR_CELL_TIP")],
		["equipment_cas_equipment", tr("WING_TYPE_cas"), tr("AIR_CELL_TIP")],
		["equipment_tactical_bomber_equipment", tr("WING_TYPE_bomber"), tr("AIR_CELL_TIP")]])
	_clear_selection_button = PanelLayout.small_button(tr("FORCE_CLEAR_SELECTION"), clear_selection, false)
	_clear_selection_button.set_meta("audio_silent", true)
	_clear_selection_button.name = "ClearWingSelection"
	_clear_selection_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(_clear_selection_button)
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
	World.player_changed.connect(func(_tag: String) -> void:
		_prune_selection()
		_queue_refresh())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func select(w: AirWing) -> void:
	selected_id = w.id if w != null and _owned_wing(w.id) == w else 0
	_sync_cards()

func clear_selection(audible := true) -> void:
	if selected_id == 0: return
	selected_id = 0
	_sync_cards()
	wing_selected.emit(null)
	if audible: Audio.play("unit_deselect")

func _owned_wing(id: int) -> AirWing:
	var c := World.player()
	if c == null: return null
	for w: AirWing in Air.wings:
		if w.id == id and w.owner == c.tag: return w
	return null

func _toggle_wing(id: int) -> void:
	var w := _owned_wing(id)
	if w == null:
		_prune_selection()
		return
	selected_id = 0 if selected_id == id else id
	_sync_cards()
	wing_selected.emit(w if selected_id != 0 else null)
	Audio.play("select_air" if selected_id != 0 else "unit_deselect", 120)

func _sync_cards() -> void:
	for collection: Dictionary in [_cards, _target_cards]:
		for id: int in collection:
			var card: SelectionCard = collection[id]
			if is_instance_valid(card): card.set_selected(id == selected_id)
	if is_instance_valid(_clear_selection_button): _clear_selection_button.disabled = selected_id == 0
	_rebuild_details()

func _prune_selection() -> void:
	if selected_id != 0 and _owned_wing(selected_id) == null: clear_selection(false)

## Haritada tıklanan bölge hedef olur (main: hava paneli açıkken sol tık)
func set_target(pid: int) -> void:
	var p := World.province(pid)
	target_zone = pid if p != null and p.type != Province.Type.LAKE else 0
	refresh()

func _queue_refresh() -> void:
	_prune_selection()
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
		_list.remove_child(ch)
		ch.queue_free()
	_cards.clear()
	_target_cards.clear()
	_grid = null
	_target_grid = null
	_details = null
	_target_details = null
	var own := Air.wings_of(c.tag)
	_build_target(c, own)
	PanelLayout.section(_list, tr("AIR_WINGS") % own.size())
	if own.is_empty():
		PanelLayout.empty(_list, tr("AIR_NO_WINGS"))
		_restore_list_scroll()
		return
	_grid = PanelLayout.grid(2)
	_grid.name = "AirRosterGrid"
	_list.add_child(_grid)
	for w in own:
		_grid.add_child(_card(w))
	_details = VBoxContainer.new()
	_details.name = "SelectedWingDetails"
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_details)
	_sync_cards()
	_restore_list_scroll()
	PanelLayout.queue_fit(self)

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
	select(w) # Preserve the existing newly-deployed wing selection behavior.
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
	_target_grid = PanelLayout.grid(2)
	_target_grid.name = "AirTargetGrid"
	_list.add_child(_target_grid)
	for w in own:
		var here := w.on_mission() and w.zone == target_zone
		var reach := Air.in_range(w, target_zone) or Air.base_for(w, target_zone) != 0
		var sub := tr("AIR_TARGET_HERE") % tr("AIR_MISSION_%d" % int(w.mission)) if here else \
			(tr("AIR_TARGET_PLANES") % w.planes if reach else tr("AIR_ERR_RANGE"))
		var card := SelectionCard.new()
		card.set_compact()
		card.name = "TargetWingSelection_%d" % w.id
		card.set_meta("wing_id", w.id)
		card.configure(w.name, sub, UiTheme.icon(TYPE_ICON[w.type]), w.id == selected_id)
		card.selection_requested.connect(func() -> void: _toggle_wing(w.id))
		if here: card.subtitle_label.add_theme_color_override("font_color", UiTheme.GOOD)
		_target_cards[w.id] = card
		_target_grid.add_child(card)
		_compact_strength(card.content, w, card.select_button.tooltip_text)
	_target_details = VBoxContainer.new()
	_target_details.name = "SelectedTargetDetails"
	_target_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_target_details)

## Kanat kartı (filo kartıyla aynı düzen): başlık (yuva, ad, üs · bölge), uçak çubuğu, görev şeridi, altta otomatik ve
## eylemler. Seçili kart altın çerçeveli, adı altın; tıklayınca seçilir
func _card(w: AirWing) -> Control:
	var sel := w.id == selected_id
	var st: StateRegion = World.states.get(w.base)
	var panel := SelectionCard.new()
	panel.set_compact()
	panel.name = "WingSelection_%d" % w.id
	panel.set_meta("wing_id", w.id)
	panel.configure(w.name, tr("AIR_MISSION_%d" % int(w.mission)), UiTheme.icon(TYPE_ICON[w.type]), sel)
	panel.select_button.tooltip_text += "\n" + tr("AIR_BASE") % (st.display_name() if st else "—") + "\n" + tr("AIR_ZONE") % Air.zone_name(w.zone)
	panel.select_button.tooltip_text += "\n" + tr("TIP_WING_STATS") % [tr("WING_TYPE_" + w.type), w.planes, Air.WING_SIZE, roundi(Air.TYPES[w.type]["range"]), roundi(w.losses_today)]
	panel.selection_requested.connect(func() -> void: _toggle_wing(w.id))
	_cards[w.id] = panel
	_compact_strength(panel.content, w, panel.select_button.tooltip_text)
	return panel

func _compact_strength(parent: Container, w: AirWing, tip: String) -> void:
	var count := UiTheme.make_label(tr("AIR_TARGET_PLANES") % w.planes + " / %d" % Air.WING_SIZE, 13, UiTheme.TEXT)
	count.tooltip_text = tip
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(count)
	var full := float(w.planes) / float(Air.WING_SIZE)
	parent.add_child(PanelLayout.progress(full, UiTheme.GOOD if full >= 0.7 else UiTheme.BAD, 4))

func _rebuild_details() -> void:
	if not is_instance_valid(_details): return
	_remember_scroll()
	_clear_details(_details)
	if is_instance_valid(_target_details): _clear_details(_target_details)
	var w := _owned_wing(selected_id)
	if w == null:
		PanelLayout.empty(_details, tr("FORCE_SELECT_HINT"))
		if is_instance_valid(_target_details): PanelLayout.empty(_target_details, tr("FORCE_SELECT_HINT"))
	else:
		var v := _detail_box(_details, w, "SelectedWingOperations")
		_build_operations(v, w)
		if is_instance_valid(_target_details):
			var target := _detail_box(_target_details, w, "SelectedTargetOrders")
			_build_target_orders(target, w)
	_restore_list_scroll()
	PanelLayout.queue_fit(self)

func _detail_box(parent: Container, w: AirWing, node_name: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_meta("selection_detail", true)
	panel.set_meta("selected_id", w.id)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 10))
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := UiTheme.make_label(w.name + " · " + tr("FORCE_OPERATIONS"), 17, UiTheme.ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	return v

func _build_target_orders(parent: Container, w: AirWing) -> void:
	var pid := target_zone
	var reach := Air.in_range(w, pid) or Air.base_for(w, pid) != 0
	var btns := GridContainer.new()
	btns.columns = 2
	btns.add_theme_constant_override("h_separation", 6)
	btns.add_theme_constant_override("v_separation", 6)
	parent.add_child(btns)
	for m: AirWing.Mission in TARGET_MISSIONS:
		var why := ""
		if not reach:
			why = tr("AIR_ERR_RANGE")
		elif m == AirWing.Mission.BOMBING:
			var err := Air.bomb_target_error(w, pid)
			why = tr(err) if err != "" else ""
		var b := PanelLayout.small_button(tr("AIR_MISSION_%d" % int(m)), func() -> void:
			if _owned_wing(w.id) != w or selected_id != w.id or pid != target_zone: return
			var e := Air.assign(w, pid, m)
			if e == "":
				Audio.play("select_air", 150)
				World.notify(tr("AIR_ORDER_OK") % [w.name, tr("AIR_MISSION_%d" % int(m)), Air.zone_name(w.zone)], "info")
			else:
				World.notify(tr(e), "bad")
			refresh(), why == "", why if why != "" else tr("TIP_AIR_MISSION_%d" % int(m)))
		b.set_meta("audio_silent", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(b)

func _build_operations(v: VBoxContainer, w: AirWing) -> void:
	var st: StateRegion = World.states.get(w.base)
	PanelLayout.detail(v, tr("AIR_BASE") % (st.display_name() if st else "—") + " · " + tr("AIR_ZONE") % Air.zone_name(w.zone), 14)
	# görev
	var items: Array = []
	for m in MISSION_ICON.size():
		items.append([MISSION_ICON[m], tr("AIR_MISSION_%d" % m), tr("TIP_AIR_MISSION_%d" % m)])
	var choices := PanelLayout.choice_row(v, items, int(w.mission), func(m: int) -> void:
		if _owned_wing(w.id) != w or selected_id != w.id: return
		w.auto = false
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
	# Keep all six real missions readable; a long six-button strip clips names.
	var missions := GridContainer.new()
	missions.name = "WingMissionChoices"
	missions.columns = 2
	missions.add_theme_constant_override("h_separation", 6)
	missions.add_theme_constant_override("v_separation", 6)
	v.add_child(missions)
	for child: Node in choices.get_children():
		choices.remove_child(child)
		missions.add_child(child)
	v.remove_child(choices)
	choices.queue_free()
	# alt satır: otomatik (oyuncu açarsa) · bölge seç · takviye · (ayrı) dağıt
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var auto := CheckBox.new()
	auto.text = tr("AIR_AUTO")
	auto.tooltip_text = tr("TIP_AIR_AUTO")
	auto.focus_mode = Control.FOCUS_NONE
	auto.button_pressed = w.auto
	auto.add_theme_font_size_override("font_size", UiTheme.fs(14))
	auto.toggled.connect(func(on: bool) -> void:
		if _owned_wing(w.id) == w and selected_id == w.id: w.auto = on)
	row.add_child(auto)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var pick := PanelLayout.small_button(tr("AIR_PICK_ZONE"), func() -> void:
		if _owned_wing(w.id) != w or selected_id != w.id: return
		pick_zone_requested.emit(w), true, tr("TIP_AIR_PICK_ZONE"))
	var rein := PanelLayout.small_button(tr("AIR_REINFORCE"), func() -> void:
		if _owned_wing(w.id) == w and selected_id == w.id: Air.reinforce(w), true, tr("TIP_AIR_REINFORCE"))
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	var dis := PanelLayout.small_button(tr("AIR_DISBAND"), func() -> void:
		if _owned_wing(w.id) == w and selected_id == w.id: Air.disband(w), true, tr("TIP_AIR_DISBAND"))
	dis.add_theme_color_override("font_color", UiTheme.BAD.lightened(0.25))
	for b: Control in [pick, rein, gap, dis]:
		if b is Button:
			b.custom_minimum_size = Vector2(0, 36)
		row.add_child(b)
	v.add_child(row)

static func _clear_details(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

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
