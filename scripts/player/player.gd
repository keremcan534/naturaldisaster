extends CharacterBody3D
## First-person player: movement, camera, health and damage from debris, falls and blasts.
##
## The camera is drawn where the body is between two physics steps (interpolated),
## so it glides at any frame rate instead of stepping 60 times a second against a
## 40 or 90 Hz screen. Turning applies at once. After dying, it follows a bot.

signal health_changed(value: float, max_value: float)
signal died
signal respawned
## While dead: the bot being watched ("" when none).
signal spectating(bot_name: String)
## Esc on desktop.
signal pause_requested

const Settings := preload("res://scripts/core/settings.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Avatar := preload("res://scripts/player/avatar.gd")

## Human scale: a brisk walk, a run, and a jump of about 1.3 m.
const SPEED := 4.5
const SPRINT_SPEED := 7.0
const JUMP_VELOCITY := 5.0
## Body: 1.75 m tall, shoulders about 0.6 m across.
const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.75
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

## Jump pressed this long before landing still jumps; walking off an edge still
## allows a jump this long after.
## Climbing speed on ladders (pieces tagged "ladder"); how long after touching
## one the player still counts as on it.
const CLIMB_SPEED := 3.5
const LADDER_GRACE := 0.2
const JUMP_BUFFER := 0.15
const COYOTE_TIME := 0.12
## Horizontal field of view, as in most first-person games. Sprinting widens it a
## little with a mouse; not on touch, where the stick sits near the sprint edge.
const FOV := 90.0
const SPRINT_FOV := 94.0
## Camera offset (m) at full shake.
const SHAKE_AMOUNT := 0.12
## Auto-jump: something in the way at knee height but not at chest height.
const KNEE_HEIGHT := 0.45
const CHEST_HEIGHT := 1.35
const AUTO_JUMP_REACH := 0.7
## Gentle head bob while walking (meters, steps per meter).
const BOB_HEIGHT := 0.035
const BOB_RATE := 0.9

const EYE_HEIGHT := 1.62
const PITCH_LIMIT := 1.45
const MOUSE_JUMP_LIMIT := 250.0

var health := MAX_HEALTH
var max_health := MAX_HEALTH
var alive := true
## False on touch devices: the cursor is never captured and touch_controls.gd drives look.
var use_mouse := true
## False while a menu is open: no walking, jumping or turning.
var controls_enabled := true
## Scoreboard (see disaster_manager.gd).
var display_name := "Sen"
var tint := Color(0.2, 0.5, 0.95)
var is_bot := false
var score := 0
var round_points := 0
var streak := 0
## This round: the highest the feet got (m) and the damage taken (missions).
var max_height := 0.0
var damage_taken := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body: Avatar
var _head: Node3D
var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0
## Where the body was at the previous physics step (camera interpolation).
var _prev_pos := Vector3.ZERO
## _quake: the ground shaking (sways footing and view); _rumble: the view only
## (something heavy landing nearby).
var _quake := 0.0
var _rumble := 0.0
var _shake_time := 0.0
var _spectate: Node3D
var _spectate_time := 0.0
## Shop perks (see profile.gd), read at every respawn.
var _jump_velocity := JUMP_VELOCITY
var _sprint_speed := SPRINT_SPEED
var _debris_factor := 1.0
var _breath_time := BREATH_TIME
var _swim_factor := SWIM_SPEED_FACTOR
var _fall_damage_speed := FALL_DAMAGE_MIN_SPEED
var _ladder := 0.0
var _jump_buffer := 0.0
var _coyote := 0.0
var _bob_phase := 0.0
var _bob := 0.0
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
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = BODY_HEIGHT * 0.5
	add_child(shape)

	# Our own character: only its shadow shows (first person).
	_body = Avatar.new()
	add_child(_body)

	# Slightly larger than the capsule so falling debris registers before it rests on us.
	var hitbox := Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.monitorable = false
	var hit_shape := CollisionShape3D.new()
	var hit_capsule := CapsuleShape3D.new()
	hit_capsule.radius = BODY_RADIUS + 0.12
	hit_capsule.height = BODY_HEIGHT + 0.25
	hit_shape.shape = hit_capsule
	hit_shape.position.y = (BODY_HEIGHT + 0.25) * 0.5
	hitbox.add_child(hit_shape)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	add_child(hitbox)

	# First person: yaw turns the body; the head is placed every frame (see _process).
	_head = Node3D.new()
	_head.top_level = true
	add_child(_head)
	_camera = Camera3D.new()
	# FOV is horizontal, so wide phone screens don't turn into a fisheye that makes
	# everything look small (and the player feel like a giant).
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = FOV
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

	apply_perks()
	_prev_pos = global_position
	_place_camera(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not use_mouse or not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Capturing the cursor can report one huge jump; ignore it.
		if event.relative.length() < MOUSE_JUMP_LIMIT:
			var step: Vector2 = event.relative * MOUSE_SENSITIVITY * Settings.sensitivity
			if Settings.invert_y:
				step.y = -step.y
			add_look(step)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_requested.emit()
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only lock the pointer from a click.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Turns the view; amount is in radians (x: yaw, y: pitch). Used by mouse and touch.
func add_look(amount: Vector2) -> void:
	if not controls_enabled:
		return
	_yaw = wrapf(_yaw - amount.x, -PI, PI)
	_pitch = clampf(_pitch - amount.y, -PITCH_LIMIT, PITCH_LIMIT)
	rotation.y = _yaw


## Faces a direction (radians; pitch positive looks up).
func set_view(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	rotation.y = _yaw


## Moves the player without the camera gliding there.
func teleport(pos: Vector3) -> void:
	global_position = pos
	_prev_pos = pos


func make_camera_current() -> void:
	_camera.make_current()


## Shop perks: read again at every respawn, so a purchase counts from the next round.
func apply_perks() -> void:
	max_health = 125.0 if Profile.has("medkit") else MAX_HEALTH
	_jump_velocity = JUMP_VELOCITY * (1.12 if Profile.has("boots") else 1.0)
	_fall_damage_speed = FALL_DAMAGE_MIN_SPEED + (5.0 if Profile.has("boots") else 0.0)
	_sprint_speed = SPRINT_SPEED * (1.1 if Profile.has("runner") else 1.0)
	_debris_factor = 0.6 if Profile.has("helmet") else 1.0
	_breath_time = BREATH_TIME * (2.0 if Profile.has("vest") else 1.0)
	_swim_factor = SWIM_SPEED_FACTOR * (1.3 if Profile.has("vest") else 1.0)
	tint = Profile.skin_color()
	display_name = Profile.player_name
	_body.set_colors(tint, Avatar.PANTS[0], Avatar.SKIN_TONES[0])
	_body.set_hat(Profile.has("helmet"))


func _physics_process(delta: float) -> void:
	_prev_pos = global_position
	if not alive:
		return

	var in_water := _in_water()
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer -= delta
	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	if is_on_floor():
		if _fall_speed > _fall_damage_speed:
			take_damage((_fall_speed - _fall_damage_speed) * 6.0)
		_fall_speed = 0.0
	else:
		velocity.y -= _gravity * (0.35 if in_water else 1.0) * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not in_water:
		velocity.y = _jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

	var drag := PUSH_DRAG_GROUND if is_on_floor() else PUSH_DRAG_AIR
	if in_water:
		drag = PUSH_DRAG_WATER
		_fall_speed = 0.0
		velocity.y = maxf(velocity.y, -3.0)
		if controls_enabled and Input.is_action_just_pressed("jump") and global_position.y < _water_level - 0.5:
			velocity.y = SWIM_UP_VELOCITY
		_push += _water_current * delta
	_update_breath(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled else Vector2.ZERO
	# On a ladder, pushing forward climbs and letting go slides down slowly.
	_ladder -= delta
	if _ladder > 0.0 and not in_water:
		velocity.y = CLIMB_SPEED * -input.y if input.y < -0.2 else maxf(velocity.y, -1.5)
		_fall_speed = 0.0
	# Analog: a half-pushed stick walks at half speed.
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	var speed := _sprint_speed if controls_enabled and Input.is_action_pressed("sprint") else SPEED
	if in_water:
		speed *= _swim_factor
	if not use_mouse and Settings.auto_jump and not in_water:
		_auto_jump(dir)
	# A shaking ground makes footing unreliable (a smooth sway, not jitter).
	var sway_t := _shake_time * 3.0
	var wobble := Vector3(sin(sway_t), 0, cos(sway_t * 1.3)) * _quake * 1.2
	_walk = _walk.move_toward(dir * speed + wobble, speed * 10.0 * delta)
	_push = _push.lerp(Vector3.ZERO, minf(drag * delta, 1.0))
	velocity.x = _walk.x + _push.x
	velocity.z = _walk.z + _push.z
	move_and_slide()
	_touch_pieces()
	max_height = maxf(max_height, global_position.y)
	# Grass and flowers bend away from the player's legs.
	RenderingServer.global_shader_parameter_set("player_pos", global_position)

	if global_position.y < KILL_HEIGHT:
		take_damage(MAX_HEALTH)


## Reacts to tagged structure pieces touched this step: trampolines ("bounce":
## launch speed) and ladders.
func _touch_pieces() -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var piece := hit.get_collider() as Node
		if piece == null:
			continue
		if piece.has_meta("bounce") and hit.get_normal().y > 0.6:
			velocity.y = piece.get_meta("bounce")
			_fall_speed = 0.0
			_coyote = 0.0
			_rumble = maxf(_rumble, 0.15)
		elif piece.has_meta("ladder") and absf(hit.get_normal().y) < 0.4:
			_ladder = LADDER_GRACE


## Walking into something knee-high (a chair, rubble, a step) hops over it, as in
## mobile block games; walls and ladders are taller than chest height, so they don't.
func _auto_jump(dir: Vector3) -> void:
	if not is_on_floor() or not is_on_wall() or dir.length() < 0.3 or _ladder > 0.0:
		return
	var ahead := Vector3(dir.x, 0, dir.z).normalized()
	if ahead.dot(-get_wall_normal()) < 0.5:
		return
	var space := get_world_3d().direct_space_state
	var knee := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * KNEE_HEIGHT,
			global_position + Vector3.UP * KNEE_HEIGHT + ahead * (BODY_RADIUS + AUTO_JUMP_REACH), 1 | 2, [get_rid()])
	if space.intersect_ray(knee).is_empty():
		return
	var chest := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * CHEST_HEIGHT,
			global_position + Vector3.UP * CHEST_HEIGHT + ahead * (BODY_RADIUS + AUTO_JUMP_REACH), 1 | 2, [get_rid()])
	if space.intersect_ray(chest).is_empty():
		_jump_buffer = JUMP_BUFFER


func _process(delta: float) -> void:
	_shake_time += delta
	_quake = move_toward(_quake, 0.0, delta * 2.0)
	_rumble = move_toward(_rumble, 0.0, delta * 3.0)
	if not alive:
		_follow_bot(delta)
		return
	_place_camera(delta)
	var surface := _water_level if Engine.get_physics_frames() - _water_frame <= 1 else SEA_LEVEL
	_underwater_tint.visible = _camera.global_position.y < surface
	var ground_speed := Vector2(_walk.x, _walk.z).length() if is_on_floor() else 0.0
	_body.animate(delta, ground_speed, 1.0 if _ladder > 0.0 else 0.0)


## The eye where the body is between the last two physics steps, plus a smooth
## shake (not a new random offset every frame, which reads as jitter) and, with
## a mouse, a gentle head bob.
func _place_camera(delta: float) -> void:
	var t := _shake_time * 22.0
	var shake := maxf(_quake, _rumble) * SHAKE_AMOUNT
	var body := _prev_pos.lerp(global_position, Engine.get_physics_interpolation_fraction())
	_head.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0)), body + Vector3.UP * EYE_HEIGHT)
	_camera.h_offset = (sin(t) + sin(t * 2.3 + 1.7)) * 0.5 * shake
	# Head bob follows distance walked, so it matches the stride at any speed.
	# Not on touch screens: there it only makes aiming harder.
	var ground_speed := Vector2(_walk.x, _walk.z).length() if is_on_floor() and alive else 0.0
	_bob_phase += ground_speed * BOB_RATE * delta * TAU * 0.5
	var bob := BOB_HEIGHT * clampf(ground_speed / SPEED, 0.0, 1.3) if use_mouse else 0.0
	_bob = lerpf(_bob, bob, minf(delta * 8.0, 1.0))
	_camera.v_offset = (sin(t * 1.3 + 0.5) + sin(t * 2.9 + 2.1)) * 0.5 * shake + sin(_bob_phase * 2.0) * _bob
	var sprinting := use_mouse and Input.is_action_pressed("sprint") and ground_speed > SPEED
	_camera.fov = lerpf(_camera.fov, SPRINT_FOV if sprinting else FOV, minf(delta * 6.0, 1.0))


