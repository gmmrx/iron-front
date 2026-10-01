class_name AlertBar
extends HBoxContainer
## Üst bardaki kare uyarı kutucukları: oyuncunun ülkesine göre yapılması gerekenler,
## bekleyen olaylar, sorunlar. Kırmızı acil · sarı uyarı · mavi bilgi. Tıklayınca ilgili panel açılır.

const TILE := 62
const LEVEL_COLOR := {"urgent": Color(0.92, 0.3, 0.25), "warn": Color(0.95, 0.75, 0.25), "info": Color(0.45, 0.7, 0.95)}

var hud: Hud
var strip: Control                  ## üst çubuktaki şerit (uyarı yokken gizlenir)
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
			(c.get_meta("bar") as Control).modulate = Color(1, 1, 1, 0.45 + 0.55 * (0.5 + 0.5 * sin(_pulse * 4.0)))
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
	# sade oyun (docs/DESIGN.md): araştırma, program, üretim hattı, tersane, inşaat, konvoy, stok uçak ve yakıt uyarıları
	# yok (o ekranlar menüde değil); yerine asker alma ve boştaki kanat
	var cheapest := INF
	for u: Dictionary in Military.recruit_def()["units"].values():
		cheapest = minf(cheapest, float(u["sp"]))
	if c.sp >= cheapest:
		var cap := World.capital_province(c.tag)
		out.append(["recruit", "army", "info", tr("ALERT_RECRUIT"), tr("ALERT_RECRUIT_D") % int(c.sp), func() -> void: World.select_province(cap)])
	var idle_wings := 0
	for w in Air.wings_of(c.tag):
		if not w.on_mission():
			idle_wings += 1
	if idle_wings > 0:
		out.append(["wings", "air", "info", tr("ALERT_IDLE_WINGS"), tr("ALERT_IDLE_WINGS_D") % idle_wings, hud.toggle_air])
	var unsup := 0
	var total := 0
	for d in Military.country_divisions(c.tag):
		total += 1
		if not d.supplied:
			unsup += 1
	if unsup > 0:
		out.append(["supply", "army", "urgent", tr("ALERT_SUPPLY"), tr("ALERT_SUPPLY_D") % unsup, hud.toggle_army])
	if c.available_manpower() < 20000 and total > 0:
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
	if strip:
		strip.visible = not alerts.is_empty()

## Kutucuk: metal zeminde doğal renkli resim; seviye rengi altta ince çubuk (acil olan nabız atar)
func _tile(a: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.icon = UiTheme.trimmed(UiTheme.icon(a[1]))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", TILE - 8)
	for spec: Array in [["normal", "slot"], ["hover", "slot_gold"], ["pressed", "slot_gold"], ["hover_pressed", "slot_gold"]]:
		b.add_theme_stylebox_override(spec[0], UiTheme.skin(spec[1], 6, 3))
	b.add_theme_color_override("icon_hover_color", Color(1.2, 1.15, 1.05))
	var col: Color = LEVEL_COLOR[a[2]]
	var bar := ColorRect.new()
	bar.color = col
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 4
	bar.offset_right = -4
	bar.offset_top = -7
	bar.offset_bottom = -3
	b.add_child(bar)
	b.set_meta("bar", bar)
	b.tooltip_text = "%s\n%s" % [a[3], a[4]]
	if a[2] == "urgent":
		b.set_meta("urgent", true)
	var act: Callable = a[5]
	b.pressed.connect(func() -> void: act.call())
	return b
