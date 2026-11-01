extends CharacterBody3D
## An AI teammate. It runs around like a player and, a moment after a disaster
## is announced, heads for safety the way a person would: up the stairs or a
## ladder for floods, open ground for quakes, inside for meteors, away from
## tornadoes and lava. Some are quicker and smarter than others, and they don't
## always make it. Bots are in the "player" group, so disasters hurt them
## exactly like the player, and they compete for round points.

signal died

const Avatar := preload("res://scripts/player/avatar.gd")
const Maps := preload("res://scripts/world/maps.gd")

## What bots shout when they react to a disaster.
const SHOUTS := {
	"tsunami": ["Çatıya çıkın!", "Su geliyor!", "Yukarı, yukarı!"],
	"earthquake": ["Binalardan uzaklaşın!", "Açık alana!", "Yer sallanıyor!"],
	"meteor": ["İçeri girin!", "Gökyüzüne bakın!", "Saklanın!"],
	"tornado": ["Kaçııın!", "Hortum geliyor!", "Uzaklaşın!"],
	"volcano": ["Lavdan uzak durun!", "Dağ patlıyor!"],
	"fire": ["Yangın var!", "Dumandan uzak durun!", "Dışarı çıkın!"],
	"lightning": ["Çatıdan inin!", "Açıkta durmayın!", "İçeri!"],
	"hail": ["Çatının altına!", "Başınızı koruyun!"],
	"acid": ["Islanmayın!", "Kapalı yere!"],
	"sandstorm": ["Hiçbir şey görmüyorum!", "İçeri girin!"],
	"hurricane": ["Rüzgâr çok sert!", "Üst kata çıkın!"],
	"sinkhole": ["Yer çöküyor!", "Kenardan uzaklaşın!"],
	"bigmeteor": ["Halkadan çıkın!", "Koşuuun!"],
	"gas": ["Nefes alamıyorum!", "Yukarı çıkın!"],
	"heat": ["Çok sıcak!", "Gölgeye girin!"],
	"flare": ["Işınım geliyor!", "Çatı altına!"],
	"ash": ["Kül yağıyor!", "İçeri girin!"],
	"blizzard": ["Donuyorum!", "İçeri girin!"],
	"blackhole": ["Bizi çekiyor!", "Tutunun!"],
	"ufo": ["Uzaylılar!", "Işıktan kaçın!"],
	"default": ["Dikkat!", "Koşun!"],
}

const NAMES := ["Mert_06", "ZeynoTR", "KasırgaAvcısı", "Elif.exe", "BurakPro", "Deniz35", "Ayşegül", "CanBey",
		"KralKaan", "Ecem", "Yiğit", "SelinX"]
const SHIRTS := [Color(0.9, 0.3, 0.25), Color(0.25, 0.7, 0.35), Color(0.95, 0.6, 0.1), Color(0.6, 0.35, 0.85),
		Color(0.15, 0.7, 0.75), Color(0.95, 0.85, 0.2), Color(0.9, 0.45, 0.65), Color(0.4, 0.42, 0.48)]

const SPEED := 4.5
const SPRINT_SPEED := 7.0
const JUMP_VELOCITY := 5.0
const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.75
const MAX_HEALTH := 100.0
const CLIMB_SPEED := 3.5
const LADDER_GRACE := 0.2
const DEBRIS_MIN_SPEED := 4.0
const FALL_DAMAGE_MIN_SPEED := 14.0
const KILL_HEIGHT := -30.0
const PUSH_DRAG_GROUND := 6.0
const PUSH_DRAG_AIR := 1.0
const PUSH_DRAG_WATER := 2.0
const HEAD_HEIGHT := 1.6
const BREATH_TIME := 4.0
const DROWN_DAMAGE_PER_SEC := 20.0
## Decisions are made a few times a second, not every frame.
const THINK_INTERVAL := 0.25
## A waypoint counts as reached this close (horizontally).
const REACH := 0.6
## Stuck: moved less than this in one think, for this long.
const STUCK_STEP := 0.2
const STUCK_TIME := 1.0
## Tsunami crests reach about 8 m; good bots climb at least this high.
const SAFE_HEIGHT := 9.0
const EDGE_MARGIN := 3.5

