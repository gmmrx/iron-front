class_name MapIconLayer
extends Node3D
## Uzak zoom'da stratejik şehir ve hava üssü ikonları. Limanlar gerçek 3D kıyı tesisidir.
## Yaklaşınca ikonlar söner, ayrıntılı 3D dioramalar belirir.

## (başlangıç, bitiş) kamera mesafesi. Yaklaşırken önce birlik bayrakları (UnitLayer.HIDE_ALL), sonra başkent yıldızı ve
## şehir, en son liman ve hava üssü ikonları belirir; kıta görünümünde hiçbiri yok (sade)
const AIR_RANGE := Vector2(380.0, 1000.0)
const CAPITAL_END := 1600.0                    ## (eski) başkent yıldızı; başkentte artık işaret yok, adı sarı yazar
const DOT_PX := 5.0                            ## şehir noktasının ekran boyu (1080p): sade, küçük
static var _dot: Texture2D

var map: MapView3D
var _air_tex: Texture2D
var _city_tex: Texture2D
var _capital_tex: Texture2D
var _air_nodes := {}   ## eyalet -> düğüm
var _port_nodes := {}  ## eski API uyumu; 3D PortLayer varken liman sprite'ı oluşturulmaz
var _fog_seen := -1

func _ready() -> void:
	_air_tex = preload("res://assets/ui/map/airbase.svg")
	_city_tex = preload("res://assets/ui/map/city.svg")
	_capital_tex = preload("res://assets/ui/map/capital.svg")
	for c: City in World.cities:
		if not c.is_capital and c.victory_points >= 3:   # başkentte işaret yok: sarı adı yeter
			_add_city(c)
	if Economy.SHOW_BUILDINGS:
		for sid: int in map.airbase_sites:
			_add_airbase(sid)
	Economy.building_completed.connect(func(_t: String, sid: int, b: String) -> void:
		if b == "air_base" and map.airbase_sites.has(sid) and Economy.SHOW_BUILDINGS:
			if _air_nodes.has(sid):
				_air_nodes[sid].queue_free()
			_add_airbase(sid))

## Savaş sisi: bulutun altındaki hava üssü ikonları gizli (şehir işaretleri kalır).
func _process(_d: float) -> void:
	if _fog_seen == Military.fog_version:
		return
	_fog_seen = Military.fog_version
	for sid: int in _air_nodes:
		(_air_nodes[sid] as Node3D).visible = not Military.state_fogged(World.states.get(sid))

func _add_airbase(sid: int) -> void:
	var st: StateRegion = World.states[sid]
	var pos: Vector2 = map.airbase_sites[sid][0]
	_air_nodes[sid] = _add_icon(_air_tex, pos, st.building_level("air_base"), AIR_RANGE, "")

func _add_city(c: City) -> void:
	var begin := PinLayer.city_range(c)           # yakında şehir minyatürü gelince nokta söner
	var tex := dot_texture()
	# uzaktan yalnız önemli şehirler; yanında daha önemli şehir varsa ancak ondan ayrılınca (adıyla aynı)
	var end := minf(minf(1300.0 if c.victory_points >= 10 else 1000.0, CityLayer3D.LABEL_RANGE[CityLayer.tier_of(c)]),
		CityLayer3D.spacing_range(c))
	if end <= begin * 1.2:
		return                                    # minyatürden önce hiç ayrılmıyor: nokta gereksiz
	var root := _add_icon(tex, c.position, 0, Vector2(begin, end), c.display_name())
	var sprite := root.get_child(0) as Sprite3D
	sprite.pixel_size = DOT_PX / (float(tex.get_width()) * UnitLayer.PX)

## Şehir işareti: küçük fildişi nokta, ince koyu kenarlı (doku 4 kat çözünürlükte, kenarı yumuşak)
static func dot_texture() -> Texture2D:
	if _dot == null:
		var n := 20
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var r := n * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
				var col := CityLayer.TEXT_COLOR if d < r - 4.0 else Color(0.05, 0.05, 0.04)
				col.a = clampf(r - 0.5 - d, 0.0, 1.0)
				img.set_pixel(x, y, col)
		_dot = ImageTexture.create_from_image(img)
	return _dot

func _add_icon(tex: Texture2D, pos: Vector2, level: int, rng: Vector2, _tip: String) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(pos.x, maxf(map.height_at(pos), 0.0) + 4.0, pos.y)
	add_child(root)
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.pixel_size = 0.00016 * UiTheme.px_scale(tex, 154.0)
	# Compact cartographic symbols sit on their actual map position.
	s.offset = Vector2.ZERO
	s.no_depth_test = true
	s.render_priority = 6
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_range(s, rng)
	root.add_child(s)
	if level > 0:
		var l := Label3D.new()
		l.text = str(level)
		l.font = UiTheme.bold_font()
		l.font_size = 30
		l.outline_size = 10
		l.modulate = Color("f6e2a4")
		l.outline_modulate = Color(0.05, 0.05, 0.04, 1)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0005
		l.offset = Vector2(20, -16)
		l.no_depth_test = true
		l.render_priority = 7
		l.outline_render_priority = 6
		# seviye sayısı yalnız orta zoom'da: uzakta haritada sayı kalmasın (birlikler de bayrağa döner)
		_range(l, Vector2(rng.x, minf(rng.y, UnitLayer.FLAG_MODE)))
		root.add_child(l)
	return root

func _range(g: GeometryInstance3D, rng: Vector2) -> void:
	g.visibility_range_begin = rng.x
	g.visibility_range_begin_margin = rng.x * 0.25
	g.visibility_range_end = rng.y
	g.visibility_range_end_margin = rng.y * 0.1
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
