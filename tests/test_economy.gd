extends "res://tests/test_case.gd"
## Ekonomi: inşaat, bina yuvası, kamu inşaat tabanı, üretim verimliliği, kaynak açığı, tüketim malı.

## Oyuncunun (TUR) boş yuvası en çok olan eyaleti
func _roomy_state(c: Country) -> StateRegion:
	var best: StateRegion = null
	for sid in c.states:
		var st: StateRegion = World.states[sid]
		if best == null or st.free_slots() > best.free_slots():
			best = st
	return best

func test_construction_progresses_and_completes() -> void:
	var c := player()
	var st: StateRegion = World.states[c.capital_state]
	var level0 := st.building_level("infrastructure")
	check(Economy.queue_building(c, st, "infrastructure"), "başkente altyapı kuyruğa eklenmeli")
	var p: ConstructionProject = c.construction_queue.back()
	var free := Economy.available_civilian(c)
	eq(p.assigned_factories, mini(free, int(Economy.params["max_factories_per_project"])), "projeye atanan sivil fabrika")
	days(1)
	var infra := 1.0 + level0 * float(Economy.params["infrastructure_speed_bonus"])
	var speed := maxf(1.0 + c.mod("construction_speed") + Politics.stability_output_penalty(c), 0.1)
	near(p.progress, p.assigned_factories * float(Economy.params["civ_factory_output"]) * infra * speed, 0.01, "bir günlük ilerleme formülü")
	gt(p.progress, 0.0, "inşaat ilerler")
	p.progress = p.cost - 0.01
	days(1)
	eq(st.building_level("infrastructure"), level0 + 1, "bitince altyapı seviyesi")
	check(not p in c.construction_queue, "biten proje kuyruktan çıkar")

func test_building_slot_limit() -> void:
	var c := player()
	var st := _roomy_state(c)
	var free := st.free_slots()
	gt(free, 0, "boş yuvalı eyalet")
	var queued := 0
	for i in free + 3:
		if Economy.queue_building(c, st, "civilian_factory"):
			queued += 1
	eq(queued, free, "kuyruğa eklenebilen fabrika = boş yuva")
	eq(Economy.can_build(c, st, "civilian_factory"), "BUILD_ERR_SLOTS", "yuva dolunca hata nedeni")
	eq(Economy.can_build(c, st, "military_factory"), "BUILD_ERR_SLOTS", "ortak yuva askerî fabrikayı da kapatır")
	eq(Economy.can_build(c, st, "infrastructure"), "", "altyapı yuva kullanmaz")

func test_building_max_level_and_owner() -> void:
	var c := player()
	var st: StateRegion = World.states[c.capital_state]
	var max_infra := int(Economy.defs["infrastructure"]["max"])
	var n := 0
	while Economy.queue_building(c, st, "infrastructure"):
		n += 1
	eq(st.building_level("infrastructure") + n, max_infra, "altyapı en çok seviyesine kadar kuyruğa girer")
	eq(Economy.can_build(c, st, "infrastructure"), "BUILD_ERR_MAX", "tavanda hata nedeni")
	var foreign: StateRegion = World.states[country("GER").capital_state]
	eq(Economy.can_build(c, foreign, "infrastructure"), "BUILD_ERR_OWNER", "başka ülkenin eyaletine inşaat yok")

## Tüketim malı ve ithalat her fabrikayı yutsa da en az 1 fabrikalık kamu inşaatı sürer
func test_public_construction_floor() -> void:
	var c := player()
	c.trade_factories_paid = 1000
	eq(Economy.available_civilian(c), 1, "taban: 1 sivil fabrika")
	var st: StateRegion = World.states[c.capital_state]
	check(Economy.queue_building(c, st, "infrastructure"), "kuyruğa ekle")
	var p: ConstructionProject = c.construction_queue.back()
	eq(p.assigned_factories, 1, "projeye 1 fabrika")
	Economy._on_day_impl()
	gt(p.progress, 0.0, "tabanla inşaat ilerler")

