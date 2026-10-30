extends RefCounted
## Map layouts. Each round builds one under a fresh root node; the previous root
## is freed, so a map always starts intact.

const Structure := preload("res://scripts/world/structure.gd")

const COUNT := 4
const LEAF_COLOR := Color(0.25, 0.55, 0.25)
const TRUNK_COLOR := Color(0.45, 0.3, 0.18)
const FENCE_COLOR := Color(0.92, 0.9, 0.85)
const ROAD_COLOR := Color(0.25, 0.25, 0.27)
const PATH_COLOR := Color(0.7, 0.66, 0.6)
const EPS_FENCE := 0.01
const CAR_COLORS := [Color(0.8, 0.15, 0.15), Color(0.15, 0.3, 0.75), Color(0.9, 0.9, 0.9), Color(0.2, 0.2, 0.22)]


## Builds map `index` under root and returns {name, size, spawn}.
static func build(index: int, root: Node3D) -> Dictionary:
	match index:
		0:
			return _skyscraper(root)
		1:
			return _garden_house(root)
		2:
			return _apartment(root)
		_:
			return _neighbourhood(root)


static func _skyscraper(root: Node3D) -> Dictionary:
	var size := 56.0
	_ground(root, size, Color(0.55, 0.55, 0.52))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_decal(root, Vector3(corner.x * 19, 0, corner.y * 19), Vector2(14, 14), Color(0.36, 0.55, 0.3))
	_building(root, Vector3(0, 0, -2), Vector2i(4, 4), 12, Color(0.7, 0.76, 0.82), 1.3)
	var props := _props()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_tree(props, Vector3(corner.x * 19, 0, corner.y * 19))
	_car(props, Vector3(-14, 0, 14), false, CAR_COLORS[0])
	_car(props, Vector3(14, 0, 10), false, CAR_COLORS[1])
	root.add_child(props)
	return {"name": "Gökdelen", "size": size, "spawn": Vector3(0, 0.5, 20)}


static func _garden_house(root: Node3D) -> Dictionary:
	var size := 44.0
	_ground(root, size, Color(0.36, 0.55, 0.3))
	_decal(root, Vector3(0, 0, 9), Vector2(2, 14), PATH_COLOR)
	_decal(root, Vector3(-10, 0, 6), Vector2(6, 4), Color(0.2, 0.55, 0.85))
	_building(root, Vector3(0, 0, -6), Vector2i(4, 3), 2, Color(0.9, 0.82, 0.68), 1.0)
	_building(root, Vector3(12, 0, -1), Vector2i(2, 2), 1, Color(0.6, 0.42, 0.3), 0.8)
	var props := _props()
	_fence(props, Rect2(-18, -18, 36, 34), 2.0)
	for pos: Vector3 in [Vector3(-12, 0, -13), Vector3(12, 0, -13), Vector3(-14, 0, 12), Vector3(13, 0, 10)]:
		_tree(props, pos)
	root.add_child(props)
	return {"name": "Bahçeli Ev", "size": size, "spawn": Vector3(0, 0.5, 12)}


static func _apartment(root: Node3D) -> Dictionary:
	var size := 50.0
	_ground(root, size, Color(0.36, 0.55, 0.3))
	_decal(root, Vector3(0, 0, 14), Vector2(size, 8), ROAD_COLOR)
	_decal(root, Vector3(0, 0, 5.5), Vector2(2, 7), PATH_COLOR)
	_building(root, Vector3(0, 0, -4), Vector2i(5, 4), 6, Color(0.85, 0.62, 0.5), 1.1)
	var props := _props()
	for i in 4:
		_car(props, Vector3(-15 + i * 10, 0, 14), i % 2 == 0, CAR_COLORS[i])
	_tree(props, Vector3(-16, 0, -12))
	_tree(props, Vector3(16, 0, -12))
	root.add_child(props)
	return {"name": "Apartman", "size": size, "spawn": Vector3(0, 0.5, 20)}


static func _neighbourhood(root: Node3D) -> Dictionary:
	var size := 76.0
	_ground(root, size, Color(0.36, 0.55, 0.3))
	_decal(root, Vector3.ZERO, Vector2(8, size), ROAD_COLOR)
	_decal(root, Vector3.ZERO, Vector2(size, 8), ROAD_COLOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var colors := [Color(0.85, 0.78, 0.66), Color(0.78, 0.55, 0.45), Color(0.7, 0.74, 0.78), Color(0.62, 0.68, 0.58)]
	var lots := [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18, 0, 18)]
	for k in lots.size():
		var footprint := Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 5))
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
	# A visible slab, so the map reads as an island with an edge you can fall off.
	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = box.size
	slab.material = _flat_material(color)
	mesh.mesh = slab
	mesh.position.y = -1.0
	ground.add_child(mesh)
	root.add_child(ground)


## Purely visual flat patch (roads, paths, pools).
static func _decal(root: Node3D, center: Vector3, size: Vector2, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = _flat_material(color)
	mesh.mesh = plane
	mesh.position = center + Vector3(0, 0.01, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)


static func _building(root: Node3D, pos: Vector3, footprint: Vector2i, floors: int, color: Color, strength: float) -> void:
	var building := Structure.new()
	building.position = pos
	building.strength = strength
	building.add_building(Vector3.ZERO, footprint, floors, color)
	root.add_child(building)


## Trees, fences and cars share one structure; it is added to the tree after filling.
static func _props() -> Structure:
	var props := Structure.new()
	props.strength = 1.5
	return props


static func _tree(props: Structure, pos: Vector3) -> void:
	props.add_box(pos + Vector3(0, 1.2, 0), Vector3(0.5, 2.4, 0.5), TRUNK_COLOR)
	props.add_box(pos + Vector3(0, 3.5, 0), Vector3(2.4, 2.2, 2.4), LEAF_COLOR)


static func _car(props: Structure, pos: Vector3, along_x: bool, color: Color) -> void:
	var body := Vector3(4.0, 1.1, 1.9)
	var cabin := Vector3(2.2, 0.8, 1.7)
	var cabin_offset := Vector3(-0.3, 0, 0)
	if not along_x:
		body = Vector3(body.z, body.y, body.x)
		cabin = Vector3(cabin.z, cabin.y, cabin.x)
		cabin_offset = Vector3(0, 0, -0.3)
	props.add_box(pos + Vector3(0, body.y * 0.5, 0), body, color)
	props.add_box(pos + cabin_offset + Vector3(0, body.y + cabin.y * 0.5, 0), cabin, color.lightened(0.3))


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


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
