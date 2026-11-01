extends "res://scripts/disasters/tsunami.gd"
## Three waves in a row from the same side, each bigger than the last, the flood
## rising after each. The first is a warning: whoever comes down after it gets
## caught by the next.

const HEIGHTS := [5.5, 7.0, 9.5]
const LEVELS := [1.5, 2.8, 4.2]
const SERIES_PART := 0.78

var _wave := -1


func _init() -> void:
	super()
	display_name = "Dalga Serisi"
	warning = "Art arda üç dalga geliyor! Yüksekte kal, dalgalar arasında inme!"
	duration = 42.0
	safe_height = 10.5


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var period := duration * SERIES_PART / HEIGHTS.size()
	var k := mini(int(_elapsed / period), HEIGHTS.size() - 1)
	if k != _wave:
		_wave = k
		crest_height = HEIGHTS[k]
		_hit_players.clear()
		_water_mat.set_shader_parameter("lip_size", crest_height * 0.28)
	var travel := clampf((_elapsed - k * period) / (period * 0.75), 0.0, 1.0)
	if _elapsed > duration * SERIES_PART:
		travel = 1.0
	_front = lerpf(-_half - EDGE_MARGIN, _half + EDGE_MARGIN, travel)
	var drain := clampf((duration - _elapsed) / (duration * 0.15), 0.0, 1.0)
	var rising: float = LEVELS[k] if travel > 0.6 else (LEVELS[k - 1] if k > 0 else 0.0)
	_level = lerpf(_level, rising, minf(delta, 1.0)) * drain
	_update_meshes(travel)
	_affect_players()
	var camera := get_viewport().get_camera_3d()
	if camera:
		var gap := absf(camera.global_position.dot(_dir) - _front)
		var roar := (1.0 - clampf(gap / 60.0, 0.0, 1.0)) if travel < 1.0 else 0.0
		get_tree().call_group("sound", "loop", "surf", maxf(roar, 0.3 if _level > 0.5 else 0.0), 0.85)
	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = FIELD_INTERVAL
		var width := _half + EDGE_MARGIN
		var local := AABB(Vector3(-width, -1.0, -width), Vector3(_front + width, crest_height + 2.0, width * 2.0))
		get_tree().call_group("structures", "apply_field", _root.global_transform * local, _force_at, FIELD_INTERVAL)
