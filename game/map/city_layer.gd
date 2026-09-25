class_name CityLayer
extends Node2D
## Şehir ikonları ve adları. Ekranda sabit boyutta çizilir; önem sırasına göre
## zoom'la kademeli belirir ve üst üste binen adlar gizlenir.

const TIER_MIN_ZOOM: Array[float] = [0.3, 0.55, 0.8, 1.3, 2.2]   ## başkent, VP≥10, VP≥3, VP≥1, diğer
const NAME_SIZE := 15
const CAPITAL_NAME_SIZE := 17
const TEXT_COLOR := Color(0.98, 0.96, 0.9)
const OUTLINE := Color(0.04, 0.04, 0.03, 0.85)
const CAPITAL_COLOR := Color("f0c75e")
const PORT_COLOR := Color("8fc3e8")

var _font: Font
var _bold: Font
var _visible: Array[City] = []
var _last_zoom := -1.0

func _ready() -> void:
	_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	_bold = UiTheme.bold_font()

func _process(_delta: float) -> void:
	var z := get_viewport().get_canvas_transform().x.x
	if not is_equal_approx(z, _last_zoom):
		_last_zoom = z
		_relayout()
		queue_redraw()

static func tier_of(c: City) -> int:
	if c.is_capital: return 0
	if c.victory_points >= 10: return 1
	if c.victory_points >= 3: return 2
	if c.victory_points >= 1: return 3
	return 4

## Görünür şehirleri seç: önemli olan önce yerleşir, çakışan sonrakiler atlanır.
func _relayout() -> void:
	_visible.clear()
	var z := _last_zoom
	var candidates: Array[City] = []
	for c in World.cities:
		if z >= TIER_MIN_ZOOM[tier_of(c)]:
			candidates.append(c)
	candidates.sort_custom(func(a: City, b: City) -> bool:
		var ta := tier_of(a)
		var tb := tier_of(b)
		return ta < tb if ta != tb else a.population > b.population)
	var cell := 120.0 / z
	var grid := {}
	for c in candidates:
		var r := _screen_rect(c)
		var world_r := Rect2(c.position + r.position / z, r.size / z)
		var x0 := int(floor(world_r.position.x / cell))
		var x1 := int(floor(world_r.end.x / cell))
		var y0 := int(floor(world_r.position.y / cell))
		var y1 := int(floor(world_r.end.y / cell))
		var hit := false
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				for other: Rect2 in grid.get(Vector2i(gx, gy), []):
					if other.intersects(world_r):
						hit = true
						break
				if hit: break
			if hit: break
		if hit:
			continue
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(world_r)
		_visible.append(c)

## İkon + ad kutusu, ekran pikseli cinsinden (şehir noktasına göre)
func _screen_rect(c: City) -> Rect2:
	var size := CAPITAL_NAME_SIZE if c.is_capital else NAME_SIZE
	var f := _bold if c.is_capital else _font
	var w := f.get_string_size(c.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return Rect2(Vector2(-8, -size * 0.6), Vector2(w + 22, size * 1.2))

func _draw() -> void:
	var z := maxf(_last_zoom, 1e-4)
	var s := 1.0 / z
	for c in _visible:
		draw_set_transform(c.position, 0.0, Vector2(s, s))
		if c.is_capital:
			draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.65))
			draw_colored_polygon(FlagFactory._star(Vector2.ZERO, 7.0, 3.0), CAPITAL_COLOR)
		else:
			var col := PORT_COLOR if c.is_port else TEXT_COLOR
			var half := 3.5 if c.victory_points >= 3 else 2.5
			draw_rect(Rect2(-half - 1.2, -half - 1.2, (half + 1.2) * 2, (half + 1.2) * 2), OUTLINE)
			draw_rect(Rect2(-half, -half, half * 2, half * 2), col)
		var size := CAPITAL_NAME_SIZE if c.is_capital else NAME_SIZE
		var f := _bold if c.is_capital else _font
		var pos := Vector2(11, size * 0.35)
		draw_string_outline(f, pos, c.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, OUTLINE)
		draw_string(f, pos, c.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, CAPITAL_COLOR if c.is_capital else TEXT_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
