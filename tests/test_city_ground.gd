extends "res://tests/test_case.gd"
const Ground := preload("res://game/map/city_ground.gd")
const Probe := preload("res://tests/map_probe.gd")

class DryMap extends MapView3D:
	func province_at(p: Vector2) -> int:
		return Probe.province_at(p)

func _inland_city() -> City:
	for c: City in World.cities:
		if c.is_capital and c.state_id == World.countries["TUR"].capital_state: return c
	return World.cities[0]

func test_ground_and_exit_roads_are_world_sized_and_shared() -> void:
	var map := DryMap.new()
	var library := Ground.new()
	var city := _inland_city()
	var width := PinLayer.city_model_width(city)
	var a := library.build(map, city.position, width, 0.7, city.id)
	var b := library.build(map, city.position, width, 0.7, city.id)
	eq(a.mesh.get_surface_count(), 2, "toprak parseli ve çıkış yolları iki yüzey")
	for surface in a.mesh.get_surface_count():
		check(a.mesh.surface_get_material(surface) == b.mesh.surface_get_material(surface), "malzeme şehir başına kopyalanmaz")
	check(a.transform.is_equal_approx(b.transform), "tekrar kurulum aynı worldtransform")
	var paths: Array = a.get_meta("exit_paths")
	eq(paths.size(), 3, "büyük iç şehirde iki ana yol ve bir kısa yan sokak")
	for path: Dictionary in paths:
		var points: PackedVector2Array = path["points"]
		gt(points.size(), 3, "yol keskin tekparça değil örneklenmiş kıvrım")
		lt(points[-1].distance_to(points[0]), width * 0.65, "şehirden çıkan yol minik")
		lt(float(path["width"]), width * 0.05, "modelin sokak genişliği korunur")
	var bound := a.mesh.get_aabb()
	lt(bound.size.x, width * 3.6, "parsel ve çıkışlar küçük yerleşim sınırında")
	near(bound.position.y, Ground.GROUND_Y, 0.00001, "toprak zemin haritada")
	near(bound.end.y, Ground.ROAD_Y, 0.00002, "yol havada değil tabanda")
	a.free()
	b.free()
	map.free()

func test_city_ground_never_places_vertices_in_water() -> void:
	var map := DryMap.new()
	var library := Ground.new()
	var samples := 0
	for c: City in World.cities:
		if not c.is_port: continue
		var model := library.build(map, c.position, PinLayer.city_model_width(c), c.grid_angle, c.id)
		for surface in model.mesh.get_surface_count():
			var arrays := model.mesh.surface_get_arrays(surface)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = model.transform * point
				check(not Probe.is_water(Vector2(p.x, p.z)), "parsel/yol denize taşmaz: " + c.display_name())
		samples += 1
		model.free()
		if samples >= 20: break
	gt(samples, 10, "gerçek kıyı şehirleri kontrol edildi")
	map.free()

func test_pin_visibility_does_not_leave_floating_city_ground() -> void:
	var map := DryMap.new()
	var camera := MapCamera3D.new()
	var tree := Engine.get_main_loop() as SceneTree
	camera.map_size = Vector2(16384, 8106)
	tree.root.add_child(camera)
	var pins := PinLayer.new()
	pins.map = map
	pins.camera = camera
	tree.root.add_child(pins)
	var index := 0
	var c: City = pins._pins[index][4]
	var model: Dictionary = pins._city_models.model_for(c)
	pins._write_hall(index, c, 1.0, model)
	var ground: MeshInstance3D = pins._city_sites[index]
	var transform := ground.transform
	for d: float in [55, 100, 350]:
		camera.focus_on(c.position, d)
		pins._write_hall(index, c, 1.0, model)
		check(ground.visible and ground.transform.is_equal_approx(transform), "zemin zoom ile yeniden ölçeklenmez")
	pins._write_hall(index, c, 0.0, model)
	check(not ground.visible, "şehir gizliyken zemin/yol da gizli")
	check(ground.transform.is_equal_approx(transform), "gizlenme transform'u değiştirmez")
	check(not "naval_base" in PinLayer.BUILDINGS, "liman artık rozet yerine fiziksel tesis")
	tree.root.remove_child(pins)
	pins.free()
	tree.root.remove_child(camera)
	camera.free()
	map.free()
