extends "res://scripts/disasters/disaster.gd"
## A wave crosses the map from one side, smashing the lower floors of whatever it
## hits and leaving deep water full of floating debris that drains at the end.
## Upper floors and roofs are the safe spots.

const FIELD_INTERVAL := 0.1
const CREST_HEIGHT := 6.0
const CREST_DEPTH := 6.0
const WATER_LEVEL := 3.0
const CREST_FORCE := 38.0
const CURRENT_FORCE := 5.0
## Just under gravity, so debris drifts and slowly sinks.
const BUOYANCY := 8.5
const CREST_PLAYER_DAMAGE := 30.0
## Fractions of the duration: the wave crossing, and draining at the end.
const TRAVEL_PART := 0.45
const DRAIN_PART := 0.25
const EDGE_MARGIN := 20.0

var _dir := Vector3.RIGHT
var _half := 30.0
var _front := 0.0
var _level := 0.0
var _elapsed := 0.0
var _field_timer := 0.0
var _hit_players := {}
## Rotated so local +X is the travel direction.
var _root: Node3D
var _body: MeshInstance3D
var _crest: MeshInstance3D


func _init() -> void:
	display_name = "Tsunami"
	warning = "Üst katlara ya da çatıya çık!"
	duration = 28.0


func begin() -> void:
	_half = world.map_size * 0.5
	var angle := PI * 0.5 * (randi() % 4)
	_dir = Basis(Vector3.UP, angle) * Vector3.RIGHT
	_root = Node3D.new()
	_root.rotation.y = angle
	add_child(_root)
	_front = -_half - EDGE_MARGIN

	_body = _water_mesh(BoxMesh.new(), Color(0.1, 0.35, 0.6, 0.75))
	var crest_mesh := PrismMesh.new()
	crest_mesh.left_to_right = 1.0
	_crest = _water_mesh(crest_mesh, Color(0.55, 0.75, 0.85, 0.85))


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var travel := minf(_elapsed / (duration * TRAVEL_PART), 1.0)
	_front = lerpf(-_half - EDGE_MARGIN, _half + EDGE_MARGIN, travel)
	_level = WATER_LEVEL * clampf((duration - _elapsed) / (duration * DRAIN_PART), 0.0, 1.0)
	_update_meshes(travel)
	_affect_players()

	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = FIELD_INTERVAL
		var width := _half + EDGE_MARGIN
		var local := AABB(Vector3(-width, -1.0, -width), Vector3(_front + width, CREST_HEIGHT + 2.0, width * 2.0))
		get_tree().call_group("structures", "apply_field", _root.global_transform * local, _force_at, FIELD_INTERVAL)


func _force_at(p: Vector3) -> Vector3:
	var s := p.dot(_dir)
	if s > _front:
		return Vector3.ZERO
	if s > _front - CREST_DEPTH and p.y < CREST_HEIGHT:
		return _dir * CREST_FORCE * (1.0 - p.y / CREST_HEIGHT) + Vector3.UP * 6.0
	if p.y < _level:
		return _dir * CURRENT_FORCE + Vector3.UP * BUOYANCY
	return Vector3.ZERO


func _affect_players() -> void:
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive:
			continue
		var s := p.global_position.dot(_dir)
		if s > _front:
			continue
		if s > _front - CREST_DEPTH and p.global_position.y < CREST_HEIGHT:
			if not _hit_players.has(p):
				_hit_players[p] = true
				p.take_damage(CREST_PLAYER_DAMAGE)
				p.push(_dir * 14.0 + Vector3.UP * 4.0)
			p.set_water(CREST_HEIGHT, _dir * 20.0)
		elif _level > 0.0:
			p.set_water(_level, _dir * CURRENT_FORCE)


func _update_meshes(travel: float) -> void:
	var width := (_half + EDGE_MARGIN) * 2.0
	var back := -_half - EDGE_MARGIN
	var body_len := _front - CREST_DEPTH - back
	_body.visible = body_len > 0.0 and _level > 0.01
	if _body.visible:
		_body.scale = Vector3(body_len, _level, width)
		_body.position = Vector3(back + body_len * 0.5, _level * 0.5, 0)
	_crest.visible = travel < 1.0
	_crest.scale = Vector3(CREST_DEPTH, CREST_HEIGHT, width)
	_crest.position = Vector3(_front - CREST_DEPTH * 0.5, CREST_HEIGHT * 0.5, 0)


func _water_mesh(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	_root.add_child(instance)
	return instance
