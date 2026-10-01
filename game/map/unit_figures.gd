class_name UnitFigures
extends RefCounted
## Birlik figürleri: kaideli minyatürler (asker: assets/models/soldier-model.glb, tank: assets/models/tank-model.glb),
## yakın zoom'da tümen levhasının yerine haritada durur. Zırhlı tümen yığını tank, öbürleri asker (UnitLayer seçer).
## Modelin kaidesine gömülü bayrak ve sayı silinir: o paneldeki üçgenler dokunun kaide duvarındaki temiz bir noktasına
## ("clean_uv") yeniden eşlenir (kabartması da düzlenir; doku değişmez, ekran kartından geri okunmaz: tarayıcıda da çalışır);
## kaidenin önüne ülkenin bayrağı (kaideye oturan eğri kuşak) ve tümen sayısı gelir.
## Model iki parçaya ayrılır: kaide ("h": bayrak kuşağı ve sayı; hep kameraya bakar) ve üstündeki asker/tank ile durduğu
## disk ("t": yürüdüğü ya da ateş ettiği yöne döner). Ayrım bağlantılı parçalara göre: en alt noktası split_y'nin üstünde
## kalan parçalar üst; kaide duvarı, alt dudak ve gömülü bayrak alt.
## Her model yüklenirken köşeleri asker düzenine getirilir: kaide altı y = -0.5, kaidenin dış yarıçapı BASE_R (scale);
## aşağıdaki ölçüler bu dönüşümden SONRAKİ model birimiyle. Model +x'e bakar; bayrak paneli kaidede +x'ten +z'ye doğru
## band_a0..band_a1 derece arasında; face_yaw panelin ortasını kameraya (+z) çevirir.

## Model ölçüleri. Tank (ölçüldü, 1 Ekim 2026): kaide modelde merkezde değil (alt dudak x -0,500..0,406, z -0,456..0,452):
## merkez (-0,047; -0,002), yarıçap 0,4535 → önce ortalanır, scale 0,9526 (kaide asker kaidesiyle aynı boy, 0,432); y' =
## 0,9526·y − 0,1861. Boyalı panel dokudan ölçüldü (kırmızı ve beyaz teksellerin üçgenleri): özgün y -0,280..-0,116, açı
## 6°..96° (ortalanınca ~5°..90°) → kuşak -0,453..-0,305; temizlik -0,291'e kadar, r ≥ 0,319; panelin ortası ~47,5° →
## face_yaw -42,5. Tank en altta -0,13 (→ -0,31), ayrım -0,20 (→ -0,377). Namlu ucu (0,50; 0,25; -0,03) → (0,521; 0,049;
## -0,028), düz ileri (aim 0).
## Temiz boya noktası (clean_uv): panelin dışındaki kaide duvarı üçgenlerinin dokusunda ortanca renge en yakın, 25 × 25
## teksel içinde en düzgün yer: asker (31, 30, 31), tank (47, 46, 42).
const SPECS := {
	"soldier": {"model": "res://assets/models/soldier-model.glb", "scale": 1.0,
		"band_a0": -28.0, "band_a1": 70.0, "band_y0": -0.446, "band_y1": -0.314, "r0": 0.419, "r1": 0.381,
		"clean_top": -0.285, "clean_r": 0.32, "split_y": -0.32, "face_yaw": -70.0,
		"aim": 0.8308, "muzzle": Vector3(0.3127, 0.1345, -0.3425), "clean_uv": Vector2(0.78203, 0.32277)},
	"tank": {"model": "res://assets/models/tank-model.glb", "scale": 0.9526, "center": Vector2(-0.047, -0.002),
		"band_a0": 5.0, "band_a1": 90.0, "band_y0": -0.453, "band_y1": -0.305, "r0": 0.40, "r1": 0.40,
		"clean_top": -0.291, "clean_r": 0.319, "split_y": -0.377, "face_yaw": -42.5,
		"aim": 0.0, "muzzle": Vector3(0.521, 0.049, -0.028), "clean_uv": Vector2(0.73362, 0.70584)},
}
const FACE_YAW := -70.0              ## askerin varsayılan duruşu (UnitLayer'ın varsayılan yönü)
const BASE_COLOR := Color8(28, 27, 26)
const BASE_R := 0.432                ## kaidenin en dış yarıçapı (model birimi; figür boyu 1): haritada kapladığı daire
const FLAG_U := Vector2(0.22, 0.50)  ## kuşakta bayrağın yeri (soldan; sağ ucu panelin ortası, kameraya bakan yer)
const NUM_U := 0.66                  ## sayının yeri (bayrağın sağında)
const FACE_DIR := Vector2(cos(deg_to_rad(FACE_YAW)), -sin(deg_to_rad(FACE_YAW)))  ## varsayılan duruşun harita yönü (güney-güneydoğu)
const PROFILE_N := 16

