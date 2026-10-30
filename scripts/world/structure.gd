extends Node3D
## A breakable structure made of box pieces: a building (walls, floor tiles,
## ramps) or props (trees, fences, cars).
##
## Intact pieces are frozen rigid bodies: the physics engine treats them as static,
## so a whole map costs almost nothing until something breaks. Damage unfreezes
## pieces, and after every hit a support pass drops whatever is no longer held up
## from the ground. Fill it with add_box()/add_building() before adding it to the tree.

const WALL_THICKNESS := 0.3
const SLAB_THICKNESS := 0.3
const RAMP_THICKNESS := 0.25
const CELL := 2.0
const FLOOR_HEIGHT := 3.0
const WINDOW_COLOR := Color(0.25, 0.35, 0.45)
## How many pieces a piece may hang sideways from something supported below.
const MAX_SPAN := 2
const DENSITY := 1.5
const EPS := 0.01
const QUAKE_PIECES_PER_TICK := 2.5
## Acceleration (m/s²) an intact piece withstands at strength 1.
const HOLD_FORCE := 25.0
## Break chance per second when the force is double the hold.
const BREAK_RATE := 5.0

static var _meshes := {}
static var _shapes := {}
static var _materials := {}
static var _physics_material: PhysicsMaterial

## Higher survives more shaking.
@export var strength := 1.0

var _pieces: Array[RigidBody3D] = []
var _boxes: Array[AABB] = []
var _loose := PackedByteArray()
var _grounded := PackedByteArray()
## Per piece: indices of pieces resting on it / touching it sideways.
var _up: Array[Array] = []
var _side: Array[Array] = []
var _bounds := AABB()


func _ready() -> void:
	add_to_group("structures")
	_link_pieces()


## center is in this node's local space. A rotated piece links to its neighbours
## through its axis-aligned bounds.
func add_box(center: Vector3, box_size: Vector3, color: Color, rotation_basis := Basis.IDENTITY) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 2
	rb.collision_mask = 1 | 2 | 4
	rb.mass = maxf(box_size.x * box_size.y * box_size.z * DENSITY, 0.3)
	rb.physics_material_override = _get_physics_material()
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	rb.freeze = true
	rb.transform = Transform3D(rotation_basis, center)

	var shape := CollisionShape3D.new()
	shape.shape = _box_shape(box_size)
	rb.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh(box_size)
	mesh.material_override = _material(color)
	rb.add_child(mesh)
	add_child(rb)

	var box := rb.transform * AABB(-box_size * 0.5, box_size)
	_pieces.append(rb)
	_boxes.append(box)
	_bounds = box if _pieces.size() == 1 else _bounds.merge(box)


## A building with its front door facing +Z. With stairs (footprint at least 3x3),
## ramps in the back-left corner connect every floor and the roof.
func add_building(origin: Vector3, footprint: Vector2i, floors: int, color: Color, with_stairs := true) -> void:
	var stairs := with_stairs and footprint.x >= 3 and footprint.y >= 3
	var slab_color := color.darkened(0.35)
	var w := footprint.x * CELL
	var d := footprint.y * CELL
	var door := footprint.x / 2
	for f in floors:
		var y0 := f * FLOOR_HEIGHT
		if f > 0:
			_add_slab(origin, footprint, y0, slab_color, (f - 1) % 2 if stairs else -1)
		var wall_bottom := y0 + (SLAB_THICKNESS if f > 0 else 0.0)
		var h := y0 + FLOOR_HEIGHT - wall_bottom
		var cy := wall_bottom + h * 0.5
		# Front/back walls span the full width; side walls fit between them.
		for i in footprint.x:
			var x := -w * 0.5 + CELL * (i + 0.5)
			var c := WINDOW_COLOR if f > 0 and i % 2 == 1 else color
			if not (f == 0 and i == door):
				add_box(origin + Vector3(x, cy, d * 0.5 - WALL_THICKNESS * 0.5), Vector3(CELL, h, WALL_THICKNESS), c)
			add_box(origin + Vector3(x, cy, -d * 0.5 + WALL_THICKNESS * 0.5), Vector3(CELL, h, WALL_THICKNESS), c)
		var side_len := (d - WALL_THICKNESS * 2.0) / footprint.y
		for j in footprint.y:
			var z := -d * 0.5 + WALL_THICKNESS + side_len * (j + 0.5)
			var c := WINDOW_COLOR if f > 0 and j % 2 == 1 else color
			add_box(origin + Vector3(w * 0.5 - WALL_THICKNESS * 0.5, cy, z), Vector3(WALL_THICKNESS, h, side_len), c)
			add_box(origin + Vector3(-w * 0.5 + WALL_THICKNESS * 0.5, cy, z), Vector3(WALL_THICKNESS, h, side_len), c)
		if stairs:
			_add_ramp(origin, w, d, f, color.darkened(0.15))
	_add_slab(origin, footprint, floors * FLOOR_HEIGHT, slab_color, (floors - 1) % 2 if stairs else -1)


