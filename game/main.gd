extends Node
## Oyun sahnesi: 3D harita + kamera + ışık/ortam + arayüz, girdi yönlendirmesi.

const DRAG_THRESHOLD := 6.0

enum Phase { MENU, SETUP, PLAYING }
var phase := Phase.MENU
var weather: WeatherLayer
var _menu_layer: CanvasLayer
var _menu: MainMenu
var _select: CountrySelect
var _drift_t := 0.0
var _env: Environment
var _sun: DirectionalLight3D

var map_view: MapView3D
var camera: MapCamera3D
var _ctrl_country := ""            ## Ctrl ile üzerine gelinen ülke (vurgulu)
var cities: CityLayer3D
var units: UnitLayer
var fleets: FleetLayer
var routes: RouteLayer
var roads: RoadLayer
var pins: PinLayer
var _zone_pick: Fleet = null          ## "Bölge seç": sonraki tıklama filo görev bölgesi
var _wing_pick: AirWing = null        ## hava kanadı için bölge / üs seçimi
var _recon_pick := false               ## keşif: sonraki sol tık hedef bölge (K ya da soldaki dürbün)
## Konuşlandırma: {kind: "division" | "wing" | "ships", data, marks: eyalet -> uygun mu}; panel kapanır, uygun
## eyaletler vurgulanır (öbürleri kararır), sol tık oraya konuşlandırır, sağ tık / Esc vazgeçer
var _place := {}
var hud: Hud

var _left_down := false
var _dragging := false
var _middle_down := false
var _press_pos := Vector2.ZERO
var _last_mouse := Vector2.ZERO

func _ready() -> void:
	UiTheme.install_cursors()
	_setup_environment()
	map_view = MapView3D.new()
	add_child(map_view)
	add_child(map_view.labels)
	camera = MapCamera3D.new()
	camera.map = map_view
	camera.map_size = Vector2(World.map_width, World.map_height)
	add_child(camera)
	camera.make_current()
	camera.focus_on(World.capital_position(World.player_tag), 900.0)
	cities = CityLayer3D.new()
	cities.map = map_view
	add_child(cities)
	var models := UnitModels.new()
	models.map = map_view
	models.camera = camera
	models.cities = cities
	add_child(models)
	units = UnitLayer.new()
	units.map = map_view
	units.camera = camera
	units.models = models
	add_child(units)
	fleets = FleetLayer.new()
	fleets.map = map_view
	fleets.camera = camera
	fleets.models = models
	add_child(fleets)
	var battle_audio := BattleAudio.new()
	battle_audio.map = map_view
	add_child(battle_audio)
	weather = WeatherLayer.new()
	weather.map = map_view
	weather.camera = camera
	add_child(weather)
	var fronts := FrontLayer.new()
	fronts.map = map_view
	fronts.camera = camera
	add_child(fronts)
	var battle_icons := BattleIcons.new()
	battle_icons.map = map_view
	battle_icons.camera = camera
	add_child(battle_icons)
	var ticker := BattleTicker.new()          # muharebede durumu düzelen tarafta yeşil ▲, kötüleşende kırmızı ▼
	ticker.map = map_view
	ticker.camera = camera
	ticker.units = units
	add_child(ticker)
	World.daily_update.connect(map_view.update_season)
	map_view.update_season()
	roads = RoadLayer.new()                   # kara yolları ve demiryolları (Yollar kipinde, yakın zoom)
	roads.map = map_view
	roads.camera = camera
	add_child(roads)
	routes = RouteLayer.new()
	routes.map = map_view
	routes.camera = camera
	routes.fleets = fleets
	add_child(routes)
	var air_layer := AirLayer.new()
	air_layer.map = map_view
	air_layer.camera = camera
	air_layer.models = models
	add_child(air_layer)
	units.obstacles = [fleets, air_layer]     # filo ve kanat levhaları: tümen levhaları bunlara binmez (üstlerine çıkar)
	pins = PinLayer.new()
	pins.map = map_view
	pins.camera = camera
	pins.cities = cities
	pins.units = units
	pins.fleets = fleets
	pins.air = air_layer
	add_child(pins)
	hud = Hud.new()
	add_child(hud)
	hud.divisions.units = units
	hud.army.units = units
	hud.navy.fleet_selected.connect(func(f: Fleet) -> void:
		units.clear_selection()
		fleets.select(f)
		camera.focus_on(fleets.fleet_position(f), minf(camera.distance, 900.0)))
	hud.air.pick_zone_requested.connect(func(w: AirWing) -> void:
		_wing_pick = w
		World.notify(tr("AIR_CLICK_ZONE"), "info"))
	hud.army.deploy_requested.connect(func(ti: int) -> void: _begin_place("division", ti))
	hud.air.deploy_requested.connect(func(t: String) -> void: _begin_place("wing", t))
	hud.recon_requested.connect(_begin_recon)
	hud.top_bar.globe.setup(map_view.terrain_texture, map_view.map_size.y)
	hud.navy.deploy_requested.connect(func() -> void: _begin_place("ships", null))
	hud.navy.pick_zone_requested.connect(func(f: Fleet) -> void:
		_zone_pick = f
		World.notify(tr("NAVY_CLICK_ZONE"), "info"))
	hud.pause_menu.to_main_menu.connect(_back_to_menu)
	hud.pause_menu.load_requested.connect(_load_slot)
	hud.game_over.to_main_menu.connect(_back_to_menu)
	hud.game_over.continue_pressed.connect(func() -> void: pass)
	hud.world.goto.connect(func(p: Vector2) -> void: camera.focus_on(p))      # dünya olayı: harita oraya
	hud.map_modes.mode_selected.connect(func(m: int) -> void: _apply_mode(m))
	hud.construction.building_selected.connect(func(_b: String) -> void: _update_construction_marks())
	hud.construction_toggled.connect(func(_o: bool) -> void: _update_construction_marks())
	Economy.construction_changed.connect(func(_t: String) -> void: _update_construction_marks())
	Military.divisions_changed.connect(_update_fog)
	World.game_started.connect(_update_fog)
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 20
	add_child(_menu_layer)
	_handle_dev_args()
	if Game.loaded:
		Game.loaded = false
		var fresh := Game.fresh_start
		Game.fresh_start = false
		_enter_playing(World.player_tag, not fresh)      # senaryo başlangıcı: oyuncunun tarafına yeni oyun varsayılanları
		if fresh and not Game.scenario.is_empty():
			_focus_front()
			World.notify(tr("NOTE_SCENARIO_START") % Politics.loc(Game.scenario["name"]), "good")
		if Game.resume_view.z > 0.0:
			camera.focus_on(Vector2(Game.resume_view.x, Game.resume_view.y), Game.resume_view.z)
			Game.resume_view = Vector3.ZERO
		if Game.observer:
			GameClock.set_speed(2)             # izleyici modu: savaş kendiliğinden akar
			GameClock.set_paused(false)
			World.notify(tr("NOTE_OBSERVER"), "info")
		if Game.reopen_settings:
			Game.reopen_settings = false
			hud.pause_menu.toggle()
			hud.pause_menu._was_paused = Game.resume_was_paused
			hud.pause_menu._settings()
	elif phase == Phase.MENU:
		_enter_menu()
		if Game.reopen_settings:
			Game.reopen_settings = false
			_menu.open_settings()

# ------------------------------------------------------------------ aşamalar
func _clear_menu_layer() -> void:
	for ch in _menu_layer.get_children():
		ch.queue_free()
	_menu = null
	_select = null

func _enter_menu() -> void:
	phase = Phase.MENU
	_clear_menu_layer()
	hud.set_game_ui_visible(false)
	map_view.set_highlight_country("")
	GameClock.set_paused(true)
	_menu = MainMenu.new()
	_menu.theme = UiTheme.get_theme()
	_menu.new_game_pressed.connect(_enter_setup)
	_menu.quit_pressed.connect(func() -> void: get_tree().quit())
	_menu.load_pressed.connect(_load_slot)
	_menu.dev_war_pressed.connect(_dev_war_demo)
	_menu.scenarios_pressed.connect(_enter_scenarios)
	_menu_layer.add_child(_menu)

## Senaryo seçimi (ana menü → Senaryolar)
func _enter_scenarios() -> void:
	phase = Phase.SETUP
	_clear_menu_layer()
	hud.set_game_ui_visible(false)
	var sel := ScenarioSelect.new()
	sel.theme = UiTheme.get_theme()
	sel.start_pressed.connect(_start_scenario)
	sel.back_pressed.connect(_enter_menu)
	_menu_layer.add_child(sel)

## Senaryoyu başlat: başlangıç kaydı yüklenir, sahne yeniden kurulur, oyuncu seçtiği taraf olur
func _start_scenario(id: String, tag: String) -> void:
	if Game.start_scenario(id, tag):
		get_tree().reload_current_scene()

func _enter_setup() -> void:
	phase = Phase.SETUP
	_clear_menu_layer()
	hud.set_game_ui_visible(false)
	_select = CountrySelect.new()
	_select.theme = UiTheme.get_theme()
	_select.selection_changed.connect(func(tag: String) -> void:
		map_view.set_highlight_country(tag)
		camera.focus_on(World.capital_position(tag), 1500.0))
	_select.start_pressed.connect(_start_game)
	_select.back_pressed.connect(_enter_menu)
	_menu_layer.add_child(_select)

