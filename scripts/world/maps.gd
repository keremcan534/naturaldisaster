extends RefCounted
## Map layouts. Each round builds one under a fresh root node; the previous root
## is freed, so a map always starts intact.

const Structure := preload("res://scripts/world/structure.gd")
const Look := preload("res://scripts/world/look.gd")
const Mall := preload("res://scripts/world/mall.gd")
const Quality := preload("res://scripts/core/quality.gd")

const COUNT := 5
const PLAZA_COLOR := Color(0.72, 0.7, 0.66)
const TRAMPOLINE_COLOR := Color(0.15, 0.45, 0.95)
## Clutter: how weakly it holds (it should fly first), how much per meter of map.
const CLUTTER_STRENGTH := 0.45
const CLUTTER_PER_METER := 0.6
const CLUTTER := ["crate", "crate", "barrel", "barrel", "bin", "bench", "mailbox", "table"]
## Launch speed (m/s) off a trampoline.
const BOUNCE := 13.0
const LEAF_COLOR := Color(0.22, 0.48, 0.2)
const LEAF_LIGHT_COLOR := Color(0.32, 0.58, 0.24)
const TRUNK_COLOR := Color(0.45, 0.3, 0.18)
const FENCE_COLOR := Color(0.92, 0.9, 0.85)
const ROAD_COLOR := Color(0.2, 0.2, 0.22)
const GRASS_COLOR := Color(0.27, 0.43, 0.19)
const POOL_RIM_COLOR := Color(0.78, 0.76, 0.72)
const WHEEL_COLOR := Color(0.08, 0.08, 0.09)
## How far the island's rock sides reach down (they go below the sea).
const CLIFF_DEPTH := 14.0
const PATH_COLOR := Color(0.7, 0.66, 0.6)
const EPS_FENCE := 0.01
## Grass tufts per square meter; the cap and draw distance come from the quality
## level. Grass is split into square chunks so only nearby ones are drawn.
const GRASS_DENSITY := 3.0
const GRASS_CHUNK := 16.0
## Flowers grow in clumps: clumps per square meter, flowers per clump.
const FLOWER_CLUMPS := 0.05
const FLOWERS_PER_CLUMP := 9
const FLOWER_COLORS := [Color(0.97, 0.97, 0.95), Color(0.95, 0.85, 0.2), Color(0.85, 0.12, 0.1),
		Color(0.6, 0.35, 0.85), Color(0.55, 0.7, 0.95), Color(0.98, 0.6, 0.75)]
const CAR_COLORS := [Color(0.8, 0.15, 0.15), Color(0.15, 0.3, 0.75), Color(0.9, 0.9, 0.9), Color(0.2, 0.2, 0.22)]


## Filled while a map is built: where grass grows, where it can't (roads,
## buildings, ...), and what casts a contact shadow on the ground.
static var _grass_areas: Array[Rect2] = []
static var _bare: Array[Rect2] = []
static var _shades: Array[Rect2] = []
## Roads on this map: [center, length, along_x], for street lamps.
static var _roads: Array[Array] = []
## For bots (see bot.gd): ways up to high ground, each {"path": waypoints in
## world space (the last one on top), "height": how high it ends, "structure":
## the building, "stairs": true for stairs inside (false for a ladder outside)}.
## buildings: building footprints (world XZ), to keep away from in quakes.
static var refuges: Array[Dictionary] = []
static var buildings: Array[Rect2] = []


## Builds map `index` under root and returns {name, size, spawn}.
static func build(index: int, root: Node3D) -> Dictionary:
	_grass_areas.clear()
	_bare.clear()
	_shades.clear()
	_roads.clear()
	refuges.clear()
	var info: Dictionary
	match index:
		0:
			info = _skyscraper(root)
		1:
			info = _garden_house(root)
		2:
			info = _apartment(root)
		3:
			info = _neighbourhood(root)
		_:
			info = _mall(root)
	_clutter(root, info.size, info.spawn, index)
	_scatter_grass(root, index)
	Look.set_shades(_shades)
	buildings = _shades.duplicate()
	return info


