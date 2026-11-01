extends "res://scripts/disasters/tsunami.gd"
## A giant tsunami: a wall of water twice as high, a flood deep enough to swim
## over houses, and a cargo ship surfing down its face. The ship plows through
## whatever it meets, rides the flood inland and runs aground when the water
## drains, staying on the island until the next map. Only the tallest roofs are safe.

const Ship := preload("res://scripts/world/ship.gd")

## The ship rides this far behind the front, its bow just over the lip.
const SHIP_BEHIND := 14.0
## Pieces in the ship's way: radius and push of each hit, along the hull.
const SHIP_HIT_RADIUS := 4.5
const SHIP_HIT_FORCE := 45.0
const SHIP_HIT_POINTS := [15.0, 7.0, -1.0, -9.0]
const SHIP_PLAYER_DAMAGE := 45.0
## Most it tips while surfing (radians).
const MAX_PITCH := 0.32
## A building at least this strong stops the ship: it rams it and sticks there.
const RAM_STRENGTH := 1.8
## One hard knock where the bow hits, then it only drifts (too slowly to break more).
const RAM_RADIUS := 3.5
const RAM_FORCE := 40.0
const RAM_SPEED := 0.6

var _ship: AnimatableBody3D
var _ship_s := 0.0
var _ship_z := 0.0
var _ship_y := 0.0
var _ship_speed := 0.0
var _ship_pitch := 0.0
var _ship_roll := 0.0
var _stop_s := 0.0
var _riding := true
var _aground := false
var _hit_timer := 0.0
var _ship_hits := {}


func _init() -> void:
	super()
	display_name = "Dev Tsunami"
	warning = "Dev dalga ve gemi geliyor! En yüksek binanın tepesine çık!"
	duration = 34.0
	mood = "overcast"
	crest_height = 17.0
	crest_depth = 12.0
	water_level = 9.5
	crest_force = 90.0
	crest_damage = 70.0
	safe_height = 18.5
	warning_time = 12.0


func begin() -> void:
	super()
	_spray.amount = 120
	_spray.scale_amount_min = 3.5
	_spray.scale_amount_max = 7.0
	_ship = AnimatableBody3D.new()
	_ship.sync_to_physics = true
	_ship.collision_layer = 1
	_ship.collision_mask = 0
	for box: Array in Ship.collision_boxes():
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box[1]
		shape.shape = b
		shape.position = box[0]
		_ship.add_child(shape)
	var hull := MeshInstance3D.new()
	hull.mesh = Ship.mesh()
	_ship.add_child(hull)
	_ship_z = randf_range(-_half * 0.4, _half * 0.4)
	_stop_s = randf_range(-_half * 0.1, _half * 0.35)
	_ship_s = _front - SHIP_BEHIND
	_ship_y = _wave_height(_ship_s) - Ship.DRAFT
	# Placed before it enters the world: a moving body that starts at the map's
	# middle would sweep through everything there on its first step.
	_place_ship()
	_root.add_child(_ship)
	_ship.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_ship.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	super(delta)
	_move_ship(delta)


func end() -> void:
	# The wreck stays where it ran aground until the next map.
	if is_instance_valid(_ship) and world.has_method("keep_on_map"):
		world.keep_on_map(_ship)


## Surf with the front until the stop point, then drift on the flood and settle
## onto the ground as it drains, tipping a little.
func _move_ship(delta: float) -> void:
	var before := Vector3(_ship_s, _ship_y, _ship_z)
	if _riding:
		_ship_s = _front - SHIP_BEHIND
		_ship_speed = (_half + EDGE_MARGIN) * 2.0 / (duration * TRAVEL_PART)
		if _ship_s >= _stop_s:
			_riding = false
		elif _rams_building():
			_riding = false
			_ship_speed = RAM_SPEED
			var bow := _ship.global_transform * Vector3(Ship.BOW, Ship.HULL_HEIGHT * 0.5, 0)
			get_tree().call_group("structures", "damage_sphere", bow, RAM_RADIUS, RAM_FORCE)
			get_tree().call_group("sound", "play", "boom", bow, 8.0, 0.7)
	elif not _aground:
		_ship_speed = move_toward(_ship_speed, 0.0, delta * 3.0)
		_ship_s += _ship_speed * delta
	var surface := _wave_height(_ship_s) if _riding else _level
	var target_y := maxf(surface - Ship.DRAFT, 0.0)
	_ship_y = lerpf(_ship_y, target_y, minf(delta * (3.0 if _riding else 1.5), 1.0))
	if not _riding and not _aground and _ship_y < 0.05 and _level < Ship.DRAFT:
		_aground = true
	if _riding:
		var ahead := _wave_height(_ship_s + 12.0)
		var back := _wave_height(_ship_s - 12.0)
		_ship_pitch = lerpf(_ship_pitch, clampf(atan2(ahead - back, 24.0), -MAX_PITCH, MAX_PITCH), minf(delta * 2.0, 1.0))
	else:
		_ship_pitch = lerpf(_ship_pitch, 0.04 if _aground else 0.0, minf(delta, 1.0))
	_ship_roll = lerpf(_ship_roll, 0.1 if _aground else sin(_elapsed * 0.9) * 0.05, minf(delta, 1.0))
	_place_ship()

	var moved := Vector3(_ship_s, _ship_y, _ship_z) - before
	var speed := moved.length() / maxf(delta, 0.001)
	_hit_timer -= delta
	if speed > 1.0 and _hit_timer <= 0.0:
		_hit_timer = FIELD_INTERVAL
		for x: float in SHIP_HIT_POINTS:
			var at := _ship.global_transform * Vector3(x, Ship.HULL_HEIGHT * 0.5, 0)
			get_tree().call_group("structures", "damage_sphere", at, SHIP_HIT_RADIUS, SHIP_HIT_FORCE)
	if speed > 3.0:
		_ram_players(speed)


func _place_ship() -> void:
	var basis := Basis.from_euler(Vector3(_ship_roll, 0, _ship_pitch))
	_ship.transform = Transform3D(basis, Vector3(_ship_s, _ship_y, _ship_z))


## The bow inside a strong building's bounds (low enough to hit it)?
func _rams_building() -> bool:
	var bow := _ship.global_transform * Vector3(Ship.BOW, Ship.HULL_HEIGHT * 0.5, 0)
	for s: Node in get_tree().get_nodes_in_group("structures"):
		if s.strength >= RAM_STRENGTH and s.world_bounds().grow(3.0).has_point(bow):
			return true
	return false


## Anyone the hull runs into (not standing on its deck) is hurt and thrown ahead.
func _ram_players(speed: float) -> void:
	var to_local := _ship.global_transform.affine_inverse()
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive or _ship_hits.has(p):
			continue
		var q := to_local * p.global_position
		if q.x > Ship.STERN - 0.5 and q.x < Ship.BOW + 0.8 and absf(q.z) < Ship.WIDTH * 0.5 + 0.7 \
				and q.y > -1.5 and q.y < Ship.DECK - 0.4:
			_ship_hits[p] = true
			p.take_damage(SHIP_PLAYER_DAMAGE)
			p.push(_dir * minf(speed, 18.0) + Vector3.UP * 6.0)


## The water surface (m) at distance s along the travel direction; the same
## profile the tsunami shader draws.
func _wave_height(s: float) -> float:
	var behind := _front - s
	if behind < 0.0:
		return lerpf(crest_height, BOTTOM, smoothstep(0.0, 4.5, -behind))
	var bump := exp(-pow(maxf(behind - 1.0, 0.0) / (crest_depth * 0.7), 2.0))
	return lerpf(_level, crest_height, bump)
