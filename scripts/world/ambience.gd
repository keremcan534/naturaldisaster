extends Node3D
## Life around the island between disasters: cargo ships sailing slow circles
## out at sea, rocking on the swell, and seagulls circling overhead (moved by
## their shader). Rebuilt for each map's size; the birds leave at night.

const Ship := preload("res://scripts/world/ship.gd")
const BIRD_SHADER := preload("res://shaders/birds.gdshader")

const SHIPS := 2
const BIRDS := 16

var _ships: Array[MeshInstance3D] = []
## Per ship: circle radius, angle, angular speed.
var _routes: Array[Vector3] = []
var _birds: MultiMeshInstance3D
var _time := 0.0


func _ready() -> void:
	add_to_group("ambience")
	for i in SHIPS:
		var ship := MeshInstance3D.new()
		ship.mesh = Ship.mesh()
		ship.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ship)
		_ships.append(ship)
		_routes.append(Vector3.ZERO)
	_birds = MultiMeshInstance3D.new()
	_birds.multimesh = _bird_flock()
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_birds.custom_aabb = AABB(Vector3(-80, 0, -80), Vector3(160, 60, 160))
	add_child(_birds)


## A new map: ships farther out for bigger islands, at random spots of their circle.
func set_island(half: float) -> void:
	for i in SHIPS:
		var radius := half + 45.0 + i * 40.0
		var speed := (2.5 + randf() * 1.5) / radius * (1.0 if i % 2 == 0 else -1.0)
		_routes[i] = Vector3(radius, randf() * TAU, speed)


func set_night(night: bool) -> void:
	_birds.visible = not night
	_flee(0.0, 0.1)


## The gulls fly off before an earthquake or an eruption (they come back next map).
func scatter() -> void:
	_flee(1.0, 7.0)


func _flee(to: float, seconds: float) -> void:
	var mat: ShaderMaterial = _birds.multimesh.mesh.surface_get_material(0)
	var tween := create_tween()
	var from: Variant = mat.get_shader_parameter("flee")
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("flee", v), from if from != null else 0.0, to, seconds)


func _process(delta: float) -> void:
	_time += delta
	for i in SHIPS:
		var route := _routes[i]
		var angle := route.y + _time * route.z
		var pos := Vector3(cos(angle) * route.x, -2.5 - Ship.DRAFT + sin(_time * 0.7 + i) * 0.3, sin(angle) * route.x)
		# Bow along the direction of travel, rocking on the swell.
		var heading := -angle - PI * 0.5 if route.z > 0.0 else -angle + PI * 0.5
		var rock := Basis.from_euler(Vector3(sin(_time * 0.5 + i) * 0.04, 0, sin(_time * 0.37 + i * 2.0) * 0.025))
		_ships[i].transform = Transform3D(Basis(Vector3.UP, heading) * rock, pos)


func _bird_flock() -> MultiMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Body along -Z, two wings out to +-0.75 m (the shader flaps |x| > 0.1).
	var tris := [
		[Vector3(0, 0, -0.35), Vector3(-0.08, 0, 0.25), Vector3(0.08, 0, 0.25)],
		[Vector3(-0.08, 0, -0.1), Vector3(-0.75, 0, 0.12), Vector3(-0.08, 0, 0.15)],
		[Vector3(0.08, 0, -0.1), Vector3(0.08, 0, 0.15), Vector3(0.75, 0, 0.12)],
	]
	for tri: Array in tris:
		for v: Vector3 in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mat := ShaderMaterial.new()
	mat.shader = BIRD_SHADER
	st.set_material(mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = st.commit()
	mm.instance_count = BIRDS
	for i in BIRDS:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		var speed := randf_range(7.0, 10.0) * (1.0 if i % 3 != 0 else -1.0)
		mm.set_instance_custom_data(i, Color(randf() * TAU, randf_range(18.0, 45.0), randf_range(16.0, 32.0), speed))
	return mm
