extends "res://scripts/disasters/disaster.gd"
## A fire breaks out in a couple of buildings and spreads: up through floors,
## along walls, down slowly (see Structure.ignite), and as embers blown from the
## blaze onto whatever is near, trees, cars and the next house included. Burnt
## pieces fall and the building comes down around them. Open ground is safe;
## the flames (flames.gd) hurt anyone who gets close. Put out when it ends.

## Buildings that catch fire first, and where (ground floor or a random storey).
const START_FIRES := 2
## Embers: how often, how far they fly, and how wide a spot they light.
const EMBER_INTERVAL := 0.8
const EMBER_REACH := 4.0
const EMBER_RADIUS := 1.6

var _ember_timer := 0.0
var _points: Array = []


func _init() -> void:
	display_name = "Yangın"
	kind = "fire"
	warning = "Binalarda yangın çıktı! Alevlerden ve binalardan uzak dur!"
	duration = 40.0
	mood = "dusk"


func begin() -> void:
	var buildings: Array = []
	for s: Node in get_tree().get_nodes_in_group("structures"):
		if not s.climb_path.is_empty() or s.world_bounds().size.y > 6.0:
			buildings.append(s)
	buildings.shuffle()
	for k in mini(roundi(START_FIRES * power), buildings.size()):
		var bounds: AABB = buildings[k].world_bounds()
		var floors := maxi(int(bounds.size.y / 3.0), 1)
		var y := 1.5 + 3.0 * (randi() % mini(floors, 3))
		var at := Vector3(randf_range(bounds.position.x + 1.5, bounds.end.x - 1.5), y,
				randf_range(bounds.position.z + 1.5, bounds.end.z - 1.5))
		get_tree().call_group("structures", "ignite", at, 2.5)


func _physics_process(delta: float) -> void:
	_ember_timer -= delta
	if _ember_timer > 0.0:
		return
	_ember_timer = EMBER_INTERVAL
	_points.clear()
	for s: Node in get_tree().get_nodes_in_group("structures"):
		s.collect_fire(_points)
	if _points.is_empty():
		return
	# An ember from a random blaze lands a few meters away, mostly downwind.
	var p: Vector4 = _points.pick_random()
	var wind := Vector3(1.0, 0.0, 0.4).normalized()
	var drift := (wind + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.2), randf_range(-1, 1))).normalized()
	var at := Vector3(p.x, p.y, p.z) + drift * randf_range(1.5, EMBER_REACH)
	get_tree().call_group("structures", "ignite", at, EMBER_RADIUS)


func end() -> void:
	get_tree().call_group("structures", "extinguish")


## The nearest fire (from the last ember tick's list).
func danger_point(from: Vector3) -> Vector3:
	var best := Vector3.INF
	for p: Vector4 in _points:
		var at := Vector3(p.x, p.y, p.z)
		if best == Vector3.INF or at.distance_squared_to(from) < best.distance_squared_to(from):
			best = at
	return best
