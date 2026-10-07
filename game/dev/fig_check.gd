extends SceneTree
## Figür yerleşimi sınaması (başsız): --play=DEN --war=GER,DEN gibi bir savaşta sınırdaki ilk muharebenin çevresinde
## N oyun günü, 30 kare/sn, hız 3. Her karede görünen figür çiftlerinin ölçülü uzaydaki uzaklığı (dmin altı = üst
## üste), figürün yer değişimi ile bakışı arasındaki açı (kayma: 60°'den açık) ve kare başına sıçrama (1 birimden uzun)
## sayılır. Mantık fig_check_run.gd'de: -s ile koşan betik autoload'lardan önce derlenir, proje sınıflarına burada
## değinilemez (tests/run.gd gibi sonradan yüklenir).
##   godot --headless --path . -s game/dev/fig_check.gd -- [--days=3] [--war=GER,DEN] [--play=DEN] [--speed=3]
##                                                          [--dist=140] [--verbose]
##   ... -- --load=war_demo_watch [--pair=GER,SOV] [--battle]   kayıttan (savaş demosu): en kalabalık cephede (ya da
##                                                   süren en kalabalık muharebede) ölçer, --focus'u yazar
func _init() -> void:
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var runner: Object = load("res://game/dev/fig_check_run.gd").new()
	var code: int = await runner.run(self, args)
	var errors: Array = catcher.take()
	OS.remove_logger(catcher)
	if not errors.is_empty():
		print("FIGCHECK runtime errors=", errors)
		code = 1
	quit(code)
