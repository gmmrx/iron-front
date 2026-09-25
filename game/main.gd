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
var cities: CityLayer3D
var units: UnitLayer
var fleets: FleetLayer
var routes: RouteLayer
var _zone_pick: Fleet = null          ## "Bölge seç": sonraki tıklama filo görev bölgesi
var _wing_pick: AirWing = null        ## hava kanadı için bölge / üs seçimi
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
	World.daily_update.connect(map_view.update_season)
	map_view.update_season()
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
	hud = Hud.new()
	add_child(hud)
	hud.divisions.units = units
	hud.navy.fleet_selected.connect(func(f: Fleet) -> void:
		units.clear_selection()
		fleets.select(f)
		camera.focus_on(fleets.fleet_position(f), minf(camera.distance, 900.0)))
	hud.air.pick_zone_requested.connect(func(w: AirWing) -> void:
		_wing_pick = w
		World.notify(tr("AIR_CLICK_ZONE"), "info"))
	hud.navy.pick_zone_requested.connect(func(f: Fleet) -> void:
		_zone_pick = f
		World.notify(tr("NAVY_CLICK_ZONE"), "info"))
	hud.pause_menu.to_main_menu.connect(_back_to_menu)
	hud.pause_menu.load_requested.connect(_load_slot)
	hud.game_over.to_main_menu.connect(_back_to_menu)
	hud.game_over.continue_pressed.connect(func() -> void: pass)
	hud.map_modes.mode_selected.connect(func(m: int) -> void: _apply_mode(m))
	hud.construction.building_selected.connect(func(_b: String) -> void: _update_construction_marks())
	hud.construction_toggled.connect(func(_o: bool) -> void: _update_construction_marks())
	Economy.construction_changed.connect(func(_t: String) -> void: _update_construction_marks())
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 20
	add_child(_menu_layer)
	_handle_dev_args()
	if Game.loaded:
		Game.loaded = false
		_enter_playing(World.player_tag)
	elif phase == Phase.MENU:
		_enter_menu()

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
	_menu_layer.add_child(_menu)

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
	_select.select(World.player_tag)

func _start_game(tag: String) -> void:
	if tag == "":
		return
	_enter_playing(tag)
	World.notify(tr("NOTE_WELCOME") % World.player().display_name(), "good")

func _enter_playing(tag: String) -> void:
	_clear_menu_layer()
	map_view.set_highlight_country("")
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
	if args.has("load"):
		if Game.load_game(args["load"]):
			Game.loaded = false
			_enter_playing(World.player_tag)
	if args.has("play"):
		_start_game(args["play"] if args["play"] != "" else World.player_tag)
	elif args.has("setup"):
		_enter_setup()
	if args.has("focus"):
		var xy: PackedStringArray = args["focus"].split(",")
		camera.focus_on(Vector2(float(xy[0]), float(xy[1])))
	if args.has("dist"):
		camera.focus_on(Vector2(camera.target.x, camera.target.z), float(args["dist"]))
	if args.has("select"):
		World.select_province(int(args["select"]))
	if args.has("mode"):
		_set_mode(int(args["mode"]))
	if args.has("queue"):
		var c := World.player()
		var sids := c.states.duplicate()
		sids.sort_custom(func(a: int, b: int) -> bool: return World.states[a].population > World.states[b].population)
		for i in 4:
			Economy.queue_building(c, World.states[sids[i]], "civilian_factory" if i % 2 == 0 else "military_factory")
		Economy.queue_building(c, World.states[c.capital_state], "infrastructure")
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
			units.select_divisions(Military.army_divisions(ar).slice(0, 6), false)
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
		for i in 24 * 90:
			if not Military.battles.is_empty():
				break
			GameClock.advance_hours(1)
		if not Military.battles.is_empty():
			var pid: int = Military.battles.keys()[0]
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
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_msec()
		var proc := 0.0
		var n := 0
		while Time.get_ticks_msec() - t0 < secs * 1000.0:
			await get_tree().process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			n += 1
		var fps := (Engine.get_frames_drawn() - frames) / ((Time.get_ticks_msec() - t0) / 1000.0)
		print("FPS=%.1f process_ms=%.1f draw_calls=%d objects=%d nodes=%d date=%s" % [fps, proc / maxi(n, 1) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), GameClock.date_string()])
		for k in GameClock.prof: print("  %s %.2f s" % [k, GameClock.prof[k] / 1e6])
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
	if args.has("shots") and args.has("screenshot"):
		# film şeridi: N kare, her biri `every` kare arayla (hareket kalitesi incelemesi)
		var n := int(args["shots"])
		var every := int(args.get("every", "30"))
		var base: String = args["screenshot"].trim_suffix(".png")
		for k in n:
			for i in every:
				await get_tree().process_frame
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
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if hud.is_mouse_over_ui():
		hud.tooltip.visible = false
		map_view.set_hovered(0)

