class_name CountryRim
extends Node
## Ülke sınırına yakınlık alanı: siyasi haritada ülke rengi içeride yarı saydam, sınıra yaklaştıkça koyulaşır. Sahiplik
## oyunda değiştiği için önceden hesaplanamaz; GPU'da, haritanın CELL pikselik hücre ızgarasında iki geçişle kurulur
## (assets/shaders/rim_edge, rim_dist) ve yalnız sahiplik değişince yenilenir (iki kare sürer; o arada eski alan
## görünür). Sonuç `texture` (R: 1 sınırda, RADIUS hücre içeride 0), map3d.gdshader'da rim_tex.

const CELL := 16.0                    ## hücre boyu (harita pikseli): dünya haritasında 1024 × 507 ızgara
const RADIUS := 6                     ## alanın genişliği (hücre): ~96 harita pikseli ≈ 1-2 bölge derinliği
const EDGE_SHADER := preload("res://assets/shaders/rim_edge.gdshader")
const DIST_SHADER := preload("res://assets/shaders/rim_dist.gdshader")

var texture: Texture2D
var _edge: SubViewport
var _dist: SubViewport
var _edge_mat: ShaderMaterial
var _step := 0                        ## 0 boşta; 1 kenar geçişi bu karede; 2 uzaklık geçişi bu karede

func setup(province_tex: Texture2D, data_tex: Texture2D, map_size: Vector2, wrap: bool) -> void:
	var grid := Vector2i(ceili(map_size.x / CELL), ceili(map_size.y / CELL))
	_edge_mat = ShaderMaterial.new()
	_edge_mat.shader = EDGE_SHADER
	_edge_mat.set_shader_parameter("province_tex", province_tex)
	_edge_mat.set_shader_parameter("data_tex", data_tex)
	_edge_mat.set_shader_parameter("map_size", map_size)
	_edge_mat.set_shader_parameter("grid", Vector2(grid))
	_edge_mat.set_shader_parameter("cell", CELL)
	_edge_mat.set_shader_parameter("wrap_x", wrap)
	_edge = _pass(grid, _edge_mat)
	var dm := ShaderMaterial.new()
	dm.shader = DIST_SHADER
	dm.set_shader_parameter("edge_tex", _edge.get_texture())
	dm.set_shader_parameter("grid", Vector2(grid))
	dm.set_shader_parameter("radius", RADIUS)
	dm.set_shader_parameter("wrap_x", wrap)
	_dist = _pass(grid, dm)
	texture = _dist.get_texture()
	_step = 1

## Bölge verisi dokusu yeniden kurulduysa (satır sayısı değişti) yenisi
func set_data_texture(data_tex: Texture2D) -> void:
	if _edge_mat:
		_edge_mat.set_shader_parameter("data_tex", data_tex)

## Sahiplik ya da denetim değişti: alan iki karede yeniden hesaplanır (savaşta cephe saatte birçok kez kayar: en çok
## REFRESH_GAP saniyede bir)
const REFRESH_GAP := 0.4
var _pending := false
var _since := 0.0
func refresh() -> void:
	_pending = true

func _process(delta: float) -> void:
	_since += delta
	if _pending and _step == 0 and _since >= REFRESH_GAP:
		_pending = false
		_since = 0.0
		_step = 1
	if _step == 1:
		_edge.render_target_update_mode = SubViewport.UPDATE_ONCE
		_step = 2
	elif _step == 2:
		# kenar geçişi bir önceki karede çizildi; uzaklık onun üstünden
		_dist.render_target_update_mode = SubViewport.UPDATE_ONCE
		_step = 0

func _pass(grid: Vector2i, mat: ShaderMaterial) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = grid
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	rect.size = Vector2(grid)
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	return vp