## A ladder up a building's wall as a refuge: walk to its foot, climb, step onto
## the roof. The ladder's thin side (local +Z) faces away from the wall.
static func _add_ladder_refuge(building: Structure, rung: Node3D, top: float) -> void:
	var out := rung.transform.basis.z
	out = Vector3(out.x, 0, out.z).normalized()
	var at := building.position + Vector3(rung.position.x, 0, rung.position.z)
	refuges.append({"path": [at + out * 1.0, at - out * 2.2 + Vector3(0, top, 0)], "height": top,
			"structure": building, "stairs": false})


static func _add_stairs_refuge(building: Structure) -> void:
	if building.climb_path.is_empty():
		return
	var path: Array[Vector3] = []
	for p in building.climb_path:
		path.append(building.position + p)
	refuges.append({"path": path, "height": building.roof_height, "structure": building, "stairs": true})


static func _skyscraper(root: Node3D) -> Dictionary:
	var size := 56.0
	_ground(root, size, Color(0.55, 0.55, 0.52))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_decal(root, Vector3(corner.x * 19, 0, corner.y * 19), Vector2(14, 14), GRASS_COLOR)
	_building(root, Vector3(0, 0, -2), Vector2i(5, 5), 10, Color(0.7, 0.76, 0.82), 2.6, false, true, true)
	var props := _props()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_tree(props, Vector3(corner.x * 19, 0, corner.y * 19))
	_car(props, Vector3(-14, 0, 14), false, CAR_COLORS[0])
	_car(props, Vector3(14, 0, 10), false, CAR_COLORS[1])
	root.add_child(props)
	return {"name": "Gökdelen", "size": size, "spawn": Vector3(0, 0.5, 20)}


static func _garden_house(root: Node3D) -> Dictionary:
	var size := 44.0
	_ground(root, size, GRASS_COLOR)
	_decal(root, Vector3(0, 0, 9), Vector2(2, 14), PATH_COLOR)
	_pool(root, Vector3(-10, 0, 6), Vector2(6, 4))
	_building(root, Vector3(0, 0, -6), Vector2i(6, 5), 2, Color(0.9, 0.82, 0.68), 1.0, true)
	_building(root, Vector3(12, 0, -1), Vector2i(3, 3), 1, Color(0.6, 0.42, 0.3), 0.8)
	var props := _props()
	_fence(props, Rect2(-18, -18, 36, 34), 2.0)
	_trampoline(props, Vector3(9, 0, 9))
	_slide(props, Vector3(-15, 0, -4))
	for pos: Vector3 in [Vector3(-12, 0, -13), Vector3(12, 0, -13), Vector3(-14, 0, 12), Vector3(13, 0, 10)]:
		_tree(props, pos)
	root.add_child(props)
	return {"name": "Bahçeli Ev", "size": size, "spawn": Vector3(0, 0.5, 12)}


static func _apartment(root: Node3D) -> Dictionary:
	var size := 50.0
	_ground(root, size, GRASS_COLOR)
	_road(root, Vector3(0, 0, 14), size, true)
	_decal(root, Vector3(0, 0, 5.5), Vector2(2, 7), PATH_COLOR)
	_building(root, Vector3(0, 0, -3), Vector2i(7, 5), 6, Color(0.85, 0.62, 0.5), 2.0, true)
	var props := _props()
	for i in 4:
		_car(props, Vector3(-15 + i * 10, 0, 14), i % 2 == 0, CAR_COLORS[i])
	_tree(props, Vector3(-16, 0, -12))
	_tree(props, Vector3(16, 0, -12))
	root.add_child(props)
	return {"name": "Apartman", "size": size, "spawn": Vector3(0, 0.5, 20)}


