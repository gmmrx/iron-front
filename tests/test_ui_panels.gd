extends "res://tests/test_case.gd"
## Panel davranışları (görünüm değil): program ağacında yakınlaştırma/kaydırma, diplomasi araması, ticaret panelinde
## otomatik ticaret hücresi, araştırmada ilerlemenin düğme zemini olarak dolması.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Program ağacı: imlecin altındaki yer yakınlaşırken yerinde kalır, sınırı aşmaz, geçiş yumuşak (bir karede sıçramaz)
func test_focus_tree_zoom_and_pan() -> void:
	var fp := FocusPanel.new()
	_tree().root.add_child(fp)
	fp.open()
	fp._view.size = Vector2(1200, 700)
	var cursor := Vector2(600, 300)
	var world_before := (cursor - fp._pan_t) / fp._zoom_t
	fp._zoom_at(cursor, FocusPanel.ZOOM_STEP)
	gt(fp._zoom_t, 1.0, "tekerlekle yakınlaşır")
	fp._process(1.0 / 60.0)
	check(fp._zoom < fp._zoom_t, "bir karede sıçramaz, yumuşakça gelir")
	for i in 120:
		fp._process(1.0 / 60.0)
	near(fp._zoom, fp._zoom_t, 0.002, "hedef yakınlığa varır")
	var world_after := (cursor - fp._pan) / fp._zoom
	lt(world_before.distance_to(world_after), 40.0, "imlecin altındaki yer yerinde kalır (kenar sınırı dışında)")
	for i in 40:
		fp._zoom_at(cursor, 1.0 / FocusPanel.ZOOM_STEP)
	near(fp._zoom_t, FocusPanel.ZOOM_MIN, 0.001, "en çok ZOOM_MIN'e kadar uzaklaşır")
	fp._pan_t = Vector2(99999, 99999)
	fp._process(1.0 / 60.0)
	lt(fp._pan_t.x, 99999.0, "ağaç görünümden kaçmaz")
	fp._fit()
	check(fp._zoom_t <= 1.0 and fp._zoom_t >= FocusPanel.ZOOM_MIN, "Sığdır ağacı gösterir")
	_tree().root.remove_child(fp)
	fp.free()

## Diplomasi: ülke listesi aranır (Türkçe harf ve büyük/küçük harf fark etmez, ülke koduyla da); bayraklar tek boy
func test_diplomacy_search() -> void:
	var dp := DiplomacyPanel.new()
	_tree().root.add_child(dp)
	dp.open()
	var shown := func() -> Array:
		var out: Array = []
		for e: Array in dp._list:
			if (e[0] as Button).visible:
				out.append(e[2])
		return out
	gt((shown.call() as Array).size(), 20, "arama boşken bütün ülkeler")
	dp._search.text = "letonya"
	dp._filter()
	check("LAT" in shown.call(), "'letonya' Letonya'yı bulur: %s" % str(shown.call()))
	dp._search.text = "isvec"
	dp._filter()
	check(not "SWE" in shown.call(), "savaşa katılmayan İsveç listede yok")
	dp._search.text = "SOV"
	dp._filter()
	check("SOV" in shown.call(), "ülke koduyla bulunur")
	var sizes := {}
	for e: Array in dp._list:
		var tex: Texture2D = (e[0] as Button).icon
		sizes[Vector2i(tex.get_width(), tex.get_height())] = true
	eq(sizes.size(), 1, "bütün bayraklar aynı boyda")
	_tree().root.remove_child(dp)
	dp.free()

## Ticaret: otomatik ticaret öbür özetler gibi bir hücre; yanındaki düğme açar/kapatır, hücre durumu söyler
func test_trade_auto_cell() -> void:
	var tp := TradePanel.new()
	_tree().root.add_child(tp)
	tp.open()
	var c := player()
	check(not c.auto_trade, "oyuncuda kapalı başlar")
	eq(tp._cells[4].text, tr("TRD_AUTO_STATE_OFF"), "hücre kapalı diyor")
	tp._auto.pressed.emit()
	check(c.auto_trade, "düğme açar")
	eq(tp._cells[4].text, tr("TRD_AUTO_STATE_ON"), "hücre açık diyor")
	tp._auto.pressed.emit()
	check(not c.auto_trade, "düğme kapatır")
	_tree().root.remove_child(tp)
	tp.free()

## Araştırma: ilerleme düğmenin arkasında dolar (yazının arkasında), ilerleme oranında
func test_research_progress_fill() -> void:
	var b := Button.new()
	b.text = "x"
	ResearchPanel._progress_back(b, StyleBoxEmpty.new(), 0.4)
	var fills := b.get_children().filter(func(n: Node) -> bool: return n is TextureRect)
	if check(fills.size() == 1, "dolgu var"):
		var f: TextureRect = fills[0]
		check(f.show_behind_parent, "dolgu yazının arkasında")
		near(f.anchor_right, 0.4, 0.001, "ilerleme oranında dolar")
	b.free()