## Dead: after a moment, watch a bot that is still alive from behind and above.
func _follow_bot(delta: float) -> void:
	_spectate_time += delta
	_underwater_tint.visible = false
	if _spectate_time < 1.5:
		return
	if _spectate == null or not is_instance_valid(_spectate) or not _spectate.alive:
		_spectate = null
		for bot: Node3D in get_tree().get_nodes_in_group("bots"):
			if bot.alive:
				_spectate = bot
				break
		spectating.emit(_spectate.display_name if _spectate else "")
		if _spectate == null:
			return
	var target := _spectate.global_position + Vector3.UP * 1.4
	var back := _spectate.global_transform.basis.z
	back = Vector3(back.x, 0, back.z).normalized()
	var eye := target + back * 4.0 + Vector3.UP * 1.8
	var follow := minf(delta * 4.0, 1.0)
	_head.global_position = _head.global_position.lerp(eye, follow)
	var look := _head.global_transform.looking_at(target, Vector3.UP)
	_head.global_basis = _head.global_basis.slerp(look.basis, follow)
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0


## Something heavy crashed down at pos (energy: mass times speed lost): the
## closer, the more the view trembles (only the view; the ground isn't moving).
func rumble(pos: Vector3, energy: float) -> void:
	var near := 1.0 - clampf(global_position.distance_to(pos) / 20.0, 0.0, 1.0)
	_rumble = maxf(_rumble, clampf(energy / 400.0, 0.0, 0.35) * near * near)


