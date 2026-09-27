class_name DivisionPanel
extends PanelContainer
## Seçili tümenler (alt orta), haritadaki mikro yönetim:
## - başlık: ortak ordu (renk, ad, komutan, cephe, duruş, Ordu ekranında yönet) ya da seçim sayısı
## - özet hücreleri: tümen, ortalama bütünlük ve güç, muharebede, ikmalsiz, doğrudan emirde
## - bileşim: şablona göre sayılar (tıkla: yalnız o tür seçili kalsın)
## - tümen kartları: simge, ad, bütünlük/güç çubukları, durum; tıkla = yalnız onu seç, × = seçimden çıkar
## - araç çubuğu: durdur, böl, ordu planına döndür | yeni ordu, orduya kat, ordudan çıkar | son askere kadar, dağıt
## Doğrudan emir: haritadan emir verilen ordu tümeni orduda kalır ama ordu planı onu oynatmaz.

signal manage_army(id: int)

const COLS := 6
const TILE := Vector2(142, 74)

var units: UnitLayer
var _head: HBoxContainer
var _cells: HBoxContainer
var _comp: HFlowContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _tools: HBoxContainer
var _hold: CheckButton
var _key := ""
var _grid_key := ""
var _timer := 0.0
var _grid_timer := 0.0
var _popup_open := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -14
	custom_minimum_size = Vector2(COLS * (TILE.x + 4) + 34, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	v.add_child(hp)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 10)
	hp.add_child(_head)
	_cells = HBoxContainer.new()
	_cells.add_theme_constant_override("separation", 4)
	v.add_child(_cells)
	_comp = HFlowContainer.new()
	_comp.add_theme_constant_override("h_separation", 4)
	_comp.add_theme_constant_override("v_separation", 4)
	v.add_child(_comp)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	DragScroll.attach(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)
	var tp := PanelContainer.new()
	tp.theme_type_variation = "Strip"
	v.add_child(tp)
	_tools = HBoxContainer.new()
	_tools.add_theme_constant_override("separation", 6)
	tp.add_child(_tools)
	_hold = CheckButton.new()
	_hold.text = tr("DIV_HOLD")
	_hold.tooltip_text = tr("TIP_DIV_HOLD")
	_hold.focus_mode = Control.FOCUS_NONE
	_hold.add_theme_font_size_override("font_size", 14)
	_hold.toggled.connect(func(on: bool) -> void:
		for d in units.selected:
			if d.owner == World.player_tag:
				d.hold = on)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.25:
		return
	_grid_timer += _timer
	_timer = 0.0
	units.prune_selection()
	visible = not units.selected.is_empty()
	if not visible:
		_key = ""
		_grid_key = ""
		return
	_refresh()

func _mine() -> Array[Division]:
	var out: Array[Division] = []
	for d in units.selected:
		if d.owner == World.player_tag:
			out.append(d)
	return out

func _common_army(mine: Array[Division]) -> Army:
	var common := -1
	for d in mine:
		if common == -1:
			common = d.army
		elif common != d.army:
			return null
	return Military.army_by_id(common) if common > 0 else null

func _refresh() -> void:
	var sel := units.selected
	var mine := _mine()
	var all_hold := not mine.is_empty()
	for d in mine:
		all_hold = all_hold and d.hold
	_hold.set_pressed_no_signal(all_hold)
	# yapısal kısımlar yalnız seçim ya da ordular değişince yeniden kurulur (açık liste kapanmasın)
	var ids := PackedStringArray()
	for d in sel:
		ids.append("%d/%d/%d" % [d.id, d.army, int(d.manual)])
	var akey := ""
	for a in Military.armies_of(World.player_tag):
		akey += "%d:%s:%d:%d:%d," % [a.id, a.enemy, int(a.mode), a.commander, a.group]
	var key := ",".join(ids) + "|" + akey
	if key != _key and not _popup_open:
		_key = key
		_build_head(sel, mine)
		_build_comp(sel)
		_build_tools(mine)
		_grid_key = ""
	if key != _grid_key or _grid_timer >= 1.0:
		_grid_key = key
		_grid_timer = 0.0
		_build_cells(sel)
		_build_grid(sel)