static func _neighbourhood(root: Node3D) -> Dictionary:
	var size := 76.0
	_ground(root, size, GRASS_COLOR)
	_road(root, Vector3.ZERO, size, false)
	_road(root, Vector3(0, 0.003, 0), size, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var colors := [Color(0.85, 0.78, 0.66), Color(0.78, 0.55, 0.45), Color(0.7, 0.74, 0.78), Color(0.62, 0.68, 0.58)]
	var lots := [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18, 0, 18)]
	for k in lots.size():
		var footprint := Vector2i(rng.randi_range(4, 6), rng.randi_range(4, 5))
		_building(root, lots[k], footprint, rng.randi_range(2, 5), colors[k], rng.randf_range(0.75, 1.15), k % 2 == 0)
	var props := _props()
	for pos: Vector3 in [Vector3(-30, 0, -6), Vector3(30, 0, 6), Vector3(-6, 0, 30), Vector3(6, 0, -30)]:
		_tree(props, pos)
	_car(props, Vector3(-2, 0, 22), false, CAR_COLORS[0])
	_car(props, Vector3(24, 0, 2), true, CAR_COLORS[2])
	_trampoline(props, Vector3(-8, 0, 8))
	_trampoline(props, Vector3(8, 0, -8))
	_slide(props, Vector3(6, 0, 30))
	root.add_child(props)
	return {"name": "Mahalle", "size": size, "spawn": Vector3(0, 0.5, 0)}


static func _ground(root: Node3D, size: float, color: Color) -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.material = Look.ground(color)
	top.mesh = plane
	ground.add_child(top)
	if color == GRASS_COLOR:
		_grass_areas.append(Rect2(-size * 0.5, -size * 0.5, size, size))
	# Rock sides down into the sea, so the map reads as an island with an edge you can fall off.
	var cliff := MeshInstance3D.new()
	var rock := BoxMesh.new()
	rock.size = Vector3(size, CLIFF_DEPTH, size)
	rock.material = Look.cliff()
	cliff.mesh = rock
	cliff.position.y = -CLIFF_DEPTH * 0.5 - 0.03
	cliff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(cliff)
	root.add_child(ground)


## Purely visual flat patch (roads, paths, pools).
static func _decal(root: Node3D, center: Vector3, size: Vector2, color: Color) -> void:
	_flat(root, center, size, Look.ground(color))
	var rect := _rect(center, size)
	if color == GRASS_COLOR:
		_grass_areas.append(rect)
	else:
		_bare.append(rect)


## A road with lane markings along Z, or along X.
static func _road(root: Node3D, center: Vector3, length: float, along_x: bool) -> void:
	var road := _flat(root, center, Vector2(8, length), Look.ground(ROAD_COLOR, Vector2(8, length)))
	if along_x:
		road.rotation.y = PI * 0.5
	_bare.append(_rect(center, Vector2(length, 8) if along_x else Vector2(8, length)))
	_roads.append([center, length, along_x])


static func _pool(root: Node3D, center: Vector3, size: Vector2) -> void:
	_bare.append(_rect(center, size + Vector2(1.2, 1.2)))
	_flat(root, center, size + Vector2(1.2, 1.2), Look.ground(POOL_RIM_COLOR))
	_flat(root, center + Vector3(0, 0.005, 0), size, Look.water())


