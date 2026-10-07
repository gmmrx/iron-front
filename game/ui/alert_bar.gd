class_name AlertBar
extends HBoxContainer
## Üst bardaki kare uyarı kutucukları: oyuncunun ülkesine göre yapılması gerekenler,
## bekleyen olaylar, sorunlar. Kırmızı acil · sarı uyarı · mavi bilgi. Tıklayınca ilgili panel açılır.

const TILE := 62
const LEVEL_COLOR := {"urgent": Color(0.92, 0.3, 0.25), "warn": Color(0.95, 0.75, 0.25), "info": Color(0.45, 0.7, 0.95)}
## Blink period / duration. Brief opacity dip, without disappearing or adding glow.
const ATTENTION_MIN_OPACITY := 0.45
const ATTENTION := {
	"urgent": Vector2(2.8, 0.5),
	"warn": Vector2(7.0, 0.5),
	"info": Vector2(12.0, 0.5),
}
const RECRUIT_ATTENTION := Vector2(20.0, 0.5)
## Notification-only artwork: do not change the icons in other menus/panels.
const ICON_IDS := ["event", "research", "construction", "recruit", "wings", "supply", "motivate", "manpower", "surrender"]
const ICON_DIR := "res://assets/ui/alerts_gold/"
static var _icons := {}

static func notification_icon(id: String, fallback: String = "diplomacy") -> Texture2D:
	if id not in ICON_IDS:
		return UiTheme.icon(fallback)
	if not _icons.has(id):
		_icons[id] = load(ICON_DIR + id + ".png")
	return _icons[id]

static func _tile_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TopBar.sheet("btn_square")
	style.set_texture_margin_all(10)
	style.set_content_margin_all(3)
	style.modulate_color = tint
	return style

var hud: Hud
var strip: Control                  ## üst çubuktaki şerit (uyarı yokken gizlenir)
var _timer := 0.0
var _key := ""
var _pulse := 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_animate_urgency(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	if not World.in_game or World.player() == null:
		_rebuild([])
		return
	_rebuild(_collect(World.player()))

func _animate_urgency(delta: float) -> void:
	_pulse += delta # Keep phase across text/count rebuilds; do not restart notifications every 0.5s.
	for tile in get_children():
		if tile.has_meta("attention"):
			_apply_attention(tile)

static func attention_profile(id: String, level: String) -> Vector2:
	# A future urgent recruit alert must still take precedence over the low-priority override.
	if id == "recruit" and level == "info":
		return RECRUIT_ATTENTION
	return ATTENTION.get(level, ATTENTION["info"])

static func attention_opacity(elapsed: float, profile: Vector2) -> float:
	var phase := fposmod(elapsed, profile.x)
	if phase >= profile.y:
		return 1.0
	var t := phase / profile.y
	if t < 0.5:
		return lerpf(1.0, ATTENTION_MIN_OPACITY, smoothstep(0.0, 0.5, t))
	return lerpf(ATTENTION_MIN_OPACITY, 1.0, smoothstep(0.5, 1.0, t))

func _apply_attention(tile: Button) -> void:
	var profile: Vector2 = tile.get_meta("attention")
	tile.modulate = Color(1.0, 1.0, 1.0, attention_opacity(_pulse, profile))

## [kimlik, simge, seviye, başlık, açıklama, eylem]
func _collect(c: Country) -> Array:
	var out: Array = []
	if not Politics.pending_events.is_empty():
		out.append(["event", "diplomacy", "urgent", tr("ALERT_EVENT"), tr("ALERT_EVENT_D") % Politics.pending_events.size(), func() -> void: hud.events._next()])
	# sade oyun (docs/DESIGN.md): uyarılar oyuncunun sıradaki işi (boş kalmasın): boş araştırma yuvası, asker almaya yeten
	# SP, çarpışan tümenleri teşvike yeten nüfuz, boştaki kanat, boş inşaat, ikmalsiz tümen (tıkla: seçilir). Program,
	# üretim hattı, konvoy ve yakıt uyarıları yok (o sistemler oyuncunun değil)
	var idle_slots := c.research_slots - c.research_current.size()
	if idle_slots > 0:
		out.append(["research", "research", "warn", tr("ALERT_RESEARCH"), tr("ALERT_RESEARCH_D") % idle_slots, hud.toggle_research])
	if Economy.CONSTRUCTION and c.construction_queue.is_empty() and Economy.available_civilian(c) > 0:
		out.append(["construction", "construction", "warn", tr("ALERT_CONSTRUCTION"), tr("ALERT_CONSTRUCTION_D"), hud.toggle_construction])
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
	var total := 0
	var fighting: Array = []
	var unsup: Array = []
	for d in Military.country_divisions(c.tag):
		total += 1
		if d.in_combat and d.training == 0 and not Military.motivated(d):
			fighting.append(d)
		if not d.supplied:
			unsup.append(d)
	if not unsup.is_empty():
		out.append(["supply", "army", "urgent", tr("ALERT_SUPPLY"), tr("ALERT_SUPPLY_D") % unsup.size(),
			func() -> void: hud.divisions_requested.emit(unsup)])
	var per := float(Military.motivate_def()["pp_per_division"])
	if not fighting.is_empty() and c.political_power >= per:
		out.append(["motivate", "political_power", "info", tr("ALERT_MOTIVATE"), tr("ALERT_MOTIVATE_D") % [fighting.size(), int(c.political_power)],
			func() -> void: hud.divisions_requested.emit(fighting)])
	if c.available_manpower() < 20000 and total > 0:
		var capm := World.capital_province(c.tag)
		out.append(["manpower", "manpower", "warn", tr("ALERT_MANPOWER"), tr("ALERT_MANPOWER_D"), func() -> void: World.select_province(capm)])
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

## Altın simge ve çerçeve korunur; önem rengi kutunun içinde hafif bir kaplama.
func _tile(a: Array) -> Button:
	var b := Button.new()
	Audio.ui_bind(b, "notification_open")
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.icon = notification_icon(a[0], a[1])
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", TILE - 8)
	for spec: Array in [["normal", Color.WHITE], ["hover", Color(1.15, 1.1, 1.02)],
			["pressed", Color(0.82, 0.79, 0.72)], ["hover_pressed", Color(0.9, 0.86, 0.78)]]:
		b.add_theme_stylebox_override(spec[0], _tile_style(spec[1]))
	b.add_theme_color_override("icon_hover_color", Color(1.08, 1.06, 1.02))
	var col: Color = LEVEL_COLOR[a[2]]
	var urgent: bool = a[2] == "urgent"
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(col, 0.08 if urgent else 0.04)
	wash.border_color = Color(col, 0.35 if urgent else 0.2)
	wash.set_border_width_all(1)
	wash.set_corner_radius_all(5)
	var overlay := Panel.new()
	overlay.name = "LevelOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", wash)
	b.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 5
	overlay.offset_top = 5
	overlay.offset_right = -5
	overlay.offset_bottom = -5
	b.set_meta("level_overlay", overlay)
	b.set_meta("attention", attention_profile(a[0], a[2]))
	b.tooltip_text = "%s\n%s" % [a[3], a[4]]
	if urgent:
		b.set_meta("urgent", true)
	_apply_attention(b)
	var act: Callable = a[5]
	b.pressed.connect(func() -> void: act.call())
	return b