func _start_game(tag: String) -> void:
	if tag == "":
		return
	_enter_playing(tag)
	World.notify(tr("NOTE_WELCOME") % World.player().display_name(), "good")

## resumed: kayıttan devam — oyuncunun kayıttaki tercihleri korunur (yeni oyun varsayılanları kurulmaz)
func _enter_playing(tag: String, resumed := false) -> void:
	_fog_start.call_deferred()
	_clear_menu_layer()
	map_view.set_highlight_country("")
	if resumed:
		World.resume_game(tag)
	else:
		World.start_game(tag)
	phase = Phase.PLAYING
	hud.set_game_ui_visible(true)
	camera.focus_on(World.capital_position(tag), 700.0)

func _back_to_menu() -> void:
	Game.new_game()
	get_tree().reload_current_scene()

func _load_slot(slot: String) -> void:
	if Game.load_game(slot):
		get_tree().reload_current_scene()

## Geliştirici: savaş izle. Savaş demosunun izleme kaydı (game/dev/war_demo.gd yazar; yoksa oynanan demo kaydı) izleyici
## modunda açılır: bütün ülkeleri yapay zekâ yönetir, zaman akar, kamera en kalabalık cephe bölgesine iner
func _dev_war_demo(slot := "") -> void:
	if slot == "":
		slot = "war_demo_watch" if FileAccess.file_exists(Game.SAVE_DIR + "war_demo_watch.json") else "war_demo"
	if not Game.load_game(slot):
		return
	Game.observer = true
	# kamera en yeni büyük güç savaşının cephesine (saldıranın yığını + karşısındaki savunan yığını en çok olan yer);
	# yoksa herhangi iki büyük gücün karşı karşıya durduğu en kalabalık yer
	var best := 0
	var best_n := 0
	var best_at := Vector2.ZERO
	var pairs: Array = []
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_DIR + slot + ".meta.json")) \
		if FileAccess.file_exists(Game.SAVE_DIR + slot + ".meta.json") else null
	if meta is Dictionary and Diplomacy.are_enemies(str(meta.get("a", "")), str(meta.get("b", ""))):
		pairs.append([str(meta["a"]), str(meta["b"])])      # savaş demosunun izlenen iki ülkesi
	for i in range(Diplomacy.wars.size() - 1, -1, -1):
		var w: Dictionary = Diplomacy.wars[i]
		var wa: Country = World.countries.get(str(w["attackers"][0]))
		var wd: Country = World.countries.get(str(w["defenders"][0]))
		if wa and wd and wa.is_major() and wd.is_major() and wa.exists() and wd.exists():
			pairs.append([wa.tag, wd.tag])
			break
	pairs.append(["", ""])
	# cephe noktası: iki taraf karşı karşıya (komşu bölgelerde); puan = çevresindeki (200 harita pikseli) iki tarafın
	# tümen sayısı — uzun, kalabalık cephe tek bir uzak çıkarmadan önce gelir
	for pair: Array in pairs:
		var front: Array[int] = []
		for pid: int in Military.by_province:
			var here: Array = Military.by_province[pid]
			var owner := (here[0] as Division).owner
			var oc: Country = World.countries.get(owner)
			if oc == null or not oc.is_major() or not World.province(pid).is_land() or (pair[0] != "" and owner != pair[0]):
				continue
			for q in World.land_neighbors(pid):
				# karşı taraf: komşuda düşman tümeni ya da (tümeni geride olsa da) izlenen düşmanın elindeki bölge
				var ok: bool = pair[1] != "" and World.controller_tag(q) == pair[1]
				for f: Division in Military.enemies_in(q, owner):
					if (pair[1] == "" and (World.countries[f.owner] as Country).is_major()) or f.owner == pair[1]:
						ok = true
						break
				if ok:
					front.append(pid)
					break
		# temas noktası: iki tarafın da kalabalık olduğu yer (puan: azınlıktaki tarafın sayısı önce), kamera cephe bölgesi
		# ile karşısındaki düşman bölgesinin ortasına (cephenin gerisine değil)
		for pid: int in front:
			var c := World.province(pid).center
			var foe_pid := 0
			var foe_most := -1
			for q in World.land_neighbors(pid):
				var ec := Military.enemies_in(q, (Military.by_province[pid][0] as Division).owner).size()
				if ec > foe_most:
					foe_most = ec
					foe_pid = q
			var m := c.lerp(World.province(foe_pid).center, 0.5) if foe_pid > 0 else c
			var na := 0
			var nb := 0
			for q: int in Military.by_province:
				if World.province(q).center.distance_to(m) < 150.0:
					for d: Division in Military.by_province[q]:
						if pair[0] == "" or d.owner == pair[0]:
							na += 1
						elif d.owner == pair[1]:
							nb += 1
			var n := mini(na, nb) * 3 + na + nb
			if n > best_n:
				best = pid
				best_n = n
				best_at = m
		if best != 0:
			break
	if best != 0:
		var dist := 320.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--dist="):
				dist = float(a.substr(7))       # geliştirici: demoyu başka yakınlıkta aç (çekim için)
		Game.resume_view = Vector3(best_at.x, best_at.y, dist)
	get_tree().reload_current_scene()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 2.25
	env.ssao_intensity = 1.65
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.09
	env.adjustment_saturation = 0.96
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.55, 0.62, 0.7)
	env.fog_depth_begin = 3500.0
	env.fog_depth_end = 12000.0
	env.fog_density = 0.35
	if UnitModels.COMPAT:
		# Compatibility (web): glow/SSAO/renk ayarı açıkken GLES3 ton eşlemeyi LDR son işlemde yapar ve
		# güneş gölgesi ayrı toplamalı geçişte çizilir; ikisi de görüntüyü Forward+'a göre çok parlatır.
		# Kapatılınca iki renderer aynı sonucu verir (ölçüldü: ort. fark 9/255, kalan SSAO ayrıntısı).
		env.ssao_enabled = false
		env.glow_enabled = false
		env.adjustment_enabled = false
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	sun.light_energy = 0.88
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = not UnitModels.COMPAT
	_sun = sun
	sun.directional_shadow_max_distance = 450.0
	add_child(sun)