# ------------------------------------------------------------------ başlık
func _build_head(sel: Array[Division], mine: Array[Division]) -> void:
	for ch in _head.get_children():
		ch.queue_free()
	var a := _common_army(mine)
	if a:
		var sw := ColorRect.new()
		sw.color = a.color
		sw.custom_minimum_size = Vector2(6, 30)
		_head.add_child(sw)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -3)
	_head.add_child(tv)
	var t := UiTheme.make_label((a.name if a else tr("DIV_SELECTED") % sel.size()).to_upper(), 20, a.color.lightened(0.25) if a else UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.title_font())
	tv.add_child(t)
	var sub := ""
	if a:
		sub = tr("DIV_SELECTED") % sel.size()
	elif not mine.is_empty():
		var n := 0
		var seen := {}
		for d in mine:
			if d.army != 0 and Military.army_by_id(d.army) and not seen.has(d.army):
				seen[d.army] = true
				n += 1
		sub = tr("DIVSEL_MIXED") % n if n > 0 else tr("DIVSEL_NO_ARMY")
	tv.add_child(UiTheme.make_label(sub, 13, UiTheme.TEXT_DIM))
	if a:
		# komutan
		var cm := Military.commander_by_id(a.commander)
		var cb := HBoxContainer.new()
		cb.add_theme_constant_override("separation", 6)
		cb.tooltip_text = tr("TIP_COMMANDER") % [cm.name, cm.rank_name(), cm.skill, roundi(cm.xp * 100),
			roundi(Military.GENERAL_BONUS * cm.skill * 100), roundi(Military.MARSHAL_BONUS * cm.skill * 100)] if cm else tr("ARM_NO_COMMANDER_HINT")
		cb.mouse_filter = Control.MOUSE_FILTER_STOP
		_head.add_child(cb)
		var ci := UiTheme.icon_texture(UiTheme.icon("command_power"), 30)
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cb.add_child(ci)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", -3)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cb.add_child(cv)
		var cn := UiTheme.make_label(cm.name if cm else tr("ARM_NO_COMMANDER"), 15, UiTheme.TEXT if cm else UiTheme.BAD.lightened(0.2))
		cn.add_theme_font_override("font", UiTheme.bold_font())
		cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(cn)
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 6)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(cr)
		if cm:
			var rl := UiTheme.make_label(cm.rank_name(), 12, UiTheme.TEXT_DIM)
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cr.add_child(rl)
			cr.add_child(_pips(cm.skill))
			var bl := UiTheme.make_label("+%d%%" % roundi(Military.army_bonus(a) * 100), 12, UiTheme.GOOD)
			bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cr.add_child(bl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.add_child(spacer)
	if a:
		var opt := OptionButton.new()
		opt.focus_mode = Control.FOCUS_NONE
		opt.tooltip_text = tr("TIP_ARMY_FRONT")
		opt.custom_minimum_size.x = 150
		opt.add_theme_font_size_override("font_size", 14)
		opt.add_item(tr("ARMY_NO_FRONT"))
		var tags := front_candidates()
		for i in tags.size():
			opt.add_item(World.countries[tags[i]].display_name())
			if tags[i] == a.enemy:
				opt.select(i + 1)
		opt.item_selected.connect(func(idx: int) -> void:
			_popup_open = false
			a.enemy = tags[idx - 1] if idx > 0 else ""
			Military.armies_changed.emit())
		opt.get_popup().about_to_popup.connect(func() -> void: _popup_open = true)
		opt.get_popup().popup_hide.connect(func() -> void: _popup_open = false)
		opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_head.add_child(opt)
		var seg := HBoxContainer.new()
		seg.add_theme_constant_override("separation", 0)
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_head.add_child(seg)
		var group := ButtonGroup.new()
		for pair: Array in [[Army.Mode.HOLD, tr("ARMY_HOLD"), tr("TIP_ARMY_HOLD")], [Army.Mode.ATTACK, tr("ARMY_ATTACK"), tr("TIP_ARMY_ATTACK")]]:
			var b := _btn(pair[1], pair[2])
			b.theme_type_variation = "Tab"
			b.toggle_mode = true
			b.button_group = group
			b.set_pressed_no_signal(a.mode == pair[0])
			b.custom_minimum_size.x = 76
			var m: Army.Mode = pair[0]
			b.pressed.connect(func() -> void:
				a.mode = m
				Military.armies_changed.emit())
			seg.add_child(b)
		var mng := _btn(tr("ARM_MANAGE"), tr("TIP_ARM_MANAGE"))
		mng.icon = UiTheme.icon("army")
		mng.expand_icon = true
		mng.add_theme_constant_override("icon_max_width", 18)
		mng.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var aid := a.id
		mng.pressed.connect(func() -> void: manage_army.emit(aid))
		_head.add_child(mng)
		var sel_all := _btn(tr("ARMY_SELECT"), tr("TIP_ARMY_SELECT"))
		sel_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sel_all.pressed.connect(func() -> void: units.select_divisions(Military.army_divisions(a), false))
		_head.add_child(sel_all)
	var close := UiTheme.icon_button("close", tr("TIP_CLOSE"), func() -> void: units.clear_selection(), 28)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(close)

# ------------------------------------------------------------------ özet hücreleri
func _build_cells(sel: Array[Division]) -> void:
	for ch in _cells.get_children():
		ch.queue_free()
	var org := 0.0
	var strength := 0.0
	var combat := 0
	var nosup := 0
	var manual := 0
	var training := 0
	for d in sel:
		org += d.org / maxf(Military.div_stats(d)["org"], 1.0)
		strength += d.strength
		combat += int(d.in_combat)
		nosup += int(not d.supplied)
		manual += int(d.manual)
		training += int(d.training > 0)
	var n := maxf(sel.size(), 1.0)
	_cell(UiTheme.icon("army"), tr("DIVSEL_C_DIVS"), "%d" % sel.size(), UiTheme.TEXT, -1.0, Color.WHITE,
		tr("DIVSEL_C_TRAINING") % training if training > 0 else "")
	_cell(UiTheme.icon("manpower"), tr("DIVSEL_C_ORG"), "%d%%" % roundi(org / n * 100), _ratio(org / n), org / n, Color(0.45, 0.85, 0.35), "")
	_cell(UiTheme.icon_or("equipment_infantry_equipment", "army"), tr("DIVSEL_C_STR"), "%d%%" % roundi(strength / n * 100), _ratio(strength / n), strength / n, Color(0.95, 0.78, 0.3), "")
	_cell(UiTheme.icon_or("battle", "war_support"), tr("DIVSEL_C_COMBAT"), "%d" % combat, UiTheme.BAD if combat > 0 else UiTheme.TEXT_DIM, -1.0, Color.WHITE, "")
	_cell(UiTheme.icon_or("supply", "fuel"), tr("DIVSEL_C_SUPPLY"), tr("DIVSEL_SUPPLY_OK") if nosup == 0 else tr("DIVSEL_SUPPLY_BAD") % nosup,
		UiTheme.GOOD if nosup == 0 else UiTheme.BAD, -1.0, Color.WHITE, "")
	_cell(UiTheme.icon_or("command_power", "army"), tr("DIVSEL_C_MANUAL"), "%d" % manual, UiTheme.ACCENT if manual > 0 else UiTheme.TEXT_DIM, -1.0, Color.WHITE,
		tr("TIP_DIVSEL_TO_PLAN"))

func _cell(icon: Texture2D, caption: String, value: String, col: Color, ratio: float, bar_col: Color, tip: String) -> void:
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Cell"
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.tooltip_text = (caption + "\n" + tip) if tip != "" else ""
	pc.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	_cells.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	if icon:
		var ic := UiTheme.icon_texture(icon, 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var cl := UiTheme.make_label(caption, 11, UiTheme.TEXT_DIM)
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cl)
	var vl := UiTheme.make_label(value, 16, col)
	vl.add_theme_font_override("font", UiTheme.bold_font())
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(vl)
	if ratio >= 0.0:
		v.add_child(_bar(ratio, bar_col, 90.0, 4.0))

static func _ratio(v: float) -> Color:
	return UiTheme.GOOD if v >= 0.7 else (UiTheme.BAD if v < 0.35 else Color(0.93, 0.78, 0.4))

# ------------------------------------------------------------------ bileşim
func _build_comp(sel: Array[Division]) -> void:
	for ch in _comp.get_children():
		ch.queue_free()
	var by := {}
	var order: Array = []
	for d in sel:
		var k := "%s:%d" % [d.owner, d.template]
		if not by.has(k):
			by[k] = []
			order.append(k)
		by[k].append(d)
	for k: String in order:
		var group: Array = by[k]
		var d0: Division = group[0]
		var c: Country = World.countries.get(d0.owner)
		var b := Button.new()
		b.theme_type_variation = "Tab"
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%d × %s" % [group.size(), Military.template_name(c, d0.template) if c else "?"]
		b.icon = _template_icon(c, d0.template)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 20)
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = tr("TIP_DIVSEL_ONLY") % b.text
		b.disabled = order.size() < 2
		b.pressed.connect(func() -> void: units.select_divisions(group, false))
		_comp.add_child(b)

