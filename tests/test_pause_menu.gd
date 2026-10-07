extends "res://tests/test_case.gd"
## ESC presentation/lifecycle only. Never press Save, a save slot, Main menu or Quit.

const BUTTONS := ["PauseResume", "PauseSave", "PauseLoad", "PauseSettings", "PauseMainMenu", "PauseQuit"]

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	_tree().root.add_child(menu)
	return menu

func _button(menu: PauseMenu, name: String) -> Button:
	return menu.find_child(name, true, false) as Button

func _active_settings(menu: PauseMenu) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in menu.get_children():
		if child is SettingsPanel and not child.is_queued_for_deletion(): result.append(child)
	return result

func _finish(menu: PauseMenu, paused_before: bool) -> void:
	if menu.visible: menu.close()
	menu.free()
	GameClock.set_paused(paused_before)

func test_opening_and_resume_restore_a_running_clock_without_changing_speed() -> void:
	var paused_before := GameClock.paused
	GameClock.set_paused(false)
	var speed := GameClock.speed
	var menu := _menu()
	check(not menu.visible, "ESC overlay starts hidden")
	menu.toggle()
	check(menu.visible and GameClock.paused, "opening ESC pauses a previously running game")
	check(not menu._was_paused, "opening captures the actual old running state")
	eq(GameClock.speed, speed, "opening does not change the simulation speed")
	var resume := _button(menu, "PauseResume")
	if check(resume != null, "real Resume action exists"):
		resume.pressed.emit()
	check(not menu.visible and not GameClock.paused, "Resume closes and restores the old running state")
	eq(GameClock.speed, speed, "resuming preserves the old speed")
	_finish(menu, paused_before)

func _settings_values() -> Array:
	return [GameSettings.master, GameSettings.music, GameSettings.sfx, GameSettings.ui,
		GameSettings.music_track, GameSettings.lang, GameSettings.fullscreen, GameSettings.edge_pan,
		Audio.music_db, Audio.sfx_db, Audio.ui_db, Audio.forced_track, AudioServer.get_bus_volume_db(0)]

func test_only_command_settings_bounds_music_at_720p_and_preserves_preferences() -> void:
	var before := _settings_values()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	_tree().root.add_child(viewport)
	var settings := SettingsPanel.new()
	settings.command_style = true
	viewport.add_child(settings)
	eq(settings.get_viewport_rect().size, Vector2(1280, 720), "command Settings uses the actual native 720p viewport")
	var scroll := settings.find_child("SettingsMusicScroll", true, false) as ScrollContainer
	if check(scroll != null, "only the long command music list uses a dedicated scroll container"):
		near(scroll.custom_minimum_size.y, 300.0, 0.01, "720p music list has the explicit 300 px height bound")
		eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "track names cannot make horizontal scroll")
		check(scroll.follow_focus, "music list follows keyboard focus")
		eq(settings._music_box.get_parent(), scroll, "actual tracks are inside the bounded list")
		var title: Label
		var done: Button
		for node: Node in settings.find_children("*", "Label", true, false):
			if (node as Label).text == tr("PAUSE_SETTINGS").to_upper(): title = node as Label
		for node: Node in settings.find_children("*", "Button", true, false):
			if (node as Button).text == tr("SET_DONE"): done = node as Button
		check(title != null and not scroll.is_ancestor_of(title), "Settings header stays outside the scrolling track list")
		if title != null: eq(title.get_theme_font("font"), UiTheme.bold_font(), "command header matches the established bold panel typography")
		check(done != null and not scroll.is_ancestor_of(done), "Done stays outside the scrolling track list")
		var tracks := settings._music_box.find_children("*", "Button", true, false)
		eq(tracks.size(), SettingsPanel.TRACKS.size() + 1, "all eight real tracks plus Auto remain available")
		if not tracks.is_empty(): eq((tracks[0] as Button).text, tr("SET_MUSIC_AUTO"), "first choice is the real automatic playback mode")
		for i in SettingsPanel.TRACKS.size():
			check((tracks[i + 1] as Button).text.begins_with(tr("MUSIC_" + SettingsPanel.TRACKS[i])), "track caption uses the actual registered track, including its existing duration")
	var menu_settings := SettingsPanel.new()
	viewport.add_child(menu_settings)
	check(not menu_settings.command_style, "main-menu Settings remains an opt-out of the command-only layout")
	check(menu_settings.find_child("SettingsMusicScroll", true, false) == null, "noncommand Settings keeps its original unscrolled music layout")
	eq(menu_settings._music_box.find_children("*", "Button", true, false).size(), SettingsPanel.TRACKS.size() + 1, "main-menu layout retains the same actual music choices")
	eq(_settings_values(), before, "creating both layouts does not change or persist any sound/display/language preference")
	viewport.free()

func test_prepaused_game_stays_paused_after_toggle_close() -> void:
	var paused_before := GameClock.paused
	GameClock.set_paused(true)
	var menu := _menu()
	menu.toggle()
	check(menu._was_paused, "already paused state is captured")
	menu.toggle()
	check(not menu.visible and GameClock.paused, "closing ESC cannot accidentally unpause a prepaused game")
	_finish(menu, paused_before)