## Geliştirici argümanları: godot --path . -- --screenshot=out.png [--dist=600] [--focus=x,y] [--select=id] [--mode=1] [--run]
func _handle_dev_args() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if Game.loaded:
		# dil değişimiyle ya da savaş demosuyla yeniden kurulan sahne: oyun sürer, yalnız görüntü argümanları kalır
		# (savaş demosu filme alınabilsin: --dev_war --speed=2 --shots=.. --every=.. --screenshot=..)
		for k: String in args.keys():
			if not k in ["screenshot", "wait", "shots", "every", "speed", "film", "dolly", "pan", "hide_ui", "plates", "fps", "spike_ms", "front_sel", "air_demo", "plane_view"]:
				args.erase(k)
	if args.has("plates"):
		UnitLayer.FIGURES = false            # geliştirici: web'deki gibi figür yerine levha (masaüstünde denemek için)
	if args.has("dev_war"):
		# ana menüdeki "Geliştirici: Savaş demosu" ile aynı (sahne kurulduktan sonra); --dev_war=kayıt başka izleme kaydı
		_dev_war_demo.call_deferred(str(args["dev_war"]))
		return
	if args.has("menu_settings"):
		Game.reopen_settings = true      # ana menü Ayarlar açık kurulur
	if args.has("nofog"):
		Military.fog_enabled = false         # geliştirici: savaş sisi kapalı (performans karşılaştırması)
	if args.has("scenario"):
		# test: senaryoyu doğrudan başlat --scenario=kimlik:ÜLKE (menüden başlatmayla aynı: yeni oyun varsayılanları)
		var sa: PackedStringArray = str(args["scenario"]).split(":")
		if sa.size() == 2 and Game.start_scenario(sa[0], sa[1]):
			Game.loaded = false
			Game.fresh_start = false
			_enter_playing(sa[1], false)
			_focus_front()
			hud.top_bar._update_date()
	if args.has("load"):
		if Game.load_game(args["load"]):
			Game.loaded = false
			_enter_playing(World.player_tag, true)
			hud.top_bar._update_date()      # saat ilerlemeden tarih kayıttaki gün olsun
	if args.has("play"):
		_start_game(args["play"] if args["play"] != "" else World.player_tag)
	elif args.has("setup"):
		_enter_setup()
	elif args.has("scenarios"):
		_enter_scenarios()
	if args.has("focus"):
		var xy: PackedStringArray = args["focus"].split(",")
		camera.focus_on(Vector2(float(xy[0]), float(xy[1])))
	if args.has("dist"):
		camera.focus_on(Vector2(camera.target.x, camera.target.z), float(args["dist"]))
	if args.has("settings"):
		hud.pause_menu.toggle()
		hud.pause_menu._settings()
		if args.has("lang_test"):
			# test: Ayarlar'dan dili değiştir (--lang_test=en); sahne yeniden kurulur, oyun kaldığı yerden sürer
			for i in 10:
				await get_tree().process_frame
			for sp in find_children("*", "SettingsPanel", true, false):
				(sp as SettingsPanel)._set_lang(args["lang_test"])
			return
	if args.has("politics_of"):
		hud.show_politics_of(args["politics_of"])     # test: başka ülkenin siyaseti (salt okunur)
	if args.has("pause_menu"):
		hud.pause_menu.toggle()
	if args.has("gameover"):
		Game._end(args["gameover"] != "lose", "GAMEOVER_WORLD" if args["gameover"] != "lose" else "GAMEOVER_DEFEAT")
	if args.has("event"):
		# test: oyuncuya olay gönder --event=id[,from]
		var ea: PackedStringArray = args["event"].split(",")
		Politics.fire_event(World.player(), ea[0], ea[1] if ea.size() > 1 else World.player_tag)
	if args.has("select"):
		World.select_province(int(args["select"]))
	if args.has("mode"):
		_set_mode(int(args["mode"]))
	if args.has("place"):
		# test: konuşlandırma kipi (--place=division|wing|ships): uygun eyaletler vurgulu, panel kapalı
		var kind: String = args["place"]
		_begin_place(kind, 0 if kind == "division" else ("fighter" if kind == "wing" else null))
	if args.has("queue"):
		var c := World.player()
		var sids := c.states.duplicate()
		sids.sort_custom(func(a: int, b: int) -> bool: return World.states[a].population > World.states[b].population)
		for i in 4:
			Economy.queue_building(c, World.states[sids[i]], "civilian_factory" if i % 2 == 0 else "military_factory")
		Economy.queue_building(c, World.states[c.capital_state], "infrastructure")
	if args.has("army_demo"):
		# test: örnek komuta zinciri (bir ordular grubu, iki ordu, boş bir ordu, bağlanmamış tümenler)
		var me := World.player_tag
		var mine := Military.country_divisions(me)
		var cms := Military.commanders_of(me)
		var g := Military.create_group(me)
		for cm in cms:
			if cm.is_marshal():
				Military.assign_group_commander(g, cm.id)
				break
		var third := mine.size() / 3
		var a1 := Military.create_army(me, mine.slice(0, third))
		var a2 := Military.create_army(me, mine.slice(third, third * 2))
		Military.set_army_group(a1, g.id)
		Military.set_army_group(a2, g.id)
		Military.assign_army_commander(a1, Military.free_commanders(me)[0].id)
		Military.assign_army_commander(a2, Military.free_commanders(me)[0].id)
		a1.enemy = args["army_demo"] if args["army_demo"] != "" else ""
		Military.create_army(me, [])
		if args.has("army_sel"):
			hud.army._sel = args["army_sel"]
		if args.has("sel_demo"):
			var pick := mine.slice(third - 4, third + 4)
			pick[5].manual = true
			pick[6].manual = true
			get_tree().create_timer(0.2).timeout.connect(func() -> void: units.select_divisions(pick, false))
	if args.has("split_demo"):
		# test: oyuncunun ilk 4 tümeni aynı bölgede; ikisinden yeni ordu → aynı bölgede iki ayrı sayaç/iğne
		var four := Military.country_divisions(World.player_tag).slice(0, 4)
		if four.size() == 4:
			for d: Division in four:
				d.province = four[0].province
				d.path.clear()
			var army := Military.create_army(World.player_tag, four.slice(0, 2))
			for cm: Commander in Military.commanders:
				if cm.owner == World.player_tag and not cm.is_marshal():
					Military.assign_army_commander(army, cm.id)       # sayacın yanında komutanın portresi
					break
			Military.divisions_changed.emit()
			var fp := World.province(four[0].province).center
			var fd := float(args["split_demo"]) if args["split_demo"] != "" else 160.0
			get_tree().create_timer(0.1).timeout.connect(func() -> void: camera.focus_on(fp, fd))
	if args.has("research_fill"):
		# test: boş araştırma yuvalarını açılabilen ilk teknolojilerle doldur, biraz ilerlet (ekran görüntüsü için)
		var rc := World.player()
		for id: String in Research.techs:
			if rc.research_current.size() >= rc.research_slots:
				break
			if Research.can_research(rc, id):
				Research.start(rc, id)
		for i in rc.research_current.size():
			rc.research_current[i]["progress"] = float(Research.techs[rc.research_current[i]["tech"]]["cost"]) * (0.2 + 0.2 * i)
	if args.has("panel"):
		match args["panel"]:
			"construction": hud.toggle_construction()
			"production": hud.toggle_production()
			"politics": hud.toggle_politics()
			"trade": hud.toggle_trade()
			"army": hud.toggle_army()
			"research": hud.toggle_research()
			"focus": hud.toggle_focus()
			"logistics": hud.toggle_logistics()
			"world": hud.toggle_world()
			"navy": hud.toggle_navy()
			"air": hud.toggle_air()
			"diplomacy": hud.diplomacy.open_for(args.get("target", ""))
	if args.has("build"):
		hud.toggle_construction()
		hud.construction._buttons[args["build"]].button_pressed = true
	if args.has("days"):
		GameClock.advance_hours(int(args["days"]) * 24)
		World.flush_ownership()
	if args.has("run"):
		GameClock.set_speed(5)
		GameClock.set_paused(false)
	if args.has("war"):
		# test savaşı: --war=GER,DEN (saldıran, hedef); garanti/ittifakları çağırmadan yalın savaş
		var wt: PackedStringArray = args["war"].split(",")
		var wa: Country = World.countries[wt[0]]
		wa.war_goals[wt[1]] = "ready"
		Diplomacy.declare_war(wt[0], wt[1])
	if args.has("army"):
		# test: oyuncunun bütün tümenleri tek ordu, --army=HEDEF cephe, --army_mode=attack
		var mine := Military.country_divisions(World.player_tag)
		var ar := Military.create_army(World.player_tag, mine)
		ar.enemy = args["army"]
		if args.get("army_mode", "") == "attack":
			ar.mode = Army.Mode.ATTACK
		for i in int(args.get("army_days", "0")):
			GameClock.advance_hours(24)
		if args.has("army_select"):
			if args.has("army_cmd"):
				Military.assign_army_commander(ar, Military.commanders_of(World.player_tag)[1].id)
			var pick6 := Military.army_divisions(ar).slice(0, 6)
			get_tree().create_timer(0.2).timeout.connect(func() -> void: units.select_divisions(pick6, false))
	if args.has("fx_test"):
		# efekt testi: kamera odağında muharebe efektleri (patlama, duman, namlu alevi)
		var fx := Node3D.new()
		var fp := Vector2(camera.target.x, camera.target.z)
		fx.position = Vector3(fp.x, maxf(map_view.height_at(fp), 0.0) + 1.0, fp.y)
		add_child(fx)
		fx.add_child(units.models._particles_flash())
		fx.add_child(units.models._particles_explosion())
		fx.add_child(units.models._particles_smoke())
	if args.has("focus_battle"):
		# [--battle_pair=GER,SOV]: yalnız bu saldıran ile savunanın en kalabalık muharebesi (kayıttan büyük savaş için)
		var bpair: PackedStringArray = str(args.get("battle_pair", "")).split(",") if args.has("battle_pair") else PackedStringArray()
		var pick := func() -> int:
			var best := 0
			var best_n := -1
			for bp: int in Military.battles:
				var bb: Dictionary = Military.battles[bp]
				var n := 0
				for d: Division in bb.get("attackers", []):
					if bpair.size() < 2 or d.owner == bpair[0]:
						n += 1
				var nd := 0
				for d: Division in bb.get("defenders", []):
					if bpair.size() < 2 or d.owner == bpair[1]:
						nd += 1
				if bpair.size() >= 2 and (n == 0 or nd == 0):
					continue
				if n + nd > best_n:
					best_n = n + nd
					best = bp
			return best
		for i in 24 * 90:
			if pick.call() != 0:
				break
			GameClock.advance_hours(1)
		var bpid: int = pick.call()
		if bpid != 0:
			var pid: int = bpid
			var b: Dictionary = Military.battles[pid]
			var m := World.province(int(b["from"])).center.lerp(World.province(pid).center, 0.5)
			camera.focus_on(m, float(args["focus_battle"]) if args["focus_battle"] != "" else 160.0)
	if args.has("focus_fleet"):
		# "TAG" limandaki ilk filo; "sea" denizdeki bir filo; "battle" deniz muharebesi (en çok 30 gün bekler)
		var want: String = args["focus_fleet"]
		var target: Fleet = null
		for i in (720 if want == "battle" else 1):
			if want == "battle" and not Navy.battles.is_empty():
				break
			if want == "battle":
				GameClock.advance_hours(1)
		if want == "battle" and not Navy.battles.is_empty():
			var bpos: Vector2 = Navy.battles.values()[0]["pos"]
			camera.focus_on(bpos, 260.0)
		else:
			for f in Navy.fleets:
				if (want == "sea" and f.is_moving()) or f.owner == want:
					target = f
					break
			if target:
				fleets.select(target)
				hud.show_navy()
				hud.navy.select(target)
				camera.focus_on(fleets.fleet_position(target) if fleets._positions.has(target.id) else World.province(target.location).center, 220.0)
	if args.has("focus_air"):
		# hava muharebesi olan bir bölgeye odaklan (en çok 60 gün bekler)
		for i in 60:
			if not Air.fights.is_empty():
				break
			GameClock.advance_hours(24)
		if not Air.fights.is_empty():
			var ap: Vector2 = Air.fights.values()[0]["pos"]
			camera.focus_on(ap, float(args["focus_air"]) if args["focus_air"] != "" else 260.0)
	if args.has("demo_order"):
		var me := World.player()
		var divs := Military.country_divisions(me.tag).slice(0, 6)
		units.select_divisions(divs, false)
		var target := 0
		for city in World.cities:
			if World.states.has(city.state_id) and World.states[city.state_id].owner == me.tag and city.province_id != divs[0].province and city.victory_points >= 3:
				target = city.province_id
		if args["demo_order"].is_valid_int():
			target = int(args["demo_order"])   # belirli hedef eyalet (ör. deniz aşırı)
		for d in divs:
			Military.order_move(d, target)
		units._dirty = true
	if args.has("off"):
		for what: String in args["off"].split(","):
			match what:
				"units": units.visible = false; units.process_mode = Node.PROCESS_MODE_DISABLED
				"labels": map_view.labels.visible = false
				"cities": cities.visible = false
				"ssao": _env.ssao_enabled = false
				"adjust": _env.adjustment_enabled = false
				"fog": _env.fog_enabled = false
				"glow": _env.glow_enabled = false
				"shadow": _sun.shadow_enabled = false
				"msaa": get_viewport().msaa_3d = Viewport.MSAA_DISABLED
				"clouds": map_view.set_camera_distance(0.0); map_view.process_mode = Node.PROCESS_MODE_DISABLED
				"ui": hud.visible = false
				"sun": _sun.light_energy = 0.0
				"ambient": _env.ambient_light_energy = 0.0
	if args.has("fps"):
		# performans ölçümü: n saniye oyun akarken ortalama FPS ve süreler
		var secs := float(args["fps"]) if args["fps"] != "" else 10.0
		await get_tree().create_timer(2.0).timeout
		# kayıttan açılışta kaydın görüşü --focus/--dist'i ezebilir: ölçüm istenen görüşte başlar (koşular karşılaştırılabilir);
		# gerçek imleç pencerenin kenarındaysa kenar kaydırması kamerayı oynatmasın
		camera.edge_pan_enabled = false
		if args.has("focus"):
			var fxy: PackedStringArray = args["focus"].split(",")
			camera.focus_on(Vector2(float(fxy[0]), float(fxy[1])), camera.distance)
		if args.has("dist"):
			camera.focus_on(Vector2(camera.target.x, camera.target.z), float(args["dist"]))
		await get_tree().create_timer(0.5).timeout
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_msec()
		var proc := 0.0
		var n := 0
		var ft: Array[float] = []            # kare süreleri (ms)
		var prof_prev := {}
		var day0 := World.day_count
		var vrid := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vrid, true)
		var rcpu := 0.0
		var rgpu := 0.0
		var pproc := 0.0
		GameClock.prof.clear()
		var tprev := Time.get_ticks_usec()
		while Time.get_ticks_msec() - t0 < secs * 1000.0:
			await get_tree().process_frame
			if args.has("run") and GameClock.paused:
				GameClock.set_paused(false)      # ölçüm: pencereye yanlışlıkla basılan Space/olay penceresi süreyi durdurmasın
			if args.has("fps_zoom"):
				# kamera 120 ile 1600 arasında gidip gelir (yakınlaştırma/uzaklaştırma, ~4 sn'de bir tur)
				var zt := Time.get_ticks_msec() / 1000.0
				camera.focus_on(Vector2(camera.target.x, camera.target.z), lerpf(120.0, 1600.0, 0.5 + 0.5 * sin(zt * 1.6)))
			if args.has("fps_mouse"):
				# fare haritada daire çizer (hover: bölge/yapı kartı, seçiliyse varış ve yol önizlemesi) — her karede 3 olay
				var vp := get_viewport().get_visible_rect().size
				for j in 3:
					var a := (Time.get_ticks_msec() / 1000.0 + j * 0.01) * 1.3
					var mv := InputEventMouseMotion.new()
					mv.position = vp * 0.5 + Vector2(cos(a), sin(a) * 0.6) * vp.y * 0.35
					mv.global_position = mv.position
					Input.parse_input_event(mv)
			var tn := Time.get_ticks_usec()
			ft.append((tn - tprev) / 1000.0)
			if (tn - tprev) > (int(args["spike_ms"]) * 1000 if args.has("spike_ms") else 150000):
				var parts: Array = []
				for k in GameClock.prof:
					var dv := int(GameClock.prof[k]) - int(prof_prev.get(k, 0))
					if dv > (3000 if args.has("spike_ms") else 8000):
						parts.append("%s=%d" % [k, dv / 1000])
				print("SPIKE %.0fms d=%.0f %s %s" % [(tn - tprev) / 1000.0, camera.distance, GameClock.date_string(), " ".join(parts)])
			prof_prev = GameClock.prof.duplicate()
			tprev = tn
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
			rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			n += 1
		var fps := (Engine.get_frames_drawn() - frames) / ((Time.get_ticks_msec() - t0) / 1000.0)
		ft.sort()
		if not ft.is_empty():
			print("FRAMES n=%d p50=%.1fms p95=%.1fms p99=%.1fms max=%.1fms gün/sn=%.1f" % [ft.size(), ft[ft.size() / 2], ft[ft.size() * 95 / 100],
				ft[mini(ft.size() * 99 / 100, ft.size() - 1)], ft[ft.size() - 1], float(World.day_count - day0) / ((Time.get_ticks_msec() - t0) / 1000.0)])
		print("FPS=%.1f process_ms=%.1f draw_calls=%d objects=%d prims=%d nodes=%d date=%s" % [fps, proc / maxi(n, 1) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), GameClock.date_string()])
		print("RENDER cpu=%.2fms gpu=%.2fms (kare başı ortalama)" % [rcpu / maxi(n, 1), rgpu / maxi(n, 1)])
		for k in GameClock.prof: print("  %s %.2f s" % [k, GameClock.prof[k] / 1e6])
		if OS.has_environment("PATHDBG"):
			var ks: Array = Military.path_stats.keys()
			ks.sort_custom(func(a, b) -> bool: return Military.path_stats[a].y > Military.path_stats[b].y)
			for k in ks.slice(0, 12):
				print("  PATH %-22s çağrı %5d adım %8d" % [k, Military.path_stats[k].x, Military.path_stats[k].y])
		get_tree().quit()
	if args.has("demo_fleet"):
		# oyuncunun ilk su üstü filosunu uzak bir deniz bölgesine gönder (hareket testi)
		for f in Navy.fleets_of(World.player_tag):
			if not f.is_sub_fleet():
				var far := 0
				var fd := 0.0
				for pid in Navy.zone(Navy.sea_for(f.home)).slice(0, 1):
					pass
				for q: Province in World.provinces:
					if q and q.type == Province.Type.SEA:
						var dd := q.center.distance_to(World.province(f.home).center)
						if dd > fd and dd < float(args["demo_fleet"] if args["demo_fleet"] != "" else "400") and not Navy.find_path(f.location, q.id).is_empty():
							fd = dd
							far = q.id
				if far > 0:
					Navy.set_mission(f, Fleet.Mission.SUPERIORITY, far)
					fleets.select(f)
				break
	if args.has("weather"):
		weather.force = {"clear": 0, "rain": 1, "snow": 2}.get(args["weather"], -1)
	if args.has("panel_air"):
		hud.toggle_air()
	if args.has("speed"):
		GameClock.set_speed(int(args["speed"]))
		GameClock.set_paused(false)
	if args.has("follow_fleet"):
		for i in int(args["follow_fleet"]):
			await get_tree().process_frame
			if fleets.selected:
				camera.focus_on(fleets.fleet_position(fleets.selected), camera.distance)
	if args.has("film"):
		# kısa video: godot --write-movie out.avi --fixed-fps 30 -- --play=.. --film=saniye
		#   [--dolly=uzak,yakın] kamera mesafesi yumuşak geçiş · [--pan=dx,dz] saniyede harita px kayma
		#   [--track] seçili tümen/filoyu izle · [--hide_ui] arayüzü gizle
		var secs := float(args["film"])
		camera.edge_pan_enabled = false
		_capture = true
		map_view.set_hovered(-1)
		if args.has("hide_ui"):
			hud.visible = false
		var d0 := camera.distance
		var d1 := d0
		if args.has("dolly"):
			var dd: PackedStringArray = args["dolly"].split(",")
			d0 = float(dd[0])
			d1 = float(dd[1])
			camera.focus_on(Vector2(camera.target.x, camera.target.z), d0)
		var pan := Vector2.ZERO
		if args.has("pan"):
			var pp: PackedStringArray = args["pan"].split(",")
			pan = Vector2(float(pp[0]), float(pp[1]))
		var t := 0.0
		var iters := 0
		var f0 := Engine.get_frames_drawn()
		while t < secs:
			await get_tree().process_frame
			var dt := minf(get_process_delta_time(), 1.0 / 20.0)   # yükleme takılmaları filmi kısaltmasın
			t += dt
			iters += 1
			var u := smoothstep(0.0, 1.0, t / secs)
			var c := Vector2(camera.target.x, camera.target.z)
			if args.has("track") and fleets.selected:
				c = fleets.fleet_position(fleets.selected)
			elif args.has("track") and not units.selected.is_empty():
				var sd: Division = units.selected[units.selected.size() - 1]
				if units.models and units.models.anchors.has(sd.id):
					c = units.models.anchors[sd.id][0]
			c += pan * dt
			camera.focus_on(c, lerpf(d0, d1, u))
			hud.tooltip.visible = false
		print("film: ", secs, " s ", GameClock.date_string(), " iters=", iters, " frames=", Engine.get_frames_drawn() - f0)
		get_tree().quit()
		return
	if args.has("plane_view"):
		# test: oyuncunun bir hava üssü yakından (park etmiş uçaklar); --plane_view[=uzaklık][:fly] fly: kanat üssünün
		# üstünde hava üstünlüğü görevine çıkar (kalkan ve tur atan uçaklar)
		var pva: PackedStringArray = str(args["plane_view"]).split(":")
		var pvd := float(pva[0]) if pva[0] != "" else 60.0
		for w in Air.wings_of(World.player_tag):
			if w.planes > 0 and map_view.airbase_sites.has(w.base):
				var bp: Vector2 = map_view.airbase_sites[w.base][0]
				camera.focus_on(bp + Vector2(0, 9.0), pvd)
				if "fly" in pva:
					print("plane_view görev: ", Air.assign(w, map_view.province_at(bp), AirWing.Mission.SUPERIORITY))
				print("plane_view: üs=%d kanat=%d %s" % [w.base, w.id, bp])
				break
		for i in 20:
			await get_tree().process_frame
	if args.has("shots") and args.has("screenshot"):
		# film şeridi: N kare, her biri `every` kare arayla (hareket kalitesi incelemesi)
		var n := int(args["shots"])
		var every := int(args.get("every", "30"))
		var base: String = args["screenshot"].trim_suffix(".png")
		camera.edge_pan_enabled = false      # çekim sırasında fare kamerayı kaydırmasın, ipucu açmasın
		_capture = true
		for k in n:
			for i in every:
				await get_tree().process_frame
				map_view.set_hovered(-1)
				hud.tooltip.visible = false
				if args.has("track") and fleets.selected:
					camera.focus_on(fleets.fleet_position(fleets.selected), camera.distance)
				elif args.has("track") and not units.selected.is_empty():
					var sd: Division = units.selected[units.selected.size() - 1]
					if units.models and units.models.anchors.has(sd.id):
						camera.focus_on(units.models.anchors[sd.id][0], camera.distance)
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [base, k])
		print("shots: ", n, " ", GameClock.date_string())
		if args.has("dump_ui"):
			var st: Array[Node] = [get_tree().root]
			while not st.is_empty():
				var nd: Node = st.pop_back()
				if nd is Window and nd != get_tree().root and (nd as Window).visible:
					print("WIN ", nd.get_path(), " ", nd.get_class(), " ", (nd as Window).position, " ", (nd as Window).size)
				if nd is Control and (nd as Control).is_visible_in_tree():
					var r := (nd as Control).get_global_rect()
					if r.size.y > 400 and r.size.x < 900:
						print("UI ", nd.get_path(), " ", nd.get_class(), " ", r)
				st.append_array(nd.get_children())
		get_tree().quit()
		return
	if args.has("click"):
		# test: ekran koordinatına sol tık (basma + bırakma) enjekte et: --click=x,y[;x2,y2]
		for i in 20:
			await get_tree().process_frame
		for pt: String in args["click"].split(";"):
			var xy: PackedStringArray = pt.split(",")
			var pos := Vector2(float(xy[0]), float(xy[1]))
			var mv := InputEventMouseMotion.new()
			mv.position = pos
			mv.global_position = pos
			Input.parse_input_event(mv)
			await get_tree().process_frame
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = pos
				ev.global_position = pos
				Input.parse_input_event(ev)
				await get_tree().process_frame
	if args.has("screenshot"):
		for i in (int(args["wait"]) if args.has("wait") else 40):
			await get_tree().process_frame
		# Görsel QA: belirli bir bölgenin bilgi kartını ve gerçek cursor dokusunu kadraja ekle.
		if not args.has("hover") and not args.has("hover_route") and not args.has("hover_building"):
			set_process(false)          # gerçek imlecin harita ipucu kareye girmesin
			hud.tooltip.visible = false
		if args.has("hover"):
			var hv: PackedStringArray = args["hover"].split(",")
			var hp := Vector2(float(hv[1]), float(hv[2])) if hv.size() >= 3 else Vector2(960, 540)
			hud.tooltip.show_province(int(hv[0]), hp)
			if args.has("cursor"):
				var cursor_preview := TextureRect.new()
				cursor_preview.texture = load("res://assets/ui/cursors/command.svg")
				cursor_preview.position = hp - Vector2(4, 3)
				cursor_preview.custom_minimum_size = Vector2(24, 24)
				cursor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hud.root.add_child(cursor_preview)
			await get_tree().process_frame
		if args.has("hover_at"):
			# test: ekran konumundaki bölgenin kartı --hover_at=x,y
			var hv3: PackedStringArray = args["hover_at"].split(",")
			var hp3 := Vector2(float(hv3[0]), float(hv3[1]))
			hud.tooltip.order_eta = _order_eta(_pick(hp3))      # tümen seçiliyse tahmini varış
			hud.tooltip.order_odds = _order_odds(_pick(hp3))    # düşman bölgesiyse saldırı tahmini
			hud.tooltip.show_province(_pick(hp3), hp3)
			await get_tree().process_frame
		if args.has("air_demo"):
			# test: hava paneli açık, hedef cephedeki bir düşman bölgesi (--air_demo[=ÜLKE]: izleyici kipinde o ülke)
			var ad: String = args["air_demo"]
			if ad != "" and World.countries.has(ad):
				World.player_tag = ad
			var ap := _front_pick()
			hud.toggle_air()
			if not ap.is_empty():
				hud.air.set_target(ap[1])
				camera.focus_on(World.province(ap[1]).center, 900.0)
			for i in 30:
				await get_tree().process_frame
			print("air_demo: hedef=%d kanat=%d" % [hud.air.target_zone, Air.wings_of(World.player_tag).size()])
		if args.has("front_sel"):
			# test: cephede kendi tümenlerimizin durduğu, karşısında düşman askeri olan bölge: tümenler seçilir, düşman
			# bölgesinin kartı saldırı tahminiyle açılır (seçim panelinin komutları ve kart birlikte görünür).
			# --front_sel[=ÜLKE][:uzaklık]: ülke verilirse (izleyici kipindeki savaş demosu) o ülkenin gözünden
			var fsa: PackedStringArray = str(args["front_sel"]).split(":")
			if fsa[0] != "" and World.countries.has(fsa[0]):
				World.player_tag = fsa[0]
			var fs := _front_pick()
			if fs.is_empty():
				print("front_sel: cephe yok")
			else:
				var own: Array = Military.divisions_in(fs[0]).filter(func(d: Division) -> bool: return d.owner == World.player_tag)
				units.select_divisions(own, false)
				var fsd: String = fsa[fsa.size() - 1]
				camera.focus_on(World.province(fs[0]).center, float(fsd) if fsd.is_valid_float() else 300.0)
				for i in 30:
					await get_tree().process_frame
				var hp4 := Vector2(90, 110)
				hud.tooltip.order_eta = _order_eta(fs[1])
				hud.tooltip.order_odds = _order_odds(fs[1])
				hud.tooltip.show_province(fs[1], hp4)
				print("front_sel: own=%d (%d tümen) enemy=%d odds=%s" % [fs[0], own.size(), fs[1], str(hud.tooltip.order_odds)])
				await get_tree().process_frame
		if args.has("scroll_end"):
			# test: açık yan panel en alta kaydırılır; panelin ve kaydırma alanının ekrandaki yeri yazılır
			for p: Control in hud._left_panels():
				if p.visible and p.has_meta("scroll"):
					var sc: ScrollContainer = p.get_meta("scroll")
					sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
					await get_tree().process_frame
					print("PANEL ", p.name, " rect=", p.get_global_rect(), " scroll=", sc.get_global_rect(), " vp=", get_viewport().get_visible_rect().size)
		if args.has("hover_building"):
			# test: ekranın ortasına en yakın yapı rozetinin üstüne gel (büyüme, ses, kart) --hover_building
			var best := {}
			var bp := Vector2.ZERO
			var mid := get_viewport().get_visible_rect().size * 0.5
			for gy in range(40, int(mid.y * 2.0) - 40, 6):
				for gx in range(40, int(mid.x * 2.0) - 40, 6):
					var q := Vector2(gx, gy)
					if best.is_empty() or q.distance_to(mid) < bp.distance_to(mid):
						var h := pins.pick_building(q)
						if not h.is_empty():
							best = h
							bp = q
			print("hover_building ", best, " at ", bp)
			if not best.is_empty():
				pins.set_hovered_building(best)
				hud.tooltip.show_building(int(best["sid"]), String(best["building"]), bp)
			await get_tree().process_frame
		if args.has("ctrl_hover"):
			# test: Ctrl basılıyken ülke kartı --ctrl_hover=x,y (ekran konumu)
			var cv: PackedStringArray = args["ctrl_hover"].split(",")
			var cp := Vector2(float(cv[0]), float(cv[1]))
			_country_hover(_pick(cp), cp)
			await get_tree().process_frame
		if args.has("hover_route"):
			var hv2: PackedStringArray = args["hover_route"].split(",")
			var rp := Vector2(float(hv2[0]), float(hv2[1]))
			var r := _route_at(rp)
			if not r.is_empty():
				routes.select(r)
				hud.tooltip.show_route(r, rp)
			await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(args["screenshot"])
		print("screenshot: ", args["screenshot"], " date=", GameClock.date_string())
		get_tree().quit()

