class_name ArmyPanel
extends PanelContainer
## Konuşlandır: panel kapanır, haritada uygun bölgeler vurgulanır, oyuncu yeri seçer (main._begin_place)
signal deploy_requested(template: int)
## Ordu (U), iki sekme:
## - Komuta zinciri: ordular grubu (mareşal) → ordu (general) → tümen ağacı; seçili düğümün ayrıntısı (komutan,
##   cephe, duruş, bağlı tümenler, tümen aktarma) ve komutan kadrosu (atama, mareşalliğe terfi, yeni general).
## - Tümen şablonları: şablon listesi, tabur tasarımcısı, konuşlandırma.
## Her karar oyuncunundur: oyuncunun ordularına kendiliğinden komutan atanmaz, tümen aktarılmaz.

var units: UnitLayer              ## "haritada seç" için (main bağlar)
var _cells: Array[Label] = []
var _body: VBoxContainer          ## bölümlerin eklendiği sütun (refresh sırasında değişir)
var _root: VBoxContainer
var _edit := -1
var _tab := 0                     ## 0 komuta zinciri, 1 şablonlar
var _sel := ""                    ## "a:ID" ordu, "g:ID" ordular grubu, "free" bağlanmamış tümenler
var _pending := false
var _popup_open := false          ## açılır liste açıkken günlük yenileme listeyi kapatmasın
var _portrait_map: Dictionary = {}
var _portrait_map_loaded := false
var _portrait_textures: Dictionary = {}
var _selection_cards: Array[Dictionary] = []
var _selection_timer := 0.0
var _selection_key := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_root = PanelLayout.frame(self, tr("ARMY_TITLE"), "army", -1.0)     # tam ekran
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["army", tr("ARM_CELL_DIVS"), tr("ARM_CELL_DIVS_TIP")],
		["command_power", tr("ARM_CELL_CP"), tr("ARM_CELL_CP_TIP")],
		["manpower", tr("LOG_CELL_MANPOWER"), tr("LOG_CELL_MANPOWER_TIP")],
		["equipment_infantry_equipment", tr("ARM_CELL_INF"), tr("ARM_CELL_INF_TIP")]])
	World.daily_update.connect(func() -> void:
		if visible and not _popup_open and World.day_count % 2 == 0: _queue_refresh())
	Military.armies_changed.connect(func() -> void:
		if visible: _queue_refresh())

func open() -> void:
	visible = true
	refresh()

## Bir orduyu seçili açar (seçili tümen panelindeki "Yönet")
func open_army(id: int) -> void:
	_tab = 0
	_sel = "a:%d" % id
	visible = true
	refresh()

func close() -> void:
	visible = false
	_popup_open = false

func _process(delta: float) -> void:
	if not visible or units == null: return
	_selection_timer += delta
	if _selection_timer < 0.15: return
	_selection_timer = 0.0
	var ids := PackedStringArray()
	for d: Division in units.selected: ids.append(str(d.id))
	var signature := ",".join(ids)
	if signature != _selection_key:
		_selection_key = signature
		_sync_selection_cards()

func _queue_refresh() -> void:
	if _pending:
		return
	_pending = true
	(func() -> void:
		_pending = false
		if visible: refresh()).call_deferred()

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
	_cells[1].text = "%d" % int(c.command_power)
	_cells[2].text = UiTheme.format_number(c.available_manpower())
	_cells[3].text = UiTheme.format_number(c.stockpile.get("infantry_equipment", 0.0))
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	_selection_cards.clear()
	_popup_open = false
	PanelLayout.tabs(_root, [tr("ARM_TAB_COMMAND"), tr("ARM_TAB_TEMPLATES")], _switch_tab, _tab)
	if _tab == 0:
		_build_command(c)
	else:
		_build_templates(c)
	_sync_selection_cards()
	PanelLayout.queue_fit(self)

func _switch_tab(index: int) -> void:
	if _tab != index:
		_tab = index
		# Daily updates preserve the roster position, but a different page starts at its heading.
		(get_meta("scroll") as ScrollContainer).scroll_vertical = 0
	refresh()

# ================================================================== komuta zinciri
func _build_command(c: Country) -> void:
	_validate_sel(c)
	var cols := PanelLayout.columns(_root, [1.0, 1.8, 1.0])
	_tree(cols[0], c)
	var kind := _sel.get_slice(":", 0)
	var id := int(_sel.get_slice(":", 1)) if _sel.contains(":") else 0
	if kind == "a" and Military.army_by_id(id):
		_army_detail(cols[1], c, Military.army_by_id(id))
	elif kind == "g" and Military.group_by_id(id):
		_group_detail(cols[1], c, Military.group_by_id(id))
	else:
		_free_detail(cols[1], c)
	_roster(cols[2], c)

