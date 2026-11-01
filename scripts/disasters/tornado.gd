extends "res://scripts/disasters/disaster.gd"
## A funnel wanders across the map, tearing pieces off buildings and flinging
## them (and players) around. Being inside the core hurts; the drop hurts more.
##
## Looks: two shader layers on lathe meshes (a dark core and a wide dusty sheath
## with a skirt at the ground) whose axis sways and trails behind as it moves, a
## wall cloud turning overhead, dust spiralling up around the foot (moved by
## the shader, nothing per frame) and chunks of debris orbiting.

const RADIUS := 12.0
const CORE_RADIUS := 3.0
const TOP_HEIGHT := 35.0
const SWIRL := 50.0
const PULL := 22.0
## Above gravity, so the core lifts things.
const LIFT := 38.0
const SPEED := 6.0
const CORE_DAMAGE_PER_SEC := 15.0
const FIELD_INTERVAL := 0.1
const DEBRIS_COUNT := 60
const DUST_COUNT := 90
const FUNNEL_SHADER := preload("res://shaders/tornado.gdshader")
const CLOUD_SHADER := preload("res://shaders/tornado_cloud.gdshader")
const DUST_SHADER := preload("res://shaders/tornado_dust.gdshader")
const DEBRIS_COLORS := [Color(0.45, 0.33, 0.22), Color(0.55, 0.3, 0.24), Color(0.5, 0.5, 0.48), Color(0.3, 0.27, 0.24)]
## Funnel layers: bottom radius, top radius, extra skirt at the ground, density,
## spin, low and high colors.
const LAYERS := [
	[2.3, 11.5, 1.2, 1.0, 1.1, Color(0.12, 0.11, 0.1), Color(0.2, 0.21, 0.24)],
	[4.2, 17.0, 5.0, 0.26, 0.7, Color(0.32, 0.28, 0.23), Color(0.34, 0.35, 0.38)],
]

const Look := preload("res://scripts/world/look.gd")

static var _lathes := {}

var _pos := Vector3.ZERO
var _target := Vector3.ZERO
var _half := 30.0
var _field_timer := 0.0
var _time := 0.0
var _root: Node3D
var _funnel_mats: Array[ShaderMaterial] = []
var _lean := Vector2.ZERO
var _last_pos := Vector3.ZERO
var _debris: MultiMesh
var _debris_scale := PackedFloat32Array()
## Per debris chunk: orbit radius, height, phase.
var _orbits := PackedVector3Array()


func _init() -> void:
	display_name = "Hortum"
	kind = "tornado"
	warning = "Hortumun yolundan çekil!"
	duration = 30.0
	mood = "storm"


func begin() -> void:
	_half = world.map_size * 0.5
	var angle := randf() * TAU
	_pos = Vector3(cos(angle), 0, sin(angle)) * (_half - 4.0)
	_pick_target()
	_root = Node3D.new()
	_root.position = _pos
	add_child(_root)

	_last_pos = _pos
	var texture := Look.noise_texture()
	var height := TOP_HEIGHT + 6.0
	for spec: Array in LAYERS:
		var mat := ShaderMaterial.new()
		mat.shader = FUNNEL_SHADER
		mat.set_shader_parameter("noise", texture)
		mat.set_shader_parameter("density", spec[3])
		mat.set_shader_parameter("spin", spec[4])
		mat.set_shader_parameter("color_low", spec[5])
		mat.set_shader_parameter("color_high", spec[6])
		var funnel := MeshInstance3D.new()
		funnel.mesh = _lathe(spec[0], spec[1], spec[2], height)
		funnel.material_override = mat
		# The dark core is drawn over the faint sheath, so it always reads.
		mat.render_priority = 1 if _funnel_mats.is_empty() else 0
		funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader bends the axis a few meters.
		funnel.extra_cull_margin = 12.0
		_root.add_child(funnel)
		_funnel_mats.append(mat)

	# The wall cloud: a wide slowly turning disk where the funnel meets the sky.
	var cloud_mat := ShaderMaterial.new()
	cloud_mat.shader = CLOUD_SHADER
	cloud_mat.set_shader_parameter("noise", texture)
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 110)
	var cloud := MeshInstance3D.new()
	cloud.mesh = plane
	cloud.material_override = cloud_mat
	cloud.position.y = height - 3.0
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(cloud)

	_root.add_child(_dust())

	# Orbiting chunks are visual only: one MultiMesh, one draw call.
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.7, 0.35, 0.5)
	var chunk_mat := StandardMaterial3D.new()
	chunk_mat.vertex_color_use_as_albedo = true
	chunk.material = chunk_mat
	_debris = MultiMesh.new()
	_debris.transform_format = MultiMesh.TRANSFORM_3D
	_debris.use_colors = true
	_debris.mesh = chunk
	_debris.instance_count = DEBRIS_COUNT
	var debris_instance := MultiMeshInstance3D.new()
	debris_instance.multimesh = _debris
	debris_instance.extra_cull_margin = 20.0
	_root.add_child(debris_instance)
	for i in DEBRIS_COUNT:
		var h := randf_range(0.5, TOP_HEIGHT)
		_orbits.append(Vector3(lerpf(2.5, 11.0, h / TOP_HEIGHT) + randf_range(-1.5, 1.5), h, randf() * TAU))
		_debris_scale.append(randf_range(0.4, 1.6))
		_debris.set_instance_color(i, DEBRIS_COLORS[i % DEBRIS_COLORS.size()])


