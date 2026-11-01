extends "res://scripts/disasters/sky_hazard.gd"
## Green rain that burns: out in the open you lose health, and things left out
## in it (clutter, cars, roof edges) eat away and fall apart. Stay under a roof.

const MELTS_PER_TICK := 9


func _init() -> void:
	display_name = "Asit Yağmuru"
	kind = "acid"
	warning = "Asit yağmuru! Kapalı bir yere sığın!"
	duration = 30.0
	mood = "acid"
	exposed_dps = 10.0


func _hazard_frame(_delta: float) -> void:
	var k := intensity()
	get_tree().call_group("sound", "loop", "rain", 0.5 + k * 0.4, 0.85)
	# The hiss of it eating through things.
	get_tree().call_group("sound", "loop", "fire", k * 0.35, 1.6)


func _hazard_tick(k: float) -> void:
	for i in int(MELTS_PER_TICK * k + randf()):
		var at := random_top()
		get_tree().call_group("structures", "dissolve", at, 1.4)
		get_tree().call_group("effects", "dust", at)
