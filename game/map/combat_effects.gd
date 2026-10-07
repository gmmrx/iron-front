class_name CombatEffects
extends Node3D
## Shared, bounded visual combat system. Events never apply gameplay damage.
## Fixed batches, private cosmetic RNG, no particle/emitter nodes per shot.
signal impacted(at: Vector3, radius: float, heavy: bool)

const EXPLOSION_PATH := "res://assets/vfx/combat/explosion_flipbook.png"
const SMOKE_PATH := "res://assets/vfx/combat/smoke_atlas.png"
const WATER_PATH := "res://assets/vfx/combat/water_flipbook.png"
const CAPS := [256, 160, 48, 96] # alpha billboards, hot streaks, ground skirts, debris
const MAX_DISTANCE := 580.0
const MAX_TRAILS := 16
const MAX_LIGHTS := 3
enum Batch { SPRITE, GLOW, GROUND, DEBRIS }

class Particle:
	var batch := 0
	var kind := 0
	var age := 0.0
	var life := 1.0
	var start := Vector3.ZERO
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var accel := Vector3.ZERO
	var goal := Vector3.ZERO
	var size := Vector2.ONE
	var growth := 0.0
	var drag := 0.0
	var angle := 0.0
	var spin := 0.0
	var color := Color.WHITE
	var variant := 0
	var weapon := ""
	var hit_scale := 1.0
	var ground := 0.0
	var depth := 0.0

var map: Node3D
var camera: Camera3D
var _particles: Array[Particle] = []
var _counts := [0, 0, 0, 0]
var _batches: Array[MultiMeshInstance3D] = []
var _trails: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _light_life: Array[float] = []
var _light_power: Array[float] = []
var _rng := RandomNumberGenerator.new()
var dropped := 0
var emitted := 0
var textures_ready := false

func configure(map_ref: Node3D, camera_ref: Camera3D) -> void:
	map = map_ref
	camera = camera_ref

func _ready() -> void:
	_rng.randomize()
	var explosion := _load_texture(EXPLOSION_PATH)
	var smoke_tex := _load_texture(SMOKE_PATH)
	var water_tex := _load_texture(WATER_PATH)
	textures_ready = explosion != null and smoke_tex != null and water_tex != null
	var sprite := ShaderMaterial.new()
	sprite.shader = preload("res://assets/shaders/combat_sprite.gdshader")
	sprite.set_shader_parameter("explosion_atlas", explosion)
	sprite.set_shader_parameter("smoke_atlas", smoke_tex)
	sprite.set_shader_parameter("water_atlas", water_tex)
	UnitModels.compat_material(sprite)
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://assets/shaders/combat_glow.gdshader")
	UnitModels.compat_material(glow)
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://assets/shaders/combat_ground.gdshader")
	ground.set_shader_parameter("smoke_atlas", smoke_tex)
	UnitModels.compat_material(ground)
	var debris := StandardMaterial3D.new()
	debris.vertex_color_use_as_albedo = true
	debris.albedo_color = Color.WHITE
	debris.roughness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var chip := BoxMesh.new()
	chip.size = Vector3(0.7, 0.45, 1.0)
	var mats: Array[Material] = [sprite, glow, ground, debris]
	for i in CAPS.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = chip if i == Batch.DEBRIS else quad
		mm.instance_count = CAPS[i]
		mm.visible_instance_count = 0
		UnitModels.compat_colors(mm)
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mats[i]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_batches.append(node)
	for i in MAX_LIGHTS:
		var light := OmniLight3D.new()
		light.shadow_enabled = false
		light.light_color = Color(1.0, 0.56, 0.20)
		light.omni_attenuation = 2.3
		light.visible = false
		add_child(light)
		_lights.append(light)
		_light_life.append(0.0)
		_light_power.append(0.0)

func _load_texture(path: String) -> Texture2D:
	# Imported resources survive PCK/web exports; raw source PNGs need not exist there.
	if not ResourceLoader.exists(path): return null
	return load(path) as Texture2D

func _distance() -> float:
	if camera is MapCamera3D: return (camera as MapCamera3D).distance
	return camera.global_position.y if camera != null else INF

func _can_emit(at: Vector3) -> bool:
	if not World.in_game or camera == null or map == null or _distance() >= MAX_DISTANCE: return false
	if not at.is_finite() or camera.is_position_behind(at): return false
	var pid: int = map.province_at(Vector2(at.x, at.z))
	if pid <= 0 or not Military.is_visible(pid): return false
	var screen := camera.unproject_position(at)
	var viewport := camera.get_viewport().get_visible_rect().grow(160.0)
	return viewport.has_point(screen)

