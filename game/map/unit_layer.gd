class_name UnitLayer
extends Node3D
## Tümen sayaçları (bölge + ülke başına bir sayaç), seçim, hareket okları ve muharebe işaretleri.

const PIXEL := 0.00042
const FAR_ALL := 2400.0            ## bu mesafeden uzakta yalnız oyuncu ve düşmanları gösterilir
const WORLD_VIEW := 6500.0         ## bu mesafeden uzakta (dünya görünümü) sayaç gösterilmez
const LIFT := 5.0

var map: MapView3D
var camera: Camera3D
var models: UnitModels                 ## akıcı görsel konumlar (sayaçlar ve oklar)
var selected: Array[Division] = []

var _counters := {}                ## "pid:tag" -> {root, label, org, str, divs}
var _counter_tex := {}             ## tag -> Texture2D
var _battle_nodes := {}            ## pid -> Node3D
var _arrows: MeshInstance3D
var _arrow_mat: ShaderMaterial
var _white: Texture2D
var _dirty := true
var _timer := 0.0
var _was_far := -1
var _pulse := 0.0
var _sel_keys: Array[String] = []
var _vis_dirty := true
var _cluster_timer := 0.0

func _ready() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	_arrows = MeshInstance3D.new()
	_arrow_mat = ShaderMaterial.new()
	_arrow_mat.shader = preload("res://assets/shaders/arrow.gdshader")
	UnitModels.compat_material(_arrow_mat)
	_arrow_mat.render_priority = 8
	_arrows.material_override = _arrow_mat
	_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrows)
	Military.divisions_changed.connect(func() -> void: _dirty = true)
	Military.battles_changed.connect(_update_battles)
	World.player_changed.connect(func(_t: String) -> void: clear_selection())

func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer > 0.35:
		_timer = 0.0
		_dirty = false
		_rebuild()
		_vis_dirty = true
	_follow_anchors()
	_draw_arrows()
	_pulse += delta
	var k := 1.0 + 0.07 * sin(_pulse * 5.0)
	for d in selected.slice(0, 1):
		pass
	for key: String in _sel_keys:
		if _counters.has(key):
			_counters[key]["root"].scale = Vector3.ONE * k
	# 0 yakın: hepsi, 1 uzak: oyuncu + düşmanları, 2 dünya görünümü: hiçbiri (yığılma olmasın)
	var far := 0
	if camera:
		far = 2 if camera.distance > WORLD_VIEW else (1 if camera.distance > FAR_ALL else 0)
	if far != _was_far or _vis_dirty:
		_was_far = far
		_vis_dirty = false
		var shown := {World.player_tag: true}
		for t in Diplomacy.enemies_of(World.player_tag):
			shown[t] = true
		for key: String in _counters:
			var c: Dictionary = _counters[key]
			c["base_vis"] = far == 0 or (far == 1 and shown.has(c["tag"]))
			c["root"].visible = c["base_vis"] and not c.get("merged", false)
	_cluster_timer -= delta
	if _cluster_timer <= 0.0:
		_cluster_timer = 0.25
		_cluster()

## Sayaçlar tümenlerin akıcı görsel konumunu izler (bölgede zıplamaz)
func _follow_anchors() -> void:
	if models == null:
		return
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var divs: Array = c["divs"]
		var sum := Vector2.ZERO
		var n := 0
		for d: Division in divs:
			var a: Array = models.anchors.get(d.id, [])
			if not a.is_empty():
				sum += a[0]
				n += 1
		if n == 0:
			continue
		var p := sum / n + Vector2(c.get("off", 0.0), 0.0)
		var root: Node3D = c["root"]
		# figürlerin üstünde dursun (yakın zoom'da figür boyu kadar yukarı)
		var cam_d: float = (camera as MapCamera3D).distance if camera is MapCamera3D else 300.0
		var h := maxf(map.height_at(p), 0.0) + LIFT + clampf(cam_d * 0.09, 0.0, 14.0)
		root.position = Vector3(p.x, h, p.y)   # doğrudan: sayaç kaymaz

