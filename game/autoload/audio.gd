extends Node
## Ses: arayüz (çeşitlemeli tık, panel açma/kapama, sekme, anahtar, onay damgası, saat), oyuncunun eylemleri (inşaat,
## üretim, araştırma, odak, yasa, danışman, ticaret, diplomasi, konuşlandırma), birim seçimi ve emirler (telsiz),
## uyarılar ve müzik yönetmeni. Muharebe sesleri 3D olarak BattleAudio'da.
## Efektler: tools/make_audio.py (assets/audio/*.wav), müzik: tools/make_music.py (assets/audio/music/*.ogg).

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
}
## bildirim ve bitiş sesleri üst üste binmez: kuyruğa girer, biri bitince sıradaki çalar (aynı ses kuyrukta tekrarlanmaz)
const QUEUED := {"notify_good": true, "notify_bad": true, "event": true, "research_done": true, "focus_done": true,
	"production_done": true, "capitulation": true, "battle_start": true}
const QUEUE_GAP := 0.12
const QUEUE_MAX := 4
## müzik durumu -> parçalar (sırayla değil, tekrarsız rastgele)
const MUSIC := {
	"menu": ["main_theme"],
	"peace": ["peace_1", "peace_2", "main_theme"],
	"tension": ["tension", "peace_2"],
	"war_world": ["war_world", "tension"],
	"war_player": ["war_front", "war_hold"],
}
const TENSION_MUSIC := 40.0          ## dünya gerginliği bu değeri geçince gerginlik müziği
const FADE := 3.0
const POOL := 12

var _streams := {}                   ## ad -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var music_db := -14.0
var sfx_db := 0.0
var _last_hover_ms := 0
var _last_play := {}                 ## ad -> ms (aynı sesin art arda yığılmasını önler)
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
var _queue: Array = []               ## [[ad, extra_db], ...]
var _queue_free_ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: String in SOUNDS:
		var arr: Array[AudioStream] = []
		var count: int = SOUNDS[n][1]
		for i in count:
			var path := "res://assets/audio/%s.wav" % n if count == 1 else "res://assets/audio/%s_%d.wav" % [n, i + 1]
			if ResourceLoader.exists(path):
				arr.append(load(path))
		_streams[n] = arr
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_stinger = AudioStreamPlayer.new()
	add_child(_stinger)
	get_tree().node_added.connect(_on_node_added)
	World.notification.connect(_on_notification)
	Research.tech_completed.connect(func(tag: String, _id: String) -> void: if _mine(tag): play("research_done"))
	Politics.focus_completed.connect(func(tag: String, _id: String) -> void: if _mine(tag): play("focus_done"))
	Politics.event_fired.connect(func(tag: String, _id: String, _from: String) -> void: if _mine(tag): play("event"))
	Economy.building_completed.connect(func(tag: String, _sid: int, _b: String) -> void: if _mine(tag): play("production_done", 6000))
	Diplomacy.country_capitulated.connect(_on_capitulated)
	Diplomacy.wars_changed.connect(_on_wars_changed)
	Game.game_over.connect(func(victory: bool, _r: String) -> void: stinger("stinger_victory" if victory else "stinger_defeat"))
	GameClock.time_state_changed.connect(_on_time_state)
	World.player_changed.connect(func(_t: String) -> void: _snap.clear())
	World.game_started.connect(func() -> void:
		_snap.clear()
		_wars = _war_keys()
		_player_at_war = Diplomacy.at_war(World.player_tag))
	Military.battles_changed.connect(_on_battles)
	_update_music(true)

func _mine(tag: String) -> bool:
	return World.in_game and tag == World.player_tag

# ------------------------------------------------------------------ ses seviyeleri
func music_linear() -> float:
	return clampf(db_to_linear(music_db + 14.0), 0.0, 1.0)

func set_music_linear(v: float) -> void:
	music_db = linear_to_db(maxf(v, 0.001)) - 14.0
	_apply_music_volume()

