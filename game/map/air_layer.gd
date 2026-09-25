class_name AirLayer
extends Node3D
## Hava kanatlarının görünümü: üslerde park etmiş uçaklar, görev bölgesi üstünde tur atan V düzenleri,
## it dalaşı (iz mermileri, düşen uçak), yakın destek bombaları.

const VISIBLE_DIST := 2200.0
const MODEL_FILES := ["res://assets/models/muster_units.glb", "res://assets/models/units.glb"]
const MUSTER_SCALE := 0.28          ## Muster uçakları gerçek metre (~10 m kanat); tanktan biraz büyük
const BLENDER_SCALE := {"fighter": 1.25, "bomber": 0.95}
const ZS := 2.6                     ## sabit ölçek: zoom'la uçaklar büyüyüp yer değiştirmez
const ORBIT_R := 13.0               ## tur yarıçapı (× ölçek)
const ALT := 14.0                   ## avcı irtifası (× ölçek); yakın destek alçakta, dalışta yere iner
const CYCLE := 7.0                  ## bir saldırı turu (gerçek saniye)
## V düzeni (yan, geri)
const V_SLOTS := [Vector2(0, 0), Vector2(-5.0, -4.6), Vector2(5.0, -4.6), Vector2(-10.0, -9.2)]

var map: MapView3D
var camera: MapCamera3D
var models: UnitModels

var _meshes := {}
var _mmi := {}
var _zs := ZS
var _fx := {}                       ## anahtar -> Node3D (it dalaşı / bombardıman)
var _fx_timer := 0.0
var _crash_timer := 0.0

func _ready() -> void:
	for path: String in MODEL_FILES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var stack: Array[Node] = [scene]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D and not _meshes.has(String(n.name)):
				_meshes[String(n.name)] = (n as MeshInstance3D).mesh
			stack.append_array(n.get_children())
		scene.free()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/unit.gdshader")
	UnitModels.compat_material(mat)
	for name: String in ["fighter_germany", "fighter_uk", "fighter_usa", "cas_soviet", "fighter", "bomber"]:
		if not _meshes.has(name):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = UnitModels.COMPAT
		mm.use_custom_data = true
		mm.mesh = _meshes[name]
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
		add_child(mi)
		_mmi[name] = mi

func _process(delta: float) -> void:
	var close := camera != null and camera.distance < VISIBLE_DIST and World.in_game
	visible = close
	if not close:
		for ck: String in _counters.keys():
			(_counters[ck] as Node3D).queue_free()
		_counters.clear()
		for k in _fx.keys():
			_fx[k].queue_free()
		_fx.clear()
		return
	_update_planes()
	_update_projectiles(minf(delta, 0.1))
	_crash_timer -= delta
	if _crash_timer <= 0.0:
		_crash_timer = randf_range(6.0, 12.0)
		_maybe_crash()

func _view_rect() -> Rect2:
	var r := camera.distance * 1.4
	return Rect2(Vector2(camera.target.x, camera.target.z) - Vector2(r, r * 0.9), Vector2(r * 2, r * 1.8))

## Kanat -> [model adı, ülkeye özgü mü (Muster)]
func _model(w: AirWing) -> Array:
	var fac := UnitModels.faction_of(w.owner)
	if w.type == "bomber":
		return ["bomber", false]
	if w.type == "cas" and fac == "soviet":
		return ["cas_soviet", true]
	var n := "fighter_%s" % fac
	if _mmi.has(n):
		return [n, true]
	if fac == "soviet":
		return ["cas_soviet", true]
	return ["fighter", false]

func _scale(name: String) -> float:
	return (MUSTER_SCALE if not BLENDER_SCALE.has(name) else float(BLENDER_SCALE[name])) * _zs

## Muster +Z'ye, Blender -Z'ye bakar
func _yaw_fix(name: String) -> float:
	return PI if BLENDER_SCALE.has(name) else 0.0