static func _template_icon(c: Country, ti: int) -> Texture2D:
	if c == null or ti >= c.templates.size():
		return UiTheme.icon("army")
	var main := "infantry"
	var best := -1
	var bats: Dictionary = c.templates[ti]["battalions"]
	for b: String in bats:
		if int(bats[b]) > best:
			best = int(bats[b])
			main = b
	return ArmyPanel.bat_icon(main) if Military.battalions.has(main) else UiTheme.icon("army")

# ------------------------------------------------------------------ tümen kartları
func _build_grid(sel: Array[Division]) -> void:
	for ch in _grid.get_children():
		ch.queue_free()
	for d in sel:
		_grid.add_child(_tile(d))
	var rows := ceili(sel.size() / float(COLS))
	_scroll.custom_minimum_size.y = minf(rows, 2.5) * (TILE.y + 4.0)

func _tile(d: Division) -> Control:
	var s := Military.div_stats(d)
	var c: Country = World.countries.get(d.owner)
	var a := Military.army_by_id(d.army)
	var bad := d.in_combat or not d.supplied
	var pc := PanelContainer.new()
	pc.theme_type_variation = "SlotBad" if bad else ("SlotGold" if d.manual else "Slot")
	pc.custom_minimum_size = TILE
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := World.state_of_province(d.province)
	var status := tr("DIV_TRAINING") % d.training if d.training > 0 else (tr("DIV_COMBAT") if d.in_combat else (tr("DIV_MOVING") if d.is_moving() else tr("DIV_IDLE")))
	if not d.supplied:
		status += " · " + tr("DIV_NO_SUPPLY")
	pc.tooltip_text = tr("TIP_DIVSEL_TILE") % [d.name, Military.template_name(c, d.template) if c else "?", a.name if a else "—",
		(" (" + tr("DIVSEL_MANUAL_TAG") + ")") if d.manual else "", int(d.org), int(s["org"]), roundi(d.strength * 100),
		tr("DIV_XP_%d" % d.xp_level()), roundi(d.planning * 20.0), status, st.display_name() if st else "—"]
	pc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			units.select_divisions([d], false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var ic := UiTheme.icon_texture(_template_icon(c, d.template), 24)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(ic)
	var n := UiTheme.make_label(d.name, 13, UiTheme.TEXT)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.clip_text = true
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	var x := UiTheme.icon_button("close", tr("TIP_DIVSEL_REMOVE"), func() -> void:
		units.selected.erase(d)
		units._dirty = true, 16)
	x.flat = true
	x.modulate = Color(1, 1, 1, 0.7)
	top.add_child(x)
	v.add_child(_bar(d.org / maxf(s["org"], 1.0), Color(0.45, 0.85, 0.35), TILE.x - 16.0, 5.0))
	v.add_child(_bar(d.strength, Color(0.95, 0.78, 0.3), TILE.x - 16.0, 5.0))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	var sl := UiTheme.make_label(status, 11, UiTheme.BAD if bad else UiTheme.TEXT_DIM)
	sl.clip_text = true
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sl)
	if a:
		var al := UiTheme.make_label(a.name, 11, a.color.lightened(0.2))
		al.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.add_child(al)
	return pc

