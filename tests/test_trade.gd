extends "res://tests/test_case.gd"
## Ticaret: elle anlaşma, ödeme sınırı, düşmanla ticaret yok, otomatik ticaret varsayılanları, konvoy.

## Oyuncunun alabileceği (ihraç etmediği) ve satıcısı olan ilk kaynak: [kaynak, satıcı, arz]
func _deal(c: Country) -> Array:
	for r: String in ["oil", "rubber", "aluminium", "tungsten", "steel", "chromium"]:
		var exporting := false
		for ex: Dictionary in c.exports:
			if ex["res"] == r:
				exporting = true
		var sellers: Array = Economy.trade_sellers(c, r)
		if not exporting and not sellers.is_empty() and float(sellers[0][1]) >= 8.0:
			return [r, sellers[0][0], float(sellers[0][1])]
	return []

## İki ülke arasında (gerekçesiz) savaş: testler için doğrudan savaş kaydı
func _war(a: String, b: String) -> void:
	country(a).war_goals[b] = true
	Diplomacy.declare_war(a, b)

func test_auto_trade_defaults() -> void:
	check(not player().auto_trade, "oyuncunun otomatik ticareti kapalı başlar")
	var bad: Array = []
	for c: Country in World.countries.values():
		if c.tag != World.player_tag and not c.auto_trade:
			bad.append(c.tag)
	none(bad, "AI ülkesinde otomatik ticaret kapalı")
	eq(player().trade_orders.size(), 0, "oyuncunun başlangıçta anlaşması yok")

func test_manual_trade_adds_resource() -> void:
	var c := player()
	c.stockpile["convoy"] = 1000.0
	var d := _deal(c)
	if not check(not d.is_empty(), "satıcısı olan kaynak bulunmalı"):
		return
	var res: String = d[0]
	var seller: String = d[1]
	var before := float(Economy.resource_available(c).get(res, 0.0))
	var earned := c.trade_factories_earned
	check(Economy.add_trade(c, res, seller, 8.0), "anlaşma yapılır")
	var got := 0.0
	for im: Dictionary in c.imports:
		if im["res"] == res and im["from"] == seller:
			got += float(im["amount"])
	eq(got, 8.0, "satıcıdan gelen ithalat")
	near(float(Economy.resource_available(c).get(res, 0.0)) - before, 8.0, 0.001, "kullanılabilir kaynak artışı")
	eq(c.trade_factories_paid, 1, "8 kaynak = 1 sivil fabrika")
	var exp := 0.0
	for ex: Dictionary in country(seller).exports:
		if ex["to"] == c.tag and ex["res"] == res:
			exp += float(ex["amount"])
	eq(exp, 8.0, "satıcının ihracatında görünür")
	eq(c.trade_factories_earned, earned, "alıcı ihracat kazancı değişmez")

func test_unaffordable_trade_rejected() -> void:
	var c := player()
	var d := _deal(c)
	if not check(not d.is_empty(), "satıcısı olan kaynak bulunmalı"):
		return
	var spare := Economy.count(c, "civilian_factory") - Economy.consumer_goods_factories(c) + c.trade_factories_earned
	var too_much := (spare + 1) * Economy.RESOURCES_PER_TRADE_FACTORY
	check(not Economy.trade_affordable(c, too_much), "boştaki fabrikayı aşan anlaşma ödenemez")
	check(not Economy.add_trade(c, d[0], d[1], too_much), "ödenemeyen anlaşma reddedilir")
	eq(c.trade_orders.size(), 0, "reddedilen anlaşma kaydedilmez")

func test_no_trade_with_enemy() -> void:
	var c := player()
	c.stockpile["convoy"] = 1000.0
	var d := _deal(c)
	if not check(not d.is_empty(), "satıcısı olan kaynak bulunmalı"):
		return
	var seller: String = d[1]
	check(Economy.add_trade(c, d[0], seller, 8.0), "barışta anlaşma yapılır")
	_war(c.tag, seller)
	check(Diplomacy.are_enemies(c.tag, seller), "savaş başladı")
	var sellers: Array = Economy.trade_sellers(c, d[0]).map(func(x: Array) -> String: return x[0])
	check(not seller in sellers, "düşman satıcı listesinde yok")
	for im: Dictionary in c.imports:
		check(im["from"] != seller, "savaş başlayınca düşmandan ithalat biter")
	check(not Economy.add_trade(c, d[0], seller, 8.0), "düşmanla yeni anlaşma yapılmaz")

## Yapay zekânın otomatik ticareti düşmandan alıyor mu — bilinen durum (abluka dengeyi değiştirir, ROADMAP P1): uyarı
func test_ai_auto_trade_with_enemy_known() -> void:
	Economy._run_trade()
	var buyer: Country = null
	var seller := ""
	for c: Country in World.countries.values():
		if c.tag != World.player_tag and c.auto_trade and c.exists() and not c.imports.is_empty():
			buyer = c
			seller = str(c.imports[0]["from"])
			break
	if not check(buyer != null, "ithalat yapan AI ülkesi bulunmalı"):
		return
	_war(buyer.tag, seller)
	Economy._run_trade()
	var n := 0
	for im: Dictionary in buyer.imports:
		if Diplomacy.are_enemies(buyer.tag, str(im["from"])):
			n += 1
	if n > 0:
		warn("bilinen: yapay zekâ savaştığı ülkeden alıyor (%s ← %s); kesmek denge kararı" % [buyer.tag, seller])

func test_convoy_shortage_reduces_imports() -> void:
	var c := player()
	var d := _deal(c)
	if not check(not d.is_empty(), "satıcısı olan kaynak bulunmalı"):
		return
	c.stockpile["convoy"] = 1000.0
	check(Economy.add_trade(c, d[0], d[1], 8.0), "anlaşma")
	eq(Economy.convoy_factor(c), 1.0, "yeterli konvoy")
	var full := float(Economy.resource_available(c).get(d[0], 0.0))
	c.stockpile["convoy"] = 2.0          # 8 kaynak için 4 konvoy gerekir
	near(Economy.convoy_factor(c), 0.5, 0.0001, "konvoy yarısı kadar")
	near(full - float(Economy.resource_available(c).get(d[0], 0.0)), 4.0, 0.001, "ithalatın yarısı gelmez")
	c.stockpile["convoy"] = 0.0
	near(Economy.convoy_factor(c), 0.25, 0.0001, "konvoysuz taban %25")
