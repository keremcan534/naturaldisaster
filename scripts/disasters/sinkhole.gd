extends "res://scripts/disasters/disaster.gd"
## The ground gives way: a round hole opens and widens, swallowing whatever
## stands over it; buildings at its edge lose their footing and topple in.
## The island's ground is one box, so at the start its collision is cut around
## the spot and the gap filled with hidden tiles that drop as the hole grows;
## the ground shader stops drawing inside the hole (global "hole").

const TICK := 0.25
const GROW_PART := 0.75
const TILE := 2.0

var _center := Vector3.ZERO
var _max_radius := 9.0
var _radius := 0.0
var _elapsed := 0.0
var _tick := 0.0
var _tiles: Node3D
var _wall: MeshInstance3D


func _init() -> void:
	display_name = "Obruk"
	kind = "sinkhole"
	warning = "Yer çöküyor! Çöken yerden ve kenarındaki binalardan uzak dur!"
	duration = 32.0
	mood = "dust"


func begin() -> void:
	var half: float = world.map_size * 0.5
	_max_radius = clampf(world.map_size * 0.16, 7.0, 12.0) * lerpf(0.8, 1.2, (power - 0.8) / 0.5)
	var structures := get_tree().get_nodes_in_group("structures")
	var spot := Vector3(randf_range(-half * 0.5, half * 0.5), 0, randf_range(-half * 0.5, half * 0.5))
	if not structures.is_empty() and randf() < 0.6:
		var b: AABB = structures.pick_random().world_bounds()
		spot = Vector3(b.get_center().x + b.size.x * 0.5 + randf_range(-2.0, 2.0), 0, b.get_center().z)
	var reach := half - _max_radius - TILE
	_center = Vector3(clampf(spot.x, -reach, reach), 0, clampf(spot.z, -reach, reach))
	_cut_ground(half)
	_wall = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 0.85
	tube.height = 30.0
	tube.cap_top = false
	tube.cap_bottom = false
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.3, 0.22, 0.15)
	dirt.albedo_texture = preload("res://scripts/world/look.gd").noise_texture()
	dirt.uv1_scale = Vector3(4, 6, 1)
	dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	tube.material = dirt
	_wall.mesh = tube
	_wall.position = _center + Vector3.DOWN * 15.0
	_wall.scale = Vector3(0.01, 1, 0.01)
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)


## Replaces the ground's single box with four around a square gap, and fills the
## gap with invisible tiles (structure pieces, so they can drop one by one).
func _cut_ground(half: float) -> void:
	var ground: Node = get_tree().get_first_node_in_group("ground")
	if ground == null:
		return
	for child in ground.get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var gap := _max_radius + TILE
	var x0 := _center.x - gap
	var x1 := _center.x + gap
	var z0 := _center.z - gap
	var z1 := _center.z + gap
	for r: Rect2 in [Rect2(-half, -half, x0 + half, half * 2.0), Rect2(x1, -half, half - x1, half * 2.0),
			Rect2(x0, -half, x1 - x0, z0 + half), Rect2(x0, z1, x1 - x0, half - z1)]:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, 2.0, r.size.y)
		shape.shape = box
		shape.position = Vector3(r.get_center().x, -1.0, r.get_center().y)
		ground.add_child(shape)
	var Structure := preload("res://scripts/world/structure.gd")
	var tiles: Node3D = Structure.new()
	tiles.strength = 10.0
	var empty := ArrayMesh.new()
	var x := x0 + TILE * 0.5
	while x < x1:
		var z := z0 + TILE * 0.5
		while z < z1:
			tiles.add_box(Vector3(x, -1.0, z), Vector3(TILE, 2.0, TILE), Color(0.3, 0.25, 0.2), Basis.IDENTITY, empty)
			z += TILE
		x += TILE
	_tiles = tiles
	world.keep_on_map(_attach(tiles))


func _attach(node: Node3D) -> Node3D:
	add_child(node)
	return node


func _physics_process(delta: float) -> void:
	_elapsed += delta
	get_tree().call_group("sound", "loop", "rumble", 0.4 + 0.5 * (1.0 if _radius < _max_radius else 0.3), 0.7)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	_radius = _max_radius * smoothstep(0.0, GROW_PART, _elapsed / duration)
	RenderingServer.global_shader_parameter_set("hole", Vector4(_center.x, _center.z, _radius, 0.0))
	_wall.scale = Vector3(maxf(_radius, 0.01), 1, maxf(_radius, 0.01))
	if _radius > 0.3:
		get_tree().call_group("structures", "sink", _center, _radius)
		get_tree().call_group("player", "add_shake", 0.15)
		var a := randf() * TAU
		get_tree().call_group("effects", "dust", _center + Vector3(cos(a), 0.2, sin(a)) * _radius)


func danger_center() -> Vector3:
	return _center
