extends Node3D
## Pooled particle bursts: explosions (fire, smoke, flying rocks) and dust from
## collapsing structures. Everything is created in _ready(); a burst just moves a
## free slot and restarts its emitters. Reached through call_group("effects", ...).

const Look := preload("res://scripts/world/look.gd")

const EXPLOSION_SLOTS := 8
const DUST_SLOTS := 10
## Big rolling clouds when a whole part of a building comes down.
const CLOUD_SLOTS := 3

var _explosions: Array[Node3D] = []
var _dusts: Array[CPUParticles3D] = []
var _next_explosion := 0
var _next_dust := 0
var _clouds: Array[CPUParticles3D] = []
var _next_cloud := 0


func _ready() -> void:
	add_to_group("effects")
	for i in EXPLOSION_SLOTS:
		var slot := Node3D.new()
		slot.add_child(_fire())
		slot.add_child(_smoke())
		slot.add_child(_rocks())
		add_child(slot)
		_explosions.append(slot)
	for i in DUST_SLOTS:
		var dust := _dust()
		add_child(dust)
		_dusts.append(dust)
	for i in CLOUD_SLOTS:
		var cloud := _cloud()
		add_child(cloud)
		_clouds.append(cloud)


func explosion(pos: Vector3, radius: float) -> void:
	var slot := _explosions[_next_explosion]
	_next_explosion = (_next_explosion + 1) % _explosions.size()
	slot.global_position = pos
	slot.scale = Vector3.ONE * clampf(radius / 5.0, 0.5, 1.5)
	get_tree().call_group("sound", "play", "boom", pos, 4.0)
	for emitter: CPUParticles3D in slot.get_children():
		emitter.restart()


## A collapse: a cloud of dust rolling out low from where it came down.
func cloud(pos: Vector3, size: float) -> void:
	var emitter := _clouds[_next_cloud]
	_next_cloud = (_next_cloud + 1) % _clouds.size()
	emitter.global_position = pos
	emitter.scale = Vector3.ONE * clampf(size / 6.0, 0.6, 2.0)
	emitter.restart()
	get_tree().call_group("sound", "play", "boom", pos, 2.0, 0.45)
	get_tree().call_group("player", "rumble", pos, 600.0)


## Puff of dust where a structure piece broke loose.
func dust(pos: Vector3) -> void:
	var emitter := _dusts[_next_dust]
	_next_dust = (_next_dust + 1) % _dusts.size()
	emitter.global_position = pos
	emitter.restart()
	get_tree().call_group("sound", "play", "crash", pos)


func _fire() -> CPUParticles3D:
	var p := _burst(14, 0.8, Look.sprite(3.0))
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 11.0
	p.damping_min = 8.0
	p.damping_max = 12.0
	p.gravity = Vector3(0, 3, 0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.scale_amount_curve = Look.grow(0.4)
	p.color_ramp = Look.ramp([Color(1, 0.95, 0.7), Color(1, 0.55, 0.15, 0.9), Color(0.4, 0.15, 0.05, 0)])
	return p


func _smoke() -> CPUParticles3D:
	var p := _burst(16, 3.5, Look.sprite())
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	p.scale_amount_curve = Look.grow(0.3)
	p.color_ramp = Look.ramp([Color(0.25, 0.22, 0.2, 0.0), Color(0.22, 0.2, 0.19, 0.85), Color(0.45, 0.43, 0.42, 0)])
	return p


func _rocks() -> CPUParticles3D:
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.18, 0.15)
	chunk.material = mat
	var p := CPUParticles3D.new()
	p.mesh = chunk
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 1.6
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 15.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	return p


func _dust() -> CPUParticles3D:
	var p := _burst(10, 3.0, Look.sprite())
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.5
	p.scale_amount_curve = Look.grow(0.4)
	p.color_ramp = Look.ramp([Color(0.6, 0.55, 0.48, 0.0), Color(0.6, 0.55, 0.48, 0.6), Color(0.65, 0.6, 0.55, 0)])
	return p


func _cloud() -> CPUParticles3D:
	var p := _burst(18, 5.5, Look.sprite())
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 90.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 6.0
	p.scale_amount_max = 11.0
	p.scale_amount_curve = Look.grow(0.35)
	p.color_ramp = Look.ramp([Color(0.55, 0.5, 0.44, 0.0), Color(0.55, 0.5, 0.44, 0.75), Color(0.6, 0.56, 0.5, 0.4), Color(0.65, 0.6, 0.55, 0)])
	return p


func _burst(amount: int, lifetime: float, material: Material) -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.material = material
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
