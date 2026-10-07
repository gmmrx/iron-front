extends Node
## Ses: harekât masası dünyası (1936–45 karargâhında haritanın başında durmak: pirinç iğne, keçe, kâğıt, deri dosya,
## daktilo, teleks, telgraf, sahra telefonu). Arayüz (çeşitlemeli şalter, dosya açma/kapama, fihrist, anahtar, damga, saat),
## oyuncunun eylemleri (inşaat, üretim, araştırma, odak, yasa, danışman, ticaret, diplomasi, konuşlandırma), birim seçimi ve
## emirler (ahşap sayaç, mantara iğne, hat tıkı), harita yapı rozetleri (üstüne gelince yapının uzaktan imzası),
## bildirimler (teleks, masa zili, kurye, şaryo, dosya, fabrika düdüğü) ve müzik yönetmeni. Muharebe sesleri 3D olarak
## BattleAudio'da.
## Efekt bankası: assets/audio/ww2/catalog.json; eski assets/audio/*.wav yedek olarak korunur.
## Müzik yönetmeni efekt bankasından bağımsızdır.

signal cue_requested(key: String) ## Yalnız kabul edilen istek; kuyrukta çalarken ikinci kez yayımlanmaz.

## ad: [dB, çeşitleme sayısı] — çeşitlemeler ad_1.wav, ad_2.wav... (1 ise tek dosya: ad.wav)
const SOUNDS := {
	"ui_click": [-11.0, 3], "ui_hover": [-24.0, 1], "ui_open": [-13.0, 2], "ui_close": [-14.0, 2], "ui_tab": [-12.0, 1],
	"ui_error": [-9.0, 1], "ui_confirm": [-8.0, 2], "ui_toggle": [-12.0, 1], "ui_speed": [-15.0, 1],
	"ui_pause": [-11.0, 1], "ui_resume": [-12.0, 1],
	"build_queued": [-10.0, 1], "production_line": [-10.0, 1], "research_start": [-11.0, 1], "focus_start": [-9.0, 1],
	"trade_deal": [-10.0, 1], "diplomacy": [-9.0, 1], "deploy": [-10.0, 1],
	"select_unit": [-9.0, 3], "order_move": [-8.0, 3], "order_attack": [-7.0, 2], "select_fleet": [-9.0, 2],
	"select_air": [-9.0, 2],
	"notify_good": [-11.0, 1], "notify_bad": [-10.0, 1], "event": [-9.0, 1], "research_done": [-10.0, 1],
	"focus_done": [-9.0, 1], "production_done": [-13.0, 1], "capitulation": [-8.0, 1], "battle_start": [-10.0, 2],
	# harita yapı rozetleri (üstüne gelince; kısık): iğne dokunuşu + yapının uzaktan imzası
	"map_civilian_factory": [-17.0, 1], "map_military_factory": [-17.0, 1], "map_synthetic_refinery": [-17.0, 1],
	"map_dockyard": [-17.0, 1], "map_naval_base": [-17.0, 1], "map_air_base": [-17.0, 1], "map_anti_air": [-17.0, 1],
	"map_infrastructure": [-17.0, 1],
}
## Haritada yapı rozetinin üstüne gelince: yapının kendi sesi (map_<yapı>.wav); dosyası yoksa yakın bir eylem sesi kısık
## çalar. Ses listesi ve üretim tarifi: docs/art/SOUND_PROMPTS.md (yerel).
const MAP_FALLBACK := {"civilian_factory": "build_queued", "military_factory": "production_line",
	"synthetic_refinery": "production_line", "dockyard": "select_fleet", "naval_base": "select_fleet",
	"air_base": "select_air", "anti_air": "order_attack", "infrastructure": "build_queued"}
const MAP_FALLBACK_DB := -9.0
## bildirim ve bitiş sesleri üst üste binmez: kuyruğa girer, biri bitince sıradaki çalar (aynı ses kuyrukta tekrarlanmaz)
const QUEUED := {"notify_good": true, "notify_bad": true, "event": true, "research_done": true, "focus_done": true,
	"production_done": true, "capitulation": true, "battle_start": true}
