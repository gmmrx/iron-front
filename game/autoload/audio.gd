extends Node
## Ses: arayüz (tık, açılış/kapanış), birim seçimi ve emirler (telsiz), uyarılar (telgraf/daktilo),
## büyük olaylar (savaş ilanı, teslim, zafer), ortam müziği. Muharebe sesleri 3D olarak BattleAudio'da.
## Tüm sesler tools/make_audio.py ile üretilir (assets/audio/*.wav).

const SOUNDS := {
	# ad: ses düzeyi (dB)
	"ui_click": -10.0, "ui_hover": -22.0, "ui_open": -10.0, "ui_close": -12.0, "ui_tab": -12.0, "ui_error": -8.0,
	"select_unit": -8.0, "order_move": -7.0, "order_attack": -6.0, "select_fleet": -8.0, "select_air": -8.0,
	"alert": -7.0, "research_done": -6.0, "focus_done": -6.0, "event": -6.0, "production_done": -12.0,
	"capitulation": -3.0, "victory": -2.0, "war_declare": -2.0, "battle_start": -8.0,
}
const POOL := 10

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var music: AudioStreamPlayer
var music_db := -16.0
var sfx_db := 0.0
var _last_hover_ms := 0
var _last_play := {}                 ## ad -> ms (aynı sesin art arda yığılmasını önler)
var _known_battles := {}

func _ready() -> void:
	for n: String in SOUNDS:
		_streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	music = AudioStreamPlayer.new()
	var st: AudioStreamWAV = load("res://assets/audio/ambient.wav")
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	music.stream = st
	music.volume_db = music_db
	add_child(music)
	music.play()
	get_tree().node_added.connect(_on_node_added)
	World.notification.connect(_on_notification)
	Research.tech_completed.connect(func(tag: String, _id: String) -> void: if _mine(tag): play("research_done"))
	Politics.focus_completed.connect(func(tag: String, _id: String) -> void: if _mine(tag): play("focus_done"))
	Politics.event_fired.connect(func(tag: String, _id: String, _from: String) -> void: if _mine(tag): play("event"))
	Economy.building_completed.connect(func(tag: String, _sid: int, _b: String) -> void: if _mine(tag): play("production_done", 6000))
	Diplomacy.country_capitulated.connect(func(tag: String) -> void:
		if not World.in_game:
			return
		if tag == World.player_tag or Diplomacy.are_allies(tag, World.player_tag):
			play("capitulation")
		elif Diplomacy.are_enemies(tag, World.player_tag):
			play("victory")
		elif World.countries[tag].is_major():
			play("capitulation", 0, -8.0))
	Game.game_over.connect(func(victory: bool, _r: String) -> void: play("victory" if victory else "capitulation"))
	Military.battles_changed.connect(_on_battles)

func music_linear() -> float:
	return clampf(db_to_linear(music_db + 16.0), 0.0, 1.0)

func set_music_linear(v: float) -> void:
	music_db = linear_to_db(maxf(v, 0.001)) - 16.0
	music.volume_db = music_db

func sfx_linear() -> float:
	return clampf(db_to_linear(sfx_db), 0.0, 1.0)

func set_sfx_linear(v: float) -> void:
	sfx_db = linear_to_db(maxf(v, 0.001))

func _mine(tag: String) -> bool:
	return World.in_game and tag == World.player_tag

## Ses çal. min_gap_ms: aynı ses bu süre içinde tekrar çalınmaz; extra_db: ek düzey
func play(n: String, min_gap_ms: int = 60, extra_db: float = 0.0) -> void:
	if not _streams.has(n):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(n, -100000)) < min_gap_ms:
		return
	_last_play[n] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[n]
	p.volume_db = float(SOUNDS[n]) + sfx_db + extra_db
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()

func _on_notification(text: String, kind: String) -> void:
	if not World.in_game:
		return
	match kind:
		"war":
			play("war_declare" if text.contains("→") else "alert", 300)
		"bad":
			play("alert", 400)
		"good":
			play("alert", 400, -4.0)

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

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func() -> void: play("ui_click", 30))
		b.mouse_entered.connect(func() -> void:
			var now := Time.get_ticks_msec()
			if now - _last_hover_ms > 50 and not b.disabled:
				_last_hover_ms = now
				play("ui_hover", 40))
