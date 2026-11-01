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
## Items left this round changed (HUD and touch buttons show them).
signal items_changed(items: Dictionary)
## Patched up a hurt teammate.
signal helped(bot_name: String)
## P / the pause menu: a screenshot without the HUD (main.gd).
signal photo_requested
## Lifted by the rescue helicopter.
signal rescued_now

const Settings := preload("res://scripts/core/settings.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Gyro := preload("res://scripts/core/gyro.gd")
const Quality := preload("res://scripts/core/quality.gd")
const UNDERWATER_SHADER := preload("res://shaders/underwater.gdshader")
const DROPS_SHADER := preload("res://shaders/screen_drops.gdshader")
const DROPS_LITE_SHADER := preload("res://shaders/screen_drops_lite.gdshader")
## Third person: the camera this far behind the head, a little to the right.
const THIRD_DISTANCE := 3.4
const THIRD_SIDE := 0.45
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
## Crouching: shorter body (fits under tables), lower eye, slow.
const CROUCH_HEIGHT := 1.1
const CROUCH_EYE := 0.95
const CROUCH_SPEED := 2.3
## Mantling: a ledge this high (above the feet) can be climbed onto from a jump.
const LEDGE_MIN := 0.6
const LEDGE_MAX := 2.2
const MANTLE_TIME := 0.3
## Items (bought in the shop, refilled each round).
const CHUTE_TIME := 7.0
const CHUTE_FALL := 2.2
const HOOK_RANGE := 32.0
const HOOK_SPEED := 18.0
const BANDAGE_HEAL := 40.0
## Standing by a badly hurt teammate this long patches them up.
const HELP_TIME := 1.5
const HELP_HEAL := 40.0
const HELP_POINTS := 25
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
## Extra round points (rescues, helping teammates).
var bonus_points := 0
## Uses left this round: parachute, bandage, hook.
var items := {}
## Reached the rescue helicopter: nothing hurts any more this round.
var rescued := false
## Map votes are open: the number keys vote instead of using items (hud.gd).
var voting := false

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
## Icy ground (blizzard): slow to speed up, slow to stop.
var _icy := false
var _shape: CollisionShape3D
var _crouching := false
var _eye := EYE_HEIGHT
var _mantle := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _chute := 0.0
var _canopy: MeshInstance3D
var _hook_point := Vector3.INF
var _hook_time := 0.0
var _hook_line: MeshInstance3D
var _hook_mesh: ImmediateMesh
var _help_time := 0.0
var _help_target: Node3D
var _push := Vector3.ZERO
var _water_level := 0.0
var _water_current := Vector3.ZERO
var _water_frame := -10
var _underwater_time := 0.0
var _underwater_tint: ColorRect
var _underwater_mat: ShaderMaterial
## Water on the lens: rain while out in the open, streaks after surfacing.
var _drops: ColorRect
var _drops_mat: ShaderMaterial
var _lens := 0.0
var _lens_splash := 0.0
var _was_under := false
var _roof_check := 0.0
var _under_roof := false
## Waving (emote): arms up for a moment (seen in third person and the shadow).
var _wave_time := 0.0
## First-person hands, shown only while climbing, mantling, gliding or hooking.
var _hands: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _hands_up := 0.0
var _hand_phase := 0.0


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
	_shape = shape

	# Parachute canopy over the head, and the hook's rope (drawn only in use).
	_canopy = MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 2.2
	dome.height = 1.6
	dome.is_hemisphere = true
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.95, 0.35, 0.15)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material = cloth
	_canopy.mesh = dome
	_canopy.position.y = 3.6
	_canopy.visible = false
	add_child(_canopy)
	_hook_mesh = ImmediateMesh.new()
	_hook_line = MeshInstance3D.new()
	_hook_line.mesh = _hook_mesh
	_hook_line.top_level = true
	var rope := StandardMaterial3D.new()
	rope.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope.albedo_color = Color(0.2, 0.18, 0.15)
	_hook_line.material_override = rope
	add_child(_hook_line)

	# Our own character: only its shadow shows (first person).
	_body = Avatar.new()
	# Placed every frame at the drawn (interpolated) position, like the camera,
	# so in third person it doesn't stutter against it.
	_body.top_level = true
	add_child(_body)

	# Slightly larger than the capsule so falling debris registers before it rests on us.
	var hitbox := Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2 | 16
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
	_underwater_mat = ShaderMaterial.new()
	_underwater_mat.shader = UNDERWATER_SHADER
	_underwater_tint.material = _underwater_mat
	_underwater_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_underwater_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater_tint.visible = false
	tint_layer.add_child(_underwater_tint)
	_drops = ColorRect.new()
	_drops_mat = ShaderMaterial.new()
	_drops.material = _drops_mat
	_drops.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drops.visible = false
	tint_layer.add_child(_drops)
	add_child(tint_layer)
	_build_hands()

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
	_body.set_extras(Profile.wearing, Profile.skin_color().darkened(0.25))
	apply_camera_mode()