func _update_planes() -> void:
	var view := _view_rect()
	var lists := {}
	for n: String in _mmi:
		lists[n] = []
	var t := Time.get_ticks_msec() / 1000.0
	# gruplama (tümenler gibi): aynı üs / aynı görev bölgesi + sahip + tür -> tek temsilci düzen, sayı sayaçta
	var group_lead := {}
	var group_planes := {}
	for w in Air.wings:
		if w.planes <= 0:
			continue
		var gk := "%s:%s:%s:%d" % [w.owner, w.type, "m" if w.on_mission() else "b", w.zone if w.on_mission() else w.base]
		if not group_lead.has(gk):
			group_lead[gk] = w
		group_planes[gk] = int(group_planes.get(gk, 0)) + w.planes
	var counters_seen := {}
	# üslerde bekleyenler: pist boyunca sıra
	var parked := {}
	for w in Air.wings:
		if w.planes <= 0:
			continue
		var gk := "%s:%s:%s:%d" % [w.owner, w.type, "m" if w.on_mission() else "b", w.zone if w.on_mission() else w.base]
		if group_lead[gk] != w:
			continue
		var total: int = group_planes[gk]
		var m := _model(w)
		var col: Color = World.countries[w.owner].color.darkened(0.25)
		var custom := Color(col.r, col.g, col.b, 1000.0 if m[1] else 0.0)
		if not w.on_mission():
			if not map.airbase_sites.has(w.base):
				continue
			var site: Array = map.airbase_sites[w.base]
			var pos: Vector2 = site[0]
			if not view.has_point(pos):
				continue
			var yaw: float = site[1]
			var along := Vector2(cos(yaw), sin(yaw))
			var i := int(parked.get(w.base, 0))
			var n := mini(3, maxi(1, total / 34))
			for k in n:
				var p := pos + along * ((i + k) * 3.6 - 5.5) * _zs + Vector2(-along.y, along.x) * 3.6 * _zs
				var h := maxf(map.height_at(p), 0.0) + 0.3
				var b := Basis(Vector3.UP, -yaw + PI * 0.5 + _yaw_fix(m[0])).scaled(Vector3.ONE * _scale(m[0]))
				lists[m[0]].append([Transform3D(b, Vector3(p.x, h, p.y)), custom])
			parked[w.base] = i + n
			_counter(gk, w.owner, total, Vector3(pos.x, maxf(map.height_at(pos), 0.0) + 5.0, pos.y), counters_seen)
			continue
		# görevde: hedef üstünde saldırı turu (yakın destek / bombardıman) ya da yüksekte devriye (avcı)
		var tgt := _wing_target(w)
		var center: Vector2 = tgt[0]
		if not view.has_point(center):
			continue
		var attack: bool = tgt[1]
		var dog := _in_dogfight(center)
		var n2 := mini(3, maxi(1, total / 34))
		_counter(gk, w.owner, total, Vector3(center.x, maxf(map.height_at(center), 0.0) + ALT * _zs * 1.6, center.y), counters_seen)
		var ground := maxf(map.height_at(center), 0.0)
		for k in n2:
			var key := "%d:%d" % [w.id, k]
			var ph := fmod(t / CYCLE + float(k) / float(n2) * (1.0 if attack else 0.0) + float(w.id % 7) * 0.13, 1.0)
			var pose := _flight_pose(w, k, center, ground, ph, attack, dog, t)
			var p3: Vector3 = pose[0]
			var fwd3: Vector3 = pose[1]
			var bank: float = pose[2]
			var yaw := atan2(fwd3.x, fwd3.z)
			var pitch := -asin(clampf(fwd3.y, -1.0, 1.0))
			var b := Basis(Vector3.UP, yaw + _yaw_fix(m[0])) * Basis(Vector3.RIGHT, pitch * (-1.0 if _yaw_fix(m[0]) != 0.0 else 1.0)) * Basis(Vector3.FORWARD, bank)
			b = b.scaled(Vector3.ONE * _scale(m[0]))
			lists[m[0]].append([Transform3D(b, p3), custom])
			# bomba bırakma anı (turda bir kez): dalışın dibinde
			var last: float = _phase.get(key, ph)
			_phase[key] = ph
			if attack and last < 0.7 and ph >= 0.7:
				_drop_bomb(p3, fwd3, w)
			# it dalaşı: burundan kısa atış dizileri
			if dog and randf() < 0.05:
				_fire_burst(p3 + fwd3 * 2.0 * _zs, fwd3)
	for ck: String in _counters.keys():
		if not counters_seen.has(ck):
			(_counters[ck] as Node3D).queue_free()
			_counters.erase(ck)
	for n: String in lists:
		var mm: MultiMesh = _mmi[n].multimesh
		var arr: Array = lists[n]
		if mm.instance_count < arr.size():
			mm.instance_count = arr.size() + 8
			UnitModels.compat_colors(mm)
		mm.visible_instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i][0])
			mm.set_instance_custom_data(i, arr[i][1])