func _pick(screen: Vector2) -> int:
	var g = camera.ground_point(screen)
	return map_view.province_at(Vector2(g.x, g.z)) if g != null else 0

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.MENU:
		return
	if phase == Phase.SETUP:
		_setup_input(event)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var button := mb.button_index
		if button == MOUSE_BUTTON_LEFT and mb.ctrl_pressed:
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
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					if _zone_pick:
						_zone_pick = null
					elif fleets.selected and fleets.selected.owner == World.player_tag:
						_order_fleet(fleets.selected, _pick(mb.position))
					elif not units.selected.is_empty():
						_order_move(_pick(mb.position))
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
		var pid := _pick(mm.position)
		map_view.set_hovered(pid)
		var hf := fleets.pick(mm.position)
		var hr := _route_at(mm.position)
		if hf:
			hud.tooltip.show_fleet(hf, mm.position)
		elif not hr.is_empty():
			hud.tooltip.show_route(hr, mm.position)
		else:
			hud.tooltip.show_province(pid, mm.position)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		camera.zoom_at(mg.position, log(mg.factor) / log(MapCamera3D.ZOOM_STEP))
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		camera.drag(pg.position, pg.position - pg.delta * 12.0)
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
				elif _zone_pick or _wing_pick:
					_zone_pick = null
					_wing_pick = null
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
			KEY_T: hud.toggle_construction()
			KEY_Y: hud.toggle_production()
			KEY_Q: hud.toggle_politics()
			KEY_R: hud.toggle_trade()
			KEY_U: hud.toggle_army()
			KEY_N: hud.toggle_navy()
			KEY_H: hud.toggle_air()
			KEY_L: hud.toggle_logistics()
			KEY_I: hud.toggle_research()
			KEY_O: hud.toggle_diplomacy()
			KEY_F: hud.toggle_focus()
			KEY_F5: Game.save_game("hizli_kayit")

## Yollar modunda imlecin altındaki rota
func _route_at(screen: Vector2) -> Dictionary:
	if not routes.active:
		return {}
	var g = camera.ground_point(screen)
	return routes.pick(Vector2(g.x, g.z)) if g != null else {}

func _left_click(pos: Vector2, shift: bool) -> void:
	if routes.active and not _wing_pick and not _zone_pick:
		var r := _route_at(pos)
		routes.select(r)
		if not r.is_empty():
			hud.tooltip.show_route(r, pos)
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
	if hud.construction.visible and hud.construction.selected != "":
		_try_build(_pick(pos))
	else:
		World.select_province(_pick(pos))

## Seçili tümenlere hareket/saldırı emri
func _order_move(pid: int) -> void:
	var p := World.province(pid)
	if p == null or p.type == Province.Type.LAKE:
		return
	var ok := 0
	for d in units.selected:
		if Military.order_move(d, pid):
			ok += 1
	if ok == 0:
		World.notify(tr("NOTE_NO_PATH"), "bad")
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
func _update_construction_marks() -> void:
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
			if owner:
				_select.select(owner.tag)
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
