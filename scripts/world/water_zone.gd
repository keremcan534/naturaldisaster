extends Node3D
## Standing water that is part of a map (a river): anyone inside one of the
## rectangles and below the surface swims in it (the same set_water() the
## floods use), with a gentle current.

var rects: Array[Rect2] = []
var level := -0.6
var current := Vector3.ZERO


func _physics_process(_delta: float) -> void:
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive or p.global_position.y > level:
			continue
		var at := Vector2(p.global_position.x, p.global_position.z)
		for r in rects:
			if r.has_point(at):
				p.set_water(level, current)
				break
