extends CharacterBody3D
## First-person player: movement, camera, health and damage from debris, falls and blasts.

signal health_changed(value: float, max_value: float)
signal died
signal respawned

const SPEED := 6.0
const SPRINT_SPEED := 9.5
const JUMP_VELOCITY := 6.5
const MOUSE_SENSITIVITY := 0.0025
const MAX_HEALTH := 100.0
## Debris slower than this does not hurt.
const DEBRIS_MIN_SPEED := 4.0
const FALL_DAMAGE_MIN_SPEED := 14.0
const KILL_HEIGHT := -30.0
## Linear drag on world pushes, per second.
const PUSH_DRAG_GROUND := 6.0
const PUSH_DRAG_AIR := 1.0
const PUSH_DRAG_WATER := 2.0
const SWIM_SPEED_FACTOR := 0.55
const SWIM_UP_VELOCITY := 4.0
const HEAD_HEIGHT := 1.6
const BREATH_TIME := 4.0
const DROWN_DAMAGE_PER_SEC := 20.0

## The sea around the island (see weather.gd), for the underwater tint.
const SEA_LEVEL := -2.5

const EYE_HEIGHT := 1.6
const PITCH_LIMIT := 1.45
const MOUSE_JUMP_LIMIT := 250.0

var health := MAX_HEALTH
var alive := true
## False on touch devices: the cursor is never captured and touch_controls.gd drives look.
var use_mouse := true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body: MeshInstance3D
var _head: Node3D
var _camera: Camera3D
var _shake := 0.0
var _shake_time := 0.0
var _fall_speed := 0.0
## Horizontal velocity from input / from the world (blasts, wind, water).
var _walk := Vector3.ZERO
var _push := Vector3.ZERO
var _water_level := 0.0
var _water_current := Vector3.ZERO
var _water_frame := -10
var _underwater_time := 0.0
var _underwater_tint: ColorRect


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1 | 2
	# Building ramps are just under 42 degrees.
	floor_max_angle = deg_to_rad(48.0)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 1.0)
	mesh.material = mat
	_body.mesh = mesh
	_body.position.y = 0.9
	add_child(_body)

	# Slightly larger than the capsule so falling debris registers before it rests on us.
	var hitbox := Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.monitorable = false
	var hit_shape := CollisionShape3D.new()
	var hit_capsule := CapsuleShape3D.new()
	hit_capsule.radius = 0.55
	hit_capsule.height = 2.1
	hit_shape.shape = hit_capsule
	hit_shape.position.y = 0.95
	hitbox.add_child(hit_shape)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	add_child(hitbox)

	# First person: yaw turns the whole body, pitch only the head.
	_head = Node3D.new()
	_head.position.y = EYE_HEIGHT
	add_child(_head)
	_camera = Camera3D.new()
	_camera.fov = 80.0
	_camera.near = 0.05
	_camera.far = 800.0
	_head.add_child(_camera)
	_camera.make_current()
	# Our own body would fill the view; keep only its shadow.
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	# Murky blue over the view while the camera is below a water surface.
	var tint_layer := CanvasLayer.new()
	tint_layer.layer = -1
	_underwater_tint = ColorRect.new()
	_underwater_tint.color = Color(0.05, 0.25, 0.32, 0.65)
	_underwater_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_underwater_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater_tint.visible = false
	tint_layer.add_child(_underwater_tint)
	add_child(tint_layer)

	if use_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not use_mouse:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Capturing the cursor can report one huge jump; ignore it.
		if event.relative.length() < MOUSE_JUMP_LIMIT:
			add_look(event.relative * MOUSE_SENSITIVITY)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Turns the view; amount is in radians (x: yaw, y: pitch). Used by mouse and touch.