const QUEUE_GAP := 0.12
const QUEUE_MAX := 8
const CATALOG_PATH := "res://assets/audio/ww2/catalog.json"
const STREAM_CACHE_MAX := 48
const BURST_MAX := 8
const BURST_WINDOW_MS := 200
const LEGACY_ALIASES := {
	"menu_hover": "ui_hover", "menu_click": "ui_click", "menu_open": "ui_open", "menu_close": "ui_close",
	"menu_confirm": "ui_confirm", "menu_tab": "ui_tab", "menu_new_game": "ui_confirm", "menu_tutorial": "ui_open",
	"menu_continue": "ui_confirm", "menu_settings": "ui_open", "menu_quit": "ui_close", "country_select": "ui_click",
	"game_start": "ui_confirm", "unit_deselect": "ui_close", "select_infantry": "select_unit", "select_armor": "select_unit",
	"select_artillery": "select_unit", "select_motorized": "select_unit", "order_stop": "ui_confirm", "order_retreat": "order_move",
	"notification_open": "ui_open", "notify_info": "event", "notify_warning": "notify_bad", "notify_urgent": "notify_bad",
	"war_declare": "battle_start", "war_declared_on": "notify_bad", "war_world": "battle_start", "peace_signed": "notify_good",
	"alliance_formed": "diplomacy", "guarantee_issued": "diplomacy", "access_granted": "diplomacy",
	"diplomacy_rejected": "ui_error", "war_justification": "diplomacy", "law_change": "ui_confirm",
	"advisor_hire": "ui_confirm", "advisor_dismiss": "ui_close", "decision_take": "ui_confirm", "government_change": "event",
}
## müzik durumu -> parçalar (sırayla değil, tekrarsız rastgele)
const MUSIC := {
	"menu": ["main_theme"],
	"peace": ["peace_1", "peace_2", "main_theme"],
	"tension": ["tension", "peace_2"],
	"war_world": ["war_world", "tension", "march"],
	"war_player": ["war_front", "war_hold"],
}
const TENSION_MUSIC := 40.0          ## dünya gerginliği bu değeri geçince gerginlik müziği
const FADE := 3.0
const POOL := 12

var test_mode := false               ## Testlerde gerçek aygıta ses göndermeden kabul sözleşmesini gözle.
var _catalog := {}
var _catalog_loaded := false
var _stream_cache := {}             ## dosya -> AudioStream; bütün bankayı RAM'e yükleme.
var _stream_lru: Array[String] = []
var _last_variant := {}             ## mantıksal ad -> son dosya
var _rng := RandomNumberGenerator.new() ## Efektler oyun/müzik RNG dizisini değiştirmez.
var _pool: Array[AudioStreamPlayer] = []
var _notice_player: AudioStreamPlayer
var _next := 0
var music_db := -14.0
var sfx_db := 0.0
var ui_db := 0.0                     ## arayüz sesleri (tık, panel, sekme...) için ayrı düzey
var forced_track := ""               ## Ayarlar'dan seçilen parça ("" = oyun durumuna göre)
var _last_hover_ms := -100000
var _last_play := {}                 ## ad -> ms (aynı sesin art arda yığılmasını önler)
var _last_category := {}
var _burst_times: Array[int] = []
var _semantic_frame := -1
var _explicit_ui_frame := -1
var _pending_notifications: Array = []
var _notification_flush_pending := false
var _pending_panel := {}
var _panel_flush_pending := false
var _pending_generic_ui: Array = []
var _generic_ui_flush_pending := false
var _known_battles := {}

# --- müzik yönetmeni
var _music: Array[AudioStreamPlayer] = []   ## çapraz kararma için iki çalar
var _active := 0
var _stinger: AudioStreamPlayer
var _music_streams := {}
var _state := ""
var _track := ""
var _gap := 0.0
var _duck := 0.0                     ## olay müziği çalarken müzik kısılır (dB)
var _pending_state := ""            ## olay müziği bitince geçilecek durum
var _check := 0.0

