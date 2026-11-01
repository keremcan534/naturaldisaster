extends "res://scripts/disasters/sky_hazard.gd"
## Volcanic ash falls from a dark sky and settles on everything, turning the
## island grey. It is hard to breathe out in the open, and the weight piling up
## on weak roofs brings them down one after another.

const ROOF_EVERY := 2.2
const ROOF_PIECES := 4

var _roof_timer := 4.0


func _init() -> void:
	display_name = "Kül Yağmuru"
	kind = "ash"
	warning = "Volkanik kül yağıyor! Kapalı yere gir ama zayıf çatılardan uzak dur!"
	duration = 36.0
	mood = "ash"
	exposed_dps = 1.8


func begin() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	quad.material = Look.sprite(0.5)
	var amount: int = [180, 300, 450][Quality.level]
	var ash := curtain(quad, amount, 2.5, Vector3(0.2, -1, 0.1).normalized(), Vector3(18, 1, 18), 5.0)
	ash.position = Vector3(0, 12, 0)
	ash.color = Color(0.45, 0.43, 0.42, 0.9)
	ash.spread = 25.0


func _hazard_frame(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set("ash_cover", intensity() * 0.85 if _elapsed < duration * 0.9 else 0.85)
	get_tree().call_group("sound", "loop", "wind", 0.25, 0.7)


func _hazard_tick(k: float) -> void:
	_roof_timer -= TICK
	if _roof_timer > 0.0:
		return
	_roof_timer = ROOF_EVERY
	var weak: Array = []
	for s: Node in get_tree().get_nodes_in_group("structures"):
		if s.strength < 1.6 and s.world_bounds().size.y > 4.0:
			weak.append(s)
	if not weak.is_empty() and k > 0.3:
		weak.pick_random().overload(ROOF_PIECES)
