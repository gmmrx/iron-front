class_name DivisionPanel
extends PanelContainer
## Seçili tümenler: ekranın sağ kenarında, sağdan kayarak açılan dikey panel (haritada mikro yönetim):
## - başlık: seçili tümen sayısı ve kapat
## - özet hücreleri: tümen, ortalama bütünlük ve güç, muharebede, ikmal (üçerli ızgara)
## - bileşim: şablona göre sayılar (tıkla: yalnız o tür seçili kalsın)
## - tümen kartları (iki sütun, kaydırılır): simge, ad, bütünlük/güç çubukları, durum; tıkla = yalnız onu seç, × = çıkar
## - araç çubuğu: dur (siper kazar), geri çekil, böl (1 / yarısı / hepsi), duruş (son askere kadar / esnek), dağıt
## Ordu, ordular grubu ve komutan yok (docs/DESIGN.md): oyuncu tümenleri seçip doğrudan oynar.

signal manage_army(id: int)

const COLS := 2
const WIDTH := 440                    ## compact two-column selection overview, with an explicit checkbox per card
const SLIDE := 0.18                   ## sağdan kayarak açılma süresi (sn)
const TILE := Vector2(188, 170)

var units: UnitLayer
var _head: HBoxContainer
var _cells: GridContainer
var _comp: HFlowContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _tools: HFlowContainer            ## komutlar sığmazsa ikinci satıra akar
var _stance: HBoxContainer            ## duruş: son askere kadar / esnek (araç çubuğu yeniden kurulurken korunur)
var _stance_hold: Button
var _stance_flex: Button
var _motivate_btn: Button            ## teşvik: nüfuz harcayıp seçilileri güçlendir (bedeli ve durumu her yenilemede)
var _motivate_for: Array[Division] = []
var _key := ""
var _grid_key := ""
var _timer := 0.0
var _grid_timer := 0.0
var _popup_open := false

func _ready() -> void:
	CommandPanelSkin.apply(self)
	# sağ kenar: üst çubuğun altından harita kipi düğmelerinin üstüne kadar
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH - 10
	offset_right = -10
	offset_top = 110
	offset_bottom = -84
	custom_minimum_size = Vector2(WIDTH, 0)
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
	_cells = GridContainer.new()
	_cells.columns = 3
	_cells.add_theme_constant_override("h_separation", 4)
	_cells.add_theme_constant_override("v_separation", 4)
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
	_tools = HFlowContainer.new()
	_tools.add_theme_constant_override("h_separation", 6)
	_tools.add_theme_constant_override("v_separation", 4)
	tp.add_child(_tools)
	_stance = HBoxContainer.new()
	_stance.add_theme_constant_override("separation", 0)
	var sl := UiTheme.make_label(tr("DIV_STANCE"), 13, UiTheme.TEXT_DIM)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stance.add_child(sl)
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	_stance.add_child(gap)
	_stance_hold = _btn(tr("DIV_STANCE_HOLD"), tr("TIP_DIV_STANCE_HOLD"))
	_stance_flex = _btn(tr("DIV_STANCE_FLEX"), tr("TIP_DIV_STANCE_FLEX"))
	for pair: Array in [[_stance_hold, true], [_stance_flex, false]]:
		var b: Button = pair[0]
		var hold: bool = pair[1]
		b.theme_type_variation = "Tab"
		b.toggle_mode = true
		b.pressed.connect(func() -> void:
			for d in units.selected:
				if d.owner == World.player_tag:
					d.hold = hold
			_sync_stance())
		_stance.add_child(b)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.25:
		return
	_grid_timer += _timer
	_timer = 0.0
	units.prune_selection()
	var want := not units.selected.is_empty() and not _army_panel_open()
	if want and not visible:
		_slide_in()
	visible = want
	if not visible:
		_key = ""
		_grid_key = ""
		return
	_refresh()