# ------------------------------------------------------------------ sayaçlar
func _tex_for(tag: String, ob: int = 10, sb: int = 10, selected := false) -> Texture2D:
	var ck := "%s:%d:%d:%s" % [tag, ob, sb, selected]
	if _counter_tex.has(ck):
		return _counter_tex[ck]
	var c: Country = World.countries[tag]
	var w := 132
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.06, 0.06, 0.05, 0.95)
	var bh := 52
	img.fill_rect(Rect2i(0, 0, w, h), dark)
	img.fill_rect(Rect2i(3, 3, w - 6, bh - 6), c.color.darkened(0.15))
	img.fill_rect(Rect2i(3, 3, 44, bh - 6), Color(0.12, 0.12, 0.11))
	# organizasyon (yeşil) ve güç (sarı) çubukları
	img.fill_rect(Rect2i(3, bh, int((w - 6) * ob / 10.0), 5), Color(0.45, 0.85, 0.35))
	img.fill_rect(Rect2i(3, bh + 6, int((w - 6) * sb / 10.0), 4), Color(0.95, 0.78, 0.3))
	# NATO piyade sembolü (çapraz)
	for i in 38:
		var x := 6 + i
		var y1 := 8 + int(i * (bh - 16) / 38.0)
		var y2 := bh - 8 - int(i * (bh - 16) / 38.0)
		for t in 3:
			img.set_pixel(x, clampi(y1 + t - 1, 0, h - 1), Color(0.9, 0.85, 0.7))
			img.set_pixel(x, clampi(y2 + t - 1, 0, h - 1), Color(0.9, 0.85, 0.7))
	# çerçeve: normalde ince pirinç, seçiliyse kalın parlak altın
	var brass := Color(1.0, 0.84, 0.36) if selected else Color(0.72, 0.6, 0.34)
	var bw := 4 if selected else 1
	for k in bw:
		for x in w:
			img.set_pixel(x, k, brass); img.set_pixel(x, 51 - k, brass)
		for y in 52:
			img.set_pixel(k, y, brass); img.set_pixel(w - 1 - k, y, brass)
	var tex := ImageTexture.create_from_image(img)
	_counter_tex[ck] = tex
	return tex

func _group_pos(pid: int, tag: String, index: int, count: int) -> Vector3:
	var p := World.province(pid).center
	var off := Vector2((index - (count - 1) * 0.5) * 14.0, 0.0)
	var h := maxf(map.height_at(p), 0.0) + LIFT
	return Vector3(p.x + off.x, h, p.y + off.y)

func _rebuild() -> void:
	var groups := {}
	for d in Military.divisions:
		var key := "%d:%s" % [d.province, d.owner]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(d)
	_sel_keys.clear()
	for key: String in _counters.keys():
		if not groups.has(key):
			_counters[key]["root"].queue_free()
			_counters.erase(key)
	# bir bölgedeki farklı ülkeler yan yana
	var per_pid := {}
	for key: String in groups:
		var pid := int(key.get_slice(":", 0))
		if not per_pid.has(pid):
			per_pid[pid] = []
		per_pid[pid].append(key)
	for pid: int in per_pid:
		var keys: Array = per_pid[pid]
		keys.sort()
		for i in keys.size():
			var key: String = keys[i]
			var divs: Array = groups[key]
			var tag: String = key.get_slice(":", 1)
			if not _counters.has(key):
				_counters[key] = _make_counter(tag)
			var c: Dictionary = _counters[key]
			c["divs"] = divs
			c["off"] = (i - (keys.size() - 1) * 0.5) * 14.0
			if models == null or c["root"].position == Vector3.ZERO:
				c["root"].position = _group_pos(pid, tag, i, keys.size())
			var org := 0.0
			var strn := 0.0
			var sel := false
			for d: Division in divs:
				org += d.org / maxf(Military.div_stats(d)["org"], 1.0)
				strn += d.strength
				if d in selected:
					sel = true
			c["label"].text = str(divs.size())
			c["bg"].texture = _tex_for(tag, clampi(roundi(org / divs.size() * 10.0), 0, 10), clampi(roundi(strn / divs.size() * 10.0), 0, 10), sel)
			c["selected"] = sel
			if sel:
				_sel_keys.append(key)
			else:
				c["root"].scale = Vector3.ONE

