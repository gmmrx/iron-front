class_name FleetLayer
extends Node3D
## Filoların haritadaki görünümü: sayaçlar (seçim), limanda demirli / denizde seyreden 3D gemiler,
## seyir izi, dalıştaki denizaltılar, deniz muharebesi efektleri (top alevi, su sütunları, duman) ve batan gemiler.

const PIXEL := 0.00042
const SHIP_DIST := 1600.0              ## kamera bu mesafenin altındayken 3D gemiler görünür
const MODELS := ["battleship", "cruiser", "destroyer", "submarine"]
const SHIP_SCALE := {"battleship": 0.62, "cruiser": 0.7, "destroyer": 0.8, "submarine": 0.8}
## seyir düzeni (sağ-sol, ileri-geri): ortada ağır gemi, önde ve yanlarda eskort, arkada bir gemi
const SLOTS := [Vector2(0, 3.5), Vector2(-4.2, -3.0), Vector2(4.2, -3.0)]   ## sıkı üçgen: amiral önde, iki eskort arkada
## limanda: kıyıya paralel ikişerli sıra (x: kıyı boyunca, y: denize doğru)
const PORT_SLOTS := [Vector2(0, 0), Vector2(-2.6, 0), Vector2(2.6, 0)]   ## limanda yan yana, pruva denize (kıç rıhtımda)
const MODEL_LEN := {"battleship": 12.0, "cruiser": 8.5, "destroyer": 6.0, "submarine": 6.5}
const MAX_SHOWN := 3                  ## bir konumda en çok bu kadar gemi modeli (sayı sayaçta yazar)
const ZS := 1.4                        ## sabit model/düzen ölçeği: zoom'la konumlar oynamaz
const TURN_SMOOTH := 5.0               ## pruva rota yönünü bu yumuşaklıkla izler

var map: MapView3D
var camera: MapCamera3D
var models: UnitModels
var selected: Fleet = null

var _meshes := {}
var _mmi := {}
var _wake: MultiMeshInstance3D
var _counters := {}                    ## fleet id -> {root, bg, label, key}
var _tex := {}
var _fx := {}                          ## deniz pid -> Node3D
var _timer := 0.0
var _zs := ZS
var _positions := {}                   ## fleet id -> [Vector2 pos, Vector2 heading]
var _pulse := 0.0
var _dock := {}                        ## liman pid -> [su noktası, denize dönük yön]
var _groups := {}                      ## filo id -> {pos, yaw, rate, v, depth, last}
var _trails := {}                      ## filo id -> geçilen noktalar (yeniden eskiye), pruva hattı için
var _anchor := {}                      ## filo id -> akıcı konum (sayaç)

func _ready() -> void:
	var scene: Node = (load("res://assets/models/units.glb") as PackedScene).instantiate()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			_meshes[String(n.name)] = (n as MeshInstance3D).mesh
		stack.append_array(n.get_children())
	scene.free()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/unit.gdshader")
	UnitModels.compat_material(mat)
	for name: String in MODELS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = UnitModels.COMPAT
		mm.use_custom_data = true
		mm.mesh = _meshes.get(name)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
		add_child(mi)
		_mmi[name] = mi
	# seyir izi: gemi arkasında V şeklinde köpük
	var wm := MultiMesh.new()
	wm.transform_format = MultiMesh.TRANSFORM_3D
	wm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	var wmat := ShaderMaterial.new()
	wmat.shader = preload("res://assets/shaders/wake.gdshader")
	q.material = wmat
	wm.mesh = q
	_wake = MultiMeshInstance3D.new()
	_wake.multimesh = wm
	_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wake.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_wake)
	Navy.fleets_changed.connect(_sync_counters)
	Navy.ship_sunk.connect(_on_sunk)
	World.player_changed.connect(func(_t: String) -> void: select(null))
	_sync_counters()

func _process(delta: float) -> void:
	_pulse += delta
	if not World.in_game:
		visible = false
		return
	visible = true
	var dt := minf(delta, 0.1)
	_update_positions(dt)
	_update_counters()
	var close := camera.distance < SHIP_DIST
	for name: String in _mmi:
		_mmi[name].visible = close
	_wake.visible = close
	if close:
		_update_ships(dt)
	else:
		_groups.clear()
	_timer += delta
	if _timer > 0.2:
		_timer = 0.0
		_update_fx(close)

