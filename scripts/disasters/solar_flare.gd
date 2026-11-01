extends "res://scripts/disasters/sky_hazard.gd"
## A solar storm: the sky turns pale and an aurora burns even by day, the power
## goes out (street lamps and windows go dark), and waves of radiation sweep
## down every few seconds. A yellow flash warns of each one; whoever is out in
## the open when it hits gets burnt. Stay under a roof.

const PERIOD := 6.0
const WARN := 1.4
const BURST := 1.8

var _overlay: ColorRect
var _phase := 2.0


func _init() -> void:
	display_name = "Güneş Patlaması"
	kind = "flare"
	warning = "Güneş fırtınası! Elektrik gidiyor, ışınım dalgaları geliyor: çatı altında kal!"
	duration = 32.0
	mood = "flare"
	exposed_dps = 0.0


func begin() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(1.0, 0.92, 0.5, 0.0)
	layer.add_child(_overlay)
	add_child(layer)
	Look.set_lamps(0.0)
	RenderingServer.global_shader_parameter_set("rooms", 0.0)


func _hazard_frame(delta: float) -> void:
	_phase += delta
	var t := fmod(_phase, PERIOD)
	var warning_on := t > PERIOD - WARN
	var burst := t < BURST
	var flicker := 0.5 + 0.5 * sin(_phase * 30.0)
	_overlay.color.a = 0.35 * flicker if burst else (0.12 * flicker if warning_on else 0.0)
	RenderingServer.global_shader_parameter_set("aurora", 1.0)
	get_tree().call_group("sound", "loop", "wind", 0.2 + (0.5 if burst else 0.0), 1.6)
	exposed_dps = 16.0 if burst else 0.0


func end() -> void:
	Look.set_lamps(1.0)