## Called every frame by shaking disasters; amount is 0..1.
func add_shake(amount: float) -> void:
	_quake = maxf(_quake, amount)


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
		if _underwater_time > _breath_time:
			take_damage(DROWN_DAMAGE_PER_SEC * delta)
	else:
		_underwater_time = 0.0


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	damage_taken += minf(amount, health)
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		alive = false
		_body.visible = false
		velocity = Vector3.ZERO
		_spectate = null
		_spectate_time = 0.0
		died.emit()


func respawn(pos: Vector3) -> void:
	teleport(pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	# Spawn points sit on the +Z side of each map, so face the middle.
	set_view(0.0, 0.0)
	apply_perks()
	velocity = Vector3.ZERO
	_walk = Vector3.ZERO
	_push = Vector3.ZERO
	_fall_speed = 0.0
	_underwater_time = 0.0
	health = max_health
	max_height = 0.0
	damage_taken = 0.0
	alive = true
	_body.visible = true
	health_changed.emit(health, max_health)
	respawned.emit()


func _on_hitbox_body_entered(body: Node3D) -> void:
	var rb := body as RigidBody3D
	if rb == null:
		return
	var speed := rb.linear_velocity.length()
	if speed > DEBRIS_MIN_SPEED:
		take_damage(minf((speed - DEBRIS_MIN_SPEED) * rb.mass * 4.0 * _debris_factor, MAX_HEALTH))