var display_name := "Bot"
var tint := Color.WHITE
var is_bot := true
var score := 0
var round_points := 0
var streak := 0
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var alive := true
## Set before adding: the disaster manager (what is coming) and the world (map size).
var manager: Node
var world: Node3D

var _avatar: Avatar
var _label: Label3D
var _bubble: Label3D
var _bubble_time := 0.0
var _rng := RandomNumberGenerator.new()
## 0..1: how quickly and how sensibly it reacts.
var _skill := 1.0
## Everyone runs at a slightly different speed, so bots on the same route spread out.
var _pace := 1.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _path: Array[Vector3] = []
var _plan := ""
## The disaster the current plan answers ("" between disasters).
var _plan_for := ""
var _react := 0.0
var _hurry := false
var _stop_height := INF
var _wait := 0.0
var _think := 0.0
var _last_pos := Vector3.ZERO
var _stuck := 0.0
var _stuck_count := 0
var _sidestep := Vector3.ZERO
var _sidestep_time := 0.0
var _ladder := 0.0
var _walk := Vector3.ZERO
var _push := Vector3.ZERO
var _fall_speed := 0.0
var _water_level := 0.0
var _water_current := Vector3.ZERO
var _water_frame := -10
var _underwater := 0.0
var _dead_time := 0.0
var _panic := 0.0


func setup(index: int, seed_value: int) -> void:
	_rng.seed = seed_value
	display_name = NAMES[index % NAMES.size()]
	tint = SHIRTS[index % SHIRTS.size()]
	_skill = _rng.randf_range(0.35, 1.0)
	_pace = _rng.randf_range(0.88, 1.04)


func _ready() -> void:
	add_to_group("player")
	add_to_group("bots")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(48.0)
	_think = _rng.randf() * THINK_INTERVAL

	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = BODY_HEIGHT * 0.5
	add_child(shape)

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

	_avatar = Avatar.new()
	_avatar.set_colors(tint, Avatar.PANTS[_rng.randi() % Avatar.PANTS.size()],
			Avatar.SKIN_TONES[_rng.randi() % Avatar.SKIN_TONES.size()])
	_avatar.set_hat(_rng.randf() < 0.25)
	_avatar.visibility_range_end = 80.0
	add_child(_avatar)

	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# The same size on screen at any distance, like name tags in online games.
	_label.fixed_size = true
	_label.font_size = 40
	_label.outline_size = 12
	_label.pixel_size = 0.0009
	_label.position.y = 2.15
	_label.modulate = tint.lightened(0.35)
	_label.visibility_range_end = 45.0
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_label)

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.fixed_size = true
	_bubble.font_size = 40
	_bubble.outline_size = 14
	_bubble.pixel_size = 0.001
	_bubble.position.y = 2.55
	_bubble.modulate = Color(1.0, 0.95, 0.6)
	_bubble.outline_modulate = Color(0.1, 0.08, 0.05)
	_bubble.visibility_range_end = 40.0
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.visible = false
	add_child(_bubble)


