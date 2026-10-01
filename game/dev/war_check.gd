extends SceneTree
## Savaş davranışı ölçümü (başsız): savaş demosu kaydında (ya da --war ile) N oyun günü; iki ülkenin tümenleri için
## emir sayısı, yanal (dost toprakta cephe boyunca) yer değiştirme, gidip-dönme (A→B→A, 3 gün içinde), geri çekilme
## sıçraması, cephe bölgelerinde duranların payı, ele geçen bölgeler. Mantık war_check_run.gd'de (autoload'lardan sonra
## yüklenir).
##   godot --headless --path . -s game/dev/war_check.gd -- [--load=war_demo_watch] [--pair=GER,SOV] [--days=14]
func _init() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var runner: Object = load("res://game/dev/war_check_run.gd").new()
	var code: int = await runner.run(self, args)
	quit(code)