# --- oyuncu eylemi izleme
var _snap := {}
var _snap_timer := 0.0
var _wars := {}
var _player_at_war := false
var _pending_close := false
var _queue: Array = []               ## [{key, extra_db, priority}, ...]
var _queue_free_ms := 0
var _notice_key := ""
var _notice_priority := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for bus: String in ["UI", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		p.finished.connect(func() -> void: p.stream = null)
	_notice_player = AudioStreamPlayer.new()
	_notice_player.bus = "SFX"
	add_child(_notice_player)
	_notice_player.finished.connect(func() -> void: _notice_player.stream = null)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_stinger = AudioStreamPlayer.new()
	add_child(_stinger)
	get_tree().node_added.connect(_on_node_added)
	World.notification.connect(_on_notification)
	World.world_logged.connect(_on_world_logged)
	Research.research_started.connect(func(tag: String, id: String) -> void: if _mine(tag): _research_event(id, "start"))
	Research.research_cancelled.connect(func(tag: String, id: String) -> void: if _mine(tag): _research_event(id, "cancel"))
	Research.tech_completed.connect(func(tag: String, id: String) -> void: if _mine(tag): _research_event(id, "done"))
	Politics.focus_completed.connect(func(tag: String, _id: String) -> void: if _mine(tag): play("focus_done"))
	Politics.event_fired.connect(func(tag: String, _id: String, _from: String) -> void: if _mine(tag): _semantic_cue("event"))
	Politics.advisor_hired.connect(func(tag: String, _id: String) -> void: if _mine(tag): _semantic_cue("advisor_hire"))
	Politics.advisor_dismissed.connect(func(tag: String, _id: String) -> void: if _mine(tag): _semantic_cue("advisor_dismiss"))
	Politics.decision_taken.connect(func(tag: String, _id: String) -> void: if _mine(tag): _semantic_cue("decision_take"))
	Economy.law_changed.connect(func(tag: String, _id: String) -> void: if _mine(tag): _semantic_cue("law_change"))
	Diplomacy.action_completed.connect(func(actor: String, kind: String, _target: String) -> void:
		if _mine(actor) and kind in ["war_justification", "access_granted"]: _semantic_cue(kind))
	Economy.building_completed.connect(func(tag: String, _sid: int, _b: String) -> void: if _mine(tag): play("production_done", 6000))
	Diplomacy.country_capitulated.connect(_on_capitulated)
	Diplomacy.wars_changed.connect(_on_wars_changed)
	Game.game_over.connect(func(victory: bool, _r: String) -> void: stinger("stinger_victory" if victory else "stinger_defeat"))
	GameClock.time_state_changed.connect(_on_time_state)
	World.player_changed.connect(func(_t: String) -> void:
		_snap.clear()
		reset_effect_state())
	World.game_started.connect(func() -> void:
		_snap.clear()
		reset_effect_state()
		_wars = _war_keys()
		_player_at_war = Diplomacy.at_war(World.player_tag))
	Military.battles_changed.connect(_on_battles)
	GameSettings.load_and_apply()          # ses düzeyleri, seçili parça, dil (arayüz kurulmadan önce)
	_update_music(true)

func _mine(tag: String) -> bool:
	return World.in_game and tag == World.player_tag

# ------------------------------------------------------------------ ses seviyeleri
func music_linear() -> float:
	return clampf(db_to_linear(music_db + 14.0), 0.0, 1.0)

func set_music_linear(v: float) -> void:
	music_db = linear_to_db(maxf(v, 0.001)) - 14.0
	_apply_music_volume()

func ui_linear() -> float:
	if ui_db <= -59.9: return 0.0
	return clampf(db_to_linear(ui_db), 0.0, 1.0)

func set_ui_linear(v: float) -> void:
	ui_db = linear_to_db(maxf(v, 0.001))
	_refresh_effect_levels()

## Seçili parçayı sürekli çal ("" = oyun durumuna göre otomatik)
func set_forced_track(name: String) -> void:
	if name == forced_track and (name == "" or _track == name):
		return
	forced_track = name
	if is_node_ready():               # açılışta _ready kendisi başlatır
		_update_music(true)

func sfx_linear() -> float:
	if sfx_db <= -59.9: return 0.0
	return clampf(db_to_linear(sfx_db), 0.0, 1.0)

func set_sfx_linear(v: float) -> void:
	sfx_db = linear_to_db(maxf(v, 0.001))
	_refresh_effect_levels()

func _refresh_effect_levels() -> void:
	# Bus mute also silences already-running 3D voices; gain remains per player.
	for bus: String in ["UI", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0: AudioServer.set_bus_mute(index, sfx_linear() <= 0.001 or (bus == "UI" and ui_linear() <= 0.001))
	var players: Array[AudioStreamPlayer] = _pool.duplicate()
	if _notice_player: players.append(_notice_player)
	for player: AudioStreamPlayer in players:
		var ui := bool(player.get_meta("audio_ui", false))
		if sfx_linear() <= 0.001 or (ui and ui_linear() <= 0.001):
			player.stop()
			player.stream = null
		else:
			player.volume_db = float(player.get_meta("audio_gain", -11.0)) + sfx_db + (ui_db if ui else 0.0)
	_queue = _queue.filter(func(request: Dictionary) -> bool: return not _effect_muted(_definition(request["key"])))
	if _notice_key != "" and _effect_muted(_definition(_notice_key)):
		_notice_key = ""
		_notice_priority = -1
		_queue_free_ms = 0

# ------------------------------------------------------------------ efekt
func _ensure_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if value is Dictionary and int(value.get("version", 0)) == 2 and value.get("sounds") is Dictionary:
		_catalog = value

func _definition(n: String) -> Dictionary:
	_ensure_catalog()
	var sounds: Dictionary = _catalog.get("sounds", {})
	if sounds.get(n) is Dictionary:
		return sounds[n]
	return _legacy_definition(n)

func _legacy_definition(n: String) -> Dictionary:
	var legacy := str(LEGACY_ALIASES.get(n, n))
	if not SOUNDS.has(legacy):
		return {}
	var files: Array[String] = []
	var count: int = SOUNDS[legacy][1]
	for i in count:
		files.append("res://assets/audio/%s.wav" % legacy if count == 1 else "res://assets/audio/%s_%d.wav" % [legacy, i + 1])
	var ui := n.begins_with("ui_") or n.begins_with("menu_") or n.begins_with("map_") or n in ["country_select", "notification_open"]
	return {"files": files, "gain_db": SOUNDS[legacy][0], "bus": "ui" if ui else "sfx",
		"priority": 2 if QUEUED.has(legacy) else 0, "queue": QUEUED.has(legacy), "cooldown_ms": 60}

func _cached_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		_stream_lru.erase(path)
		_stream_lru.append(path)
		return _stream_cache[path]
	if not ResourceLoader.exists(path, "AudioStream"):
		return null
	var stream := ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
	if stream == null:
		return null
	_stream_cache[path] = stream
	_stream_lru.append(path)
	while _stream_lru.size() > STREAM_CACHE_MAX:
		_stream_cache.erase(_stream_lru.pop_front())
	return stream

## 3D ses katmanı da aynı bankayı kullanır; burada 2D çalma/istek/cooldown yoktur.
func effect_stream(key: String) -> AudioStream:
	var definition := _definition(key)
	var files: Array = definition.get("files", [])
	var stream := _variant_stream(key, files)
	if stream: return stream
	var legacy: Array = _legacy_definition(key).get("files", [])
	return _variant_stream(key, legacy) if legacy != files else null

func _variant_stream(key: String, files: Array) -> AudioStream:
	if files.is_empty():
		return null
	var candidates: Array[String] = []
	for value: Variant in files:
		var path := str(value)
		if files.size() == 1 or path != str(_last_variant.get(key, "")):
			candidates.append(path)
	while not candidates.is_empty():
		var index := _rng.randi_range(0, candidates.size() - 1)
		var path := candidates[index]
		candidates.remove_at(index)
		var candidate := _cached_stream(path)
		if candidate:
			_last_variant[key] = path
			return candidate
	# A damaged/missing variant must not silence a still-available previous file.
	return _cached_stream(str(_last_variant[key])) if _last_variant.has(key) else null

func _has_stream(definition: Dictionary, key: String = "") -> bool:
	for path: Variant in definition.get("files", []):
		if _cached_stream(str(path)) != null: return true
	if key != "":
		for path: Variant in _legacy_definition(key).get("files", []):
			if _cached_stream(str(path)) != null: return true
	return false

func _category(n: String) -> String:
	if n.ends_with("hover") or n.begins_with("map_"): return "hover"
	if n.begins_with("select_") or n in ["unit_deselect", "country_select"]: return "selection"
	if n in ["ui_click", "menu_click", "ui_tab", "menu_tab", "ui_toggle"]: return "click"
	return ""

func _effect_muted(definition: Dictionary) -> bool:
	return sfx_linear() <= 0.001 or (str(definition.get("bus", "sfx")) == "ui" and ui_linear() <= 0.001)

## -1 = katalog cooldown; açık 0, ad cooldown'unu atlar. Hover/toplam patlama limitleri daima geçerlidir.
func play(n: String, min_gap_ms: int = -1, extra_db: float = 0.0) -> void:
	var definition := _definition(n)
	if definition.is_empty() or _effect_muted(definition):
		return
	var now := Time.get_ticks_msec()
	var gap := int(definition.get("cooldown_ms", 60)) if min_gap_ms < 0 else min_gap_ms
	if now - int(_last_play.get(n, -100000)) < gap:
		return
	var category := _category(n)
	var category_gap := 120 if category == "hover" else (60 if category == "selection" else 35)
	if category != "" and now - int(_last_category.get(category, -100000)) < category_gap:
		return
	var queued := bool(definition.get("queue", false))
	var priority := clampi(int(definition.get("priority", 0)), 0, 3)
	while not _burst_times.is_empty() and now - _burst_times[0] >= BURST_WINDOW_MS:
		_burst_times.pop_front()
	if not queued and _burst_times.size() >= BURST_MAX:
		return
	if not test_mode and not _has_stream(definition, n): return
	if queued:
		if n == _notice_key and now < _queue_free_ms:
			return
		for q: Dictionary in _queue:
			if q["key"] == n: return
		if _queue.size() >= QUEUE_MAX:
			var lowest := _queue.size() - 1
			if priority <= int(_queue[lowest]["priority"]): return
			_queue.remove_at(lowest)
	_last_play[n] = now
	if category != "": _last_category[category] = now
	if category == "hover": _last_hover_ms = now
	if queued:
		var request := {"key": n, "extra_db": extra_db, "priority": priority}
		var insert_at := _queue.size()
		for i in _queue.size():
			if priority > int(_queue[i]["priority"]):
				insert_at = i
				break
		_queue.insert(insert_at, request)
		if priority > _notice_priority and _notice_key != "":
			_notice_player.stop()
			_notice_player.stream = null
			_notice_key = ""
			_notice_priority = -1
			_queue_free_ms = 0
	else:
		_burst_times.append(now)
		_play_now(n, extra_db)
	cue_requested.emit(n)

## Harita yapı rozeti sesi (aynı ses 250 ms içinde yinelenmez: fare rozetler üstünde gezinirken yığılmasın)
func hover_building(building: String) -> void:
	var n := "map_" + building
	if not _definition(n).is_empty() and (test_mode or _has_stream(_definition(n), n)):
		play(n, 250)
	elif MAP_FALLBACK.has(building):
		play(String(MAP_FALLBACK[building]), 250, MAP_FALLBACK_DB)

func _play_now(n: String, extra_db: float, notice: bool = false) -> float:
	var definition := _definition(n)
	if definition.is_empty() or _effect_muted(definition): return 0.0
	var stream := effect_stream(n)
	if stream == null:
		return 0.0
	var ui := str(definition.get("bus", "sfx")) == "ui"
	var p := _notice_player if notice else _pool[_next]
	if not notice: _next = (_next + 1) % POOL
	p.stop()
	p.stream = stream
	p.bus = "UI" if ui else "SFX"
	p.set_meta("audio_ui", ui)
	p.set_meta("audio_gain", float(definition.get("gain_db", -11.0)) + extra_db)
	p.volume_db = float(p.get_meta("audio_gain")) + sfx_db + (ui_db if ui else 0.0)
	p.pitch_scale = 1.0 if notice else _rng.randf_range(0.985, 1.015)
	if not test_mode: p.play()
	var length := stream.get_length()
	if test_mode: p.stream = null
	return length

func _pump_queue() -> void:
	var now := Time.get_ticks_msec()
	if now < _queue_free_ms:
		return
	_notice_key = ""
	_notice_priority = -1
	if _queue.is_empty(): return
	var q: Dictionary = _queue.pop_front()
	_notice_key = q["key"]
	_notice_priority = int(q["priority"])
	var length := _play_now(q["key"], q["extra_db"], true)
	_queue_free_ms = now + int((maxf(length, 0.15) + QUEUE_GAP) * 1000.0)

## Yan panel açıldı / kapandı: aynı karede başka panel açılırsa kapanma sesi çalınmaz (panel değiştirme tek ses)
func panel(opened: bool) -> void:
	var frame := Engine.get_process_frames()
	if not opened and not _pending_panel.is_empty() and _pending_panel.get("frame") == frame and bool(_pending_panel.get("opened")):
		return
	_pending_panel = {"opened": opened, "frame": frame, "in_game": World.in_game}
	if not _panel_flush_pending:
		_panel_flush_pending = true
		_flush_panel.call_deferred()

func _flush_panel() -> void:
	_panel_flush_pending = false
	if _pending_panel.is_empty(): return
	var request := _pending_panel
	_pending_panel = {}
	if int(request["frame"]) == _explicit_ui_frame: return
	var prefix := "ui_" if bool(request["in_game"]) else "menu_"
	play(prefix + ("open" if bool(request["opened"]) else "close"), 80)

func ui_bind(button: BaseButton, key: String, hover_key: String = "") -> void:
	button.set_meta("audio_cue", key)
	if hover_key != "": button.set_meta("audio_hover", hover_key)
	_hook_button(button)

func _defer_generic_ui(key: String) -> void:
	if _pending_generic_ui.size() < BURST_MAX:
		_pending_generic_ui.append({"key": key, "frame": Engine.get_process_frames()})
	if not _generic_ui_flush_pending:
		_generic_ui_flush_pending = true
		_flush_generic_ui.call_deferred()

func _flush_generic_ui() -> void:
	_generic_ui_flush_pending = false
	var pending := _pending_generic_ui
	_pending_generic_ui = []
	for request: Dictionary in pending:
		if int(request["frame"]) != _semantic_frame and int(request["frame"]) != _explicit_ui_frame:
			play(request["key"], 30)

func _hook_button(b: BaseButton) -> void:
	if bool(b.get_meta("audio_hooked", false)): return
	b.set_meta("audio_hooked", true)
	var reference: WeakRef = weakref(b)
	b.pressed.connect(func() -> void:
		var button := reference.get_ref() as BaseButton
		if not is_instance_valid(button) or button.disabled or bool(button.get_meta("audio_silent", false)): return
		var key := str(button.get_meta("audio_cue", ""))
		if key != "":
			_explicit_ui_frame = Engine.get_process_frames()
			play(key)
		elif button is CheckButton or button is CheckBox:
			_defer_generic_ui("ui_toggle")
		elif button is Button and (button as Button).theme_type_variation == "Tab":
			_defer_generic_ui("ui_tab" if World.in_game else "menu_tab")
		else:
			_defer_generic_ui("ui_click" if World.in_game else "menu_click"))
	b.mouse_entered.connect(func() -> void:
		var button := reference.get_ref() as BaseButton
		if not is_instance_valid(button) or button.disabled or bool(button.get_meta("audio_silent", false)): return
		var key := str(button.get_meta("audio_hover", ""))
		play(key if key != "" else ("ui_hover" if World.in_game else "menu_hover")))

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_hook_button(n as BaseButton)

func _on_time_state(speed: int, paused: bool) -> void:
	if not World.in_game:
		return
	if paused != bool(_snap.get("paused", true)):
		play("ui_pause" if paused else "ui_resume", 120)
	elif int(_snap.get("speed", speed)) != speed:
		play("ui_speed", 60)
	_snap["paused"] = paused
	_snap["speed"] = speed

func _on_notification(_text: String, kind: String) -> void:
	if not World.in_game:
		return
	var key: String = {"good": "notify_good", "bad": "notify_bad", "warn": "notify_warning",
		"warning": "notify_warning", "urgent": "notify_urgent", "info": "notify_info", "war": "notify_urgent"}.get(kind, "")
	if key == "": return
	if _pending_notifications.size() < 16:
		_pending_notifications.append({"key": key, "frame": Engine.get_process_frames()})
	if not _notification_flush_pending:
		_notification_flush_pending = true
		_flush_notifications.call_deferred()

func _flush_notifications() -> void:
	_notification_flush_pending = false
	var pending := _pending_notifications
	_pending_notifications = []
	for note: Dictionary in pending:
		# Handles both notify-before-world_logged and success-before-notify order.
		if int(note["frame"]) != _semantic_frame: play(note["key"])

func _semantic_cue(key: String) -> void:
	_semantic_frame = Engine.get_process_frames()
	play(key)

func _research_event(id: String, phase: String) -> void:
	_semantic_frame = Engine.get_process_frames()
	research_cue(id, phase)

func research_key(id: String, phase: String) -> String:
	if phase not in ["select", "start", "done", "cancel"]: return ""
	_ensure_catalog()
	var exact: Dictionary = _catalog.get("research", {}).get(id, {})
	var key := str(exact.get(phase, ""))
	if key != "" and not _definition(key).is_empty(): return key
	var category := ""
	if Research.techs.has(id):
		category = str(Research.techs[id].get("cat", ""))
	else:
		var repeat := Research.parse_repeat(id)
		if not repeat.is_empty(): category = str(repeat[0])
	var fallback: Dictionary = _catalog.get("research_categories", {}).get(category, {})
	key = str(fallback.get(phase, ""))
	if key != "" and not _definition(key).is_empty(): return key
	return str({"select": "ui_click", "start": "research_start", "done": "research_done", "cancel": "ui_close"}[phase])

func research_cue(id: String, phase: String) -> void:
	var key := research_key(id, phase)
	if key != "": play(key)

func unit_selection(divs: Array) -> void:
	for value: Variant in divs:
		if not value is Division: continue
		var d := value as Division
		var c: Country = World.countries.get(d.owner)
		if c == null or d.template < 0 or d.template >= c.templates.size(): continue
		var kinds: Dictionary = c.templates[d.template].get("battalions", {})
		var armor := false
		var motorized := false
		var artillery_count := 0.0
		var infantry_count := 0.0
		for type: String in kinds:
			if float(kinds[type]) <= 0.0: continue
			var category := str(Military.battalions.get(type, {}).get("category", ""))
			armor = armor or category == "armor" or type.contains("armor") or (type.contains("tank") and not type.begins_with("anti_"))
			motorized = motorized or type.contains("motor") or type.contains("mechanized")
			if category == "artillery" or type.contains("artillery"): artillery_count += float(kinds[type])
			elif category == "infantry" or type == "infantry": infantry_count += float(kinds[type])
		play("select_armor" if armor else ("select_motorized" if motorized else ("select_artillery" if artillery_count > infantry_count else "select_infantry")))
		return
	if not divs.is_empty(): play("select_unit")

func _on_world_logged(entry: Dictionary) -> void:
	if not World.in_game: return
	var tags: Array = entry.get("tags", [])
	if not World._feed_worthy(str(entry.get("kind", "")), tags): return
	var cue := ""
	match str(entry.get("key", "")):
		"NOTE_WAR_DECLARED":
			cue = "war_declare" if not tags.is_empty() and str(tags[0]) == World.player_tag else ("war_declared_on" if World.player_tag in tags else "war_world")
		"NOTE_WHITE_PEACE", "NOTE_WAR_ENDED_OF": cue = "peace_signed"
		"NOTE_JOINS_FACTION": cue = "alliance_formed"
		"NOTE_GUARANTEE": cue = "guarantee_issued"
		"NOTE_CAPITULATED": cue = "capitulation"
	if cue != "": _semantic_cue(cue)

## Yalnız efektlerin geçici durumunu temizler; müzik seçimi/çalarları/ayarları değişmez.
func reset_effect_state() -> void:
	_last_play.clear()
	_last_category.clear()
	_last_hover_ms = -100000
	_burst_times.clear()
	_queue.clear()
	_queue_free_ms = 0
	_notice_key = ""
	_notice_priority = -1
	_pending_notifications.clear()
	_pending_panel.clear()
	_pending_generic_ui.clear()
	_pending_close = false
	_semantic_frame = -1
	_explicit_ui_frame = -1
	for player: AudioStreamPlayer in _pool:
		player.stop()
		player.stream = null
	if _notice_player:
		_notice_player.stop()
		_notice_player.stream = null

## Oyuncunun tümenlerinin karıştığı yeni bir kara muharebesi: uzak topçu
func _on_battles() -> void:
	if not World.in_game:
		return
	var seen := {}
	for pid: int in Military.battles:
		seen[pid] = true
		if _known_battles.has(pid):
			continue
		var b: Dictionary = Military.battles[pid]
		var mine := false
		for d: Division in b["attackers"] + b["defenders"]:
			if d.owner == World.player_tag:
				mine = true
				break
		if mine:
			play("battle_start", 4000)
	_known_battles = seen

func _on_capitulated(tag: String) -> void:
	if not World.in_game:
		return
	if tag == World.player_tag or Diplomacy.are_allies(tag, World.player_tag):
		stinger("stinger_defeat")
	elif Diplomacy.are_enemies(tag, World.player_tag):
		stinger("stinger_victory")
	elif World.countries[tag].is_major():
		play("capitulation", 0, -4.0)

## Savaşlar değişti: oyuncunun yeni savaşı başka, dünyadaki yeni büyük savaş başka müzikle duyurulur; oyuncunun
## savaşı teslim olmadan biterse barış müziği
func _war_keys() -> Dictionary:
	var out := {}
	for w: Dictionary in Diplomacy.wars:
		out["%s>%s" % [w["attackers"][0], w["defenders"][0]]] = w
	return out

func _on_wars_changed() -> void:
	if not World.in_game:
		_wars = _war_keys()
		return
	var now := _war_keys()
	var player_new := false
	var world_new := false
	for k: String in now:
		if _wars.has(k):
			continue
		var w: Dictionary = now[k]
		if World.player_tag in w["attackers"] or World.player_tag in w["defenders"]:
			player_new = true
		else:
			for t: String in w["attackers"] + w["defenders"]:
				var c: Country = World.countries.get(t)
				if c and c.is_major():
					world_new = true
	_wars = now
	var at_war := Diplomacy.at_war(World.player_tag)
	if player_new:
		stinger("stinger_war_player")
	elif world_new:
		stinger("stinger_war_world")
	elif _player_at_war and not at_war and not World.player().capitulated:
		stinger("stinger_peace")
	_player_at_war = at_war
	_update_music()

# ------------------------------------------------------------------ oyuncu eylemleri
func _process(delta: float) -> void:
	_pump_queue()
	_snap_timer -= delta
	if _snap_timer <= 0.0:
		_snap_timer = 0.2
		_watch_player()
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update_music()
	_music_tick(delta)

func _watch_player() -> void:
	var c := World.player()
	if not World.in_game or c == null:
		return
	var trade := 0.0
	for o: Dictionary in c.trade_orders:
		trade += float(o["amount"])
	var cur := {
		"queue": c.construction_queue.size(), "lines": c.production_lines.size(), "focus": c.focus_current,
		"trade": trade,
		"divs": Military.country_divisions(c.tag).size(),
	}
	if _snap.has("queue"):
		if cur["queue"] > _snap["queue"]: play("build_queued", 150)
		if cur["lines"] > _snap["lines"]: play("production_line", 150)
		if cur["focus"] != "" and cur["focus"] != _snap["focus"]: play("focus_start", 150)
		if float(cur["trade"]) > float(_snap["trade"]): play("trade_deal", 150)
		if cur["divs"] > _snap["divs"]: play("deploy", 300)
	for k: String in cur:
		_snap[k] = cur[k]

# ------------------------------------------------------------------ müzik yönetmeni
func _music_stream(name: String) -> AudioStream:
	if not _music_streams.has(name):
		var path := "res://assets/audio/music/%s.ogg" % name
		_music_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _music_streams[name]

func _desired_state() -> String:
	if forced_track != "":
		return "forced"
	if not World.in_game:
		return "menu"
	if Diplomacy.at_war(World.player_tag):
		return "war_player"
	if not Diplomacy.wars.is_empty():
		return "war_world"
	if World.world_tension >= TENSION_MUSIC:
		return "tension"
	return "peace"

func _update_music(force := false) -> void:
	var want := _desired_state()
	if want == _state and not force:
		return
	_state = want
	if _stinger.playing:
		_pending_state = want       # olay müziği bitince geçilir
		return
	_start_track(_pick(want), FADE if not force else 1.0)

func _pick(state: String) -> String:
	var list: Array = [forced_track] if state == "forced" else MUSIC.get(state, MUSIC["peace"])
	var options := list.filter(func(n: String) -> bool: return n != _track)
	if options.is_empty():
		options = list
	return options[randi() % options.size()]

func _start_track(name: String, fade: float) -> void:
	var st := _music_stream(name)
	if st == null:
		return
	var old := _music[_active]
	_active = 1 - _active
	var nu := _music[_active]
	_track = name
	nu.stream = st
	nu.volume_db = -60.0
	nu.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nu, "volume_db", music_db + _duck, fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.chain().tween_callback(old.stop)
	_gap = 0.0

func _music_tick(delta: float) -> void:
	if _stinger.playing:
		return
	if _pending_state != "":
		# olay müziği sırasında durum değişti (ör. oyuncu savaşa girdi): yeni durumun parçası
		var s := _pending_state
		_pending_state = ""
		_duck = 0.0
		_start_track(_pick(s), 2.0)
		return
	if _duck < 0.0:
		_duck = 0.0
		_apply_music_volume(2.0)
	var cur := _music[_active]
	if not cur.playing and _track != "":
		# parça bitti: kısa bir sessizlikten sonra aynı durumdan başka bir parça
		_gap += delta
		if _gap > randf_range(3.0, 6.0):
			_start_track(_pick(_state), 2.5)

## Olay müziği: müziği kısar, bitince müzik geri gelir (gerekirse yeni duruma geçer)
func stinger(name: String) -> void:
	var st := _music_stream(name)
	if st == null:
		return
	_stinger.stream = st
	_stinger.volume_db = music_db + 4.0
	_stinger.play()
	_duck = -18.0
	_apply_music_volume(0.6)

func _apply_music_volume(fade: float = 0.3) -> void:
	var cur := _music[_active]
	if cur.playing:
		var tw := create_tween()
		tw.tween_property(cur, "volume_db", music_db + _duck, fade)
	if _stinger.playing:
		_stinger.volume_db = music_db + 4.0
