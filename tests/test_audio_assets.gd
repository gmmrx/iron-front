extends "res://tests/test_case.gd"
## Real imported WWII WAVs and the production lazy bank, plus bounded selection/mute regressions.
## No music files or music scheduling are changed by these checks.

const CATALOG := "res://assets/audio/ww2/catalog.json"
const PHASES := ["select", "start", "done", "cancel"]

func _catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CATALOG))

func _sorted_keys(data: Dictionary) -> Array:
	var keys := data.keys()
	keys.sort()
	return keys

func _cue_spy() -> Dictionary:
	var heard: Array[String] = []
	var callback := func(key: String) -> void: heard.append(key)
	Audio.cue_requested.connect(callback)
	return {"heard": heard, "callback": callback}

func test_catalog_covers_all_37_technologies_four_phases_and_375_registered_wavs() -> void:
	var catalog := _catalog()
	var source: Dictionary = read_json(Research.PATH)
	eq(catalog["version"], 2, "versioned effect bank")
	eq(catalog["sample_rate"], 48000, "authoring sample rate")
	eq((catalog["research"] as Dictionary).size(), 37, "all current historical/government technologies")
	eq(_sorted_keys(catalog["research"]), _sorted_keys(source["techs"]), "no base technology is missing a personal cue family")
	eq(_sorted_keys(catalog["research_categories"]), _sorted_keys(source["categories"]), "all repeatable/future branches have fallbacks")
	var sounds: Dictionary = catalog["sounds"]
	for families: Dictionary in [catalog["research"], catalog["research_categories"]]:
		for id: String in families:
			var phases: Dictionary = families[id]
			eq(phases.size(), 4, "four phases for " + id)
			var distinct := {}
			for phase: String in PHASES:
				var key := str(phases.get(phase, ""))
				check(key != "" and sounds.has(key), "registered %s %s cue" % [id, phase])
				distinct[key] = true
			eq(distinct.size(), 4, "select/start/done/cancel use distinct assets: " + id)
	var paths := {}
	var count := 0
	for key: String in sounds:
		var definition: Dictionary = sounds[key]
		check(not (definition["files"] as Array).is_empty(), "nonempty cue: " + key)
		check(str(definition["bus"]) in ["ui", "sfx"], "effect bus only: " + key)
		for value: Variant in definition["files"]:
			var path := str(value)
			check(path.begins_with("res://assets/audio/ww2/") and path.ends_with(".wav"), "bank never routes to music: " + path)
			check(not paths.has(path), "one registered identity per variant: " + path)
			paths[path] = true
			check(ResourceLoader.exists(path, "AudioStreamWAV"), "Godot-imported WAV exists: " + path)
			count += 1
	eq(count, 375, "complete generated bank is imported")
	eq(paths.size(), 375, "all imported variant paths are unique")

func test_real_effect_streams_load_without_playback_repeat_or_unbounded_cache() -> void:
	var previous_mode := Audio.test_mode
	Audio.test_mode = false # Exercise real ResourceLoader imports, not simulated cues.
	Audio._stream_cache.clear()
	Audio._stream_lru.clear()
	var catalog := _catalog()
	var sounds: Dictionary = catalog["sounds"]
	var log := _cue_spy()
	var loaded := 0
	for key: String in sounds:
		var stream := Audio.effect_stream(key)
		if check(stream is AudioStreamWAV, "real production stream for " + key):
			var wav := stream as AudioStreamWAV
			check(stream.resource_path in sounds[key]["files"], "bank chooses only a registered variant: " + key)
			eq(wav.mix_rate, 48000, "import preserves sample rate: " + key)
			check(not wav.stereo, "mono effects: " + key)
			check(wav.format in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS, AudioStreamWAV.FORMAT_IMA_ADPCM, AudioStreamWAV.FORMAT_QOA], "supported Godot WAV import format: " + key)
			check(not wav.data.is_empty(), "nonempty decoded/compressed sample data: " + key)
			gt(wav.get_length(), 0.02, "meaningful duration: " + key)
			lt(wav.get_length(), 12.0, "bounded one-shot effect duration: " + key)
			eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "effect never becomes music/ambient looping: " + key)
			loaded += 1
		le_cache()
	eq(loaded, sounds.size(), "every catalog cue supplies a real stream")
	eq(Audio._stream_cache.size(), Audio.STREAM_CACHE_MAX, "lazy bank remains at its hard bounded capacity")
	for key: String in sounds:
		if (sounds[key]["files"] as Array).size() < 2: continue
		var previous := ""
		for i in 6:
			var stream := Audio.effect_stream(key)
			if stream != null:
				check(stream.resource_path != previous, "no immediate repeated variation: " + key)
				previous = stream.resource_path
		le_cache()
	check(Audio.effect_stream("_missing_audio_asset") == null, "unknown cue cannot accidentally load another asset")
	eq(log.heard, [], "stream requests do not play/emit semantic cue requests")
	Audio.cue_requested.disconnect(log.callback)
	Audio.test_mode = previous_mode

