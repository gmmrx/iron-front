class_name MapIconLayer
extends Node3D
## Uzak zoom'da stratejik şehir, liman ve hava üssü ikonları.
## Yaklaşınca ikonlar söner, ayrıntılı 3D dioramalar belirir.

const PORT_RANGE := Vector2(560.0, 2300.0)      ## (başlangıç, bitiş) kamera mesafesi
const AIR_RANGE := Vector2(760.0, 2300.0)

var map: MapView3D
var _port_tex: Texture2D
var _air_tex: Texture2D
var _city_tex: Texture2D
var _capital_tex: Texture2D
var _air_nodes := {}   ## eyalet -> düğüm

func _ready() -> void:
	_port_tex = UiTheme.icon("map_port")
	_air_tex = UiTheme.icon("map_airbase")
	_city_tex = UiTheme.icon("map_city")
	_capital_tex = UiTheme.icon("map_capital")
	var seen := {}
	for c: City in World.cities:
		if c.is_capital or c.victory_points >= 3:
			_add_city(c)
		if c.is_port and not seen.has(c.state_id):
			seen[c.state_id] = true
			var st: StateRegion = World.states.get(c.state_id)
			var lvl := st.building_level("naval_base") if st else 0
			_add_icon(_port_tex, c.position + Vector2(0, 7), lvl, PORT_RANGE, tr("MAPICON_PORT") % [c.display_name(), lvl])
	for sid: int in map.airbase_sites:
		_add_airbase(sid)
	Economy.building_completed.connect(func(_t: String, sid: int, b: String) -> void:
		if b == "air_base" and map.airbase_sites.has(sid):
			if _air_nodes.has(sid):
				_air_nodes[sid].queue_free()
			_add_airbase(sid))

func _add_airbase(sid: int) -> void:
	var st: StateRegion = World.states[sid]
	var pos: Vector2 = map.airbase_sites[sid][0]
	_air_nodes[sid] = _add_icon(_air_tex, pos, st.building_level("air_base"), AIR_RANGE, "")

func _add_city(c: City) -> void:
	var begin := 1300.0 if c.is_capital else (900.0 if c.victory_points >= 10 else 640.0)
	var tex := _capital_tex if c.is_capital else _city_tex
	# uzaktan yalnız önemli şehirler (dünya haritasında binlerce şehir var)
	var end := 7000.0 if c.is_capital else (3200.0 if c.victory_points >= 10 else 1900.0)
	var root := _add_icon(tex, c.position, 0, Vector2(begin, end), c.display_name())
	var sprite := root.get_child(0) as Sprite3D
	sprite.pixel_size = 0.00022 if c.is_capital else 0.00016

func _add_icon(tex: Texture2D, pos: Vector2, level: int, rng: Vector2, _tip: String) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(pos.x, maxf(map.height_at(pos), 0.0) + 4.0, pos.y)
	add_child(root)
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.pixel_size = 0.00016
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
		l.offset = Vector2(26, -22)
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