func _army_panel_open() -> bool:
	var parent := get_parent()
	if parent == null: return false
	for child: Node in parent.get_children():
		if child is ArmyPanel and (child as ArmyPanel).visible: return true
	return false

## Sağdan kayarak açılır (panel genişliği kadar dışarıdan yerine)
func _slide_in() -> void:
	offset_left = -10.0
	offset_right = WIDTH - 10.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "offset_left", -float(WIDTH) - 10.0, SLIDE)
	tw.tween_property(self, "offset_right", -10.0, SLIDE)

func _mine() -> Array[Division]:
	var out: Array[Division] = []
	for d in units.selected:
		if d.owner == World.player_tag:
			out.append(d)
	return out

func _sync_stance() -> void:
	var mine := _mine()
	var n_hold := 0
	for d in mine:
		n_hold += int(d.hold)
	_stance_hold.set_pressed_no_signal(not mine.is_empty() and n_hold == mine.size())
	_stance_flex.set_pressed_no_signal(not mine.is_empty() and n_hold == 0)

## Teşvik düğmesi: bedel (nüfuz), yapılamıyorsa soluk ve nedeni ipucunda
func _sync_motivate() -> void:
	if _motivate_btn == null or not is_instance_valid(_motivate_btn):
		return
	var c := World.player()
	var md := Military.motivate_def()
	var cost := int(Military.motivate_cost(c, _motivate_for))
	var err := Military.motivate_error(c, _motivate_for)
	_motivate_btn.text = tr("DIV_MOTIVATE") % cost
	_motivate_btn.disabled = err != ""
	var tip := tr("TIP_DIV_MOTIVATE") % [roundi(float(md["org"]) * 100.0), roundi(float(md["bonus"]) * 100.0), int(md["hours"]),
		cost, int(md["pp_per_division"])]
	_motivate_btn.tooltip_text = tip + ("" if err == "" else "\n\n⚠ " + tr(err))

func _refresh() -> void:
	var sel := units.selected
	var mine := _mine()
	_sync_stance()
	_sync_motivate()
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
func _build_head(sel: Array[Division], _mine: Array[Division]) -> void:
	for ch in _head.get_children():
		ch.queue_free()
	var t := UiTheme.make_label((tr("DIV_SELECTED") % sel.size()).to_upper(), 20, UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	_head.add_child(t)
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
	var training := 0
	for d in sel:
		org += d.org / maxf(Military.div_stats(d)["org"], 1.0)
		strength += d.strength
		combat += int(d.in_combat)
		nosup += int(not d.supplied)
		training += int(d.training > 0)
	var n := maxf(sel.size(), 1.0)
	_cell(UiTheme.icon("army"), tr("DIVSEL_C_DIVS"), "%d" % sel.size(), UiTheme.TEXT, -1.0, Color.WHITE,
		tr("DIVSEL_C_TRAINING") % training if training > 0 else "")
	_cell(UiTheme.icon("manpower"), tr("DIVSEL_C_ORG"), "%d%%" % roundi(org / n * 100), _ratio(org / n), org / n, Color(0.45, 0.85, 0.35), "")
	_cell(UiTheme.icon_or("equipment_infantry_equipment", "army"), tr("DIVSEL_C_STR"), "%d%%" % roundi(strength / n * 100), _ratio(strength / n), strength / n, Color(0.95, 0.78, 0.3), "")
	_cell(UiTheme.icon_or("battle", "war_support"), tr("DIVSEL_C_COMBAT"), "%d" % combat, UiTheme.BAD if combat > 0 else UiTheme.TEXT_DIM, -1.0, Color.WHITE, "")
	_cell(UiTheme.icon_or("supply", "fuel"), tr("DIVSEL_C_SUPPLY"), tr("DIVSEL_SUPPLY_OK") if nosup == 0 else tr("DIVSEL_SUPPLY_BAD") % nosup,
		UiTheme.GOOD if nosup == 0 else UiTheme.BAD, -1.0, Color.WHITE, "")

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
		b.set_meta("audio_silent", true) # UnitLayer is the selection-audio owner.
		b.theme_type_variation = "Tab"
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%d × %s" % [group.size(), Military.template_name(c, d0.template) if c else "?"]
		b.icon = _template_icon(c, d0.template)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 20)
		b.add_theme_font_size_override("font_size", UiTheme.fs(14))
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
		_grid.remove_child(ch)
		ch.queue_free()
	for d in sel:
		_grid.add_child(_tile(d))
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL      # yan panelde kalan yüksekliği doldurur