# ------------------------------------------------------------------ konum
## Filo çapaları: limanda rıhtım, seyirde saat içi ara değerli eğri (PathMotion); aynı yerdekiler yan yana
func _update_positions(dt: float) -> void:
	_positions.clear()
	var slot := {}
	for f in Navy.fleets:
		var here := World.province(f.location)
		var base := SeaLanes.node(f.location) if not here.is_land() else here.center
		var heading := Vector2(0, 1)
		if here.is_land():
			var dk := _dock_point(f.location)
			var out: Vector2 = dk[1]
			base = dk[0]
			heading = out
		var m := PathMotion.fleet(f, base)
		var pos: Vector2 = m[0]
		if m[2]:
			heading = m[1]
		# aynı yerde (ve aynı rotada) duran/giden filolar tek grup: modeller bir kez, sayaçlar yan yana
		var k := "%d:%d:%s" % [f.location, f.path[0] if not f.path.is_empty() else -1, f.owner]
		var i := int(slot.get(k, 0))
		slot[k] = i + 1
		_positions[f.id] = [pos, heading, m[2], float(m[3]), i, k]
		# pruva hattı izi
		var tr: Array = _trails.get(f.id, [])
		if tr.is_empty() or (tr[0] as Vector2).distance_to(pos) > 1.2 * _zs:
			tr.push_front(pos)
			if tr.size() > 120:
				tr.pop_back()
		_trails[f.id] = tr
	for id: int in _trails.keys():
		if not _positions.has(id):
			_trails.erase(id)

## İz üzerinde, baştan geriye doğru `back` birim gerideki nokta ve yön
func _trail_point(id: int, back: float) -> Array:
	var tr: Array = _trails.get(id, [])
	if tr.size() < 2:
		return []
	var acc := 0.0
	for i in tr.size() - 1:
		var a: Vector2 = tr[i]
		var b: Vector2 = tr[i + 1]
		var seg := a.distance_to(b)
		if acc + seg >= back:
			var t := (back - acc) / maxf(seg, 0.001)
			return [a.lerp(b, t), (a - b).normalized()]
		acc += seg
	return []

## Limanın rıhtımı: şehirden denize doğru ilk su pikseli
func _dock_point(pid: int) -> Array:
	if _dock.has(pid):
		return _dock[pid]
	var p := World.province(pid)
	var from := p.city.position if p.city else p.center
	var sea := Navy.sea_for(pid)
	# liman modeli varsa gemiler tam önüne, ilk suya yanaşır
	if map.harbors.has(pid):
		var hb: Array = map.harbors[pid]
		var hp: Vector2 = hb[0]
		var hd: Vector2 = hb[1]
		for i in 60:
			if is_water(hp):
				break
			hp += hd * 1.0
		_dock[pid] = [hp + hd * 1.5, hd]
		return _dock[pid]
	var ld := SeaLanes.dock(pid, sea) if sea > 0 else Vector2.INF
	if ld != Vector2.INF:
		_dock[pid] = [ld, (SeaLanes.node(sea) - ld).normalized()]
		return _dock[pid]
	var dir := (World.province(sea).center - from).normalized() if sea > 0 else Vector2(0, 1)
	var pt := from
	for i in 120:
		if is_water(pt):
			break
		pt += dir * 1.5
	_dock[pid] = [pt, dir]
	return _dock[pid]

func is_water(pt: Vector2) -> bool:
	var q := World.province(map.province_at(pt))
	return q != null and not q.is_land()

## Kara üstüne düşen gemiyi verilen yönde suya it
func _to_water(pt: Vector2, dir: Vector2) -> Vector2:
	var p := pt
	for i in 40:
		if is_water(p):
			return p
		p += dir * 2.0
	return pt

