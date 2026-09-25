class_name BattleAudio
extends Node3D
## 3D muharebe sesleri: kara muharebelerinde tüfek/makineli/top, deniz muharebelerinde gemi topu,
## hava çatışmalarında uçak geçişi. Kaynaklar dünya konumunda; kamera (dinleyici) yaklaştıkça duyulur,
## uzak zoom'da kendiliğinden susar (mesafe zayıflaması). Sesler tools/make_audio.py ile üretilir.

const POOL := 14
const MAX_DIST := 520.0        ## dünya birimi; bu mesafenin ötesinde ses yok
const TICK := 0.22

var map: MapView3D
var _players: Array[AudioStreamPlayer3D] = []
var _streams := {}
var _next := 0
var _acc := 0.0

func _ready() -> void:
	for n in ["rifle_crack", "mg_burst", "artillery_boom", "explosion", "naval_gun", "plane_flyby"]:
		_streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 70.0
		p.max_distance = MAX_DIST
		p.max_db = 0.0
		p.attenuation_filter_cutoff_hz = 4500.0
		add_child(p)
		_players.append(p)

func _process(delta: float) -> void:
	if not World.in_game or GameClock.paused:
		return
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var lp := cam.global_position
	var hear2 := MAX_DIST * MAX_DIST
	var budget := 3      # her tikte en çok 3 yeni ses
	# kara muharebeleri: yoğunluk = tümen sayısı; tüfek sık, makineli orta, top/patlama seyrek
	for pid: int in Military.battles:
		if budget <= 0:
			break
		var b: Dictionary = Military.battles[pid]
		var from := World.province(int(b["from"]))
		var to := World.province(pid)
		if from == null or to == null:
			continue
		var c: Vector2 = from.center.lerp(to.center, 0.5)
		var pos := Vector3(c.x, 0.0, c.y)
		if pos.distance_squared_to(lp) > hear2:
			continue
		var n: int = (b["attackers"] as Array).size() + (b["defenders"] as Array).size()
		var rate := clampf(0.35 + n * 0.12, 0.35, 1.2)
		if randf() < rate:
			var r := randf()
			var name := "rifle_crack" if r < 0.55 else ("mg_burst" if r < 0.82 else ("artillery_boom" if r < 0.95 else "explosion"))
			_emit(name, c, -6.0 if name == "rifle_crack" else -3.0)
			budget -= 1
	# deniz muharebeleri: gemi topu
	for pid: int in Navy.battles:
		if budget <= 0:
			break
		var nb: Dictionary = Navy.battles[pid]
		var c: Vector2 = nb["pos"]
		if Vector3(c.x, 0.0, c.y).distance_squared_to(lp) > hear2:
			continue
		if randf() < 0.45:
			_emit("naval_gun", c, 0.0)
			budget -= 1
	# hava çatışmaları: uçak geçişi
	for key: int in Air.fights:
		if budget <= 0:
			break
		var f: Dictionary = Air.fights[key]
		var c: Vector2 = f["pos"]
		if Vector3(c.x, 0.0, c.y).distance_squared_to(lp) > hear2:
			continue
		if randf() < 0.18:
			_emit("plane_flyby", c + Vector2(randf_range(-30, 30), randf_range(-30, 30)), -4.0, 14.0)
			budget -= 1

func _emit(name: String, c: Vector2, db: float, height: float = 1.5) -> void:
	var p := _players[_next]
	_next = (_next + 1) % POOL
	var y := (map.height_at(c) if map else 0.0) + height
	p.global_position = Vector3(c.x + randf_range(-6, 6), y, c.y + randf_range(-6, 6))
	p.stream = _streams[name]
	p.volume_db = db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