func _physics_process(delta: float) -> void:
	_prev_pos = global_position
	if not alive:
		return
	if _mantle > 0.0:
		# Pulling up over a ledge: a short scripted move, no physics.
		_mantle -= delta
		var t := 1.0 - maxf(_mantle, 0.0) / MANTLE_TIME
		global_position = _mantle_from.lerp(_mantle_to, smoothstep(0.0, 1.0, t))
		velocity = Vector3.ZERO
		_fall_speed = 0.0
		return
	_update_crouch()
	_use_items()
	_help_teammates(delta)

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
	if _crouching:
		speed = CROUCH_SPEED
	if in_water:
		speed *= _swim_factor
	if not use_mouse and Settings.auto_jump and not in_water and not _crouching:
		_auto_jump(dir)
	if not is_on_floor() and not in_water and input.y < -0.5:
		_try_mantle(dir)
	if _chute > 0.0:
		_chute -= delta
		velocity.y = maxf(velocity.y, -CHUTE_FALL)
		_fall_speed = 0.0
		if is_on_floor() or in_water:
			_chute = 0.0
	if _hook_time > 0.0:
		_hook_time -= delta
		var to := _hook_point - (global_position + Vector3.UP)
		if to.length() < 1.5 or is_on_wall() and _hook_time < 0.9:
			_hook_time = 0.0
		else:
			velocity.y = to.normalized().y * HOOK_SPEED
			_push = Vector3(to.x, 0, to.z).normalized() * HOOK_SPEED
			_fall_speed = 0.0
	# A shaking ground makes footing unreliable (a smooth sway, not jitter).
	var sway_t := _shake_time * 3.0
	var wobble := Vector3(sin(sway_t), 0, cos(sway_t * 1.3)) * _quake * 1.2
	_walk = _walk.move_toward(dir * speed + wobble, speed * (1.6 if _icy else 10.0) * delta)
	_push = _push.lerp(Vector3.ZERO, minf(drag * delta, 1.0))
	velocity.x = _walk.x + _push.x
	velocity.z = _walk.z + _push.z
	move_and_slide()
	_touch_pieces()
	max_height = maxf(max_height, global_position.y)
	# Grass and flowers bend away from the player's legs.
	RenderingServer.global_shader_parameter_set("player_pos", global_position)

	if global_position.y < KILL_HEIGHT:
		if rescued:
			# Safe this round, but not falling forever.
			teleport(Vector3(0, 30, 0))
		take_damage(MAX_HEALTH)


## The rescue helicopter picked us up: full health, bonus, safe till the round ends.
func rescue(bonus: int) -> void:
	if not alive or rescued:
		return
	rescued = true
	bonus_points += bonus
	health = max_health
	health_changed.emit(health, max_health)
	rescued_now.emit()


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


## Crouch while the action is held (a toggle on touch); standing up needs room.
func _update_crouch() -> void:
	var want := controls_enabled and Input.is_action_pressed("crouch") and is_on_floor()
	if want == _crouching:
		return
	if not want:
		var space := get_world_3d().direct_space_state
		var from := global_position + Vector3.UP * (CROUCH_HEIGHT - 0.1)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * (BODY_HEIGHT - CROUCH_HEIGHT + 0.15), 1 | 2, [get_rid()])
		if not space.intersect_ray(query).is_empty():
			return
	_crouching = want
	var capsule := _shape.shape as CapsuleShape3D
	capsule.height = CROUCH_HEIGHT if want else BODY_HEIGHT
	_shape.position.y = capsule.height * 0.5