func add_look(amount: Vector2) -> void:
	rotation.y -= amount.x
	_head.rotation.x = clampf(_head.rotation.x - amount.y, -PITCH_LIMIT, PITCH_LIMIT)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	var in_water := _in_water()
	if is_on_floor():
		if _fall_speed > FALL_DAMAGE_MIN_SPEED:
			take_damage((_fall_speed - FALL_DAMAGE_MIN_SPEED) * 6.0)
		_fall_speed = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= _gravity * (0.35 if in_water else 1.0) * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	var drag := PUSH_DRAG_GROUND if is_on_floor() else PUSH_DRAG_AIR
	if in_water:
		drag = PUSH_DRAG_WATER
		_fall_speed = 0.0
		velocity.y = maxf(velocity.y, -3.0)
		if Input.is_action_just_pressed("jump") and global_position.y < _water_level - 0.5:
			velocity.y = SWIM_UP_VELOCITY
		_push += _water_current * delta
	_update_breath(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	if in_water:
		speed *= SWIM_SPEED_FACTOR
	# Strong shaking makes footing unreliable.
	var wobble := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake * 2.0
	_walk = _walk.move_toward(dir * speed + wobble, speed * 10.0 * delta)
	_push = _push.lerp(Vector3.ZERO, minf(drag * delta, 1.0))
	velocity.x = _walk.x + _push.x
	velocity.z = _walk.z + _push.z
	move_and_slide()

	if global_position.y < KILL_HEIGHT:
		take_damage(MAX_HEALTH)


func _process(delta: float) -> void:
	# Smooth wobble rather than a new random offset every frame, which reads as jitter.
	_shake_time += delta
	var t := _shake_time * 22.0
	_camera.h_offset = (sin(t) + sin(t * 2.3 + 1.7)) * 0.5 * _shake * 0.25
	_camera.v_offset = (sin(t * 1.3 + 0.5) + sin(t * 2.9 + 2.1)) * 0.5 * _shake * 0.25
	_shake = move_toward(_shake, 0.0, delta * 2.0)
	var surface := _water_level if Engine.get_physics_frames() - _water_frame <= 1 else SEA_LEVEL
	_underwater_tint.visible = _camera.global_position.y < surface


## Called every frame by shaking disasters; amount is 0..1.
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func explode_at(pos: Vector3, radius: float, damage: float) -> void:
	if not alive:
		return
	var offset := global_position - pos
	var dist := offset.length()
	if dist >= radius:
		return
	var falloff := 1.0 - dist / radius
	take_damage(damage * falloff)
	push((offset.normalized() + Vector3.UP) * 8.0 * falloff)


## Adds a velocity change from the world (blasts, wind, water).
func push(delta_v: Vector3) -> void:
	_push += Vector3(delta_v.x, 0, delta_v.z)
	velocity.y += delta_v.y


## Called every physics frame by flooding disasters while the player is over water.
func set_water(level: float, current: Vector3) -> void:
	_water_level = level
	_water_current = current
	_water_frame = Engine.get_physics_frames()


func _in_water() -> bool:
	return Engine.get_physics_frames() - _water_frame <= 1 and global_position.y < _water_level


func _update_breath(delta: float) -> void:
	if _in_water() and global_position.y + HEAD_HEIGHT < _water_level:
		_underwater_time += delta
		if _underwater_time > BREATH_TIME:
			take_damage(DROWN_DAMAGE_PER_SEC * delta)
	else:
		_underwater_time = 0.0


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		alive = false
		_body.visible = false
		velocity = Vector3.ZERO
		died.emit()


func respawn(pos: Vector3) -> void:
	global_position = pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	# Spawn points sit on the +Z side of each map, so face the middle.
	rotation.y = 0.0
	_head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_walk = Vector3.ZERO
	_push = Vector3.ZERO
	_fall_speed = 0.0
	_underwater_time = 0.0
	health = MAX_HEALTH
	alive = true
	_body.visible = true
	health_changed.emit(health, MAX_HEALTH)
	respawned.emit()


func _on_hitbox_body_entered(body: Node3D) -> void:
	var rb := body as RigidBody3D
	if rb == null:
		return
	var speed := rb.linear_velocity.length()
	if speed > DEBRIS_MIN_SPEED:
		take_damage(minf((speed - DEBRIS_MIN_SPEED) * rb.mass * 4.0, MAX_HEALTH))