func _spawn(batch: int, at: Vector3, life: float, size: Vector2, color: Color, kind := 0, delay := 0.0) -> Particle:
	if _counts[batch] >= CAPS[batch]:
		dropped += 1
		return null
	var p := Particle.new()
	p.batch = batch
	p.kind = kind
	p.start = at
	p.pos = at
	p.life = maxf(life, 0.02)
	p.age = -delay
	p.size = size
	p.color = color
	p.angle = _rng.randf_range(-PI, PI)
	p.variant = _rng.randi_range(0, 3)
	p.ground = maxf(map.height_at(Vector2(at.x, at.z)), 0.0) if map != null else 0.0
	_particles.append(p)
	_counts[batch] += 1
	emitted += 1
	return p

func muzzle(at: Vector3, direction: Vector3, weapon := "rifle", scale := 1.0) -> void:
	if GameClock.paused or not _can_emit(at): return
	var heavy := weapon in ["cannon", "naval"]
	var dir := direction.normalized()
	if dir.length_squared() < 0.1: return
	var length := (2.9 if heavy else 0.9) * scale
	var p := _spawn(Batch.GLOW, at + dir * length * 0.40, 0.10 if heavy else 0.055,
		Vector2((1.4 if heavy else 0.40) * scale, length), Color(1.8, 0.94, 0.28, 0.95))
	if p != null: p.vel = dir
	smoke(at + dir * 0.45 * scale, scale * (0.42 if heavy else 0.14), false, dir * (3.0 if heavy else 1.5) + Vector3.UP * 0.8)
	if heavy: _light(at, 8.0 * scale, 2.0)

func projectile(from: Vector3, to: Vector3, weapon := "rifle", scale := 1.0) -> void:
	if GameClock.paused or not _can_emit(from): return
	var heavy := weapon in ["cannon", "naval"]
	var p := _flight(from, to, 210.0 if heavy else 170.0, scale * (1.5 if heavy else 0.65))
	if p != null:
		p.weapon = weapon
		p.hit_scale = scale

func tracer(from: Vector3, to: Vector3, speed := 180.0, scale := 1.0) -> void:
	if not GameClock.paused and _can_emit(from): _flight(from, to, speed, scale)

func _flight(from: Vector3, to: Vector3, speed: float, scale: float) -> Particle:
	var length := from.distance_to(to)
	if length < 0.02: return null
	var p := _spawn(Batch.GLOW, from, clampf(length / maxf(speed, 1.0), 0.06, 1.2), Vector2(0.15 * scale, 2.1 * scale), Color(1.9, 1.25, 0.48, 0.95), 1)
	if p != null:
		p.goal = to
		p.vel = (to - from).normalized()
	return p

func impact(at: Vector3, kind := "shell", scale := 1.0) -> void:
	if GameClock.paused or not _can_emit(at): return
	var water := kind == "water"
	var small := kind == "rifle"
	var s := clampf(scale, 0.25, 3.0) * (0.32 if small else (1.35 if kind in ["bomb", "crash"] else 1.0))
	var ground := maxf(map.height_at(Vector2(at.x, at.z)), 0.0)
	var base := Vector3(at.x, ground + 0.08, at.z)
	if water:
		var splash := _spawn(Batch.SPRITE, base + Vector3.UP * 3.8 * s, 1.35,
			Vector2(8.4, 10.4) * s, Color(0.91, 0.97, 1.0, 0.90), 3)
		if splash != null:
			splash.angle = _rng.randf_range(-0.07, 0.07)
			splash.growth = 0.08
	if not water and not small:
		var burst := _spawn(Batch.SPRITE, base + Vector3.UP * 3.1 * s, 1.55,
			Vector2(8.4, 8.4) * s, Color(1.12, 1.08, 1.0, 0.96))
		if burst != null:
			burst.angle = _rng.randf_range(-0.1, 0.1)
			burst.growth = 0.16
		_light(base + Vector3.UP * 2.0, 16.0 * s, 3.8)
		var scorch := _spawn(Batch.GROUND, base, 8.0, Vector2(4.2, 3.7) * s, Color(0.08, 0.065, 0.045, 0.42), 1)
		if scorch != null: scorch.pos.y = ground + 0.025
	var skirt := _spawn(Batch.GROUND, base, 0.85, Vector2.ONE * 4.2 * s,
		Color(0.65, 0.67, 0.64, 0.35) if water else Color(0.47, 0.38, 0.25, 0.52))
	if skirt != null: skirt.growth = 2.7
	for i in (4 if small else (3 if water else 9)):
		var a := _rng.randf() * TAU
		var speed := _rng.randf_range(2.0, 7.0) * s
		var v := Vector3(cos(a) * speed, _rng.randf_range(4.0, 12.0) * s, sin(a) * speed)
		var col := Color(0.88, 0.96, 1.0, 0.18) if water else Color(0.43, 0.36, 0.27, 0.64)
		var puff := _spawn(Batch.SPRITE, base + Vector3.UP * 0.45 * s, _rng.randf_range(1.0, 2.0), Vector2.ONE * _rng.randf_range(1.0, 2.0) * s, col, 1, i * 0.018)
		if puff != null:
			puff.vel = v * 0.55
			puff.accel = Vector3.DOWN * (5.0 if water else 1.3)
			puff.drag = 1.7
			puff.growth = 1.8
			puff.spin = _rng.randf_range(-0.35, 0.35)
	for i in (3 if small else 10):
		var debris := _spawn(Batch.DEBRIS, base + Vector3.UP * 0.3, _rng.randf_range(0.65, 1.25), Vector2.ONE * _rng.randf_range(0.09, 0.24) * s,
			Color(0.72, 0.80, 0.85) if water else Color(0.24, 0.18, 0.11))
		if debris != null:
			debris.vel = Vector3(_rng.randf_range(-8.0, 8.0), _rng.randf_range(7.0, 15.0), _rng.randf_range(-8.0, 8.0)) * s
			debris.accel = Vector3.DOWN * 24.0
			debris.spin = _rng.randf_range(-10.0, 10.0)
	if not water and not small:
		for i in 3:
			var p := _smoke(base + Vector3(_rng.randf_range(-0.8, 0.8), 1.6 + i * 0.55, _rng.randf_range(-0.8, 0.8)) * s,
				s * (0.7 + i * 0.16), true, Vector3(0.45, 1.45, 0.2))
			if p != null: p.age = -0.2 - i * 0.12
	impacted.emit(base, 12.0 * s, not small)