## Jumping at a wall whose top is within reach pulls you up onto it.
func _try_mantle(dir: Vector3) -> void:
	if not is_on_wall() or dir.length() < 0.3 or _ladder > 0.0:
		return
	var ahead := Vector3(dir.x, 0, dir.z).normalized()
	if ahead.dot(-get_wall_normal()) < 0.5:
		return
	var space := get_world_3d().direct_space_state
	var probe := global_position + ahead * (BODY_RADIUS + 0.45) + Vector3.UP * (LEDGE_MAX + 0.3)
	var down := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * (LEDGE_MAX - LEDGE_MIN + 0.3), 1 | 2, [get_rid()])
	var hit := space.intersect_ray(down)
	if hit.is_empty() or hit.normal.y < 0.7:
		return
	var top: Vector3 = hit.position
	# Room to stand up there.
	var up := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.1, top + Vector3.UP * (BODY_HEIGHT - 0.1), 1 | 2, [get_rid()])
	if not space.intersect_ray(up).is_empty():
		return
	_mantle = MANTLE_TIME
	_mantle_from = global_position
	_mantle_to = top + Vector3.UP * 0.05
	_jump_buffer = 0.0


## Item buttons / keys (1, 2, 3).
func _use_items() -> void:
	if not controls_enabled or voting:
		return
	if Input.is_action_just_pressed("item_parachute"):
		use_item("parachute")
	if Input.is_action_just_pressed("item_bandage"):
		use_item("bandage")
	if Input.is_action_just_pressed("item_hook"):
		use_item("hook")
	if Input.is_action_just_pressed("follow"):
		call_followers()
	if Input.is_action_just_pressed("emote"):
		wave()
	if Input.is_action_just_pressed("photo"):
		photo_requested.emit()
	if Input.is_action_just_pressed("camera"):
		toggle_camera()


## First / third person (V, the touch "Kamera" button, settings).
func toggle_camera() -> void:
	Settings.third_person = not Settings.third_person
	Settings.save_settings()
	apply_camera_mode()


func apply_camera_mode() -> void:
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.third_person \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## "Beni takip et!": the two nearest bots follow; pressed again, they stop.
func call_followers() -> void:
	var following := get_tree().get_nodes_in_group("bots").filter(func(b: Node) -> bool: return b.leader == self)
	if not following.is_empty():
		for bot: Node in following:
			bot.follow(null)
		get_tree().call_group("hud", "add_note", "Takım: kendi başınıza")
		return
	var near := get_tree().get_nodes_in_group("bots").filter(func(b: Node3D) -> bool:
		return b.alive and b.global_position.distance_to(global_position) < 30.0)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	for bot: Node in near.slice(0, 2):
		bot.follow(self)
	get_tree().call_group("hud", "add_note", "Beni takip edin!" if not near.is_empty() else "Yakında kimse yok")


## Waves hello: bots nearby wave back.
func wave() -> void:
	_wave_time = 1.8
	for bot: Node3D in get_tree().get_nodes_in_group("bots"):
		if bot.alive and bot.global_position.distance_to(global_position) < 20.0:
			bot.wave_back()