func _physics_process(delta: float) -> void:
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.visible = false
	if not alive:
		_dead_time += delta
		_avatar.rotation.x = move_toward(_avatar.rotation.x, -PI * 0.5, delta * 6.0)
		if _dead_time > 3.0:
			_avatar.visible = false
		return

	_think -= delta
	if _think <= 0.0:
		_think = THINK_INTERVAL
		_decide()

	var in_water := _in_water()
	var dir := Vector3.ZERO
	var climb := false
	if not _path.is_empty():
		var to := _path[0] - global_position
		var flat := Vector3(to.x, 0, to.z)
		# Floating above a waypoint on the ground counts as there (swimming to a ladder).
		if flat.length() < REACH and to.y < 1.4 and (to.y > -1.2 or in_water):
			_path.pop_front()
			_stuck_count = 0
		else:
			dir = flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
			# On a ladder, keep going up until over its top (it stands above
			# the roof's edge), unless the goal is well below.
			climb = to.y > -2.5
	if _sidestep_time > 0.0:
		_sidestep_time -= delta
		dir = _sidestep
	if global_position.y > _stop_height and is_on_floor():
		# High enough: stay here.
		_path.clear()
		_stop_height = INF
		_plan = "hold"

	if is_on_floor():
		if _fall_speed > FALL_DAMAGE_MIN_SPEED:
			take_damage((_fall_speed - FALL_DAMAGE_MIN_SPEED) * 6.0)
		_fall_speed = 0.0
	else:
		velocity.y -= _gravity * (0.35 if in_water else 1.0) * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	_ladder -= delta
	if _ladder > 0.0 and climb:
		velocity.y = CLIMB_SPEED
		_fall_speed = 0.0
	elif is_on_floor() and is_on_wall() and dir != Vector3.ZERO and not in_water:
		# Bumped into something while walking: hop (furniture, rubble, kerbs).
		if dir.dot(-get_wall_normal()) > 0.3:
			velocity.y = JUMP_VELOCITY

	var drag := PUSH_DRAG_GROUND if is_on_floor() else PUSH_DRAG_AIR
	var speed := (SPRINT_SPEED if _hurry else SPEED * 0.65) * _pace
	if in_water:
		drag = PUSH_DRAG_WATER
		speed *= 0.55
		_fall_speed = 0.0
		velocity.y = maxf(velocity.y, -3.0)
		# Keep the head above water.
		if global_position.y + HEAD_HEIGHT < _water_level + 0.3:
			velocity.y = maxf(velocity.y, 2.5)
		_push += _water_current * delta
	_update_breath(delta)

	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * 10.0, 1.0))
	_walk = _walk.move_toward(dir * speed, speed * 8.0 * delta)
	_push = _push.lerp(Vector3.ZERO, minf(drag * delta, 1.0))
	velocity.x = _walk.x + _push.x
	velocity.z = _walk.z + _push.z
	move_and_slide()
	_touch_pieces()
	if global_position.y < KILL_HEIGHT:
		take_damage(MAX_HEALTH)

	var ground_speed := Vector2(_walk.x, _walk.z).length() if is_on_floor() else 0.0
	var arms := 1.0 if _ladder > 0.0 or (_panic > 0.0 and _hurry) else 0.0
	_avatar.animate(delta, ground_speed, arms)


func _touch_pieces() -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var piece := hit.get_collider() as Node
		if piece == null:
			continue
		if piece.has_meta("bounce") and hit.get_normal().y > 0.6:
			velocity.y = piece.get_meta("bounce")
			_fall_speed = 0.0
		elif piece.has_meta("ladder") and absf(hit.get_normal().y) < 0.4:
			_ladder = LADDER_GRACE


## A few times a second: notice what is coming, make or refresh a plan, and get
## unstuck.
func _decide() -> void:
	var coming: String = manager.coming_kind() if manager and manager.running() else ""
	if coming != _plan_for:
		_plan_for = coming
		_path.clear()
		_plan = ""
		_hurry = false
		_stop_height = INF
		# Slow ones take a few seconds to react.
		_react = lerpf(3.5, 0.3, _skill) + _rng.randf() * 1.0 if coming != "" else 0.0
	if _react > 0.0:
		_react -= THINK_INTERVAL
		if _react > 0.0:
			if _plan == "":
				_plan = "wander"
			_follow_plan()
			return
		_plan = ""
	if _plan == "":
		_make_plan(coming)
	_follow_plan()
	_check_stuck()


func _make_plan(coming: String) -> void:
	_panic = 0.0
	match coming:
		"tsunami":
			_panic = 1.0
			_go_up()
		"earthquake":
			_go_open()
		"meteor":
			if _rng.randf() < 0.5 + _skill * 0.3:
				_go_inside()
			else:
				_plan = "dodge"
				_hurry = true
		"tornado":
			_panic = 1.0
			_plan = "flee"
			_hurry = true
		"volcano":
			_go_far_side()
		"fire":
			_go_open()
		"hurricane", "gas":
			_panic = 1.0
			_go_up()
		"sinkhole", "bigmeteor":
			_panic = 1.0
			_plan = "flee"
			_hurry = true
		"blackhole", "ufo":
			_panic = 1.0
			_plan = "flee"
			_hurry = true
		"lightning", "hail", "acid", "sandstorm", "heat", "flare", "ash", "blizzard":
			_panic = 1.0 if coming == "lightning" else 0.0
			_go_inside()
		_:
			_plan = "wander"
			_hurry = false
	if coming != "" and _rng.randf() < 0.65:
		var lines: Array = SHOUTS.get(coming, SHOUTS.default)
		_say(lines[_rng.randi() % lines.size()])