# ------------------------------------------------------------------ sayaçlar
func _sync_counters() -> void:
	var alive := {}
	for f in Navy.fleets:
		alive[f.id] = true
		if not _counters.has(f.id):
			_counters[f.id] = _make_counter(f.owner)
	for id: int in _counters.keys():
		if not alive.has(id):
			_counters[id]["root"].queue_free()
			_counters.erase(id)
	if selected and not selected in Navy.fleets:
		selected = null

var _group_ships := {}

func _update_counters() -> void:
	_group_ships.clear()
	for f in Navy.fleets:
		if _positions.has(f.id):
			var gk: String = _positions[f.id][5]
			_group_ships[gk] = int(_group_ships.get(gk, 0)) + f.total()
	var far := camera.distance > UnitLayer.FAR_ALL
	var world := camera.distance > UnitLayer.WORLD_VIEW
	for f in Navy.fleets:
		var c: Dictionary = _counters.get(f.id, {})
		if c.is_empty():
			continue
		var pos: Vector2 = _positions[f.id][0]
		var root: Node3D = c["root"]
		var idx: int = _positions[f.id][4]
		root.position = Vector3(pos.x, 6.0, pos.y)
		# aynı yer + rota + sahip: tek sayaç (ilk filo gösterir, toplam gemi); diğerleri gizli — kayan yan yana sayaç yok
		if idx > 0:
			root.visible = false
			continue
		root.visible = not world and (not far or f.owner == World.player_tag or Diplomacy.are_enemies(f.owner, World.player_tag))
		var sel := f == selected
		var key := "%s:%d:%s:%s" % [f.owner, roundi(f.org * 10.0), sel, f.is_sub_fleet()]
		if c["key"] != key:
			c["key"] = key
			c["bg"].texture = _tex_for(f.owner, roundi(f.org * 10.0), sel, f.is_sub_fleet())
		var gk: String = _positions[f.id][5]
		c["label"].text = str(int(_group_ships.get(gk, f.total())))
		root.scale = Vector3.ONE * ((1.0 + 0.07 * sin(_pulse * 5.0)) if sel else 1.0)

func _make_counter(tag: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var bg := Sprite3D.new()
	bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg.fixed_size = true
	bg.pixel_size = PIXEL * 0.6
	bg.no_depth_test = true
	bg.render_priority = 10
	bg.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(bg)
	var lbl := Label3D.new()
	lbl.font = UiTheme.bold_font()
	lbl.font_size = 40
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.modulate = Color(1, 0.97, 0.9)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = true
	lbl.pixel_size = PIXEL * 0.8
	lbl.no_depth_test = true
	lbl.render_priority = 12
	lbl.outline_render_priority = 11
	lbl.offset = Vector2(22, 7)
	root.add_child(lbl)
	return {"root": root, "bg": bg, "label": lbl, "key": ""}

## Deniz sayacı: ülke renginde plaka, lacivert şerit, gemi silueti (denizaltıda periskop), org çubuğu
func _tex_for(tag: String, ob: int, selected_: bool, sub: bool) -> Texture2D:
	var ck := "%s:%d:%s:%s" % [tag, ob, selected_, sub]
	if _tex.has(ck):
		return _tex[ck]
	var c: Country = World.countries[tag]
	var w := 132
	var h := 64
	var bh := 52
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, w, h), Color(0.05, 0.07, 0.1, 0.95))
	img.fill_rect(Rect2i(3, 3, w - 6, bh - 6), c.color.darkened(0.15))
	img.fill_rect(Rect2i(3, 3, 44, bh - 6), Color(0.08, 0.13, 0.22))
	var ink := Color(0.88, 0.9, 0.95)
	# gövde (yamuk) + köprü + baca / kule
	for y in 6:
		var inset := y
		img.fill_rect(Rect2i(8 + inset, 30 + y, 32 - inset * 2 + (4 if y < 2 else 0), 1), ink)
	if sub:
		img.fill_rect(Rect2i(21, 22, 7, 8), ink)
		img.fill_rect(Rect2i(24, 14, 2, 8), ink)
		img.fill_rect(Rect2i(8, 36, 32, 2), Color(0.3, 0.5, 0.8))
	else:
		img.fill_rect(Rect2i(16, 24, 14, 6), ink)
		img.fill_rect(Rect2i(20, 18, 5, 6), ink)
		img.fill_rect(Rect2i(12, 27, 3, 3), ink)
		img.fill_rect(Rect2i(33, 27, 3, 3), ink)
		img.fill_rect(Rect2i(8, 38, 34, 2), Color(0.3, 0.5, 0.8))
	img.fill_rect(Rect2i(3, bh, int((w - 6) * ob / 10.0), 5), Color(0.45, 0.85, 0.35))
	var brass := Color(1.0, 0.84, 0.36) if selected_ else Color(0.55, 0.68, 0.85)
	var bw := 4 if selected_ else 1
	for k in bw:
		for x in w:
			img.set_pixel(x, k, brass); img.set_pixel(x, bh - 1 - k, brass)
		for y in bh:
			img.set_pixel(k, y, brass); img.set_pixel(w - 1 - k, y, brass)
	var tex := ImageTexture.create_from_image(img)
	_tex[ck] = tex
	return tex