func _process(delta: float) -> void:
	# sis kamera mesafesine göre: odak noktası hiç sislenmesin, yalnız ufuk (dünya zoom'unda harita soluklaşmasın)
	if _env and camera:
		_env.fog_depth_begin = maxf(3500.0, camera.distance * 1.25)
		_env.fog_depth_end = _env.fog_depth_begin * 3.5
	if units.process_mode != Node.PROCESS_MODE_DISABLED:
		units.visible = phase == Phase.PLAYING
	cities.get_node_or_null(".")
	map_view.set_view_scale(camera.view_scale())
	map_view.set_camera_distance(camera.distance)
	_update_reach()
	if phase == Phase.MENU:
		# menü arkasında Avrupa üzerinde yavaş süzülme
		_drift_t += delta * 0.035
		var eu := World.capital_position("GER")
		camera.focus_on(eu + Vector2(cos(_drift_t) * 700, sin(_drift_t * 1.3) * 380), 1250.0)
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control is BaseButton:
		Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN if (hovered_control as BaseButton).disabled else Input.CURSOR_POINTING_HAND)
	elif _middle_down:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	elif phase == Phase.PLAYING and (not units.selected.is_empty() or hud.construction.selected != ""):
		var cursor_pid := _pick(get_viewport().get_mouse_position())
		var cursor_province := World.province(cursor_pid)
		Input.set_default_cursor_shape(Input.CURSOR_CROSS if cursor_province and cursor_province.is_land() else Input.CURSOR_FORBIDDEN)
	elif pins and pins.hovered_building() != "":
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if hud.is_mouse_over_ui():
		hud.tooltip.visible = false
		if pins:
			pins.set_hovered_building({})
		_eta_sig = ""
	if _ctrl_country != "" and (hud.is_mouse_over_ui() or not Input.is_key_pressed(KEY_CTRL)):
		_country_hover(0, Vector2.ZERO)        # Ctrl bırakıldı (pencere dışında da) ya da imleç arayüzde: vurgu kalkar
		map_view.set_hovered(0)
	# arayüzle uğraşırken harita kıpırdamaz: tam ekran panelde kamera kilitli, arayüz üstünde kenar kaydırması yok
	var locked := hud.fullscreen_open()
	camera.input_locked = locked
	camera.edge_pan_enabled = GameSettings.edge_pan and not locked and not hud.is_mouse_over_ui()