func use_item(id: String) -> void:
	if items.get(id, 0) <= 0 or not alive:
		return
	match id:
		"parachute":
			if is_on_floor():
				return
			_chute = CHUTE_TIME
		"bandage":
			if health >= max_health:
				return
			health = minf(health + BANDAGE_HEAL, max_health)
			health_changed.emit(health, max_health)
		"hook":
			var from := _camera.global_position
			var query := PhysicsRayQueryParameters3D.create(from, from - _camera.global_basis.z * HOOK_RANGE, 1 | 2, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				return
			_hook_point = hit.position
			_hook_time = 1.4
	items[id] -= 1
	items_changed.emit(items)
	get_tree().call_group("sound", "play", "click", null, 0.0, 0.7)


## Standing by a badly hurt bot for a moment patches it up (and earns points).
func _help_teammates(delta: float) -> void:
	if _help_target and (not is_instance_valid(_help_target) or not _help_target.alive \
			or _help_target.global_position.distance_to(global_position) > 2.2):
		_help_target = null
		_help_time = 0.0
	if _help_target == null:
		for bot: Node3D in get_tree().get_nodes_in_group("bots"):
			if bot.alive and bot.health < 35.0 and bot.global_position.distance_to(global_position) < 2.0:
				_help_target = bot
				break
		return
	_help_time += delta
	if _help_time >= HELP_TIME:
		_help_target.heal(HELP_HEAL)
		bonus_points += HELP_POINTS
		helped.emit(_help_target.display_name)
		_help_target = null
		_help_time = 0.0


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
	_eye = lerpf(_eye, CROUCH_EYE if _crouching else EYE_HEIGHT, minf(delta * 12.0, 1.0))
	_place_camera(delta)
	_canopy.visible = _chute > 0.0
	_hook_mesh.clear_surfaces()
	if _hook_time > 0.0:
		_hook_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_hook_mesh.surface_add_vertex(global_position + Vector3.UP * 1.2)
		_hook_mesh.surface_add_vertex(_hook_point)
		_hook_mesh.surface_end()
	# Right stick of a gamepad turns the view.
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.18:
		add_look(stick * 2.8 * delta * Settings.sensitivity)
	if Settings.gyro and not use_mouse:
		var turn := Gyro.read()
		if turn != Vector2.ZERO:
			add_look(turn)
	var surface := _water_level if Engine.get_physics_frames() - _water_frame <= 1 else SEA_LEVEL
	var under := _camera.global_position.y < surface
	_underwater_tint.visible = under
	if under:
		_underwater_mat.set_shader_parameter("depth", surface - _camera.global_position.y)
	_update_lens(delta, under)
	_update_hands(delta)
	_wave_time -= delta
	var ground_speed := Vector2(_walk.x, _walk.z).length() if is_on_floor() else 0.0
	_body.animate(delta, ground_speed, 1.0 if _ladder > 0.0 or _wave_time > 0.0 or _chute > 0.0 else 0.0)


## Rain on the lens out in the open (nothing overhead), and water running off
## it right after coming up from under water.
func _update_lens(delta: float, under: bool) -> void:
	var weather := get_tree().get_first_node_in_group("weather")
	var raining: bool = weather != null and weather.raining()
	_roof_check -= delta
	if raining and _roof_check <= 0.0:
		_roof_check = 0.3
		var from := _camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 40.0, 1 | 2, [get_rid()])
		_under_roof = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var target: float = weather.rain_strength() if raining and not _under_roof and not under else 0.0
	_lens = move_toward(_lens, target, delta * (0.4 if target > _lens else 0.2))
	if under:
		_was_under = true
		_lens_splash = 0.0
	elif _was_under:
		_was_under = false
		_lens_splash = 1.0
	_lens_splash = maxf(_lens_splash - delta * 0.35, 0.0)
	_drops.visible = _lens > 0.01 or _lens_splash > 0.01
	if _drops.visible:
		var shader := DROPS_SHADER if Quality.level >= 1 else DROPS_LITE_SHADER
		if _drops_mat.shader != shader:
			_drops_mat.shader = shader
		_drops_mat.set_shader_parameter("amount", _lens)
		_drops_mat.set_shader_parameter("splash", _lens_splash)


## Two forearms at the bottom of the view, raised only while doing something
## with the hands: climbing (in turns), pulling up a ledge, holding the
## parachute's lines or the hook's rope.
func _build_hands() -> void:
	_hands = Node3D.new()
	_camera.add_child(_hands)
	var sleeve := BoxMesh.new()
	sleeve.size = Vector3(0.09, 0.09, 0.32)
	var hand := BoxMesh.new()
	hand.size = Vector3(0.08, 0.08, 0.1)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Avatar.SKIN_TONES[0]
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Profile.skin_color()
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		var s := MeshInstance3D.new()
		s.mesh = sleeve
		s.material_override = cloth
		s.position.z = 0.1
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(s)
		var h := MeshInstance3D.new()
		h.mesh = hand
		h.material_override = skin
		h.position.z = -0.1
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(h)
		_hands.add_child(arm)
		if side < 0.0:
			_hand_l = arm
		else:
			_hand_r = arm
	_hands.visible = false