func _validate_sel(c: Country) -> void:
	# The unattached roster is an explicit selection, not an invalid army id.
	if _sel == "free": return
	var kind := _sel.get_slice(":", 0)
	var id := int(_sel.get_slice(":", 1)) if _sel.contains(":") else 0
	if kind == "a":
		var a := Military.army_by_id(id)
		if a and a.owner == c.tag:
			return
	elif kind == "g":
		var g := Military.group_by_id(id)
		if g and g.owner == c.tag:
			return
	var mine := Military.armies_of(c.tag)
	_sel = "a:%d" % mine[0].id if not mine.is_empty() else "free"

func _free_divisions(c: Country) -> Array[Division]:
	var out: Array[Division] = []
	for d in Military.country_divisions(c.tag):
		if d.army == 0 or Military.army_by_id(d.army) == null:
			out.append(d)
	return out

# ------------------------------------------------------------------ ağaç
func _tree(col: VBoxContainer, c: Country) -> void:
	PanelLayout.section(col, tr("ARM_CHAIN"))
	var groups := Military.groups_of(c.tag)
	for g in groups:
		_group_node(col, g)
		for a in Military.group_armies(g):
			_army_node(col, a, 26)
	var solo := Military.armies_of(c.tag).filter(func(a: Army) -> bool: return Military.group_by_id(a.group) == null)
	if not solo.is_empty() and not groups.is_empty():
		PanelLayout.section(col, tr("ARM_INDEPENDENT"))
	for a: Army in solo:
		_army_node(col, a, 0)
	if groups.is_empty() and solo.is_empty():
		PanelLayout.empty(col, tr("ARM_NO_ARMIES"))
	var free := _free_divisions(c)
	var fv := _node(col, "free", 0)
	var fl := UiTheme.make_label(tr("ARM_FREE_NODE") % free.size(), 16, UiTheme.TEXT if not free.is_empty() else UiTheme.TEXT_DIM)
	fl.add_theme_font_override("font", UiTheme.bold_font())
	fv.add_child(fl)
	fv.add_child(_dim(tr("ARM_FREE_NODE_SUB")))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	col.add_child(hb)
	var na := PanelLayout.small_button(tr("ARM_NEW_ARMY"), func() -> void:
		var a := Military.create_army(c.tag, [])
		_sel = "a:%d" % a.id, true, tr("TIP_ARM_NEW_ARMY"))
	na.icon = UiTheme.trimmed(UiTheme.icon("plus"))
	na.expand_icon = true
	na.add_theme_constant_override("icon_max_width", 18)
	na.custom_minimum_size.y = 38
	na.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(na)
	var ng := PanelLayout.small_button(tr("ARM_NEW_GROUP"), func() -> void:
		var g := Military.create_group(c.tag)
		_sel = "g:%d" % g.id, true, tr("TIP_ARM_NEW_GROUP"))
	ng.icon = UiTheme.trimmed(UiTheme.icon("plus"))
	ng.expand_icon = true
	ng.add_theme_constant_override("icon_max_width", 18)
	ng.custom_minimum_size.y = 38
	ng.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ng)
	PanelLayout.detail(col, tr("ARM_CHAIN_HELP"), 13)

## Tıklanınca seçilen ağaç düğümü (seçiliyse altın çerçeve)
func _node(parent: Container, key: String, indent: int) -> VBoxContainer:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", indent)
	parent.add_child(wrap)
	var pc := PanelContainer.new()
	pc.custom_minimum_size.y = 92
	pc.set_meta("force_key", key)
	ForceSelectionCard.apply(pc, false)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mouse := e as InputEventMouseButton
			_select_node(key, mouse.shift_pressed or mouse.ctrl_pressed, mouse.ctrl_pressed)
			pc.accept_event())
	wrap.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var checkbox := ForceSelectionCard.checkbox(false, func() -> void: _toggle_node(key))
	checkbox.name = "SelectionCheckbox"
	hb.add_child(checkbox)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var art := UiTheme.icon_texture(CommandPanelSkin.illustration("army"), 74)
	art.name = "ForceThumbnail"
	art.custom_minimum_size = Vector2(0, 74)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	_selection_cards.append({"panel": pc, "checkbox": checkbox, "key": key})
	return v

func _node_members(key: String) -> Array:
	var c := World.player()
	if c == null: return []
	if key == "free": return _free_divisions(c)
	var id := int(key.get_slice(":", 1))
	if key.begins_with("a:"):
		var army := Military.army_by_id(id)
		return Military.army_divisions(army) if army != null and army.owner == c.tag else []
	var group := Military.group_by_id(id)
	var members: Array[Division] = []
	if group != null and group.owner == c.tag:
		for army: Army in Military.group_armies(group): members.append_array(Military.army_divisions(army))
	return members

func _select_members(members: Array, additive: bool, toggle: bool) -> void:
	if units == null or members.is_empty(): return
	members = members.filter(func(d: Division) -> bool: return d in Military.divisions and d.owner == World.player_tag)
	if members.is_empty(): return
	var all_selected := members.all(func(d: Division) -> bool: return d in units.selected)
	if toggle and all_selected:
		var remaining := units.selected.filter(func(d: Division) -> bool: return not d in members)
		units.select_divisions(remaining, false)
	else:
		units.select_divisions(members, additive)
	_sync_selection_cards()