# ------------------------------------------------------------------ sayaçlar
var _counters := {}                 ## grup anahtarı -> Node3D (plaka + sayı)

## Hava grubu sayacı: ülke renginde küçük plaka, uçak simgesi ve toplam uçak sayısı
func _counter(key: String, owner: String, total: int, pos: Vector3, seen: Dictionary) -> void:
	seen[key] = true
	var root: Node3D = _counters.get(key)
	if root == null:
		root = Node3D.new()
		add_child(root)
		var plate := Sprite3D.new()
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.fixed_size = true
		plate.pixel_size = 0.00042 * 0.55
		plate.no_depth_test = true
		plate.render_priority = 10
		plate.texture = _plate_tex(owner)
		root.add_child(plate)
		var icon := Sprite3D.new()
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.fixed_size = true
		icon.no_depth_test = true
		icon.render_priority = 11
		icon.texture = UiTheme.icon("air")
		# simge dosyasının çözünürlüğünden bağımsız: ekranda ~20 px
		var th := float(icon.texture.get_height()) if icon.texture else 64.0
		icon.pixel_size = 0.00042 * 0.55 * 44.0 / maxf(th, 1.0)
		icon.offset = Vector2(-38.0 * maxf(th, 1.0) / 44.0, 0)
		root.add_child(icon)
		var lbl := Label3D.new()
		lbl.font = UiTheme.bold_font()
		lbl.font_size = 40
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0, 0, 0, 0.9)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.fixed_size = true
		lbl.pixel_size = 0.00042 * 0.7
		lbl.no_depth_test = true
		lbl.render_priority = 12
		lbl.outline_render_priority = 11
		lbl.offset = Vector2(14, 0)
		lbl.name = "n"
		root.add_child(lbl)
		_counters[key] = root
	root.position = pos
	root.visible = camera.distance < 1100.0
	(root.get_node("n") as Label3D).text = str(total)

var _plates := {}
func _plate_tex(owner: String) -> Texture2D:
	if _plates.has(owner):
		return _plates[owner]
	var img := Image.create(150, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.07, 0.1, 0.92))
	img.fill_rect(Rect2i(3, 3, 144, 50), World.countries[owner].color.darkened(0.2))
	img.fill_rect(Rect2i(3, 3, 50, 50), Color(0.08, 0.13, 0.22))
	var tex := ImageTexture.create_from_image(img)
	_plates[owner] = tex
	return tex

# ------------------------------------------------------------------ uçuş
var _phase := {}                    ## "kanat:uçak" -> son tur evresi (bomba bırakma tespiti)

## Kanadın hedefi: [nokta, saldırı mı]. Yakın destek/bombardıman: bölgedeki bir muharebede düşman tümen konumu.
func _wing_target(w: AirWing) -> Array:
	var zc := World.province(w.zone).center
	if w.mission == AirWing.Mission.CAS or w.type == "bomber":
		var best := Vector2.INF
		var bd := INF
		for pid: int in Military.battles:
			if not Air.covers(w, pid):
				continue
			var b: Dictionary = Military.battles[pid]
			var side: Array = b["defenders"]
			var atk: Array = b["attackers"]
			if not atk.is_empty() and Diplomacy.are_enemies((atk[0] as Division).owner, w.owner):
				side = atk
			for d: Division in side:
				var a: Array = models.anchors.get(d.id, []) if models else []
				var pos: Vector2 = a[0] if not a.is_empty() else World.province(d.province).center
				var dd := pos.distance_squared_to(zc)
				if dd < bd:
					bd = dd
					best = pos
		if best != Vector2.INF:
			return [best, true]
	return [zc, false]

func _in_dogfight(center: Vector2) -> bool:
	for zone: int in Air.fights:
		if (Air.fights[zone]["pos"] as Vector2).distance_to(center) < ORBIT_R * _zs * 4.0:
			return true
	return false

