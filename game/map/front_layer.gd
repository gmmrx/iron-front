class_name FrontLayer
extends Node3D
## Oyuncu ordularının cephe hatları: sınırın tam üstünde, ordu renginde çizgi ve düşmana bakan dişler
## (taarruzda uzun ok dişleri). Sınır noktaları bölge merkezinden komşuya piksel piksel yürüyerek bulunur.

const REFRESH := 1.0
const SCREEN_W := 0.0026

var map: MapView3D
var camera: MapCamera3D
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _timer := 0.0
var _border_cache := {}              ## "f:n" -> Vector2 sınır noktası

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/route.gdshader")
	_mat.set_shader_parameter("opacity", 0.95)
	_mat.render_priority = 3
	_mi = MeshInstance3D.new()
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_mi)
	Military.armies_changed.connect(func() -> void: _timer = 0.0)

func _process(delta: float) -> void:
	visible = World.in_game and camera.distance < 6000.0
	if not visible:
		return
	_mat.set_shader_parameter("width", camera.distance * SCREEN_W)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_rebuild()

## f bölgesinden n'ye doğru ilk sınır pikseli
func _border(f: int, n: int) -> Vector2:
	var key := "%d:%d" % [f, n]
	if _border_cache.has(key):
		return _border_cache[key]
	var a := World.province(f).center
	var b := World.unwrap_near(a, World.province(n).center)
	var dir := (b - a).normalized()
	var p := a
	var steps := int(a.distance_to(b)) + 2
	for i in steps:
		var q := p + dir
		if map.province_at(q) != f:
			break
		p = q
	_border_cache[key] = p
	return p

func _rebuild() -> void:
	var lines: Array = []
	for a in Military.armies:
		if a.owner != World.player_tag or a.enemy == "":
			continue
		var pts: Array = []          # [konum, düşmana yön]
		for f in Military.front_provinces(a):
			var fc := World.province(f).center
			for n in World.land_neighbors(f):
				if Military._is_target_pid(a, n):
					var bp := _border(f, n)
					pts.append([bp, (World.unwrap_near(fc, World.province(n).center) - fc).normalized()])
		if pts.size() < 1:
			continue
		# komşu sınır noktalarını bağla: her nokta en yakın iki komşusuna (makul mesafe içinde)
		var nn := PackedFloat32Array()
		for i in pts.size():
			var best := INF
			for j in pts.size():
				if i != j:
					best = minf(best, (pts[i][0] as Vector2).distance_to(pts[j][0]))
			nn.append(best)
		var sorted := Array(nn)
		sorted.sort()
		var med: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 10.0
		var r := maxf(med * 2.4, 6.0)
		var seen := {}
		for i in pts.size():
			var cand: Array = []
			for j in pts.size():
				if i == j:
					continue
				var d := (pts[i][0] as Vector2).distance_to(pts[j][0])
				if d <= r:
					cand.append([d, j])
			cand.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
			for c: Array in cand.slice(0, 2):
				var j: int = c[1]
				var k := "%d-%d" % [mini(i, j), maxi(i, j)]
				if seen.has(k):
					continue
				seen[k] = true
				lines.append({"pts": PackedVector2Array([pts[i][0], pts[j][0]]), "color": a.color, "w": 1.0})
		# dişler: düşmana doğru kısa çıkıntı (taarruzda uzun)
		var tooth := 5.0 if a.mode == Army.Mode.ATTACK else 2.8
		for i in range(0, pts.size(), 1):
			var p0: Vector2 = pts[i][0]
			var dir: Vector2 = pts[i][1]
			lines.append({"pts": PackedVector2Array([p0, p0 + dir * tooth]), "color": a.color, "w": 0.9 if a.mode == Army.Mode.ATTACK else 0.7})
	_mi.mesh = _ribbon(lines)

## Şerit ağı (RouteLayer ile aynı kodlama: UV2 yan yön, UV.x ±genişlik)
func _ribbon(lines: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for ln: Dictionary in lines:
		var pts: PackedVector2Array = ln["pts"]
		if pts.size() < 2:
			continue
		var col: Color = ln["color"]
		var wf: float = ln["w"]
		var base := verts.size()
		var t := (pts[1] - pts[0]).normalized()
		var nrm := Vector2(-t.y, t.x)
		for i in pts.size():
			var h := maxf(map.height_at(pts[i]), 0.0) + 0.8
			var p3 := Vector3(pts[i].x, h, pts[i].y)
			verts.append(p3); verts.append(p3)
			uv.append(Vector2(wf, 0.0)); uv.append(Vector2(-wf, 0.0))
			uv2.append(nrm); uv2.append(nrm)
			cols.append(col); cols.append(col)
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