## Tür başına hazırlanmış parçalar: tür -> {top, base, mat, profile, band, flags}
static var _k := {}

## Silahın gövdeye göre açısı (asker: tüfek sola dönük; tank: namlu düz) ve namlu ucu (üst parçada, model birimi)
static func aim_yaw(kind: String) -> float:
	return float(SPECS.get(kind, SPECS["soldier"])["aim"])

static func muzzle(kind: String) -> Vector3:
	return SPECS.get(kind, SPECS["soldier"])["muzzle"]

## Modelin hazır parçaları (tür başına bir kez): asker düzenine dönüştürülmüş örgü, temizlenmiş malzeme, kaide profili
static func _prepare(kind: String) -> Dictionary:
	if _k.has(kind):
		return _k[kind]
	var sp: Dictionary = SPECS.get(kind, SPECS["soldier"])
	var k := {"flags": {}}
	_k[kind] = k
	var scene: PackedScene = load(String(sp["model"]))
	var root := scene.instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := mi.mesh
	var src := mesh.surface_get_material(0) as StandardMaterial3D
	var mat := src.duplicate() as StandardMaterial3D
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	# asker düzeni: kaide altı y = -0.5, kaide BASE_R boyunda (scale)
	var sc := float(sp["scale"])
	var base_c: Vector2 = sp.get("center", Vector2.ZERO)        # kaidenin modeldeki merkezi
	var min_y := INF
	for v in verts:
		min_y = minf(min_y, v.y)
	var dy := -0.5 - min_y * sc
	if sc != 1.0 or absf(dy) > 0.0005 or base_c != Vector2.ZERO:
		var shift := Vector3(base_c.x, 0.0, base_c.y)
		for vi in verts.size():
			verts[vi] = (verts[vi] - shift) * sc + Vector3(0.0, dy, 0.0)
		arr[Mesh.ARRAY_VERTEX] = verts
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var a0 := float(sp["band_a0"])
	var a1 := float(sp["band_a1"])
	var y0 := float(sp["band_y0"])
	var y1 := float(sp["band_y1"])
	# kaidenin panel boyunca gerçek yarıçapı (pah dahil): her yükseklik diliminde panel açılarındaki en dış nokta
	var profile := PackedFloat32Array()
	profile.resize(PROFILE_N + 1)
	profile.fill(0.0)
	for v in verts:
		if v.y < y0 - 0.002 or v.y > y1 + 0.006:      # alttaki dudak sayılmaz
			continue
		var va := rad_to_deg(atan2(v.z, v.x))
		if va < a0 - 10.0 or va > a1 + 10.0:
			continue
		var row := clampi(roundi((v.y - y0) / (y1 - y0) * PROFILE_N), 0, PROFILE_N)
		profile[row] = maxf(profile[row], Vector2(v.x, v.z).length())
	# köşesi olmayan dilimler (düz duvar): en yakın ölçülü dilimler arasından; sonra 3 dilimlik en büyük (kuşak girintilere
	# gömülmesin)
	for i in PROFILE_N + 1:
		if profile[i] > 0.0:
			continue
		var lo := i - 1
		while lo >= 0 and profile[lo] <= 0.0:
			lo -= 1
		var hi := i + 1
		while hi <= PROFILE_N and profile[hi] <= 0.0:
			hi += 1
		if lo >= 0 and hi <= PROFILE_N:
			profile[i] = lerpf(profile[lo], profile[hi], float(i - lo) / float(hi - lo))
		elif lo >= 0:
			profile[i] = profile[lo]
		elif hi <= PROFILE_N:
			profile[i] = profile[hi]
		else:
			profile[i] = lerpf(float(sp["r0"]), float(sp["r1"]), float(i) / PROFILE_N)
	var smooth := profile.duplicate()
	for i in PROFILE_N + 1:
		smooth[i] = maxf(profile[maxi(i - 1, 0)], maxf(profile[i], profile[mini(i + 1, PROFILE_N)]))
	k["profile"] = smooth
	var clean_top := float(sp["clean_top"])
	var clean_r := float(sp["clean_r"])
	# içe aktarılan LOD'lar (uzakta az üçgen) da aynı temizlikten ve ayrımdan geçer
	var surf: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var lods: Array = []                           # [kenar boyu, üçgen dizini]
	for l: Dictionary in surf.get("lods", []):
		lods.append([float(l["edge_length"]), PlaneModel._indices(l["index_data"], verts.size() > 65535)])
	var dup := {}                                  # köşe -> temiz boyalı kopyası
	var order: Array[Vector2i] = []
	var n0 := verts.size()
	for tri: PackedInt32Array in [idx] + lods.map(func(e: Array) -> PackedInt32Array: return e[1]):
		for t in range(0, tri.size(), 3):
			var cen := (verts[tri[t]] + verts[tri[t + 1]] + verts[tri[t + 2]]) / 3.0
			var cr := Vector2(cen.x, cen.z).length()
			if cen.y < y0 - 0.02 or cen.y > clean_top or cr < clean_r:
				continue
			var ang := rad_to_deg(atan2(cen.z, cen.x))
			if ang < a0 - 8.0 or ang > a1 + 8.0:
				continue
			for j in 3:
				var v := tri[t + j]
				if not dup.has(v):
					dup[v] = n0 + order.size()
					order.append(Vector2i(v, 0))
				tri[t + j] = int(dup[v])
	arr = with_copies(arr, order, [sp["clean_uv"]])
	arr[Mesh.ARRAY_INDEX] = idx
	verts = arr[Mesh.ARRAY_VERTEX]
	k["mat"] = mat
	var parts := _split(arr, verts, idx, float(sp["split_y"]), lods)
	k["top"] = parts[0]
	k["base"] = parts[1]
	root.free()
	return k

