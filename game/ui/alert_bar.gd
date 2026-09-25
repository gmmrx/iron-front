class_name AlertBar
extends HBoxContainer
## Üst bardaki kare uyarı kutucukları (türün klasik uyarıları gibi): oyuncunun ülkesine göre yapılması gerekenler,
## bekleyen olaylar, sorunlar. Kırmızı acil · sarı uyarı · mavi bilgi. Tıklayınca ilgili panel açılır.

const TILE := 44
const LEVEL_COLOR := {"urgent": Color(0.92, 0.3, 0.25), "warn": Color(0.95, 0.75, 0.25), "info": Color(0.45, 0.7, 0.95)}

var hud: Hud
var _timer := 0.0
var _key := ""
var _pulse := 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_pulse += delta
	for c in get_children():
		if c.has_meta("urgent"):
			(c as Control).modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(_pulse * 4.0))
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	if not World.in_game or World.player() == null:
		_rebuild([])
		return
	_rebuild(_collect(World.player()))

## [kimlik, simge, seviye, başlık, açıklama, eylem]
func _collect(c: Country) -> Array:
	var out: Array = []
	if not Politics.pending_events.is_empty():
		out.append(["event", "diplomacy", "urgent", tr("ALERT_EVENT"), tr("ALERT_EVENT_D") % Politics.pending_events.size(), func() -> void: hud.events._next()])
	if c.research_current.size() < c.research_slots:
		out.append(["research", "research", "urgent", tr("ALERT_RESEARCH"), tr("ALERT_RESEARCH_D") % (c.research_slots - c.research_current.size()), hud.toggle_research])
	if c.focus_current == "":
		out.append(["focus", "politics", "urgent", tr("ALERT_FOCUS"), tr("ALERT_FOCUS_D"), hud.toggle_focus])
	var free_mil := Economy.free_military(c)
	if free_mil > 0:
		out.append(["prod", "military_factory", "warn", tr("ALERT_PRODUCTION"), tr("ALERT_PRODUCTION_D") % free_mil, hud.toggle_production])
	var free_dock := Economy.free_military(c, true)
	if free_dock > 0:
		out.append(["dock", "building_dockyard", "warn", tr("ALERT_DOCKYARD"), tr("ALERT_DOCKYARD_D") % free_dock, hud.toggle_production])
	if c.construction_queue.is_empty():
		out.append(["build", "construction", "warn", tr("ALERT_CONSTRUCTION"), tr("ALERT_CONSTRUCTION_D"), hud.toggle_construction])
	var unsup := 0
	var total := 0
	for d in Military.country_divisions(c.tag):
		total += 1
		if not d.supplied:
			unsup += 1
	if unsup > 0:
		out.append(["supply", "army", "urgent", tr("ALERT_SUPPLY"), tr("ALERT_SUPPLY_D") % unsup, hud.toggle_army])
	if Diplomacy.at_war(c.tag) and Economy.convoy_factor(c) < 0.95:
		out.append(["convoy", "equipment_convoy", "warn", tr("ALERT_CONVOY"), tr("ALERT_CONVOY_D") % roundi(Economy.convoy_factor(c) * 100.0), hud.toggle_production])
	var planes := int(c.stockpile.get("fighter_equipment", 0.0)) + int(c.stockpile.get("cas_equipment", 0.0)) + int(c.stockpile.get("tactical_bomber_equipment", 0.0))
	if planes >= 20:
		out.append(["planes", "air", "info", tr("ALERT_PLANES"), tr("ALERT_PLANES_D") % planes, hud.toggle_air])
	if c.fuel >= 0.0 and c.fuel < c.fuel_cap * 0.1:
		out.append(["fuel", "equipment_convoy", "urgent", tr("ALERT_FUEL"), tr("ALERT_FUEL_D"), hud.toggle_trade])
	if c.recruitable_manpower() < 20000 and total > 0:
		out.append(["manpower", "manpower", "warn", tr("ALERT_MANPOWER"), tr("ALERT_MANPOWER_D"), hud.toggle_army])
	if Diplomacy.at_war(c.tag) and c.surrender_progress > 0.2:
		out.append(["surrender", "battle", "urgent", tr("ALERT_SURRENDER"), tr("ALERT_SURRENDER_D") % roundi(c.surrender_progress * 100.0), hud.toggle_diplomacy])
	return out

func _rebuild(alerts: Array) -> void:
	var key := ""
	for a: Array in alerts:
		key += "%s|%s|%s;" % [a[0], a[2], a[4]]
	if key == _key:
		return
	_key = key
	for ch in get_children():
		ch.queue_free()
	for a: Array in alerts:
		add_child(_tile(a))

func _tile(a: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = UiTheme.icon(a[1])
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 36)
	var col: Color = LEVEL_COLOR[a[2]]
	for st: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.07, 0.09, 0.92) if st == "normal" else Color(0.12, 0.13, 0.16, 0.95)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("icon_normal_color", col.lightened(0.35))
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.tooltip_text = "%s\n%s" % [a[3], a[4]]
	if a[2] == "urgent":
		b.set_meta("urgent", true)
	var act: Callable = a[5]
	b.pressed.connect(func() -> void: act.call())
	return b
