extends "res://scripts/disasters/sky_hazard.gd"
## A heat wave: a white-hot sun beats down; out in the open you lose health,
## shade and roofs are safe. The air shimmers, and dry things catch fire.

const SHIMMER := preload("res://shaders/heat_shimmer.gdshader")
const FIRE_EVERY := 2.0

var _fire_timer := 3.0
var _shimmer: CanvasLayer


func _init() -> void:
	display_name = "Isı Dalgası"
	kind = "heat"
	warning = "Isı dalgası! Gölgeye, kapalı bir yere gir!"
	duration = 35.0
	mood = "heat"
	exposed_dps = 3.2


func begin() -> void:
	# Shimmer costs a full-screen pass: medium quality and up.
	if Quality.level >= 1:
		_shimmer = CanvasLayer.new()
		_shimmer.layer = -2
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = SHIMMER
		rect.material = mat
		_shimmer.add_child(rect)
		add_child(_shimmer)


func _hazard_frame(_delta: float) -> void:
	get_tree().call_group("sound", "loop", "wind", 0.15, 1.4)


func _hazard_tick(k: float) -> void:
	_fire_timer -= TICK
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_EVERY
		if randf() < 0.4 * k:
			get_tree().call_group("structures", "ignite", random_top(), 1.4)