func _sprite(tex: Texture2D, px: float, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.pixel_size = px
	s.no_depth_test = true
	s.render_priority = prio
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s

func _make_counter(tag: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var bg := _sprite(_tex_for(tag), PIXEL * 0.6, 10)
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
	return {"root": root, "label": lbl, "bg": bg, "tag": tag, "divs": [], "selected": false}

# ------------------------------------------------------------------ muharebe işaretleri
func _update_battles() -> void:
	var tex := UiTheme.icon("battle")
	for pid: int in _battle_nodes.keys():
		if not Military.battles.has(pid):
			_battle_nodes[pid].queue_free()
			_battle_nodes.erase(pid)
	for pid: int in Military.battles:
		var b: Dictionary = Military.battles[pid]
		if not _battle_nodes.has(pid):
			var root := Node3D.new()
			add_child(root)
			var s := _sprite(tex, PIXEL * 0.35, 13)
			root.add_child(s)
			var l := Label3D.new()
			l.font = UiTheme.bold_font()
			l.font_size = 26
			l.outline_size = 8
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.fixed_size = true
			l.pixel_size = PIXEL * 0.6
			l.no_depth_test = true
			l.render_priority = 14
			l.outline_render_priority = 13
			l.offset = Vector2(0, -34)
			root.add_child(l)
			_battle_nodes[pid] = root
		var node: Node3D = _battle_nodes[pid]
		var a := World.province(int(b["from"])).center
		var t := World.province(pid).center
		var m := a.lerp(t, 0.6)
		node.position = Vector3(m.x, maxf(map.height_at(m), 0.0) + LIFT + 2.0, m.y)
		var lbl: Label3D = node.get_child(1)
		var att := float(b["att_ratio"])
		var dfn := float(b["def_ratio"])
		lbl.text = "%d%%" % roundi(att / maxf(att + dfn, 0.01) * 100.0)
		var player_att := false
		for d: Division in b["attackers"]:
			if d.owner == World.player_tag or Diplomacy.are_allies(d.owner, World.player_tag):
				player_att = true
		var winning := att > dfn
		lbl.modulate = Color(0.55, 0.95, 0.45) if winning == player_att else Color(1.0, 0.45, 0.35)

# ------------------------------------------------------------------ seçim
func clear_selection() -> void:
	selected.clear()
	_dirty = true

## Ekrandaki noktaya en yakın oyuncu sayacı (30 px içinde)
## Uzak zoom: aynı ülkenin yakın sayaçları tek sayaçta birleşir. Harita üstünde sabit ızgara (kaydırınca değişmez),
## yalnız 3 zoom eşiğinde değişir; birleşik sayaç en büyük yığının kendi yerinde durur (kayma / ortalama yok)
const CLUSTER_TIERS := [[800.0, 75.0], [1500.0, 140.0], [2600.0, 240.0]]

func _cluster() -> void:
	var cam := camera as MapCamera3D
	var tier := -1
	if cam:
		for i in CLUSTER_TIERS.size():
			if cam.distance > float(CLUSTER_TIERS[i][0]):
				tier = i
	# gruplar: ızgara hücresi + ülke; lider = en çok tümenli yığın
	var cells := {}
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["members"] = [key]
		if tier < 0:
			continue
		var s: float = CLUSTER_TIERS[tier][1]
		var p: Vector3 = (c["root"] as Node3D).position
		var ck := "%s:%d:%d" % [c["tag"], floori(p.x / s), floori(p.z / s)]
		if not cells.has(ck):
			cells[ck] = []
		cells[ck].append(key)
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["merged"] = false
		c["label"].text = str((c["divs"] as Array).size())
	for ck: String in cells:
		var keys: Array = cells[ck]
		if keys.size() < 2:
			continue
		keys.sort_custom(func(x: String, y: String) -> bool:
			var nx := (_counters[x]["divs"] as Array).size()
			var ny := (_counters[y]["divs"] as Array).size()
			return nx > ny or (nx == ny and x < y))
		var lead: Dictionary = _counters[keys[0]]
		lead["members"] = keys
		var total := 0
		for k: String in keys:
			total += (_counters[k]["divs"] as Array).size()
			if k != keys[0]:
				_counters[k]["merged"] = true
		lead["label"].text = str(total)
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["root"].visible = c.get("base_vis", true) and not c["merged"]

## Sayacın temsil ettiği bütün tümenler (birleşik sayaçta grubun tamamı)
func _counter_divs(c: Dictionary) -> Array:
	var mem: Array = c.get("members", [])
	if mem.size() < 2:
		return c["divs"]
	var out: Array = []
	for mk: String in mem:
		out.append_array(_counters[mk]["divs"])
	return out

func pick(screen: Vector2) -> Array:
	var best: Array = []
	var best_d := 30.0
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if not c["root"].visible or camera.is_position_behind(c["root"].global_position):
			continue
		var sp := camera.unproject_position(c["root"].global_position)
		var dd := sp.distance_to(screen)
		if dd < best_d:
			best_d = dd
			best = _counter_divs(c)
	return best

func select_in_rect(rect: Rect2, additive: bool) -> void:
	if not additive:
		selected.clear()
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if c["tag"] != World.player_tag or camera.is_position_behind(c["root"].global_position):
			continue
		if c.get("merged", false):
			continue
		if rect.has_point(camera.unproject_position(c["root"].global_position)):
			for d: Division in _counter_divs(c):
				if not d in selected:
					selected.append(d)
	_dirty = true

func select_divisions(divs: Array, additive: bool) -> void:
	if not additive:
		selected.clear()
	var before := selected.size()
	for d: Division in divs:
		if d.owner == World.player_tag and not d in selected:
			selected.append(d)
	if selected.size() > before:
		Audio.play("select_unit", 120)
	_dirty = true

func prune_selection() -> void:
	selected = selected.filter(func(d: Division) -> bool: return d in Military.divisions)

# ------------------------------------------------------------------ oklar
## Seçili tümenlerin okları (her karede): tümenin bulunduğu yerden başlar, eğri boyunca sivrilir
func _draw_arrows() -> void:
	if selected.is_empty():
		if _arrows.mesh != null:
			_arrows.mesh = null
		return
	prune_selection()
	var im := ImmediateMesh.new()
	var any := false
	var drawn := {}
	var cam_d: float = (camera as MapCamera3D).distance if camera is MapCamera3D else 300.0
	var width := clampf(cam_d * 0.017, 1.8, 50.0)
	var arrows: Array = []
	for d in selected:
		if d.path.is_empty():
			continue
		var key := "%d>%d" % [d.province, d.path[d.path.size() - 1]]
		if drawn.has(key):
			continue
		drawn[key] = true
		var start: Vector2 = World.province(d.province).center
		if models and models.anchors.has(d.id):
			start = models.anchors[d.id][0]
		var pts: Array[Vector2] = [start]
		for pid in d.path:
			pts.append(World.province(pid).center)
		var hostile := false
		for pid in d.path:
			if Diplomacy.are_enemies(World.controller_tag(pid), d.owner):
				hostile = true
		# ülke renginde, haritaya boyanmış gibi yarı saydam
		var cc: Color = World.countries[d.owner].color
		arrows.append([_curve(pts), Color(cc.r, cc.g, cc.b, 1.0), d.path[d.path.size() - 1]])
	if arrows.is_empty():
		_arrows.mesh = null
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# önce gölgeler, sonra oklar
	# aynı hedefe giden oklar: gövdeler birleşir, uçta tek ok başı (en uzun rotanınki)
	var head_of := {}
	for a: Array in arrows:
		var dest: int = a[2]
		var len := _length(a[0])
		if not head_of.has(dest) or len > float(head_of[dest][1]):
			head_of[dest] = [a, len]
	for a: Array in arrows:
		_ribbon(im, a[0], a[1], width, head_of[a[2]][0] == a)
	im.surface_end()
	_arrows.mesh = im

## Catmull-Rom ile yumuşatılmış rota (kesim başına 8 örnek)
func _curve(pts: Array[Vector2]) -> Array[Vector2]:
	if pts.size() < 2:
		return pts
	var out: Array[Vector2] = []
	for i in pts.size() - 1:
		var p0 := pts[i - 1] if i > 0 else pts[i] - (pts[i + 1] - pts[i])
		var p3 := pts[i + 2] if i + 2 < pts.size() else pts[i + 1] + (pts[i + 1] - pts[i])
		for k in 8:
			out.append(PathMotion.catmull(p0, pts[i], pts[i + 1], p3, k / 8.0))
	out.append(pts[pts.size() - 1])
	return out

## Kesintisiz şerit (köşelerde ortak kenar), kuyrukta incelen gövde ve çentikli geniş ok başı
func _length(pts: Array[Vector2]) -> float:
	var l := 0.0
	for i in pts.size() - 1:
		l += pts[i].distance_to(pts[i + 1])
	return l

func _ribbon(im: ImmediateMesh, pts: Array[Vector2], col: Color, width: float, head := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var cum: Array[float] = [0.0]
	for i in n - 1:
		cum.append(cum[i] + pts[i].distance_to(pts[i + 1]))
	var total: float = cum[n - 1]
	if total < 0.5:
		return
	var head_len := minf(width * 3.4, total * 0.45)
	var body_end := total - head_len if head else total - head_len * 0.5
	var lift := 0.6
	# gövde: her örnekte ortalama normal (birleşimler kopmaz)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_u := 0.0
	var have := false
	var neck := pts[n - 1]
	var neck_dir := (pts[n - 1] - pts[n - 2]).normalized()
	for i in n:
		var along: float = cum[i]
		var p := pts[i]
		var clip := false
		if along > body_end:
			# gövdeyi tam ok başı tabanında kes
			var j := maxi(i - 1, 0)
			var seg: float = cum[i] - cum[j]
			var t := (body_end - cum[j]) / maxf(seg, 0.001)
			p = pts[j].lerp(pts[i], clampf(t, 0.0, 1.0))
			along = body_end
			clip = true
		var d0 := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d0.y, d0.x)
		var taper := lerpf(0.35, 1.0, smoothstep(0.0, total * 0.18, along))
		var w := width * 0.5 * taper
		var y := maxf(map.height_at(p), 0.0) + lift
		var l := Vector3(p.x + nrm.x * w, y, p.y + nrm.y * w)
		var r := Vector3(p.x - nrm.x * w, y, p.y - nrm.y * w)
		var u := along / total
		if have:
			_quad(im, prev_l, prev_r, r, l, prev_u, u, col)
		prev_l = l
		prev_r = r
		prev_u = u
		have = true
		if clip:
			neck = p
			neck_dir = d0
			break
	if not head:
		return
	# ok başı: çentikli (kırlangıç kuyruğu) geniş üçgen
	var tip := pts[n - 1]
	var hd := (tip - neck).normalized() if tip.distance_to(neck) > 0.01 else neck_dir
	var hn := Vector2(-hd.y, hd.x)
	var hw := width * 1.25
	var y0 := maxf(map.height_at(neck), 0.0) + lift
	var y1 := maxf(map.height_at(tip), 0.0) + lift
	var notch := neck + hd * head_len * 0.18
	var wl := neck + hn * hw
	var wr := neck - hn * hw
	var V := func(p: Vector2, yy: float) -> Vector3: return Vector3(p.x, yy, p.y)
	# iki yarım: (kanat, uç, çentik) — UV.y kenar degradesi için 0/0.5/1
	for tri: Array in [[V.call(wl, y0), 0.0, V.call(tip, y1), 0.5, V.call(notch, y0), 0.5],
			[V.call(notch, y0), 0.5, V.call(tip, y1), 0.5, V.call(wr, y0), 1.0]]:
		for k in 3:
			im.surface_set_color(col)
			im.surface_set_uv(Vector2(1.0, tri[k * 2 + 1]))
			im.surface_add_vertex(tri[k * 2])

func _quad(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float, col: Color) -> void:
	# a=önceki sol, b=önceki sağ, c=şimdiki sağ, d=şimdiki sol
	var q := [[a, Vector2(u0, 0.0)], [b, Vector2(u0, 1.0)], [c, Vector2(u1, 1.0)], [d, Vector2(u1, 0.0)]]
	for k in [0, 1, 2, 0, 2, 3]:
		im.surface_set_color(col)
		im.surface_set_uv(q[k][1])
		im.surface_add_vertex(q[k][0])
