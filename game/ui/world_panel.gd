class_name WorldPanel
extends PanelContainer
## Dünya olayları (E): dünyada olanların akışı, en yenisi üstte — ülke bayrağı, metin, tarih ve tür. Süzgeç: komşularım /
## ittifakım / bütün dünya. Satıra tıklayınca harita oraya gider. Oyuncunun taraf olmadığı savaş ilanlarına ve ilhaklara
## süresi içinde seçeneklerle cevap verilir (WorldReact; bedel ve etkiler ipucunda). Bildirim akışı oyuncunun kendi
## işleri için kalır; bu menü dünyanın geri kalanıdır.

signal goto(world_pos: Vector2)

const SHOW_MAX := 120
const FILTER_NEAR := 0
const FILTER_ALLY := 1
const FILTER_ALL := 2

var filter := FILTER_ALL
var _list: VBoxContainer
var _dirty := false
var _near_day := -1
var _near := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_list = PanelLayout.frame(self, tr("WORLD_TITLE"), "diplomacy", 460.0)
	var top := PanelLayout.fixed(self)
	PanelLayout.tabs(top, [tr("WORLD_FILTER_NEAR"), tr("WORLD_FILTER_ALLY"), tr("WORLD_FILTER_ALL")], func(i: int) -> void:
		filter = i
		refresh(), filter)
	World.world_logged.connect(func(_e: Dictionary) -> void:
		if visible: _dirty = true)
	World.daily_update.connect(func() -> void:
		if visible: _dirty = true)          # kalan cevap süresi

func _process(_delta: float) -> void:
	if _dirty and visible:
		_dirty = false
		refresh()

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	var shown := 0
	for i in range(World.world_log.size() - 1, -1, -1):
		var e: Dictionary = World.world_log[i]
		if not passes(e):
			continue
		_row(e)
		shown += 1
		if shown >= SHOW_MAX:
			break
	if shown == 0:
		PanelLayout.empty(_list, tr("WORLD_EMPTY"))

## Kayıt süzgeçten geçer mi: komşularım (oyuncu ya da sınır komşusu), ittifakım (oyuncu ya da müttefiki), bütün dünya
func passes(e: Dictionary) -> bool:
	if filter == FILTER_ALL:
		return true
	var me := World.player_tag
	for t: Variant in e.get("tags", []):
		var tag := str(t)
		if tag == me:
			return true
		if filter == FILTER_ALLY and Diplomacy.are_allies(tag, me):
			return true
		if filter == FILTER_NEAR and neighbours().has(tag):
			return true
	return false

## Oyuncunun kara sınırı komşuları (günde bir hesaplanır)
func neighbours() -> Dictionary:
	if _near_day == World.day_count:
		return _near
	_near_day = World.day_count
	_near.clear()
	var me: Country = World.player()
	if me == null:
		return _near
	for sid: int in me.states:
		for pid: int in World.states[sid].provinces:
			for n: int in World.land_neighbors(pid):
				var st: StateRegion = World.states.get(World.province(n).state_id)
				if st and st.owner != me.tag:
					_near[st.owner] = true
	return _near

func _row(e: Dictionary) -> void:
	var tags: Array = e.get("tags", [])
	var c: Country = World.countries.get(str(tags[0])) if not tags.is_empty() else null
	var can_react := WorldReact.is_open(e)
	var sub := "%s · %s" % [_date_text(int(e.get("date", 0))), tr("WORLD_KIND_" + str(e.get("kind", "")))]
	var col := PanelLayout.row(_list, FlagFactory.get_flag(c) if c else null, World.world_text(e), sub, tr("WORLD_GOTO"),
		"SlotGold" if can_react else "Row")
	var pc := col.get_parent().get_parent() as Control
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			goto.emit(place(e)))
	if e.has("choice"):
		var o := WorldReact.option(e, str(e["choice"]))
		if not o.is_empty():
			col.add_child(UiTheme.make_label(tr("WORLD_CHOSEN") % Politics.loc(o["name"]), 14, UiTheme.ACCENT))
	elif can_react:
		var days := int((WorldReact.data()[str(e["react"])] as Dictionary).get("days", 30)) - (World.day_count - int(e["day"]))
		col.add_child(UiTheme.make_label(tr("WORLD_REACT") % maxi(days, 0), 14, UiTheme.ACCENT))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		col.add_child(h)
		var me := World.player()
		for o: Dictionary in WorldReact.options(e):
			var why := WorldReact.block(me, e, o) if me else "?"
			var tip := WorldReact.describe(e, o)
			if why != "":
				tip += "\n\n⚠ " + why
			var id := str(o["id"])
			var b := PanelLayout.small_button(Politics.loc(o["name"]), func() -> void:
				if WorldReact.choose(e, id):
					refresh(), why == "", tip)
			h.add_child(b)

## Kaydın haritadaki yeri: olayın bölgesi, yoksa ilk ülkenin başkenti
static func place(e: Dictionary) -> Vector2:
	var pid := int(e.get("pid", 0))
	if pid > 0 and World.province(pid) != null:
		return World.province(pid).center
	var tags: Array = e.get("tags", [])
	return World.capital_position(str(tags[0])) if not tags.is_empty() else World.capital_position(World.player_tag)

static func _date_text(v: int) -> String:
	if v <= 0:
		return ""
	return "%d %s %d" % [v % 100, TranslationServer.translate("MONTH_%d" % ((v / 100) % 100)), v / 10000]
