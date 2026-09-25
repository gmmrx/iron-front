class_name TopBar
extends PanelContainer
## Üst bar: oyuncu ülkesi, temel göstergeler, tarih ve hız kontrolü.

var _flag: TextureRect
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = 58
	var sb := UiTheme.textured("topbar", 10, 8)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.content_margin_left = 10
	add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	# --- ülke
	var flag_frame := PanelContainer.new()
	var fsb := UiTheme.panel_style(Color.BLACK, UiTheme.ACCENT)
	fsb.set_content_margin_all(1)
	fsb.shadow_size = 0
	flag_frame.add_theme_stylebox_override("panel", fsb)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(66, 44)
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	flag_frame.add_child(_flag)
	flag_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag_frame)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", -4)
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.custom_minimum_size.x = 230
	_name = UiTheme.make_label("", 22, UiTheme.ACCENT)
	_name.add_theme_font_override("font", UiTheme.title_font())
	_leader = UiTheme.make_label("", 15, UiTheme.TEXT_DIM)
	name_box.add_child(_name)
	name_box.add_child(_leader)
	row.add_child(name_box)
	row.add_child(VSeparator.new())

	# --- göstergeler
	_pp = _stat(row, ResourceIcon.Kind.POLITICAL_POWER, "UI_POLITICAL_POWER_TIP")
	_stability = _stat(row, ResourceIcon.Kind.STABILITY, "UI_STABILITY_TIP")
	_war_support = _stat(row, ResourceIcon.Kind.WAR_SUPPORT, "UI_WAR_SUPPORT_TIP")
	_manpower = _stat(row, ResourceIcon.Kind.MANPOWER, "UI_MANPOWER_TIP")
	_factories = _stat(row, ResourceIcon.Kind.FACTORY, "UI_FACTORIES_TIP")
	_factories.custom_minimum_size.x = 70
	_fuel = _stat(row, ResourceIcon.Kind.FUEL, "UI_FUEL_TIP")

	_tension = UiTheme.make_label("", 18, UiTheme.TEXT)
	_tension.add_theme_font_override("font", UiTheme.bold_font())
	_tension.mouse_filter = Control.MOUSE_FILTER_STOP
	_tension.tooltip_text = tr("TIP_TENSION")
	row.add_child(_tension)
	_war = UiTheme.make_label("", 18, UiTheme.BAD)
	_war.add_theme_font_override("font", UiTheme.bold_font())
	_war.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(_war)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# --- tarih & hız
	var date_panel := PanelContainer.new()
	date_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0, 0, 0, 0.35), UiTheme.BORDER_DIM))
	date_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(date_panel)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 10)
	date_panel.add_child(drow)

	_pause_btn = UiTheme.icon_button("play", tr("UI_PAUSE_TIP"), GameClock.toggle_pause, 34)
	drow.add_child(_pause_btn)

	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", -2)
	dcol.custom_minimum_size.x = 190
	_date = UiTheme.make_label("", 20)
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

func _stat(parent: Container, kind: ResourceIcon.Kind, tip_key: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.tooltip_text = tr(tip_key)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceIcon.FILES.has(kind):
		var icon := TextureRect.new()
		icon.texture = UiTheme.icon(ResourceIcon.FILES[kind])
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	else:
		box.add_child(ResourceIcon.new(kind))   # simge dosyası yoksa vektörel çizim
	var l := UiTheme.make_label("", 20)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.custom_minimum_size.x = 64
	box.add_child(l)
	parent.add_child(box)
	return l

func _update_country() -> void:
	var c := World.player()
	if c == null:
		return
	_flag.texture = FlagFactory.get_flag(c)
	_name.text = c.display_name()
	_flag.get_parent().tooltip_text = tr("TIP_COUNTRY") % [c.display_name(), c.leader, tr("IDEOLOGY_" + c.ideology), UiTheme.format_number(c.population), c.states.size()]
	_leader.text = "%s — %s" % [c.leader, tr("IDEOLOGY_" + c.ideology)]
	_pp.text = "%d" % int(c.political_power)
	_pp.get_parent().tooltip_text = tr("TIP_POLITICAL_POWER") % [c.daily_political_power_gain()]
	_stability.text = "%d%%" % roundi(c.stability * 100)
	_war_support.text = "%d%%" % roundi(c.war_support * 100)
	_stability.get_parent().tooltip_text = tr("TIP_STABILITY")
	_war_support.get_parent().tooltip_text = tr("TIP_WAR_SUPPORT")
	_manpower.get_parent().tooltip_text = tr("TIP_MANPOWER") % [UiTheme.format_number(c.recruitable_manpower()), Economy.law_name("conscription", c.laws["conscription"])]
	_manpower.text = UiTheme.format_number(c.recruitable_manpower())
	_factories.text = "%d / %d" % [Economy.count(c, "civilian_factory"), Economy.count(c, "military_factory")]
	var tip := tr("UI_FACTORIES_TIP") + "\n" + tr("CONSTRUCTION_SUMMARY") % [Economy.count(c, "civilian_factory"), Economy.consumer_goods_factories(c), Economy.available_civilian(c)]
	tip += "\n" + Economy.building_name("dockyard") + ": %d" % Economy.count(c, "dockyard")
	for r: String in Economy.resource_names:
		var n := Economy.resource_total(c, r)
		if n > 0:
			tip += "\n%s: %d" % [tr("RES_" + r), n]
	_factories.get_parent().tooltip_text = tip
	var fcap := maxf(c.fuel_cap, 1.0)
	_fuel.text = "%d%%" % roundi(maxf(c.fuel, 0.0) / fcap * 100.0)
	_fuel.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3) if c.fuel <= fcap * 0.1 and c.fuel >= 0.0 else UiTheme.TEXT)
	_fuel.get_parent().tooltip_text = tr("UI_FUEL_TIP") + "\n" + tr("UI_FUEL_DETAIL") % [UiTheme.format_number(roundi(maxf(c.fuel, 0.0))), UiTheme.format_number(roundi(fcap))]
	_tension.text = tr("TOP_TENSION") % roundi(World.world_tension)
	if Diplomacy.at_war(c.tag):
		var foes := Diplomacy.enemies_of(c.tag)
		_war.text = tr("TOP_AT_WAR") % [foes.size(), roundi(c.surrender_progress * 100)]
		_war.tooltip_text = tr("TIP_AT_WAR") % [", ".join(foes.map(func(t: String) -> String: return World.countries[t].display_name())), roundi(Diplomacy.capitulation_threshold(c) * 100)]
	else:
		_war.text = ""

func _update_date() -> void:
	_date.text = GameClock.date_string()

func _update_time_state() -> void:
	for i in _pips.size():
		var on := i < GameClock.speed
		_pips[i].color = (UiTheme.ACCENT if not GameClock.paused else UiTheme.TEXT_DIM) if on else Color(1, 1, 1, 0.12)
	_pause_label.visible = GameClock.paused
	_pause_btn.icon = UiTheme.icon("play" if GameClock.paused else "pause")
