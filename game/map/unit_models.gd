class_name UnitModels
extends Node3D
## Yakın zoom'da tümenlerin 3D figürleri: şablona göre asker/top/tank/kamyon grupları.
## Kara modelleri: Muster WWII Model Archive (MIT, github.com/Kenton-GMI/muster-ww2) — ülkeye özgü
## teçhizat (Alman, Sovyet, İngiliz, ABD, İtalyan, Japon); diğer ülkelerin piyadesi dönem üniforma rengine boyanır.
## Figürler bölgeler arasında hareket ilerlemesine göre yürür; muharebede düşmana döner ve ateş eder.
## Muharebe bölgelerinde namlu alevi, patlama ve duman efektleri.

const MODEL_FILES := ["res://assets/models/muster_units.glb", "res://assets/models/soldiers.glb", "res://assets/models/units.glb"]
const SHADER := preload("res://assets/shaders/unit.gdshader")
const VISIBLE_DIST := 700.0          ## kamera mesafesi: bunun altında figürler görünür
## rol önekine göre ölçek (modeller gerçek metre; piyade okunabilirlik için abartılı)
const ROLE_SCALE := {"inf": 2.6, "mg": 2.6, "art": 0.95, "aa": 0.85, "tank": 0.8, "heavy": 0.78, "truck": 0.72, "cargo": 0.75}
## ülke -> teçhizat seti (muster_units.glb içindeki model son eki)
const FACTION := {
	"GER": "germany", "AUS": "germany", "SOV": "soviet", "MON": "soviet", "ENG": "uk", "CAN": "uk", "AST": "uk",
	"SAF": "uk", "NZL": "uk", "RAJ": "uk", "USA": "usa", "ITA": "italy", "JAP": "japan",
	"TUR": "turkey", "FRA": "france",
}
## Dönem üniforma renkleri (yoksa haki + ülke renginden hafif ton)
const UNIFORMS := {
	"GER": Color("5d6152"), "SOV": Color("7a7050"), "ENG": Color("7d6c4a"), "FRA": Color("6f7f94"),
	"ITA": Color("6e7358"), "TUR": Color("7a6f4e"), "POL": Color("6b6a4c"), "USA": Color("6f6246"),
	"SPR": Color("6f6a50"), "ROM": Color("6e6b52"), "HUN": Color("75694a"), "CZE": Color("6c6e52"),
	"YUG": Color("6a6650"), "GRE": Color("786c4c"), "BUL": Color("6c6a50"), "FIN": Color("6b706a"),
	"JAP": Color("7a7048"), "AUS": Color("6a6c60"),
}
const MAX_DIVS_PER_GROUP := 1       ## bir yığında tek temsilci grup (tümen sayısı sayaçta yazar)
const ZS := 2.3                      ## sabit figür ölçeği: zoom'la figürler yer değiştirmez
## Figür hareketi: dönüş hızı (rad/s), ivme (birim/s², _zs ile ölçeklenir), adım boyu (birim)
const SOLDIER := {"turn": 6.0, "accel": 10.0, "stride": 1.1, "vmax": 7.0}
const VEHICLE := {"turn": 2.6, "accel": 3.0, "stride": 0.0, "vmax": 9.0}

var map: MapView3D
var camera: MapCamera3D
var _meshes := {}
var _zs := ZS
var _mmi := {}                       ## model adı -> MultiMeshInstance3D
var _fx := {}                        ## muharebe pid -> Node3D
var _fx_timer := 0.0
var _figs := {}                      ## "divid:slot" -> figür durumu (konum, yön, hız, adım fazı)
var _face := {}                      ## div id -> son bakış yönü (Vector2)
var _flash_mmi: MultiMeshInstance3D
var _flashes: Array = []             ## [Transform3D, yaş] bu karenin namlu alevleri
var _gtracers: Array = []            ## [konum, hız, ömür] piyade iz mermileri
var _gtracer_mmi: MultiMeshInstance3D
var anchors := {}                    ## div id -> akıcı görsel konum (sayaçlar ve oklar kullanır)

## Compatibility (web/GLES3) renderer farkları — Forward+ (masaüstü) bu bayrakla hiç değişmez.
## 1) Sahne sRGB uzayında çizilir: shader'lar srgb_out=true ile çıkışı kendileri sRGB'ye çevirir.
## 2) custom_data kullanan MultiMesh'te renk yuvası sıfır kalır ve köşe rengi sıfırla çarpılır (siyah figür):
##    use_colors açılıp her instance rengi beyaz yapılır.
static var COMPAT: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"