func smoke(at: Vector3, scale := 1.0, dark := false, drift := Vector3(0.3, 0.8, 0.1)) -> void:
	if not GameClock.paused and _can_emit(at): _smoke(at, scale, dark, drift)

func _smoke(at: Vector3, scale: float, dark: bool, drift: Vector3) -> Particle:
	var p := _spawn(Batch.SPRITE, at, _rng.randf_range(2.6, 4.2), Vector2.ONE * 3.4 * scale,
		Color(0.48, 0.46, 0.43, 0.66) if dark else Color(0.84, 0.81, 0.75, 0.34), 1)
	if p != null:
		p.vel = drift
		p.drag = 0.18
		p.growth = 1.65
		p.spin = _rng.randf_range(-0.16, 0.16)
	return p

func trail(target: Node3D, scale := 1.0, duration := 5.0, burning := true) -> void:
	if GameClock.paused or not is_instance_valid(target) or not _can_emit(target.global_position) or _trails.size() >= MAX_TRAILS: return
	_trails.append({"target": weakref(target), "scale": scale, "left": duration, "clock": 0.0, "burning": burning})

func _light(at: Vector3, radius: float, power: float) -> void:
	for i in _lights.size():
		if _light_life[i] > 0.0: continue
		_lights[i].global_position = at
		_lights[i].omni_range = radius
		_lights[i].light_energy = power
		_lights[i].visible = true
		_light_life[i] = 0.14
		_light_power[i] = power
		break

func _process(delta: float) -> void:
	advance(delta)