## A speech bubble over the head for a few seconds.
func _say(text: String, seconds := 2.8) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = seconds


## Re-aims plans that follow a moving danger, and keeps wandering going.
func _follow_plan() -> void:
	match _plan:
		"wander":
			# Up on a roof or a floor: stay there until the next round.
			if _path.is_empty() and global_position.y < 1.5:
				_wait -= THINK_INTERVAL
				if _wait <= 0.0:
					_wait = _rng.randf_range(0.5, 4.0)
					var target := _island_point(global_position, 12.0)
					# In the main menu the camera stands just behind the spawn
					# point: stay out in front of it, not in its face.
					if manager and not manager.running():
						target.z = minf(target.z, world.spawn_point.z - 3.0)
					_path = [target]
					if _rng.randf() < 0.15 and is_on_floor():
						velocity.y = JUMP_VELOCITY
		"flee":
			var center: Vector3 = manager.danger_center()
			if center == Vector3.INF:
				# Not there yet: get away from the middle of the map.
				center = Vector3.ZERO
			var away := global_position - center
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
			var side := away.cross(Vector3.UP).normalized() * _rng.randf_range(-4.0, 4.0)
			_path = [_clamp_island(global_position + away.normalized() * 10.0 + side)]
		"dodge":
			if _path.is_empty():
				_path = [_island_point(global_position, 9.0)]


## Tsunami: up the best reachable building (stairs inside or a ladder outside),
## at least SAFE_HEIGHT if it is that tall; without one, to the far side.
func _go_up() -> void:
	var best: Dictionary = {}
	var best_score := -INF
	var safe: float = maxf(SAFE_HEIGHT, manager.safe_height())
	for refuge: Dictionary in Maps.refuges:
		if not is_instance_valid(refuge.structure):
			continue
		var path: Array = refuge.path
		var dist := global_position.distance_to(path[0])
		var value := minf(refuge.height, safe + 3.0) * 3.0 - dist * (0.3 + (1.0 - _skill) * 0.5) + _rng.randf() * 6.0
		if value > best_score:
			best_score = value
			best = refuge
	if best.is_empty():
		_go_far_side()
		return
	_plan = "climb"
	_hurry = true
	_path.assign(best.path)
	# Not exactly in each other's footsteps.
	for k in _path.size():
		_path[k] += Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25))
	if best.height > safe + 3.0:
		_stop_height = safe + _rng.randf() * 4.0


## Earthquake: the open spot farthest from buildings among a few tries.
func _go_open() -> void:
	_plan = "open"
	_hurry = true
	var best := global_position
	var best_score := -INF
	for k in 14:
		var p := _island_point(global_position, world.map_size * 0.5)
		var clear := INF
		for rect: Rect2 in Maps.buildings:
			var grown := rect.grow(1.0)
			var q := Vector2(p.x, p.z)
			var closest := q.clamp(grown.position, grown.end)
			clear = minf(clear, q.distance_to(closest))
		var value := minf(clear, 12.0) - global_position.distance_to(p) * 0.15 * (1.0 - _skill * 0.5)
		if value > best_score:
			best_score = value
			best = p
	_path = [best]


## Meteors: into the nearest building with stairs, a little way past the door.
func _go_inside() -> void:
	var best: Dictionary = {}
	var best_dist := INF
	for refuge: Dictionary in Maps.refuges:
		if refuge.stairs and is_instance_valid(refuge.structure):
			var dist := global_position.distance_to(refuge.path[0])
			if dist < best_dist:
				best_dist = dist
				best = refuge
	if best.is_empty():
		_plan = "dodge"
		_hurry = true
		return
	_plan = "inside"
	_hurry = true
	var path: Array = best.path
	_path.assign(path.slice(0, 3))