static func compat_material(mat: ShaderMaterial) -> ShaderMaterial:
	if COMPAT:
		mat.set_shader_parameter("srgb_out", true)
	return mat

static func compat_colors(mm: MultiMesh) -> void:
	if COMPAT and mm.use_colors:
		for i in mm.instance_count:
			mm.set_instance_color(i, Color.WHITE)

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	compat_material(mat)
	for path: String in MODEL_FILES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var stack: Array[Node] = [scene]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D and not _meshes.has(String(n.name)):
				_meshes[String(n.name)] = (n as MeshInstance3D).mesh
			stack.append_array(n.get_children())
		scene.free()
	for name: String in _meshes:
		if not ROLE_SCALE.has(name.get_slice("_", 0)):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = COMPAT
		mm.use_custom_data = true
		mm.mesh = _meshes.get(name)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
		add_child(mi)
		_mmi[name] = mi
	# namlu alevleri: ateş eden figürlerin namlu ucunda anlık yıldız parlamaları
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	fm.use_custom_data = true
	fm.mesh = _vquad(1.0, 2, Color.WHITE, 1.4)
	_flash_mmi = MultiMeshInstance3D.new()
	_flash_mmi.multimesh = fm
	_flash_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_flash_mmi)
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.22, 3.6)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(1.0, 0.85, 0.45)
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.75, 0.35)
	tmat.emission_energy_multiplier = 2.5
	box.material = tmat
	tm.mesh = box
	_gtracer_mmi = MultiMeshInstance3D.new()
	_gtracer_mmi.multimesh = tm
	_gtracer_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gtracer_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_gtracer_mmi)

func _process(delta: float) -> void:
	var close := camera != null and camera.distance < VISIBLE_DIST and World.in_game
	visible = close
	_update_anchors()
	if not close:
		if not _fx.is_empty():
			for pid in _fx.keys():
				_fx[pid].queue_free()
			_fx.clear()
		_figs.clear()
		return
	_update_models(minf(delta, 0.1))
	_fx_timer += delta
	if _fx_timer > 0.2:
		_fx_timer = 0.0
		_update_fx()

## Kameranın gördüğü alan (yaklaşık): hedef nokta etrafında mesafeyle orantılı yarıçap
func _view_rect() -> Rect2:
	var r := camera.distance * 1.3
	return Rect2(Vector2(camera.target.x, camera.target.z) - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.6))

## Tüm tümenlerin akıcı görsel konumları (saat içi ara değer + eğri); aynı bölgede duranlar yan yana
func _update_anchors() -> void:
	anchors.clear()
	if not World.in_game:
		return
	var stacks := {}
	for d in Military.divisions:
		var m := PathMotion.division(d)
		if m[2] and d.attacking == 0:
			anchors[d.id] = [m[0], m[1], 0.5, float(m[3])]
			continue
		var key := "%d:%s" % [d.province, d.owner]
		if not stacks.has(key):
			stacks[key] = []
		stacks[key].append(d)
	for key: String in stacks:
		var divs: Array = stacks[key]
		for i in divs.size():
			var d: Division = divs[i]
			var here := World.province(d.province).center
			var facing := _facing(d)
			var pos := here
			var state := 0.0
			if d.attacking > 0:
				var tgt := World.province(d.attacking).center
				facing = (tgt - here).normalized()
				pos = here.lerp(tgt, 0.2)
				state = 1.0
			elif d.in_combat:
				state = 1.0
			anchors[d.id] = [pos, facing, state, 0.0]

## Duran tümenin bakışı: düşman komşuya; yoksa son hareket yönü
func _facing(d: Division) -> Vector2:
	var here := World.province(d.province).center
	for n in World.land_neighbors(d.province):
		if Diplomacy.are_enemies(World.controller_tag(n), d.owner):
			var f := (World.province(n).center - here).normalized()
			_face[d.id] = f
			return f
	return _face.get(d.id, Vector2(0, 1))

