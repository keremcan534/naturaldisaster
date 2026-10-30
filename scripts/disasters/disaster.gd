extends Node
## Base for every disaster. DisasterManager creates one per round, adds it to the
## tree when the disaster starts, calls begin(), and frees it (with its children)
## when the round ends. Disasters do their work in _process/_physics_process.

var display_name := "Felaket"
var warning := ""
## Weather mood (see weather.gd) the sky turns to from the warning on.
var mood := "clear"
## Seconds; the manager may scale this before begin().
var duration := 30.0
## The main world node, for spawning things and reading spawn_point.
var world: Node3D


func begin() -> void:
	pass


func end() -> void:
	pass