func _select_node(key: String, additive := false, toggle := false) -> void:
	_sel = key
	_select_members(_node_members(key), additive, toggle)
	refresh()

func _toggle_node(key: String) -> void:
	_sel = key
	_select_members(_node_members(key), true, true)
	refresh()

func _sync_selection_cards() -> void:
	for record: Dictionary in _selection_cards:
		var panel := record["panel"] as PanelContainer
		if not is_instance_valid(panel): continue
		var members: Array = [record["division"]] if record.has("division") else _node_members(record["key"])
		members = members.filter(func(d: Division) -> bool: return d in Military.divisions and d.owner == World.player_tag)
		var selected := 0
		for d: Division in members:
			if units != null and d in units.selected: selected += 1
		var all_selected := not members.is_empty() and selected == members.size()
		var partial := selected > 0 and not all_selected
		ForceSelectionCard.apply(panel, all_selected, partial)
		var checkbox := record["checkbox"] as ForceSelectionCard.SelectionBox
		checkbox.set_pressed_no_signal(all_selected)
		checkbox.partial = partial
		checkbox.disabled = units == null or members.is_empty()
		checkbox.tooltip_text = tr("FORCE_PARTIAL") if partial else tr("FORCE_DESELECT" if all_selected else "FORCE_SELECT")
		checkbox.queue_redraw()

func _group_node(col: VBoxContainer, g: ArmyGroup) -> void:
	var v := _node(col, "g:%d" % g.id, 0)
	var hb := _hrow(v)
	hb.add_child(UiTheme.icon_texture(UiTheme.icon("command_power"), 26))
	var n := UiTheme.make_label(g.name, 18, UiTheme.ACCENT)
	n.add_theme_font_override("font", UiTheme.title_font())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(n)
	var nd := 0
	var armies := Military.group_armies(g)
	for a in armies:
		nd += Military.army_divisions(a).size()
	hb.add_child(_dim(tr("ARM_GROUP_COUNTS") % [armies.size(), nd]))
	_commander_line(v, Military.commander_by_id(g.commander), true)

func _army_node(col: VBoxContainer, a: Army, indent: int) -> void:
	var v := _node(col, "a:%d" % a.id, indent)
	var divs := Military.army_divisions(a)
	var hb := _hrow(v)
	var sw := ColorRect.new()
	sw.color = a.color
	sw.custom_minimum_size = Vector2(6, 20)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sw)
	var n := UiTheme.make_label(a.name, 16, a.color.lightened(0.2))
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(n)
	var cnt := UiTheme.make_label("%d/%d" % [divs.size(), Military.ARMY_CAP], 15, UiTheme.BAD if divs.size() > Military.ARMY_CAP else UiTheme.TEXT)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cnt)
	_commander_line(v, Military.commander_by_id(a.commander), false)
	var front: String = World.countries[a.enemy].display_name() if World.countries.has(a.enemy) else tr("ARMY_NO_FRONT")
	var st := _hrow(v)
	var fl := _dim("%s  ·  %s" % [front, tr("ARMY_ATTACK") if a.mode == Army.Mode.ATTACK else tr("ARMY_HOLD")])
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(fl)
	st.add_child(_bar(_avg_org(divs), Color(0.45, 0.85, 0.35), 70.0, 5.0))

