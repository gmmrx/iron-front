class_name Tutorial
extends PanelContainer
## Öğretici (data/common/tutorial.json): alt ortada küçük bir rehber kartı. Her adım tek bir iş söyler, gerekiyorsa
## haritada yeri ("Göster": kamerayı oraya götürür) ve arayüzde düğmeyi (nabız atar) gösterir, sonra bekler. Adım oyunun
## durumundan geçer (_done); oyuncu önceden yaptıysa kendiliğinden geçilir. Öğretici oyuncu adına hiçbir oyun eylemi
## yapmaz: yalnız okur, oyunu durdurur ve kamerayı (oyuncu "Göster"e basınca) götürür.

const DATA_PATH := "res://data/common/tutorial.json"
const WIDTH := 560.0
const CHECK_EVERY := 0.25

var camera: MapCamera3D
var units: UnitLayer
var hud: Hud

var _data: Dictionary = {}
var _steps: Array = []
var _chapter: Label
var _count: Label
var _text: RichTextLabel
var _show_btn: Button
var _next_btn: Button
var _timer := 0.0
var _pressed_next := false
var _baseline := 0
var _pulse: Tween
var _pulsed: CanvasItem

static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

## Yeni öğretici: tarihî Habeşistan savaşı açık başlar (Ocak 1936'da sürüyordu). Oyuncunun kararı değil, başlangıç durumu.
static func begin_war() -> void:
	var d := data()
	var a: Country = World.countries.get(String(d["country"]))
	if a == null or Diplomacy.are_enemies(a.tag, String(d["enemy"])):
		return
	a.war_goals[String(d["enemy"])] = "ready"
	Diplomacy.declare_war(a.tag, String(d["enemy"]))