func le_cache() -> void:
	check(Audio._stream_cache.size() <= Audio.STREAM_CACHE_MAX, "stream cache is bounded after each request")
	check(Audio._stream_lru.size() <= Audio.STREAM_CACHE_MAX, "LRU bookkeeping is bounded too")
	eq(Audio.STREAM_CACHE_MAX, 48, "deliberate runtime residency budget")

func test_music_mute_does_not_mute_effects_and_sfx_zero_blocks_battle_voices() -> void:
	var previous := [Audio.music_db, Audio.sfx_db, Audio.ui_db, Audio.test_mode]
	Audio.test_mode = true
	Audio.reset_effect_state()
	var log := _cue_spy()
	Audio.music_db = -80.0
	Audio.sfx_db = 0.0
	Audio.ui_db = 0.0
	Audio._refresh_effect_levels()
	check(Audio.music_linear() < 0.001, "music volume is actually muted for this fixture")
	Audio.play("ui_click", 0)
	eq(log.heard, ["ui_click"], "effect remains available with music muted")
	(log.heard as Array).clear()
	Audio.reset_effect_state()
	Audio.set_sfx_linear(0.0)
	Audio.play("artillery_boom", 0)
	eq(log.heard, [], "SFX mute rejects effects before cue admission")
	(log.heard as Array).clear()
	var battle := BattleAudio.new()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	var next := battle._next
	Audio._stream_cache.clear()
	Audio._stream_lru.clear()
	battle._emit("artillery_boom", Vector2.ZERO, 0.0)
	eq(battle._next, next, "muted direct battle emission does not consume a voice slot")
	eq(Audio._stream_cache.size(), 0, "muted battle emission does not load a sample either")
	for voice: AudioStreamPlayer3D in battle._players:
		check(not voice.playing and voice.stream == null, "no muted 3D battle voice starts")
	battle.free()
	Audio.sfx_db = 0.0
	Audio.set_ui_linear(0.0)
	Audio.play("ui_click", 0)
	eq(log.heard, [], "UI mute rejects interface cues independently of music")
	Audio.cue_requested.disconnect(log.callback)
	Audio.music_db = previous[0]
	Audio.sfx_db = previous[1]
	Audio.ui_db = previous[2]
	Audio.test_mode = previous[3]
	Audio._refresh_effect_levels()
	Audio.reset_effect_state()

func test_real_unit_selection_only_sounds_when_selection_changes() -> void:
	var previous := [Audio.sfx_db, Audio.ui_db, Audio.test_mode]
	Audio.sfx_db = 0.0
	Audio.ui_db = 0.0
	Audio._refresh_effect_levels()
	Audio.test_mode = true
	Audio.reset_effect_state()
	var log := _cue_spy()
	var units := UnitLayer.new()
	units.process_mode = Node.PROCESS_MODE_DISABLED
	(Engine.get_main_loop() as SceneTree).root.add_child(units)
	var own := Military.country_divisions(World.player_tag)
	check(own.size() >= 2, "real typed military fixture")
	units.select_divisions([own[0]], false)
	eq(log.heard.size(), 1, "initial selection has one typed cue")
	if not log.heard.is_empty(): check(str(log.heard[0]).begins_with("select_"), "typed unit selection cue family")
	(log.heard as Array).clear()
	Audio.reset_effect_state()
	units.select_divisions([own[0]], false)
	units.select_divisions([own[0]], true)
	eq(log.heard, [], "unchanged replace/additive selection never duplicates the cue")
	units.select_divisions([own[1]], true)
	eq(log.heard.size(), 1, "one actual addition has one cue")
	(log.heard as Array).clear()
	Audio.reset_effect_state()
	units.select_divisions([own[0]], false)
	eq(log.heard, ["unit_deselect"], "partial removal has only a deselect, not a false new-selection cue")
	(log.heard as Array).clear()
	Audio.reset_effect_state()
	units.select_divisions([], false)
	eq(log.heard, ["unit_deselect"], "empty selection has one deselect")
	(log.heard as Array).clear()
	Audio.reset_effect_state()
	units.clear_selection()
	eq(log.heard, [], "programmatic clear/prune stays silent")
	units.free()
	Audio.cue_requested.disconnect(log.callback)
	Audio.sfx_db = previous[0]
	Audio.ui_db = previous[1]
	Audio.test_mode = previous[2]
	Audio._refresh_effect_levels()
	Audio.reset_effect_state()
