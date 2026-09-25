class_name StraitLayer
extends Node3D
## Boğaz geçişleri. Kısa boğazlar: çelik kafes köprü (ayaklı açıklıklar + taş başlıklar).
## Uzun geçişler (Manş, Cebelitarık...): feribot hattı (kesikli çizgi + ad).

const BRIDGE_MAX_LEN := 20.0
const SPAN_SCALE := 4.0            ## köprü açıklığı dünya uzunluğu (model 1 birim)
const WIDTH_SCALE := 5.0           ## stratejik kamerada okunur yatay genişlik; düşey eksen ölçeklenmez
const END_LENGTH_SCALE := 3.2
const DECK_HEIGHT := 0.38
const DASH := 1.4
const GAP := 1.0
const COLOR := Color(0.93, 0.84, 0.6)
const VISIBLE_RANGE := 1100.0

var map: MapView3D
var library: Dictionary        ## CityLayer3D'nin bina kütüphanesi (bridge_span, bridge_end)
var building_mesh: Callable    ## ad -> Mesh (bina shader'ıyla)

func _ready() -> void:
	for s: Dictionary in World.straits:
		var a := Vector2(s["from"][0], s["from"][1])
		var b := Vector2(s["to"][0], s["to"][1])
		var names: Dictionary = s["name"]
		var title: String = names.get(TranslationServer.get_locale().substr(0, 2), names["en"])
		if a.distance_to(b) <= BRIDGE_MAX_LEN:
			_bridge(a, b)
		else:
			_ferry(a, b)
		var l := Label3D.new()
		l.text = title
		l.font = UiTheme.bold_font()
		l.font_size = 20
		l.outline_size = 8
		l.modulate = COLOR
		l.outline_modulate = Color(0.03, 0.03, 0.02, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0005
		l.no_depth_test = true
		var mid := (a + b) * 0.5
		l.position = Vector3(mid.x, 5.0, mid.y)
		l.visibility_range_end = VISIBLE_RANGE * 0.7
		add_child(l)

## Uçlar karada kalacak şekilde köprü: taş başlık + n açıklık + taş başlık
func _bridge(a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	# her iki ucu kıyıya doğru biraz uzat, karada otursun
	a -= dir * 2.0
	b += dir * 2.0
	var L := a.distance_to(b)
	var n := maxi(1, int(ceil(L / SPAN_SCALE)))
	var span := L / n
	var deck := maxf(maxf(map.height_at(a), map.height_at(b)), 0.0) + DECK_HEIGHT
	var yaw := -atan2(dir.y, dir.x)
	var span_mesh: Mesh = building_mesh.call("bridge_span")
	var end_mesh: Mesh = building_mesh.call("bridge_end")
	if span_mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = span_mesh
	mm.instance_count = n
	for i in n:
		var p := a + dir * (span * i)
		# glTF sonrası model eksenleri: X=uzunluk, Y=yükseklik, Z=genişlik.
		# Eski kod Y'yi WIDTH_SCALE ile çarpıp köprüleri dikeyde beş kat uzatıyordu.
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(span, 1.0, WIDTH_SCALE))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, deck, p.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = VISIBLE_RANGE
	mmi.visibility_range_end_margin = VISIBLE_RANGE * 0.12
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	if end_mesh:
		for pair: Array in [[a, yaw + PI], [b, yaw]]:
			var mi := MeshInstance3D.new()
			mi.mesh = end_mesh
			var p2: Vector2 = pair[0]
			var end_basis := Basis(Vector3.UP, pair[1]) * Basis.from_scale(Vector3(END_LENGTH_SCALE, 1.0, WIDTH_SCALE))
			mi.transform = Transform3D(end_basis, Vector3(p2.x, deck, p2.y))
			mi.visibility_range_end = VISIBLE_RANGE
			mi.visibility_range_end_margin = VISIBLE_RANGE * 0.12
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mi)

func _ferry(a: Vector2, b: Vector2) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR
	mat.no_depth_test = true
	mat.render_priority = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x) * 0.3
	var length := a.distance_to(b)
	var t := 0.0
	while t < length:
		var p0 := a + dir * t
		var p1 := a + dir * minf(t + DASH, length)
		var v := [Vector3(p0.x - nrm.x, 0.6, p0.y - nrm.y), Vector3(p0.x + nrm.x, 0.6, p0.y + nrm.y),
				Vector3(p1.x + nrm.x, 0.6, p1.y + nrm.y), Vector3(p1.x - nrm.x, 0.6, p1.y - nrm.y)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v[i])
		t += DASH + GAP
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VISIBLE_RANGE * 2.0
	add_child(mi)