## Modeli kaide ve dönen üst parça olarak iki örgüye böler: aynı noktadaki köşeler birleşik sayılır (dikişler), üçgenler
## bağlantılı parçalara ayrılır; parçanın en alt noktası split_y'nin üstündeyse üst (asker/tank, disk), değilse kaide.
## LOD'lar ([kenar boyu, üçgen dizini]) aynı parçalara bölünür. Dönen: [üst örgü, kaide örgüsü]
static func _split(arr: Array, verts: PackedVector3Array, idx: PackedInt32Array, split_y: float, lods: Array = []) -> Array:
	var n := verts.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	var alias := PackedInt32Array()
	alias.resize(n)
	var pos_id := {}
	for i in n:
		parent[i] = i
		var k := Vector3i((verts[i] * 2000.0).round())
		if not pos_id.has(k):
			pos_id[k] = i
		alias[i] = pos_id[k]
	for t in range(0, idx.size(), 3):
		var a := _find(parent, alias[idx[t]])
		var b := _find(parent, alias[idx[t + 1]])
		var c := _find(parent, alias[idx[t + 2]])
		parent[b] = a
		parent[_find(parent, c)] = _find(parent, a)
	var low := {}                                   # parça kökü -> en alt y
	for i in n:
		var r0 := _find(parent, alias[i])
		low[r0] = minf(float(low.get(r0, INF)), verts[i].y)
	var is_top := PackedByteArray()
	is_top.resize(n)
	for i in n:
		is_top[i] = 1 if float(low[_find(parent, alias[i])]) >= split_y else 0
	var parts := _part_tris(idx, is_top)
	var lod_top := {}
	var lod_base := {}
	for l: Array in lods:
		var lp := _part_tris(l[1], is_top)
		lod_top[float(l[0])] = lp[0]
		lod_base[float(l[0])] = lp[1]
	var mesh_top := ArrayMesh.new()
	var at := arr.duplicate()
	at[Mesh.ARRAY_INDEX] = parts[0]
	mesh_top.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, at, [], lod_top)
	var mesh_base := ArrayMesh.new()
	var ab := arr.duplicate()
	ab[Mesh.ARRAY_INDEX] = parts[1]
	mesh_base.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ab, [], lod_base)
	return [mesh_top, mesh_base]

