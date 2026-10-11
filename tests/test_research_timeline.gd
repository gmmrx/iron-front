extends "res://tests/test_case.gd"
## Araştırma ekranı: komuta paneli kartlarıyla zaman çizelgesi. Her teknoloji kendi dalının satırında, yılının sütununda;
## iyileştirme seviyesi son sütunda; ulusal projeler Yönetim sekmesinde, çizelgenin dışında; yıl başlığı ve dal adları
## kaydırırken yerinde kalır; çizelge yumuşak kayar (tekerlek hedefi taşır, konum ona süzülür, sınırda durur) ve seçilen
## kart görünmüyorsa ona süzülür.

func _tree() -> SceneTree: return Engine.get_main_loop() as SceneTree

func _panel(branch := "all") -> ResearchPanel:
	var panel := ResearchPanel.new()
	_tree().root.add_child(panel)
	panel.size = Vector2(1700, 900)
	panel.visible = true
	panel._set_branch(branch)
	return panel

func test_every_technology_sits_in_its_branch_row_and_year_column() -> void:
	var panel := _panel()
	var rows := {}
	for r: Array in panel._rows:
		rows[r[0]] = r
	for id: String in Research.techs:
		if not ResearchPanel._on_timeline(id):
			continue
		if not check(panel._nodes.has(id), "technology on the timeline: " + id):
			continue
		var card: Control = panel._nodes[id]
		var t: Dictionary = Research.techs[id]
		eq(card.get_parent(), panel._canvas, "card is on the timeline: " + id)
		eq(panel._y0 + floori(card.position.x / panel._col_w), int(t["year"]), "card stands in its year column: " + id)
		var row: Array = rows.get(t["cat"], [])
		if check(not row.is_empty(), "branch row exists: " + str(t["cat"])):
			check(card.position.y >= float(row[1]) and card.position.y + card.size.y <= float(row[1]) + float(row[2]), "card inside its branch row: " + id)
	for cat: String in Research.categories:
		var rep := Research.next_repeat(player(), cat)
		if rep != "" and check(panel._nodes.has(rep), "next refinement level shown for " + cat):
			eq(floori((panel._nodes[rep] as Control).position.x / panel._col_w), panel._y1 - panel._y0 + 1, "refinement level is in the last column")
	for id: String in panel._nodes:
		check(not Research.is_government_project(id), "national projects are not on the year timeline: " + id)
	panel.free()

func test_government_tab_holds_the_national_projects() -> void:
	var panel := _panel("governance")
	var n := 0
	for id: String in Research.techs:
		if Research.is_government_project(id):
			n += 1
			check(panel._nodes.has(id), "national project shown: " + id)
	eq(panel._nodes.size(), n, "only national projects on the Government tab")
	check(not panel._header_row.visible, "no year header for projects without a year")
	panel.free()

func test_branch_tabs_filter_rows_and_header_and_labels_stay_in_place() -> void:
	var panel := _panel("army")
	for r: Array in panel._rows:
		check(r[0] in ResearchPanel.BRANCHES["army"], "army tab shows only army branches: " + str(r[0]))
	panel._catalog_scroll.size = Vector2(500, 300)
	panel._catalog_scroll.scroll_horizontal = 120
	panel._catalog_scroll.scroll_vertical = 80
	panel._process(0.016)
	eq(panel._header.position.x, -float(panel._catalog_scroll.scroll_horizontal), "year header follows horizontal scroll")
	eq(panel._labels.position.y, -float(panel._catalog_scroll.scroll_vertical), "branch names follow vertical scroll")
	panel.free()

func test_smooth_scroll_eases_to_target_and_stops_at_edges() -> void:
	var panel := _panel()
	var sc := panel._catalog_scroll
	sc.size = Vector2(600, 400)
	sc.notification(Container.NOTIFICATION_SORT_CHILDREN)     # testte düzen geçişi yok: kaydırma sınırları güncellensin
	var drag: DragScroll = panel._drag
	check(drag.smooth, "research timeline scrolls smoothly")
	drag.jump_to(Vector2.ZERO)
	drag.scroll_to(Vector2(300, 200))
	eq(drag.target(), Vector2(300, 200), "target set at once")
	drag._process(0.016)
	var moved := Vector2(sc.scroll_horizontal, sc.scroll_vertical)
	check(moved.x > 0.0 and moved.x < 300.0, "first frame moves part of the way (eased), not a jump: %s" % moved)
	for i in 120:
		drag._process(0.016)
	eq(Vector2(sc.scroll_horizontal, sc.scroll_vertical), Vector2(300, 200), "settles exactly on the target")
	drag.scroll_to(Vector2(-500, 99999))
	var mx := drag._max_scroll()
	eq(drag.target(), Vector2(0, mx.y), "target is clamped to the content")
	panel.free()

func test_selected_card_is_brought_into_view() -> void:
	var panel := _panel()
	panel._catalog_scroll.size = Vector2(600, 400)
	panel._drag.jump_to(Vector2.ZERO)
	var far := ""
	for id: String in panel._nodes:
		if (panel._nodes[id] as Control).position.x > 900.0:
			far = id
			break
	if check(far != "", "fixture has a card outside the first view"):
		(panel._nodes[far] as Button).pressed.emit()
		var card: Control = panel._nodes[far]
		var t := panel._drag.target()
		check(card.position.x >= t.x and card.position.x + card.size.x <= t.x + 600.0, "timeline glides to the selected card")
	panel.free()
