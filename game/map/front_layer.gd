class_name FrontLayer
extends Node3D
## Cephe hattı: oyuncunun tarafının (oyuncu ve müttefikleri; izleyici kipinde izlenen savaşın saldıranı: Game.front_tag)
## elindeki bölgelerle düşmanın elindeki bölgelerin sınırı, haritaya mürekkeple basılmış taraklı çizgi olarak
## (assets/shaders/front_ink.gdshader): yarı saydam mint mürekkep, tek taraflı dik ImageGen dişleri.
## Geometri zoom, fare ve muharebe değişimlerinde sabit kalır.
##
## Bütünlük: cephe bölge çifti çifti değil, bütün olarak kurulur. Bizim tarafın pikseli ile düşmanın pikseli arasındaki
## her piksel kenarı bir ağda toplanır ve kenarlar uç uca eklenerek uzun, kesintisiz çizgilere dizilir; çizgi yalnız
## gerçekten bittiği yerde (kıyı, tarafsız ülke, haritanın ucu) biter. Her kenarın hangi yanının bizim olduğu bilindiğinden
## dişler her yerde düşmana bakar. Çizgiler yumuşatılıp eşit aralıkla örneklenir; dişlerin sırası çizgi boyunca kesintisiz.
## Tek geometri kullanılır; keskin kıvrımlarda şerit yerel eğrilik yarıçapına göre daralır.
##
## Hız: bir bölgenin sınır kenarları (komşu bölgeleriyle) bölge haritasından bir kez çıkarılır ve saklanır (sınırlar hiç
## değişmez); cephe değişince yalnız ağ yeniden dizilir. İş kare başına süre bütçesiyle karelere yayılır.

const REFRESH := 1.0                   ## cephe en sık bu aralıkla yeniden dizilir (sn)
const BUDGET_USEC := 1000              ## kare başına iş bütçesi (µs)
const LIFT := 0.06                     ## printed on the flat terrain, not floating above the border
const SMOOTH_PASSES := 24              ## remove raster-scale zigzags before placing perpendicular teeth
const SAMPLE_STEP := 2.0
const HATCH_PERIOD := 4.0              ## larger spaced teeth, fixed in world space
const HATCH_BAND := 8.0                ## larger single-sided comb; tight bends remain limited
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var map: MapView3D
var camera: MapCamera3D
var _mat: ShaderMaterial
var _edges := {}                       ## bölge -> PackedInt32Array [x, y, yön, komşu bölge] × n (sınır kenarları)
var _mi: Array[MeshInstance3D] = []    ## one stable mesh, no camera-dependent replacement
var _dirty := true
var _busy := false
var _timer := 0.0
var _built_pairs := PackedInt32Array()

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/front_ink.gdshader")
	UnitModels.compat_material(_mat)
	_mat.render_priority = 2
	_mat.set_shader_parameter("period", HATCH_PERIOD)
	_mat.set_shader_parameter("band", HATCH_BAND)
	_mat.set_shader_parameter("comb_tex", preload("res://assets/ui/map/front_comb_perpendicular_v3.png"))
	# Reuse the authoritative owner/controller buffers. No new texture or CPU mask pass.
	_mat.set_shader_parameter("province_mask_enabled", map._province_texture != null and map._data_texture != null)
	_mat.set_shader_parameter("province_tex", map._province_texture)
	_mat.set_shader_parameter("data_tex", map._data_texture)
	_mat.set_shader_parameter("map_size", map.map_size)
	_mat.set_shader_parameter("wrap_x", World.wraps)
	for i in 1:
		var mi := MeshInstance3D.new()
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
		add_child(mi)
		_mi.append(mi)
	var mark := func(_a: Variant = null, _b: Variant = null) -> void: _dirty = true
	World.control_changed.connect(mark)
	World.ownership_changed.connect(mark)
	World.player_changed.connect(mark)
	World.game_started.connect(mark)
	Diplomacy.wars_changed.connect(mark)
	Diplomacy.diplomacy_changed.connect(mark)

func _process(delta: float) -> void:
	visible = World.in_game
	if not visible:
		return
	# No zoom-dependent width/period: a territory keeps the same printed marks while zooming.
	_timer -= delta
	if _dirty and not _busy and _timer <= 0.0:
		_dirty = false
		_timer = REFRESH
		_rebuild()