## Üçgen dizini üst ve kaide olarak (ilk köşenin parçasına göre): [üst, kaide]
static func _part_tris(tri: PackedInt32Array, is_top: PackedByteArray) -> Array:
	var top := PackedInt32Array()
	var base := PackedInt32Array()
	for t in range(0, tri.size(), 3):
		var dst := top if is_top[tri[t]] == 1 else base
		dst.append(tri[t])
		dst.append(tri[t + 1])
		dst.append(tri[t + 2])
	return [top, base]

static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x

## Köşe dizilerinin sonuna kopyalar eklenir: order [özgün köşe, sıra], kopyanın dokusu uvs[sıra] (öbür bilgileri özgün
## köşeninki). Panel boyasını silmek için: o üçgenler kopyalara bağlanır, komşu üçgenler özgün köşede kalır.
static func with_copies(arr: Array, order: Array[Vector2i], uvs: Array) -> Array:
	var out := arr.duplicate()
	var n := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for t in Mesh.ARRAY_MAX:
		if t == Mesh.ARRAY_INDEX or arr[t] == null:
			continue
		var a = arr[t]
		if a is PackedVector3Array:
			var r: PackedVector3Array = a.duplicate()
			for o in order:
				r.append((a as PackedVector3Array)[o.x])
			out[t] = r
		elif a is PackedVector2Array:
			var r: PackedVector2Array = a.duplicate()
			for o in order:
				r.append(uvs[o.y] if t == Mesh.ARRAY_TEX_UV else (a as PackedVector2Array)[o.x])
			out[t] = r
		elif a is PackedFloat32Array:
			var stride := (a as PackedFloat32Array).size() / n
			var r: PackedFloat32Array = a.duplicate()
			for o in order:
				for q in stride:
					r.append((a as PackedFloat32Array)[o.x * stride + q])
			out[t] = r
		elif a is PackedColorArray:
			var r: PackedColorArray = a.duplicate()
			for o in order:
				r.append((a as PackedColorArray)[o.x])
			out[t] = r
		else:
			push_warning("UnitFigures: beklenmeyen köşe dizisi %d" % t)
	return out

## Kaideye oturan eğri kuşak (koni parçası), u soldan sağa, v yukarıdan aşağı
static func _band(kind: String) -> ArrayMesh:
	var k := _prepare(kind)
	if k.has("band"):
		return k["band"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	var rows := PROFILE_N
	for i in seg:
		var f0 := float(i) / seg
		var f1 := float(i + 1) / seg
		for j in rows:
			var g0 := float(j) / rows
			var g1 := float(j + 1) / rows
			var q := [_band_pt(kind, f0, g0), _band_pt(kind, f1, g0), _band_pt(kind, f1, g1), _band_pt(kind, f0, g1)]
			var uvq := [Vector2(f0, g0), Vector2(f1, g0), Vector2(f1, g1), Vector2(f0, g1)]
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				for vi: int in tri:
					var p: Vector3 = q[vi]
					st.set_normal(Vector3(p.x, 0.0, p.z).normalized())
					st.set_uv(uvq[vi])
					st.add_vertex(p)
	k["band"] = st.commit()
	return k["band"]

## Kuşakta u (0 sol, 1 sağ), v (0 üst, 1 alt) noktası: kaidenin gerçek yüzeyinin (profil) 6 milimetre dışında
static func _band_pt(kind: String, u: float, v: float, lift: float = 0.006) -> Vector3:
	var sp: Dictionary = SPECS.get(kind, SPECS["soldier"])
	var y0 := float(sp["band_y0"])
	var y1 := float(sp["band_y1"])
	var ang := deg_to_rad(lerpf(float(sp["band_a1"]), float(sp["band_a0"]), u))
	var y := lerpf(y1, y0, v)
	var fr := (y - y0) / (y1 - y0) * PROFILE_N
	var i0 := clampi(floori(fr), 0, PROFILE_N)
	var i1 := clampi(i0 + 1, 0, PROFILE_N)
	var r := lerpf(float(sp["r0"]), float(sp["r1"]), fr / PROFILE_N)
	var profile: PackedFloat32Array = _k[kind]["profile"] if _k.has(kind) and _k[kind].has("profile") else PackedFloat32Array()
	if profile.size() == PROFILE_N + 1:
		r = lerpf(profile[i0], profile[i1], fr - float(i0))
	r += lift
	return Vector3(cos(ang) * r, y, sin(ang) * r)

## Ülkenin kuşak malzemesi: koyu zemin, solda bayrak (tek boy, 3:2); kuşak boyu her modelde aynı oran (tür başına ayrı
## önbellek: kuşakların açı genişliği farklı olsa da doku aynı yerleşimde)
static func _flag_mat(kind: String, c: Country) -> StandardMaterial3D:
	var flags: Dictionary = _prepare(kind)["flags"]
	if flags.has(c.tag):
		return flags[c.tag]
	var w := 512
	var h := 116
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BASE_COLOR)
	var flag: Image = FlagFactory.map_flag(c).duplicate()
	var fh := int(h * 0.86)
	var fw := int(float(w) * (FLAG_U.y - FLAG_U.x))
	flag.resize(fw, fh, Image.INTERPOLATE_LANCZOS)
	var fx := int(w * FLAG_U.x)
	var fy := (h - fh) / 2
	# ince pirinç çerçeve: koyu şeritli bayraklar kaidenin koyu zeminine karışmasın
	img.fill_rect(Rect2i(fx - 3, fy - 3, fw + 6, fh + 6), Color("b89a52"))
	img.blit_rect(flag, Rect2i(0, 0, fw, fh), Vector2i(fx, fy))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.8
	flags[c.tag] = m
	return m