static func _flat(root: Node3D, center: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = material
	mesh.mesh = plane
	mesh.position = center + Vector3(0, 0.01, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return mesh


## ladder: a ladder up the right side to the roof. office: lobby and desks inside.
## helipad: an H painted on the roof.
static func _building(root: Node3D, pos: Vector3, footprint: Vector2i, floors: int, color: Color, strength: float,
		ladder := false, office := false, helipad := false) -> Structure:
	var building := Structure.new()
	building.position = pos
	building.strength = strength
	building.add_building(Vector3.ZERO, footprint, floors, color, true, office)
	if ladder:
		var height := floors * Structure.FLOOR_HEIGHT + Structure.SLAB_THICKNESS + Structure.PARAPET_HEIGHT + 1.0
		var x := footprint.x * Structure.CELL * 0.5 + 0.08
		var z := (footprint.y % 2) * Structure.CELL * 0.5
		var rung := building.add_box(Vector3(x, height * 0.5, z), Vector3(0.6, height, 0.12), Color(0.75, 0.62, 0.2),
				Basis(Vector3.UP, PI * 0.5), Look.ladder(height))
		rung.set_meta("ladder", true)
		_add_ladder_refuge(building, rung, building.roof_height)
	_add_stairs_refuge(building)
	if helipad:
		_helipad(building, Vector3(1.0, floors * Structure.FLOOR_HEIGHT + Structure.SLAB_THICKNESS, 1.0))
	root.add_child(building)
	var rect := _rect(pos, Vector2(footprint) * Structure.CELL)
	_bare.append(rect)
	_shades.append(rect)
	return building


## A big bouncy pad on a dark frame; landing on it throws you up.
static func _trampoline(props: Structure, pos: Vector3) -> void:
	props.add_box(pos + Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 2.4), Color(0.15, 0.15, 0.17))
	var pad := props.add_box(pos + Vector3(0, 0.45, 0), Vector3(2.0, 0.1, 2.0), TRAMPOLINE_COLOR)
	pad.set_meta("bounce", BOUNCE)
	_bare.append(_rect(pos, Vector2(2.4, 2.4)))


## A slide: a post and platform with a ladder at the back and a steep chute down
## toward +x.
static func _slide(props: Structure, pos: Vector3) -> void:
	var top := 2.6
	props.add_box(pos + Vector3(0, (top - 0.15) * 0.5, 0), Vector3(0.3, top - 0.15, 0.3), Color(0.85, 0.2, 0.2))
	props.add_box(pos + Vector3(0, top - 0.075, 0), Vector3(1.4, 0.15, 1.4), Color(0.95, 0.75, 0.15))
	var ladder_height := top + 1.3
	var ladder := props.add_box(pos + Vector3(-0.78, ladder_height * 0.5, 0), Vector3(0.6, ladder_height, 0.12),
			Color(0.75, 0.62, 0.2), Basis(Vector3.UP, -PI * 0.5), Look.ladder(ladder_height))
	ladder.set_meta("ladder", true)
	props.add_incline(pos + Vector3(0.7, top, 0), pos + Vector3(3.0, 0.08, 0), 0.9, 0.12, Color(0.2, 0.55, 0.95))
	_bare.append(_rect(pos + Vector3(1.0, 0, 0), Vector2(4.2, 1.6)))


## A painted H on a roof, for show.
static func _helipad(building: Structure, center: Vector3) -> void:
	var paint := Color(0.95, 0.8, 0.15)
	building.add_box(center + Vector3(-0.9, 0.01, 0), Vector3(0.35, 0.02, 2.6), paint)
	building.add_box(center + Vector3(0.9, 0.01, 0), Vector3(0.35, 0.02, 2.6), paint)
	building.add_box(center + Vector3(0, 0.01, 0), Vector3(1.45, 0.02, 0.35), paint)


static func _mall(root: Node3D) -> Dictionary:
	var size := 72.0
	_ground(root, size, GRASS_COLOR)
	_road(root, Vector3(0, 0, 27), size, true)
	_decal(root, Vector3(0, 0, 10), Vector2(16, 18), PLAZA_COLOR)
	var mall := Structure.new()
	mall.position = Vector3(0, 0, -8)
	mall.strength = 2.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	Mall.build(mall, rng)
	var roof := Mall.FLOORS * Structure.FLOOR_HEIGHT + Structure.SLAB_THICKNESS
	_car(mall, Vector3(-8, roof, 5), false, CAR_COLORS[0])
	_car(mall, Vector3(7, roof, -6), true, CAR_COLORS[1])
	_car(mall, Vector3(8, roof, 5), false, CAR_COLORS[2])
	root.add_child(mall)
	for piece in mall.get_children():
		if piece.has_meta("ladder"):
			_add_ladder_refuge(mall, piece, roof)
	var rect := _rect(mall.position, Vector2(Mall.SIZE) * Structure.CELL)
	_bare.append(rect)
	_shades.append(rect)

	var props := _props()
	_trampoline(props, Vector3(-5, 0, 12))
	_trampoline(props, Vector3(5, 0, 12))
	for x: float in [-30.0, -20.0, 20.0, 30.0]:
		_tree(props, Vector3(x, 0, 12))
	for pos: Vector3 in [Vector3(-28, 0, -26), Vector3(28, 0, -26), Vector3(-28, 0, -6), Vector3(28, 0, -6)]:
		_tree(props, pos)
	for i in 4:
		_car(props, Vector3(-24 + i * 14, 0, 27), true, CAR_COLORS[(i + 1) % CAR_COLORS.size()])
	root.add_child(props)
	return {"name": "AVM", "size": size, "spawn": Vector3(0, 0.5, 19)}


## Loose odds and ends all over the map, and street lamps along the roads: one
## weak structure, so disasters throw it all around. Kept off buildings, roads
## (cones excepted) and the spawn point.
static func _clutter(root: Node3D, size: float, spawn: Vector3, seed_value: int) -> void:
	var s := Structure.new()
	s.strength = CLUTTER_STRENGTH
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	for road: Array in _roads:
		var center: Vector3 = road[0]
		var length: float = road[1]
		var along := Vector3.RIGHT if road[2] else Vector3.BACK
		var across := along.cross(Vector3.UP)
		var t := -length * 0.5 + 6.0
		var side := 1.0
		while t < length * 0.5 - 4.0:
			var pos := center + along * t + across * 4.7 * side
			if not _is_bare(Vector2(pos.x, pos.z), 0.4) and absf(pos.x) < size * 0.5 - 1.0 and absf(pos.z) < size * 0.5 - 1.0:
				_lamp(s, Vector3(pos.x, 0, pos.z))
			# A cone on the road now and then.
			if rng.randf() < 0.35:
				var cone := center + along * (t + 3.0) + across * rng.randf_range(-3.0, 3.0)
				s.add_box(Vector3(cone.x, 0.35, cone.z), Vector3(0.5, 0.7, 0.5), Color(1.0, 0.45, 0.05), Basis.IDENTITY,
						Look.cylinder(0.25, 0.03, 0.7, Color(1.0, 0.45, 0.05)))
			t += 11.0
			side = -side
	var count := int(size * CLUTTER_PER_METER)
	var tries := count * 6
	while count > 0 and tries > 0:
		tries -= 1
		var half := size * 0.5 - 2.0
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if _is_bare(p, 0.8) or p.distance_to(Vector2(spawn.x, spawn.z)) < 4.0:
			continue
		_clutter_item(s, CLUTTER[rng.randi() % CLUTTER.size()], Vector3(p.x, 0, p.y), rng)
		_bare.append(_rect(Vector3(p.x, 0, p.y), Vector2(1.6, 1.6)))
		count -= 1
	root.add_child(s)


static func _clutter_item(s: Structure, kind: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var turn := Basis(Vector3.UP, rng.randf() * TAU)
	match kind:
		"crate":
			var stack := rng.randi_range(1, 3)
			for k in stack:
				s.add_box(pos + Vector3(0, 0.45 + k * 0.9, 0), Vector3(0.9, 0.9, 0.9), Color(0.6, 0.45, 0.25),
						turn.rotated(Vector3.UP, rng.randf_range(-0.3, 0.3)))
		"barrel":
			var color: Color = [Color(0.75, 0.15, 0.12), Color(0.15, 0.35, 0.7), Color(0.3, 0.5, 0.25)][rng.randi() % 3]
			s.add_box(pos + Vector3(0, 0.45, 0), Vector3(0.64, 0.9, 0.64), color, turn, Look.cylinder(0.32, 0.32, 0.9, color))
		"bin":
			s.add_box(pos + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6), Color(0.2, 0.35, 0.25), turn)
		"bench":
			s.add_box(pos + Vector3(0, 0.22, 0), Vector3(1.6, 0.44, 0.5), Color(0.5, 0.33, 0.2), turn)
			s.add_box(pos + Vector3(0, 0.66, 0) + turn * Vector3(0, 0, -0.22), Vector3(1.6, 0.44, 0.06), Color(0.5, 0.33, 0.2), turn)
		"mailbox":
			var color: Color = [Color(0.15, 0.3, 0.75), Color(0.8, 0.15, 0.1)][rng.randi() % 2]
			s.add_box(pos + Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.45), color, turn)
		"table":
			s.add_box(pos + Vector3(0, 0.37, 0), Vector3(0.12, 0.74, 0.7), Color(0.45, 0.32, 0.2), turn)
			s.add_box(pos + Vector3(0, 0.77, 0), Vector3(1.6, 0.06, 0.8), Color(0.55, 0.4, 0.25), turn)


