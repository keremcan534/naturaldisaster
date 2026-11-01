extends "res://scripts/disasters/disaster.gd"
## Base for things that fall from the sky (hail, acid rain, sand): whoever is
## out in the open (exposed(): nothing overhead) loses health on a fixed tick,
## more as the storm builds; a roof over your head is safe. Subclasses add their
## look, sound and what they do to the island in _hazard_tick().

const Quality := preload("res://scripts/core/quality.gd")
const Look := preload("res://scripts/world/look.gd")

const TICK := 0.25
## Strength builds up over this part of the duration, and fades over the last.
const RAMP := 0.3
const FADE := 0.12

## Health per second lost in the open at full strength.
var exposed_dps := 6.0
var _elapsed := 0.0
var _tick := 0.0
## Particles that follow the camera (rain-like curtains of the hazard).
var _around_camera: Array[Node3D] = []


func intensity() -> float:
	var p := _elapsed / maxf(duration, 0.01)
	return clampf(p / RAMP, 0.0, 1.0) * clampf((1.0 - p) / FADE, 0.0, 1.0)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		for node in _around_camera:
			node.global_position = camera.global_position
	_hazard_frame(delta)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var k := intensity()
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if p.alive and exposed(p.global_position):
			p.take_damage(exposed_dps * k * power * TICK)
	_hazard_tick(k)


## Every frame (sounds, visuals).
func _hazard_frame(_delta: float) -> void:
	pass


## Every TICK, at strength k (0..1).
func _hazard_tick(_k: float) -> void:
	pass


## The top of whatever is under a random spot of the island (roof, car, ground).
func random_top() -> Vector3:
	var half: float = world.map_size * 0.5
	var at := Vector3(randf_range(-half, half), 60.0, randf_range(-half, half))
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 70.0, 1 | 2)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3(at.x, 0.0, at.z)


## Falling bits around the camera: a box of particles above it moving along dir.
func curtain(mesh: Mesh, amount: int, speed: float, dir: Vector3, extents: Vector3, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = dir
	p.spread = 6.0
	p.initial_velocity_min = speed * 0.85
	p.initial_velocity_max = speed * 1.15
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-extents * 3.0, extents * 6.0)
	add_child(p)
	_around_camera.append(p)
	return p