func _tile(d: Division) -> Control:
	var s := Military.div_stats(d)
	var c: Country = World.countries.get(d.owner)
	var bad := d.in_combat or not d.supplied
	var selected := d.owner == World.player_tag and d in Military.divisions and d in units.selected
	var pc := PanelContainer.new()
	ForceSelectionCard.apply(pc, selected)
	pc.set_meta("division_id", d.id)
	pc.custom_minimum_size = TILE
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := World.state_of_province(d.province)
	var status := tr("DIV_TRAINING") % d.training if d.training > 0 else (tr("DIV_COMBAT") if d.in_combat else (tr("DIV_MOVING") if d.is_moving() else tr("DIV_IDLE")))
	if not d.supplied:
		status += " · " + tr("DIV_NO_SUPPLY")
	pc.tooltip_text = tr("TIP_DIVSEL_TILE") % [d.name, Military.template_name(c, d.template) if c else "?", "—",
		"", int(d.org), int(s["org"]), roundi(d.strength * 100),
		tr("DIV_XP_%d" % d.xp_level()), roundi(d.planning * 20.0), status, st.display_name() if st else "—"]
	pc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mouse := e as InputEventMouseButton
			_select_tile(d, mouse.shift_pressed or mouse.ctrl_pressed, mouse.ctrl_pressed)
			pc.accept_event())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var art := UiTheme.icon_texture(_template_icon(c, d.template), 74)
	art.name = "DivisionThumbnail"
	art.custom_minimum_size = Vector2(0, 74)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var checkbox := ForceSelectionCard.checkbox(selected, func() -> void: _select_tile(d, true, true))
	checkbox.name = "SelectionCheckbox"
	checkbox.custom_minimum_size = Vector2(24, 24)
	checkbox.disabled = d.owner != World.player_tag or not d in Military.divisions
	top.add_child(checkbox)
	var n := UiTheme.make_label(d.name, 15, UiTheme.TEXT)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	var x := UiTheme.icon_button("close", tr("TIP_DIVSEL_REMOVE"), func() -> void: _remove_tile(d), 16)
	x.set_meta("audio_silent", true)
	x.flat = true
	x.modulate = Color(1, 1, 1, 0.7)
	top.add_child(x)
	v.add_child(_bar(d.org / maxf(s["org"], 1.0), Color(0.45, 0.85, 0.35), TILE.x - 16.0, 5.0))
	v.add_child(_bar(d.strength, Color(0.95, 0.78, 0.3), TILE.x - 16.0, 5.0))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	var sl := UiTheme.make_label(status, 13, UiTheme.BAD if bad else UiTheme.TEXT_DIM)
	sl.clip_text = true
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sl)
	return pc

func _select_tile(d: Division, additive := false, toggle := false) -> void:
	if units == null: return
	if not d in Military.divisions or d.owner != World.player_tag: return
	if toggle and d in units.selected:
		_remove_tile(d)
	else:
		units.select_divisions([d], additive)
		_refresh()

func _remove_tile(d: Division) -> void:
	if units == null: return
	var remaining := units.selected.filter(func(other: Division) -> bool: return other != d)
	units.select_divisions(remaining, false)
	_refresh()