func _update_models(dt: float) -> void:
	var view := _view_rect()
	var lists := {}
	for name: String in _mmi:
		lists[name] = []
	var per_stack := {}
	var seen := {}
	for d in Military.divisions:
		var a: Array = anchors.get(d.id, [])
		if a.is_empty() or not view.has_point(a[0]):
			continue
		var key := "%d:%d:%s" % [d.province, d.path[0] if not d.path.is_empty() and float(a[2]) > 0.25 and float(a[2]) < 0.75 else -1, d.owner]
		per_stack[key] = int(per_stack.get(key, 0)) + 1
		if int(per_stack[key]) > MAX_DIVS_PER_GROUP:
			continue
		_place_division(d, a, lists, seen, dt)
	for k: String in _figs.keys():
		if not seen.has(k):
			_figs.erase(k)
	var fmm := _flash_mmi.multimesh
	if fmm.instance_count < _flashes.size():
		fmm.instance_count = _flashes.size() + 32
	fmm.visible_instance_count = _flashes.size()
	for i in _flashes.size():
		fmm.set_instance_transform(i, _flashes[i])
		fmm.set_instance_color(i, Color(1, 1, 1, randf_range(0.5, 1.0)))
		fmm.set_instance_custom_data(i, Color(randf() * TAU, 0, 0, 0))
	_flashes.clear()
	for i in range(_gtracers.size() - 1, -1, -1):
		var tr: Array = _gtracers[i]
		tr[0] = (tr[0] as Vector3) + (tr[1] as Vector3) * dt
		tr[2] = float(tr[2]) - dt
		if float(tr[2]) <= 0.0:
			_gtracers.remove_at(i)
	var gm := _gtracer_mmi.multimesh
	if gm.instance_count < _gtracers.size():
		gm.instance_count = _gtracers.size() + 32
	gm.visible_instance_count = _gtracers.size()
	for i in _gtracers.size():
		var d3: Vector3 = (_gtracers[i][1] as Vector3).normalized()
		gm.set_instance_transform(i, Transform3D(Basis.looking_at(d3, Vector3.UP), _gtracers[i][0]))
	for name: String in lists:
		var mm: MultiMesh = _mmi[name].multimesh
		var arr: Array = lists[name]
		if mm.instance_count < arr.size():
			mm.instance_count = arr.size() + 16
			compat_colors(mm)
		mm.visible_instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i][0])
			mm.set_instance_custom_data(i, arr[i][1])

static func uniform_color(tag: String) -> Color:
	if UNIFORMS.has(tag):
		return UNIFORMS[tag]
	var c: Color = World.countries[tag].color
	return Color("6d6a4e").lerp(c, 0.18)

## Ülkenin teçhizat seti; tanımlı değilse ideolojiye göre
static func faction_of(tag: String) -> String:
	if FACTION.has(tag):
		return FACTION[tag]
	match World.countries[tag].ideology:
		"fascism": return "germany"
		"communism": return "soviet"
	return "uk"

## Rol + ülke -> model adı ve ülkeye özgü mü (değilse üniforma boyanır)
func _model(role: String, fac: String) -> Array:
	var name := "%s_%s" % [role, fac]
	if _mmi.has(name):
		return [name, true]
	match role:
		"inf", "mg": return ["%s_soviet" % role, false]
		"art": return ["art_germany" if fac in ["italy", "japan"] else "art_uk", true]
		"tank": return ["tank_germany", true]
		"truck": return ["truck_germany" if fac in ["germany", "italy", "japan"] else "truck_soviet", true]
		"cargo": return ["cargo_ship", true]
	return [name, true]

## Tümenin figür yuvaları: yürüyüşte iki sıralı kol, beklerken savunma hattı, muharebede yayılmış hat
func _slots(d: Division, moving: bool, firing: bool) -> Array:
	# denizde (nakliye): askerler değil, nakliye gemisi
	if not World.province(d.province).is_land() or (not d.path.is_empty() and not World.province(d.path[0]).is_land() and moving):
		return [["cargo", 0.0, 0.0]]
	var c: Country = World.countries[d.owner]
	var bats: Dictionary = c.templates[clampi(d.template, 0, c.templates.size() - 1)]["battalions"]
	var armor := int(bats.get("light_armor", 0)) + int(bats.get("medium_armor", 0))
	var arty := int(bats.get("artillery", 0)) + int(bats.get("anti_tank", 0))
	var motor := int(bats.get("motorized", 0))
	if armor > 0:
		if moving:
			return [["tank", 0.0, 3.0], ["tank", 0.0, -1.2], ["truck", 0.0, -5.2]]
		return [["tank", -2.6, 1.4], ["tank", 2.6, 1.4], ["truck", 0.0, -3.6]]
	var out: Array = []
	if moving:
		out = [["inf", -0.55, 2.4], ["inf", 0.55, 2.4], ["inf", -0.55, 1.1], ["inf", 0.55, 1.1], ["mg", 0.0, -0.2]]
		if motor > 0:
			out.append(["truck", 0.0, -3.4])
		elif arty > 0:
			out.append(["art", 0.0, -3.2])
		return out
	var spread := 1.35 if firing else 1.0
	out = [["inf", -1.7 * spread, 1.0], ["inf", 0.0, 1.5], ["inf", 1.7 * spread, 1.0], ["mg", -0.8, 0.0], ["inf", 0.9, -0.2]]
	if motor > 0:
		out.append(["truck", 0.0, -3.4])
	elif arty > 0:
		out.append(["art", 0.0, -3.0])
	return out

