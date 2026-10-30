extends RefCounted
## Map layouts. Each round builds one under a fresh root node; the previous root
## is freed, so a map always starts intact.

const Structure := preload("res://scripts/world/structure.gd")
const Look := preload("res://scripts/world/look.gd")

const COUNT := 4
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
## Grass tufts per square meter, and a cap so big maps stay cheap.
const GRASS_DENSITY := 3.0
const MAX_TUFTS := 12000
const CAR_COLORS := [Color(0.8, 0.15, 0.15), Color(0.15, 0.3, 0.75), Color(0.9, 0.9, 0.9), Color(0.2, 0.2, 0.22)]


## Filled while a map is built: where grass grows, where it can't (roads,
## buildings, ...), and what casts a contact shadow on the ground.
static var _grass_areas: Array[Rect2] = []
static var _bare: Array[Rect2] = []
static var _shades: Array[Rect2] = []


## Builds map `index` under root and returns {name, size, spawn}.
static func build(index: int, root: Node3D) -> Dictionary:
	_grass_areas.clear()
	_bare.clear()
	_shades.clear()
	var info: Dictionary
	match index:
		0:
			info = _skyscraper(root)
		1:
			info = _garden_house(root)
		2:
			info = _apartment(root)
		_:
			info = _neighbourhood(root)
	_scatter_grass(root, index)
	Look.set_shades(_shades)
	return info


static func _skyscraper(root: Node3D) -> Dictionary:
	var size := 56.0
	_ground(root, size, Color(0.55, 0.55, 0.52))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_decal(root, Vector3(corner.x * 19, 0, corner.y * 19), Vector2(14, 14), GRASS_COLOR)
	_building(root, Vector3(0, 0, -2), Vector2i(5, 5), 10, Color(0.7, 0.76, 0.82), 1.3)
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
	_building(root, Vector3(0, 0, -6), Vector2i(6, 5), 2, Color(0.9, 0.82, 0.68), 1.0)
	_building(root, Vector3(12, 0, -1), Vector2i(3, 3), 1, Color(0.6, 0.42, 0.3), 0.8)
	var props := _props()
	_fence(props, Rect2(-18, -18, 36, 34), 2.0)
	for pos: Vector3 in [Vector3(-12, 0, -13), Vector3(12, 0, -13), Vector3(-14, 0, 12), Vector3(13, 0, 10)]:
		_tree(props, pos)
	root.add_child(props)
	return {"name": "Bahçeli Ev", "size": size, "spawn": Vector3(0, 0.5, 12)}


static func _apartment(root: Node3D) -> Dictionary:
	var size := 50.0
	_ground(root, size, GRASS_COLOR)
	_road(root, Vector3(0, 0, 14), size, true)
	_decal(root, Vector3(0, 0, 5.5), Vector2(2, 7), PATH_COLOR)
	_building(root, Vector3(0, 0, -3), Vector2i(7, 5), 6, Color(0.85, 0.62, 0.5), 1.1)
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
		_building(root, lots[k], footprint, rng.randi_range(2, 5), colors[k], rng.randf_range(0.7, 1.4))
	var props := _props()
	for pos: Vector3 in [Vector3(-30, 0, -6), Vector3(30, 0, 6), Vector3(-6, 0, 30), Vector3(6, 0, -30)]:
		_tree(props, pos)
	_car(props, Vector3(-2, 0, 22), false, CAR_COLORS[0])
	_car(props, Vector3(24, 0, 2), true, CAR_COLORS[2])
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


static func _building(root: Node3D, pos: Vector3, footprint: Vector2i, floors: int, color: Color, strength: float) -> void:
	var building := Structure.new()
	building.position = pos
	building.strength = strength
	building.add_building(Vector3.ZERO, footprint, floors, color)
	root.add_child(building)
	var rect := _rect(pos, Vector2(footprint) * Structure.CELL)
	_bare.append(rect)
	_shades.append(rect)


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


## One MultiMesh of grass tufts over the grass areas, kept off bare ground.
static func _scatter_grass(root: Node3D, seed_value: int) -> void:
	var area := 0.0
	for r in _grass_areas:
		area += r.get_area()
	if area <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var transforms: Array[Transform3D] = []
	var wanted := mini(int(area * GRASS_DENSITY), MAX_TUFTS)
	var attempts := wanted * 2
	while transforms.size() < wanted and attempts > 0:
		attempts -= 1
		# Pick an area weighted by size, then a point in it.
		var pick := rng.randf() * area
		var rect := _grass_areas[0]
		for r in _grass_areas:
			rect = r
			pick -= r.get_area()
			if pick <= 0.0:
				break
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		var blocked := false
		for b in _bare:
			if b.grow(0.2).has_point(p):
				blocked = true
				break
		if blocked:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.25))
		transforms.append(Transform3D(basis, Vector3(p.x, 0, p.y)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = Look.grass_tuft()
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var grass := MultiMeshInstance3D.new()
	grass.multimesh = multimesh
	grass.material_override = Look.grass_material(GRASS_COLOR)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass)
