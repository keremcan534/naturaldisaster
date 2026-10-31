extends Node3D
## A breakable structure made of box pieces: a building (walls, floor tiles,
## ramps) or props (trees, fences, cars).
##
## Intact pieces are frozen rigid bodies: the physics engine treats them as static,
## so a whole map costs almost nothing until something breaks. Damage unfreezes
## pieces, and after every hit a support pass drops whatever is no longer held up
## from the ground. Fill it with add_box()/add_building() before adding it to the tree.
##
## Intact pieces are drawn in batches, so a building is a handful of draw calls
## instead of hundreds: plain boxes are one unit cube scaled per instance, tinted
## per instance (Look.tinted()); boxes with their own material batch per material,
## custom visuals per mesh. A piece that comes loose leaves its batch (its
## instance shrinks to nothing) and shows its own mesh.

const Look := preload("res://scripts/world/look.gd")
const Interior := preload("res://scripts/world/interior.gd")
const Quality := preload("res://scripts/core/quality.gd")

const WALL_THICKNESS := 0.3
const SLAB_THICKNESS := 0.3
const RAMP_THICKNESS := 0.25
## Stairs: flat floor before the ramp starts, and how many cells of the back row
## the ramp spans (the next cell is the landing at the top).
const RAMP_LANDING := 1.0
const STAIR_CELLS := 3
const PARAPET_HEIGHT := 0.7
const PARAPET_THICKNESS := 0.25
const CELL := 2.0
const FLOOR_HEIGHT := 3.0
const FLOOR_WOOD := Color(0.52, 0.38, 0.26)
const WINDOW_COLOR := Look.GLASS_KEY
## Wall piece orientations: local +Z points out of the building.
const FACING_BACK := Basis(Vector3.UP, PI)
const FACING_RIGHT := Basis(Vector3.UP, PI * 0.5)
const FACING_LEFT := Basis(Vector3.UP, -PI * 0.5)
## How many pieces a piece may hang sideways from something supported below.
const MAX_SPAN := 2
const DENSITY := 1.5
const EPS := 0.01
const QUAKE_PIECES_PER_TICK := 6.0
## Acceleration (m/s²) an intact piece withstands at strength 1.
const HOLD_FORCE := 25.0
## Break chance per second when the force is double the hold.
const BREAK_RATE := 5.0
## Minimum time between dust puffs from one structure.
const DUST_INTERVAL_MS := 120
## Falling pieces: checked this often; losing this much speed at once is a hard hit.
const IMPACT_TICK := 0.1
const IMPACT_DV := 8.0
## Hit energy (mass * speed lost) that knocks an intact piece loose at strength 1.
const IMPACT_HOLD := 60.0
## Explosions shatter pieces within this fraction of their radius.
const SHATTER_RADIUS := 0.55

## Loose pieces still moving, across all structures. Past the quality level's
## "chaos" budget, pieces that break off crumble to dust instead of tumbling, so
## a whole town coming down can't drown the physics on a phone.
static var awake := 0

static var _meshes := {}
static var _shapes := {}
static var _physics_material: PhysicsMaterial
## A batch instance that is no longer drawn.
const _HIDDEN_SCALE := Basis(Vector3(0.0001, 0, 0), Vector3(0, 0.0001, 0), Vector3(0, 0, 0.0001))

## Higher survives more shaking.
@export var strength := 1.0

var _pieces: Array[RigidBody3D] = []
var _boxes: Array[AABB] = []
## Per piece: size and color (for breaking it into chunks), and whether it is a
## plain box that can break up that way.
var _sizes: Array[Vector3] = []
var _colors: Array[Color] = []
var _solid: Array[bool] = []
## Per piece: its own mesh (hidden while it is batched), its batch and slot there.
var _visuals: Array[MeshInstance3D] = []
var _batch_of := PackedInt32Array()
var _slot_of := PackedInt32Array()
var _batches: Array[MultiMesh] = []
## Per piece: [mesh, material] of its batch, and its instance color there.
var _batch_keys: Array[Array] = []
var _tints: Array[Color] = []
var _loose := PackedByteArray()
## Pieces broken into debris chunks (hidden, no collision).
var _gone := PackedByteArray()
## Loose pieces still moving, watched for hard hits; their speed last tick.
var _moving: Array[int] = []
var _last_speed := PackedFloat32Array()
var _impact_timer := 0.0
var _grounded := PackedByteArray()
## Per piece: indices of pieces resting on it / touching it sideways.
var _up: Array[Array] = []
var _side: Array[Array] = []
var _bounds := AABB()
var _last_dust_ms := -DUST_INTERVAL_MS