## Bir figür: kaide tabanı düğümün y=0'ında, kaide ("h") yüzü kameraya (+z), sayı "h/n" etiketinde; asker/tank ve diski
## ("t") set_yaw ile döndürülür (başta varsayılan duruş). kind: "soldier" ya da "tank"
static func make(c: Country, kind: String = "soldier") -> Node3D:
	var k := _prepare(kind)
	var sp: Dictionary = SPECS.get(kind, SPECS["soldier"])
	var fig := Node3D.new()
	fig.set_meta("kind", kind)
	var holder := Node3D.new()
	holder.name = "h"
	holder.rotation.y = deg_to_rad(float(sp["face_yaw"]))
	holder.position.y = 0.5
	fig.add_child(holder)
	var base := MeshInstance3D.new()
	base.mesh = k["base"]
	base.material_override = k["mat"]
	holder.add_child(base)
	var top := Node3D.new()
	top.name = "t"
	top.rotation.y = deg_to_rad(FACE_YAW)
	top.position.y = 0.5
	fig.add_child(top)
	var body := MeshInstance3D.new()
	body.mesh = k["top"]
	body.material_override = k["mat"]
	top.add_child(body)
	var band := MeshInstance3D.new()
	band.mesh = _band(kind)
	band.material_override = _flag_mat(kind, c)
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(band)
	var num := Label3D.new()
	num.name = "n"
	num.font = UiTheme.bold_font()
	num.font_size = 72
	num.pixel_size = 0.0026                               # rakam boyu bayrak boyunda
	num.modulate = Color("f3ead0")
	num.outline_size = 0
	num.double_sided = false
	# kaidenin yüzeyinde, bayrağın sağında; kaide yukarı doğru içe eğik: yazı da o eğimle yatar (alt ucu kaideye gömülmez,
	# yukarıdan bakan kamerada daha okunur)
	var p := _band_pt(kind, NUM_U, 0.54, 0.012)
	var up := (_band_pt(kind, NUM_U, 0.0, 0.012) - _band_pt(kind, NUM_U, 1.0, 0.012)).normalized()
	var out := Vector3(p.x, 0.0, p.z).normalized()
	var side := Vector3(out.z, 0.0, -out.x)
	num.transform = Transform3D(Basis(side, up, side.cross(up)), p)
	holder.add_child(num)
	return fig

## Figürün türü (make'te verilen)
static func kind_of(fig: Node3D) -> String:
	return String(fig.get_meta("kind", "soldier")) if fig else "soldier"

static func set_count(fig: Node3D, n: int) -> void:
	var l: Label3D = fig.get_node_or_null("h/n")
	if l:
		l.text = str(n) if n < 1000 else UiTheme.format_number(n).replace(".0K", "K")

## Harita yönünün (+x doğu, +y güney) asker için y ekseni dönüşü: model +x'e bakar, y ekseninde saat yönünün tersine
## dönünce +x, -z'ye (kuzeye) kayar
static func yaw_for(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)

## Askerin (ve diskinin) baktığı yön; kaide, bayrak ve sayı yerinde kalır
static func set_yaw(fig: Node3D, yaw: float) -> void:
	var t: Node3D = fig.get_node_or_null("t")
	if t:
		t.rotation.y = yaw
