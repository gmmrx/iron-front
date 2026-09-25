extends Node
## Ses: arayüz tıklamaları (tüm düğmeler), bildirim/savaş sesleri, ortam müziği.

var _players := {}
var music: AudioStreamPlayer
var volume := 0.8

func _ready() -> void:
	for n in ["click", "notify", "war"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		p.volume_db = -8.0 if n == "click" else -4.0
		add_child(p)
		_players[n] = p
	music = AudioStreamPlayer.new()
	var st: AudioStreamWAV = load("res://assets/audio/ambient.wav")
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	music.stream = st
	music.volume_db = -14.0
	add_child(music)
	music.play()
	get_tree().node_added.connect(_on_node_added)
	World.notification.connect(func(_t: String, kind: String) -> void:
		if World.in_game:
			play("war" if kind == "war" and _t.contains("→") else "notify"))

func play(n: String) -> void:
	var p: AudioStreamPlayer = _players.get(n)
	if p:
		p.play()

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(func() -> void: play("click"))
