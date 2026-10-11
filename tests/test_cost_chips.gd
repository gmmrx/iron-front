extends "res://tests/test_case.gd"
## Eylemlerin bedeli düğmenin yanında simgeyle (PanelLayout.cost_chip): sayı doğru, eldeki yetmiyorsa kırmızı, büyük sayı
## kısaltılır, sıfır bedel gösterilmez; diplomaside savaş gerekçesi, asker almada SP ve insan gücü bedeli görünür.

func player_tag() -> String:
	return "GER"

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _amounts(chip: Control) -> Array:
	var out := []
	for n: Node in chip.find_children("*", "Label", true, false):     # aynı adlı ikinci etiketi Godot yeniden adlandırır
		out.append([(n as Label).text, (n as Label).get_theme_color("font_color")])
	return out

func test_chip_shows_amount_shortage_and_short_numbers() -> void:
	var chip := PanelLayout.cost_chip([["influence", 30.0, 10.0], ["sp", 0.0, 5.0], ["manpower", 8000.0, 99999.0]])
	var a := _amounts(chip)
	eq(a.size(), 2, "zero cost is left out")
	eq(a[0][0], "30", "influence amount")
	eq(a[0][1], UiTheme.BAD, "amount is red when the country has too little")
	eq(a[1][0], UiTheme.format_number(8000), "large amounts are shortened like the top bar")
	eq(a[1][1], UiTheme.TEXT, "affordable amount in normal colour")
	check(chip.find_children("*", "TextureRect", true, false).size() == 2, "each cost has its icon")
	chip.free()

func test_diplomacy_and_recruit_show_their_costs() -> void:
	var panel := DiplomacyPanel.new()
	_tree().root.add_child(panel)
	panel.open_for("POL")
	var found := false
	for chip: Node in panel.find_children("Cost", "HBoxContainer", true, false):
		for amount: Array in _amounts(chip as Control):
			if amount[0] == str(int(Diplomacy.JUSTIFY_COST)):
				found = true
	check(found, "casus belli cost is shown next to its button")
	panel.free()
	var st := StatePanel.new()
	_tree().root.add_child(st)
	World.select_province(World.capital_province("GER"))
	var chips := st.find_children("Cost", "HBoxContainer", true, false)
	gt(float(chips.size()), 3.0, "every recruitable unit shows its cost")
	st.free()