func _place_division(d: Division, a: Array, lists: Dictionary, seen: Dictionary, dt: float) -> void:
	var pos: Vector2 = a[0]
	var facing: Vector2 = a[1]
	if facing == Vector2.ZERO:
		facing = _face.get(d.id, Vector2(0, 1))
	else:
		_face[d.id] = facing
	var state: float = a[2]
	var div_speed: float = a[3]
	var moving := state > 0.25 and state < 0.75
	var firing := state >= 0.75
	var side := Vector2(-facing.y, facing.x)
	var col: Color = uniform_color(d.owner)
	var fac := faction_of(d.owner)
	var slots := _slots(d, moving, firing)
	var face_yaw := atan2(facing.x, facing.y)
	for i in slots.size():
		var sl: Array = slots[i]
		var role: String = sl[0]
		var m := _model(role, fac)
		var name: String = m[0]
		if not lists.has(name):
			continue
		var native: bool = m[1]
		var target := pos + (side * float(sl[1]) + facing * float(sl[2])) * _zs * 1.5
		var key := "%d:%d" % [d.id, i]
		seen[key] = true
		var infantry := role == "inf" or role == "mg"
		var k: Dictionary = SOLDIER if infantry else VEHICLE
		var f: Dictionary = _figs.get(key, {})
		if f.is_empty() or f["pos"].distance_to(target) > 60.0 * _zs:
			f = {"pos": target, "yaw": face_yaw, "v": 0.0, "phase": randf(), "name": name}
			_figs[key] = f
		if moving:
			_steer(f, target, face_yaw, div_speed, k, dt)
		else:
			# duran tümen: figürler yerinde (zoom ölçeği değişse de yürümez), yalnız bakış yumuşak döner
			f["pos"] = target
			f["last"] = target
			f["v"] = 0.0
			f["yaw"] = lerp_angle(float(f["yaw"]), face_yaw, minf(dt * 4.0, 1.0))
		var fp: Vector2 = f["pos"]
		var yaw: float = f["yaw"]
		var h := maxf(map.height_at(fp), 0.0)
		var sc := float(ROLE_SCALE[role]) * _zs
		var basis := Basis(Vector3.UP, yaw)
		if role == "cargo":
			basis = Basis(Vector3.UP, yaw + PI)
		elif not infantry:
			basis = _terrain_basis(fp, yaw, sc)
		basis = basis.scaled(Vector3.ONE * sc)
		# durum: 0 bekleme, 1 yürüyüş (adım fazı), 2 ateş; +1000 ülkeye özgü (boyanmaz)
		var st := 0.0
		var v: float = f["v"]
		if infantry and v > 0.15 * _zs:
			f["phase"] = fmod(float(f["phase"]) + v * dt / (float(k["stride"]) * sc), 1.0)
			st = 100.0 + float(f["phase"]) * 99.0
		elif firing:
			st = 200.0
			# namlu alevi: piyade sık ve küçük, top/tank seyrek ve büyük
			var chance := 0.16 if infantry else 0.035
			if randf() < chance:
				var fwd3 := Vector3(sin(yaw), 0.0, cos(yaw))
				var tip := Vector3(fp.x, h, fp.y) + fwd3 * sc * (0.55 if infantry else 1.9) + Vector3.UP * sc * (0.55 if infantry else 0.45)
				var fs := sc * (0.45 if infantry else 1.3) * randf_range(0.8, 1.2)
				_flashes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(fs, fs, fs)), tip))
			# iz mermisi: makineli sık kısa diziler, tüfekçi ara sıra; düşmana doğru
			var tchance := 0.3 if role == "mg" else (0.05 if infantry else 0.0)
			if randf() < tchance:
				var fwd4 := Vector3(sin(yaw), 0.0, cos(yaw))
				var tip2 := Vector3(fp.x, h, fp.y) + fwd4 * sc * 0.6 + Vector3.UP * sc * 0.55
				for bi in (3 if role == "mg" else 1):
					var dir := (fwd4 + Vector3(randf_range(-0.08, 0.08), randf_range(-0.01, 0.03), randf_range(-0.08, 0.08))).normalized()
					_gtracers.append([tip2 + dir * bi * 2.0, dir * 150.0, 0.16])
		elif not infantry and v > 0.2 * _zs:
			st = 100.0 + fmod(float(f["phase"]) + v * dt * 0.05, 1.0) * 99.0
			f["phase"] = (st - 100.0) / 99.0
		var custom := Color(col.r, col.g, col.b, st + (1000.0 if native else 0.0))
		lists[name].append([Transform3D(basis, Vector3(fp.x, h, fp.y)), custom])