## Fare cephenin bu kesitinde (iki bölge; 0, 0 = hiçbiri): kesit koyu ve kalın
func set_hover(a: int, b: int) -> void:
	_mat.set_shader_parameter("hover_a", a)
	_mat.set_shader_parameter("hover_b", b)

## Cephe çiftleri: bizim tarafın elindeki her kara bölgesi ve düşmanın elindeki kara komşuları
func front_pairs() -> Array:
	var out: Array = []
	if not Diplomacy.at_war(Game.front_tag()):
		return out
	var side := _sides()
	for p: Province in World.provinces:
		if p == null or not p.is_land() or side.get(World.controller_tag(p.id), 0) != 1:
			continue
		for n in World.land_neighbors(p.id):
			if side.get(World.controller_tag(n), 0) == 2:
				out.append([p.id, n])
	return out

func _sides() -> Dictionary:
	var side := {}
	for c: Country in World.countries.values():
		var s := FrontPanel.side(c.tag)
		if s > 0:
			side[c.tag] = s
	return side

# ------------------------------------------------------------------ kurulum (karelere yayılır)
func _rebuild() -> void:
	_busy = true
	var current_pairs := front_pairs()
	var signature := PackedInt32Array()
	for pair: Array in current_pairs:
		signature.append_array(pair)
	if signature == _built_pairs:
		_busy = false
		return
	var side := _sides()
	var front: Array[int] = []
	var seen := {}
	for pr: Array in current_pairs:
		if not seen.has(pr[0]):
			seen[pr[0]] = true
			front.append(pr[0])
	# 1) cephe bölgelerinin sınır kenarları (önbellekte yoksa çıkarılır)
	var t0 := Time.get_ticks_usec()
	for a in front:
		if not _edges.has(a):
			_edges[a] = await _extract(a)
			if Time.get_ticks_usec() - t0 > BUDGET_USEC:
				await get_tree().process_frame
				t0 = Time.get_ticks_usec()
	# 2) bizim taraf ile düşman arasındaki kenarlar: köşe ağı
	var w := int(map.map_size.x) + 1
	var corner_edges := {}             # köşe anahtarı -> [kenar indeksleri]
	var ex := PackedInt32Array()       # kenar başına: köşe0, köşe1, normal x, normal y, a, b
	for a in front:
		var e: PackedInt32Array = _edges[a]
		for i in range(0, e.size(), 4):
			var nb := e[i + 3]
			var pnb := World.province(nb)
			if pnb == null or not pnb.is_land() or side.get(World.controller_tag(nb), 0) != 2:
				continue
			var x := e[i]
			var y := e[i + 1]
			var d := e[i + 2]
			var c0 := 0
			var c1 := 0
			match d:
				0:
					c0 = y * w + x + 1                               # sağ yüz
					c1 = (y + 1) * w + x + 1
				1:
					c0 = y * w + x                                   # sol yüz
					c1 = (y + 1) * w + x
				2:
					c0 = (y + 1) * w + x                             # alt yüz
					c1 = (y + 1) * w + x + 1
				_:
					c0 = y * w + x                                   # üst yüz
					c1 = y * w + x + 1
			var k := ex.size() / 6
			ex.append_array([c0, c1, DIRS[d].x, DIRS[d].y, a, nb])
			if not corner_edges.has(c0):
				corner_edges[c0] = []
			(corner_edges[c0] as Array).append(k)
			if not corner_edges.has(c1):
				corner_edges[c1] = []
			(corner_edges[c1] as Array).append(k)
		if Time.get_ticks_usec() - t0 > BUDGET_USEC:
			await get_tree().process_frame
			t0 = Time.get_ticks_usec()
	# 3) kenarları uç uca ekleyerek çizgiler: önce gerçek uçlardan (tek kenarlı köşe), sonra kapalı halkalar
	var n_edges := ex.size() / 6
	var used := PackedByteArray()
	used.resize(n_edges)
	var chains: Array = []             # [noktalar, kenar çiftleri (a, b), işaret]
	var starts: Array = []
	for ck: int in corner_edges:
		if (corner_edges[ck] as Array).size() == 1:
			starts.append(ck)
	for pass_i in 2:
		var cand: Array = starts if pass_i == 0 else range(n_edges)
		for item: int in cand:
			var start_corner: int
			var first := -1
			if pass_i == 0:
				start_corner = item
				for k: int in corner_edges[start_corner]:
					if used[k] == 0:
						first = k
						break
			else:
				if used[item] != 0:
					continue
				first = item
				start_corner = ex[item * 6]
			if first < 0:
				continue
			var pts := PackedVector2Array([_corner_pos(start_corner, w)])
			var pairs := PackedInt32Array()
			var sgn := 0.0
			var cur := start_corner
			var k := first
			while k >= 0:
				used[k] = 1
				var nxt: int = ex[k * 6 + 1] if ex[k * 6] == cur else ex[k * 6]
				var t := _corner_pos(nxt, w) - _corner_pos(cur, w)
				sgn += signf(Vector2(-t.y, t.x).dot(Vector2(ex[k * 6 + 2], ex[k * 6 + 3])))
				pts.append(_corner_pos(nxt, w))
				pairs.append_array([ex[k * 6 + 4], ex[k * 6 + 5]])
				cur = nxt
				k = -1
				for k2: int in corner_edges[cur]:
					if used[k2] == 0:
						k = k2
						break
			if pts.size() >= 4:
				chains.append([pts, pairs, 1.0 if sgn >= 0.0 else -1.0])
			if Time.get_ticks_usec() - t0 > BUDGET_USEC:
				await get_tree().process_frame
				t0 = Time.get_ticks_usec()
	# Build once; camera zoom never selects a differently smoothed border.
	var mesh: ArrayMesh = await _build_mesh(chains, SMOOTH_PASSES, SAMPLE_STEP)
	_mi[0].mesh = mesh
	_built_pairs = signature
	_busy = false

