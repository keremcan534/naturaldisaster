extends "res://scripts/disasters/sky_hazard.gd"
## A wall of sand: the air turns orange and you can barely see, a steady gale
## shoves you and sends clutter flying, and out in the open the sand wears you
## down. Get indoors.

## Push on players (m/s per second) and pieces (acceleration) at full strength.
const PLAYER_PUSH := 7.0
const PIECE_FORCE := 15.0
const FIELD_INTERVAL := 0.1

var _wind := Vector3.RIGHT
var _field_timer := 0.0


func _init() -> void:
	display_name = "Kum Fırtınası"
	kind = "sandstorm"
	warning = "Kum fırtınası! İçeri gir, açıkta kalma!"
	duration = 35.0
	mood = "sandstorm"
	exposed_dps = 4.0


func begin() -> void:
	var angle := randf() * TAU
	_wind = Vector3(cos(angle), 0, sin(angle))
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 0.5)
	quad.material = Look.sprite(0.9)
	var amount: int = [160, 260, 380][Quality.level]
	var sand := curtain(quad, amount, 26.0, _wind, Vector3(26, 6, 26), 1.6)
	sand.position = -_wind * 22.0 + Vector3.UP * 2.0
	sand.color = Color(0.85, 0.66, 0.42, 0.55)
	sand.spread = 10.0


func _hazard_frame(delta: float) -> void:
	var k := intensity()
	get_tree().call_group("sound", "loop", "wind", 0.5 + k * 0.5, 0.85)
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if p.alive:
			p.push(_wind * PLAYER_PUSH * k * delta)
	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = FIELD_INTERVAL
		var half: float = world.map_size * 0.5 + 5.0
		var region := AABB(Vector3(-half, -1, -half), Vector3(half * 2.0, 25.0, half * 2.0))
		var force := (_wind * PIECE_FORCE + Vector3.UP * 2.0) * k
		get_tree().call_group("structures", "apply_field", region, func(_p: Vector3) -> Vector3: return force, FIELD_INTERVAL)