## A street lamp: pole and a glowing head on top.
static func _lamp(s: Structure, pos: Vector3) -> void:
	var height := 4.2
	s.add_box(pos + Vector3(0, height * 0.5, 0), Vector3(0.16, height, 0.16), Color(0.3, 0.32, 0.35), Basis.IDENTITY,
			Look.cylinder(0.08, 0.06, height, Color(0.3, 0.32, 0.35)))
	var head := Vector3(0.5, 0.18, 0.5)
	s.add_box(pos + Vector3(0, height + head.y * 0.5, 0), head, Color.WHITE, Basis.IDENTITY, Look.glow(head, Color(1.0, 0.9, 0.7), 1.6))


## Trees, fences and cars share one structure; it is added to the tree after filling.
static func _props() -> Structure:
	var props := Structure.new()
	props.strength = 1.5
	return props


## A trunk and two leafy blobs (box collision, rounded visuals).
static func _tree(props: Structure, pos: Vector3) -> void:
	var turn := Basis(Vector3.UP, (pos.x + pos.z) * 0.37)
	var trunk := Vector3(0.5, 2.4, 0.5)
	var low := Vector3(3.4, 2.6, 3.4)
	var high := Vector3(2.4, 1.7, 2.4)
	props.add_box(pos + Vector3(0, trunk.y * 0.5, 0), trunk, TRUNK_COLOR, turn, Look.trunk(trunk, TRUNK_COLOR))
	props.add_box(pos + Vector3(0, trunk.y + low.y * 0.5, 0), low, LEAF_COLOR, turn, Look.canopy(low, LEAF_COLOR))
	props.add_box(pos + Vector3(0.3, trunk.y + low.y + high.y * 0.5, -0.2), high, LEAF_LIGHT_COLOR, turn,
			Look.canopy(high, LEAF_LIGHT_COLOR))
	_bare.append(_rect(pos, Vector2(0.8, 0.8)))
	_shades.append(_rect(pos, Vector2(2.2, 2.2)))


