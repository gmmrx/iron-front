class_name CloudFog
extends Node3D
## Savaş sisinin keşif maskesi (assets/shaders/fog_mask): CELL pikselik hücre ızgarasında keşfedilmemiş payı, GPU'da
## yalnız keşif değişince bir kez çizilir; doğrusal süzülünce bölge sınırında yumuşak geçiş verir. Harita gölgelendiricisi
## keşfedilmemiş yerde nötr sis tabanı çizer; üstte iki istemcinin ortak yoğunluk alanıyla hacimli bulut bulunur.

const CELL := 16.0                    ## maske hücresi (harita pikseli): dünya haritasında 1024 × 507
const Y0 := 70.0                      ## tabakanın altı (dağlar en çok ~60, Himalaya bulutu deler)
const Y1 := 240.0                     ## yaklaşınca kamera gerçekten bu hacmin içinden geçer
const MASK_SHADER := preload("res://assets/shaders/fog_mask.gdshader")
const VOLUME := true
const VOLUME_SHADER := preload("res://assets/shaders/fog_volume.gdshader")

var _mask_vp: SubViewport
var _mask_mat: ShaderMaterial
var _mat: ShaderMaterial
var _mi: MeshInstance3D

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
	if not VOLUME:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = VOLUME_SHADER
	UnitModels.compat_material(_mat)
	_mat.set_shader_parameter("mask_tex", _mask_vp.get_texture())
	_mat.set_shader_parameter("noise_tex", _noise())
	_mat.set_shader_parameter("map_size", map_size)
	_mat.set_shader_parameter("wrap_x", wrap)
	_mat.set_shader_parameter("y0", Y0)
	_mat.set_shader_parameter("y1", Y1)
	_mat.set_shader_parameter("steps", 20 if UnitModels.COMPAT else 28)
	var box := BoxMesh.new()
	box.size = Vector3(map_size.x * (3.0 if wrap else 1.0), Y1 - Y0, map_size.y)
	_mi = MeshInstance3D.new()
	_mi.mesh = box
	_mi.material_override = _mat
	_mi.position = Vector3(map_size.x / 2.0, (Y0 + Y1) / 2.0, map_size.y / 2.0)
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.custom_aabb = AABB(Vector3(-map_size.x, -100.0, -map_size.y), Vector3(map_size.x * 3.0, 400.0, map_size.y * 3.0))
	_mi.visible = false
	add_child(_mi)

## Web ile aynı periyodik 256 KiB alan; runtime noise iş parçacığı gerektirmez.
func _noise() -> ImageTexture3D:
	var bytes := FileAccess.get_file_as_bytes("res://assets/textures/fog_noise_64.bin")
	assert(bytes.size() == 64 * 64 * 64, "Cloud noise asset missing or truncated")
	var slices: Array[Image] = []
	for z in 64:
		slices.append(Image.create_from_data(64, 64, false, Image.FORMAT_R8, bytes.slice(z * 4096, (z + 1) * 4096)))
	var t := ImageTexture3D.new()
	t.create(Image.FORMAT_R8, 64, 64, 64, false, slices)
	return t

## Keşif değişti: maske yeniden çizilir, bulut görünür
func set_fog(fog_tex: Texture2D) -> void:
	_mask_mat.set_shader_parameter("fog_tex", fog_tex)
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _mi:
		_mi.visible = true

func clear() -> void:
	if _mi:
		_mi.visible = false

## Keşfedilmemiş payı dokusu (R), harita gölgelendiricisi için
func mask_texture() -> Texture2D:
	return _mask_vp.get_texture()