## Figür yönlendirme: tümenin hızını taşır (ileri besleme, geride kalmaz); formasyon içindeki yer değişimini
## kendi hızıyla, önce dönüp sonra yürüyerek yapar. f["v"] = gerçek yer hızı (adım fazı ve durum için)
func _steer(f: Dictionary, target: Vector2, face_yaw: float, _div_speed: float, k: Dictionary, dt: float) -> void:
	var pos: Vector2 = f["pos"]
	var last: Vector2 = f.get("last", target)
	var tv := (target - last) / maxf(dt, 0.001)
	if tv.length() > 3000.0:
		tv = Vector2.ZERO
	f["last"] = target
	var carried := pos + tv * dt
	var res := target - carried
	var dist := res.length()
	var arrive := 0.3 * _zs
	var yaw: float = f["yaw"]
	# istenen bakış: hareket varsa hareket yönü, yuvada tümen yönü
	var move_dir := tv
	var lv := 0.0
	if dist > arrive:
		lv = minf(dist * 2.5, float(k["vmax"]) * _zs * 0.4)
		move_dir += res / dist * lv
	var desired := face_yaw
	if move_dir.length() > 0.3 * _zs:
		desired = atan2(move_dir.x, move_dir.y)
	var err := wrapf(desired - yaw, -PI, PI)
	var turn := float(k["turn"]) * dt
	yaw += clampf(err, -turn, turn)
	f["yaw"] = yaw
	# yerel düzeltme yalnız bakılan yöne doğru (yana kayma yok); yuvaya çok yakında yumuşak oturma
	var fwd := Vector2(sin(yaw), cos(yaw))
	var local := fwd * lv * maxf(fwd.dot(res / maxf(dist, 0.001)), 0.0) * dt
	var npos := carried + local
	if dist < arrive * 3.0:
		npos = npos.lerp(target, minf(dt * 3.0, 1.0))
	var ground := (npos - pos).length() / maxf(dt, 0.001)
	f["v"] = lerpf(float(f["v"]), ground, minf(dt * 8.0, 1.0))
	f["pos"] = npos

## Araç araziye oturur: ön-arka ve sağ-sol yükseklik farkından eğim
func _terrain_basis(p: Vector2, yaw: float, sc: float) -> Basis:
	var fwd := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(fwd.y, -fwd.x)
	var L := 3.0 * sc
	var W := 1.4 * sc
	var hf := maxf(map.height_at(p + fwd * L), 0.0)
	var hb := maxf(map.height_at(p - fwd * L), 0.0)
	var hr := maxf(map.height_at(p + right * W), 0.0)
	var hl := maxf(map.height_at(p - right * W), 0.0)
	var f3 := Vector3(fwd.x * 2.0 * L, hf - hb, fwd.y * 2.0 * L).normalized()
	var r3 := Vector3(right.x * 2.0 * W, hr - hl, right.y * 2.0 * W).normalized()
	var up := f3.cross(r3).normalized()
	if up.y < 0.0:
		up = -up
	var x := up.cross(f3).normalized()
	return Basis(x, up, f3)