## Exposed for a deterministic real-render preview and budget/fog regressions.
func advance(delta: float) -> void:
	if camera == null or not World.in_game or _distance() >= MAX_DISTANCE:
		clear_all()
		return
	if GameClock.paused:
		for i in _lights.size():
			_lights[i].visible = _light_life[i] > 0.0 and _can_emit(_lights[i].global_position)
		_draw()
		return
	var dt := clampf(delta, 0.0, 0.1)
	for i in range(_trails.size() - 1, -1, -1):
		var tr: Dictionary = _trails[i]
		var target: Node3D = (tr["target"] as WeakRef).get_ref()
		tr["left"] -= dt
		if not is_instance_valid(target) or tr["left"] <= 0.0 or not _can_emit(target.global_position):
			_trails.remove_at(i)
			continue
		tr["clock"] -= dt
		if tr["clock"] <= 0.0:
			tr["clock"] = 0.16
			_smoke(target.global_position, tr["scale"] * 0.65, true, Vector3(0.3, 0.7, 0.1))
			if tr["burning"]:
				var flame := _spawn(Batch.SPRITE, target.global_position + Vector3.UP * tr["scale"], 0.58,
					Vector2.ONE * 3.3 * tr["scale"], Color(1.15, 1.0, 0.78, 0.76), 2)
				if flame != null: flame.angle *= 0.08
	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		p.age += dt
		var finished := p.age >= p.life
		if finished or not _can_emit(p.pos):
			if finished and p.weapon != "" and _can_emit(p.goal):
				var pid: int = map.province_at(Vector2(p.goal.x, p.goal.z))
				var province: Object = World.province(pid)
				var kind := "water" if province != null and not province.is_land() else ("shell" if p.weapon in ["cannon", "naval"] else "rifle")
				impact(p.goal, kind, p.hit_scale)
			_counts[p.batch] -= 1
			_particles.remove_at(i)
			continue
		if p.age < 0.0: continue
		if p.batch == Batch.GLOW:
			if p.kind == 1: p.pos = p.start.lerp(p.goal, clampf(p.age / p.life, 0.0, 1.0))
		else:
			p.vel += p.accel * dt
			p.vel *= exp(-p.drag * dt)
			p.pos += p.vel * dt
			p.pos.y = maxf(p.pos.y, p.ground + 0.035)
		p.angle += p.spin * dt
	for i in _lights.size():
		_light_life[i] = maxf(0.0, _light_life[i] - dt)
		_lights[i].visible = _light_life[i] > 0.0 and _can_emit(_lights[i].global_position)
		_lights[i].light_energy = _light_power[i] * pow(_light_life[i] / 0.14, 2.0)
	_draw()

func _draw() -> void:
	if camera == null or _batches.is_empty(): return
	var cb := camera.global_basis.orthonormalized()
	var alpha: Array[Particle] = []
	var lists: Array = [alpha, [], [], []]
	for p: Particle in _particles:
		if p.age < 0.0 or not _can_emit(p.pos): continue
		p.depth = (p.pos - camera.global_position).dot(-cb.z)
		(lists[p.batch] as Array).append(p)
	alpha.sort_custom(func(a: Particle, b: Particle) -> bool: return a.depth > b.depth)
	var fade := 1.0 - smoothstep(430.0, MAX_DISTANCE, _distance())
	for batch in _batches.size():
		var mm := _batches[batch].multimesh
		var list: Array = lists[batch]
		mm.visible_instance_count = list.size()
		for i in list.size():
			var p: Particle = list[i]
			var age := clampf(p.age / p.life, 0.0, 1.0)
			var size := p.size * (1.0 + p.growth * sqrt(age))
			var basis := cb * Basis(Vector3.BACK, p.angle)
			var col := p.color
			var frame := float(p.variant)
			var mode := float(p.kind)
			if batch == Batch.SPRITE:
				if p.kind == 0 or p.kind == 3:
					frame = age * 15.0
					col.a *= 1.0 - smoothstep(0.72, 1.0, age)
				elif p.kind == 2:
					mode = 0.0
					frame = 1.0 + age * 7.0
					col.a *= sin(age * PI)
				else:
					col.a *= smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.3, 1.0, age))
			elif batch == Batch.GLOW:
				var along := p.vel.normalized()
				var side := along.cross(camera.global_position - p.pos).normalized()
				if side.length_squared() < 0.1: side = cb.x
				basis = Basis(side, along, side.cross(along).normalized())
				frame = age
			elif batch == Batch.GROUND:
				basis = Basis(Vector3.UP, p.angle) * Basis(Vector3.RIGHT, -PI * 0.5)
				col.a *= 1.0 - smoothstep(0.12 if p.kind == 0 else 0.45, 1.0, age)
			elif batch == Batch.DEBRIS:
				basis = Basis.from_euler(Vector3(p.angle, p.angle * 1.7, p.angle * 0.6))
				size *= 1.0 - smoothstep(0.65, 1.0, age)
			col.a *= fade
			var scaled := Basis(basis.x * size.x, basis.y * size.y, basis.z * size.x)
			mm.set_instance_transform(i, Transform3D(scaled, p.pos))
			mm.set_instance_color(i, col)
			mm.set_instance_custom_data(i, Color(frame, p.angle, mode, p.ground))

func clear_all() -> void:
	_particles.clear()
	_trails.clear()
	_counts = [0, 0, 0, 0]
	for b: MultiMeshInstance3D in _batches: b.multimesh.visible_instance_count = 0
	for i in _lights.size():
		_lights[i].visible = false
		_light_life[i] = 0.0

func stats() -> Dictionary:
	return {"active": _particles.size(), "capacity": CAPS.reduce(func(a: int, b: int) -> int: return a + b, 0),
		"batches": _batches.size(), "trails": _trails.size(), "emitted": emitted, "dropped": dropped}