## Floor tiles at height y. hole_row >= 0 leaves out the two tiles a ramp comes up through.
func _add_slab(origin: Vector3, footprint: Vector2i, y: float, color: Color, hole_row: int) -> void:
	for i in footprint.x:
		for j in footprint.y:
			if j == hole_row and i < 2:
				continue
			var x := -footprint.x * CELL * 0.5 + CELL * (i + 0.5)
			var z := -footprint.y * CELL * 0.5 + CELL * (j + 0.5)
			add_box(origin + Vector3(x, y + SLAB_THICKNESS * 0.5, z), Vector3(CELL, SLAB_THICKNESS, CELL), color)


## Ramp from floor f up to floor f + 1 over the first two cells of the back row
## (rows alternate per floor so ramps never stack on top of each other).
func _add_ramp(origin: Vector3, w: float, d: float, f: int, color: Color) -> void:
	var row := f % 2
	var x0 := -w * 0.5 + WALL_THICKNESS
	var x1 := -w * 0.5 + CELL * 2.0
	var z0 := -d * 0.5 + CELL * row + (WALL_THICKNESS if row == 0 else 0.0)
	var z1 := -d * 0.5 + CELL * (row + 1)
	var bottom := f * FLOOR_HEIGHT + (SLAB_THICKNESS if f > 0 else 0.0)
	var top := (f + 1) * FLOOR_HEIGHT + SLAB_THICKNESS
	var run := x1 - x0
	var rise := top - bottom
	var angle := atan2(rise, run)
	var normal := Vector3(-sin(angle), cos(angle), 0)
	var center := Vector3((x0 + x1) * 0.5, (bottom + top) * 0.5, (z0 + z1) * 0.5) - normal * RAMP_THICKNESS * 0.5
	var ramp_size := Vector3(sqrt(run * run + rise * rise), RAMP_THICKNESS, z1 - z0)
	add_box(origin + center, ramp_size, color, Basis(Vector3.BACK, angle))


func _link_pieces() -> void:
	var n := _pieces.size()
	_loose.resize(n)
	_loose.fill(0)
	_grounded.resize(n)
	_up.resize(n)
	_side.resize(n)
	for i in n:
		_grounded[i] = 1 if _boxes[i].position.y <= EPS else 0
		_up[i] = []
		_side[i] = []
	# Sweep along y: once a piece starts above i's top, nothing later can touch i.
	var order := range(n)
	order.sort_custom(func(a: int, b: int) -> bool: return _boxes[a].position.y < _boxes[b].position.y)
	for oi in n:
		var i: int = order[oi]
		var top := _boxes[i].end.y + EPS
		for oj in range(oi + 1, n):
			var j: int = order[oj]
			if _boxes[j].position.y > top:
				break
			_link(i, j)


func _link(i: int, j: int) -> void:
	var a := _boxes[i]
	var b := _boxes[j]
	var ox := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var oy := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	var oz := minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	if ox < -EPS or oy < -EPS or oz < -EPS:
		return
	if ox > EPS and oz > EPS and absf(oy) <= EPS:
		if a.position.y < b.position.y:
			_up[i].append(j)
		else:
			_up[j].append(i)
	elif oy > EPS and (ox > EPS or oz > EPS):
		_side[i].append(j)
		_side[j].append(i)