func _update_hands(delta: float) -> void:
	var climbing := _ladder > 0.0 and not is_on_floor()
	var busy := climbing or _mantle > 0.0 or _chute > 0.0 or _hook_time > 0.0
	_hands_up = move_toward(_hands_up, 1.0 if busy and not Settings.third_person else 0.0, delta * 5.0)
	_hands.visible = _hands_up > 0.01
	if not _hands.visible:
		return
	(_hand_l.get_child(0).material_override as StandardMaterial3D).albedo_color = tint
	_hand_phase += delta * (7.0 if climbing else 0.0)
	var low := Vector3(0, -0.55, -0.35)
	for k in 2:
		var arm := _hand_l if k == 0 else _hand_r
		var side := -1.0 if k == 0 else 1.0
		var reach := Vector3(side * 0.2, -0.16, -0.42)
		if climbing:
			# Hand over hand.
			reach.y += sin(_hand_phase + k * PI) * 0.12
		elif _chute > 0.0:
			reach = Vector3(side * 0.24, 0.12, -0.32)
		elif _hook_time > 0.0 and k == 1:
			reach = Vector3(0.1, -0.08, -0.5)
		arm.position = low.lerp(reach, _hands_up)
		arm.rotation.x = lerpf(-0.9, 0.35 if _chute > 0.0 else 0.0, _hands_up)


## The eye where the body is between the last two physics steps, plus a smooth
## shake (not a new random offset every frame, which reads as jitter) and, with
## a mouse, a gentle head bob.
func _place_camera(delta: float) -> void:
	var t := _shake_time * 22.0
	var shake := maxf(_quake, _rumble) * SHAKE_AMOUNT
	var body := _prev_pos.lerp(global_position, Engine.get_physics_interpolation_fraction())
	var view := Basis.from_euler(Vector3(_pitch, _yaw, 0))
	var eye := body + Vector3.UP * _eye
	if Settings.third_person:
		# Over the shoulder, pulled in where a wall or ceiling is in the way.
		var want := eye + view * Vector3(THIRD_SIDE, 0.25, THIRD_DISTANCE)
		var query := PhysicsRayQueryParameters3D.create(eye, want, 1 | 2, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		eye = want if hit.is_empty() else eye + (hit.position - eye) * 0.85
	_head.global_transform = Transform3D(view, eye)
	_body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), body)
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
	var aim := target
	# Not through walls and floors: stop short of the first thing in the way;
	# with no room behind (a stairwell), look through the bot's own eyes.
	var query := PhysicsRayQueryParameters3D.create(target, eye, 1 | 2, [_spectate.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var room := target.distance_to(hit.position)
		if room < 1.6:
			eye = target + Vector3.UP * 0.2 - back * 0.2
			aim = eye - back * 6.0
		else:
			eye = target + (hit.position - target).normalized() * (room - 0.4)
	var follow := minf(delta * 4.0, 1.0)
	_head.global_position = _head.global_position.lerp(eye, follow)
	var look := _head.global_transform.looking_at(aim, Vector3.UP)
	_head.global_basis = _head.global_basis.slerp(look.basis, follow)
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0


## Something heavy crashed down at pos (energy: mass times speed lost): the
## closer, the more the view trembles (only the view; the ground isn't moving).
func rumble(pos: Vector3, energy: float) -> void:
	var near := 1.0 - clampf(global_position.distance_to(pos) / 20.0, 0.0, 1.0)
	_rumble = maxf(_rumble, clampf(energy / 400.0, 0.0, 0.35) * near * near)


func set_icy(on: bool) -> void:
	_icy = on


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
	if not alive or amount <= 0.0 or rescued:
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
	bonus_points = 0
	rescued = false
	_chute = 0.0
	_hook_time = 0.0
	_mantle = 0.0
	items = {"parachute": 1 if Profile.has("parachute") else 0, "bandage": 2 if Profile.has("bandage") else 0,
			"hook": 3 if Profile.has("hook") else 0}
	items_changed.emit(items)
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
