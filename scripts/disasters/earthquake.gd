extends "res://scripts/disasters/disaster.gd"
## Ground shaking that ramps up, cracks buildings and throws loose debris around.

const DAMAGE_INTERVAL := 0.3

var _elapsed := 0.0
var _damage_timer := 0.0


func _init() -> void:
	display_name = "Deprem"
	kind = "earthquake"
	warning = "Binalardan uzak dur!"
	duration = 25.0
	mood = "dust"


func _process(delta: float) -> void:
	_elapsed += delta
	var intensity := _intensity()
	get_tree().call_group("player", "add_shake", intensity)
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = DAMAGE_INTERVAL
		get_tree().call_group("structures", "quake", intensity)


## 0..1: ramps up over the first 40%, holds, fades out over the last 15%.
func _intensity() -> float:
	var p := _elapsed / duration
	if p < 0.4:
		return p / 0.4
	if p > 0.85:
		return maxf((1.0 - p) / 0.15, 0.0)
	return 1.0