func _commander_line(v: VBoxContainer, cm: Commander, marshal_slot: bool) -> void:
	var hb := _hrow(v)
	if cm == null:
		var l := UiTheme.make_label(tr("ARM_NO_MARSHAL") if marshal_slot else tr("ARM_NO_COMMANDER"), 14, UiTheme.BAD.lightened(0.2))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(l)
		return
	var l := UiTheme.make_label("%s %s" % [cm.rank_name(), cm.name], 14, UiTheme.TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	hb.add_child(l)
	hb.add_child(_pips(cm.skill))

# ------------------------------------------------------------------ ordu ayrıntısı
func _army_detail(col: VBoxContainer, c: Country, a: Army) -> void:
	var divs := Military.army_divisions(a)
	PanelLayout.section(col, a.name.to_upper())
	# komutan
	var cm := Military.commander_by_id(a.commander)
	var picks: Array = [[tr("ARM_PICK_NONE"), 0]]
	if cm:
		picks.append(["%s  (%s)" % [cm.name, tr("ARM_CURRENT")], cm.id])
	for f in Military.free_commanders(c.tag):
		picks.append(["%s  ·  %s %d" % [f.name, f.rank_name(), f.skill], f.id])
	_commander_box(col, cm, picks, a.commander, func(v: int) -> void: Military.assign_army_commander(a, v),
		tr("ARM_BONUS_ARMY") % roundi(Military.army_bonus(a) * 100.0) if cm or Military.group_by_id(a.group) else tr("ARM_NO_COMMANDER_HINT"))
	# ayarlar
	var g := PanelLayout.grid(2)
	g.add_theme_constant_override("h_separation", 12)
	col.add_child(g)
	g.add_child(_label_cell(tr("ARM_FRONT")))
	var fronts: Array = [[tr("ARMY_NO_FRONT"), ""]]
	for t in DivisionPanel.front_candidates():
		fronts.append([World.countries[t].display_name(), t])
	g.add_child(_option(fronts, a.enemy, func(v: String) -> void:
		a.enemy = v
		Military.armies_changed.emit(), tr("TIP_ARMY_FRONT")))
	g.add_child(_label_cell(tr("ARM_STANCE")))
	g.add_child(_stance(func() -> Army.Mode: return a.mode, func(m: Army.Mode) -> void:
		a.mode = m
		Military.armies_changed.emit()))
	g.add_child(_label_cell(tr("ARM_GROUP")))
	var gl: Array = [[tr("ARM_PICK_INDEPENDENT"), 0]]
	for gr in Military.groups_of(c.tag):
		gl.append([gr.name, gr.id])
	g.add_child(_option(gl, a.group, func(v: int) -> void: Military.set_army_group(a, v), tr("TIP_ARM_GROUP")))
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 6)
	col.add_child(act)
	act.add_child(PanelLayout.small_button(tr("ARMY_SELECT"), func() -> void:
		if units:
			units.select_divisions(Military.army_divisions(a), false), not divs.is_empty(), tr("TIP_ARMY_SELECT")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act.add_child(spacer)
	act.add_child(PanelLayout.small_button(tr("ARMY_DISBAND"), func() -> void: Military.disband_army(a), true, tr("TIP_ARMY_DISBAND")))
	# tümenler
	PanelLayout.section(col, tr("ARM_DIVS_OF") % [divs.size(), Military.ARMY_CAP])
	if divs.size() > Military.ARMY_CAP:
		PanelLayout.detail(col, tr("ARM_OVER_CAP") % Military.ARMY_CAP, 14)
	if divs.is_empty():
		PanelLayout.empty(col, tr("ARM_EMPTY_ARMY"))
	var targets: Array = [[tr("ARM_MOVE_TO"), -1], [tr("ARM_UNASSIGN"), 0]]
	for o in Military.armies_of(c.tag):
		if o != a:
			targets.append([o.name, o.id])
	var division_grid := _division_grid(col, "ArmyDivisionGrid")
	for d in divs:
		_division_row(division_grid, c, d, _option(targets, -1, func(v: int) -> void:
			if v >= 0: Military.set_division_army(d, v), tr("TIP_ARM_MOVE_DIV")))
	# bağlanmamış tümenler buraya katılabilir
	var free := _free_divisions(c)
	if not free.is_empty():
		PanelLayout.section(col, tr("ARM_ADD_FREE") % free.size())
		col.add_child(PanelLayout.small_button(tr("ARM_ADD_ALL") % free.size(), func() -> void:
			for d in free:
				d.army = a.id
			Military.armies_changed.emit()))
		var free_grid := _division_grid(col, "AvailableDivisionGrid")
		for d in free.slice(0, 12):
			_division_row(free_grid, c, d, PanelLayout.small_button(tr("ARM_ADD_ONE"), func() -> void: Military.set_division_army(d, a.id)))
		if free.size() > 12:
			PanelLayout.empty(col, tr("DIV_MORE") % (free.size() - 12))

# ------------------------------------------------------------------ ordular grubu ayrıntısı
func _group_detail(col: VBoxContainer, c: Country, g: ArmyGroup) -> void:
	var armies := Military.group_armies(g)
	PanelLayout.section(col, g.name.to_upper())
	var cm := Military.commander_by_id(g.commander)
	var picks: Array = [[tr("ARM_PICK_NONE"), 0]]
	if cm:
		picks.append(["%s  (%s)" % [cm.name, tr("ARM_CURRENT")], cm.id])
	for f in Military.free_commanders(c.tag, true):
		picks.append(["%s  ·  %s %d" % [f.name, f.rank_name(), f.skill], f.id])
	_commander_box(col, cm, picks, g.commander, func(v: int) -> void: Military.assign_group_commander(g, v),
		tr("ARM_BONUS_GROUP") % roundi(Military.MARSHAL_BONUS * (cm.skill if cm else 0) * 100.0) if cm else tr("ARM_NO_MARSHAL_HINT"))
	# bütün ordulara tek seferde
	var g2 := PanelLayout.grid(2)
	g2.add_theme_constant_override("h_separation", 12)
	col.add_child(g2)
	g2.add_child(_label_cell(tr("ARM_GROUP_FRONT")))
	var fronts: Array = [[tr("ARM_PICK_KEEP"), "?"], [tr("ARMY_NO_FRONT"), ""]]
	for t in DivisionPanel.front_candidates():
		fronts.append([World.countries[t].display_name(), t])
	g2.add_child(_option(fronts, "?", func(v: String) -> void:
		if v == "?": return
		for a in armies:
			a.enemy = v
		Military.armies_changed.emit(), tr("TIP_ARM_GROUP_FRONT")))
	g2.add_child(_label_cell(tr("ARM_GROUP_STANCE")))
	var mode := Army.Mode.ATTACK
	for a in armies:
		if a.mode == Army.Mode.HOLD:
			mode = Army.Mode.HOLD
	g2.add_child(_stance(func() -> Army.Mode: return mode if not armies.is_empty() else Army.Mode.HOLD, func(m: Army.Mode) -> void:
		for a in armies:
			a.mode = m
		Military.armies_changed.emit()))
	PanelLayout.section(col, tr("ARM_GROUP_ARMIES") % armies.size())
	if armies.is_empty():
		PanelLayout.empty(col, tr("ARM_GROUP_EMPTY"))
	for a in armies:
		var divs := Military.army_divisions(a)
		var acm := Military.commander_by_id(a.commander)
		var r := PanelLayout.row(col, UiTheme.icon("army"), a.name,
			"%s  ·  %d/%d  ·  %s" % [acm.name if acm else tr("ARM_NO_COMMANDER"), divs.size(), Military.ARMY_CAP,
				tr("ARMY_ATTACK") if a.mode == Army.Mode.ATTACK else tr("ARMY_HOLD")])
		var ctl := HBoxContainer.new()
		ctl.add_theme_constant_override("separation", 4)
		ctl.add_child(PanelLayout.small_button(tr("ARM_OPEN"), func() -> void:
			_sel = "a:%d" % a.id
			refresh()))
		ctl.add_child(PanelLayout.small_button(tr("ARM_REMOVE_FROM_GROUP"), func() -> void: Military.set_army_group(a, 0)))
		PanelLayout.row_action(r, ctl)
	var others: Array = [[tr("ARM_ADD_ARMY_PICK"), 0]]
	for a in Military.armies_of(c.tag):
		if a.group != g.id:
			others.append([a.name + ("  (%s)" % Military.group_by_id(a.group).name if Military.group_by_id(a.group) else ""), a.id])
	if others.size() > 1:
		col.add_child(_option(others, 0, func(v: int) -> void:
			if v > 0: Military.set_army_group(Military.army_by_id(v), g.id), tr("TIP_ARM_ADD_ARMY")))
	col.add_child(PanelLayout.small_button(tr("ARM_DISBAND_GROUP"), func() -> void: Military.disband_group(g), true, tr("TIP_ARM_DISBAND_GROUP")))

# ------------------------------------------------------------------ bağlanmamış tümenler
func _free_detail(col: VBoxContainer, c: Country) -> void:
	var free := _free_divisions(c)
	PanelLayout.section(col, tr("ARM_FREE_TITLE") % free.size())
	PanelLayout.detail(col, tr("ARM_FREE_HELP"), 14)
	if free.is_empty():
		PanelLayout.empty(col, tr("ARM_FREE_NONE"))
		return
	col.add_child(PanelLayout.small_button(tr("ARM_FREE_NEW_ARMY") % free.size(), func() -> void:
		var a := Military.create_army(c.tag, free)
		_sel = "a:%d" % a.id, true, tr("TIP_ARMY_CREATE")))
	var targets: Array = [[tr("ARM_JOIN_ARMY"), 0]]
	for o in Military.armies_of(c.tag):
		targets.append([o.name, o.id])
	var free_grid := _division_grid(col, "FreeDivisionGrid")
	for d in free:
		_division_row(free_grid, c, d, _option(targets, 0, func(v: int) -> void:
			if v > 0: Military.set_division_army(d, v), tr("TIP_ARM_JOIN")) if targets.size() > 1 else Control.new())

# ------------------------------------------------------------------ komutan kadrosu
func _roster(col: VBoxContainer, c: Country) -> void:
	var list := Military.commanders_of(c.tag)
	# boştakiler üstte, atanmış komutanlar listenin altında (atanacak komutan hemen bulunsun)
	var busy := {}
	for cm in list:
		busy[cm.id] = Military.post_of(cm) != null
	list.sort_custom(func(x: Commander, y: Commander) -> bool:
		if busy[x.id] != busy[y.id]: return not busy[x.id]
		if x.rank != y.rank: return x.rank > y.rank
		if x.skill != y.skill: return x.skill > y.skill
		return x.name < y.name)
	PanelLayout.section(col, tr("ARM_ROSTER") % list.size())
	PanelLayout.detail(col, tr("ARM_ROSTER_HELP") % [int(c.command_power), int(Military.PROMOTE_COST), int(Military.RECRUIT_COST)], 13)
	var kind := _sel.get_slice(":", 0)
	var sel_army := Military.army_by_id(int(_sel.get_slice(":", 1))) if kind == "a" else null
	var sel_group := Military.group_by_id(int(_sel.get_slice(":", 1))) if kind == "g" else null
	for cm in list:
		var post := Military.post_of(cm)
		var post_txt := tr("ARM_IDLE")
		if post is Army:
			post_txt = (post as Army).name
		elif post is ArmyGroup:
			post_txt = (post as ArmyGroup).name
		var pc := PanelContainer.new()
		pc.theme_type_variation = "SlotGold" if cm.is_marshal() else "Row"
		UiTheme.pad(pc, 12, 8)
		pc.tooltip_text = tr("TIP_COMMANDER") % [cm.name, cm.rank_name(), cm.skill, roundi(cm.xp * 100),
			roundi(Military.GENERAL_BONUS * cm.skill * 100), roundi(Military.MARSHAL_BONUS * cm.skill * 100)]
		col.add_child(pc)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		pc.add_child(stack)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		stack.add_child(hb)
		var portrait := _commander_portrait(cm, Vector2(42, 54))
		if portrait != null:
			hb.add_child(portrait)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(v)
		var n := UiTheme.make_label(cm.name, 15, UiTheme.ACCENT if cm.is_marshal() else UiTheme.TEXT)
		n.add_theme_font_override("font", UiTheme.bold_font())
		n.clip_text = true
		v.add_child(n)
		var r2 := HFlowContainer.new()
		r2.add_theme_constant_override("h_separation", 6)
		v.add_child(r2)
		r2.add_child(_dim(cm.rank_name()))
		r2.add_child(_pips(cm.skill))
		r2.add_child(_bar(cm.xp, Color(0.72, 0.5, 0.95), 50.0, 4.0))
		var pl := _dim(post_txt)
		if post == null:
			pl.add_theme_color_override("font_color", UiTheme.TEXT_DIM.darkened(0.2))
		v.add_child(pl)
		var btns := HFlowContainer.new()
		btns.add_theme_constant_override("h_separation", 6)
		btns.add_theme_constant_override("v_separation", 4)
		btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stack.add_child(btns)
		if sel_army and sel_army.commander != cm.id:
			btns.add_child(PanelLayout.small_button(tr("ARM_ASSIGN"), func() -> void: Military.assign_army_commander(sel_army, cm.id),
				true, tr("TIP_ARM_ASSIGN") % [cm.name, sel_army.name]))
		elif sel_group and sel_group.commander != cm.id and cm.is_marshal():
			btns.add_child(PanelLayout.small_button(tr("ARM_ASSIGN"), func() -> void: Military.assign_group_commander(sel_group, cm.id),
				true, tr("TIP_ARM_ASSIGN") % [cm.name, sel_group.name]))
		if not cm.is_marshal():
			btns.add_child(PanelLayout.small_button(tr("ARM_PROMOTE") % int(Military.PROMOTE_COST), func() -> void: Military.promote(cm),
				Military.can_promote(cm), tr("TIP_ARM_PROMOTE") % [cm.name, int(Military.PROMOTE_COST), int(c.command_power)]))
	col.add_child(PanelLayout.small_button(tr("ARM_RECRUIT") % int(Military.RECRUIT_COST), func() -> void: Military.recruit_commander(c.tag),
		Military.can_recruit(c.tag), tr("TIP_ARM_RECRUIT") % [int(Military.RECRUIT_COST), int(c.command_power)]))

# ------------------------------------------------------------------ ortak parçalar
func _commander_box(col: VBoxContainer, cm: Commander, picks: Array, current: int, on_pick: Callable, bonus_text: String) -> void:
	var box := PanelContainer.new()
	box.theme_type_variation = "Row"
	UiTheme.pad(box, 14, 10)
	col.add_child(box)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	box.add_child(stack)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	stack.add_child(hb)
	var portrait := _commander_portrait(cm, Vector2(64, 76)) if cm else null
	if portrait != null:
		hb.add_child(portrait)
	else:
		var s := PanelLayout.slot(UiTheme.icon("command_power"), 64, "", "SlotGold" if cm else "SlotBad")
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	if cm:
		var n := UiTheme.make_label(cm.name, 20, UiTheme.ACCENT)
		n.add_theme_font_override("font", UiTheme.title_font())
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.custom_minimum_size.x = 1
		v.add_child(n)
		var r := HFlowContainer.new()
		r.add_theme_constant_override("h_separation", 8)
		v.add_child(r)
		r.add_child(UiTheme.make_label(cm.rank_name(), 15, UiTheme.TEXT))
		r.add_child(_pips(cm.skill))
		r.add_child(_dim(tr("ARM_XP") % roundi(cm.xp * 100)))
		r.add_child(_bar(cm.xp, Color(0.72, 0.5, 0.95), 90.0, 5.0))
	else:
		v.add_child(UiTheme.make_label(tr("ARM_NO_COMMANDER"), 18, UiTheme.BAD.lightened(0.2)))
	PanelLayout.detail(v, bonus_text, 14)
	var pick := _option(picks, current, on_pick, tr("TIP_ARM_PICK"))
	pick.custom_minimum_size.x = 0
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(pick)

## Tarihî kadro portreleri yalnızca veri eşleşmesi varsa gösterilir; rastgele üretilen
## komutanlara başka bir gerçek kişinin fotoğrafı asla düşmez.
func _commander_portrait(cm: Commander, size: Vector2) -> Control:
	if cm == null:
		return null
	if not _portrait_map_loaded:
		_portrait_map_loaded = true
		var path := "res://data/common/commander_portraits.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_portrait_map = parsed
	var image_path := str(_portrait_map.get("%s|%s" % [cm.owner, cm.name], ""))
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return null
	var tex: Texture2D = _portrait_textures.get(image_path)
	var invalid_import := false
	if FileAccess.file_exists(image_path + ".import"):
		var imported := ConfigFile.new()
		if imported.load(image_path + ".import") == OK and not bool(imported.get_value("remap", "valid", true)):
			invalid_import = true
	if tex == null:
		if invalid_import:
			# TUR_210.jpg is the exact mapped portrait but contains PNG bytes. Godot
			# rejected the extension-based import; decode that verified buffer only.
			var bytes := FileAccess.get_file_as_bytes(image_path)
			if bytes.size() < 8 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]): return null
			var image := Image.new()
			if image.load_png_from_buffer(bytes) != OK: return null
			tex = ImageTexture.create_from_image(image)
		else:
			tex = ResourceLoader.load(image_path) as Texture2D
		_portrait_textures[image_path] = tex
	if tex == null:
		return null
	var frame := PanelContainer.new()
	frame.theme_type_variation = "SlotGold" if cm.is_marshal() else "Row"
	frame.custom_minimum_size = size
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var image := TextureRect.new()
	image.texture = tex
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = size - Vector2(6, 6)
	frame.add_child(image)
	return frame

