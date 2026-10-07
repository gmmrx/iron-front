extends "res://tests/test_case.gd"
## Şehir yazısı bütün zoomlarda aynı sade harita yazısıdır; şehir minyatürü etiketi değiştiremez.

const Probe := preload("res://tests/map_probe.gd")

class ProbeMap extends MapView3D:
	func province_at(p: Vector2) -> int:
		return Probe.province_at(p)
	func height_at(_world_xz: Vector2) -> float:
		return 0.0

class LabelCities extends CityLayer3D:
	func _ready() -> void:
		_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
		_bold = UiTheme.bold_font()
		_build_labels()

func _setup() -> Array:
	Probe.ensure()
	var tree := Engine.get_main_loop() as SceneTree
	var map := ProbeMap.new()
	var cities := LabelCities.new()
	cities.map = map
	tree.root.add_child(cities)
	var camera := MapCamera3D.new()
	camera.map_size = Vector2(Probe.image.get_width(), Probe.image.get_height())
	tree.root.add_child(camera)
	var pins := PinLayer.new()
	pins.map = map
	pins.camera = camera
	pins.cities = cities
	tree.root.add_child(pins)
	return [pins, camera, cities, map]

func _free_setup(nodes: Array) -> void:
	for node: Node in nodes:
		if node.is_inside_tree():
			node.get_parent().remove_child(node)
		node.free()

func _snapshot(label: Label3D) -> Array:
	return [label.text, label.font, label.font_size, label.modulate, label.pixel_size,
		label.scale, label.offset, label.position, label.outline_size, label.outline_modulate]

func test_one_plain_city_label_without_near_far_style_swap() -> void:
	var nodes := _setup()
	var cities: CityLayer3D = nodes[2]
	eq(cities.labels.size(), World.cities.size(), "şehir başına bir normal etiket")
	eq(cities.find_children("*", "Label3D", true, false).size(), World.cities.size(), "ikinci yakın etiket yok")
	eq(cities.label_plates.size(), 0, "şehir yazısı altında kutu yok")
	eq(cities.find_children("*", "Sprite3D", true, false).size(), 0, "şehir etiketleri kutu sprite'ı oluşturmaz")
	for c: City in World.cities:
		var label: Label3D = cities.labels[c.id]
		check(label == cities.far_labels[c.id], "uzak/yakın API aynı tek etiketi kullanır")
		eq(label.text, c.display_name(), "şehir adı ve harf büyüklüğü aynen korunur")
		check(label.font == (cities._bold if c.is_capital else cities._font), "normal harita fontu; serif geçişi yok")
		eq(label.modulate, CityLayer.CAPITAL_COLOR if c.is_capital else CityLayer.TEXT_COLOR, "normal harita rengi")
		eq(label.scale, Vector3.ONE, "etiket ölçeği bir")
		near(label.pixel_size, CityLayer3D.LABEL_PX, 1e-9, "normal harita yazısının piksel boyu")
		near(label.visibility_range_begin, 0.0, 0.0, "yakın zoom'da isim kaybolmaz")
		near(label.visibility_range_end, minf(CityLayer3D.LABEL_RANGE[CityLayer.tier_of(c)], CityLayer3D.spacing_range(c)), 0.01,
			"uzak görünürlük: kademe sınırı ve yanındaki önemli şehirden ayrılma")
	# kalabalık yok: bir zoom'da birlikte görünen iki şehrin adı ekranda en az SPACING_PX ayrık
	for d: float in [200.0, 500.0, 1000.0]:
		var shown: Array[City] = []
		for c: City in World.cities:
			if (cities.labels[c.id] as Label3D).visibility_range_end >= d:
				shown.append(c)
		var crowded := 0
		for i in shown.size():
			for j in range(i + 1, shown.size()):
				if shown[i].position.distance_to(shown[j].position) / d * UnitLayer.PX < CityLayer3D.SPACING_PX * 0.99:
					crowded += 1
		eq(crowded, 0, "%d uzaklıkta üst üste şehir adı yok (%d ad)" % [int(d), shown.size()])
	_free_setup(nodes)

func test_city_label_style_and_anchor_do_not_change_with_zoom_or_hover() -> void:
	var nodes := _setup()
	var pins: PinLayer = nodes[0]
	var camera: MapCamera3D = nodes[1]
	var cities: CityLayer3D = nodes[2]
	var baseline := {}
	for c: City in World.cities:
		baseline[c.id] = _snapshot(cities.labels[c.id])
	var at: Vector2 = World.states[World.countries[World.player_tag].capital_state].center
	for d: float in [1200.0, 400.0, 200.0, 100.0, 55.0, 800.0]:
		camera.focus_on(at, d)
		pins._process(1.0 / 60.0)
		pins.hovered_city = 0
		pins._write_pin(0)
		for c: City in World.cities:
			eq(_snapshot(cities.labels[c.id]), baseline[c.id], "şehir etiketi zoom/hover boyunca sabit: " + c.name)
	pins._restore_labels()
	for c: City in World.cities:
		eq(_snapshot(cities.labels[c.id]), baseline[c.id], "etiket 'restore' sırasında da değişmez: " + c.name)
	_free_setup(nodes)
