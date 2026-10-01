extends "res://tests/test_case.gd"

const TYPES := ["infantry", "motorized", "light_armor", "medium_armor", "artillery", "anti_tank", "plane", "ship"]

func test_generated_card_art_loads_with_transparency() -> void:
	for kind: String in TYPES:
		var path := "res://assets/ui/unit_cards/card_%s.png" % kind
		check(ResourceLoader.exists(path), "kart resmi mevcut: " + kind)
		var texture: Texture2D = load(path)
		var source := texture.get_image() if texture else null
		if not check(source != null, "PNG açılıyor: " + kind):
			continue
		eq(source.get_size(), Vector2i(1536, 1024), "yüksek çözünürlüklü kaynak: " + kind)
		check(source.detect_alpha() != Image.ALPHA_NONE, "şeffaf arka plan: " + kind)
		var glyph := UnitLayer.card_glyph(kind)
		check(glyph != null and not glyph.is_empty(), "kart resmi yükleniyor: " + kind)
		var plate := UnitLayer.plate_tex(World.player_tag, false, kind)
		eq(plate.get_size(), Vector2(UnitLayer.COUNTER_W, UnitLayer.COUNTER_H), "kart ölçüsü korundu: " + kind)

func test_submarine_retains_existing_fallback() -> void:
	var glyph := UnitLayer.card_glyph("submarine")
	check(glyph != null and not glyph.is_empty(), "denizaltı fallback resmi korunuyor")

func test_gold_engraving_preserves_alpha_and_lifts_midtones() -> void:
	var source := Color(0.38, 0.32, 0.22, 0.67)
	var gold := UnitLayer._engraving_ink(source)
	near(gold.a, source.a, 0.00001, "şeffaf kenarlar korunur")
	gt(gold.r, source.r + 0.2, "koyu sepya orta tonları görünür altına dönüşür")
	check(gold.r > gold.g and gold.g > gold.b, "sıcak altın palet")
	var shadow := UnitLayer._engraving_ink(Color(0.05, 0.05, 0.05))
	lt(shadow.r, 0.22, "koyu gravür çizgileri korunur")
