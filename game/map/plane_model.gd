class_name PlaneModel
extends RefCounted
## Uçak modeli (assets/models/plane-model.glb): hava kanatlarının haritadaki uçağı (AirLayer). Model tek örgü; açılışta bir
## kez üç parçaya ayrılır: gövde (içe aktarılan LOD'larıyla), pervane (kendi ekseninde döner) ve ülkenin bayrak çıkartması
## (modelin boyalı bayrak panellerinin üstüne, yüzeye oturan ince örgü; doku ülke başına küçük bir resim). Yeni resim
## dosyası yok.
##
## Ölçüler (1 Ekim 2026; modelin kendi birimi: burun +x, yukarı +y, kanatlar z boyunca, kanat açıklığı 1,0):
## - Pervane: tümüyle x ≥ 0,39'da kalan 5 bağlantılı parça (3 pal ve kökleri). Ekseni +x (palların düzleminin normali
##   (1; 0,001; 0,008)); göbek (0,43; −0,013; −0,016): göbek ucu (0,454; −0,012; −0,018), palların ağırlık merkezi
##   (0,415; −0,015; −0,014).
## - Model burun ekseni çevresinde yatık: kanat uçları y −0,071 (+z) ve +0,026 (−z) → 5,6°, dikey kuyruk 1,6°; ortalama
##   3,6° düzeltilir (ROLL).
## - Boyalı bayrak panelleri dokudaki kırmızı ve beyaz tekselleri taşıyan üçgenlerden: iki kanadın üstünde ~0,21 × 0,135
##   (3:2) ve dikey kuyruğun iki yüzünde ~0,12 × 0,12. Eski bayrak silinir: panelin (biraz taşarak, "clean" yarı boyları)
##   üçgenleri dokunun aynı yüzdeki temiz bir boya noktasına ("uv") yeniden eşlenir; gövde malzemesiyle aynı ışığı alır,
##   resim değişmez. Boya noktaları panelin çevresindeki boyanın ortancasına en yakın, 33 × 33 teksel içinde en düzgün
##   renkli yer: kanatlar (84, 85, 45), kuyruk (71, 70, 30). Üstüne 3:2 bayrak çıkartması gelir (kanatta paneli örter,
##   kuyrukta kuyruğun eninde). Yüzeyin pürüzlülüğü ~0,47 (ORM) → çıkartma 0,5.
## - Eski uçağın (units.glb "fighter") kanat açıklığı 2,3 × 1,25 = 2,875 → SPAN aynı boyu verir.

const MODEL := "res://assets/models/plane-model.glb"
const PROP_X := 0.39
const HUB := Vector3(0.43, -0.013, -0.016)
const ROLL := -3.6                   ## derece; +x çevresinde (+z kanadı kalkar)
const SPAN := 2.875                  ## harita ölçeği (AirLayer ile çarpılır): eski uçakla aynı kanat açıklığı
const GROUND := 0.17                 ## modelin merkezinden en alt noktasına (pervane ucu): parkta yere oturur
const LIFT := 0.004                  ## çıkartma yüzeyin bu kadar dışında
## Bayrak panelleri: merkez, yüzey normali (dışa), bayrağın üstü (burun ya da yukarı), bayrağın genişliği ve yüksekliği,
## silinen boyanın yarı boyları, temiz boya noktası. Bayrak yan (genişlik) ekseni up × normal: dışarıdan bakan her yüzde
## bayrak ters görünmez.
const PANELS := [
	{"c": Vector3(0.1418, -0.0644, 0.2956), "n": Vector3(-0.077, 0.997, -0.0006), "up": Vector3(1, 0, 0), "w": 0.225, "h": 0.15,
		"clean": Vector2(0.122, 0.082), "uv": Vector2(0.51111, 0.86213)},
	{"c": Vector3(0.1298, -0.0191, -0.3124), "n": Vector3(-0.1783, 0.9398, 0.2915), "up": Vector3(1, 0, 0), "w": 0.225, "h": 0.15,
		"clean": Vector2(0.122, 0.082), "uv": Vector2(0.21044, 0.77446)},
	{"c": Vector3(-0.3666, -0.0485, 0.0118), "n": Vector3(-0.0277, -0.0021, 0.9996), "up": Vector3(0, 1, 0), "w": 0.13, "h": 0.0867,
		"clean": Vector2(0.078, 0.078), "uv": Vector2(0.2581, 0.61721)},
	{"c": Vector3(-0.3634, -0.0551, -0.004), "n": Vector3(-0.0579, 0.0263, -0.998), "up": Vector3(0, 1, 0), "w": 0.13, "h": 0.0867,
		"clean": Vector2(0.078, 0.078), "uv": Vector2(0.18059, 0.55977)},
]
const TEX_W := 192                   ## bayrak dokusu (3:2)
const TEX_H := 128

