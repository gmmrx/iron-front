class_name TopBar
extends Control
## Üst bar: oyuncu ülkesi, temel göstergeler, tarih ve hız kontrolü.

var _flag: TextureRect
var _mini_flag: TextureRect
var _name: Label
var _leader: Label
var _pp: Label
var _stability: Label
var _war_support: Label
var _manpower: Label
var _factories: Label
var _fuel: Label
var _tension: Label
var _war: Label
var _date: Label
var _pause_label: Label
var _pips: Array[ColorRect] = []
var _pause_btn: Button
var _pause_icon: PlayPauseIcon
var _convoys: Label
var _supply: Label
var _command: Label
var _xp_army: Label
var _xp_navy: Label
var _xp_air: Label

## Yazı tipinde olmayan ▶ / ❚❚ glifleri yerine vektörel ikon
class PlayPauseIcon extends Control:
	var paused := true
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var col := UiTheme.ACCENT if paused else UiTheme.TEXT
		if paused:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -7), c + Vector2(7, 0), c + Vector2(-5, 7)]), col)
		else:
			draw_rect(Rect2(c + Vector2(-6, -7), Vector2(4, 14)), col)
			draw_rect(Rect2(c + Vector2(2, -7), Vector2(4, 14)), col)

## Türün klasiği düzeni: sol üstte blok — büyük çerçeveli bayrak; sağında üstte koyu metal şeritte gösterge hücreleri
## (sağda komuta/tecrübe grubu ayrı), altında bayrağa dayalı menü düğmeleri (HUD `task_row`a ekler). Tarih/hız sağ üstte ayrı.
var task_row: HBoxContainer
const FLAG_W := 100
const FLAG_H := 66

