extends "res://tests/test_case.gd"
## Figürlerin gruplanması: yazan sayı her yerde aynı (figürün kaidesi ve başı, uzak rozet); uzak kümenin ya da kapalı
## destenin lideri üyelerinin toplamını yazar. Muharebede komşu bölgelerin figürleri sınırda aynı yere durmaz. Bölgesinden
## ayrılan asker orada kalan grubundan bir kaide boyu uzaklaşana dek grubun sayısında kalır, sonra ayrı figür olur.
const Probe := preload("res://tests/map_probe.gd")

class ProbeMap extends MapView3D:
	func province_at(world_xz: Vector2) -> int:
		return Probe.province_at(world_xz)
	func height_at(_p: Vector2) -> float:
		return 0.0

func player_tag() -> String:
	return "GER"

func _layer() -> UnitLayer:
	var ul := UnitLayer.new()
	ul.map = ProbeMap.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(ul)
	return ul

func _dispose(ul: UnitLayer) -> void:
	var pm := ul.map
	ul.free()
	pm.free()

func _labels(c: Dictionary) -> Array:
	var out := [(c["clabel"] as Label3D).text]
	var fig: Node3D = c.get("fig")
	if fig:
		for path: String in ["h/n", "top_n"]:
			var l: Label3D = fig.get_node_or_null(path)
			if l:
				out.append(l.text)
	return out

func _counter(ul: UnitLayer, key: String, n: int) -> Dictionary:
	var c := ul._make_counter("GER")
	var divs: Array = []
	for i in n:
		divs.append(Military.country_divisions("GER")[i])
	c["divs"] = divs
	c["members"] = [key]
	ul._counters[key] = c
	return c

func test_every_label_shows_the_same_count_and_leads_sum_their_members() -> void:
	var ul := _layer()
	var a := _counter(ul, "100:GER:0:", 2)
	var b := _counter(ul, "101:GER:0:", 3)
	ul._apply_counts()
	for t: String in _labels(a):
		eq(t, "2", "figure base, figure top and map chip agree")
	b["extra"] = 1                                     # yürüyen bir asker bu figüre katıldı
	a["gone"] = 1                                      # biri başka bölgedeki figüre geçti
	ul._refresh_counts()
	for t: String in _labels(b):
		eq(t, "4", "a soldier who joined is counted on every label at once")
	for t: String in _labels(a):
		eq(t, "1", "one who left is no longer counted here")
	a["members"] = ["100:GER:0:", "101:GER:0:"]       # uzakta küme (ya da yakında kapalı deste): a lider
	b["merged"] = true
	ul._apply_counts()
	for t: String in _labels(a):
		eq(t, "5", "the lead shows the divisions of the whole group, joined ones included")
	_dispose(ul)

func test_neighbouring_battle_posts_do_not_overlap() -> void:
	var ul := _layer()
	Probe.ensure()
	# Almanya'nın Polonya'ya komşu iki bölgesi, aynı Polonya bölgesine bakıyor
	var foe := 0
	var own: Array[int] = []
	for p: Province in World.provinces:
		if p == null or not p.is_land() or World.controller_tag(p.id) != "POL":
			continue
		var mine: Array[int] = []
		for q in World.land_neighbors(p.id):
			if World.controller_tag(q) == "GER":
				mine.append(q)
		if mine.size() >= 2:
			foe = p.id
			own = mine
			break
	if not check(foe != 0, "fixture: a Polish province with two German neighbours"):
		_dispose(ul)
		return
	var dmin := 2.0 * UnitLayer.FIG_SIZE * UnitFigures.BASE_R * UnitLayer.FIG_GAP
	var kz := dmin / (UnitLayer.FIG_SIZE * UnitLayer.FIG_DEPTH)
	var posts: Array[Vector2] = []
	for i in 2:
		var key := "%d:GER:0:" % own[i]
		var c := _counter(ul, key, 1)
		(c["root"] as Node3D).visible = true
		var post := ul._free_post(key, own[i], foe)
		c["post_goal"] = post
		posts.append(post)
		eq(ul.map.province_at(post), own[i], "the post stays inside its own province")
	var dv := posts[1] - posts[0]
	ge(Vector2(dv.x, dv.y * kz).length(), dmin, "the second post moves along the border instead of overlapping")
	_dispose(ul)

