extends "res://tests/test_case.gd"
## Panel davranışları (görünüm değil): program ağacında yakınlaştırma/kaydırma, diplomasi araması, ticaret panelinde
## otomatik ticaret hücresi, araştırmada ilerlemenin düğme zemini olarak dolması.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Program ağacı: imlecin altındaki yer yakınlaşırken yerinde kalır, sınırı aşmaz, geçiş yumuşak (bir karede sıçramaz)
func test_focus_tree_is_inert_and_never_opens() -> void:
	var fp := FocusPanel.new()
	_tree().root.add_child(fp)
	fp.open()
	check(not fp.visible, "Devlet Programı hiçbir açma çağrısında görünmez")
	eq(fp.get_child_count(), 0, "kapalı özellik için ağaç/kart/resim oluşturulmaz")
	check(not fp.is_processing() and not fp.is_processing_input(), "kapalı panel girdi ve animasyon tüketmez")
	fp.visible = true
	fp.refresh()
	check(not fp.visible, "legacy doğrudan refresh de paneli gösteremez")
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
	# görünen ad oyunun dilinde (ayarsız açılış İngilizce): aranan da o dilde, büyük/küçük harf ve Türkçe harf farkı yok
	var lat_name: String = World.countries["LAT"].display_name()
	dp._search.text = lat_name.substr(0, 5).to_upper()
	dp._filter()
	check("LAT" in shown.call(), "'%s' %s'yı bulur: %s" % [dp._search.text, lat_name, str(shown.call())])
	dp._search.text = World.countries["SWE"].display_name()
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

## Üst çubuk (arayüz sayfasının parçalarıyla): ❚❚ duraklatır, ▶ sürdürür (akarken yavaşlatır), ▶▶ hızlandırır; hız
## çubuğu kademeyi gösterir; on gösterge hücresi sayfanın ikonlarıyla
func test_top_bar_speed_buttons() -> void:
	var tb := TopBar.new()
	_tree().root.add_child(tb)
	GameClock.set_paused(false)
	GameClock.set_speed(3)
	tb._pause_btn.pressed.emit()
	check(GameClock.paused, "❚❚ duraklatır")
	tb._play_btn.pressed.emit()
	check(not GameClock.paused, "▶ sürdürür")
	eq(GameClock.speed, 3, "duraklatılmışken ▶ hızı değiştirmez")
	tb._play_btn.pressed.emit()
	eq(GameClock.speed, 2, "akarken ▶ yavaşlatır")
	tb._fast_btn.pressed.emit()
	tb._fast_btn.pressed.emit()
	eq(GameClock.speed, 4, "▶▶ hızlandırır")
	tb._update_time_state()
	eq(int(tb._speed_bar.value), 4, "hız çubuğu kademede")
	check(tb.sheet("icon_political_power") != null and tb.sheet("date_frame") != null, "sayfa parçaları yüklenir")
	# savaşta değilken savaş hücresi ve önündeki ayraç gizli (çubuğun sonunda boş ayraç kalmaz)
	var war_cell := tb._cell_of(tb._war)
	check(not war_cell.visible and not (war_cell.get_meta("div") as Control).visible, "barışta savaş hücresi ve ayracı gizli")
	# portre çerçevenin içinin oranında, üstten kırpılır
	if UiTheme.portrait(World.player()) != null:
		var at := tb._flag.texture as AtlasTexture
		check(at != null and at.region.position.y < at.atlas.get_height() * 0.05, "portre üstten hizalı kırpılır")
	GameClock.set_paused(true)
	_tree().root.remove_child(tb)
	tb.free()
