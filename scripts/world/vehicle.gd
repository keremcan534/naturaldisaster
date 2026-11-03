extends CharacterBody3D
const Prof := preload("res://scripts/core/prof.gd")
## An all-terrain quad parked near the spawn. The player gets on next to it
## (E, or the touch "Bin" button) and drives with the stick: forward/back for
## throttle and reverse, sideways to steer (turning needs speed). Hitting
## something hard at speed hurts; deep water drowns the engine. The rider sits
## on it (player.gd `vehicle`), looking around freely. Water disasters reach it
## through set_water() (group "boats"). Idle and settled, it costs nothing.

const MAX_SPEED := 15.0
const REVERSE := 5.0
const ACCEL := 9.0
const BRAKE := 16.0
const DRAG := 2.5
const TURN := 1.9
const ENTER_RADIUS := 2.4
## Hitting a wall faster than this hurts the rider.
const CRASH_SPEED := 9.0
const SEAT := Vector3(0, 0.75, 0.15)

var rider: Node3D
var speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _water := -INF
var _water_frame := -10
var _settled := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("boats")
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(42.0)
	floor_snap_length = 0.5
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 0.8, 2.1)
	shape.shape = box
	shape.position = Vector3(0, 0.55, 0)
	add_child(shape)
	var body := Color(0.2, 0.45, 0.22)
	var dark := Color(0.08, 0.08, 0.09)
	var metal := Color(0.55, 0.56, 0.58)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = preload("res://scripts/world/rescue_heli.gd")._boxes([
		[Vector3(0, 0.6, 0), Vector3(1.0, 0.35, 1.7), body],
		[Vector3(0, 0.85, 0.25), Vector3(0.55, 0.2, 0.8), dark],
		[Vector3(0, 0.82, -0.75), Vector3(1.15, 0.12, 0.45), body],
		[Vector3(0, 0.82, 0.85), Vector3(1.15, 0.12, 0.45), body],
		[Vector3(0, 1.05, -0.55), Vector3(0.08, 0.45, 0.08), metal],
		[Vector3(0, 1.28, -0.55), Vector3(0.8, 0.06, 0.06), dark],
		[Vector3(0.62, 0.32, -0.65), Vector3(0.28, 0.6, 0.6), dark],
		[Vector3(-0.62, 0.32, -0.65), Vector3(0.28, 0.6, 0.6), dark],
		[Vector3(0.62, 0.32, 0.65), Vector3(0.28, 0.6, 0.6), dark],
		[Vector3(-0.62, 0.32, 0.65), Vector3(0.28, 0.6, 0.6), dark],
		[Vector3(0, 0.7, -0.88), Vector3(0.5, 0.12, 0.05), Color(1.0, 0.95, 0.7)],
	])
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.7
	_mesh.material_override = paint
	add_child(_mesh)


## Called every physics frame by water disasters while it is in the water.
func set_water(level: float, _current: Vector3) -> void:
	_water = level
	_water_frame = Engine.get_physics_frames()


## Deep water: the engine dies.
func drowned() -> bool:
	return Engine.get_physics_frames() - _water_frame <= 1 and _water > global_position.y + 0.9


## Where the rider sits (world space).
func seat() -> Vector3:
	return global_transform * SEAT


func _physics_process(delta: float) -> void:
	var _p := Prof.begin()
	if rider == null and is_on_floor() and absf(speed) < 0.05:
		# Parked: settle once, then stop costing anything.
		_settled += delta
		if _settled > 1.0:
			velocity = Vector3.ZERO
			Prof.end("vehicle", _p)
			return
	else:
		_settled = 0.0
	var throttle := 0.0
	var steer := 0.0
	if rider and rider.controls_enabled and not drowned():
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		throttle = -input.y
		steer = -input.x
	if throttle > 0.05:
		speed = move_toward(speed, MAX_SPEED * throttle, (ACCEL if speed >= 0.0 else BRAKE) * delta)
	elif throttle < -0.05:
		speed = move_toward(speed, -REVERSE * -throttle, (BRAKE if speed > 0.0 else ACCEL) * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	# Steering turns more the faster it goes (and the other way backing up).
	if is_on_floor():
		rotation.y += steer * TURN * clampf(speed / 6.0, -1.0, 1.0) * delta
	var ahead := -global_basis.z
	var before := velocity
	velocity.x = ahead.x * speed
	velocity.z = ahead.z * speed
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	# Ran into something: the speed goes, and a hard hit hurts.
	if is_on_wall() and absf(speed) > 1.0:
		var hit := absf(Vector2(before.x, before.z).dot(Vector2(get_wall_normal().x, get_wall_normal().z)))
		if hit > CRASH_SPEED and rider:
			rider.take_damage((hit - CRASH_SPEED) * 6.0)
			rider.rumble(global_position, 900.0)
			get_tree().call_group("sound", "play", "metal", global_position, 2.0, 0.8)
		speed *= 0.3
	if rider:
		get_tree().call_group("sound", "loop", "rumble", 0.15 + absf(speed) / MAX_SPEED * 0.35, 1.6 + absf(speed) / MAX_SPEED)
		# The rider moves with it (here, after this step's move, so they never lag behind).
		rider.ride_to(seat())
	Prof.end("vehicle", _p)
