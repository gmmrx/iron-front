extends "res://tests/test_case.gd"
## Production playback paths, not only the test-mode cue spy. Headless uses Godot's dummy driver.

func _begin_audio() -> Array:
	var previous := [Audio.test_mode, Audio.sfx_db, Audio.ui_db, Audio.music_db]
	Audio.test_mode = false
	Audio.sfx_db = 0.0
	Audio.ui_db = 0.0
	Audio.music_db = -80.0
	Audio._refresh_effect_levels()
	Audio.reset_effect_state()
	return previous

func _end_audio(previous: Array) -> void:
	Audio.reset_effect_state()
	Audio.test_mode = previous[0]
	Audio.sfx_db = previous[1]
	Audio.ui_db = previous[2]
	Audio.music_db = previous[3]
	Audio._refresh_effect_levels()

func test_menu_and_game_ui_start_real_independent_voices_with_music_muted() -> void:
	var previous := _begin_audio()
	var first := Audio._next
	Audio.play("menu_click", 0)
	var voice: AudioStreamPlayer = Audio._pool[first]
	check(voice.playing, "native one-shot playback starts with music muted")
	check(voice.stream is AudioStreamWAV, "real imported WAV, not a mocked cue")
	if voice.stream:
		check(voice.stream.resource_path.begins_with("res://assets/audio/ww2/menu_click_"), "menu owns its heavy click variants")
	eq(str(voice.bus), "UI", "UI voice has its own bus")
	lt(voice.volume_db, 0.0, "effect preserves output headroom")
	Audio.reset_effect_state()
	first = Audio._next
	Audio.play("ui_click", 0)
	voice = Audio._pool[first]
	check(voice.playing and voice.stream != null, "game UI is also playable")
	if voice.stream:
		check(voice.stream.resource_path.begins_with("res://assets/audio/ww2/ui_click_"), "game click is not the menu asset")
	_end_audio(previous)

func test_priority_notice_plays_from_real_bank_without_a_music_stinger() -> void:
	var previous := _begin_audio()
	Audio.play("peace_signed", 0)
	Audio._pump_queue()
	var voice: AudioStreamPlayer = Audio._notice_player
	check(voice.playing and voice.stream is AudioStreamWAV, "queued diplomatic effect reaches native playback")
	if voice.stream:
		check(voice.stream.resource_path.begins_with("res://assets/audio/ww2/peace_signed_"), "peace uses a dedicated document effect")
	eq(str(voice.bus), "SFX", "notification is independent of UI/music")
	eq(Audio._notice_key, "peace_signed", "semantic queue owns the active voice")
	_end_audio(previous)

func test_spatial_battle_voice_uses_new_wavs_and_effect_volume() -> void:
	var previous := _begin_audio()
	Audio.sfx_db = -12.0
	var battle := BattleAudio.new()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	battle._emit("artillery_boom", Vector2(20, 30), -3.0)
	var voice: AudioStreamPlayer3D = battle._players[0]
	check(voice.playing and voice.stream is AudioStreamWAV, "nearby 3D one-shot actually starts")
	if voice.stream:
		check(voice.stream.resource_path.begins_with("res://assets/audio/ww2/artillery_boom_"), "battle does not use the legacy sample")
	check(voice.volume_db <= -15.0, "3D sound respects the SFX slider plus its local gain")
	eq(voice.max_distance, BattleAudio.MAX_DIST, "far-zoom attenuation is preserved")
	Audio.set_sfx_linear(0.0)
	var next := battle._next
	battle._emit("rifle_crack", Vector2.ZERO, 0.0)
	eq(battle._next, next, "muted spatial requests cannot start a second voice")
	battle.free()
	_end_audio(previous)