## Volcano: it rises off the -Z edge and its lava runs down the middle, so the
## +Z corners are safest.
func _go_far_side() -> void:
	_plan = "far"
	_hurry = true
	var half: float = world.map_size * 0.5 - EDGE_MARGIN
	var x := _rng.randf_range(6.0, maxf(half, 7.0)) * (1.0 if global_position.x >= 0.0 else -1.0)
	_path = [_clamp_island(Vector3(x, 0, half * _rng.randf_range(0.5, 1.0)))]


func _check_stuck() -> void:
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if _path.is_empty() or _sidestep_time > 0.0:
		_stuck = 0.0
		return
	_stuck = _stuck + THINK_INTERVAL if moved < STUCK_STEP else 0.0
	if _stuck < STUCK_TIME:
		return
	_stuck = 0.0
	_stuck_count += 1
	# Step aside and hop; after a few tries, skip this waypoint.
	var to := _path[0] - global_position
	var side := Vector3(to.x, 0, to.z).normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_sidestep = (side + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))).normalized()
	_sidestep_time = 0.6
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
	if _stuck_count >= 4:
		_stuck_count = 0
		_path.pop_front()
		if _path.is_empty() and _plan != "wander":
			_plan = ""


## A random walkable point within reach of `from`, on the island.
func _island_point(from: Vector3, reach: float) -> Vector3:
	var p := from + Vector3(_rng.randf_range(-reach, reach), 0, _rng.randf_range(-reach, reach))
	return _clamp_island(p)


func _clamp_island(p: Vector3) -> Vector3:
	var half: float = world.map_size * 0.5 - EDGE_MARGIN if world else 20.0
	return Vector3(clampf(p.x, -half, half), 0.0, clampf(p.z, -half, half))


## One line for --botlog.
func describe() -> String:
	var pos := global_position
	return "%-14s %-7s hp %3d at (%5.1f, %4.1f, %5.1f) wp %d%s" % [display_name, _plan, health, pos.x, pos.y, pos.z,
			_path.size(), "" if alive else " DEAD"]


func set_icy(_on: bool) -> void:
	pass


func add_shake(_amount: float) -> void:
	pass


func rumble(_pos: Vector3, _energy: float) -> void:
	pass


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


func push(delta_v: Vector3) -> void:
	_push += Vector3(delta_v.x, 0, delta_v.z)
	velocity.y += delta_v.y


func set_water(level: float, current: Vector3) -> void:
	_water_level = level
	_water_current = current
	_water_frame = Engine.get_physics_frames()


func _in_water() -> bool:
	return Engine.get_physics_frames() - _water_frame <= 1 and global_position.y < _water_level


func _update_breath(delta: float) -> void:
	if _in_water() and global_position.y + HEAD_HEIGHT < _water_level:
		_underwater += delta
		if _underwater > BREATH_TIME:
			take_damage(DROWN_DAMAGE_PER_SEC * delta)
	else:
		_underwater = 0.0


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		alive = false
		_dead_time = 0.0
		_label.visible = false
		_bubble.visible = false
		velocity = Vector3.ZERO
		_path.clear()
		died.emit()


func respawn(pos: Vector3) -> void:
	global_position = pos + Vector3(_rng.randf_range(-3.5, 3.5), 0, _rng.randf_range(-3.5, 3.5))
	reset_physics_interpolation()
	rotation.y = _rng.randf() * TAU
	velocity = Vector3.ZERO
	_walk = Vector3.ZERO
	_push = Vector3.ZERO
	_fall_speed = 0.0
	_underwater = 0.0
	health = MAX_HEALTH
	alive = true
	_avatar.visible = true
	_avatar.rotation.x = 0.0
	_label.visible = true
	_path.clear()
	_plan = "wander"
	_plan_for = ""
	_react = 0.0
	_hurry = false
	_stop_height = INF
	_wait = _rng.randf_range(0.0, 2.0)
	_last_pos = global_position


func _on_hitbox_body_entered(body: Node3D) -> void:
	var rb := body as RigidBody3D
	if rb == null:
		return
	var speed := rb.linear_velocity.length()
	if speed > DEBRIS_MIN_SPEED:
		take_damage(minf((speed - DEBRIS_MIN_SPEED) * rb.mass * 4.0, MAX_HEALTH))