func _walker(ul: UnitLayer, key: String, n: int, path: Array, at: Vector2) -> Dictionary:
	var c := _counter(ul, key, 0)
	var divs: Array = []
	for i in n:
		var d := Division.new()
		d.id = 900000 + ul._counters.size() * 10 + i
		d.owner = "GER"
		d.province = int(key.get_slice(":", 0))
		d.path = path.duplicate()
		divs.append(d)
	c["divs"] = divs
	c["walking"] = true
	c["pos0"] = at
	(c["root"] as Node3D).position = Vector3(at.x, 0.0, at.y)
	return c

func test_same_tile_merges_and_passing_soldiers_walk_on() -> void:
	var ul := _layer()
	UnitLayer.FIGURES = true
	ul._was_far = 0
	var home := World.capital_province("GER")
	var n1: int = World.land_neighbors(home)[0]
	var n2 := 0
	for q in World.land_neighbors(n1):
		if q != home and World.controller_tag(q) == "GER":
			n2 = q
			break
	if not check(n2 != 0, "fixture: a German province two steps away"):
		_dispose(ul)
		return
	var c_home := World.province(home).center
	var c1 := World.province(n1).center
	var c2 := World.province(n2).center
	var stay_home := _counter(ul, "%d:GER:0:" % home, 2)
	var stay1 := _counter(ul, "%d:GER:0:" % n1, 1)
	ul._tile_key = {"%d:GER" % home: "%d:GER:0:" % home, "%d:GER" % n1: "%d:GER:0:" % n1}
	ul._merge_stay = {"%d:GER:0:" % home: 2, "%d:GER:0:" % n1: 1}
	var leaving := _walker(ul, "%d:GER:0:>%d" % [home, n1], 1, [n1], c_home)
	var arriving := _walker(ul, "%d:GER:0:>%d" % [home, n1], 1, [n1], c1)
	arriving["divs"][0].province = home
	var passing := _walker(ul, "%d:GER:0:>%d|p" % [home, n1], 1, [n1, n2], c1)
	var first := _walker(ul, "%d:GER:0:>%d|a" % [n1, n2], 2, [n2], c2)
	var second := _walker(ul, "%d:GER:0:>%d|b" % [n1, n2], 1, [n2], c2 + Vector2(1.0, 0.0))
	ul._merge_walkers()
	check((leaving["root"] as Node3D).visible, "a soldier leaving splits off right where its group stands")
	check(not (arriving["root"] as Node3D).visible, "a soldier entering its destination joins the figure there at once")
	check((passing["root"] as Node3D).visible, "a soldier whose road only passes through the province walks on")
	eq(int(stay1.get("extra", 0)), 1, "only the arriving soldier is added to the figure there")
	eq(int(stay_home.get("extra", 0)), 0, "the group it left does not count it")
	check((first["root"] as Node3D).visible and not (second["root"] as Node3D).visible,
		"soldiers entering the same empty province become one figure (the larger one carries it)")
	eq(int(first.get("extra", 0)), 1, "and it shows both")
	_dispose(ul)

func test_figure_carries_the_map_chip_over_its_head() -> void:
	var ul := _layer()
	UnitLayer.FIGURES = true
	var cam := MapCamera3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(cam)
	cam.map_size = Vector2(Probe.image.get_width(), Probe.image.get_height()) if Probe.image else Vector2(16384, 8106)
	cam.edge_pan_enabled = false
	var at := World.province(World.capital_province("GER")).center
	cam.focus_on(at, 120.0)
	cam.distance = 120.0
	ul.camera = cam
	var c := _counter(ul, "%d:GER:0:" % World.capital_province("GER"), 2)
	ul._vis_dirty = true
	ul._process(0.0)
	var fig: Node3D = c["fig"]
	check(fig.visible, "near: the soldier figure is shown")
	check((c["flag"] as Node3D).visible and (c["clabel"] as Node3D).visible, "near: the flag | number chip is shown with it")
	gt((c["flag"] as Node3D).position.y, float(fig.get_meta("head")) * UnitLayer.FIG_SIZE, "the chip floats over the head")
	eq((c["clabel"] as Node3D).position.y, (c["flag"] as Node3D).position.y, "number and flag stay together")
	check(fig.get_node_or_null("top_n") == null, "no second, plain number over the head")
	cam.distance = 600.0
	ul._process(0.0)
	eq((c["flag"] as Node3D).position.y, 0.0, "zoomed out the same chip sits on the map")
	ul.remove_child(c["root"])
	(c["root"] as Node3D).free()
	ul._counters.clear()
	cam.free()
	_dispose(ul)
