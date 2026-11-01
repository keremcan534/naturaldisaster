extends Node3D
## The rescue helicopter. In some rounds it flies in halfway through the
## disaster, hovers over the highest roof with a rope ladder hanging down, and
## whoever reaches the ladder is rescued: no more harm this round, full health
## and bonus points. Then it flies off. Built once (three meshes), hidden
## between visits; moved in _process, so physics interpolation stays off.

const Maps := preload("res://scripts/world/maps.gd")

const HOVER_TIME := 15.0
const SPEED := 24.0
## Height of the hull over the roof, and how close to the ladder's foot counts.
const HOVER_HEIGHT := 9.0
const REACH := 2.4
const BONUS := 60
const TICK := 0.1

var _state := "idle"
var _roof := Vector3.ZERO
var _from := Vector3.ZERO
var _time := 0.0
var _tick := 0.0
var _rotor: MeshInstance3D
var _tail_rotor: MeshInstance3D
var _ladder: MeshInstance3D
var _body: Node3D


func _ready() -> void:
	add_to_group("rescue")
	_body = Node3D.new()
	add_child(_body)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.45
	paint.metallic = 0.3
	var hull := MeshInstance3D.new()
	hull.mesh = _boxes([
		[Vector3(0, 0, 0), Vector3(2.2, 1.9, 4.2), Color(0.9, 0.12, 0.1)],
		[Vector3(0, 0.25, -1.9), Vector3(2.0, 1.2, 0.6), Color(0.15, 0.25, 0.35)],
		[Vector3(0, -0.2, 0.4), Vector3(2.25, 0.35, 2.6), Color(0.95, 0.95, 0.95)],
		[Vector3(0, 0.35, 4.2), Vector3(0.45, 0.45, 4.6), Color(0.9, 0.12, 0.1)],
		[Vector3(0, 1.1, 6.2), Vector3(0.15, 1.6, 0.9), Color(0.95, 0.95, 0.95)],
		[Vector3(0, 1.15, 0), Vector3(0.5, 0.45, 0.5), Color(0.2, 0.2, 0.22)],
		[Vector3(-0.95, -1.35, 0), Vector3(0.12, 0.12, 3.6), Color(0.2, 0.2, 0.22)],
		[Vector3(0.95, -1.35, 0), Vector3(0.12, 0.12, 3.6), Color(0.2, 0.2, 0.22)],
		[Vector3(-0.95, -1.1, 0.9), Vector3(0.1, 0.5, 0.1), Color(0.2, 0.2, 0.22)],
		[Vector3(0.95, -1.1, 0.9), Vector3(0.1, 0.5, 0.1), Color(0.2, 0.2, 0.22)],
		[Vector3(-0.95, -1.1, -0.9), Vector3(0.1, 0.5, 0.1), Color(0.2, 0.2, 0.22)],
		[Vector3(0.95, -1.1, -0.9), Vector3(0.1, 0.5, 0.1), Color(0.2, 0.2, 0.22)],
	])
	hull.material_override = paint
	_body.add_child(hull)
	_rotor = MeshInstance3D.new()
	_rotor.mesh = _boxes([
		[Vector3.ZERO, Vector3(10.0, 0.06, 0.35), Color(0.12, 0.12, 0.13)],
		[Vector3.ZERO, Vector3(0.35, 0.06, 10.0), Color(0.12, 0.12, 0.13)],
	])
	_rotor.material_override = paint
	_rotor.position.y = 1.45
	_body.add_child(_rotor)
	_tail_rotor = MeshInstance3D.new()
	_tail_rotor.mesh = _boxes([[Vector3.ZERO, Vector3(0.06, 1.8, 0.2), Color(0.12, 0.12, 0.13)]])
	_tail_rotor.material_override = paint
	_tail_rotor.position = Vector3(0.15, 1.1, 6.4)
	_body.add_child(_tail_rotor)
	# A rope ladder 1 m long, stretched down to the roof while hovering.
	var rungs := [[Vector3(-0.25, -0.5, 0), Vector3(0.04, 1.0, 0.04), Color(0.55, 0.45, 0.3)],
			[Vector3(0.25, -0.5, 0), Vector3(0.04, 1.0, 0.04), Color(0.55, 0.45, 0.3)]]
	for k in 4:
		rungs.append([Vector3(0, -0.125 - k * 0.25, 0), Vector3(0.5, 0.03, 0.05), Color(0.6, 0.5, 0.35)])
	_ladder = MeshInstance3D.new()
	_ladder.mesh = _boxes(rungs)
	_ladder.material_override = paint
	_ladder.position.y = -1.0
	add_child(_ladder)
	visible = false
	set_process(false)


