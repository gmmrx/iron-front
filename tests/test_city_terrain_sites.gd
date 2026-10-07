extends "res://tests/test_case.gd"
## Şehir altındaki boyalı arazi açıklığı: sabit dünya ölçeği, yumuşak kara maskesi, ham yükseklik korunur.

class SiteMap extends MapView3D:
	var coast_x := 64.0
	var committed_image: Image
	func _city_site_is_land(p: Vector2) -> bool:
		var x := fposmod(p.x, map_size.x) if World.wraps else p.x
		return x < coast_x
	func _upload_city_site_image(image: Image) -> void:
		# Headless Dummy texture.update readback'i saklamaz; CPU->GPU sınırındaki veriyi doğrula.
		committed_image = image.duplicate()
		(terrain_texture as ImageTexture).set_image(image)

func _map(resolution := Vector2i(64, 32)) -> SiteMap:
	var map := SiteMap.new()
	map.map_size = Vector2(64, 32)
	var image := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGBA8)
	for y in resolution.y:
		for x in resolution.x:
			image.set_pixel(x, y, Color(float(x + 1) / 65.0, float(y + 1) / 33.0, 0.35, 1.0))
	image.generate_mipmaps()
	map.terrain_texture = ImageTexture.create_from_image(image)
	map._city_terrain_image = image
	map._height_image = Image.create(4, 4, false, Image.FORMAT_RF)
	map._height_image.fill(Color(2200.0, 0.0, 0.0))
	return map

func _weight(map: SiteMap, p: Vector2i) -> float:
	return 1.0 - map.committed_image.get_pixelv(p).a

func test_city_clearings_only_change_existing_terrain_alpha() -> void:
	var map := _map()
	var before := map.terrain_texture.get_image()
	var height_before := map._height_image.get_data()
	var city: City = World.cities[0]
	var city_pos := city.position
	map.register_city_site(city.id, Vector2(16.5, 12.5), 3.0)
	map.commit_city_sites()
	var after := map.committed_image
	near(_weight(map, Vector2i(16, 12)), 1.0, 0.001, "parselin çekirdeği temiz")
	gt(_weight(map, Vector2i(20, 12)), 0.0, "kenar yumuşak geçiş")
	lt(_weight(map, Vector2i(20, 12)), 1.0, "kenar tam temiz değil")
	eq(_weight(map, Vector2i(22, 12)), 0.0, "açıklık sadece yerel")
	for y in before.get_height():
		for x in before.get_width():
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			eq(Vector3(b.r, b.g, b.b), Vector3(a.r, a.g, a.b), "ham arazi RGB korunur")
	eq(map._height_image.get_data(), height_before, "ham yükselti hiç değişmez")
	eq(map.height_at(Vector2(16.5, 12.5)), 0.0, "fiziksel zemin halen düz")
	eq(city.position, city_pos, "şehir oyun konumu değişmez")
	check(after.has_mipmaps(), "açıklık maskesi uzak zoom için mipmap içerir")
	check(map._city_terrain_image == null, "büyük arazi CPU kopyası commit sonunda bırakılır")
	map.free()

func test_clearings_respect_coast_and_restore_moved_sites() -> void:
	var map := _map()
	map.coast_x = 32.0
	map.register_city_site(5, Vector2(30.5, 12.5), 4.0)
	map.commit_city_sites()
	near(_weight(map, Vector2i(30, 12)), 1.0, 0.001, "kıyıdaki kara temizlenir")
	for x in range(32, 38):
		eq(_weight(map, Vector2i(x, 12)), 0.0, "deniz texeli değiştirilmez")
	map.register_city_site(5, Vector2(12.5, 12.5), 3.0)
	map.commit_city_sites()
	eq(_weight(map, Vector2i(30, 12)), 0.0, "taşınan parselin eski açıklığı kaldırılır")
	near(_weight(map, Vector2i(12, 12)), 1.0, 0.001, "yeni görsel merkez temizlenir")
	map.unregister_city_site(5)
	map.commit_city_sites()
	eq(_weight(map, Vector2i(12, 12)), 0.0, "silinen parsel doğal zemine döner")
	map.free()

func test_sites_use_world_units_at_half_resolution_and_wrap() -> void:
	var map := _map(Vector2i(32, 16))
	var wrapping: bool = World.wraps
	World.wraps = true
	map.register_city_site(9, Vector2(0.0, 15.0), 3.0)
	map.commit_city_sites()
	near(_weight(map, Vector2i(0, 7)), 1.0, 0.001, "küçük resimde dünya yarıçapı doğru")
	near(_weight(map, Vector2i(31, 7)), 1.0, 0.001, "parsel dünya sarmalama kenarında kesilmez")
	eq(_weight(map, Vector2i(4, 7)), 0.0, "resim ölçeği dünya yarıçapını büyütmez")
	var before := map.committed_image.get_data()
	map.register_city_site(9, Vector2(0.0, 15.0), 3.0)
	check(not map._city_sites_dirty, "aynı kayıt yeni tam harita yüklemesi istemez")
	map.commit_city_sites()
	eq(map.committed_image.get_data(), before, "ikinci commit sabit")
	World.wraps = wrapping
	map.free()

func test_site_shader_uses_no_new_sampler_or_geometry_displacement() -> void:
	var shader := FileAccess.get_file_as_string("res://assets/shaders/map3d.gdshader")
	var samplers := RegEx.new()
	samplers.compile("uniform\\s+sampler")
	eq(samplers.search_all(shader).size(), 13, "şehir açıklığı mevcut WebGL sampler bütçesini arttırmaz")
	check(shader.contains("1.0 - terrain_sample.a"), "maske mevcut arazi alfasından okunur")
	check(shader.contains("mix(height_normal(uv), vec3(0.0, 1.0, 0.0), site)"), "boyalı relief yalnız parselde yumuşar")
	check(shader.contains("VERTEX.y = 0.0;"), "harita geometrisi daima düz kalır")