func _ready() -> void:
	_data = data()
	_steps = _data["steps"]
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", TopBar.skin_box(22, 18) if TopBar.SELECT_SKIN else UiTheme.material_panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_chapter = UiTheme.make_label("", 18, UiTheme.ACCENT)
	_chapter.add_theme_font_override("font", UiTheme.title_font())
	_chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_chapter)
	_count = UiTheme.make_label("", 15, UiTheme.TEXT_DIM)
	head.add_child(_count)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size.x = WIDTH - 44.0
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("bold_font_size", 21)
	_text.add_theme_font_override("bold_font", UiTheme.bold_font())
	_text.add_theme_color_override("default_color", UiTheme.TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var quit := PanelLayout.small_button(tr("TUT_QUIT"), _finish)
	quit.tooltip_text = tr("TIP_TUT_QUIT")
	row.add_child(quit)
	var skip := PanelLayout.small_button(tr("TUT_SKIP_STEP"), func() -> void: _advance())
	skip.tooltip_text = tr("TIP_TUT_SKIP_STEP")
	row.add_child(skip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_show_btn = PanelLayout.small_button(tr("TUT_SHOW"), _show_target)
	_show_btn.tooltip_text = tr("TIP_TUT_SHOW")
	row.add_child(_show_btn)
	_next_btn = PanelLayout.small_button(tr("TUT_NEXT"), func() -> void: _pressed_next = true)
	row.add_child(_next_btn)
	get_viewport().size_changed.connect(_place)
	resized.connect(_place)
	_enter()

func _place() -> void:
	var vs := get_viewport_rect().size
	size = get_combined_minimum_size()
	position = Vector2((vs.x - size.x) * 0.5, vs.y - size.y - 24.0)

func _step() -> Dictionary:
	return _steps[clampi(Game.tutorial, 0, _steps.size() - 1)]

func _enter() -> void:
	if Game.tutorial < 0 or Game.tutorial >= _steps.size():
		_finish()
		return
	var s := _step()
	_pressed_next = false
	_chapter.text = tr("TUT_CH_" + String(s["chapter"])).to_upper()
	_count.text = "%d / %d" % [Game.tutorial + 1, _steps.size()]
	_text.text = tr("TUT_" + String(s["id"]))
	_next_btn.visible = bool(s.get("next", false))
	_next_btn.text = tr("TUT_DONE") if Game.tutorial == _steps.size() - 1 else tr("TUT_NEXT")
	_show_btn.visible = String(s.get("target", "")) != ""
	if bool(s.get("pause", false)):
		GameClock.set_paused(true)
	_baseline = _training_count()
	_set_pulse(_highlight_node(String(s.get("highlight", ""))))
	_place.call_deferred()

func _advance() -> void:
	_set_pulse(null)
	Game.tutorial += 1
	if Game.tutorial >= _steps.size():
		_finish()
		return
	Audio.play("order_move", 150)
	_enter()

func _finish() -> void:
	_set_pulse(null)
	Game.tutorial = -1
	queue_free()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or Game.tutorial < 0:
		return
	_timer = CHECK_EVERY
	if _done(_step()):
		_advance()

# ------------------------------------------------------------------ koşullar (yalnız okur)
func _done(s: Dictionary) -> bool:
	var me := World.player_tag
	match String(s["done"]):
		"next":
			return _pressed_next
		"camera_near_front":
			var f := _target_pos("front")
			return camera.distance < 1000.0 and Vector2(camera.target.x, camera.target.z).distance_to(f) < 450.0
		"camera_figures":
			return camera.distance <= UnitLayer.CARD_DIST
		"selected":
			return units.selected.any(func(d: Division) -> bool: return d.owner == me)
		"estimate_seen":
			return hud.tooltip.visible and (hud.tooltip.order_odds.has("ratio") or hud.tooltip.order_odds.has("empty"))
		"attack_ordered":
			for d: Division in Military.country_divisions(me):
				if d.attacking > 0:
					return true
				if not d.path.is_empty() and World.controller_tag(d.path[d.path.size() - 1]) != me:
					return true
			return false
		"running":
			return not GameClock.paused
		"battle":
			for pid: int in Military.battles:
				var b: Dictionary = Military.battles[pid]
				for side: String in ["attackers", "defenders"]:
					for d: Division in b[side]:
						if d.owner == me:
							return true
			return false
		"motivated":
			return Military.country_divisions(me).any(func(d: Division) -> bool: return Military.motivated(d))
		"province_taken":
			var foe := String(_data["enemy"])
			for p: Province in World.provinces:
				if p == null:
					continue
				var o := World.owner_of_province(p.id)
				if o and o.tag == foe and World.controller_tag(p.id) == me:
					return true
			return false
		"own_state_open":
			var sid: int = hud.state_panel._state_id
			return hud.state_panel.visible and sid > 0 and World.states[sid].owner == me
		"recruited":
			return _training_count() > _baseline
	return false

func _training_count() -> int:
	return Military.country_divisions(World.player_tag).filter(func(d: Division) -> bool: return d.training > 0).size()

# ------------------------------------------------------------------ yerler
## front: düşmana komşu bölgedeki tümenimiz; enemy: ona komşu düşman bölgesi; city: düşmana en yakın şehrimiz
func _target_pos(kind: String) -> Vector2:
	var me := World.player_tag
	var foe := String(_data["enemy"])
	match kind:
		"front", "enemy":
			for d: Division in Military.country_divisions(me):
				for n in World.land_neighbors(d.province):
					var o := World.owner_of_province(n)
					if o and o.tag == foe and World.controller_tag(n) == foe:
						return World.province(n if kind == "enemy" else d.province).center
		"city":
			var at := World.province(World.capital_province(foe)).center
			var best := Vector2.INF
			for c: City in World.cities:
				if World.controller_tag(c.province_id) == me and (best == Vector2.INF or c.position.distance_to(at) < best.distance_to(at)):
					best = c.position
			if best != Vector2.INF:
				return best
	return World.capital_position(me)

func _show_target() -> void:
	var kind := String(_step().get("target", ""))
	if kind == "":
		return
	camera.fly_to(_target_pos(kind), minf(camera.distance, 600.0 if kind != "city" else 300.0), 1.0)

# ------------------------------------------------------------------ vurgu
func _highlight_node(id: String) -> CanvasItem:
	match id:
		"clock":
			return hud.top_bar._play_btn
		"motivate":
			return hud.divisions._motivate_btn
		"alerts":
			return hud.top_bar.alert_strip
	return null

## Arayüz öğesi yavaşça aydınlanıp söner (üstüne gelinmiş düğmenin tonu); adım geçince eski haline döner
func _set_pulse(node: CanvasItem) -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	if _pulsed and is_instance_valid(_pulsed):
		_pulsed.modulate = Color.WHITE
	_pulsed = node
	if node == null or not is_instance_valid(node):
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(node, "modulate", Color(1.45, 1.3, 0.95), 0.6).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(node, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