func _division_grid(parent: Container, grid_name: String) -> GridContainer:
	var grid := PanelLayout.grid(2)
	grid.name = grid_name
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _division_row(col: Container, c: Country, d: Division, action: Control) -> void:
	var s := Military.div_stats(d)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(186, 166)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.set_meta("division_id", d.id)
	ForceSelectionCard.apply(pc, units != null and d in units.selected)
	col.add_child(pc)
	pc.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_members([d], event.shift_pressed or event.ctrl_pressed, event.ctrl_pressed)
			pc.accept_event())
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(stack)
	var art := UiTheme.icon_texture(DivisionPanel._template_icon(c, d.template), 74)
	art.name = "DivisionThumbnail"
	art.custom_minimum_size = Vector2(0, 74)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(art)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hb)
	var checkbox := ForceSelectionCard.checkbox(units != null and d in units.selected, func() -> void: _select_members([d], true, true))
	checkbox.name = "SelectionCheckbox"
	hb.add_child(checkbox)
	_selection_cards.append({"panel": pc, "checkbox": checkbox, "division": d})
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var n := UiTheme.make_label(d.name, 16, UiTheme.TEXT)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.max_lines_visible = 2
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var st := World.state_of_province(d.province)
	var description := "%s  ·  %s" % [Military.template_name(c, d.template), st.display_name() if st else "—"]
	var sub := UiTheme.make_label(description, 13, UiTheme.TEXT_DIM)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size.x = 1
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(sub)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 3)
	stack.add_child(bars)
	var ob := PanelLayout.progress(d.org / maxf(s["org"], 1.0), Color(0.45, 0.85, 0.35), 5.0)
	var sb := PanelLayout.progress(d.strength, Color(0.95, 0.78, 0.3), 5.0)
	bars.add_child(ob)
	bars.add_child(sb)
	bars.tooltip_text = tr("TIP_ORG") % [int(d.org), int(s["org"])] + "\n" + tr("TIP_STR") % roundi(d.strength * 100)
	bars.mouse_filter = Control.MOUSE_FILTER_STOP
	var status := tr("DIV_TRAINING") % d.training if d.training > 0 else (tr("DIV_COMBAT") if d.in_combat else (tr("DIV_MOVING") if d.is_moving() else tr("DIV_IDLE")))
	if not d.supplied:
		status += " · " + tr("DIV_NO_SUPPLY")
	pc.tooltip_text = d.name + "\n" + description + "\n" + bars.tooltip_text + "\n" + status
	var sl := UiTheme.make_label(status, 13, UiTheme.BAD if not d.supplied or d.in_combat else UiTheme.TEXT_DIM)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.custom_minimum_size.x = 1
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(sl)
	action.custom_minimum_size = Vector2(0, 34)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(action)

