class_name DivisionPanel
extends PanelContainer
## Seçili tümenler (alt orta): liste, durum, durdur / dağıt.

var units: UnitLayer
var _title: Label
var _list: VBoxContainer
var _timer := 0.0
var _army_row: HBoxContainer
var _army_key := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -14
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	_title = UiTheme.make_label("", 20, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.bold_font())
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var stop := Button.new()
	stop.text = tr("DIV_STOP")
	stop.tooltip_text = tr("TIP_DIV_STOP")
	stop.focus_mode = Control.FOCUS_NONE
	stop.pressed.connect(func() -> void:
		for d in units.selected: Military.stop(d)
		units._dirty = true)
	head.add_child(stop)
	var dis := Button.new()
	dis.text = tr("DIV_DISBAND")
	dis.tooltip_text = tr("TIP_DIV_DISBAND")
	dis.focus_mode = Control.FOCUS_NONE
	dis.pressed.connect(func() -> void:
		for d in units.selected.duplicate(): Military.disband(d)
		units.clear_selection())
	head.add_child(dis)
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), func() -> void: units.clear_selection()))
	v.add_child(head)
	_army_row = HBoxContainer.new()
	_army_row.add_theme_constant_override("separation", 8)
	v.add_child(_army_row)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	v.add_child(_list)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.25:
		return
	_timer = 0.0
	units.prune_selection()
	visible = not units.selected.is_empty()
	if visible:
		_refresh()

## Ordu satırı: ortak ordu yoksa "Ordu kur"; hepsi aynı ordudaysa cephe seçimi, savun/taarruz, orduyu seç, dağıt
func _refresh_army(sel: Array) -> void:
	var common := -1
	for d: Division in sel:
		if common == -1:
			common = d.army
		elif common != d.army:
			common = -2
	var a: Army = Military.army_by_id(common) if common > 0 else null
	var key := "%d:%d:%s:%d" % [sel.size(), common, a.enemy if a else "", int(a.mode) if a else -1]
	if key == _army_key:
		return
	_army_key = key
	for ch in _army_row.get_children():
		ch.queue_free()
	var mine := sel.filter(func(d: Division) -> bool: return d.owner == World.player_tag)
	if mine.is_empty():
		return
	if a == null:
		var b := _btn(tr("ARMY_CREATE"), tr("TIP_ARMY_CREATE"))
		b.pressed.connect(func() -> void:
			Military.create_army(World.player_tag, mine)
			_army_key = "")
		_army_row.add_child(b)
		return
	var name := UiTheme.make_label(a.name, 16, a.color)
	name.add_theme_font_override("font", UiTheme.bold_font())
	_army_row.add_child(name)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.tooltip_text = tr("TIP_ARMY_FRONT")
	opt.add_item(tr("ARMY_NO_FRONT"))
	var tags := _front_candidates()
	for i in tags.size():
		opt.add_item(World.countries[tags[i]].display_name())
		if tags[i] == a.enemy:
			opt.select(i + 1)
	opt.item_selected.connect(func(idx: int) -> void:
		a.enemy = tags[idx - 1] if idx > 0 else ""
		Military.armies_changed.emit()
		_army_key = "")
	_army_row.add_child(opt)
	var hold := _btn(tr("ARMY_HOLD"), tr("TIP_ARMY_HOLD"))
	hold.toggle_mode = true
	hold.button_pressed = a.mode == Army.Mode.HOLD
	hold.pressed.connect(func() -> void:
		a.mode = Army.Mode.HOLD
		_army_key = "")
	_army_row.add_child(hold)
	var atk := _btn(tr("ARMY_ATTACK"), tr("TIP_ARMY_ATTACK"))
	atk.toggle_mode = true
	atk.button_pressed = a.mode == Army.Mode.ATTACK
	atk.pressed.connect(func() -> void:
		a.mode = Army.Mode.ATTACK
		_army_key = "")
	_army_row.add_child(atk)
	var sel_all := _btn(tr("ARMY_SELECT"), tr("TIP_ARMY_SELECT"))
	sel_all.pressed.connect(func() -> void: units.select_divisions(Military.army_divisions(a), false))
	_army_row.add_child(sel_all)
	var dis := _btn(tr("ARMY_DISBAND"), tr("TIP_ARMY_DISBAND"))
	dis.pressed.connect(func() -> void:
		Military.disband_army(a)
		_army_key = "")
	_army_row.add_child(dis)

func _btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b

## Cephe adayları: savaştığımız ülkeler, savaş hedeflerimiz ve kara komşularımız
func _front_candidates() -> Array[String]:
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

func _refresh() -> void:
	var sel := units.selected
	_refresh_army(sel)
	_title.text = tr("DIV_SELECTED") % sel.size()
	for ch in _list.get_children():
		ch.queue_free()
	for i in mini(sel.size(), 10):
		var d: Division = sel[i]
		var s := Military.div_stats(d)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var n := UiTheme.make_label(d.name, 15)
		n.custom_minimum_size.x = 210
		n.clip_text = true
		row.add_child(n)
		row.add_child(_bar(d.org / maxf(s["org"], 1.0), Color(0.45, 0.85, 0.35), tr("TIP_ORG") % [int(d.org), int(s["org"])]))
		row.add_child(_bar(d.strength, Color(0.95, 0.78, 0.3), tr("TIP_STR") % roundi(d.strength * 100)))
		# tecrübe (mor) ve planlama (mavi)
		var lvl := d.xp_level()
		row.add_child(_bar(d.xp, Color(0.72, 0.5, 0.95), tr("DIV_XP_LINE") % [tr("DIV_XP_%d" % lvl), roundi((d.xp_mult() - 1.0) * 100.0)]))
		row.add_child(_bar(d.planning, Color(0.4, 0.7, 1.0), tr("DIV_PLANNING_LINE") % roundi(d.planning * 20.0)))
		var status := tr("DIV_TRAINING") % d.training if d.training > 0 else (tr("DIV_COMBAT") if d.in_combat else (tr("DIV_MOVING") if d.is_moving() else tr("DIV_IDLE")))
		if not d.supplied:
			status += " · " + tr("DIV_NO_SUPPLY")
		row.add_child(UiTheme.make_label(status, 14, UiTheme.BAD if not d.supplied or d.in_combat else UiTheme.TEXT_DIM))
		_list.add_child(row)
	if sel.size() > 10:
		_list.add_child(UiTheme.make_label(tr("DIV_MORE") % (sel.size() - 10), 14, UiTheme.TEXT_DIM))

func _bar(v: float, col: Color, tip: String) -> Control:
	var b := ProgressBar.new()
	b.max_value = 1.0
	b.value = clampf(v, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(90, 8)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var f := StyleBoxFlat.new()
	f.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", bg)
	b.tooltip_text = tip
	return b
