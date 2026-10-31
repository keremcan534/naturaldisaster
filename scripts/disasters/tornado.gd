extends "res://scripts/disasters/disaster.gd"
## A funnel wanders across the map, tearing pieces off buildings and flinging
## them (and players) around. Being inside the core hurts; the drop hurts more.

const RADIUS := 12.0
const CORE_RADIUS := 3.0
const TOP_HEIGHT := 35.0
const SWIRL := 50.0
const PULL := 22.0
## Above gravity, so the core lifts things.
const LIFT := 38.0
const SPEED := 6.0
const CORE_DAMAGE_PER_SEC := 15.0
const FIELD_INTERVAL := 0.1
const DEBRIS_COUNT := 60

const Look := preload("res://scripts/world/look.gd")

var _pos := Vector3.ZERO
var _target := Vector3.ZERO
var _half := 30.0
var _field_timer := 0.0
var _time := 0.0
var _root: Node3D
var _funnels: Array[MeshInstance3D] = []
var _debris: MultiMesh
## Per debris chunk: orbit radius, height, phase.
var _orbits := PackedVector3Array()


func _init() -> void:
	display_name = "Hortum"
	kind = "tornado"
	warning = "Hortumun yolundan çekil!"
	duration = 30.0
	mood = "storm"


func begin() -> void:
	_half = world.map_size * 0.5
	var angle := randf() * TAU
	_pos = Vector3(cos(angle), 0, sin(angle)) * (_half - 4.0)
	_pick_target()
	_root = Node3D.new()
	_root.position = _pos
	add_child(_root)

	var texture := Look.noise_texture()
	for spec: Array in [[1.5, 9.0, Color(0.5, 0.5, 0.55, 0.65)], [3.0, 13.0, Color(0.65, 0.65, 0.7, 0.3)]]:
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = spec[0]
		mesh.top_radius = spec[1]
		mesh.height = TOP_HEIGHT + 10.0
		mesh.cap_top = false
		mesh.cap_bottom = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = spec[2]
		mat.albedo_texture = texture
		mat.uv1_scale = Vector3(3, 2, 1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = mat
		var funnel := MeshInstance3D.new()
		funnel.mesh = mesh
		funnel.position.y = mesh.height * 0.5
		funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(funnel)
		_funnels.append(funnel)

	_root.add_child(_dust_cloud())

	# Orbiting chunks are visual only: one MultiMesh, one draw call.
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.6
	var chunk_mat := StandardMaterial3D.new()
	chunk_mat.albedo_color = Color(0.4, 0.33, 0.25)
	chunk.material = chunk_mat
	_debris = MultiMesh.new()
	_debris.transform_format = MultiMesh.TRANSFORM_3D
	_debris.mesh = chunk
	_debris.instance_count = DEBRIS_COUNT
	var debris_instance := MultiMeshInstance3D.new()
	debris_instance.multimesh = _debris
	_root.add_child(debris_instance)
	for i in DEBRIS_COUNT:
		var height := randf_range(0.5, TOP_HEIGHT)
		_orbits.append(Vector3(lerpf(2.0, 10.0, height / TOP_HEIGHT) + randf_range(-1, 1), height, randf() * TAU))


func _process(delta: float) -> void:
	_time += delta
	for i in _funnels.size():
		_funnels[i].rotate_y(-delta * (4.0 - i * 1.5))
	for i in DEBRIS_COUNT:
		var orbit := _orbits[i]
		var a := orbit.z - _time * (5.0 - orbit.y * 0.08)
		var spin := Basis(Vector3(1, 1, 0).normalized(), _time * 3.0 + orbit.z)
		_debris.set_instance_transform(i, Transform3D(spin, Vector3(cos(a) * orbit.x, orbit.y, sin(a) * orbit.x)))


func _physics_process(delta: float) -> void:
	var to_target := _target - _pos
	if to_target.length() < 2.0:
		_pick_target()
	else:
		_pos += to_target.normalized() * minf(SPEED * delta, to_target.length())
	_root.position = _pos

	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive:
			continue
		var at := p.global_position + Vector3.UP
		p.push(_force_at(at) * delta)
		if Vector2(at.x - _pos.x, at.z - _pos.z).length() < CORE_RADIUS:
			p.take_damage(CORE_DAMAGE_PER_SEC * delta)

	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = FIELD_INTERVAL
		var region := AABB(_pos - Vector3(RADIUS, 1.0, RADIUS), Vector3(RADIUS * 2.0, TOP_HEIGHT + 10.0, RADIUS * 2.0))
		get_tree().call_group("structures", "apply_field", region, _force_at, FIELD_INTERVAL)


func _force_at(p: Vector3) -> Vector3:
	var to_axis := Vector3(_pos.x - p.x, 0, _pos.z - p.z)
	var dist := to_axis.length()
	if dist > RADIUS:
		return Vector3.ZERO
	var falloff := 1.0 - dist / RADIUS
	var inward := to_axis / maxf(dist, 0.1)
	var tangent := inward.cross(Vector3.UP)
	var lift := LIFT * falloff if p.y < TOP_HEIGHT else -2.0
	return tangent * SWIRL * falloff + inward * PULL * falloff + Vector3.UP * lift


## Half the time head for a structure, otherwise anywhere on the map.
func _pick_target() -> void:
	var structures := get_tree().get_nodes_in_group("structures")
	if not structures.is_empty() and randf() < 0.5:
		var s: Node3D = structures.pick_random()
		_target = Vector3(s.global_position.x, 0, s.global_position.z)
	else:
		var r := _half * 0.7
		_target = Vector3(randf_range(-r, r), 0, randf_range(-r, r))


## Dust kicked up around the funnel's foot; world-space, so it trails behind.
func _dust_cloud() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.material = Look.sprite()
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.amount = 40
	p.lifetime = 2.5
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = RADIUS * 0.6
	p.emission_ring_inner_radius = 1.0
	p.emission_ring_height = 0.5
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, 1.0, 0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.scale_amount_curve = Look.grow(0.4)
	p.color_ramp = Look.ramp([Color(0.42, 0.36, 0.3, 0.0), Color(0.42, 0.36, 0.3, 0.7), Color(0.5, 0.46, 0.42, 0)])
	p.position.y = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func danger_center() -> Vector3:
	return _pos
