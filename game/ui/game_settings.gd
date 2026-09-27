class_name GameSettings
extends RefCounted
## Oyuncu ayarları (user://settings.cfg): ses düzeyleri, seçili müzik parçası, dil, tam ekran, kenar kaydırma.
## Açılışta Audio autoload'u yükler ve uygular; Ayarlar ekranı her değişiklikte kaydeder.

const PATH := "user://settings.cfg"

static var master := 1.0
static var music := 1.0
static var sfx := 1.0
static var ui := 1.0
static var music_track := ""        ## "" = oyun durumuna göre (otomatik)
static var lang := ""               ## "" = sistem dili
static var fullscreen := false
static var edge_pan := true

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = float(cfg.get_value("audio", "master", 1.0))
		music = float(cfg.get_value("audio", "music", 1.0))
		sfx = float(cfg.get_value("audio", "sfx", 1.0))
		ui = float(cfg.get_value("audio", "ui", 1.0))
		music_track = str(cfg.get_value("audio", "music_track", ""))
		lang = str(cfg.get_value("game", "lang", ""))
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		edge_pan = bool(cfg.get_value("display", "edge_pan", true))
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	Audio.set_music_linear(music)
	Audio.set_sfx_linear(sfx)
	Audio.set_ui_linear(ui)
	Audio.set_forced_track(music_track)
	if lang != "":
		TranslationServer.set_locale(lang)
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "ui", ui)
	cfg.set_value("audio", "music_track", music_track)
	cfg.set_value("game", "lang", lang)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "edge_pan", edge_pan)
	cfg.save(PATH)
