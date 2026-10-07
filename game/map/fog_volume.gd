class_name CloudFog
extends Node3D
## Savaş sisinin keşif maskesi (assets/shaders/fog_mask): CELL pikselik hücre ızgarasında keşfedilmemiş payı, GPU'da
## yalnız keşif değişince bir kez çizilir; doğrusal süzülünce bölge sınırında yumuşak geçiş verir. Harita gölgelendiricisi
## keşfedilmemiş yerde hafif nötr renk çizer. Atmosfer bulutları ayrı bir katmandır; keşif hiçbir buluta bağlı değildir.

const CELL := 16.0                    ## maske hücresi (harita pikseli): dünya haritasında 1024 × 507
const MASK_SHADER := preload("res://assets/shaders/fog_mask.gdshader")

var _mask_vp: SubViewport
var _mask_mat: ShaderMaterial

func setup(province_tex: Texture2D, map_size: Vector2, wrap: bool) -> void:
	var grid := Vector2i(ceili(map_size.x / CELL), ceili(map_size.y / CELL))
	_mask_mat = ShaderMaterial.new()
	_mask_mat.shader = MASK_SHADER
	_mask_mat.set_shader_parameter("province_tex", province_tex)
	_mask_mat.set_shader_parameter("map_size", map_size)
	_mask_mat.set_shader_parameter("grid", Vector2(grid))
	_mask_mat.set_shader_parameter("cell", CELL)
	_mask_mat.set_shader_parameter("wrap_x", wrap)
	_mask_vp = SubViewport.new()
	_mask_vp.size = grid
	_mask_vp.disable_3d = true
	_mask_vp.transparent_bg = false
	_mask_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	rect.size = Vector2(grid)
	rect.material = _mask_mat
	_mask_vp.add_child(rect)
	add_child(_mask_vp)

## Keşif değişti: yalnız küçük maske bir kez yeniden çizilir.
func set_fog(fog_tex: Texture2D) -> void:
	_mask_mat.set_shader_parameter("fog_tex", fog_tex)
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## Eski çağrı sözleşmesi: görünüm geçişini artık haritanın fog_fade değeri yönetir.
func set_fade(_f: float) -> void:
	pass

## Pahalı bulut hacmi yok: ilk çizim için çok kareli hazırlık gerekmiyor.
func prewarm(_frames: int) -> void:
	pass

func clear() -> void:
	if _mask_vp:
		_mask_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

## Keşfedilmemiş payı dokusu (R), harita gölgelendiricisi için
func mask_texture() -> Texture2D:
	return _mask_vp.get_texture()