## Açılır liste: items [[etiket, değer], ...]; seçilince cb(değer)
func _option(items: Array, current: Variant, cb: Callable, tip: String = "") -> OptionButton:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.tooltip_text = tip
	ob.add_theme_font_size_override("font_size", UiTheme.fs(16))
	ob.fit_to_longest_item = false
	ob.custom_minimum_size = Vector2(190, 42)
	for i in items.size():
		ob.add_item(str(items[i][0]))
		if items[i][1] == current:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		_popup_open = false
		cb.call(items[i][1]))
	ob.get_popup().about_to_popup.connect(func() -> void: _popup_open = true)
	ob.get_popup().popup_hide.connect(func() -> void: _popup_open = false)
	return ob

## Savun / Taarruz ikilisi
func _stance(get_mode: Callable, set_mode: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for pair: Array in [[Army.Mode.HOLD, tr("ARMY_HOLD"), tr("TIP_ARMY_HOLD")], [Army.Mode.ATTACK, tr("ARMY_ATTACK"), tr("TIP_ARMY_ATTACK")]]:
		var b := Button.new()
		b.theme_type_variation = "Tab"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.text = pair[1]
		b.tooltip_text = pair[2]
		b.custom_minimum_size.y = 42
		b.add_theme_font_size_override("font_size", UiTheme.fs(17))
		b.add_theme_font_override("font", UiTheme.bold_font())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(get_mode.call() == pair[0])
		var m: Army.Mode = pair[0]
		b.pressed.connect(func() -> void: set_mode.call(m))
		hb.add_child(b)
	return hb

## İnce çubuk, satır yüksekliğine uzamaz
func _bar(value: float, color: Color, width: float, height: float) -> Control:
	var b := PanelLayout.bar(value, color, width, height)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

func _pips(skill: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Commander.MAX_SKILL:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(9, 9)
		r.color = UiTheme.ACCENT if i < skill else Color(1, 1, 1, 0.12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
	return h

func _hrow(v: VBoxContainer) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hb)
	return hb

func _dim(text: String) -> Label:
	var l := UiTheme.make_label(text, 13, UiTheme.TEXT_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _label_cell(text: String) -> Label:
	var l := UiTheme.make_label(text, 15, UiTheme.TEXT_DIM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _avg_org(divs: Array[Division]) -> float:
	if divs.is_empty():
		return 0.0
	var t := 0.0
	for d in divs:
		t += d.org / maxf(Military.div_stats(d)["org"], 1.0)
	return t / divs.size()

# ================================================================== tümen şablonları
func _build_templates(c: Country) -> void:
	var cols := PanelLayout.columns(_root, [1.0, 1.1])
	_body = cols[0]
	if _edit < 0 and not c.templates.is_empty():
		_edit = 0
	PanelLayout.section(_body, tr("ARM_TEMPLATES") % c.templates.size())
	var templates := _division_grid(_body, "ArmyTemplateGrid")
	for i in c.templates.size():
		_template_row(c, i, templates)
	var newb := Button.new()
	newb.text = tr("ARMY_NEW_TEMPLATE")
	newb.icon = UiTheme.trimmed(UiTheme.icon("plus"))
	newb.add_theme_constant_override("icon_max_width", 18)
	newb.tooltip_text = tr("TIP_NEW_TEMPLATE")
	newb.focus_mode = Control.FOCUS_NONE
	newb.custom_minimum_size.y = 36
	newb.pressed.connect(func() -> void:
		c.templates.append({"name": tr("ARMY_TEMPLATE_N") % (c.templates.size() + 1), "battalions": {"infantry": 6}})
		_edit = c.templates.size() - 1
		refresh())
	_body.add_child(newb)
	_body = cols[1]
	if _edit >= 0 and _edit < c.templates.size():
		_build_designer(c, _edit)

func _template_row(c: Country, i: int, parent: Container = null) -> void:
	var s := Military.stats(c, i)
	var t: Dictionary = c.templates[i]
	var main := "infantry"
	var best := -1
	for b: String in t["battalions"]:
		if int(t["battalions"][b]) > best:
			best = int(t["battalions"][b])
			main = b
	var panel := PanelContainer.new()
	panel.name = "TemplateSelection_%d" % i
	panel.set_meta("template_id", i)
	panel.custom_minimum_size.x = 186
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForceSelectionCard.apply(panel, i == _edit)
	(parent if parent != null else _body).add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var select := Button.new()
	select.name = "TemplateSelectButton"
	select.text = str(t["name"])
	select.icon = UiTheme.trimmed(bat_icon(main))
	select.expand_icon = true
	select.add_theme_constant_override("icon_max_width", 40)
	select.add_theme_constant_override("h_separation", 8)
	select.add_theme_font_size_override("font_size", UiTheme.fs(17))
	select.add_theme_font_override("font", UiTheme.bold_font())
	select.add_theme_color_override("font_color", UiTheme.ACCENT if i == _edit else UiTheme.TEXT)
	select.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	select.custom_minimum_size = Vector2(0, 72)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.tooltip_text = tr("TIP_EDIT_TEMPLATE")
	select.pressed.connect(func() -> void:
		_edit = i
		refresh())
	Audio.ui_bind(select, "ui_tab")
	col.add_child(select)
	var stats := UiTheme.make_label(tr("ARMY_STATS") % [int(s["soft"]), int(s["hard"]), int(s["defense"]), int(s["breakthrough"]), int(s["org"]), snappedf(s["speed"], 0.1), int(s["width"])], 13, UiTheme.TEXT_DIM)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats)
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
		deploy_requested.emit(i), short.is_empty(), tip))
	col.add_child(ctl)

func _build_designer(c: Country, i: int) -> void:
	var t: Dictionary = c.templates[i]
	PanelLayout.section(_body, tr("ARMY_DESIGNER") % t["name"])
	# tabur ızgarası (5x5)
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