## Flies to the highest roof a bot could climb (no roof, no rescue).
func arrive() -> void:
	var best := -INF
	for refuge: Dictionary in Maps.refuges:
		if is_instance_valid(refuge.structure) and refuge.height > best:
			best = refuge.height
			_roof = refuge.path[-1]
	if best == -INF:
		return
	var away := Vector3(_roof.x, 0, _roof.z).normalized()
	if away.length() < 0.1:
		away = Vector3.BACK
	_from = _roof + away * 140.0 + Vector3.UP * 30.0
	global_position = _from
	_state = "coming"
	_time = 0.0
	visible = true
	set_process(true)
	get_tree().call_group("hud", "toast", "Kurtarma helikopteri geliyor! En yüksek çatıya çık", 0)


func leave() -> void:
	if _state == "coming" or _state == "hover":
		_state = "leaving"


func _process(delta: float) -> void:
	_time += delta
	_rotor.rotate_y(delta * 28.0)
	_tail_rotor.rotate_x(delta * 40.0)
	var hover := _roof + Vector3.UP * HOVER_HEIGHT
	var goal := hover
	match _state:
		"coming":
			if global_position.distance_to(hover) < 0.5:
				_state = "hover"
				_time = 0.0
				get_tree().call_group("bots", "heli_at", _roof)
		"hover":
			goal = hover + Vector3(sin(_time * 0.7) * 0.4, sin(_time * 1.3) * 0.25, 0)
			if _time > HOVER_TIME:
				_state = "leaving"
			_tick -= delta
			if _tick <= 0.0:
				_tick = TICK
				_pick_up()
		"leaving":
			goal = _from + Vector3.UP * 20.0
			if global_position.distance_to(goal) < 2.0:
				_state = "idle"
				visible = false
				set_process(false)
				return
	var to := goal - global_position
	var step := to.limit_length(SPEED * delta * (0.4 if _state == "hover" else 1.0))
	global_position += step
	# Nose into the flight, tilted forward while moving.
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 1.0:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-flat.x, -flat.z), minf(delta * 2.0, 1.0))
	_body.rotation.x = lerpf(_body.rotation.x, -clampf(flat.length() * 0.02, 0.0, 0.25), minf(delta * 3.0, 1.0))
	# The ladder hangs to the roof while hovering, short otherwise.
	var length := maxf(global_position.y - _roof.y - 1.0, 1.0) if _state == "hover" else 3.0
	_ladder.scale.y = lerpf(_ladder.scale.y, length, minf(delta * 3.0, 1.0))
	# Rotor chop: louder as it gets closer.
	var camera := get_viewport().get_camera_3d()
	if camera:
		var near := 1.0 - clampf(camera.global_position.distance_to(global_position) / 130.0, 0.0, 1.0)
		get_tree().call_group("sound", "loop", "rumble", near * 0.7, 2.4)


func _pick_up() -> void:
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive or p.rescued:
			continue
		var at := p.global_position
		if Vector2(at.x - _roof.x, at.z - _roof.z).length() < REACH and at.y > _roof.y - 0.8 and at.y < _roof.y + HOVER_HEIGHT:
			p.rescue(BONUS)
			if p.is_bot:
				get_tree().call_group("hud", "add_note", "%s kurtarıldı!" % p.display_name)


## One mesh of colored boxes: [center, size, color] each.
static func _boxes(list: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each face: normal and two in-plane axes with u x v = -normal (clockwise
	# from outside, Godot's front face).
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for entry: Array in list:
		var center: Vector3 = entry[0]
		var h: Vector3 = entry[1] * 0.5
		for face: Array in faces:
			var n: Vector3 = face[0]
			var u: Vector3 = face[1] * h
			var v: Vector3 = face[2] * h
			var c := center + n * h
			var corners := [c - u - v, c + u - v, c + u + v, c - u + v]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(entry[2])
				st.set_normal(n)
				st.add_vertex(corners[k])
	return st.commit()