## Tek kapalı yol: çember; saldırıda evre 0,62–0,78 arasında hedefin üstünden alçalarak geçer (dalış + toparlanma)
func _flight_pose(w: AirWing, k: int, center: Vector2, ground: float, ph: float, attack: bool, dog: bool, t: float) -> Array:
	var p := _path_point(w, k, center, ground, ph, attack, dog, t)
	var q := _path_point(w, k, center, ground, fmod(ph + 0.004, 1.0), attack, dog, t)
	var fwd := (q - p).normalized() if q.distance_to(p) > 1e-4 else Vector3(0, 0, 1)
	var dirn := 1.0 if w.id % 2 == 0 else -1.0
	var bank := 0.5 * dirn * (0.35 if attack and absf(ph - 0.7) < 0.1 else 1.0)
	return [p, fwd, bank]

func _path_point(w: AirWing, k: int, center: Vector2, ground: float, ph: float, attack: bool, dog: bool, t: float) -> Vector3:
	var dirn := 1.0 if w.id % 2 == 0 else -1.0
	var r := ORBIT_R * _zs * (1.0 + (w.id % 3) * 0.2)
	var alt := ALT * _zs * (0.75 if attack else 1.3)
	var a := (ph * TAU) * dirn + float(w.id) * 1.7
	var off := Vector2.ZERO
	if not attack:
		# devriye: V düzeni, lider çemberde
		var s: Vector2 = V_SLOTS[k]
		var tangent := Vector2(-sin(a), cos(a)) * dirn
		var side := Vector2(tangent.y, -tangent.x)
		off = (side * s.x + tangent * s.y) * _zs
		if dog:
			off += Vector2(sin(t * 2.3 + k), cos(t * 1.7 + k * 2.0)) * 5.0 * _zs
	var dip := 0.0
	if attack:
		dip = exp(-pow((ph - 0.7) / 0.075, 2.0))
	var rr := r * (1.0 - dip * 0.97)
	var xz := center + Vector2(cos(a), sin(a)) * rr + off
	var h := ground + alt - (alt - 3.2 * _zs) * dip + sin(t * 1.3 + k) * 0.3 * _zs
	return Vector3(xz.x, h, xz.y)

# ------------------------------------------------------------------ bombalar, atışlar, patlamalar
var _bombs: Array = []              ## [konum, hız]
var _tracers: Array = []            ## [konum, hız, ömür]
var _blasts := 0
var _bomb_mmi: MultiMeshInstance3D
var _tracer_mmi: MultiMeshInstance3D

func _ensure_fx_meshes() -> void:
	if _bomb_mmi != null:
		return
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	var cap := CapsuleMesh.new()
	cap.radius = 0.18
	cap.height = 1.1
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.12, 0.12, 0.12)
	cap.material = cm
	bm.mesh = cap
	_bomb_mmi = MultiMeshInstance3D.new()
	_bomb_mmi.multimesh = bm
	_bomb_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_bomb_mmi)
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 2.4)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(1.0, 0.8, 0.35)
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.7, 0.3)
	tmat.emission_energy_multiplier = 3.0
	box.material = tmat
	tm.mesh = box
	_tracer_mmi = MultiMeshInstance3D.new()
	_tracer_mmi.multimesh = tm
	_tracer_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tracer_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_tracer_mmi)

func _drop_bomb(from: Vector3, fwd: Vector3, w: AirWing) -> void:
	# yakın destek 2 bomba, bombardıman uçağı 4'lü dizi (arka arkaya düşer)
	var n := 4 if w.type == "bomber" else 2
	for i in n:
		var back := -fwd * float(i) * 1.6 * _zs
		_bombs.append([from + back + Vector3(randf_range(-0.5, 0.5), -0.8, randf_range(-0.5, 0.5)) * _zs, fwd * 9.0 * _zs])

func _fire_burst(nose: Vector3, fwd: Vector3) -> void:
	for i in 3:
		var dir := (fwd + Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), randf_range(-0.04, 0.04))).normalized()
		_tracers.append([nose + dir * i * 1.5, dir * 90.0, 0.22])

