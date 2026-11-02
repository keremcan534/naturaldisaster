extends Node
## Shader rehearsal, behind the main menu. On the web every material compiles
## the first time it is drawn, so the first tornado, UFO or lava bomb of a
## session froze the game. This plays every disaster's begin() once, with its
## nodes frozen and pulled in front of a small hidden camera, and draws a copy of
## every effect that is still hidden (debris, smoke, sparks, the helicopter...).
## Everything is drawn on render layer 20, which the game's own cameras never
## show, through a SubViewport sharing the main world (same sky, fog and sun, so
## the compiled variants are the ones the game will use). A few disasters per
## frame, so the menu stays responsive; then it frees itself.

const DisasterManager := preload("res://scripts/disasters/disaster_manager.gd")

const LAYER := 1 << 19
## Disasters whose begin() changes the map for real (sets buildings on fire,
## cuts the ground) or shows nothing new.
const SKIP := ["fire.gd", "sinkhole.gd", "earthquake.gd"]
const PER_FRAME := 2
const HOLD_FRAMES := 3

var world: Node3D
var _viewport: SubViewport
var _camera: Camera3D
var _queue: Array = []
var _live: Array = []
var _skip_nodes: Array[Node] = []


## Starts it; `exclude` are nodes whose subtrees are already drawn normally (the map).
func run(main_world: Node3D, exclude: Array[Node]) -> void:
	world = main_world
	_skip_nodes = exclude
	# The game's cameras never see the rehearsal.
	for camera: Camera3D in _cameras(get_tree().root):
		camera.cull_mask &= ~LAYER
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(160, 90)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.cull_mask = LAYER
	_camera.far = 400.0
	_viewport.add_child(_camera)
	_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, -300, 0))
	_camera.current = true
	_queue.append("pools")
	for script: GDScript in DisasterManager.DISASTERS:
		if not script.resource_path.get_file() in SKIP:
			_queue.append(script)


func _process(_delta: float) -> void:
	for k in range(_live.size() - 1, -1, -1):
		var entry: Array = _live[k]
		entry[1] -= 1
		if entry[1] <= 0:
			_finish(entry[0])
			_live.remove_at(k)
	if _queue.is_empty():
		if _live.is_empty():
			queue_free()
		return
	for k in PER_FRAME:
		if _queue.is_empty():
			break
		var next: Variant = _queue.pop_front()
		if next is String:
			_live.append([_copy_pools(), HOLD_FRAMES])
		else:
			var disaster: Node = _stage(next)
			if disaster:
				_live.append([disaster, HOLD_FRAMES])


## One disaster's begin(), frozen: nothing processes, collides or touches the map.
func _stage(script: GDScript) -> Node:
	var disaster: Node = script.new()
	disaster.world = world
	disaster.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(disaster)
	# Below a dam the waves burst it; not now.
	var dam: Vector3 = world.dam
	world.dam = Vector3.INF
	disaster.begin()
	world.dam = dam
	_show(disaster)
	print_verbose("[rehearsal] %s: %d nodes" % [script.resource_path.get_file(), _all(disaster).size()])
	return disaster


## Copies of every effect node still hidden or idle (pools of debris, smoke,
## sparks, flames, the helicopter, overlays...).
func _copy_pools() -> Node:
	var holder := Node3D.new()
	add_child(holder)
	for node: Node in _idle_geometry(world):
		var copy := node.duplicate(0)
		if copy is MultiMeshInstance3D and copy.multimesh:
			# A fresh one with the same layout (copying the buffer trips over
			# visible counts).
			var source: MultiMesh = copy.multimesh
			var mm := MultiMesh.new()
			mm.transform_format = source.transform_format
			mm.use_colors = source.use_colors
			mm.use_custom_data = source.use_custom_data
			mm.mesh = source.mesh
			mm.instance_count = 2
			copy.multimesh = mm
		holder.add_child(copy)
	_show(holder)
	print_verbose("[rehearsal] idle effects: %d nodes" % holder.get_child_count())
	return holder


func _idle_geometry(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in root.get_children():
		if child in _skip_nodes or child == self:
			continue
		if child is GeometryInstance3D:
			var idle: bool = not (child as Node3D).is_visible_in_tree()
			if child is CPUParticles3D:
				idle = idle or not child.emitting
			elif child is GPUParticles3D:
				idle = idle or not child.emitting
			elif child is MultiMeshInstance3D:
				idle = idle or child.multimesh == null or child.multimesh.visible_instance_count == 0
			if idle:
				found.append(child)
				continue
		found.append_array(_idle_geometry(child))
	return found


## Everything under node: visible, on the hidden layer, in front of the hidden
## camera, emitting, and out of physics.
func _show(node: Node) -> void:
	var spot := _camera.global_position + Vector3(0, 0, -12)
	for child: Node in _all(node):
		if child is Node3D:
			(child as Node3D).visible = true
		if child is CollisionObject3D:
			child.collision_layer = 0
			child.collision_mask = 0
		if child is RigidBody3D:
			child.freeze = true
		if child is CanvasLayer:
			child.visible = false
		if child is GeometryInstance3D:
			var geometry := child as GeometryInstance3D
			geometry.layers = LAYER
			geometry.global_position = spot + Vector3(randf_range(-3, 3), randf_range(-2, 2), 0)
			geometry.process_mode = Node.PROCESS_MODE_ALWAYS
			if geometry is CPUParticles3D:
				var p := geometry as CPUParticles3D
				p.explosiveness = 1.0
				p.one_shot = false
				p.emitting = true
				p.restart()
			elif geometry is GPUParticles3D:
				var g := geometry as GPUParticles3D
				g.explosiveness = 1.0
				g.emitting = true
				g.restart()
			elif geometry is MultiMeshInstance3D and geometry.multimesh:
				var mm: MultiMesh = geometry.multimesh
				if mm.instance_count > 0:
					mm.visible_instance_count = mini(mm.instance_count, 2)
					mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.3), Vector3.ZERO))
				geometry.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))


func _finish(node: Node) -> void:
	if node.has_method("end"):
		node.end()
	node.queue_free()


func _all(node: Node) -> Array[Node]:
	var list: Array[Node] = [node]
	for child: Node in node.get_children():
		list.append_array(_all(child))
	return list


func _cameras(node: Node) -> Array[Camera3D]:
	var list: Array[Camera3D] = []
	for child: Node in node.get_children():
		if child is Camera3D:
			list.append(child)
		list.append_array(_cameras(child))
	return list