## Ekran noktasındaki filo (sayaç üzerinde)
func pick(screen: Vector2) -> Fleet:
	var best: Fleet = null
	var bd := 40.0
	for f in Navy.fleets:
		var c: Dictionary = _counters.get(f.id, {})
		if c.is_empty() or not c["root"].visible:
			continue
		var p3: Vector3 = c["root"].global_position
		if camera.is_position_behind(p3):
			continue
		var sp := camera.unproject_position(p3)
		var d := sp.distance_to(screen)
		if d < bd:
			bd = d
			best = f
	return best

func fleet_position(f: Fleet) -> Vector2:
	if _positions.has(f.id):
		return _positions[f.id][0]
	return World.province(f.location).center

func select(f: Fleet) -> void:
	selected = f
	for id: int in _counters:
		_counters[id]["key"] = ""

# ------------------------------------------------------------------ 3D gemiler
func _view_rect() -> Rect2:
	var r := camera.distance * 1.4
	return Rect2(Vector2(camera.target.x, camera.target.z) - Vector2(r, r * 0.9), Vector2(r * 2, r * 1.8))

func _update_ships(dt: float) -> void:
	var view := _view_rect()
	var lists := {}
	for name: String in MODELS:
		lists[name] = []
	var wakes: Array = []
	var seen := {}
	# grup: aynı konum/rota/sahip filolar tek düzen; bileşim birleştirilir
	var mix := {}
	var lead := {}
	for f in Navy.fleets:
		var gk: String = _positions[f.id][5]
		if not lead.has(gk):
			lead[gk] = f
			mix[gk] = {}
		var mx: Dictionary = mix[gk]
		for t: String in f.ships:
			mx[t] = int(mx.get(t, 0)) + int(f.ships[t])
	for f in Navy.fleets:
		var pp: Array = _positions[f.id]
		if lead[pp[5]] != f:
			continue
		var target: Vector2 = pp[0]
		if not view.has_point(target):
			continue
		seen[f.id] = true
		var heading: Vector2 = pp[1]
		var moving: bool = pp[2]
		var port := f.in_port()
		var g: Dictionary = _groups.get(f.id, {})
		var want_yaw := atan2(heading.x, heading.y)
		if g.is_empty() or (g["pos"] as Vector2).distance_to(target) > 150.0 * _zs:
			g = {"pos": target, "yaw": want_yaw, "rate": 0.0, "v": 0.0, "depth": 0.0, "last": target, "spread": 1.0}
			_groups[f.id] = g
		_move_group(g, target, want_yaw, moving or port, dt)
		var gpos: Vector2 = g["pos"]
		var gyaw: float = g["yaw"]
		var fwd := Vector2(sin(gyaw), cos(gyaw))
		var right := Vector2(fwd.y, -fwd.x)
		var col := _hull_color(f.owner)
		var st := 200.0 if f.in_combat else 0.0
		var sub := f.is_sub_fleet()
		var want_depth := -0.55 * _zs if (sub and f.submerged) else 0.05
		g["depth"] = lerpf(float(g["depth"]), want_depth, minf(dt * 0.8, 1.0))
		# gösterilecek gemiler: en ağır olan ortada
		var shown: Array[String] = []
		for t: String in MODELS:
			for i in mini(int(mix[pp[5]].get(t, 0)), MAX_SHOWN):
				if shown.size() < MAX_SHOWN:
					shown.append(t)
		var roll := clampf(-float(g["rate"]) * 0.25, -0.12, 0.12)
		# kıyı / ada yakınında düzen yumuşakça sıkışır (gemiler karaya taşmaz, zıplamaz)
		var want_spread := 0.0
		for sp: float in [1.0, 0.7, 0.45, 0.25]:
			var ok := true
			for i in shown.size():
				var q := _ship_pos(gpos, fwd, right, shown[i], i, port, sp)
				var hl := _half_len(shown[i]) * 0.9
				if not is_water(q) or not is_water(q + fwd * hl) or not is_water(q - fwd * hl):
					ok = false
					break
			if ok:
				want_spread = sp
				break
		g["spread"] = lerpf(float(g.get("spread", 1.0)), want_spread, minf(dt * 2.5, 1.0))
		var spread: float = g["spread"]
		for i in shown.size():
			var t: String = shown[i]
			var p := _ship_pos(gpos, fwd, right, t, i, port, spread)
			var sc := float(SHIP_SCALE[t]) * _zs
			var b := Basis(Vector3.UP, gyaw + PI)
			b = b * Basis(Vector3.FORWARD, roll + sin(_pulse * 0.8 + i * 1.7) * 0.015)
			b = b * Basis(Vector3.RIGHT, sin(_pulse * 0.6 + i) * 0.01)
			b = b.scaled(Vector3.ONE * sc)
			lists[t].append([Transform3D(b, Vector3(p.x, float(g["depth"]), p.y)), Color(col.r, col.g, col.b, st)])
			var v: float = g["v"]
			if moving and v > 0.4 * _zs and not (sub and f.submerged):
				var len := (7.5 if t == "battleship" else 5.5) * sc * clampf(v / (5.0 * _zs), 0.4, 1.1)
				var wb := Basis(Vector3.UP, gyaw) * Basis.from_scale(Vector3(sc * 2.6, 1.0, len))
				var back := p - fwd * len * 0.5
				wakes.append([Transform3D(wb, Vector3(back.x, 0.12, back.y)), clampf(v / (4.0 * _zs), 0.25, 0.9)])
	for id: int in _groups.keys():
		if not seen.has(id):
			_groups.erase(id)
	for name: String in lists:
		var mm: MultiMesh = _mmi[name].multimesh
		var arr: Array = lists[name]
		if mm.instance_count < arr.size():
			mm.instance_count = arr.size() + 8
			UnitModels.compat_colors(mm)
		mm.visible_instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i][0])
			mm.set_instance_custom_data(i, arr[i][1])
	var wm := _wake.multimesh
	if wm.instance_count < wakes.size():
		wm.instance_count = wakes.size() + 8
	wm.visible_instance_count = wakes.size()
	for i in wakes.size():
		wm.set_instance_transform(i, wakes[i][0])
		wm.set_instance_custom_data(i, Color(1, 1, 1, wakes[i][1]))

