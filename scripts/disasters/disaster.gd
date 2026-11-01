extends Node
## Base for every disaster. DisasterManager creates one per round, adds it to the
## tree when the disaster starts, calls begin(), and frees it (with its children)
## when the round ends. Disasters do their work in _process/_physics_process.

var display_name := "Felaket"
## What bots react to: earthquake, meteor, tsunami, tornado, volcano, fire.
var kind := ""
## For floods: how high bots try to climb (0: not a flood).
var safe_height := 0.0
## Seconds of warning, when this disaster needs more than the usual.
var warning_time := 0.0
var warning := ""
## Weather mood (see weather.gd) the sky turns to from the warning on.
var mood := "clear"
## Seconds; the manager may scale this before begin().
var duration := 30.0
## The main world node, for spawning things and reading spawn_point.
var world: Node3D


func begin() -> void:
	pass


## Open to the sky above p (nothing solid within `height` meters straight up):
## hail, acid rain, sand and lightning reach it.
func exposed(p: Vector3, height := 40.0) -> bool:
	var from := p + Vector3.UP * 1.7
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * height, 1 | 2)
	return get_viewport().get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func end() -> void:
	pass


## Where the danger is (bots run from it), or Vector3.INF when it is everywhere.
func danger_center() -> Vector3:
	return Vector3.INF


## The nearest danger to `from`, for the HUD's arrow (Vector3.INF: none to show).
func danger_point(_from: Vector3) -> Vector3:
	return danger_center()
