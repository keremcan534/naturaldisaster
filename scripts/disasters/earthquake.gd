extends "res://scripts/disasters/disaster.gd"
## Ground shaking that ramps up, cracks buildings and throws loose debris around.
## It dies down halfway (a false calm, at a different moment every time) and
## then an aftershock hits just as hard. `aftershock_only`: one short jolt (the
## manager's surprise aftershock between rounds).

const DAMAGE_INTERVAL := 0.3

var _elapsed := 0.0
var _damage_timer := 0.0
## Cracks open in the ground and stay (main.gd clears them with the next map).
var _cracks := 0.0
var aftershock_only := false
## When the first shock dies down and when the aftershock hits (fractions).
var _lull := 0.5
var _after := 0.66
var _warned := false


func _init() -> void:
	display_name = "Deprem"
	kind = "earthquake"
	warning = "Binalardan uzak dur!"
	duration = 30.0
	mood = "dust"
	_lull = randf_range(0.4, 0.52)
	_after = _lull + randf_range(0.12, 0.2)


func _process(delta: float) -> void:
	_elapsed += delta
	if not aftershock_only and not _warned and _elapsed / duration > _after:
		_warned = true
		get_tree().call_group("hud", "alert", "ARTÇI SARSINTI!", "Bitti sanma: binalardan uzak dur!")
	var intensity := minf(_intensity() * power, 1.0)
	get_tree().call_group("player", "add_shake", intensity)
	get_tree().call_group("sound", "loop", "rumble", intensity)
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = DAMAGE_INTERVAL
		get_tree().call_group("structures", "quake", intensity)
		_cracks = minf(maxf(_cracks, intensity * minf(power - 0.4, 1.0)), 1.0)
		RenderingServer.global_shader_parameter_set("cracks", _cracks)


## 0..1: ramps up over the first quarter, holds, dies down to a tremble (the
## false calm), the aftershock slams back in, fades out over the last 10%.
func _intensity() -> float:
	var p := _elapsed / duration
	if aftershock_only:
		return minf(p / 0.06, 1.0) * clampf((1.0 - p) / 0.7, 0.0, 1.0)
	if p < 0.25:
		return p / 0.25
	if p < _lull:
		return 1.0
	if p < _lull + 0.06:
		return lerpf(1.0, 0.08, (p - _lull) / 0.06)
	if p < _after:
		return 0.08
	if p < _after + 0.02:
		return lerpf(0.08, 1.0, (p - _after) / 0.02)
	if p > 0.9:
		return maxf((1.0 - p) / 0.1, 0.0)
	return 1.0