static func _metal(bg: Color, border: Color, radius: int = 3, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb

## Metal doku kutusu (arayüzün geri kalanıyla aynı set): margin doku kenarı, h/v iç boşluk
static func _tex(name: String, margin: int, h: int, v: int) -> StyleBoxTexture:
	var sb := UiTheme.skin(name, margin, v)
	sb.content_margin_left = h
	sb.content_margin_right = h
	return sb

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = 120
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.position = Vector2(8, 6)
	add_child(block)

	# --- bayrak: çift çerçeve (dış koyu metal, iç altın hat)
	var flag_frame := PanelContainer.new()
	flag_frame.add_theme_stylebox_override("panel", _tex("panel", 14, 6, 6))
	flag_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner := PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color.BLACK
	isb.border_color = UiTheme.BORDER
	isb.set_border_width_all(1)
	isb.set_content_margin_all(2)
	inner.add_theme_stylebox_override("panel", isb)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(FLAG_W, FLAG_H)
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_flag)
	# portre varsa bayrak köşede küçük
	_mini_flag = TextureRect.new()
	_mini_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini_flag.stretch_mode = TextureRect.STRETCH_SCALE
	_mini_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_flag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mini_flag.offset_left = -30
	_mini_flag.offset_top = -20
	_mini_flag.offset_right = -1
	_mini_flag.offset_bottom = -1
	_mini_flag.visible = false
	_flag.add_child(_mini_flag)
	flag_frame.add_child(inner)
	block.add_child(flag_frame)
	_name = UiTheme.make_label("", 12)      # yalnız ipucu metni için tutulur
	_leader = UiTheme.make_label("", 12)

	# --- bayrağın sağı: üstte gösterge şeridi, altta menü düğmeleri
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	block.add_child(right)

	var stats_line := HBoxContainer.new()
	stats_line.add_theme_constant_override("separation", 4)
	right.add_child(stats_line)
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _tex("strip", 12, 8, 4))
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_line.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	strip.add_child(row)

	_pp = _stat(row, ResourceIcon.Kind.POLITICAL_POWER, "UI_POLITICAL_POWER_TIP")
	_stability = _stat(row, ResourceIcon.Kind.STABILITY, "UI_STABILITY_TIP")
	_war_support = _stat(row, ResourceIcon.Kind.WAR_SUPPORT, "UI_WAR_SUPPORT_TIP")
	_manpower = _stat(row, ResourceIcon.Kind.MANPOWER, "UI_MANPOWER_TIP")
	_factories = _stat(row, ResourceIcon.Kind.FACTORY, "UI_FACTORIES_TIP")
	_fuel = _stat(row, ResourceIcon.Kind.FUEL, "UI_FUEL_TIP")
	_supply = _stat(row, ResourceIcon.Kind.SUPPLY, "UI_SUPPLY_TIP")
	_convoys = _stat(row, ResourceIcon.Kind.CONVOY, "UI_CONVOY_TIP")
	_tension = _stat(row, ResourceIcon.Kind.TENSION, "TIP_TENSION")
	_war = _stat(row, ResourceIcon.Kind.WAR, "TIP_AT_WAR_SHORT")
	_war.add_theme_color_override("font_color", UiTheme.BAD)
	_cell_of(_war).visible = false
	# ayrı kutu: komuta gücü + tecrübe (referanstaki sağ kutu)
	var strip2 := PanelContainer.new()
	strip2.add_theme_stylebox_override("panel", _tex("strip", 12, 8, 4))
	strip2.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_line.add_child(strip2)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 3)
	strip2.add_child(row2)
	_command = _stat(row2, ResourceIcon.Kind.COMMAND, "UI_COMMAND_TIP")
	_xp_army = _stat(row2, ResourceIcon.Kind.XP_ARMY, "UI_XP_ARMY_TIP")
	_xp_navy = _stat(row2, ResourceIcon.Kind.XP_NAVY, "UI_XP_NAVY_TIP")
	_xp_air = _stat(row2, ResourceIcon.Kind.XP_AIR, "UI_XP_AIR_TIP")

	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", _tex("strip", 12, 6, 4))
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(tray)
	task_row = HBoxContainer.new()
	task_row.add_theme_constant_override("separation", 3)
	tray.add_child(task_row)

	# --- tarih & hız: sağ üst köşe, ayrı panel
	var date_panel := PanelContainer.new()
	date_panel.add_theme_stylebox_override("panel", _tex("strip", 12, 10, 5))
	add_child(date_panel)
	date_panel.anchor_left = 1.0
	date_panel.anchor_right = 1.0
	date_panel.anchor_top = 0.0
	date_panel.anchor_bottom = 0.0
	date_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var place_date := func() -> void:
		date_panel.offset_right = -8
		date_panel.offset_left = -8 - date_panel.get_combined_minimum_size().x
		date_panel.offset_top = 6
		date_panel.offset_bottom = 6 + date_panel.get_combined_minimum_size().y
	date_panel.minimum_size_changed.connect(place_date)
	place_date.call_deferred()
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	date_panel.add_child(drow)
	_pause_btn = UiTheme.icon_button("play", tr("UI_PAUSE_TIP"), GameClock.toggle_pause, 32)
	drow.add_child(_pause_btn)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", -2)
	dcol.custom_minimum_size.x = 168
	_date = UiTheme.make_label("", 17)
	_date.add_theme_font_override("font", UiTheme.bold_font())
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcol.add_child(_date)
	var pips_row := HBoxContainer.new()
	pips_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_row.add_theme_constant_override("separation", 4)
	for i in GameClock.MAX_SPEED:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 6)
		pips_row.add_child(pip)
		_pips.append(pip)
	_pause_label = UiTheme.make_label(tr("UI_PAUSED"), 13, UiTheme.BAD)
	pips_row.add_child(_pause_label)
	dcol.add_child(pips_row)
	drow.add_child(dcol)
	drow.add_child(UiTheme.icon_button("minus", tr("TIP_SPEED_DOWN"), func() -> void: GameClock.change_speed(-1)))
	drow.add_child(UiTheme.icon_button("plus", tr("TIP_SPEED_UP"), func() -> void: GameClock.change_speed(1)))

	GameClock.hour_passed.connect(_update_date)
	GameClock.time_state_changed.connect(func(_s: int, _p: bool) -> void: _update_time_state())
	World.daily_update.connect(_update_country)
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _update_country())
	World.player_changed.connect(func(_t: String) -> void: _update_country())
	_update_country()
	_update_date()
	_update_time_state()

var _bars := {}   ## kind -> [arka, dolgu] (yakıt, ikmal)