func _ready() -> void:
	add_to_group("structures")
	_link_pieces()
	_build_batches()


## center is in this node's local space. A rotated piece links to its neighbours
## through its axis-aligned bounds. visual replaces the box mesh (tree canopies,
## trunks); the collision shape stays a box. material replaces Look.surface(color)
## on the box (color still picks the debris look). Returns the piece, e.g. to tag
## it with a "bounce" or "ladder" meta the player reacts to.
func add_box(center: Vector3, box_size: Vector3, color: Color, rotation_basis := Basis.IDENTITY, visual: Mesh = null,
		material: Material = null) -> RigidBody3D:
	# Pieces are linked and batched in _ready(); later ones would be left out.
	assert(not is_inside_tree(), "Add pieces before adding the structure to the tree.")
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
	if visual:
		mesh.mesh = visual
	else:
		mesh.mesh = _box_mesh(box_size)
		mesh.material_override = material if material else Look.surface(color)
	mesh.visible = false
	if color == WINDOW_COLOR:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rb.add_child(mesh)
	add_child(rb)
	_visuals.append(mesh)
	if visual:
		_batch_keys.append([visual, null])
		_tints.append(Color.WHITE)
	elif material or Look.is_special(color):
		_batch_keys.append([_unit_box(), mesh.material_override])
		_tints.append(Color.WHITE)
	else:
		_batch_keys.append([_unit_box(), Look.tinted()])
		_tints.append(color)

	var box := rb.transform * AABB(-box_size * 0.5, box_size)
	_pieces.append(rb)
	_boxes.append(box)
	_sizes.append(box_size)
	_colors.append(color)
	_solid.append(visual == null)
	_bounds = box if _pieces.size() == 1 else _bounds.merge(box)
	return rb


## A sloped slab whose top surface runs from a to b (local space; the slope is
## along x or z), width across. Ramps, escalators, slides.
func add_incline(a: Vector3, b: Vector3, width: float, thickness: float, color: Color) -> RigidBody3D:
	var along := b - a
	var dir := along.normalized()
	var flat := Vector3(along.x, 0, along.z).normalized()
	var side := flat.cross(Vector3.UP)
	var normal := side.cross(dir).normalized()
	if normal.y < 0.0:
		normal = -normal
	var center := (a + b) * 0.5 - normal * thickness * 0.5
	var basis := Basis(dir, normal, dir.cross(normal))
	return add_box(center, Vector3(along.length(), thickness, width), color, basis)