func test_centered_command_window_has_six_large_focusable_real_actions_and_identity() -> void:
	var paused_before := GameClock.paused
	var menu := _menu()
	menu.toggle()
	eq(menu.theme, CommandPanelSkin.get_theme(), "ESC inherits the established command-panel design")
	check(menu._panel.get_parent() is CenterContainer, "window is centered by a real container rather than guessed offsets")
	eq(menu._panel.name, &"PauseWindow", "dedicated window remains inspectable")
	near(menu._panel.custom_minimum_size.x, 480.0, 0.01, "desktop window keeps its readable bounded width")
	check(menu._panel.get_theme_stylebox("panel").get("surface") != null, "window uses the existing generated frame artwork")
	for name: String in BUTTONS:
		var button := _button(menu, name)
		if not check(button != null, "real named action exists: " + name): continue
		eq(button.custom_minimum_size.y, 54.0, "action remains easy to target and read")
		eq(button.focus_mode, Control.FOCUS_ALL, "action is reachable using keyboard navigation")
		check(button.has_theme_stylebox_override("focus"), "keyboard focus has a visible frame")
		check(not button.get_signal_connection_list("pressed").is_empty(), "actual callback remains connected without executing it")
	var resume := _button(menu, "PauseResume")
	eq(resume.get_theme_stylebox("normal").get("surface"), CommandPanelSkin.box("selected", 10).get("surface"), "Resume has the generated gold primary treatment")
	eq(resume.get_theme_color("font_color"), UiTheme.ACCENT, "primary label uses the existing aged-gold accent")
	check(resume.has_focus(), "opening the menu focuses Resume for keyboard activation")
	var title := menu.find_child("PauseTitle", true, false) as Label
	var country := menu.find_child("PauseCountry", true, false) as Label
	var date := menu.find_child("PauseDate", true, false) as Label
	check(title != null and title.text == tr("PAUSE_TITLE").to_upper(), "header is the actual localized pause title")
	check(country != null and country.text == player().display_name(), "country label uses the actual selected country")
	check(date != null and date.text == GameClock.date_string(), "date label uses the actual game clock")
	check(menu._panel.get_combined_minimum_size().y <= 672.0, "six-button ESC content fits the 720p height budget")
	_finish(menu, paused_before)

func test_settings_close_restores_menu_and_esc_teardown_cannot_stack_settings() -> void:
	var paused_before := GameClock.paused
	GameClock.set_paused(false)
	var menu := _menu()
	menu.toggle()
	menu._settings()
	var first := menu._settings_panel
	check(first != null and first.command_style, "in-game Settings opts into the same command design")
	check(not menu._panel.visible and GameClock.paused, "Settings replaces the window while the game stays paused")
	menu._settings()
	eq(_active_settings(menu).size(), 1, "repeated Settings request cannot stack overlays")
	eq(menu._settings_panel, first, "repeated request preserves the existing Settings instance")
	first._close() # Safe close signal only; never touch sliders/language/fullscreen settings.
	check(menu._settings_panel == null and menu._panel.visible, "Settings close restores the original menu window")
	check(_button(menu, "PauseResume") != null and GameClock.paused, "restored menu is normal and still pauses the game")
	menu._settings()
	var second := menu._settings_panel
	menu.close()
	check(not menu.visible and not GameClock.paused, "ESC close from Settings restores the original running state")
	check(menu._settings_panel == null and second.get_parent() == null, "closing tears down the active Settings subtree immediately")
	menu.toggle()
	check(menu._panel.visible and _active_settings(menu).is_empty(), "reopening ESC starts with a normal window, not stale Settings")
	for name: String in BUTTONS: check(_button(menu, name) != null, "reopened menu retains its six actions")
	_finish(menu, paused_before)

func test_load_view_is_bounded_read_only_and_back_returns_to_six_button_menu() -> void:
	var paused_before := GameClock.paused
	var menu := _menu()
	menu.toggle()
	var requested: Array[String] = []
	menu.load_requested.connect(func(slot: String) -> void: requested.append(slot))
	var actual := Game.list_saves()
	menu._load_list() # Lists actual files only; never select or load any slot.
	var scroll := menu.find_child("PauseSaves", true, false) as ScrollContainer
	if check(scroll != null, "save list is inside a bounded real ScrollContainer"):
		eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "save names cannot force sideways scrolling")
		check(scroll.custom_minimum_size.y >= 140 and scroll.custom_minimum_size.y <= 280, "list height remains bounded independently of save count")
		check(scroll.follow_focus, "keyboard focus scrolls through save entries")
		var slots := scroll.find_children("*", "Button", true, false)
		eq(slots.size(), mini(actual.size(), 10), "only the first ten actual saves are listed")
		for i in slots.size(): eq((slots[i] as Button).text, actual[i], "entry preserves the exact actual slot name")
		if actual.is_empty():
			var texts: Array[String] = []
			for label: Node in scroll.find_children("*", "Label", true, false): texts.append((label as Label).text)
			check(tr("LOAD_NONE") in texts, "empty file list has an honest empty state")
	eq(requested, [], "rendering the list never requests a load")
	var fixtures: Array[String] = []
	for i in 18: fixtures.append("read_only_fixture_%02d" % i)
	menu._show_saves(fixtures) # Pure render helper: creates no files and invokes no load callbacks.
	scroll = menu.find_child("PauseSaves", true, false) as ScrollContainer
	eq(scroll.find_children("*", "Button", true, false).size(), 10, "large in-memory fixture is capped at ten slots")
	var back := _button(menu, "PauseBack")
	check(back != null and not scroll.is_ancestor_of(back), "Back stays outside the scrolling save list")
	if back != null: back.pressed.emit()
	check(menu.find_child("PauseSaves", true, false) == null, "Back removes the load-only view")
	for name: String in BUTTONS: check(_button(menu, name) != null, "Back restores the normal actual menu actions")
	eq(requested, [], "Back never loads a synthetic or actual save")
	_finish(menu, paused_before)
