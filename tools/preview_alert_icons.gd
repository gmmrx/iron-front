extends SceneTree
## Actual TopBar + actual notification buttons; lower row is a 2x inspection view.
func _init() -> void:
	await process_frame
	root.get_node("Game").new_game()
	root.get_node("World").start_game("TUR")
	var ui: Script = load("res://game/ui/ui_theme.gd")
	var top_script: Script = load("res://game/ui/top_bar.gd")
	var alert_script: Script = load("res://game/ui/alert_bar.gd")
	DisplayServer.window_set_size(Vector2i(1920, 700))
	root.content_scale_size = Vector2i(1920, 700)
	var bg := ColorRect.new()
	bg.color = Color("1b2421")
	bg.size = Vector2(1920, 700)
	root.add_child(bg)
	var top: Control = top_script.new()
	root.add_child(top)
	top.task_row.get_parent().hide() # Empty menu tray is not part of this preview.
	var alerts: HBoxContainer = alert_script.new()
	top.alert_row.add_child(alerts)
	alerts.set_process(false)
	alerts.strip = top.alert_strip
	var names := ["Olay", "Araştırma", "İnşaat", "Asker alımı", "Hava görevi", "İkmal", "Teşvik", "İnsan gücü", "Teslimiyet"]
	var levels := ["urgent", "warn", "warn", "info", "info", "urgent", "info", "warn", "urgent"]
	var entries: Array = []
	for i in alert_script.ICON_IDS.size():
		entries.append([alert_script.ICON_IDS[i], "diplomacy", levels[i], names[i], "Bildirim açıklaması", func() -> void: pass])
	alerts._rebuild(entries)
	var heading: Label = ui.make_label("BİLDİRİMLER · ALTIN METAL / YENİ UI", 24)
	heading.position = Vector2(180, 280)
	bg.add_child(heading)
	var note: Label = ui.make_label("Üstte gerçek 62 px boyut · Altta 2× detay görünümü", 18)
	note.position = Vector2(180, 322)
	bg.add_child(note)
	var detail_tiles: Array[Button] = []
	for i in entries.size():
		var holder := Control.new()
		holder.position = Vector2(180 + i * 175, 386)
		holder.scale = Vector2(2, 2)
		bg.add_child(holder)
		var tile: Button = alerts._tile(entries[i])
		tile.size = Vector2(62, 62)
		holder.add_child(tile)
		detail_tiles.append(tile)
		var caption: Label = ui.make_label(names[i], 17)
		caption.position = Vector2(180 + i * 175, 530)
		bg.add_child(caption)
	DirAccess.make_dir_recursive_absolute("res://art/previews/alerts_gold")
	# Deterministic samples from the real attention animation, including recruit's long quiet gap.
	for sample: Array in [["notification_set", 0.9], ["notification_off", 0.25], ["notification_fade", 0.375], ["notification_rest", 10.0], ["notification_recruit", 20.25]]:
		alerts._pulse = sample[1]
		alerts._animate_urgency(0.0)
		for tile in detail_tiles:
			alerts._apply_attention(tile)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/previews/alerts_gold/" + sample[0] + ".png")
	print("ALERT_PREVIEW saved")
	top.queue_free()
	bg.queue_free()
	await process_frame
	await process_frame
	quit()
