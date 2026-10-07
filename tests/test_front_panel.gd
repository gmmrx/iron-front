extends "res://tests/test_case.gd"
## Cephe paneli: savaşta bizim tarafın ve düşmanın komşu bölgeleri cephedir; panel iki tarafın birliklerini ve muharebeyi
## gösterir, hava desteği düğmesi menzildeki boştaki kanadı o bölgeye yakın destek görevine yollar. Oyuncu Almanya.

func player_tag() -> String:
	return "GER"

## Almanya'nın elindeki bir bölge ve ona komşu Polonya bölgesi (cephe)
func _front_pair() -> Array:
	for pid: int in range(1, World.provinces.size()):
		var p := World.province(pid)
		if p == null or not p.is_land() or World.controller_tag(pid) != "GER":
			continue
		for n in World.land_neighbors(pid):
			if World.controller_tag(n) == "POL":
				return [pid, n]
	return []

func test_front_sides_and_air_support() -> void:
	eq(FrontPanel.side("GER"), 1, "oyuncu bizim tarafta")
	eq(FrontPanel.side("POL"), 0, "barışta komşu tarafsız")
	country("GER").war_goals["POL"] = true
	Diplomacy.declare_war("GER", "POL")
	eq(FrontPanel.side("POL"), 2, "savaşta düşman tarafında")
	var fp := _front_pair()
	if not check(not fp.is_empty(), "Almanya–Polonya cephesi"):
		return
	var panel := FrontPanel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.show_front(fp[0], fp[1])
	check(panel.visible, "cepheye tıklayınca panel açılır")
	check(panel._title.text.contains(Air.zone_name(fp[0])), "başlıkta bizim bölge")
	# hava desteği: menzildeki boştaki kanat yakın destek görevine
	var w := FrontPanel.pick_wing("GER", panel.target(), AirWing.Mission.CAS)
	if check(w != null, "menzilde boştaki kanat var"):
		check(not panel._cas.disabled, "hava desteği düğmesi açık")
		panel._send(AirWing.Mission.CAS)
		eq(int(w.mission), int(AirWing.Mission.CAS), "kanat yakın destek görevinde")
		check(Air.covers(w, panel.target()), "kanat cepheyi kaplar")
		check(FrontPanel.pick_wing("GER", panel.target(), AirWing.Mission.CAS) != w, "aynı kanat yeniden gönderilmez")
	# cephe kalkınca (bölge el değiştirdi) panel kapanır
	World.set_controller(fp[1], "GER")
	panel.refresh()
	check(not panel.visible, "cephe kalkınca panel kapanır")
	panel.free()
