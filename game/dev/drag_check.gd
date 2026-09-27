extends SceneTree
## Sürükleyerek kaydırma denetimi: boş yerden sürükleme kaydırır, düğmeden başlayan sürükleme kaydırmaz.
func _init() -> void:
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # ekransız pencere küçük: koordinatlar bire bir olsun
	root.size = Vector2i(800, 600)
	var sc := ScrollContainer.new()
	sc.position = Vector2(100, 100)
	sc.size = Vector2(300, 300)
	root.add_child(sc)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(280, 2000)
	sc.add_child(body)
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(280, 100)
	filler.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(filler)
	var btn := Button.new()
	btn.text = "düğme"
	btn.custom_minimum_size = Vector2(280, 60)
	body.add_child(btn)
	DragScroll.attach(sc)
	await process_frame
	await process_frame
	var drag := func(from: Vector2, to: Vector2) -> void:
		var mv := InputEventMouseMotion.new(); mv.position = from; mv.global_position = from
		Input.parse_input_event(mv); await process_frame
		var p := InputEventMouseButton.new(); p.button_index = MOUSE_BUTTON_LEFT; p.pressed = true; p.position = from; p.global_position = from
		Input.parse_input_event(p); await process_frame
		for k in 10:
			var m := InputEventMouseMotion.new(); var at := from.lerp(to, (k + 1) / 10.0)
			m.position = at; m.global_position = at; m.relative = (to - from) / 10.0; m.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(m); await process_frame
		var r := InputEventMouseButton.new(); r.button_index = MOUSE_BUTTON_LEFT; r.pressed = false; r.position = to; r.global_position = to
		Input.parse_input_event(r); await process_frame
	await drag.call(Vector2(200, 150), Vector2(200, 50))
	print("boş yerden sürükleme: scroll_vertical=", sc.scroll_vertical)
	var ok1 := sc.scroll_vertical > 50
	sc.scroll_vertical = 0
	await process_frame
	var pressed := [0]
	btn.pressed.connect(func() -> void: pressed[0] += 1)
	var bpos := btn.get_global_rect().get_center()
	await drag.call(bpos, bpos + Vector2(0, -80))
	print("düğmeden sürükleme: scroll_vertical=", sc.scroll_vertical)
	var ok2 := sc.scroll_vertical == 0
	print("SONUÇ ", "geçti" if ok1 and ok2 else "KALDI")
	quit(0 if ok1 and ok2 else 1)