## Hazırlanan parçalar: body, prop, decal, mat, flags (ülke -> malzeme)
static var _k := {}

## Modeli AirLayer'ın düzenine getirir: burun -Z'ye (eski uçaklar gibi), kanatlar düz
static func fix() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(ROLL)), Vector3.ZERO)

## Pervanenin a radyan dönmüş hali (modelin kendi biriminde; fix()'ten sonra uygulanır)
static func spin(a: float) -> Transform3D:
	var b := Basis(Vector3.RIGHT, a)
	return Transform3D(b, HUB - b * HUB)

static func body() -> ArrayMesh:
	return _prepare()["body"]

static func prop() -> ArrayMesh:
	return _prepare()["prop"]

static func decal() -> ArrayMesh:
	return _prepare()["decal"]

static func material() -> Material:
	return _prepare()["mat"]

static func _prepare() -> Dictionary:
	if not _k.is_empty():
		return _k
	var root: Node = (load(MODEL) as PackedScene).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: ArrayMesh = mi.mesh
	# modelin metal haritası her yerde ~0,97 (tank ve askerde ~0,05): haritada yansıyacak gök yok, metal yüzey kara görünür;
	# öbür figürler gibi boyalı yüzey sayılır
	var mat := (mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.metallic = 0.08
	_k["mat"] = mat
	_k["flags"] = {}
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var is_prop := _prop_vertices(verts, idx)
	# gövde: pervane üçgenleri çıkar, eski bayrak panelleri temiz boyaya eşlenir; içe aktarılan LOD'lar da aynı süzgeçten
	# geçer (uzakta az üçgen)
	var surf: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var wide := verts.size() > 65535
	var dup := {}                                  # köşe -> temiz boyalı kopyası
	var order: Array[Vector2i] = []                # [özgün köşe, panel]
	var lods := {}
	for l: Dictionary in surf.get("lods", []):
		var li := _filter(_indices(l["index_data"], wide), is_prop, false)
		_clean_panels(li, verts, normals, dup, order)
		lods[float(l["edge_length"])] = li
	var bi := _filter(idx, is_prop, false)
	_clean_panels(bi, verts, normals, dup, order)
	var clean_uvs: Array = []
	for pnl: Dictionary in PANELS:
		clean_uvs.append(pnl["uv"])
	var b := UnitFigures.with_copies(arr, order, clean_uvs)
	b[Mesh.ARRAY_INDEX] = bi
	var body_mesh := ArrayMesh.new()
	body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b, [], lods)
	_k["body"] = body_mesh
	var p := arr.duplicate()
	p[Mesh.ARRAY_INDEX] = _filter(idx, is_prop, true)
	var prop_mesh := ArrayMesh.new()
	prop_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p)
	_k["prop"] = prop_mesh
	_k["decal"] = _build_decal(verts, normals, idx, is_prop)
	root.free()
	return _k

