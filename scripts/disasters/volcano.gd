extends "res://scripts/disasters/disaster.gd"
## A volcano rises just past the north edge, throws lava bombs across the map and
## sends a lava flow toward the south. It sinks back before the round ends.

const ProjectilePool := preload("res://scripts/disasters/projectile_pool.gd")
const Look := preload("res://scripts/world/look.gd")

const HEIGHT := 24.0
const BASE_RADIUS := 18.0
const CRATER_RADIUS := 5.0
## How far past the map edge the volcano's center sits; the slope reaches 3 m in.
const EDGE_OFFSET := BASE_RADIUS - 3.0
const RISE_TIME := 4.0
const SINK_TIME := 3.0
const BOMB_INTERVAL := 0.35
const LAVA_WIDTH := 8.0
const LAVA_DAMAGE_PER_SEC := 35.0
## Fraction of the map the lava flow covers by the end of the eruption.
const LAVA_REACH := 0.75

var _center := Vector3.ZERO
var _half := 30.0
var _elapsed := 0.0
var _rise := RISE_TIME
var _sink := SINK_TIME
var _bomb_timer := 0.0
var _mountain: AnimatableBody3D
var _lava: MeshInstance3D
var _lava_mat: ShaderMaterial
var _lava_start := 0.0
var _lava_length := 0.0
var _bombs: ProjectilePool


func _init() -> void:
	display_name = "Volkan"
	warning = "Lavdan ve düşen kayalardan uzak dur!"
	duration = 30.0
	mood = "ash"


func begin() -> void:
	_half = world.map_size * 0.5
	_center = Vector3(0, 0, -_half - EDGE_OFFSET)
	_rise = minf(RISE_TIME, duration * 0.15)
	_sink = minf(SINK_TIME, duration * 0.1)
	_lava_start = _center.z + BASE_RADIUS * 0.7

	_mountain = AnimatableBody3D.new()
	_mountain.collision_layer = 1
	_mountain.collision_mask = 0
	var cone := CylinderMesh.new()
	cone.top_radius = CRATER_RADIUS
	cone.bottom_radius = BASE_RADIUS
	cone.height = HEIGHT
	cone.radial_segments = 24
	cone.rings = 1
	cone.material = Look.cliff(Color(0.17, 0.15, 0.14))
	var cone_mesh := MeshInstance3D.new()
	cone_mesh.mesh = cone
	cone_mesh.position.y = HEIGHT * 0.5
	_mountain.add_child(cone_mesh)
	var shape := CollisionShape3D.new()
	shape.shape = cone.create_convex_shape()
	shape.position.y = HEIGHT * 0.5
	_mountain.add_child(shape)

	var crater := MeshInstance3D.new()
	var crater_mesh := CylinderMesh.new()
	crater_mesh.top_radius = CRATER_RADIUS * 0.9
	crater_mesh.bottom_radius = CRATER_RADIUS * 0.9
	crater_mesh.height = 0.4
	crater_mesh.material = Look.lava()
	crater.mesh = crater_mesh
	crater.position.y = HEIGHT
	_mountain.add_child(crater)
	_mountain.add_child(_smoke())
	_mountain.position = _center - Vector3(0, HEIGHT, 0)
	add_child(_mountain)

	_lava_mat = Look.lava()
	var lava_mesh := BoxMesh.new()
	lava_mesh.material = _lava_mat
	_lava = MeshInstance3D.new()
	_lava.mesh = lava_mesh
	_lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lava.visible = false
	add_child(_lava)

	_bombs = ProjectilePool.new()
	_bombs.blast_radius = 5.5
	_bombs.blast_force = 18.0
	_bombs.blast_damage = 60.0
	add_child(_bombs)
	_bombs.setup(14, 0.6, Color(0.25, 0.1, 0.05), Color(1.0, 0.35, 0.05))


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var sink_start := duration - _sink
	var erupting := _elapsed >= _rise and _elapsed < sink_start

	var rise_t := clampf(_elapsed / _rise, 0.0, 1.0)
	var sink_t := clampf((_elapsed - sink_start) / _sink, 0.0, 1.0)
	_mountain.position.y = _center.y - HEIGHT * (1.0 - ease(rise_t, -2.0)) - HEIGHT * sink_t
	get_tree().call_group("player", "add_shake", 0.4 if _elapsed < _rise else 0.06)

	if erupting:
		_bomb_timer -= delta
		if _bomb_timer <= 0.0:
			_bomb_timer = BOMB_INTERVAL
			_throw_bomb()
		var progress := (_elapsed - _rise) / (sink_start - _rise)
		_lava_length = world.map_size * LAVA_REACH * progress
		_update_lava()
		_burn_players(delta)
	elif _elapsed >= sink_start:
		_lava_mat.set_shader_parameter("energy", lerpf(3.0, 0.0, sink_t))


func _throw_bomb() -> void:
	var from := _center + Vector3(0, HEIGHT + 1.0, 0)
	var target := Vector3(randf_range(-_half, _half), 0, randf_range(-_half * 0.6, _half))
	var flight := randf_range(2.5, 4.0)
	# Ballistic: v = d / t - g * t / 2.
	var gravity := Vector3(0, -ProjectSettings.get_setting("physics/3d/default_gravity"), 0)
	_bombs.launch(from, (target - from) / flight - gravity * flight * 0.5)


func _update_lava() -> void:
	_lava.visible = _lava_length > 0.1
	_lava.scale = Vector3(LAVA_WIDTH, 0.3, maxf(_lava_length, 0.1))
	_lava.position = Vector3(_center.x, 0.1, _lava_start + _lava_length * 0.5)


func _burn_players(delta: float) -> void:
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		var pos := p.global_position
		if absf(pos.x - _center.x) < LAVA_WIDTH * 0.5 and pos.z > _lava_start \
				and pos.z < _lava_start + _lava_length and pos.y < 0.8:
			p.take_damage(LAVA_DAMAGE_PER_SEC * delta)


func _smoke() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = 4.0
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0, 0.5, 0)
	process.scale_min = 3.0
	process.scale_max = 6.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 3.0
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 4)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.2, 0.2, 0.6)
	mat.albedo_texture = Look.puff_texture()
	quad.material = mat
	var smoke := GPUParticles3D.new()
	smoke.amount = 48
	smoke.lifetime = 6.0
	smoke.process_material = process
	smoke.draw_pass_1 = quad
	smoke.visibility_aabb = AABB(Vector3(-20, 0, -20), Vector3(40, 60, 40))
	smoke.position.y = HEIGHT
	return smoke