func test_production_efficiency_grows_to_cap() -> void:
	var c := player()
	c.production_lines.clear()          # tüm askerî fabrikalar boşta: yeni hat fabrika alır
	var l: ProductionLine = Economy.add_line(c, "infantry_equipment")
	gt(l.factories, 0, "yeni hatta fabrika")
	var start := float(Economy.prod["efficiency_start"])
	var cap := float(Economy.prod["efficiency_cap"]) + c.mod("production_efficiency_cap")
	near(l.efficiency, start, 0.0001, "yeni hattın verimliliği")
	var prev := l.efficiency
	Economy._produce(c)
	gt(l.efficiency, prev, "bir günde verimlilik artar")
	near(l.efficiency - prev, float(Economy.prod["efficiency_gain_per_day"]) * (cap - prev) / cap, 0.00001, "artış formülü")
	for i in 3000:
		Economy._produce(c)
	check(l.efficiency <= cap + 0.00001, "verimlilik tavanı aşmaz (%.4f > %.4f)" % [l.efficiency, cap])
	gt(l.efficiency, cap - 0.01, "uzun sürede tavana yaklaşır")
	# fabrikasız hat verimlilik kazanmaz
	var idle: ProductionLine = Economy.add_line(c, "artillery_equipment")
	idle.factories = 0
	var e0 := idle.efficiency
	Economy._produce(c)
	eq(idle.efficiency, e0, "fabrikasız hattın verimliliği sabit")

## Kaynak yoksa hat yalnız taban oranında (resource_shortage_floor) üretir
func test_resource_shortage_slows_output() -> void:
	var c := player()
	c.production_lines.clear()
	var l: ProductionLine = Economy.add_line(c, "infantry_equipment")
	l.factories = 5
	l.efficiency = 0.3
	c.imports = []
	c.exports = []
	# bol çelik
	var cap: StateRegion = World.states[c.capital_state]
	cap.resources["steel"] = 1000
	Economy.invalidate_counts()
	Economy._produce(c)
	var full := l.last_output
	near(l.resource_fraction, 1.0, 0.0001, "kaynak tam")
	# hiç çelik yok
	for sid in c.states:
		World.states[sid].resources.erase("steel")
	Economy.invalidate_counts()
	l.efficiency = 0.3
	Economy._produce(c)
	near(l.resource_fraction, 0.0, 0.0001, "kaynak yok")
	gt(full, 0.0, "tam kaynakta üretim")
	near(l.last_output / full, float(Economy.prod["resource_shortage_floor"]), 0.01, "açıkta üretim oranı = taban")

func test_consumer_goods_follow_law_and_stability() -> void:
	var c := player()
	c.stability = 0.5
	c.laws["economy"] = "peacetime_economy"
	var civ_law := Economy.consumer_goods_factories(c)
	c.laws["economy"] = "war_economy"
	var war_law := Economy.consumer_goods_factories(c)
	check(war_law < civ_law, "savaş ekonomisinde tüketim malı barıştan az (%d < %d)" % [war_law, civ_law])
	c.laws["economy"] = "peacetime_economy"
	var total := Economy.count(c, "civilian_factory") + Economy.count(c, "military_factory")
	c.stability = 0.0
	var low := Economy.consumer_goods_factories(c)
	eq(low, mini(int(round(total * maxf((float(Economy.law_def("economy", "peacetime_economy")["consumer_goods"]) + c.mod("consumer_goods_mod")) * Politics.stability_consumer_factor(c), 0.05))), Economy.count(c, "civilian_factory")), "tüketim malı formülü")
	c.stability = 1.0
	var high := Economy.consumer_goods_factories(c)
	check(high <= low, "yüksek istikrarda tüketim malı azalır ya da aynı kalır (%d <= %d)" % [high, low])
	lt(Politics.stability_consumer_factor(c), 1.0, "istikrar %100'de tüketim çarpanı < 1")
