extends "res://scripts/disasters/tsunami.gd"
## A flash flood: no wave, the water just keeps rising over the whole island
## until the ground floors are under, with a current that drags you and floats
## everything loose. It holds for a while, then drains. Get to the first floor
## or higher (bots climb too).

const RISE_PART := 0.45
const HOLD_UNTIL := 0.8


func _init() -> void:
	super()
	display_name = "Sel"
	warning = "Sel geliyor! Su yükseliyor, üst katlara çık!"
	duration = 40.0
	mood = "overcast"
	water_level = 3.8
	crest_height = 3.8
	safe_height = 4.5


func begin() -> void:
	super()
	_spray.emitting = false
	# No wave front: the whole island is behind it.
	_front = _half + EDGE_MARGIN * 4.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var p := _elapsed / duration
	var rise := smoothstep(0.0, RISE_PART, p)
	var drain := 1.0 - smoothstep(HOLD_UNTIL, 1.0, p)
	_level = water_level * minf(rise, drain)
	_front = _half + EDGE_MARGIN * 4.0
	_update_meshes(1.0)
	_affect_players()
	get_tree().call_group("sound", "loop", "surf", 0.25 + 0.3 * rise * drain, 0.9)
	_field_timer -= delta
	if _field_timer <= 0.0 and _level > 0.1:
		_field_timer = FIELD_INTERVAL
		var half := _half + 5.0
		var region := AABB(Vector3(-half, -1.0, -half), Vector3(half * 2.0, _level + 1.5, half * 2.0))
		get_tree().call_group("structures", "apply_field", region, _force_at, FIELD_INTERVAL)


## Rising everywhere: no direction to point at.
func danger_point(_from: Vector3) -> Vector3:
	return Vector3.INF
