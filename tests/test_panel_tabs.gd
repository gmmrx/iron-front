extends "res://tests/test_case.gd"
## Visible tab state belongs to the shared skin; native selection/keyboard semantics stay intact.

func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722

func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func test_active_tab_has_bronze_fill_contrasting_border_and_physical_underline() -> void:
	var theme := CommandPanelSkin.get_theme()
	var normal := theme.get_stylebox("normal", "Tab")
	var selected := theme.get_stylebox("pressed", "Tab")
	var hover_selected := theme.get_stylebox("hover_pressed", "Tab")
	check(normal is CommandPanelSkin.TabSurface and selected is CommandPanelSkin.TabSurface, "tab states use the existing-artwork overlay style")
	check(normal != selected, "active and inactive style resources are distinct")
	eq(normal.get("underline_height"), 0.0, "inactive tab has no active underline")
	eq(selected.get("underline_height"), 4.0, "active tab has a prominent four-pixel underline")
	gt(selected.get("edge_width"), normal.get("edge_width"), "active border is physically stronger")
	var fill: Color = selected.get("fill")
	check(fill.r > fill.g and fill.g > fill.b and fill.a >= 0.8, "selected background is clearly filled warm bronze, not only a faint outline")
	gt(_luminance(selected.get("edge")), _luminance(normal.get("edge")), "active gold border has materially higher contrast")
	check((selected.get("surface") as Texture2D).resource_path.ends_with("selected_v3.png"), "generated selected nine-slice artwork is retained")
	check((normal.get("surface") as Texture2D).resource_path.ends_with("button_v3.png"), "normal nine-slice artwork is retained")
	check(hover_selected.get("fill") != selected.get("fill"), "hovering an already selected tab is distinguishable")
	ge(_contrast(theme.get_color("font_pressed_color", "Tab"), fill), 4.5, "selected ivory text remains readable on its bronze fill")
	ge(_contrast(theme.get_color("font_hover_pressed_color", "Tab"), hover_selected.get("fill")), 4.5, "hover-selected text also preserves contrast")

func test_focus_is_an_independent_outline_and_other_button_types_are_unchanged() -> void:
	var theme := CommandPanelSkin.get_theme()
	var focus := theme.get_stylebox("focus", "Tab")
	check(focus is CommandPanelSkin.TabSurface, "keyboard focus has a visible tab-specific style")
	eq((focus.get("fill") as Color).a, 0.0, "focus does not impersonate a selected filled state")
	eq(focus.get("underline_height"), 0.0, "focus alone cannot create the selected underline")
	ge(focus.get("edge_width"), 2.0, "keyboard outline is visible")
	check(focus.get("surface") == null, "focus overlay does not repaint the underlying state artwork")
	for type: String in ["Button", "Card", "MenuButton", "OptionButton", "MenuTile"]:
		var normal := theme.get_stylebox("normal", type)
		var selected := theme.get_stylebox("pressed", type)
		check(not normal is CommandPanelSkin.TabSurface and not selected is CommandPanelSkin.TabSurface, "ordinary " + type + " keeps its original styles")
		eq(normal.get("tint"), Color.WHITE, "ordinary button texture tint is unchanged: " + type)
		eq(normal.content_margin_left, 10.0, "ordinary button padding is unchanged: " + type)
		check(theme.get_stylebox("focus", type) is StyleBoxEmpty, "ordinary button focus behavior is unchanged: " + type)
		eq(theme.get_color("font_color", type), Color("eee6d3"), "ordinary button palette is unchanged: " + type)

func test_helper_preserves_one_native_selection_and_keyboard_activation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := VBoxContainer.new()
	host.theme = CommandPanelSkin.get_theme()
	tree.root.add_child(host)
	var selections: Array[int] = []
	var row := PanelLayout.tabs(host, ["Command", "Templates", "Details"], func(index: int) -> void: selections.append(index), 1)
	eq(selections, [], "initial selection paints state without invoking an action")
	var buttons: Array[Button] = []
	for node: Node in row.get_children(): buttons.append(node as Button)
	eq(buttons[0].button_group, buttons[1].button_group, "all tabs share the actual native ButtonGroup")
	check(not buttons[0].button_group.allow_unpress, "the active tab cannot be accidentally unselected")
	for i in buttons.size():
		eq(buttons[i].button_pressed, i == 1, "exactly the requested tab starts active")
		eq(buttons[i].focus_mode, Control.FOCUS_ALL, "tab is keyboard reachable")
		ge(buttons[i].custom_minimum_size.y, 56, "tab has a larger readable hit target")
		ge(buttons[i].get_theme_font_size("font_size"), UiTheme.fs(19), "helper text is at least nineteen design pixels")
	buttons[2].button_pressed = true
	buttons[2].pressed.emit()
	eq(selections, [2], "activation still calls the original on_select index once")
	for i in buttons.size(): eq(buttons[i].button_pressed, i == 2, "native exclusivity leaves one active tab")
	buttons[2].grab_focus()
	var down := InputEventAction.new()
	down.action = "ui_accept"
	down.pressed = true
	var up := InputEventAction.new()
	up.action = "ui_accept"
	up.pressed = false
	tree.root.push_input(down)
	tree.root.push_input(up)
	check(buttons[2].button_pressed, "keyboard activation of selected tab retains its active state")
	eq(selections, [2, 2], "keyboard Enter/Space uses the same single activation callback")
	host.free()

func test_enlarged_tabs_still_fit_a_720p_framed_panel() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	tree.root.add_child(viewport)
	var panel := PanelContainer.new()
	viewport.add_child(panel)
	panel.position = Vector2(PanelLayout.SIDE_LEFT, PanelLayout.SIDE_TOP)
	PanelLayout.frame(panel, "Army", "army", 700.0)
	var fixed := PanelLayout.fixed(panel)
	var row := PanelLayout.tabs(fixed, ["Command and organization", "Division templates"], func(_index: int) -> void: pass, 0)
	for i in 6:
		panel.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)
		PanelLayout.fit_full(panel)
	var rect := panel.get_global_rect()
	check(rect.end.x <= 1280 and rect.end.y <= 720, "larger shared tabs do not expand the panel outside1280×720")
	for node: Control in row.get_children():
		check(rect.encloses(node.get_global_rect()), "every tab hit target stays inside the panel")
		check(node.get_global_rect().end.x <= 1280, "long captions do not force horizontal overflow")
	panel.free()
	viewport.free()