static func _car(props: Structure, pos: Vector3, along_x: bool, color: Color) -> void:
	var rect := _rect(pos, Vector2(4.0, 1.9) if along_x else Vector2(1.9, 4.0))
	_bare.append(rect)
	_shades.append(rect.grow(-0.3))
	var body := Vector3(4.0, 1.1, 1.9)
	var cabin := Vector3(2.2, 0.8, 1.7)
	var cabin_offset := Vector3(-0.3, 0, 0)
	if not along_x:
		body = Vector3(body.z, body.y, body.x)
		cabin = Vector3(cabin.z, cabin.y, cabin.x)
		cabin_offset = Vector3(0, 0, -0.3)
	var lift := 0.3
	props.add_box(pos + Vector3(0, lift + body.y * 0.5, 0), body, color)
	props.add_box(pos + cabin_offset + Vector3(0, lift + body.y + cabin.y * 0.5, 0), cabin, Look.CAR_GLASS_KEY)
	props.add_box(pos + cabin_offset + Vector3(0, lift + body.y + cabin.y + 0.06, 0), cabin + Vector3(0.1, -cabin.y + 0.12, 0.1), color)
	# Wheels poke out a little on both sides, under the body.
	var wheel := Vector3(0.75, 0.75, 0.3) if along_x else Vector3(0.3, 0.75, 0.75)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var offset := Vector3(sx * 1.3, 0, sz * 0.88) if along_x else Vector3(sx * 0.88, 0, sz * 1.3)
			props.add_box(pos + offset + Vector3(0, wheel.y * 0.5, 0), wheel, WHEEL_COLOR)


## Fence along the rectangle's edges with a gate gap in the middle of the +Z side.
static func _fence(props: Structure, rect: Rect2, gate_width: float) -> void:
	var panel := 2.0
	var height := 1.0
	var thick := 0.15
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var gate_x := rect.get_center().x
	var x := x0
	while x < x1 - EPS_FENCE:
		var mid := x + panel * 0.5
		props.add_box(Vector3(mid, height * 0.5, z0), Vector3(panel, height, thick), FENCE_COLOR)
		if absf(mid - gate_x) > gate_width * 0.5:
			props.add_box(Vector3(mid, height * 0.5, z1), Vector3(panel, height, thick), FENCE_COLOR)
		x += panel
	var z := z0 + thick * 0.5
	while z < z1 - EPS_FENCE:
		var length := minf(panel, z1 - thick * 0.5 - z)
		props.add_box(Vector3(x0, height * 0.5, z + length * 0.5), Vector3(thick, height, length), FENCE_COLOR)
		props.add_box(Vector3(x1, height * 0.5, z + length * 0.5), Vector3(thick, height, length), FENCE_COLOR)
		z += panel