## Panelin içindeki üçgen mi (yüzü panele bakan, panel düzlemine yakın, merkezi silinen boyanın dikdörtgeninde): panel
## sırası, değilse -1
static func _panel_of(a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> int:
	var cen := (a + b + c) / 3.0
	for i in PANELS.size():
		var pnl: Dictionary = PANELS[i]
		var n: Vector3 = (pnl["n"] as Vector3).normalized()
		if nrm.dot(n) < 0.05 or absf((cen - (pnl["c"] as Vector3)).dot(n)) > 0.03:
			continue
		var up: Vector3 = pnl["up"]
		up = (up - n * up.dot(n)).normalized()
		var d := cen - (pnl["c"] as Vector3)
		var half: Vector2 = pnl["clean"]
		if absf(d.dot(up.cross(n))) < half.x and absf(d.dot(up)) < half.y:
			return i
	# dikey kuyruğun kenarları (üst, ön, arka): boyalı bayrak kenardan da taşar (üstten bakınca kırmızı çizgi); yüzünden
	# bağımsız, kuyruğun kalınlığı (|z| < 0,03) içinde bayrağın boyu kadar
	if absf(cen.z) < 0.03 and cen.x > -0.44 and cen.x < -0.29 and cen.y > -0.115 and cen.y < 0.03:
		return 2 if nrm.z >= 0.0 else 3
	return -1

## Eski bayrak boyasını sil: panellerdeki üçgenler köşelerinin temiz boyalı kopyalarına bağlanır (kopya, köşe başına bir
## kez; panelin dışındaki komşu üçgenler özgün köşede kalır)
static func _clean_panels(tri: PackedInt32Array, verts: PackedVector3Array, normals: PackedVector3Array, dup: Dictionary,
		order: Array[Vector2i]) -> void:
	var base := verts.size()
	for t in range(0, tri.size(), 3):
		var nrm := (normals[tri[t]] + normals[tri[t + 1]] + normals[tri[t + 2]]).normalized()
		var p := _panel_of(verts[tri[t]], verts[tri[t + 1]], verts[tri[t + 2]], nrm)
		if p < 0:
			continue
		for j in 3:
			var v := tri[t + j]
			if not dup.has(v):
				dup[v] = base + order.size()
				order.append(Vector2i(v, p))
			tri[t + j] = int(dup[v])

## Köşe başına pervane mi (1): aynı noktadaki köşeler birleşik sayılır, üçgenler bağlantılı parçalara ayrılır; bütün
## köşeleri PROP_X'in önünde kalan parça pervanedir
static func _prop_vertices(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedByteArray:
	var n := verts.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	var alias := PackedInt32Array()
	alias.resize(n)
	var pos_id := {}
	for i in n:
		parent[i] = i
		var key := Vector3i((verts[i] * 2000.0).round())
		if not pos_id.has(key):
			pos_id[key] = i
		alias[i] = pos_id[key]
	for t in range(0, idx.size(), 3):
		var a := UnitFigures._find(parent, alias[idx[t]])
		var b := UnitFigures._find(parent, alias[idx[t + 1]])
		var c := UnitFigures._find(parent, alias[idx[t + 2]])
		parent[b] = a
		parent[UnitFigures._find(parent, c)] = UnitFigures._find(parent, a)
	var low := {}                                   # parça kökü -> en küçük x
	for i in n:
		var r := UnitFigures._find(parent, alias[i])
		low[r] = minf(float(low.get(r, INF)), verts[i].x)
	var out := PackedByteArray()
	out.resize(n)
	for i in n:
		out[i] = 1 if float(low[UnitFigures._find(parent, alias[i])]) >= PROP_X else 0
	return out

## Üçgen dizisinden yalnız pervane (want true) ya da yalnız gövde üçgenleri
static func _filter(idx: PackedInt32Array, is_prop: PackedByteArray, want: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if (is_prop[idx[t]] == 1) == want:
			out.append(idx[t])
			out.append(idx[t + 1])
			out.append(idx[t + 2])
	return out

## RenderingServer'ın ham dizin verisi (16 ya da 32 bit)
static func _indices(data: PackedByteArray, wide: bool) -> PackedInt32Array:
	if wide:
		return data.to_int32_array()
	var out := PackedInt32Array()
	out.resize(data.size() / 2)
	for i in out.size():
		out[i] = data.decode_u16(i * 2)
	return out

## Bayrak çıkartması: her panelde, yüzü panele bakan gövde üçgenleri bayrağın dikdörtgenine kırpılır, panel normali
## boyunca LIFT kadar dışarı alınır; UV panelin düzlemsel izdüşümü
static func _build_decal(verts: PackedVector3Array, normals: PackedVector3Array, idx: PackedInt32Array, is_prop: PackedByteArray) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pnl: Dictionary in PANELS:
		var n: Vector3 = (pnl["n"] as Vector3).normalized()
		var up: Vector3 = pnl["up"]
		up = (up - n * up.dot(n)).normalized()
		var side := up.cross(n)
		var c: Vector3 = pnl["c"]
		var hw := float(pnl["w"]) * 0.5
		var hh := float(pnl["h"]) * 0.5
		var rect := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
		for t in range(0, idx.size(), 3):
			var i0 := idx[t]
			var i1 := idx[t + 1]
			var i2 := idx[t + 2]
			if is_prop[i0] == 1 or (normals[i0] + normals[i1] + normals[i2]).normalized().dot(n) < 0.05:
				continue
			var a := verts[i0]
			var b := verts[i1]
			var cc := verts[i2]
			if absf(((a + b + cc) / 3.0 - c).dot(n)) > 0.03:
				continue
			var q := PackedVector2Array([Vector2((a - c).dot(side), (a - c).dot(up)), Vector2((b - c).dot(side), (b - c).dot(up)),
				Vector2((cc - c).dot(side), (cc - c).dot(up))])
			if minf(q[0].x, minf(q[1].x, q[2].x)) > hw or maxf(q[0].x, maxf(q[1].x, q[2].x)) < -hw \
					or minf(q[0].y, minf(q[1].y, q[2].y)) > hh or maxf(q[0].y, maxf(q[1].y, q[2].y)) < -hh:
				continue
			var den := (q[1] - q[0]).cross(q[2] - q[0])
			if absf(den) < 1e-10:
				continue
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(q, rect):
				if poly.size() < 3:
					continue
				var pts: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for s: Vector2 in poly:
					var l1 := (s - q[0]).cross(q[2] - q[0]) / den
					var l2 := (q[1] - q[0]).cross(s - q[0]) / den
					pts.append(a * (1.0 - l1 - l2) + b * l1 + cc * l2 + n * LIFT)
					var u := clampf(s.x / (2.0 * hw) + 0.5, 0.0, 1.0)
					var v := clampf(0.5 - s.y / (2.0 * hh), 0.0, 1.0)
					uvs.append(Vector2((0.5 + u * (TEX_W - 1.0)) / TEX_W, (0.5 + v * (TEX_H - 1.0)) / TEX_H))
				for i in range(1, poly.size() - 1):
					for j: int in [0, i, i + 1]:
						st.set_normal(n)
						st.set_uv(uvs[j])
						st.add_vertex(pts[j])
	return st.commit()

## Ülkenin bayrak malzemesi (bütün panellerde aynı 3:2 bayrak)
static func flag_material(c: Country) -> StandardMaterial3D:
	var flags: Dictionary = _prepare()["flags"]
	if flags.has(c.tag):
		return flags[c.tag]
	var img: Image = FlagFactory.map_flag(c).duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(TEX_W, TEX_H, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	flags[c.tag] = m
	return m

## Tek uçak düğümü (düşen uçak gibi tek seferlikler için): gövde, pervane ("p/prop") ve bayrak; ölçeği çağıran verir
static func make(c: Country) -> Node3D:
	var root := Node3D.new()
	var inner := Node3D.new()
	inner.name = "p"
	inner.transform = fix()
	root.add_child(inner)
	var parts := [[body(), material(), "body"], [prop(), material(), "prop"], [decal(), flag_material(c), "flag"]]
	for part: Array in parts:
		var m := MeshInstance3D.new()
		m.name = part[2]
		m.mesh = part[0]
		m.material_override = part[1]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inner.add_child(m)
	return root