# ------------------------------------------------------------------ muharebe efektleri
func _update_fx() -> void:
	var view := _view_rect()
	for pid in _fx.keys():
		if not Military.battles.has(pid):
			_fx[pid].queue_free()
			_fx.erase(pid)
	for pid: int in Military.battles:
		if _fx.has(pid):
			continue
		var b: Dictionary = Military.battles[pid]
		var a := World.province(int(b["from"])).center
		var t := World.province(pid).center
		var mid := a.lerp(t, 0.5)
		if not view.has_point(mid):
			continue
		var node := Node3D.new()
		node.position = Vector3(mid.x, maxf(map.height_at(mid), 0.0) + 1.0, mid.y)
		node.rotation.y = atan2((t - a).x, (t - a).y)
		add_child(node)
		node.add_child(_particles_flash())
		node.add_child(_particles_explosion())
		node.add_child(_particles_smoke())
		_fx[pid] = node

func _quad(size: float, color: Color, emission: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _soft_dot()
	if emission > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	return q

var _dot: Texture2D

func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_dot = gt
	return _dot

func _pmat(box: Vector3, vel: float, spread: float, grav: float, scale_curve: bool) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(0, 1, 0)
	pm.spread = spread
	pm.initial_velocity_min = vel * 0.5
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(0, grav, 0)
	if scale_curve:
		var c := Curve.new()
		c.add_point(Vector2(0, 0.4))
		c.add_point(Vector2(1, 1.6))
		var ct := CurveTexture.new()
		ct.curve = c
		pm.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	return pm

## Prosedürel efekt dörtgeni (assets/shaders/vfx.gdshader): kind 0 ateş topu, 1 duman, 2 namlu alevi, 3 toprak
var _vfx_cache := {}
func _vquad(size: float, kind: int, tint := Color.WHITE, intensity := 1.0) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var key := "%d:%s:%.2f" % [kind, tint.to_html(), intensity]
	if not _vfx_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/vfx.gdshader")
		UnitModels.compat_material(m)
		m.set_shader_parameter("kind", kind)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("intensity", intensity)
		m.render_priority = 3 if kind != 1 else 1
		_vfx_cache[key] = m
	q.material = _vfx_cache[key]
	return q

func _emitter(amount: int, life: float, pm: ParticleProcessMaterial, mesh: QuadMesh, explosive := 0.0, extent := 40.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.randomness = 0.8
	p.explosiveness = explosive
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-extent, -5, -extent), Vector3(extent * 2, extent * 1.5, extent * 2))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _rand_angle(pm: ParticleProcessMaterial) -> ParticleProcessMaterial:
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	return pm

## Tüfek/makineli ateşi: cephe hattı boyunca kısa, yıldız biçimli namlu alevleri
func _particles_flash() -> GPUParticles3D:
	return _emitter(22, 0.07, _rand_angle(_pmat(Vector3(14, 1.0, 8), 0.2, 10, 0, false)), _vquad(2.4, 2))

## Top mermisi isabeti: gürültülü ateş topu + fırlayan toprak + ardından kabaran is
func _particles_explosion() -> GPUParticles3D:
	var root := _emitter(6, 1.0, _rand_angle(_pmat(Vector3(14, 0.2, 9), 3.0, 25, 1.0, true)), _vquad(13.0, 0), 0.3, 60.0)
	var dirt_pm := _pmat(Vector3(14, 0.1, 9), 22.0, 30, -34.0, false)
	root.add_child(_emitter(26, 1.3, _rand_angle(dirt_pm), _vquad(2.0, 3, Color(0.7, 0.6, 0.5)), 0.3, 60.0))
	var puff_pm := _pmat(Vector3(14, 0.2, 9), 2.4, 30, 0.8, true)
	root.add_child(_emitter(10, 2.6, _rand_angle(puff_pm), _vquad(14.0, 1, Color(0.2, 0.18, 0.16, 0.8)), 0.3, 60.0))
	return root

## Muharebe dumanı: yavaş yükselen, büyüyen, düzensiz kenarlı gri bulutlar
func _particles_smoke() -> GPUParticles3D:
	var pm := _rand_angle(_pmat(Vector3(15, 0.3, 10), 3.2, 18, 0.7, true))
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	return _emitter(26, 5.5, pm, _vquad(18.0, 1, Color(0.42, 0.4, 0.37, 0.6)), 0.0, 70.0)