func _stat(parent: Container, kind: ResourceIcon.Kind, tip_key: String) -> Label:
	var cell := PanelContainer.new()
	var sb := _tex("cell", 5, 7, 3)
	sb.content_margin_right = 10
	cell.add_theme_stylebox_override("panel", sb)
	cell.tooltip_text = tr(tip_key)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	if ResourceIcon.FILES.has(kind) and UiTheme.icon(ResourceIcon.FILES[kind]) != null:
		var icon := TextureRect.new()
		icon.texture = UiTheme.icon(ResourceIcon.FILES[kind])
		icon.custom_minimum_size = Vector2(28, 28)
		icon.modulate = Color(1.25, 1.2, 1.1)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
	else:
		var ri := ResourceIcon.new(kind)
		ri.custom_minimum_size = Vector2(27, 27)
		ri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(ri)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var l := UiTheme.make_label("", 17)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	if kind in [ResourceIcon.Kind.FUEL, ResourceIcon.Kind.SUPPLY]:
		var back := ColorRect.new()
		back.color = Color(0, 0, 0, 0.6)
		back.custom_minimum_size = Vector2(46, 4)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = UiTheme.GOOD
		fill.size = Vector2(46, 4)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(fill)
		col.add_child(back)
		_bars[kind] = [back, fill]
	parent.add_child(cell)
	return l

func _set_bar(kind: ResourceIcon.Kind, ratio: float) -> void:
	if not _bars.has(kind):
		return
	var fill: ColorRect = _bars[kind][1]
	fill.size.x = 46.0 * clampf(ratio, 0.0, 1.0)
	fill.color = UiTheme.GOOD if ratio > 0.5 else (Color(0.9, 0.75, 0.3) if ratio > 0.2 else UiTheme.BAD)

func _cell_of(l: Label) -> Control:
	return l.get_parent().get_parent().get_parent()

