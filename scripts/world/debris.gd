extends Node3D
## Pooled chunks a structure piece breaks into when it is hit hard: a wall turns
## into a heap of blocks, a window into glass shards. All bodies exist from
## _ready(); a break takes the oldest ones. Chunks live a while, then shrink away.
## They are drawn as two MultiMeshes (stone/wood/paint, and glass), so a collapse
## costs two draw calls however many chunks fly; chunks don't collide with each
## other (layer 5), only with the world, pieces and people.
## Reached through call_group("debris", ...).

const Look := preload("res://scripts/world/look.gd")
const Quality := preload("res://scripts/core/quality.gd")

## Chunks per chaos budget point (see quality.gd): fewer on slow phones.
const POOL_PER_CHAOS := 0.8
const LIFETIME := 6.5
const SHRINK_TIME := 1.0
const MAX_CHUNKS := 14
## Target chunk edge (m) for walls and slabs, and for glass.
const CHUNK_EDGE := 0.55
const SHARD_EDGE := 0.4
const DENSITY := 1.5
const PARK := Vector3(0, -500, 0)
const LAYER := 16

static var _shapes := {}

var _bodies: Array[RigidBody3D] = []
var _shapes_of: Array[CollisionShape3D] = []
var _sizes: Array[Vector3] = []
var _glass := PackedByteArray()
var _born := PackedFloat32Array()
var _next := 0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _solid: MultiMesh
var _shards: MultiMesh


func _ready() -> void:
	add_to_group("debris")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.1
	var count := int(Quality.current().chaos * POOL_PER_CHAOS)
	_solid = _batch(count, Look.tinted())
	_shards = _batch(count, Look.shard())
	for i in count:
		var body := RigidBody3D.new()
		body.collision_layer = LAYER
		# Chunks hit the world, pieces and people, not each other.
		body.collision_mask = 1 | 2 | 4
		body.physics_material_override = material
		body.can_sleep = true
		var shape := CollisionShape3D.new()
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)
		_shapes_of.append(shape)
		_sizes.append(Vector3.ONE)
		_glass.append(0)
		_born.append(-1.0)
		_park(i)


func _batch(count: int, material: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cube := BoxMesh.new()
	mm.mesh = cube
	mm.instance_count = count
	var hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), PARK)
	for i in count:
		mm.set_instance_transform(i, hidden)
		mm.set_instance_color(i, Color.WHITE)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.custom_aabb = AABB(Vector3(-300, -60, -300), Vector3(600, 260, 600))
	add_child(instance)
	return mm


## Breaks a box (global transform, size, color) into chunks flying apart from
## `from` with up to `power` m/s on top of the piece's own velocity.
func shatter(xform: Transform3D, size: Vector3, color: Color, velocity: Vector3, from: Vector3, power: float) -> void:
	var glass := color == Look.GLASS_KEY or color == Look.CAR_GLASS_KEY
	var edge := SHARD_EDGE if glass else CHUNK_EDGE
	var cuts := Vector3i(maxi(roundi(size.x / edge), 1), maxi(roundi(size.y / edge), 1), maxi(roundi(size.z / edge), 1))
	while cuts.x * cuts.y * cuts.z > MAX_CHUNKS:
		if cuts.x >= cuts.y and cuts.x >= cuts.z:
			cuts.x -= 1
		elif cuts.y >= cuts.z:
			cuts.y -= 1
		else:
			cuts.z -= 1
	var xs := _splits(size.x, cuts.x)
	var ys := _splits(size.y, cuts.y)
	var zs := _splits(size.z, cuts.z)
	for ix in cuts.x:
		for iy in cuts.y:
			for iz in cuts.z:
				var lo := Vector3(xs[ix], ys[iy], zs[iz])
				var hi := Vector3(xs[ix + 1], ys[iy + 1], zs[iz + 1])
				var chunk_size := _quantize(hi - lo)
				var center := xform * ((lo + hi) * 0.5 - size * 0.5)
				var away := (center - from).normalized()
				var v := velocity + away * power * _rng.randf_range(0.4, 1.0) \
						+ Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 1.5), _rng.randf_range(-1, 1)) * power * 0.25
				var tint := color.darkened(_rng.randf_range(0.0, 0.25)) if not glass else Color(0.75, 0.85, 0.95)
				_spawn(Transform3D(xform.basis, center), chunk_size, glass, tint, v)


## Puts every chunk away (a new map is loading).
func clear() -> void:
	for i in _bodies.size():
		_park(i)


func _physics_process(delta: float) -> void:
	_time += delta
	for i in _bodies.size():
		if _born[i] < 0.0:
			continue
		var age := _time - _born[i]
		if age > LIFETIME or _bodies[i].global_position.y < -30.0:
			_park(i)


## Every frame: each live chunk's batch instance follows its body.
func _process(_delta: float) -> void:
	for i in _bodies.size():
		if _born[i] < 0.0:
			continue
		var body := _bodies[i]
		var age := _time - _born[i]
		var shrink := clampf((LIFETIME - age) / SHRINK_TIME, 0.01, 1.0)
		var t := body.get_global_transform_interpolated()
		var mm := _shards if _glass[i] else _solid
		mm.set_instance_transform(i, Transform3D(t.basis * Basis.from_scale(_sizes[i] * shrink), t.origin))


func _spawn(xform: Transform3D, size: Vector3, glass: bool, color: Color, velocity: Vector3) -> void:
	var i := _next
	_next = (_next + 1) % _bodies.size()
	if _born[i] >= 0.0:
		_park(i)
	var body := _bodies[i]
	_shapes_of[i].shape = _box_shape(size)
	_sizes[i] = size
	_glass[i] = 1 if glass else 0
	(_shards if glass else _solid).set_instance_color(i, color)
	body.mass = maxf(size.x * size.y * size.z * DENSITY, 0.05)
	body.global_transform = xform
	body.reset_physics_interpolation()
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
	_born[i] = _time


func _park(i: int) -> void:
	var body := _bodies[i]
	body.freeze = true
	body.global_position = PARK + Vector3(i * 2.0, 0, 0)
	body.reset_physics_interpolation()
	_born[i] = -1.0
	var hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), PARK)
	_solid.set_instance_transform(i, hidden)
	_shards.set_instance_transform(i, hidden)


## n + 1 cut positions across a length, inner ones jittered so chunks differ.
func _splits(length: float, n: int) -> PackedFloat32Array:
	var cuts := PackedFloat32Array()
	for k in n + 1:
		var t := float(k) / n
		if k > 0 and k < n:
			t += _rng.randf_range(-0.25, 0.25) / n
		cuts.append(t * length)
	return cuts


## Sizes snap to 5 cm so the mesh and shape caches stay small.
static func _quantize(s: Vector3) -> Vector3:
	return (s / 0.05).round().max(Vector3.ONE) * 0.05


static func _box_shape(s: Vector3) -> BoxShape3D:
	if not _shapes.has(s):
		var shape := BoxShape3D.new()
		shape.size = (s - Vector3.ONE * 0.02).max(Vector3.ONE * 0.03)
		_shapes[s] = shape
	return _shapes[s]
