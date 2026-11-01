extends Node3D
## Draws fire wherever structures burn (see Structure.ignite) and hurts whoever
## stands in it: flames on the burning pieces nearest the camera (one MultiMesh,
## one draw call), smoke columns over the biggest blazes, and a flickering
## orange light by the nearest ones. Idle (nothing drawn or checked) while
## nothing burns. Lives for the whole game; any disaster can start fires.

const Structure := preload("res://scripts/world/structure.gd")
const Look := preload("res://scripts/world/look.gd")
const Quality := preload("res://scripts/core/quality.gd")
const SHADER := preload("res://shaders/flame.gdshader")

const TICK := 0.2
## Flames drawn at most, per quality level.
const MAX_FLAMES := [70, 120, 180]
const SMOKE_COLUMNS := 5
const SMOKE_SPACING := 7.0
const LIGHTS := 2
## Standing this close to a burning piece hurts, per second.
const BURN_REACH := 1.6
const BURN_DPS := 14.0

var _flames: MultiMesh
var _flame_instance: MultiMeshInstance3D
var _smokes: Array[CPUParticles3D] = []
var _lights: Array[OmniLight3D] = []
var _timer := 0.0
var _points: Array = []
var _time := 0.0


func _ready() -> void:
	add_to_group("flames")
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("noise", Look.noise_texture())
	quad.material = mat
	_flames = MultiMesh.new()
	_flames.transform_format = MultiMesh.TRANSFORM_3D
	_flames.use_custom_data = true
	_flames.mesh = quad
	_flames.instance_count = MAX_FLAMES[MAX_FLAMES.size() - 1]
	_flame_instance = MultiMeshInstance3D.new()
	_flame_instance.multimesh = _flames
	_flame_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame_instance.custom_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 120, 400))
	_flame_instance.visible = false
	add_child(_flame_instance)
	for i in SMOKE_COLUMNS:
		var smoke := _smoke()
		add_child(smoke)
		_smokes.append(smoke)
	for i in LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.18)
		light.omni_range = 9.0
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		if _lights[i].visible:
			_lights[i].light_energy = 1.1 + sin(_time * 13.0 + i * 2.0) * 0.25 + sin(_time * 29.0 + i) * 0.15


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	if Structure.fires <= 0:
		if _flame_instance.visible:
			_hide_all()
		return
	_points.clear()
	for s: Node in get_tree().get_nodes_in_group("structures"):
		if s.has_method("collect_fire"):
			s.collect_fire(_points)
	if _points.is_empty():
		_hide_all()
		return
	_burn_players()
	_draw_flames()
	var camera := get_viewport().get_camera_3d()
	if camera:
		var p: Vector4 = _points[0]
		var nearest := Vector3(p.x, p.y, p.z).distance_to(camera.global_position)
		get_tree().call_group("sound", "loop", "fire", 1.0 - clampf(nearest / 30.0, 0.0, 1.0))
	_place_smoke_and_lights()


func _hide_all() -> void:
	_flame_instance.visible = false
	for smoke in _smokes:
		smoke.emitting = false
	for light in _lights:
		light.visible = false


## The nearest burning pieces to the camera get flames.
func _draw_flames() -> void:
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3.ZERO
	var limit: int = MAX_FLAMES[Quality.level]
	if _points.size() > limit:
		_points.sort_custom(func(a: Vector4, b: Vector4) -> bool:
			return Vector3(a.x, a.y, a.z).distance_squared_to(eye) < Vector3(b.x, b.y, b.z).distance_squared_to(eye))
	var count := mini(_points.size(), limit)
	_flames.visible_instance_count = count
	for i in count:
		var p: Vector4 = _points[i]
		_flames.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, p.y - 0.4, p.z)))
		var seed_value := fmod(absf(p.x * 0.37 + p.z * 0.71 + p.y * 0.13), 1.0)
		_flames.set_instance_custom_data(i, Color(seed_value, p.w, 1.2 + p.w * 1.3 + seed_value * 0.6, 0))
	_flame_instance.visible = true


## Smoke over well-separated blazes (biggest first), lights on the nearest two.
func _place_smoke_and_lights() -> void:
	var used: Array[Vector3] = []
	for p: Vector4 in _points:
		if used.size() >= SMOKE_COLUMNS:
			break
		var at := Vector3(p.x, p.y, p.z)
		var free := true
		for u in used:
			if u.distance_to(at) < SMOKE_SPACING:
				free = false
				break
		if free:
			used.append(at)
	for i in _smokes.size():
		_smokes[i].emitting = i < used.size()
		if i < used.size():
			_smokes[i].global_position = used[i] + Vector3.UP * 1.5
	# Lights a little out toward the camera: inside a burning wall they would
	# flood its panels with flat orange.
	var camera := get_viewport().get_camera_3d()
	for i in _lights.size():
		_lights[i].visible = i < used.size()
		if i < used.size():
			var out := Vector3.ZERO
			if camera:
				out = (camera.global_position - used[i]).normalized() * 2.0
			_lights[i].global_position = used[i] + Vector3.UP * 0.8 + out


func _burn_players() -> void:
	var reach2 := BURN_REACH * BURN_REACH
	for player: Node3D in get_tree().get_nodes_in_group("player"):
		if not player.alive:
			continue
		var at := player.global_position + Vector3.UP * 0.9
		for p: Vector4 in _points:
			if Vector3(p.x, p.y, p.z).distance_squared_to(at) < reach2:
				player.take_damage(BURN_DPS * TICK)
				player.rumble(at, 60.0)
				break


func _smoke() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = Look.sprite(0.22)
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.amount = 26
	p.lifetime = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.8, 0.5, 0.3)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.scale_amount_curve = Look.grow(0.25)
	p.color_ramp = Look.ramp([Color(0.15, 0.13, 0.12, 0.0), Color(0.12, 0.11, 0.1, 0.85), Color(0.22, 0.21, 0.2, 0.5), Color(0.3, 0.3, 0.3, 0.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