## A building with its front door facing +Z. With stairs (footprint at least 4x3),
## ramps along the back-left connect every floor and the roof. Floors get
## rooms and furniture (see interior.gd).
func add_building(origin: Vector3, footprint: Vector2i, floors: int, color: Color, with_stairs := true, office := false) -> void:
	var stairs := with_stairs and footprint.x >= STAIR_CELLS + 1 and footprint.y >= 3
	# Wooden floors and white ceilings inside; the edges show as a band between storeys.
	var slab_color := color.darkened(0.3)
	var slab_material := Look.slab(FLOOR_WOOD, slab_color)
	# The ground floor stands on the island; give it a floor to look at (visual only).
	var ground_floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(footprint) * CELL
	plane.material = slab_material
	ground_floor.mesh = plane
	ground_floor.position = origin + Vector3(0, 0.005, 0)
	add_child(ground_floor)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(origin + position)
	var w := footprint.x * CELL
	var d := footprint.y * CELL
	var door := footprint.x / 2
	for f in floors:
		var y0 := f * FLOOR_HEIGHT
		if f > 0:
			_add_slab(origin, footprint, y0, slab_color, stairs, slab_material)
		var wall_bottom := y0 + (SLAB_THICKNESS if f > 0 else 0.0)
		var h := y0 + FLOOR_HEIGHT - wall_bottom
		var cy := wall_bottom + h * 0.5
		# Front/back walls span the full width; side walls fit between them. Every
		# wall piece is turned so its local +Z faces outward (the window shader needs it).
		for i in footprint.x:
			var x := -w * 0.5 + CELL * (i + 0.5)
			var c := WINDOW_COLOR if i % 2 == 1 and not (f == 0 and i == door) else color
			var mat := _wall_material(c)
			var panel := Vector3(CELL, h, WALL_THICKNESS)
			if not (f == 0 and i == door):
				add_box(origin + Vector3(x, cy, d * 0.5 - WALL_THICKNESS * 0.5), panel, c, Basis.IDENTITY, null, mat)
			add_box(origin + Vector3(x, cy, -d * 0.5 + WALL_THICKNESS * 0.5), panel, c, FACING_BACK, null, mat)
		var side_len := (d - WALL_THICKNESS * 2.0) / footprint.y
		for j in footprint.y:
			var z := -d * 0.5 + WALL_THICKNESS + side_len * (j + 0.5)
			var c := WINDOW_COLOR if j % 2 == 1 else color
			var mat := _wall_material(c)
			var panel := Vector3(side_len, h, WALL_THICKNESS)
			add_box(origin + Vector3(w * 0.5 - WALL_THICKNESS * 0.5, cy, z), panel, c, FACING_RIGHT, null, mat)
			add_box(origin + Vector3(-w * 0.5 + WALL_THICKNESS * 0.5, cy, z), panel, c, FACING_LEFT, null, mat)
		if stairs:
			_add_ramp(origin, w, d, f, color.darkened(0.15))
		Interior.furnish(self, origin, footprint, f, wall_bottom, h, stairs, CELL, WALL_THICKNESS, rng, office)
	var roof := floors * FLOOR_HEIGHT
	_add_slab(origin, footprint, roof, slab_color, stairs, Look.roof(slab_color))
	_add_parapet(origin, footprint, roof + SLAB_THICKNESS, color.darkened(0.1))
	if footprint.x >= 3 and footprint.y >= 3:
		# An air-conditioning unit on the front-right roof tile (away from the stair hole).
		var unit := Vector3(1.2, 0.8, 1.0)
		var pos := Vector3(w * 0.5 - CELL * 0.5, roof + SLAB_THICKNESS + unit.y * 0.5, d * 0.5 - CELL * 0.5)
		add_box(origin + pos, unit, Color(0.62, 0.64, 0.66))


## A low wall around the roof edge, sitting on the outer roof tiles.
func _wall_material(color: Color) -> Material:
	return Look.surface(color) if color == WINDOW_COLOR else Look.wall(color)


func _add_parapet(origin: Vector3, footprint: Vector2i, y: float, color: Color) -> void:
	var w := footprint.x * CELL
	var d := footprint.y * CELL
	var cy := y + PARAPET_HEIGHT * 0.5
	for i in footprint.x:
		var x := -w * 0.5 + CELL * (i + 0.5)
		var panel := Vector3(CELL, PARAPET_HEIGHT, PARAPET_THICKNESS)
		add_box(origin + Vector3(x, cy, d * 0.5 - PARAPET_THICKNESS * 0.5), panel, color)
		add_box(origin + Vector3(x, cy, -d * 0.5 + PARAPET_THICKNESS * 0.5), panel, color, FACING_BACK)
	var side_len := (d - PARAPET_THICKNESS * 2.0) / footprint.y
	for j in footprint.y:
		var z := -d * 0.5 + PARAPET_THICKNESS + side_len * (j + 0.5)
		var panel := Vector3(side_len, PARAPET_HEIGHT, PARAPET_THICKNESS)
		add_box(origin + Vector3(w * 0.5 - PARAPET_THICKNESS * 0.5, cy, z), panel, color, FACING_RIGHT)
		add_box(origin + Vector3(-w * 0.5 + PARAPET_THICKNESS * 0.5, cy, z), panel, color, FACING_LEFT)


