class_name RoadLayer
extends Node3D
## Kara yolları ve demiryolları (data/map/roads.json; tools/build_roads.py): kıvrılan hatlarda saydam boyalı şerit dokuları
## kullanır. Yalnız görünüm, oyun mantığı kullanmaz. Çizgiler karolara (CHUNK harita pikseli) ayrılır;
## bir karonun ağı kamera yakınına ilk geldiğinde bir kez kurulur (açılışta bütün dünyanın ağı kurulmaz). Uzakta gizli.

const DATA_PATH := "res://data/map/roads.json"
const CHUNK := 256.0
const RANGE := 560.0                  ## bu kamera uzaklığının içinde görünür (RANGE * 0.72'den sonra söner)
const MINOR_RANGE := 330.0            ## tali yollar daha yakında
const STEP := 2.0                     ## araziyi izlemek için örnekleme aralığı (harita pikseli; yükseklik shader'da)
const HALF_PX: Array[float] = [2.1, 1.5, 2.6]   ## yarım genişlik (ekran pikseli): ana yol, tali yol, demiryolu traversi
const BUILD_BUDGET_US := 3000        ## kare başına karo kurulum bütçesi (takılma olmasın)
const PATH_TEXTURES := [
	"res://assets/ui/map_roads/road_major.png",
	"res://assets/ui/map_roads/road_minor.png",
]
const PATH_REPEAT_SCREEN_PX := 112.0  ## Yol dokusundaki büyük ayrıntı her zoom'da yaklaşık aynı piksel boyunda kalır

var map: MapView3D
var camera: MapCamera3D
var active := false                   ## yalnız "Yollar" harita kipinde görünür (main._apply_mode)
var _lines := {}                      ## Vector2i karo -> [ana yollar, tali yollar, demiryolları] (PackedVector2Array)
var _built := {}                      ## Vector2i karo -> MeshInstance3D (boşsa null)
var _mats: Array[ShaderMaterial] = []
var _last_d := -1.0

func _ready() -> void:
	for k in 3:
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/road.gdshader")
		UnitModels.compat_material(m)
		m.set_shader_parameter("kind", k)
		m.set_shader_parameter("half_px", HALF_PX[k])
		if k < PATH_TEXTURES.size():
			m.set_shader_parameter("path_tex", load(PATH_TEXTURES[k]))
		m.render_priority = -12 + k        # önce tali yol, sonra ana yol, en üstte demiryolu; hepsi iğnelerin altında
		if map and map.height_texture:
			m.set_shader_parameter("height_tex", map.height_texture)
			m.set_shader_parameter("map_size", map.map_size)
			m.set_shader_parameter("height_scale", MapView3D.HEIGHT_SCALE)
			m.set_shader_parameter("mesh_step", MapView3D.VERTEX_SPACING)
		_mats.append(m)
	_load()

func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	for ln: Array in data["lines"]:
		var pts := PackedVector2Array()
		pts.resize((ln.size() - 1) / 2)
		for i in pts.size():
			pts[i] = Vector2(float(ln[1 + i * 2]), float(ln[2 + i * 2])) * 0.1
		var mid := pts[pts.size() / 2]
		var key := Vector2i(floori(mid.x / CHUNK), floori(mid.y / CHUNK))
		if not _lines.has(key):
			_lines[key] = [[], [], []]
		_lines[key][int(ln[0])].append(pts)

func _process(_delta: float) -> void:
	if camera == null:
		return
	var d := camera.distance
	visible = active and d < RANGE and World.in_game
	if not visible:
		return
	if absf(d - _last_d) > 0.5:
		_last_d = d
		var vh := get_viewport().get_visible_rect().size.y
		var pxw := 2.0 * d * tan(deg_to_rad(camera.fov) * 0.5) / maxf(vh, 1.0)
		var fade := 1.0 - smoothstep(RANGE * 0.72, RANGE, d)
		for k in 3:
			_mats[k].set_shader_parameter("px_world", pxw)
			if k < PATH_TEXTURES.size():
				_mats[k].set_shader_parameter("path_repeat", 1.0 / maxf(PATH_REPEAT_SCREEN_PX * pxw, 0.001))
			_mats[k].set_shader_parameter("fade", fade * (1.0 - smoothstep(MINOR_RANGE * 0.72, MINOR_RANGE, d) if k == 1 else 1.0))
	# kamera çevresindeki karolar (görüş genişliği uzaklıkla büyür)
	var t := Vector2(camera.target.x, camera.target.z)
	var r := d * 1.7
	var c0 := Vector2i(floori((t.x - r) / CHUNK), floori((t.y - r) / CHUNK))
	var c1 := Vector2i(floori((t.x + r) / CHUNK), floori((t.y + r) / CHUNK))
	var todo: Array[Vector2i] = []
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var key := Vector2i(cx, cy)
			if not _built.has(key):
				todo.append(key)
	if todo.is_empty():
		return
	# önce kameraya en yakın karolar; kare başına bütçe kadar
	var tc := t / CHUNK - Vector2(0.5, 0.5)
	todo.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(tc) < Vector2(b).distance_squared_to(tc))
	var t0 := Time.get_ticks_usec()
	for key in todo:
		_built[key] = _build(key)
		if Time.get_ticks_usec() - t0 > BUILD_BUDGET_US:
			return

## Bir karonun ağı: tür başına bir yüzey; her çizgi araziyi izleyecek sıklıkta örneklenir, köşelerde birleşik şerit
func _build(key: Vector2i) -> MeshInstance3D:
	if not _lines.has(key):
		return null
	var mesh := ArrayMesh.new()
	var groups: Array = _lines[key]
	for k in 3:
		var lines: Array = groups[k]
		if lines.is_empty():
			continue
		var verts := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var idx := PackedInt32Array()
		for src: PackedVector2Array in lines:
			var pts := _resample(src)
			var m := pts.size()
			if m < 2:
				continue
			var base := verts.size()
			var arc := 0.0
			for i in m:
				if i > 0:
					arc += pts[i].distance_to(pts[i - 1])
				var dir_a := (pts[i] - pts[maxi(i - 1, 0)]).normalized()
				var dir_b := (pts[mini(i + 1, m - 1)] - pts[i]).normalized()
				if i == 0:
					dir_a = dir_b
				elif i == m - 1:
					dir_b = dir_a
				var tan := (dir_a + dir_b).normalized()
				if tan == Vector2.ZERO:
					tan = dir_b
				# yön ve gönye: köşede kalınlık korunur (sivri köşede sınırlı); şerit shader'da ekran uzayında açılır
				var nrm := tan / maxf(tan.dot(dir_b), 0.45)
				var p3 := Vector3(pts[i].x, 0.0, pts[i].y)      # yükseklik shader'da
				verts.append(p3)
				verts.append(p3)
				uv.append(Vector2(-1.0, arc))
				uv.append(Vector2(1.0, arc))
				uv2.append(nrm)
				uv2.append(nrm)
				if i > 0:
					var a := base + (i - 1) * 2
					idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
		if idx.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[k])
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 64.0              # yükseklik shader'da eklenir (ağ yerde): dağdaki yol kırpılmasın
	add_child(mi)
	return mi

## Çizgiyi STEP aralıkla yeniden örnekle (uzun parçada yükseklik değişimi izlensin; kısa parçalar olduğu gibi)
static func _resample(src: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(src[0])
	for i in range(1, src.size()):
		var a := src[i - 1]
		var b := src[i]
		var n := int(a.distance_to(b) / STEP)
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n + 1)))
		out.append(b)
	return out
