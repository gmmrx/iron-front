extends "res://tests/test_case.gd"
const Clouds := preload("res://game/map/ambient_clouds.gd")

func test_cloud_layout_is_sparse_stable_and_non_grid() -> void:
	var size := Vector2(16384, 8106)
	var patches := Clouds.layout(size)
	eq(patches, Clouds.layout(size), "yerleşim zoom/yenilemeyle değişmez")
	check(patches.size() > 150 and patches.size() <= 256, "sınırlı dünya bulutu bütçesi")
	var area := 0.0
	var widths := {}
	var heights := {}
	for i in patches.size():
		var patch: Dictionary = patches[i]
		var center: Vector2 = patch["position"]
		var extent: Vector2 = patch["size"]
		check(Rect2(Vector2.ZERO, size).has_point(center), "bulut harita içinde")
		area += extent.x * extent.y
		widths[roundi(extent.x)] = true
		heights[roundi(patch["height"])] = true
		for j in i:
			ge(center.distance_to(patches[j]["position"]), Clouds.MIN_GAP - 0.01, "rastgele kümeler üst üste yoğun yığın olmaz")
	lt(area / (size.x * size.y), 0.12, "quad alanı haritanın yüzde12'sinden az; gerçek siluet daha seyrek")
	gt(widths.size(), 70, "boylar aynı tekrarlayan pattern değil")
	gt(heights.size(), 30, "yükseltiler de farklı")

func test_clouds_share_one_cheap_material_and_no_volume() -> void:
	var node := Clouds.new()
	node.setup(Vector2(16384, 8106), true)
	var count := 0
	for batch: MultiMeshInstance3D in node.batches:
		check(batch.material_override == node.material, "bütün kümeler tek malzemeyi paylaşır")
		check(batch.multimesh.mesh is PlaneMesh, "iki üçgenlik küçük kart; BoxMesh hacim yok")
		check(batch.multimesh.use_custom_data, "tek drawcall içinde görsel varyasyon")
		eq(batch.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "ek shadowpass yok")
		count += batch.multimesh.instance_count
	check(count >= node.patches.size() and count <= node.patches.size() * 3, "kenar wrap kopyaları sınırlı")
	var shader := FileAccess.get_file_as_string("res://assets/shaders/ambient_clouds.gdshader")
	var field := FileAccess.get_file_as_string("res://assets/shaders/ambient_clouds.gdshaderinc")
	check(not shader.contains("sampler") and not field.contains("sampler"), "texture/noise örneklemesi yok")
	check(not shader.contains("for (") and not field.contains("for ("), "raymarch/density döngüsü yok")
	check(not shader.contains("mask_tex"), "keşif bulut yoğunluğunu değiştirmez")
	node.free()

func test_near_camera_hides_cards_without_touching_fog_rules() -> void:
	var node := Clouds.new()
	node.setup(Vector2(16384, 8106), false)
	var baseline := node.patches.duplicate(true)
	var discovery := Military.fog_levels().duplicate()
	for distance: float in [55, 150, 250]:
		node.set_camera_distance(distance)
		check(not node.visible, "yakında kart bulut görünmez")
	node.set_camera_distance(800)
	check(node.visible, "uzak görüşte hafif atmosfer bulutları")
	near(node.material.get_shader_parameter("cloud_amount"), 0.85, 0.0001, "opacity bütçesi")
	eq(node.patches, baseline, "zoom bulutları yeniden üretmez veya büyütmez")
	eq(Military.fog_levels(), discovery, "bulut görünümü keşif durumuna dokunmaz")
	node.free()