func _pick(screen: Vector2) -> int:
	var g = camera.ground_point(screen)
	return map_view.province_at(Vector2(g.x, g.z)) if g != null else 0

## Tümen emrinin hedefi: imleç bir sayacın üstündeyse o sayacın bölgesi (yığına katılma), değilse zemin
func _order_target(screen: Vector2) -> int:
	var cp := units.pick_province(screen) if not units.selected.is_empty() else 0
	return cp if cp > 0 else _pick(screen)

## Sağ tık emri: imleç bir sayacın üstündeyse o yığına katılır; değilse tıklanan bölgeye gider ve tıklanan noktada durur
## (sınırın dibi, bölgenin ortası...). Tümenin kendi bölgesine tıklamak onu durdurup o noktaya alır.
func _order_at(screen: Vector2) -> void:
	var cp := units.pick_province(screen)
	if cp > 0:
		_order_move(cp)
		return
	var g = camera.ground_point(screen)
	if g == null:
		return
	var at := Vector2(g.x, g.z)
	_order_move(map_view.province_at(at), at)

var _capture := false                 ## geliştirici çekimi (--shots, --film) sürüyor: fare ve tekerlek haritayı oynatmaz

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.MENU or _capture:
		return
	if hud.fullscreen_open() and (event is InputEventMouse or event is InputEventGesture):
		return          # tam ekran panel açıkken harita fareye tepki vermez
	if phase == Phase.SETUP:
		_setup_input(event)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var button := mb.button_index
		if mb.ctrl_pressed and (button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT):
			# Ctrl + tık: birlik/filo seçiliyse hareket emri (Mac ve web'de sağ tık yerine), değilse o ülkenin siyaseti
			if not _has_order_selection():
				if mb.pressed:
					_ctrl_click(mb.position)
				return
			button = MOUSE_BUTTON_RIGHT   # macOS masaüstünde sistem bunu zaten sağ tık yapar; web'de (tarayıcı) yapmaz
		match button:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed: camera.zoom_at(mb.position, mb.factor if mb.factor > 0 else 1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed: camera.zoom_at(mb.position, -(mb.factor if mb.factor > 0 else 1.0))
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_left_down = true
					_dragging = false
					_press_pos = mb.position
					_last_mouse = mb.position
				else:
					if _left_down and _dragging:
						units.select_in_rect(Rect2(_press_pos, mb.position - _press_pos).abs(), mb.shift_pressed)
						hud.select_box.visible = false
					elif _left_down:
						_left_click(mb.position, mb.shift_pressed)
					_left_down = false
					_dragging = false
			MOUSE_BUTTON_MIDDLE:
				_middle_down = mb.pressed
				_last_mouse = mb.position
				if mb.pressed:
					camera.begin_drag()
				else:
					camera.end_drag()       # bırakınca harita süzülür
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					if not _place.is_empty():
						_end_place()
					elif _zone_pick:
						_zone_pick = null
					elif fleets.selected and fleets.selected.owner == World.player_tag:
						_order_fleet(fleets.selected, _pick(mb.position))
					elif not units.selected.is_empty():
						_order_at(mb.position)
					else:
						World.select_province(0)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _left_down and not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			var r := Rect2(_press_pos, mm.position - _press_pos).abs()
			hud.select_box.position = r.position
			hud.select_box.size = r.size
			hud.select_box.visible = true
		if _middle_down:
			camera.drag(_last_mouse, mm.position)
		_last_mouse = mm.position
		var __hv := Time.get_ticks_usec()
		var pid := _pick(mm.position)
		# tümen seçiliyken vurgu ve kart emrin gideceği bölgeyi gösterir (sayacın üstünde: sayacın bölgesi)
		if not units.selected.is_empty() and not _dragging:
			pid = _order_target(mm.position)
		map_view.set_hovered(pid)
		var hb := pins.pick_building(mm.position) if not _dragging and not _middle_down else {}
		pins.set_hovered_building(hb)
		hud.tooltip.order_eta = _order_eta(pid)
		hud.tooltip.order_odds = _order_odds(pid)
		var hf := fleets.pick(mm.position)
		var hr := _route_at(mm.position)
		_country_hover(pid if mm.ctrl_pressed and units.selected.is_empty() else 0, mm.position)   # tümen seçiliyken Ctrl: yürüme menzili
		if _ctrl_country != "":
			pass
		elif not hb.is_empty():
			hud.tooltip.show_building(int(hb["sid"]), String(hb["building"]), mm.position)
		elif hf:
			hud.tooltip.show_fleet(hf, mm.position)
		elif not hr.is_empty():
			hud.tooltip.show_route(hr, mm.position)
		else:
			hud.tooltip.show_province(pid, mm.position)
		GameClock.timed("hover", __hv)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		camera.zoom_at(mg.position, log(mg.factor) / log(MapCamera3D.ZOOM_STEP))
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		camera.drag(pg.position, pg.position - pg.delta * 12.0)
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_CTRL and not event.echo:
		# Ctrl basılınca imlecin altındaki ülkenin genel durumu; bırakınca normal bölge kartı
		var mp := get_viewport().get_mouse_position()
		var pid := _pick(mp)
		_country_hover(pid if event.pressed and units.selected.is_empty() else 0, mp)
		if not event.pressed:
			hud.tooltip.show_province(pid, mp)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE: GameClock.toggle_pause()
			KEY_EQUAL, KEY_KP_ADD: GameClock.change_speed(1)
			KEY_MINUS, KEY_KP_SUBTRACT: GameClock.change_speed(-1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5: GameClock.set_speed(event.keycode - KEY_0)
			KEY_F1: _set_mode(0)
			KEY_F2: _set_mode(1)
			KEY_F3: _set_mode(2)
			KEY_F4: _set_mode(3)
			KEY_ESCAPE:
				if hud.pause_menu.visible:
					hud.pause_menu.close()
				elif not _place.is_empty():
					_end_place()
				elif _zone_pick or _wing_pick or _recon_pick:
					_zone_pick = null
					_wing_pick = null
					_recon_pick = false
				elif fleets.selected:
					fleets.select(null)
					hud.navy.select(null)
				elif not units.selected.is_empty():
					units.clear_selection()
				elif hud.any_panel_open() or World.selected_province != 0:
					hud.close_panels()
					World.select_province(0)
				else:
					hud.pause_menu.toggle()
			KEY_HOME: camera.focus_on(World.capital_position(World.player_tag))
			KEY_T: if Economy.CONSTRUCTION: hud.toggle_construction()
			KEY_Y: hud.toggle_production()
			KEY_Q: hud.toggle_politics()
			KEY_R: hud.toggle_trade()
			KEY_N: hud.toggle_navy()
			KEY_H: hud.toggle_air()
			KEY_K: _begin_recon()
			KEY_L: hud.toggle_logistics()
			KEY_I: hud.toggle_research()
			KEY_O: hud.toggle_diplomacy()
			KEY_F: hud.toggle_focus()
			KEY_E: hud.toggle_world()
			KEY_F5: Game.save_game("hizli_kayit")

var _eta_sig := ""
var _eta_text := ""

## Seçili birliklerin imleçteki bölgeye tahmini varışı (kartın altında; yol çizilmez — yol ancak emirle çıkar). Bölge ya
## da seçim değişince hesaplanır; en çok 3 tümenin yolu aranır, en yavaşı yazılır. Filo seçiliyse sağ tık hedefine varışı.
func _order_eta(pid: int) -> String:
	var p := World.province(pid)
	var fl := fleets.selected
	var sig := "%d|" % pid
	if fl and fl.owner == World.player_tag:
		sig += "f%d" % fl.id
	else:
		for d: Division in units.selected.slice(0, 3):
			sig += "%d," % d.id
	if sig == _eta_sig:
		return _eta_text
	_eta_sig = sig
	_eta_text = ""
	if fl and fl.owner == World.player_tag:
		if p != null and p.type != Province.Type.LAKE:
			var fh := Navy.eta_hours(fl, pid)
			_eta_text = tr("ORDER_ETA_FLEET_NONE") if fh < 0.0 else tr("ORDER_ETA_FLEET") % maxi(1, ceili(fh / 24.0))
		return _eta_text
	if units.selected.is_empty() or p == null or not p.is_land():
		return ""
	var worst := -1.0
	var n := 0
	for d: Division in units.selected:
		if d.owner != World.player_tag:
			continue
		n += 1
		if n > 3:
			break
		worst = maxf(worst, Military.eta_hours(d, pid))
	if n > 0:
		_eta_text = tr("ORDER_ETA_NONE") if worst < 0.0 else tr("ORDER_ETA") % maxi(1, ceili(worst / 24.0))
	return _eta_text

var _odds_sig := ""
var _odds: Dictionary = {}

## Oyun başlar başlamaz sis: görünürlük hesaplanır, figürler ve harita bulutu hemen ona göre (ilk karede bulutun
## altındakiler görünmesin)
func _fog_start() -> void:
	Military.invalidate_fog()
	_update_fog()

## Keşif: sonraki sol tık hedef bölgeyi seçer
func _begin_recon() -> void:
	if phase != Phase.PLAYING:
		return
	_recon_pick = true
	_wing_pick = null
	_zone_pick = null
	World.notify(tr("RECON_PICK"), "info")

## Keşif emri: menzildeki boştaki kanatlardan biri bölgeye keşfe çıkar (avcı önce, sonra en yakın üs); başka görevdeki
## kanat alınmaz, zaten keşifte olan yeniden yönlendirilebilir. Kanadın üssü yetmiyorsa Air.assign menzili yeten üsse geçirir.
func _order_recon(pid: int) -> void:
	var p := World.province(pid)
	if p == null:
		return
	var best: AirWing = null
	var best_score := INF
	for w in Air.wings_of(World.player_tag):
		if w.planes <= 0 or (w.on_mission() and w.mission != AirWing.Mission.RECON):
			continue
		var base := w.base if Air.in_range(w, pid) else Air.base_for(w, pid)
		if base == 0:
			continue
		var score := Air.distance_km(Air.base_pos(base), p.center) + (3000.0 if w.on_mission() else 0.0) \
			+ (0.0 if w.type == "fighter" else 500.0)
		if score < best_score:
			best_score = score
			best = w
	if best == null:
		World.notify(tr("RECON_NONE"), "bad")
		return
	var err := Air.assign(best, pid, AirWing.Mission.RECON)
	if err != "":
		World.notify(tr(err), "bad")
		return
	Audio.play("select_air", 150)
	World.notify(tr("RECON_OK") % [best.name, Air.zone_name(pid), roundi(Air.recon_cost())], "good")
	if hud.air.visible:
		hud.air.refresh()

## Savaş sisi haritada bulut: sis açıksa bölge düzeyleri haritaya (yalnız sis yeniden hesaplandıysa doku değişir)
func _update_fog() -> void:
	if Military.fog_active():
		var lv := Military.fog_levels()
		map_view.set_fog(lv, Military.fog_version)
	else:
		map_view.set_fog(PackedByteArray(), 0)

## Senaryo başında kamera cepheye: oyuncunun düşmana komşu en kalabalık bölgesi (yoksa başkentte kalır)
func _focus_front() -> void:
	var fp := _front_pick()
	if not fp.is_empty():
		camera.focus_on(World.province(fp[0]).center, 900.0)

## Geliştirici: oyuncunun en az iki tümeninin durduğu, komşusunda düşman askeri olan bölge ve o düşman bölgesi
## ([kendi, düşman]; en kalabalık kendi bölgesi; yoksa boş)
func _front_pick() -> Array:
	var me := World.player_tag
	var best: Array = []
	var best_n := 1
	for pid: int in Military.by_province:
		var n := 0
		for d: Division in Military.by_province[pid]:
			if d.owner == me and d.training == 0 and d.path.is_empty():
				n += 1
		if n <= best_n or not World.province(pid).is_land():
			continue
		for q in World.land_neighbors(pid):
			if Diplomacy.are_enemies(World.controller_tag(q), me) and not Military.enemies_in(q, me).is_empty():
				best = [pid, q]
				best_n = n
				break
	return best

## Seçili kendi tümenlerimizle imleçteki düşman bölgesine saldırı tahmini (kartta). Bölge, seçim ya da oyun saati
## değişince yeniden hesaplanır.
func _order_odds(pid: int) -> Dictionary:
	var p := World.province(pid)
	if units.selected.is_empty() or p == null or not p.is_land() \
			or not Diplomacy.are_enemies(World.controller_tag(pid), World.player_tag):
		_odds_sig = ""
		return {}
	var sig := "%d|%d|%d|" % [pid, GameClock.day, GameClock.hour]
	var mine: Array = []
	for d: Division in units.selected:
		if d.owner == World.player_tag:
			mine.append(d)
			sig += "%d," % d.id
	if mine.is_empty():
		_odds_sig = ""
		return {}
	if sig != _odds_sig:
		_odds_sig = sig
		# savaş sisi: görmediğimiz bölgenin gücü bilinmez
		_odds = Military.attack_estimate(mine, pid) if Military.is_visible(pid) else {"unknown": true}
	return _odds

## Yollar modunda imlecin altındaki rota
func _route_at(screen: Vector2) -> Dictionary:
	if not routes.active:
		return {}
	var g = camera.ground_point(screen)
	return routes.pick(Vector2(g.x, g.z)) if g != null else {}

## Birlik, filo ya da hava/deniz bölgesi seçimi sürüyorsa Ctrl + tık emir verir
func _has_order_selection() -> bool:
	return not units.selected.is_empty() or (fleets.selected != null and fleets.selected.owner == World.player_tag) \
		or _zone_pick != null or _wing_pick != null or not _place.is_empty()

func _country_at(pid: int) -> String:
	var p := World.province(pid)
	if p == null or not p.is_land():
		return ""
	var st := World.state_of_province(pid)
	return st.owner if st and World.countries.has(st.owner) else ""

## Ctrl basılıyken ülke kartı ve ülke vurgusu (pid 0: kapat)
func _country_hover(pid: int, pos: Vector2) -> void:
	var tag := _country_at(pid) if pid > 0 else ""
	if tag != _ctrl_country:
		_ctrl_country = tag
		map_view.set_highlight_country(tag)
	if tag != "":
		hud.tooltip.show_country(tag, pos, not _has_order_selection())

func _ctrl_click(pos: Vector2) -> void:
	var tag := _country_at(_pick(pos))
	if tag != "":
		_country_hover(0, pos)
		hud.tooltip.visible = false
		hud.show_politics_of(tag)

func _left_click(pos: Vector2, shift: bool) -> void:
	if routes.active and not _wing_pick and not _zone_pick:
		var r := _route_at(pos)
		routes.select(r)
		if not r.is_empty():
			hud.tooltip.show_route(r, pos)
			return
	if not _place.is_empty():
		var g = camera.ground_point(pos)
		_place_at(_pick(pos), Vector2(g.x, g.z) if g != null else Vector2.INF)
		return
	if _recon_pick:
		_recon_pick = false
		_order_recon(_pick(pos))
		return
	if _wing_pick:
		var w := _wing_pick
		_wing_pick = null
		var err := Air.order(w, _pick(pos))
		if err == "":
			Audio.play("select_air", 150)
			World.notify(tr("AIR_ORDER_OK") % [w.name, tr("AIR_MISSION_%d" % int(w.mission)), Air.zone_name(w.zone)], "info")
		else:
			World.notify(tr(err), "bad")
		hud.air.refresh()
		return
	if _zone_pick:
		var f := _zone_pick
		_zone_pick = null
		_order_fleet(f, _pick(pos))
		return
	var fl := fleets.pick(pos)
	if fl and fl.owner == World.player_tag:
		units.clear_selection()
		fleets.select(fl)
		hud.show_navy()
		hud.navy.select(fl)
		return
	if fleets.selected and not shift:
		fleets.select(null)
		hud.navy.select(null)
	var divs := units.pick(pos)
	if not divs.is_empty() and divs[0].owner == World.player_tag:
		units.select_divisions(divs, shift)
		return
	if not shift:
		units.clear_selection()
	# yapı rozetine tıklanınca rozetin eyaleti (iğne ucu yerden yüksekte: imlecin altındaki bölge başka olabilir)
	var hb := pins.pick_building(pos)
	var target := int(hb["pid"]) if not hb.is_empty() and int(hb["pid"]) > 0 else _pick(pos)
	if hud.construction.visible and hud.construction.selected != "":
		_try_build(target)
	elif hud.air.visible:
		hud.air.set_target(target)          # hava: önce bölge, sonra panelde kanatlara görev
		Audio.play("select_air", 150)
	else:
		World.select_province(target)

## Seçili tümenlere hareket/saldırı emri
## at: bölge içinde duruş noktası (harita pikseli; INF = şehrin yanındaki olağan nokta)
func _order_move(pid: int, at := Vector2.INF) -> void:
	var p := World.province(pid)
	if p == null or p.type == Province.Type.LAKE:
		return
	var ok := 0
	_eta_sig = ""
	# hareket bölgeden bölgeye: tıklanan bölgeye gider, bölgenin olağan noktasında durur (bölge içinde nokta seçilmez);
	# orada kendi askeri varsa varınca tek figürde birleşir. Kendi bölgesine emir: yolundaysa durur.
	# düşman bölgesine: sınırındaki en yakın dost bölgeye yürüyüp oradan saldırır (Military.order_attack)
	var hostile := p.is_land() and Diplomacy.are_enemies(World.controller_tag(pid), World.player_tag)
	for d in units.selected:
		var moved := false
		if pid == d.province and d.owner == World.player_tag:
			Military.stop(d)
			moved = true
		elif hostile and Military.order_attack(d, pid):
			moved = true
		elif not hostile and Military.order_move(d, pid):
			moved = true
		if moved:
			ok += 1
			if d.army != 0 and d.owner == World.player_tag:
				d.manual = true          # doğrudan emir: ordu planı bu tümeni geri çekmez (seçim panelinden plana döner)
	if ok == 0:
		# neden: eğitimdeki tümen yürüyemez; yoksa geçiş izni / deniz / genel
		var mover: Division = null
		for d in units.selected:
			if d.training == 0:
				mover = d
				break
		World.notify(tr("NOTE_IN_TRAINING") if mover == null else Military.no_path_reason(mover.owner, mover.province, pid), "bad")
	else:
		Audio.play("order_attack" if Diplomacy.are_enemies(World.controller_tag(pid), World.player_tag) else "order_move", 150)
	units._dirty = true

## Seçili filoya emir: deniz/kıyı -> görev bölgesi, kendi limanı -> üs
func _order_fleet(f: Fleet, pid: int) -> void:
	if Navy.order(f, pid):
		Audio.play("order_move", 150)
		var what := Navy.zone_name(f.zone_center) if f.mission != Fleet.Mission.PORT else (World.province(f.home).city.display_name() if World.province(f.home).city else "")
		World.notify(tr("NAVY_ORDER_OK") % [f.name, "%s — %s" % [tr("MISSION_%d" % int(f.mission)), what]], "info")
		hud.navy.refresh()
	else:
		World.notify(tr("NOTE_NO_PATH"), "bad")

func _try_build(pid: int) -> void:
	var st := World.state_of_province(pid)
	if st == null:
		return
	var b := hud.construction.selected
	var err := Economy.can_build(World.player(), st, b)
	if err == "":
		Economy.queue_building(World.player(), st, b)
	hud.construction.show_result(err)

## İnşaat modunda: seçili bina için uygun eyaletleri haritada yeşil göster
## Konuşlandırmayı başlat: uygun eyaletler (tümen: elimizdeki kendi eyaletlerimiz; kanat: hava üslü eyaletler; gemi:
## limanlı eyaletler), panel kapanır, harita uygun olmayanları karartır
func _begin_place(kind: String, data: Variant) -> void:
	var c := World.player()
	var marks := {}
	var any := false
	match kind:
		"division":
			for sid: int in c.states:
				var st: StateRegion = World.states[sid]
				var ok := false
				for pid in st.provinces:
					if World.controller_tag(pid) == c.tag and World.province(pid).is_land():
						ok = true
						break
				marks[sid] = ok
		"wing":
			var bases := Air.bases_of(c.tag)
			for sid: int in c.states:
				marks[sid] = sid in bases
		"ships":
			for sid: int in c.states:
				marks[sid] = false
			for pid in Navy.ports_of(c.tag):
				var st := World.state_of_province(pid)
				if st:
					marks[st.id] = true
	for sid: int in marks:
		any = any or bool(marks[sid])
	if not any:
		World.notify(tr("PLACE_NONE"), "bad")
		return
	hud.close_panels()
	_zone_pick = null
	_wing_pick = null
	_place = {"kind": kind, "data": data, "marks": marks}
	map_view.set_marked_states(marks)
	var what := ""
	match kind:
		"division": what = String(c.templates[int(data)]["name"])
		"wing": what = tr("WING_TYPE_" + String(data))
		"ships": what = tr("NAVY_NEW_SHIPS")
	World.notify(tr("PLACE_" + kind.to_upper()) % what, "info")

func _end_place() -> void:
	_place = {}
	map_view.set_marked_states({})
	_update_construction_marks()

## Seçilen bölgeye konuşlandır (uygun değilse neden söylenir, seçim sürer)
## spot: tıklanan nokta (bölge seçimi için; tümen bölgenin olağan noktasında durur)
func _place_at(pid: int, spot := Vector2.INF) -> void:
	var c := World.player()
	var p := World.province(pid)
	var sid := p.state_id if p else 0
	if p == null or not bool((_place["marks"] as Dictionary).get(sid, false)):
		World.notify(tr("PLACE_INVALID"), "bad")
		return
	var st: StateRegion = World.states[sid]
	match String(_place["kind"]):
		"division":
			var ti := int(_place["data"])
			var at := pid
			if not p.is_land() or World.controller_tag(pid) != c.tag:
				for q in st.provinces:
					if World.controller_tag(q) == c.tag and World.province(q).is_land():
						at = q
						break
			var d := Military.deploy(c, ti, at)
			if d == null:
				World.notify(tr("PLACE_INVALID"), "bad")
			else:
				Audio.play("deploy")
				World.notify(tr("NOTE_DEPLOYED_AT") % [c.templates[ti]["name"], st.display_name()], "good")
		"wing":
			var w := Air.deploy(c, String(_place["data"]), sid)
			if w == null:
				World.notify(tr("PLACE_INVALID"), "bad")
			else:
				Audio.play("select_air", 150)
				World.notify(tr("NOTE_WING_DEPLOYED") % [w.name, st.display_name()], "good")
		"ships":
			var port := 0
			for q in Navy.ports_of(c.tag):
				if World.province(q).state_id == sid:
					port = q
					if q == pid:
						break
			var f := Navy.deploy_ships(c, port)
			if f == null:
				World.notify(tr("PLACE_INVALID"), "bad")
			else:
				Audio.play("select_fleet", 150)
				World.notify(tr("NOTE_SHIPS_DEPLOYED") % [f.name, st.display_name()], "good")
	_end_place()

## Ctrl basılıyken seçili tümenlerin yürüme menzili haritada: 1 günde varılan bölgeler parlak yeşil, 3 günde orta,
## 7 günde soluk; öbürleri kararır. Birden çok tümen seçiliyse en yavaşınınki (birlikte yürürler). Günde bir yenilenir.
var _reach_sig := ""
func _update_reach() -> void:
	var want: bool = phase == Phase.PLAYING and Input.is_key_pressed(KEY_CTRL) and not units.selected.is_empty() \
		and _place.is_empty() and not hud.fullscreen_open() and not (hud.construction.visible and hud.construction.selected != "")
	var slow: Division = null
	if want:
		for d in units.selected:
			if d.owner == World.player_tag and d.training == 0 and (slow == null or float(Military.div_stats(d)["speed"]) < float(Military.div_stats(slow)["speed"])):
				slow = d
	var sig := "%d:%d:%d" % [slow.id, slow.province, World.day_count] if slow else ""
	if sig == _reach_sig:
		return
	_reach_sig = sig
	if slow == null:
		map_view.set_marked_provinces({})
		_update_construction_marks()
		return
	var hours := Military.reach_hours(slow, 168.0)
	var vals := {}
	for pid: int in hours:
		var h: float = hours[pid]
		vals[pid] = 255 if h <= 24.0 else (228 if h <= 72.0 else 204)
	map_view.set_marked_provinces(vals)

func _update_construction_marks() -> void:
	if not _place.is_empty():
		return
	if not hud.construction.visible or hud.construction.selected == "":
		map_view.set_marked_states({})
		return
	var c := World.player()
	var marks := {}
	for sid in c.states:
		marks[sid] = Economy.can_build(c, World.states[sid], hud.construction.selected) == ""
	map_view.set_marked_states(marks)

## Ülke seçimi: haritaya tıklayınca o bölgenin sahibi seçilir; kamera serbest.
func _setup_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var pid := _pick(mb.position)
			var owner := World.owner_of_province(pid)
			if OS.has_environment("SETUPDBG"):
				print("SETUPDBG click ", mb.position, " pid=", pid, " owner=", owner.tag if owner else "-")
			if owner and World.is_active(owner.tag):     # yalnız savaşa katılan ülkeler oynanır
				_select.select_from_map(owner.tag)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom_at(mb.position, 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom_at(mb.position, -1.0)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera.drag(mm.position - mm.relative, mm.position)
		var pid := _pick(mm.position)
		map_view.set_hovered(pid)
		hud.tooltip.show_province(pid, mm.position)

func _set_mode(m: int) -> void:
	_apply_mode(m)
	hud.map_modes.set_mode(m)

func _apply_mode(m: int) -> void:
	map_view.set_map_mode(m)
	routes.active = m == MapView3D.MapMode.ROUTES
	roads.active = m == MapView3D.MapMode.ROUTES