func _update_projectiles(dt: float) -> void:
	_ensure_fx_meshes()
	for i in range(_bombs.size() - 1, -1, -1):
		var b: Array = _bombs[i]
		var v: Vector3 = b[1]
		v.y -= 55.0 * dt
		b[1] = v
		var p: Vector3 = b[0] + v * dt
		b[0] = p
		var g := maxf(map.height_at(Vector2(p.x, p.z)), 0.0)
		if p.y <= g:
			_blast(Vector3(p.x, g, p.z))
			_bombs.remove_at(i)
	for i in range(_tracers.size() - 1, -1, -1):
		var tr: Array = _tracers[i]
		tr[0] = (tr[0] as Vector3) + (tr[1] as Vector3) * dt
		tr[2] = float(tr[2]) - dt
		if float(tr[2]) <= 0.0:
			_tracers.remove_at(i)
	var bm := _bomb_mmi.multimesh
	if bm.instance_count < _bombs.size():
		bm.instance_count = _bombs.size() + 8
	bm.visible_instance_count = _bombs.size()
	for i in _bombs.size():
		var v2: Vector3 = (_bombs[i][1] as Vector3).normalized()
		var basis := Basis.looking_at(v2, Vector3.UP if absf(v2.y) < 0.99 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
		bm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * _zs * 0.6), _bombs[i][0]))
	var tm := _tracer_mmi.multimesh
	if tm.instance_count < _tracers.size():
		tm.instance_count = _tracers.size() + 16
	tm.visible_instance_count = _tracers.size()
	for i in _tracers.size():
		var d: Vector3 = (_tracers[i][1] as Vector3).normalized()
		var basis2 := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
		tm.set_instance_transform(i, Transform3D(basis2, _tracers[i][0]))

## Tek seferlik isabet patlaması (ateş topu + toprak + is), sonra kendini siler
func _blast(pos: Vector3) -> void:
	if _blasts >= 20:
		return
	_blasts += 1
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var ex := models._particles_explosion()
	ex.scale = Vector3.ONE * 0.8
	var st: Array[Node] = [ex]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is GPUParticles3D:
			var gp := n as GPUParticles3D
			gp.one_shot = true
			gp.explosiveness = 0.9
			gp.amount = maxi(gp.amount / 2, 3)
		st.append_array(n.get_children())
	# kısa ömürlü ateş topu yerine: emitter'ları dışarıda kapatmadan önce ekle
	root.add_child(ex)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		_blasts -= 1
		root.queue_free())

## İt dalaşında ara ara düşen uçak: dumanla yere çakılır, yerde patlama
func _maybe_crash() -> void:
	var view := _view_rect()
	var zones: Array = []
	for zone: int in Air.fights:
		if view.has_point(Air.fights[zone]["pos"]):
			zones.append(zone)
	if zones.is_empty():
		return
	var zone: int = zones[randi() % zones.size()]
	var pos: Vector2 = Air.fights[zone]["pos"] + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * ORBIT_R * _zs
	var tags: Array = Air.fights[zone]["tags"]
	var owner: String = tags[randi() % tags.size()] if not tags.is_empty() else World.player_tag
	var name := "fighter"
	var custom := Color(0.3, 0.3, 0.3, 0.0)
	for w in Air.wings:
		if w.owner == owner:
			var m := _model(w)
			name = m[0]
			var col: Color = World.countries[owner].color.darkened(0.25)
			custom = Color(col.r, col.g, col.b, 1000.0 if m[1] else 0.0)
			break
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = UnitModels.COMPAT
	mm.use_custom_data = true
	mm.mesh = _meshes[name]
	mm.instance_count = 1
	UnitModels.compat_colors(mm)
	mm.set_instance_custom_data(0, custom)
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _scale(name)), Vector3.ZERO))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = (_mmi[name] as MultiMeshInstance3D).material_override
	var root := Node3D.new()
	var ground := maxf(map.height_at(pos), 0.0)
	root.position = Vector3(pos.x, ground + ALT * _zs, pos.y)
	root.rotation.y = randf() * TAU
	add_child(root)
	root.add_child(mi)
	var smoke := models._particles_smoke()
	smoke.scale = Vector3.ONE * 0.5
	smoke.local_coords = false
	root.add_child(smoke)
	var fire := models._particles_flash()
	fire.scale = Vector3.ONE * 0.3
	root.add_child(fire)
	var fwd := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y)) * 25.0 * _zs
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "position", root.position + fwd + Vector3(0, -(ALT * _zs), 0), 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "rotation:z", randf_range(2.0, 5.0), 3.2)
	tw.tween_property(root, "rotation:x", 0.7, 3.2)
	tw.chain().tween_callback(func() -> void:
		mi.visible = false
		var ex := models._particles_explosion()
		ex.scale = Vector3.ONE * 1.6
		ex.one_shot = true
		ex.emitting = true
		root.add_child(ex))
	tw.chain().tween_interval(3.0)
	tw.chain().tween_callback(root.queue_free)