## Floor tiles at height y. stair_hole leaves out the tiles the ramp from the
## floor below comes up through (see _add_ramp).
func _add_slab(origin: Vector3, footprint: Vector2i, y: float, color: Color, stair_hole: bool, material: Material) -> void:
	for i in footprint.x:
		for j in footprint.y:
			if stair_hole and j == 0 and (i == 1 or i == 2):
				continue
			var x := -footprint.x * CELL * 0.5 + CELL * (i + 0.5)
			var z := -footprint.y * CELL * 0.5 + CELL * (j + 0.5)
			add_box(origin + Vector3(x, y + SLAB_THICKNESS * 0.5, z), Vector3(CELL, SLAB_THICKNESS, CELL), color, Basis.IDENTITY, null, material)


## Ramp from floor f up to floor f + 1 along the back row: it starts a landing's
## length from the left wall (walk straight onto it) and ends at the fourth
## column, where the floor above continues. Every floor's ramp sits right above
## the one below, a storey higher; the second row stays free as a walkway from
## the top of one ramp back to the foot of the next.
func _add_ramp(origin: Vector3, w: float, d: float, f: int, color: Color) -> void:
	var x0 := -w * 0.5 + WALL_THICKNESS + RAMP_LANDING
	var x1 := -w * 0.5 + CELL * STAIR_CELLS
	var z := -d * 0.5 + (CELL + WALL_THICKNESS) * 0.5
	var bottom := f * FLOOR_HEIGHT + (SLAB_THICKNESS if f > 0 else 0.0)
	var top := (f + 1) * FLOOR_HEIGHT + SLAB_THICKNESS
	add_incline(origin + Vector3(x0, bottom, z), origin + Vector3(x1, top, z), CELL - WALL_THICKNESS, RAMP_THICKNESS, color)


## One MultiMeshInstance per mesh/material pair, holding every intact piece of it.
func _build_batches() -> void:
	var groups := {}
	for i in _pieces.size():
		var key := _batch_keys[i]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	_batch_of.resize(_pieces.size())
	_slot_of.resize(_pieces.size())
	for key: Array in groups:
		var members: Array = groups[key]
		var unit: bool = key[0] == _unit_box()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = key[1] == Look.tinted()
		multimesh.mesh = key[0]
		multimesh.instance_count = members.size()
		for slot in members.size():
			var i: int = members[slot]
			multimesh.set_instance_transform(slot, _batch_transform(i, unit))
			if multimesh.use_colors:
				multimesh.set_instance_color(slot, _tints[i])
			_batch_of[i] = _batches.size()
			_slot_of[i] = slot
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = key[1]
		batch.cast_shadow = _visuals[members[0]].cast_shadow
		add_child(batch)
		_batches.append(multimesh)


## Unit cubes carry the piece's size in their instance transform.
func _batch_transform(i: int, unit: bool) -> Transform3D:
	var t := _pieces[i].transform
	return Transform3D(t.basis * Basis.from_scale(_sizes[i]), t.origin) if unit else t


func _unbatch(i: int) -> void:
	var multimesh := _batches[_batch_of[i]]
	multimesh.set_instance_transform(_slot_of[i], Transform3D(_HIDDEN_SCALE, _pieces[i].transform.origin))


func _link_pieces() -> void:
	var n := _pieces.size()
	_loose.resize(n)
	_loose.fill(0)
	_gone.resize(n)
	_gone.fill(0)
	_last_speed.resize(n)
	_last_speed.fill(0.0)
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
		if _loose[i] and not _gone[i]:
			var rb := _pieces[i]
			# Loose things hop and slide around while the ground heaves.
			var push := Vector3(randf_range(-1, 1), randf_range(0.1, 0.6), randf_range(-1, 1))
			rb.apply_central_impulse(push * rb.mass * intensity * 3.0)


