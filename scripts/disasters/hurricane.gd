extends "res://scripts/disasters/flood.gd"
## A hurricane: a storm surge floods the low ground while a gale blows from one
## side, strong enough to strip weak houses and send everything loose flying.
## Halfway through the eye passes over: a strange calm, then the wind comes
## back from the other side. Get indoors and off the ground floor.

const PLAYER_PUSH := 9.0
const PIECE_FORCE := 23.0
const WIND_INTERVAL := 0.1

var _wind := Vector3.RIGHT
var _wind_timer := 0.0
var _gust := 0.0


func _init() -> void:
	super()
	display_name = "Kasırga"
	kind = "hurricane"
	warning = "Kasırga geliyor! Fırtına ve deniz kabarması: binaya gir, üst kata çık!"
	duration = 40.0
	mood = "storm"
	water_level = 2.6
	crest_height = 2.6
	safe_height = 3.5


func begin() -> void:
	super()
	var angle := randf() * TAU
	_wind = Vector3(cos(angle), 0, sin(angle))


## Wind strength: builds, drops in the eye, then returns reversed.
func _strength() -> float:
	var p := _elapsed / duration
	var build := smoothstep(0.0, 0.3, p)
	var eye := 1.0 - 0.85 * (smoothstep(0.42, 0.47, p) - smoothstep(0.53, 0.58, p))
	var fade := 1.0 - smoothstep(0.85, 1.0, p)
	return build * eye * fade * power


func _physics_process(delta: float) -> void:
	super(delta)
	var direction := _wind if _elapsed / duration < 0.5 else -_wind
	_gust += delta
	var k := _strength() * (0.75 + 0.35 * sin(_gust * 1.7) * sin(_gust * 0.6))
	get_tree().call_group("sound", "loop", "wind", 0.3 + k * 0.7, 0.8)
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if p.alive and exposed(p.global_position, 12.0):
			p.push(direction * PLAYER_PUSH * k * delta)
	_wind_timer -= delta
	if _wind_timer <= 0.0 and k > 0.05:
		_wind_timer = WIND_INTERVAL
		var half := _half + 5.0
		var region := AABB(Vector3(-half, -1, -half), Vector3(half * 2.0, 30.0, half * 2.0))
		var force := (direction * PIECE_FORCE + Vector3.UP * 3.0) * k
		get_tree().call_group("structures", "apply_field", region, func(_p: Vector3) -> Vector3: return force, WIND_INTERVAL)
