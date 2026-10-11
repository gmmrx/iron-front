extends "res://tests/test_case.gd"
## Yükleme ekranının sağ altındaki "yüklenen / toplam MB": Godot'ta kaynaktan çalışırken de oyunun paketinin boyunu
## gösterir (içe aktarılmış, sıkıştırılmış dosyalar; dışa aktarımın dışarıda bıraktıkları yok), ham kaynak klasörlerinin
## toplamını değil.

func _raw(path: String) -> float:
	var total := 0.0
	var d := DirAccess.open(path)
	if d == null:
		return 0.0
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := path.path_join(name)
			if d.current_is_dir():
				total += _raw(full)
			elif not name.ends_with(".import") and not name.ends_with(".uid"):
				total += FileAccess.get_size(full)
		name = d.get_next()
	return total

func test_loading_screen_counts_the_package_not_the_source_folders() -> void:
	var packed := LoadingScreen.export_size_mb()
	var raw := (_raw("res://assets") + _raw("res://data") + _raw("res://game")) / 1048576.0
	gt(packed, 100.0, "the whole game is counted: %.0f MB" % packed)
	lt(packed, raw * 0.7, "imported (compressed) files and export exclusions count, not raw sources (%.0f vs %.0f MB)" % [packed, raw])
	check(LoadingScreen._excluded("res://assets/models/city_west_capital.bin", PackedStringArray(["assets/models/*.bin"])),
		"files the export leaves out are not counted")
