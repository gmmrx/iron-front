class_name RoadBridge3D
extends Node3D
## Sade, dönem uyumlu yol köprüsü: taş ayaklar, koyu çelik kuleler ve askı kabloları.
## Yerel X köprü boyu, Y yükseklik, Z yol genişliğidir; StraitLayer harita yönüne döndürür.

const RANGE := 1100.0

func build(span_length: float, road_width := 3.6) -> void:
	var L := maxf(span_length, 4.0)
	var W := road_width
	var stone := _material(Color(0.67, 0.60, 0.46))
	var stone_light := _material(Color(0.82, 0.73, 0.55))
	var steel := _material(Color(0.24, 0.29, 0.28))
	var steel_light := _material(Color(0.48, 0.47, 0.39))
	var road := _material(Color(0.31, 0.32, 0.29))

	# Hafif taş alt döşeme ve asfalt şerit.
	_box(Vector3(L, 0.20, W), Vector3(0, 0, 0), stone)
	_box(Vector3(L, 0.055, W * 0.74), Vector3(0, 0.125, 0), road)
	# Kenar bordürü ve iki yatay korkuluk.
	for side: float in [-1.0, 1.0]:
		var z := side * W * 0.46
		_box(Vector3(L, 0.10, 0.12), Vector3(0, 0.18, z), stone_light)
		_box(Vector3(L, 0.12, 0.075), Vector3(0, 0.50, z), steel_light)
		var post_count := maxi(4, ceili(L / 3.0))
		for i in range(post_count + 1):
			var x := -L * 0.5 + L * float(i) / float(post_count)
			_box(Vector3(0.11, 0.42, 0.09), Vector3(x, 0.39, z), steel)

	# Portal kuleleri ve çapraz kirişleri.
	var tower_x := L * 0.23
	var tower_h := clampf(L * 0.21, 2.0, 4.0)
	for x_sign: float in [-1.0, 1.0]:
		var x := x_sign * tower_x
		for z_sign: float in [-1.0, 1.0]:
			var z := z_sign * W * 0.47
			_box(Vector3(0.42, tower_h, 0.36), Vector3(x, tower_h * 0.5 + 0.2, z), steel)
			_box(Vector3(0.52, 0.18, 0.48), Vector3(x, tower_h + 0.2, z), steel_light)
		_box(Vector3(0.30, 0.18, W * 0.96), Vector3(x, tower_h + 0.2, 0), steel_light)

	# Ana askı kabloları; çok parçalı silindirler yumuşak bir catenary yayı verir.
	for side: float in [-1.0, 1.0]:
		var z := side * W * 0.47
		var cable_points := _cable_points(L, tower_x, tower_h)
		for i in range(cable_points.size() - 1):
			var a := cable_points[i]
			var b := cable_points[i + 1]
			a.z = z
			b.z = z
			_cylinder_between(a, b, 0.085, steel_light)
		# Seyrek ve kalın askılar küçük harita ölçeğinde köprü şeklini korur.
		var hanger_step := maxf(1.4, L / 6.0)
		var x := -tower_x + hanger_step
		while x < tower_x - hanger_step * 0.4:
			var y := _cable_height(x, L, tower_x, tower_h)
			_cylinder_between(Vector3(x, 0.19, z), Vector3(x, y, z), 0.045, steel)
			x += hanger_step

	# Taş yaklaşım başlıkları köprünün iki ucunu kıyıya bağlar.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.42, 0.50, W * 1.12), Vector3(side * (L * 0.5 - 0.10), -0.12, 0), stone)
		_box(Vector3(0.45, 0.12, W * 1.18), Vector3(side * (L * 0.5 - 0.10), 0.19, 0), stone_light)

func _cable_points(length: float, tower_x: float, tower_h: float) -> PackedVector3Array:
	var p := PackedVector3Array()
	var anchors := [Vector2(-length * 0.5, 0.44), Vector2(-tower_x, tower_h + 0.28),
		Vector2(0, maxf(tower_h * 0.48, 1.05)), Vector2(tower_x, tower_h + 0.28), Vector2(length * 0.5, 0.44)]
	for segment in range(anchors.size() - 1):
		var a: Vector2 = anchors[segment]
		var b: Vector2 = anchors[segment + 1]
		var count := maxi(2, ceili(absf(b.x - a.x) / 1.2))
		for i in range(count):
			var t := float(i) / float(count)
			p.append(Vector3(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t), 0))
	p.append(Vector3(anchors[-1].x, anchors[-1].y, 0))
	return p

func _cable_height(x: float, length: float, tower_x: float, tower_h: float) -> float:
	var points := _cable_points(length, tower_x, tower_h)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, inverse_lerp(a.x, b.x, x))
	return 1.0

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material

func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(mesh, Transform3D(Basis.IDENTITY, at), material)

func _cylinder_between(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var delta := b - a
	if delta.length_squared() < 0.00001:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = delta.length()
	mesh.radial_segments = 8
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_add_mesh(mesh, Transform3D(basis, (a + b) * 0.5), material)

func _add_mesh(mesh: Mesh, xform: Transform3D, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = xform
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = RANGE
	instance.visibility_range_end_margin = RANGE * 0.08
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)