## Earthquake tick; intensity is 0..1.
func quake(intensity: float) -> void:
	var expected := intensity * intensity * QUAKE_PIECES_PER_TICK / strength
	var count := int(expected) + (1 if randf() < expected - floorf(expected) else 0)
	var broke := false
	for k in count:
		var i := _pick_low_intact()
		if i < 0:
			break
		_release(i)
		broke = true
	if broke:
		_settle()
	for i in _pieces.size():
		if _loose[i]:
			var rb := _pieces[i]
			var push := Vector3(randf_range(-1, 1), randf_range(0, 0.3), randf_range(-1, 1))
			rb.apply_central_impulse(push * rb.mass * intensity * 1.5)


func damage_sphere(center: Vector3, radius: float, force: float) -> void:
	if not AABB(_bounds.position + global_position, _bounds.size).grow(radius).has_point(center):
		return
	for i in _pieces.size():
		var rb := _pieces[i]
		var offset := rb.global_position - center
		var dist := offset.length()
		if dist >= radius:
			continue
		if not _loose[i]:
			_release(i)
		rb.apply_central_impulse(offset.normalized() * force * rb.mass * (1.0 - dist / radius))
	_settle()


## Pushes every piece inside region (global, axis-aligned) with the acceleration
## force_at.call(global_pos) returns. Intact pieces tear loose when the force beats
## their hold. Meant to be called on a fixed tick of length delta.
func apply_field(region: AABB, force_at: Callable, delta: float) -> void:
	if not AABB(_bounds.position + global_position, _bounds.size).intersects(region):
		return
	var hold := HOLD_FORCE * strength
	var broke := false
	for i in _pieces.size():
		var rb := _pieces[i]
		var pos := rb.global_position
		if not region.has_point(pos):
			continue
		var force: Vector3 = force_at.call(pos)
		if force == Vector3.ZERO:
			continue
		if not _loose[i]:
			var over := force.length() / hold - 1.0
			if over <= 0.0 or randf() > minf(over, 1.0) * BREAK_RATE * delta:
				continue
			_release(i)
			broke = true
		rb.apply_central_impulse(force * rb.mass * delta)
	if broke:
		_settle()


func _release(i: int) -> void:
	_loose[i] = 1
	_pieces[i].freeze = false
	_pieces[i].sleeping = false


## Drops every intact piece that can't trace support back to the ground.
## Moving up through a resting contact resets the span; each sideways step costs one.
func _settle() -> void:
	var n := _pieces.size()
	var span := PackedInt32Array()
	span.resize(n)
	span.fill(MAX_SPAN + 1)
	var queue: Array[int] = []
	for i in n:
		if _grounded[i] and not _loose[i]:
			span[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		for j: int in _up[i]:
			if not _loose[j] and span[j] > 0:
				span[j] = 0
				queue.append(j)
		if span[i] < MAX_SPAN:
			for j: int in _side[i]:
				if not _loose[j] and span[j] > span[i] + 1:
					span[j] = span[i] + 1
					queue.append(j)
	for i in n:
		if not _loose[i] and span[i] > MAX_SPAN:
			_release(i)


## Random intact piece, biased toward lower floors so buildings fail from the bottom.
func _pick_low_intact() -> int:
	if _pieces.is_empty():
		return -1
	var best := -1
	for attempt in 12:
		var i := randi() % _pieces.size()
		if _loose[i]:
			continue
		if best < 0 or _boxes[i].position.y < _boxes[best].position.y:
			best = i
		if attempt >= 3 and best >= 0:
			break
	return best


static func _get_physics_material() -> PhysicsMaterial:
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
		_physics_material.friction = 0.9
		_physics_material.bounce = 0.05
	return _physics_material


static func _box_mesh(s: Vector3) -> BoxMesh:
	if not _meshes.has(s):
		var mesh := BoxMesh.new()
		mesh.size = s
		_meshes[s] = mesh
	return _meshes[s]


## Slightly smaller than the visual so freshly released neighbours don't start interpenetrating.
static func _box_shape(s: Vector3) -> BoxShape3D:
	if not _shapes.has(s):
		var shape := BoxShape3D.new()
		shape.size = s - Vector3.ONE * 0.02
		_shapes[s] = shape
	return _shapes[s]


static func _material(c: Color) -> StandardMaterial3D:
	if not _materials.has(c):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		_materials[c] = mat
	return _materials[c]
