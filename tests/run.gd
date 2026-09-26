extends SceneTree
## Test koşucusu: tests/ altındaki test_*.gd dosyalarını bulur, her test_* fonksiyonunu temiz bir oyunla çalıştırır.
##   godot --headless --path . -s tests/run.gd [-- --file=test_data] [--filter=strings]
## Test sırasında basılan motor/betik hataları (push_error, SCRIPT ERROR) da testi kırmızı yapar.
## Çıkış kodu: 0 = hepsi geçti, 1 = en az bir test kaldı.

const TEST_DIR := "res://tests/"
const MAX_LINES := 40              ## test başına yazılan en fazla hata satırı

var _catcher: Logger

func _init() -> void:
	# yakalayıcı autoload'lar yüklenmeden kurulur: veri yükleme hataları da sayılır
	_catcher = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(_catcher)
	await process_frame
	var file_only := ""
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="): file_only = a.substr(7).trim_suffix(".gd")
		if a.begins_with("--filter="): filter = a.substr(9)
	var game: Node = root.get_node("Game")
	var world: Node = root.get_node("World")
	var t0 := Time.get_ticks_msec()
	var passed := 0
	var failed: Array[String] = []
	var warnings := 0
	var boot: Array[String] = _catcher.take()
	if not boot.is_empty():
		failed.append("başlangıç")
		print("FAIL  başlangıç: veri/autoload yüklenirken hata")
		_print_lines(boot)
	for path in _test_files(file_only):
		var script: Script = load(path)
		var file := path.get_file().get_basename()
		if script == null or not script.can_instantiate():
			failed.append(file)
			print("== %s ==" % path.trim_prefix("res://"))
			print("  FAIL  betik yüklenemedi (ayrıştırma hatası?)")
			_print_lines(_catcher.take())
			continue
		var methods: Array[String] = []
		for m in _test_methods(script):
			if filter == "" or ("%s::%s" % [file, m]).contains(filter):
				methods.append(m)
		if methods.is_empty():
			continue
		print("== %s ==" % path.trim_prefix("res://"))
		var inst: Object = script.new()
		for m in methods:
			var full := "%s::%s" % [file, m]
			_catcher.take()
			var s0 := Time.get_ticks_msec()
			game.new_game()
			world.start_game(inst.call("player_tag"))
			inst.call("_begin")
			inst.call(m)
			var errs: Array[String] = []
			errs.append_array(inst.get("_failures"))
			for e in _catcher.take():
				errs.append("motor/betik hatası: " + e)
			var warns: Array = inst.get("_warnings")
			warnings += warns.size()
			var ms := Time.get_ticks_msec() - s0
			if errs.is_empty():
				passed += 1
				print("  ok    %s (%d ms)" % [m, ms])
			else:
				failed.append(full)
				print("  FAIL  %s (%d ms)" % [m, ms])
				_print_lines(errs)
			for w in warns:
				print("        uyarı: %s" % w)
		inst = null          # sonraki dosyadan önce bırak (çıkışta sızıntı uyarısı olmasın)
	print("")
	print("== %d test: %d geçti, %d kaldı, %d uyarı (%.1f sn) ==" % [passed + failed.size(), passed, failed.size(), warnings,
		(Time.get_ticks_msec() - t0) / 1000.0])
	for f in failed:
		print("   kaldı: %s" % f)
	OS.remove_logger(_catcher)
	quit(1 if not failed.is_empty() else 0)

func _print_lines(lines: Array) -> void:
	for i in mini(lines.size(), MAX_LINES):
		print("        - %s" % lines[i])
	if lines.size() > MAX_LINES:
		print("        ... ve %d satır daha" % (lines.size() - MAX_LINES))

func _test_files(only: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			if only == "" or f.get_basename() == only:
				out.append(TEST_DIR + f)
	out.sort()
	return out

## Betikte tanımlanan test_* fonksiyonları (tanım sırasıyla)
func _test_methods(script: Script) -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not n in out:
			out.append(n)
	return out
