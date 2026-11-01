extends AnimatableBody3D
## A lifeboat parked near the spawn point. When a flood or a wave covers the
## ground it floats up with the water and drifts with the current; whoever
## stands in it and pushes forward drives it where they look. Water disasters
## tell it the water level through set_water() (like players).

const SPEED := 5.0
const RISE := 3.5
## The deck sits this far below the water surface when floating.
const DRAFT := 0.35
const CREW_HEIGHT := 2.2

var _rest_y := 0.0
var _water := -INF
var _current := Vector3.ZERO
var _water_frame := -10
var _time := 0.0


func _ready() -> void:
	add_to_group("boats")
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_rest_y = global_position.y
	# Flat bottom and low sides, so nobody slides out.
	for part: Array in [[Vector3(0, 0.15, 0), Vector3(2.2, 0.3, 4.6)], [Vector3(1.05, 0.55, 0), Vector3(0.1, 0.6, 4.6)],
			[Vector3(-1.05, 0.55, 0), Vector3(0.1, 0.6, 4.6)], [Vector3(0, 0.55, 2.25), Vector3(2.2, 0.6, 0.1)],
			[Vector3(0, 0.55, -2.25), Vector3(2.2, 0.6, 0.1)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[1]
		shape.shape = box
		shape.position = part[0]
		add_child(shape)
	var hull := MeshInstance3D.new()
	hull.mesh = preload("res://scripts/world/rescue_heli.gd")._boxes([
		[Vector3(0, 0.15, 0), Vector3(2.2, 0.3, 4.6), Color(0.95, 0.45, 0.1)],
		[Vector3(1.05, 0.55, 0), Vector3(0.1, 0.6, 4.6), Color(0.95, 0.45, 0.1)],
		[Vector3(-1.05, 0.55, 0), Vector3(0.1, 0.6, 4.6), Color(0.95, 0.45, 0.1)],
		[Vector3(0, 0.55, 2.25), Vector3(2.2, 0.6, 0.1), Color(0.95, 0.45, 0.1)],
		[Vector3(0, 0.55, -2.25), Vector3(2.2, 0.6, 0.1), Color(0.95, 0.45, 0.1)],
		[Vector3(0, 0.86, 0), Vector3(2.25, 0.06, 4.65), Color(0.95, 0.95, 0.95)],
		[Vector3(0, 0.45, 0.6), Vector3(2.0, 0.08, 0.5), Color(0.55, 0.4, 0.25)],
		[Vector3(0, 0.45, -1.0), Vector3(2.0, 0.08, 0.5), Color(0.55, 0.4, 0.25)],
		[Vector3(0, 0.75, 2.45), Vector3(0.5, 0.5, 0.3), Color(0.2, 0.2, 0.22)],
	])
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.6
	hull.material_override = paint
	add_child(hull)


## Called every physics frame by water disasters while the boat is in the water.
func set_water(level: float, current: Vector3) -> void:
	_water = level
	_current = current
	_water_frame = Engine.get_physics_frames()


func _physics_process(delta: float) -> void:
	_time += delta
	if Engine.get_physics_frames() - _water_frame > 1:
		_water = -INF
		_current = Vector3.ZERO
	var afloat := _water - DRAFT > _rest_y
	var target_y := maxf(_rest_y, _water - DRAFT) + (sin(_time * 1.7) * 0.06 if afloat else 0.0)
	var pos := global_position
	pos.y = move_toward(pos.y, target_y, RISE * delta)
	if afloat:
		var drive := _driver_push()
		var flow := Vector3(_current.x, 0, _current.z).limit_length(3.0) * 0.3
		pos += (drive * SPEED + flow) * delta
		if drive.length() > 0.1:
			# Bow turns toward where it's going (the boat's -Z).
			var heading := atan2(-drive.x, -drive.z)
			rotation.y = lerp_angle(rotation.y, heading, minf(delta * 1.5, 1.0))
		pos = pos.clamp(Vector3(-200, -10, -200), Vector3(200, 60, 200))
	global_position = pos


## The player standing in the boat and pushing forward steers it where the
## camera looks.
func _driver_push() -> Vector3:
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if p.is_bot or not p.alive or not p.controls_enabled:
			continue
		var local := global_transform.affine_inverse() * p.global_position
		if absf(local.x) > 1.2 or absf(local.z) > 2.4 or local.y < -0.2 or local.y > CREW_HEIGHT:
			continue
		if not Input.is_action_pressed("move_forward"):
			return Vector3.ZERO
		var camera := get_viewport().get_camera_3d()
		var ahead := -camera.global_basis.z if camera else -global_basis.z
		return Vector3(ahead.x, 0, ahead.z).normalized() * Input.get_action_strength("move_forward")
	return Vector3.ZERO