static func _rect(center: Vector3, size: Vector2) -> Rect2:
	return Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y)


## One MultiMesh of grass tufts over the grass areas, kept off bare ground, and
## one of flowers in small clumps.
static func _scatter_grass(root: Node3D, seed_value: int) -> void:
	var area := 0.0
	for r in _grass_areas:
		area += r.get_area()
	if area <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var transforms: Array[Transform3D] = []
	var wanted := mini(int(area * GRASS_DENSITY), Quality.current().grass)
	var attempts := wanted * 2
	while transforms.size() < wanted and attempts > 0:
		attempts -= 1
		var p := _grass_point(rng, area)
		if is_nan(p.x):
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.25))
		transforms.append(Transform3D(basis, Vector3(p.x, 0, p.y)))
	var reach: float = Quality.current().grass_range
	var grass_material := Look.grass_material(GRASS_COLOR)
	grass_material.set_shader_parameter("fade_start", reach - 12.0)
	grass_material.set_shader_parameter("fade_end", reach)
	_add_chunked(root, Look.grass_tuft(), transforms, [], grass_material, reach)

	var flowers: Array[Transform3D] = []
	var colors: Array[Color] = []
	var clumps := int(area * FLOWER_CLUMPS) if Quality.current().flowers else 0
	for clump in clumps:
		var center := _grass_point(rng, area)
		if is_nan(center.x):
			continue
		var color: Color = FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()]
		for k in FLOWERS_PER_CLUMP:
			var p := center + Vector2(rng.randfn(0.0, 0.6), rng.randfn(0.0, 0.6))
			if _is_bare(p):
				continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
			flowers.append(Transform3D(basis, Vector3(p.x, 0, p.y)))
			colors.append(color * rng.randf_range(0.85, 1.05))
	if not flowers.is_empty():
		_add_chunked(root, Look.flower(), flowers, colors, Look.flowers_material(), reach - 6.0)


## A random point on grass (weighted by area), or NAN if it fell on bare ground.
static func _grass_point(rng: RandomNumberGenerator, area: float) -> Vector2:
	var pick := rng.randf() * area
	var rect := _grass_areas[0]
	for r in _grass_areas:
		rect = r
		pick -= r.get_area()
		if pick <= 0.0:
			break
	var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
	return Vector2(NAN, NAN) if _is_bare(p) else p


static func _is_bare(p: Vector2, margin := 0.2) -> bool:
	for b in _bare:
		if b.grow(margin).has_point(p):
			return true
	return false


## Splits instances into GRASS_CHUNK squares, each its own MultiMesh centered on
## its square and hidden beyond `reach` (plus the square's half diagonal), so
## distant and off-screen grass costs nothing.
static func _add_chunked(root: Node3D, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color],
		material: Material, reach: float) -> void:
	var chunks := {}
	for i in transforms.size():
		var cell := Vector2i(floori(transforms[i].origin.x / GRASS_CHUNK), floori(transforms[i].origin.z / GRASS_CHUNK))
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(i)
	for cell: Vector2i in chunks:
		var center := Vector3((cell.x + 0.5) * GRASS_CHUNK, 0, (cell.y + 0.5) * GRASS_CHUNK)
		var local: Array[Transform3D] = []
		var tints: Array[Color] = []
		for i: int in chunks[cell]:
			local.append(transforms[i].translated(-center))
			if not colors.is_empty():
				tints.append(colors[i])
		var chunk := _multimesh(mesh, local, tints)
		chunk.position = center
		chunk.material_override = material
		chunk.visibility_range_end = reach + GRASS_CHUNK * 0.71
		root.add_child(chunk)


static func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
