extends Node3D
## Sliding glass doors in the buildings' front doorways: they slide open when
## anyone (player or bot) comes near and close behind them, and shatter when the
## wall holding them breaks. Every panel is drawn by one MultiMesh (one draw
## call for all doors); each has a kinematic body to bump into. Built for every
## structure's door_spots after a map loads (add_map), freed with clear().

const Look := preload("res://scripts/world/look.gd")

const MAX_DOORS := 24
const NEAR := 3.4
const SPEED := 3.0
const TICK := 0.15

var _doors: Array[Dictionary] = []
var _multimesh: MultiMesh
var _tick := 0.0


func _ready() -> void:
	add_to_group("doors")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_multimesh.mesh = box
	_multimesh.instance_count = MAX_DOORS
	_multimesh.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.material_override = Look.surface(Look.GLASS_KEY)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-300, -20, -300), Vector3(600, 80, 600))
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(instance)


func clear() -> void:
	for door: Dictionary in _doors:
		door.body.queue_free()
	_doors.clear()
	_multimesh.visible_instance_count = 0


## A new map: a door in every structure's door spots.
func add_map() -> void:
	clear()
	for structure: Node3D in get_tree().get_nodes_in_group("structures"):
		for spot: Dictionary in structure.door_spots:
			if _doors.size() >= MAX_DOORS:
				return
			var basis := structure.global_basis
			var size: Vector3 = spot.size
			var body := AnimatableBody3D.new()
			body.sync_to_physics = true
			body.collision_layer = 2
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			body.add_child(shape)
			# Placed before entering the tree: a synced kinematic body keeps the
			# physics server's transform otherwise. The doors node sits at the origin.
			var closed: Vector3 = structure.global_transform * (spot.center as Vector3)
			body.transform = Transform3D(basis, closed)
			add_child(body)
			var index := _doors.size()
			_multimesh.set_instance_custom_data(index, Color(0, 0, 0, 0))
			_multimesh.set_instance_transform(index, Transform3D(basis * Basis.from_scale(size), closed))
			_doors.append({"body": body, "closed": closed, "slide": basis * (spot.slide as Vector3) * size.x * 0.92,
					"size": size, "basis": basis, "open": 0.0, "want": 0.0, "neighbors": spot.neighbors, "broken": false})
	_multimesh.visible_instance_count = _doors.size()


func _physics_process(delta: float) -> void:
	if _doors.is_empty():
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_check()
	for door: Dictionary in _doors:
		if door.broken or door.open == door.want:
			continue
		door.open = move_toward(door.open, door.want, delta * SPEED)
		door.body.global_position = door.closed + door.slide * smoothstep(0.0, 1.0, door.open)


func _process(_delta: float) -> void:
	for k in _doors.size():
		var door: Dictionary = _doors[k]
		if not door.broken and (door.open > 0.0 or door.want > 0.0):
			_draw(k)


## Who is near each door, and whether its wall still stands.
func _check() -> void:
	var people := get_tree().get_nodes_in_group("player")
	for k in _doors.size():
		var door: Dictionary = _doors[k]
		if door.broken:
			continue
		for piece: Variant in door.neighbors:
			if not is_instance_valid(piece) or not piece.freeze or piece.collision_layer == 0:
				_break(k)
				break
		if door.broken:
			continue
		var at: Vector3 = door.closed
		var near := false
		for p: Node3D in people:
			if p.alive and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < NEAR \
					and absf(p.global_position.y - (at.y - door.size.y * 0.5)) < 2.0:
				near = true
				break
		door.want = 1.0 if near else 0.0


func _break(k: int) -> void:
	var door: Dictionary = _doors[k]
	door.broken = true
	var body: AnimatableBody3D = door.body
	body.collision_layer = 0
	get_tree().call_group("debris", "shatter", body.global_transform, door.size, Look.GLASS_KEY, Vector3.ZERO,
			body.global_position - body.global_basis.z, 3.0)
	_multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _draw(k: int) -> void:
	var door: Dictionary = _doors[k]
	var body: AnimatableBody3D = door.body
	var xform := body.get_global_transform_interpolated()
	_multimesh.set_instance_transform(k, Transform3D(xform.basis * Basis.from_scale(door.size), xform.origin))