static func _corner_pos(c: int, w: int) -> Vector2:
	return Vector2(c % w, c / w)

func _build_mesh(chains: Array, passes: int, step: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cust := PackedFloat32Array()
	var idx := PackedInt32Array()
	var t0 := Time.get_ticks_usec()
	for ch: Array in chains:
		var raw: PackedVector2Array = ch[0]
		var pairs: PackedInt32Array = ch[1]
		var sgn: float = ch[2]
		var closed := raw[0].distance_to(raw[raw.size() - 1]) < 0.01
		var pts := _smooth(raw, passes, closed)
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var total: float = cum[cum.size() - 1]
		if total < step * 2.0:
			continue
		# eşit aralıklı örnekleme; her örneğe en yakın ham kenarın bölge çifti (fare vurgusu, muharebe)
		var n := ceili(total / step) + 1
		var base := verts.size()
		var j := 0
		for s in n:
			var dist := minf(s * step, total)
			while j < cum.size() - 2 and cum[j + 1] < dist:
				j += 1
			var f := (dist - cum[j]) / maxf(cum[j + 1] - cum[j], 1e-4)
			var p := pts[j].lerp(pts[j + 1], f)
			# yön: birkaç örnek öteye bakarak (köşelerde dişler yelpaze olmasın)
			var ta := pts[maxi(j - 2, 0)]
			var tb := pts[mini(j + 3, pts.size() - 1)]
			var t := (tb - ta).normalized()
			var nrm := Vector2(-t.y, t.x) * sgn
			# Bound the offset inside the local radius, avoiding folded inner turns.
			nrm *= bend_width_scale(ta, p, tb)
			var ei := clampi(j, 0, pairs.size() / 2 - 1)
			var h := maxf(map.height_at(p), 0.0) + LIFT
			# Center row stays on the border when battle arrows lengthen only the enemy side.
			for v in 3:
				verts.append(Vector3(p.x, h, p.y))
				uv.append(Vector2(dist, float(v) * 0.5))
				uv2.append(nrm)
				cust.append_array([float(pairs[ei * 2]), float(pairs[ei * 2 + 1]), 0.0, 0.0])
			if s > 0:
				for row in 2:
					var k := base + (s - 1) * 3 + row
					idx.append_array([k, k + 1, k + 3, k + 1, k + 4, k + 3])
			if s % 256 == 0 and Time.get_ticks_usec() - t0 > BUDGET_USEC:
				await get_tree().process_frame
				t0 = Time.get_ticks_usec()
		if Time.get_ticks_usec() - t0 > BUDGET_USEC:
			await get_tree().process_frame
			t0 = Time.get_ticks_usec()
	var mesh := ArrayMesh.new()
	if idx.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_CUSTOM0] = cust
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh

static func bend_width_scale(a: Vector2, b: Vector2, c: Vector2) -> float:
	var incoming := b - a
	var outgoing := c - b
	if incoming.length_squared() < 0.0001 or outgoing.length_squared() < 0.0001: return 1.0
	var turn := absf(incoming.normalized().angle_to(outgoing.normalized()))
	if turn < 0.001: return 1.0
	var radius := minf(incoming.length(), outgoing.length()) / (2.0 * sin(turn * 0.5))
	return clampf(radius * 0.65 / (HATCH_BAND * 0.5), 0.05, 1.0)

## Yumuşatma: [1, 2, 1] / 4 süzgeci `passes` kez (açık çizginin uçları yerinde, kapalı çizgi sarar)
static func _smooth(pts: PackedVector2Array, passes: int, closed: bool) -> PackedVector2Array:
	var cur := pts
	if closed:
		cur = cur.slice(0, cur.size() - 1)
	var n := cur.size()
	for it in passes:
		var nxt := PackedVector2Array()
		nxt.resize(n)
		for i in n:
			if not closed and (i == 0 or i == n - 1):
				nxt[i] = cur[i]
				continue
			nxt[i] = (cur[(i - 1 + n) % n] + cur[i] * 2.0 + cur[(i + 1) % n]) * 0.25
		cur = nxt
	if closed:
		cur.append(cur[0])
	return cur

## Bölgenin bütün sınır kenarları: bölge haritasından bölgenin çevresi (gerekirse büyüyen pencere) okunur, bölge içi
## taşmayla dolaşılır; komşusu başka bölge olan her piksel yüzü bir kenar. [x, y, yön (DIRS), komşu bölge] × n
func _extract(a: int) -> PackedInt32Array:
	var slice_start := Time.get_ticks_usec()
	var img: Image = map._province_image
	var iw := img.get_width()
	var ih := img.get_height()
	var stride := 4 if img.get_format() == Image.FORMAT_RGBA8 else 2
	var hi := stride - 1
	var c := World.province(a).center
	var half := 96
	while half <= 2048:
		var r := Rect2i(int(c.x) - half, int(c.y) - half, half * 2, half * 2).intersection(Rect2i(0, 0, iw, ih))
		var data := img.get_region(r).get_data()
		var rw := r.size.x
		var rh := r.size.y
		var seed := -1
		var ci := (int(c.y) - r.position.y) * rw + (int(c.x) - r.position.x)
		if ci >= 0 and ci < rw * rh and data[ci * stride] + data[ci * stride + hi] * 256 == a:
			seed = ci
		else:
			for i in rw * rh:
				if data[i * stride] + data[i * stride + hi] * 256 == a:
					seed = i
					break
		if seed < 0:
			return PackedInt32Array()
		var seen := PackedByteArray()
		seen.resize(rw * rh)
		var queue := PackedInt32Array([seed])
		seen[seed] = 1
		var head := 0
		var touches := false
		var faces := PackedInt32Array()
		while head < queue.size():
			if head % 512 == 0 and Time.get_ticks_usec() - slice_start > BUDGET_USEC:
				await get_tree().process_frame
				slice_start = Time.get_ticks_usec()
			var i := queue[head]
			head += 1
			var x := i % rw
			var y := i / rw
			# pencerenin kenarına değdi (ve harita orada bitmiyor): bölge pencereden taşıyor, pencere büyür
			if (x == 0 and r.position.x > 0) or (y == 0 and r.position.y > 0) \
					or (x == rw - 1 and r.end.x < iw) or (y == rh - 1 and r.end.y < ih):
				touches = true
				break
			for d in 4:
				var nx := x + DIRS[d].x
				var ny := y + DIRS[d].y
				if nx < 0 or ny < 0 or nx >= rw or ny >= rh:
					continue
				var jj := ny * rw + nx
				var q := data[jj * stride] + data[jj * stride + hi] * 256
				if q == a:
					if seen[jj] == 0:
						seen[jj] = 1
						queue.append(jj)
				else:
					faces.append_array([x + r.position.x, y + r.position.y, d, q])
		if not touches:
			return faces
		half *= 2
	return PackedInt32Array()