func _half_len(t: String) -> float:
	return float(MODEL_LEN[t]) * float(SHIP_SCALE[t]) * _zs * 0.5

## Düzendeki geminin konumu: denizde üçgen; limanda yan yana, kıçı rıhtımda (gövde tamamen suda)
func _ship_pos(gpos: Vector2, fwd: Vector2, right: Vector2, t: String, i: int, port: bool, spread: float) -> Vector2:
	if port:
		var s2: Vector2 = PORT_SLOTS[i]
		return gpos + right * s2.x * _zs * maxf(spread, 0.6) + fwd * (_half_len(t) + 0.8)
	var s1: Vector2 = SLOTS[i]
	return gpos + (right * s1.x + fwd * s1.y) * _zs * spread

## Filo tek parça hareket eder: konum hedefi hızıyla birlikte izler (gecikme yok), yön sınırlı hızla döner
func _move_group(g: Dictionary, target: Vector2, want_yaw: float, steer: bool, dt: float) -> void:
	var pos: Vector2 = g["pos"]
	var last: Vector2 = g["last"]
	var tv := (target - last) / maxf(dt, 0.001)
	if tv.length() > 4000.0:
		tv = Vector2.ZERO
	g["last"] = target
	var npos := (pos + tv * dt).lerp(target, 1.0 - exp(-dt * 6.0))
	g["v"] = lerpf(float(g["v"]), (npos - pos).length() / maxf(dt, 0.001), minf(dt * 3.0, 1.0))
	g["pos"] = npos
	var yaw: float = g["yaw"]
	if steer:
		# pruva rotanın teğetini izler (rota zaten yumuşak): yan kayma / ters bakma yok
		var turn := wrapf(want_yaw - yaw, -PI, PI) * (1.0 - exp(-dt * TURN_SMOOTH))
		g["yaw"] = yaw + turn
		g["rate"] = lerpf(float(g["rate"]), turn / maxf(dt, 0.001), minf(dt * 3.0, 1.0))
	else:
		g["rate"] = lerpf(float(g["rate"]), 0.0, minf(dt * 3.0, 1.0))

