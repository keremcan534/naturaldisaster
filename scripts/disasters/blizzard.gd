extends "res://scripts/disasters/sky_hazard.gd"
## A blizzard: snow so thick you can barely see, a freezing wind that pushes,
## the cold eating at anyone out in the open, and icy ground underfoot (hard to
## stop or turn). Get inside.

const PLAYER_PUSH := 5.0

var _wind := Vector3.RIGHT


func _init() -> void:
	display_name = "Kar Fırtınası"
	kind = "blizzard"
	warning = "Kar fırtınası! Dışarıda donarsın: kapalı bir yere gir!"
	duration = 34.0
	mood = "snow"
	exposed_dps = 5.0


func begin() -> void:
	var angle := randf() * TAU
	_wind = Vector3(cos(angle), 0, sin(angle))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = Look.sprite(1.4)
	var amount: int = [260, 420, 600][Quality.level]
	var snow := curtain(quad, amount, 7.0, (Vector3.DOWN + _wind * 0.8).normalized(), Vector3(16, 1, 16), 2.6)
	snow.position = Vector3(0, 10, 0) - _wind * 6.0
	snow.spread = 25.0
	get_tree().call_group("player", "set_icy", true)


func _hazard_frame(delta: float) -> void:
	var k := intensity()
	RenderingServer.global_shader_parameter_set("ash_cover", minf(k * 0.9, 0.9))
	get_tree().call_group("sound", "loop", "wind", 0.4 + k * 0.5, 1.15)
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if p.alive:
			p.push(_wind * PLAYER_PUSH * k * delta)


func end() -> void:
	get_tree().call_group("player", "set_icy", false)
