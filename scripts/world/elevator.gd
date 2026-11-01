extends AnimatableBody3D
## A glass lift running up the outside of a tall building: it waits at the
## bottom, rises to the top, waits, comes back down. Stand on it to ride. A
## quake or a strong wind can jam it (it stops where it is).

const WAIT := 3.0
const SPEED := 2.2

var bottom := 0.0
var top := 20.0
var _going_up := true
var _wait := WAIT
var _jammed := false


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_to_group("elevators")


## Disasters that shake things (see earthquake.gd) can stop it.
func jam() -> void:
	_jammed = true


func _physics_process(delta: float) -> void:
	if _jammed:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var goal := top if _going_up else bottom
	position.y = move_toward(position.y, goal, SPEED * delta)
	if is_equal_approx(position.y, goal):
		_going_up = not _going_up
		_wait = WAIT