## Savaş gemisi grisi, ülke renginden hafif ton
func _hull_color(tag: String) -> Color:
	var c: Color = World.countries[tag].color
	return Color(0.46, 0.49, 0.52).lerp(c, 0.12)

# ------------------------------------------------------------------ deniz muharebesi efektleri
func _update_fx(close: bool) -> void:
	for pid: int in _fx.keys():
		if not close or not Navy.battles.has(pid):
			_fx[pid].queue_free()
			_fx.erase(pid)
	if not close:
		return
	var view := _view_rect()
	for pid: int in Navy.battles:
		if _fx.has(pid):
			continue
		var pos: Vector2 = Navy.battles[pid]["pos"]
		if not view.has_point(pos):
			continue
		var node := Node3D.new()
		node.position = Vector3(pos.x, 0.5, pos.y)
		node.scale = Vector3.ONE * minf(_zs, 3.0)
		add_child(node)
		node.add_child(models._particles_flash())
		node.add_child(_splashes())
		node.add_child(models._particles_smoke())
		_fx[pid] = node

## Mermi düşüşleri: beyaz su sütunları
func _splashes() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 1.6
	p.randomness = 1.0
	var pm := models._pmat(Vector3(26, 0.2, 18), 12.0, 6, -10.0, true)
	p.process_material = pm
	p.draw_pass_1 = models._quad(4.2, Color(0.94, 0.97, 1.0, 0.9), 0.0)
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 40, 80))
	return p

# ------------------------------------------------------------------ batan gemi
func _on_sunk(pos: Vector2, type: String, owner: String) -> void:
	if not visible or camera.distance > SHIP_DIST or not _view_rect().has_point(pos):
		return
	if not _meshes.has(type):
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = UnitModels.COMPAT
	mm.use_custom_data = true
	mm.mesh = _meshes[type]
	mm.instance_count = 1
	UnitModels.compat_colors(mm)
	var col := _hull_color(owner)
	mm.set_instance_custom_data(0, Color(col.r, col.g, col.b, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = (_mmi[type] as MultiMeshInstance3D).material_override
	var root := Node3D.new()
	var off := Vector2(randf_range(-15, 15), randf_range(-15, 15)) * _zs
	root.position = Vector3(pos.x + off.x, 0.0, pos.y + off.y)
	root.rotation.y = randf() * TAU
	add_child(root)
	root.add_child(mi)
	var sc := float(SHIP_SCALE.get(type, 1.0)) * _zs
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc), Vector3.ZERO))
	var fire := models._particles_explosion()
	fire.scale = Vector3.ONE * minf(_zs, 3.0) * 0.5
	root.add_child(fire)
	var smoke := models._particles_smoke()
	smoke.scale = Vector3.ONE * minf(_zs, 3.0) * 0.6
	root.add_child(smoke)
	# kıç üstü batış: burun kalkar, gemi yan yatarak suya gömülür
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "rotation:x", -0.5, 6.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "rotation:z", 0.35, 6.0)
	tw.tween_property(root, "position:y", -6.0 * sc, 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free).set_delay(2.5)
