extends "res://scripts/disasters/tsunami.gd"
## A mudslide: a slow, heavy wall of brown mud rolls across the island, shoving
## houses off their footings, and leaves a thick layer behind that you wade
## through. Get up off the ground.

func _init() -> void:
	super()
	display_name = "Çamur Heyelanı"
	warning = "Heyelan! Çamur seli geliyor: yükseğe çık!"
	duration = 34.0
	mood = "overcast"
	crest_height = 5.0
	crest_depth = 9.0
	water_level = 1.6
	crest_force = 110.0
	crest_damage = 40.0
	safe_height = 6.5


func begin() -> void:
	super()
	_water_mat.set_shader_parameter("deep_color", Color(0.18, 0.11, 0.06))
	_water_mat.set_shader_parameter("shallow_color", Color(0.42, 0.29, 0.16))
	_water_mat.set_shader_parameter("reflectivity", 0.12)
	_water_mat.set_shader_parameter("foam_color", Color(0.5, 0.38, 0.24))
	_water_mat.set_shader_parameter("flow", Vector2(_dir.x, _dir.z) * 1.2)