# ------------------------------------------------------------------ araç çubuğu
func _build_tools(mine: Array[Division]) -> void:
	for ch in _tools.get_children():
		if ch != _hold:
			ch.queue_free()
	if _hold.get_parent():
		_hold.get_parent().remove_child(_hold)
	if mine.is_empty():
		return
	var manual := mine.filter(func(d: Division) -> bool: return d.manual).size()
	var stop := _btn(tr("DIV_STOP"), tr("TIP_DIV_STOP"))
	stop.pressed.connect(func() -> void:
		for d in mine: Military.stop(d)
		units._dirty = true)
	_tools.add_child(stop)
	if mine.size() >= 2:
		var half := _btn(tr("DIVSEL_SPLIT") % [(mine.size() + 1) / 2, mine.size() / 2], tr("TIP_DIVSEL_SPLIT"))
		half.pressed.connect(func() -> void: units.select_divisions(mine.slice(0, (mine.size() + 1) / 2), false))
		_tools.add_child(half)
	if manual > 0:
		var back := _btn(tr("DIVSEL_TO_PLAN") % manual, tr("TIP_DIVSEL_TO_PLAN"))
		back.pressed.connect(func() -> void:
			for d in mine:
				d.manual = false
			_key = "")
		_tools.add_child(back)
	_tools.add_child(VSeparator.new())
	var newa := _btn(tr("DIVSEL_NEW_ARMY") % mine.size(), tr("TIP_DIVSEL_NEW_ARMY"))
	newa.pressed.connect(func() -> void:
		var a := Military.create_army(World.player_tag, mine)
		World.notify(tr("NOTE_ARMY_FORMED") % [a.name, mine.size()], "info"))
	_tools.add_child(newa)
	var armies := Military.armies_of(World.player_tag)
	if not armies.is_empty():
		var join := OptionButton.new()
		join.focus_mode = Control.FOCUS_NONE
		join.tooltip_text = tr("TIP_DIVSEL_JOIN")
		join.add_theme_font_size_override("font_size", 14)
		join.add_item(tr("DIVSEL_JOIN"))
		for a in armies:
			join.add_item("%s (%d)" % [a.name, Military.army_divisions(a).size()])
		join.item_selected.connect(func(idx: int) -> void:
			_popup_open = false
			if idx <= 0:
				return
			var a: Army = armies[idx - 1]
			for d in mine:
				d.army = a.id
				d.manual = false
			Military.armies_changed.emit())
		join.get_popup().about_to_popup.connect(func() -> void: _popup_open = true)
		join.get_popup().popup_hide.connect(func() -> void: _popup_open = false)
		_tools.add_child(join)
	var in_army := mine.filter(func(d: Division) -> bool: return d.army != 0)
	if not in_army.is_empty():
		var leave := _btn(tr("DIVSEL_LEAVE") % in_army.size(), tr("TIP_DIVSEL_LEAVE"))
		leave.pressed.connect(func() -> void:
			for d: Division in in_army:
				d.army = 0
				d.manual = false
			Military.armies_changed.emit())
		_tools.add_child(leave)
	_tools.add_child(VSeparator.new())
	_tools.add_child(_hold)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools.add_child(spacer)
	var dis := _btn(tr("DIV_DISBAND"), tr("TIP_DIV_DISBAND"))
	dis.add_theme_color_override("font_color", UiTheme.BAD.lightened(0.25))
	dis.pressed.connect(func() -> void:
		for d in mine.duplicate(): Military.disband(d)
		units.clear_selection())
	_tools.add_child(dis)

func _btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	return b

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
		r.custom_minimum_size = Vector2(8, 8)
		r.color = UiTheme.ACCENT if i < skill else Color(1, 1, 1, 0.12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
	return h

## Cephe adayları: savaştığımız ülkeler, savaş hedeflerimiz ve kara komşularımız
static func front_candidates() -> Array[String]:
	var me := World.player_tag
	var out: Array[String] = []
	for t in Diplomacy.enemies_of(me):
		if not t in out: out.append(t)
	for t: String in World.countries[me].war_goals:
		if not t in out: out.append(t)
	var seen := {}
	for p: Province in World.provinces:
		if p == null or not p.is_land() or World.controller_tag(p.id) != me:
			continue
		for n in World.land_neighbors(p.id):
			var o := World.controller_tag(n)
			if o != "" and o != me and not seen.has(o):
				seen[o] = true
				if not o in out: out.append(o)
	return out