func sfx_linear() -> float:
	return clampf(db_to_linear(sfx_db), 0.0, 1.0)

func set_sfx_linear(v: float) -> void:
	sfx_db = linear_to_db(maxf(v, 0.001))

# ------------------------------------------------------------------ efekt
## Ses çal (çeşitlemelerden rastgele biri). min_gap_ms: aynı ses bu süre içinde tekrar çalınmaz; extra_db: ek düzey
func play(n: String, min_gap_ms: int = 60, extra_db: float = 0.0) -> void:
	var arr: Array = _streams.get(n, [])
	if arr.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(n, -100000)) < min_gap_ms:
		return
	_last_play[n] = now
	if QUEUED.has(n):
		for q: Array in _queue:
			if q[0] == n:
				return
		if _queue.size() < QUEUE_MAX:
			_queue.append([n, extra_db])
		return
	_play_now(n, extra_db)

func _play_now(n: String, extra_db: float) -> float:
	var arr: Array = _streams.get(n, [])
	if arr.is_empty():
		return 0.0
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = arr[randi() % arr.size()]
	p.volume_db = float(SOUNDS[n][0]) + sfx_db + extra_db
	p.pitch_scale = randf_range(0.97, 1.03) if not QUEUED.has(n) else 1.0
	p.play()
	return p.stream.get_length()

func _pump_queue() -> void:
	if _queue.is_empty() or Time.get_ticks_msec() < _queue_free_ms:
		return
	var q: Array = _queue.pop_front()
	var length := _play_now(q[0], q[1])
	_queue_free_ms = Time.get_ticks_msec() + int((minf(length * 0.7, 1.2) + QUEUE_GAP) * 1000.0)   # yankı kuyruğu beklenmez

## Yan panel açıldı / kapandı: aynı karede başka panel açılırsa kapanma sesi çalınmaz (panel değiştirme tek ses)
func panel(opened: bool) -> void:
	if opened:
		_pending_close = false
		play("ui_open", 80)
	else:
		_pending_close = true

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func() -> void:
			if b is CheckButton or b is CheckBox:
				play("ui_toggle", 30)
			elif b is Button and (b as Button).theme_type_variation == "Tab":
				play("ui_tab", 30)
			else:
				play("ui_click", 30))
		b.mouse_entered.connect(func() -> void:
			var now := Time.get_ticks_msec()
			if now - _last_hover_ms > 60 and not b.disabled:
				_last_hover_ms = now
				play("ui_hover", 40))

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
	match kind:
		"bad":
			play("notify_bad", 400)
		"good":
			play("notify_good", 400)

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
	if _pending_close:
		_pending_close = false
		play("ui_close", 80)
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
		"queue": c.construction_queue.size(), "lines": c.production_lines.size(), "research": c.research_current.size(),
		"focus": c.focus_current, "laws": str(c.laws), "advisors": c.advisors.size(), "decisions": c.decisions_active.size(),
		"trade": trade, "diplo": c.justify_progress.size() + c.guarantees.size() + c.access.size(),
		"divs": Military.country_divisions(c.tag).size(),
	}
	if _snap.has("queue"):
		if cur["queue"] > _snap["queue"]: play("build_queued", 150)
		if cur["lines"] > _snap["lines"]: play("production_line", 150)
		if cur["research"] > _snap["research"]: play("research_start", 150)
		if cur["focus"] != "" and cur["focus"] != _snap["focus"]: play("focus_start", 150)
		if cur["laws"] != _snap["laws"] or cur["advisors"] > _snap["advisors"] or cur["decisions"] > _snap["decisions"]:
			play("ui_confirm", 150)
		if float(cur["trade"]) > float(_snap["trade"]): play("trade_deal", 150)
		if cur["diplo"] > _snap["diplo"]: play("diplomacy", 150)
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
	var list: Array = MUSIC.get(state, MUSIC["peace"])
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
