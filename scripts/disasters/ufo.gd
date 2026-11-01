extends "res://scripts/disasters/disaster.gd"
## A flying saucer drifts over the island (a fun one), sweeping a beam of light
## across the ground: whatever the beam catches floats up into it, people
## included, and doesn't come back. Stay out of the light; indoors the beam
## takes the roof first.

const HEIGHT := 22.0
const BEAM_RADIUS := 4.0
const SPEED := 5.0
const LIFT := 14.0
const FIELD_INTERVAL := 0.1

var _pos := Vector3.ZERO
var _target := Vector3.ZERO
var _field_timer := 0.0
var _saucer: Node3D
var _beam: MeshInstance3D


func _init() -> void:
	display_name = "UFO İstilası"
	kind = "ufo"
	warning = "Gökyüzünde bir UFO! Işığına yakalanma, saklan!"
	duration = 32.0
	mood = "dusk"


func begin() -> void:
	var half: float = world.map_size * 0.4
	_pos = Vector3(randf_range(-half, half), HEIGHT, randf_range(-half, half))
	_pick_target()
	_saucer = Node3D.new()
	var hull := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 6.0
	disc.height = 2.4
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.7, 0.72, 0.76)
	metal.metallic = 0.8
	metal.roughness = 0.3
	disc.material = metal
	hull.mesh = disc
	_saucer.add_child(hull)
	var dome := MeshInstance3D.new()
	var bubble := SphereMesh.new()
	bubble.radius = 2.2
	bubble.height = 2.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 1.0, 0.6, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.3, 1.0, 0.5)
	bubble.material = glass
	dome.mesh = bubble
	dome.position.y = 1.0
	_saucer.add_child(dome)
	_beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 1.5
	cone.bottom_radius = BEAM_RADIUS
	cone.height = HEIGHT
	cone.cap_top = false
	cone.cap_bottom = false
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	light.albedo_color = Color(0.4, 1.0, 0.6, 0.25)
	cone.material = light
	_beam.mesh = cone
	_beam.position.y = -HEIGHT * 0.5
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_saucer.add_child(_beam)
	var spot := OmniLight3D.new()
	spot.light_color = Color(0.4, 1.0, 0.6)
	spot.omni_range = 12.0
	spot.position.y = -HEIGHT + 2.0
	_saucer.add_child(spot)
	_saucer.position = _pos
	add_child(_saucer)
	_saucer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_saucer.reset_physics_interpolation()


func _pick_target() -> void:
	var half: float = world.map_size * 0.42
	var players := get_tree().get_nodes_in_group("player").filter(func(p: Node) -> bool: return p.alive)
	if not players.is_empty() and randf() < 0.5:
		var p: Node3D = players.pick_random()
		_target = Vector3(p.global_position.x, HEIGHT, p.global_position.z)
	else:
		_target = Vector3(randf_range(-half, half), HEIGHT, randf_range(-half, half))


func _physics_process(delta: float) -> void:
	var to := _target - _pos
	if to.length() < 1.5:
		_pick_target()
	else:
		_pos += to.normalized() * minf(SPEED * power * delta, to.length())
	_saucer.position = _pos + Vector3(0, sin(Time.get_ticks_msec() * 0.002) * 0.5, 0)
	_saucer.rotate_y(delta * 0.8)
	get_tree().call_group("sound", "loop", "wind", 0.25, 1.9)
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive:
			continue
		var flat := Vector2(p.global_position.x - _pos.x, p.global_position.z - _pos.z).length()
		if flat < BEAM_RADIUS and exposed(p.global_position, HEIGHT):
			p.push(Vector3.UP * LIFT * delta * 2.0 + (Vector3(_pos.x, p.global_position.y, _pos.z) - p.global_position) * delta)
			if p.global_position.y > HEIGHT - 3.0:
				p.take_damage(1000.0)
	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = FIELD_INTERVAL
		var region := AABB(Vector3(_pos.x - BEAM_RADIUS, -1, _pos.z - BEAM_RADIUS), Vector3(BEAM_RADIUS * 2.0, HEIGHT, BEAM_RADIUS * 2.0))
		get_tree().call_group("structures", "apply_field", region, func(at: Vector3) -> Vector3:
			var axis := Vector3(_pos.x - at.x, 0, _pos.z - at.z)
			if axis.length() > BEAM_RADIUS:
				return Vector3.ZERO
			return Vector3.UP * LIFT * 2.4 * power + axis * 2.0, FIELD_INTERVAL)
		get_tree().call_group("structures", "dissolve", _pos + Vector3.DOWN * 2.0, 3.0)


func danger_center() -> Vector3:
	return Vector3(_pos.x, 0, _pos.z)
