extends "res://scripts/disasters/tsunami.gd"
## An avalanche: a fast white wall of snow sweeps across the island under a
## whiteout sky, and leaves deep snow behind. Get high, quickly.

func _init() -> void:
	super()
	display_name = "Çığ"
	warning = "Çığ geliyor! Bir binaya, yukarıya çık!"
	duration = 28.0
	mood = "snow"
	crest_height = 7.0
	crest_depth = 6.0
	water_level = 1.2
	crest_force = 100.0
	crest_damage = 50.0
	safe_height = 8.5


func begin() -> void:
	super()
	_water_mat.set_shader_parameter("deep_color", Color(0.75, 0.8, 0.86))
	_water_mat.set_shader_parameter("shallow_color", Color(0.95, 0.97, 1.0))
	_water_mat.set_shader_parameter("reflectivity", 0.1)