# ------------------------------------------------------------------ araç çubuğu
func _build_tools(mine: Array[Division]) -> void:
	for ch in _tools.get_children():
		if ch != _stance:
			ch.queue_free()
	if _stance.get_parent():
		_stance.get_parent().remove_child(_stance)
	if mine.is_empty():
		return
	var stop := _btn(tr("DIV_STOP"), tr("TIP_DIV_STOP"))
	stop.set_meta("audio_silent", true)
	stop.pressed.connect(func() -> void:
		for d in mine: Military.stop(d)
		Audio.play("order_stop", 150)
		units._dirty = true)
	_tools.add_child(stop)
	var back := _btn(tr("DIV_WITHDRAW"), tr("TIP_DIV_WITHDRAW"))
	back.set_meta("audio_silent", true)
	back.pressed.connect(func() -> void:
		var ok := 0
		for d in mine:
			if Military.withdraw(d):
				ok += 1
		if ok == 0:
			World.notify(tr("NOTE_NO_WITHDRAW"), "bad")
		else:
			Audio.play("order_retreat", 150)
		units._dirty = true)
	_tools.add_child(back)
	_motivate_btn = _btn("", "")
	_motivate_btn.set_meta("audio_silent", true)
	_motivate_for = mine
	_motivate_btn.pressed.connect(func() -> void:
		var err := Military.motivate(World.player(), _motivate_for)
		if err != "":
			World.notify(tr(err), "bad")
		else:
			Audio.play("ui_confirm", 150)
		_sync_motivate())
	_tools.add_child(_motivate_btn)
	_sync_motivate()
	_build_split(mine)
	_tools.add_child(VSeparator.new())
	_tools.add_child(_stance)
	_sync_stance()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools.add_child(spacer)
	var dis := _btn(tr("DIV_DISBAND"), tr("TIP_DIV_DISBAND"))
	dis.add_theme_color_override("font_color", UiTheme.BAD.lightened(0.25))
	dis.pressed.connect(func() -> void:
		for d in mine.duplicate(): Military.disband(d)
		units.clear_selection())
	_tools.add_child(dis)

## Böl: seçili her figürden (bölgeden) sonraki emirle kaç tümen gidecek — 1, yarısı ya da hepsi. En düzenliler
## (bütünlüğü en yüksek) önce gider, kalanlar yerinde kalır. "Hepsi" o bölgelerde duran bütün tümenleri seçer.
func _build_split(mine: Array[Division]) -> void:
	var by := {}
	for d in mine:
		if not by.has(d.province):
			by[d.province] = []
		by[d.province].append(d)
	var all: Array[Division] = []
	for pid: int in by:
		for d: Division in Military.divisions_in(pid):
			if d.owner == World.player_tag and (d.path.is_empty() or d in mine):
				all.append(d)
	var biggest := 0
	for pid: int in by:
		biggest = maxi(biggest, (by[pid] as Array).size())
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	var sl := UiTheme.make_label(tr("DIV_SPLIT"), 13, UiTheme.TEXT_DIM)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seg.add_child(sl)
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	seg.add_child(gap)
	for pair: Array in [["DIV_SPLIT_ONE", 1], ["DIV_SPLIT_HALF", 2], ["DIV_SPLIT_ALL", 0]]:
		var mode: int = pair[1]
		var b := _btn(tr(pair[0]), tr("TIP_DIV_SPLIT"))
		b.set_meta("audio_silent", true)
		b.theme_type_variation = "Tab"
		b.disabled = (mode != 0 and biggest < 2) or (mode == 0 and all.size() <= mine.size())
		b.pressed.connect(func() -> void:
			if mode == 0:
				units.select_divisions(all, false)
				return
			var pick: Array[Division] = []
			for pid: int in by:
				var group: Array = (by[pid] as Array).duplicate()
				group.sort_custom(func(x: Division, y: Division) -> bool: return x.org > y.org)
				var k := 1 if mode == 1 else (group.size() + 1) / 2
				for i in mini(k, group.size()):
					pick.append(group[i])
			units.select_divisions(pick, false))
		seg.add_child(b)
	_tools.add_child(seg)

func _btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UiTheme.fs(14))
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
