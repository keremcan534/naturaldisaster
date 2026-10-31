extends "res://scripts/disasters/disaster.gd"
## A wave crosses the map from one side, ripping out the lower floors of whatever
## it hits (weak houses collapse) and leaving deep, churning water full of floating
## debris that drains at the end. High floors of strong buildings are the safe spots.

const FIELD_INTERVAL := 0.1
const CREST_HEIGHT := 8.0
const CREST_DEPTH := 7.0
const WATER_LEVEL := 4.5
## Far beyond what ordinary walls hold: the ground floors of houses go, and the
## rest of the house comes down with them. Strong towers lose only some walls.
const CREST_FORCE := 75.0
const CURRENT_FORCE := 9.0
## Sideways churn in the flood, so debris tumbles instead of gliding.
const CHURN := 4.0
## Lift on submerged debris, past gravity once a piece is under: things float
## up and bob along the surface.
const BUOYANCY := 13.0
const CREST_PLAYER_DAMAGE := 35.0
## Fractions of the duration: the wave crossing, and draining at the end.
const TRAVEL_PART := 0.45
const DRAIN_PART := 0.25
const EDGE_MARGIN := 20.0
## The water reaches down this far so it meets the sea past the island's edge.
const BOTTOM := -3.0

const Look := preload("res://scripts/world/look.gd")

var _dir := Vector3.RIGHT
var _half := 30.0
var _front := 0.0
var _level := 0.0
var _elapsed := 0.0
var _field_timer := 0.0
var _hit_players := {}
## Rotated so local +X is the travel direction.
var _root: Node3D
## One surface for the whole flood: the shader shapes the wave front from "front".
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _spray: CPUParticles3D


func _init() -> void:
	display_name = "Tsunami"
	kind = "tsunami"
	warning = "Üst katlara ya da çatıya çık!"
	duration = 28.0
	mood = "overcast"


func begin() -> void:
	_half = world.map_size * 0.5
	var angle := PI * 0.5 * (randi() % 4)
	_dir = Basis(Vector3.UP, angle) * Vector3.RIGHT
	_root = Node3D.new()
	_root.rotation.y = angle
	add_child(_root)
	_front = -_half - EDGE_MARGIN

	_water = _make_water()
	_root.add_child(_water)
	_spray = _make_spray()
	_root.add_child(_spray)


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
	if s > _front - CREST_DEPTH and p.y < CREST_HEIGHT + 1.0:
		return _dir * CREST_FORCE * (1.0 - 0.6 * clampf(p.y / CREST_HEIGHT, 0.0, 1.0)) + Vector3.UP * 8.0
	if p.y < _level:
		var side := _dir.cross(Vector3.UP)
		var churn := side * sin(_elapsed * 1.7 + s * 0.35) * CHURN
		var depth := clampf((_level - p.y) / 1.2, 0.0, 1.0)
		return _dir * CURRENT_FORCE + churn + Vector3.UP * BUOYANCY * depth
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
				p.push(_dir * 18.0 + Vector3.UP * 5.0)
			p.set_water(CREST_HEIGHT, _dir * 20.0)
		elif _level > 0.0:
			p.set_water(_level, _dir * CURRENT_FORCE)


func _update_meshes(travel: float) -> void:
	var breaking := travel < 1.0
	_water.visible = _level > 0.02 or breaking
	_water_mat.set_shader_parameter("front", _front if breaking else _half + EDGE_MARGIN * 3.0)
	_water_mat.set_shader_parameter("level", _level)
	_water_mat.set_shader_parameter("crest_height", CREST_HEIGHT if breaking else _level)
	_spray.emitting = breaking
	_spray.position = Vector3(_front - 0.5, CREST_HEIGHT, 0)


func _make_water() -> MeshInstance3D:
	var reach := _half + EDGE_MARGIN
	var plane := PlaneMesh.new()
	plane.size = Vector2(reach * 2.0 + 20.0, reach * 2.0)
	# Dense along the travel direction, where the wave's profile is.
	plane.subdivide_width = int(plane.size.x / 0.6)
	plane.subdivide_depth = 6
	_water_mat = Look.tsunami_water()
	_water_mat.set_shader_parameter("crest_depth", CREST_DEPTH)
	_water_mat.set_shader_parameter("bottom", BOTTOM)
	_water_mat.set_shader_parameter("side_half", reach)
	_water_mat.set_shader_parameter("back", -reach - 10.0)
	_water_mat.set_shader_parameter("flow", Vector2(_dir.x, _dir.z) * 3.0)
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = _water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader lifts the flat plane into the wave.
	water.extra_cull_margin = CREST_HEIGHT - BOTTOM
	water.visible = false
	return water


## White spray blown off the top of the crest along its whole width.
func _make_spray() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.material = Look.sprite()
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.amount = 60
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.5, 0.3, _half + EDGE_MARGIN)
	p.direction = Vector3(1, 1.2, 0)
	p.spread = 25.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.scale_amount_curve = Look.grow(0.5)
	p.color_ramp = Look.ramp([Color(0.95, 0.97, 1.0, 0.0), Color(0.92, 0.95, 0.97, 0.7), Color(0.9, 0.93, 0.95, 0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