func damage_sphere(center: Vector3, radius: float, force: float) -> void:
	if not AABB(_bounds.position + global_position, _bounds.size).grow(radius).has_point(center):
		return
	for i in _pieces.size():
		if _gone[i]:
			continue
		var rb := _pieces[i]
		var offset := rb.global_position - center
		var dist := offset.length()
		if dist >= radius:
			continue
		if dist < radius * SHATTER_RADIUS:
			_shatter(i, center, force * (1.0 - dist / radius))
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
		if _gone[i]:
			continue
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
			broke = true
			# Far beyond what it can hold: it doesn't come off whole.
			if over > 1.0 and randf() < 0.5:
				_shatter(i, pos - force.normalized(), force.length() * 0.12)
				continue
			_release(i)
		rb.apply_central_impulse(force * rb.mass * delta)
	if broke:
		_settle()


## A falling piece (or anything) hit something hard at pos: intact pieces right
## there may be knocked loose, so collapses spread.
func impact(pos: Vector3, energy: float) -> void:
	if not AABB(_bounds.position + global_position, _bounds.size).grow(1.0).has_point(pos):
		return
	var chance := energy / (IMPACT_HOLD * strength)
	var broke := false
	for i in _pieces.size():
		if _loose[i]:
			continue
		var box := AABB(_boxes[i].position + global_position, _boxes[i].size).grow(0.5)
		if box.has_point(pos) and randf() < chance:
			_release(i)
			broke = true
	if broke:
		_settle()


func _physics_process(delta: float) -> void:
	if _moving.is_empty():
		return
	_impact_timer -= delta
	if _impact_timer > 0.0:
		return
	_impact_timer = IMPACT_TICK
	var k := 0
	while k < _moving.size():
		var i := _moving[k]
		var rb := _pieces[i]
		if _gone[i] or rb.sleeping:
			_moving.remove_at(k)
			awake -= 1
			continue
		k += 1
		var speed := rb.linear_velocity.length()
		var lost := _last_speed[i] - speed
		_last_speed[i] = speed
		if lost < IMPACT_DV:
			continue
		var pos := rb.global_position
		get_tree().call_group("effects", "dust", pos)
		get_tree().call_group("structures", "impact", pos, lost * rb.mass)
		get_tree().call_group("player", "rumble", pos, lost * rb.mass)
		if randf() < clampf((lost - IMPACT_DV) / 10.0, 0.15, 0.7):
			_shatter(i, pos + Vector3.DOWN, lost * 0.3)


func _release(i: int) -> void:
	if _loose[i]:
		return
	# Glass never comes out in one piece.
	if _solid[i] and _colors[i] == WINDOW_COLOR:
		_shatter(i, _pieces[i].global_position - _pieces[i].global_basis.z, 2.5)
		return
	if awake >= Quality.current().chaos:
		_crumble(i)
		return
	_dust(_pieces[i].global_position)
	_unbatch(i)
	_visuals[i].visible = true
	_loose[i] = 1
	_pieces[i].freeze = false
	_pieces[i].sleeping = false
	_last_speed[i] = 0.0
	_moving.append(i)
	awake += 1


## Over the chaos budget: the piece turns to dust where it stands.
func _crumble(i: int) -> void:
	var rb := _pieces[i]
	get_tree().call_group("effects", "dust", rb.global_position)
	_unbatch(i)
	_loose[i] = 1
	_gone[i] = 1
	rb.freeze = true
	rb.visible = false
	rb.collision_layer = 0
	rb.collision_mask = 0


## Replaces a piece with debris chunks flying away from `from` at up to `power` m/s.
## Pieces with a custom look (trees) just come loose.
func _shatter(i: int, from: Vector3, power: float) -> void:
	if not _solid[i]:
		_release(i)
		return
	var rb := _pieces[i]
	_dust(rb.global_position)
	get_tree().call_group("debris", "shatter", rb.global_transform, _sizes[i], _colors[i], rb.linear_velocity, from, power)
	_unbatch(i)
	_loose[i] = 1
	_gone[i] = 1
	rb.freeze = true
	rb.visible = false
	rb.collision_layer = 0
	rb.collision_mask = 0


func _dust(pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_dust_ms >= DUST_INTERVAL_MS:
		_last_dust_ms = now
		get_tree().call_group("effects", "dust", pos)


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


static func _unit_box() -> BoxMesh:
	return _box_mesh(Vector3.ONE)


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