func _update_country() -> void:
	var c := World.player()
	if c == null:
		return
	var por := UiTheme.portrait(c)
	if por:
		_flag.texture = por
		_flag.custom_minimum_size = Vector2(FLAG_H * 0.8, FLAG_H)
		_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_mini_flag.texture = FlagFactory.get_flag(c)
		_mini_flag.visible = true
	else:
		_flag.texture = FlagFactory.get_flag(c)
		_flag.custom_minimum_size = Vector2(FLAG_W, FLAG_H)
		_flag.stretch_mode = TextureRect.STRETCH_SCALE
		_mini_flag.visible = false
	_name.text = c.display_name()
	_flag.get_parent().tooltip_text = tr("TIP_COUNTRY") % [c.display_name(), c.leader, tr("IDEOLOGY_" + c.ideology), UiTheme.format_number(c.population), c.states.size()]
	_leader.text = "%s — %s" % [c.leader, tr("IDEOLOGY_" + c.ideology)]
	_pp.text = "%d" % int(c.political_power)
	_cell_of(_pp).tooltip_text = tr("TIP_POLITICAL_POWER") % [c.daily_political_power_gain()]
	var stab := Politics.stability(c)
	var ws := Politics.war_support(c)
	_stability.text = "%d%%" % roundi(stab * 100)
	_war_support.text = "%d%%" % roundi(ws * 100)
	_stability.add_theme_color_override("font_color", UiTheme.BAD if stab < 0.3 else UiTheme.TEXT)
	var sg := func(v: float) -> String: return ("+" if v >= 0 else "") + "%d%%" % roundi(v * 100)
	_cell_of(_stability).tooltip_text = tr("POL_STAB_BREAKDOWN") % [roundi(c.stability * 100), sg.call(c.mod("stability")), sg.call(Politics.party_stability_bonus(c)),
		roundi(stab * 100), sg.call(Politics.stability_factory_mod(c)), sg.call(Politics.stability_pp_mod(c))]
	_cell_of(_war_support).tooltip_text = tr("POL_WS_BREAKDOWN") % [roundi(c.war_support * 100), sg.call(c.mod("war_support")), sg.call(Politics.tension_war_support()),
		sg.call(Politics.war_state_support(c)), roundi(ws * 100), roundi(Diplomacy.capitulation_threshold(c) * 100)]
	_cell_of(_manpower).tooltip_text = tr("TIP_MANPOWER") % [UiTheme.format_number(c.recruitable_manpower()), Economy.law_name("conscription", c.laws["conscription"])]
	_manpower.text = UiTheme.format_number(c.recruitable_manpower())
	_factories.text = "%d / %d" % [Economy.count(c, "civilian_factory"), Economy.count(c, "military_factory")]
	var tip := tr("UI_FACTORIES_TIP") + "\n" + tr("CONSTRUCTION_SUMMARY") % [Economy.count(c, "civilian_factory"), Economy.consumer_goods_factories(c), Economy.available_civilian(c)]
	tip += "\n" + Economy.building_name("dockyard") + ": %d" % Economy.count(c, "dockyard")
	for r: String in Economy.resource_names:
		var n := Economy.resource_total(c, r)
		if n > 0:
			tip += "\n%s: %d" % [tr("RES_" + r), n]
	_cell_of(_factories).tooltip_text = tip
	var fcap := maxf(c.fuel_cap, 1.0)
	_fuel.text = "%d%%" % roundi(maxf(c.fuel, 0.0) / fcap * 100.0)
	_set_bar(ResourceIcon.Kind.FUEL, maxf(c.fuel, 0.0) / fcap)
	_fuel.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3) if c.fuel <= fcap * 0.1 and c.fuel >= 0.0 else UiTheme.TEXT)
	_cell_of(_fuel).tooltip_text = tr("UI_FUEL_TIP") + "\n" + tr("UI_FUEL_DETAIL") % [UiTheme.format_number(roundi(maxf(c.fuel, 0.0))), UiTheme.format_number(roundi(fcap))]
	# ikmal doluluğu: ikmalli tümen oranı
	var divs := Military.country_divisions(c.tag)
	var sup := 0
	for d in divs:
		if d.supplied:
			sup += 1
	var sup_pct := 100 if divs.is_empty() else roundi(100.0 * sup / divs.size())
	_supply.text = "%d%%" % sup_pct
	_set_bar(ResourceIcon.Kind.SUPPLY, sup_pct / 100.0)
	_supply.add_theme_color_override("font_color", UiTheme.BAD if sup_pct < 80 else UiTheme.TEXT)
	_cell_of(_supply).tooltip_text = tr("UI_SUPPLY_TIP") + "\n" + tr("UI_SUPPLY_DETAIL") % [sup, divs.size()]
	# konvoylar: stok / ithalat ihtiyacı
	var conv := int(c.stockpile.get("convoy", 0.0))
	var need := 0.0
	for i: Dictionary in c.imports:
		need += float(i["amount"]) * 0.5
	_convoys.text = "%d" % conv
	_convoys.add_theme_color_override("font_color", UiTheme.BAD if float(conv) < need else UiTheme.TEXT)
	_cell_of(_convoys).tooltip_text = tr("UI_CONVOY_TIP") + "\n" + tr("UI_CONVOY_DETAIL") % [conv, ceili(need)]
	_command.text = "%d" % int(c.command_power)
	_cell_of(_command).tooltip_text = tr("UI_COMMAND_TIP") % (0.5 if Diplomacy.at_war(c.tag) else 0.3)
	_xp_army.text = "%d" % int(c.army_xp)
	_xp_navy.text = "%d" % int(c.navy_xp)
	_xp_air.text = "%d" % int(c.air_xp)
	_tension.text = "%d%%" % roundi(World.world_tension)
	if Diplomacy.at_war(c.tag):
		var foes := Diplomacy.enemies_of(c.tag)
		_cell_of(_war).visible = true
		_war.text = "%d · %d%%" % [foes.size(), roundi(c.surrender_progress * 100)]
		_cell_of(_war).tooltip_text = tr("TIP_AT_WAR") % [", ".join(foes.map(func(t: String) -> String: return World.countries[t].display_name())), roundi(Diplomacy.capitulation_threshold(c) * 100)]
	else:
		_cell_of(_war).visible = false

func _update_date() -> void:
	_date.text = GameClock.date_string()

func _update_time_state() -> void:
	for i in _pips.size():
		var on := i < GameClock.speed
		_pips[i].color = (UiTheme.ACCENT if not GameClock.paused else UiTheme.TEXT_DIM) if on else Color(1, 1, 1, 0.12)
	_pause_label.visible = GameClock.paused
	_pause_btn.icon = UiTheme.icon("play" if GameClock.paused else "pause")