func _process(delta: float) -> void:
	_time += delta
	# The top trails behind the moving foot.
	var velocity := (_pos - _last_pos) / maxf(delta, 0.001)
	_last_pos = _pos
	_lean = _lean.lerp(Vector2(-velocity.x, -velocity.z) * 1.6, minf(delta * 0.8, 1.0))
	for mat in _funnel_mats:
		mat.set_shader_parameter("lean", _lean)
	for i in DEBRIS_COUNT:
		var orbit := _orbits[i]
		var a := orbit.z - _time * (5.0 - orbit.y * 0.08)
		var spin := Basis(Vector3(1, 1, 0).normalized(), _time * 3.0 + orbit.z).scaled(Vector3.ONE * _debris_scale[i])
		var t := orbit.y / TOP_HEIGHT
		var at := Vector3(cos(a) * orbit.x, orbit.y, sin(a) * orbit.x) + Vector3(_lean.x, 0, _lean.y) * t * t
		_debris.set_instance_transform(i, Transform3D(spin, at))


func _physics_process(delta: float) -> void:
	var to_target := _target - _pos
	if to_target.length() < 2.0:
		_pick_target()
	else:
		_pos += to_target.normalized() * minf(SPEED * delta, to_target.length())
	_root.position = _pos

	var camera := get_viewport().get_camera_3d()
	if camera:
		var near := 1.0 - clampf(Vector2(camera.global_position.x - _pos.x, camera.global_position.z - _pos.z).length() / 70.0, 0.0, 1.0)
		get_tree().call_group("sound", "loop", "wind", 0.25 + near * 0.75, 0.75 + near * 0.15)
		get_tree().call_group("sound", "loop", "rumble", near * near * 0.7, 1.3)
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive:
			continue
		var at := p.global_position + Vector3.UP
		p.push(_force_at(at) * delta)
		if Vector2(at.x - _pos.x, at.z - _pos.z).length() < CORE_RADIUS:
			p.take_damage(CORE_DAMAGE_PER_SEC * delta)

	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = FIELD_INTERVAL
		var region := AABB(_pos - Vector3(RADIUS, 1.0, RADIUS), Vector3(RADIUS * 2.0, TOP_HEIGHT + 10.0, RADIUS * 2.0))
		get_tree().call_group("structures", "apply_field", region, _force_at, FIELD_INTERVAL)


func _force_at(p: Vector3) -> Vector3:
	var to_axis := Vector3(_pos.x - p.x, 0, _pos.z - p.z)
	var dist := to_axis.length()
	if dist > RADIUS:
		return Vector3.ZERO
	var falloff := 1.0 - dist / RADIUS
	var inward := to_axis / maxf(dist, 0.1)
	var tangent := inward.cross(Vector3.UP)
	var lift := LIFT * falloff if p.y < TOP_HEIGHT else -2.0
	return (tangent * SWIRL * falloff + inward * PULL * falloff + Vector3.UP * lift) * power


## Half the time head for a structure, otherwise anywhere on the map.
func _pick_target() -> void:
	var structures := get_tree().get_nodes_in_group("structures")
	if not structures.is_empty() and randf() < 0.5:
		var s: Node3D = structures.pick_random()
		_target = Vector3(s.global_position.x, 0, s.global_position.z)
	else:
		var r := _half * 0.7
		_target = Vector3(randf_range(-r, r), 0, randf_range(-r, r))


## Dust spiralling up around the foot; each puff's path is in its custom data
## and the shader moves it (see tornado_dust.gdshader).
func _dust() -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = DUST_SHADER
	mat.set_shader_parameter("puff", Look.puff_texture())
	mat.set_shader_parameter("radius", RADIUS)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = DUST_COUNT
	for i in DUST_COUNT:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(randf() * TAU, randf(), randf_range(0.5, 1.0), randf_range(0.3, 1.2)))
	var dust := MultiMeshInstance3D.new()
	dust.multimesh = mm
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.custom_aabb = AABB(Vector3(-RADIUS - 6, -2, -RADIUS - 6), Vector3(RADIUS * 2 + 12, 22, RADIUS * 2 + 12))
	return dust


## A funnel-shaped surface of revolution: UV.x around, UV.y from the ground (0)
## to the cloud (1). The radius flares toward the top; skirt widens the foot.
static func _lathe(bottom: float, top: float, skirt: float, height: float) -> ArrayMesh:
	var key := [bottom, top, skirt, height]
	if _lathes.has(key):
		return _lathes[key]
	const RINGS := 36
	const SEGMENTS := 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in RINGS + 1:
		var t := float(ring) / RINGS
		var r := bottom + (top - bottom) * t * t + skirt * exp(-t * 14.0)
		for seg in SEGMENTS + 1:
			var u := float(seg) / SEGMENTS
			var a := u * TAU
			var dir := Vector3(cos(a), 0, sin(a))
			st.set_uv(Vector2(u, t))
			st.set_normal(dir)
			st.add_vertex(dir * r + Vector3.UP * t * height)
	for ring in RINGS:
		for seg in SEGMENTS:
			var i := ring * (SEGMENTS + 1) + seg
			var j := i + SEGMENTS + 1
			for k: int in [i, j, i + 1, i + 1, j, j + 1]:
				st.add_index(k)
	var mesh := st.commit()
	_lathes[key] = mesh
	return mesh


func danger_center() -> Vector3:
	return _pos
