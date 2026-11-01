extends "res://scripts/disasters/disaster.gd"
## A black hole opens above the island (a fun one): a black sphere ringed by a
## glowing whirl of matter, pulling everything toward it harder and harder.
## Pieces tear off and spiral in; get too close and you are gone. Run, and hold
## on to something heavy.

const Look := preload("res://scripts/world/look.gd")
const DISK_SHADER := preload("res://shaders/tornado_cloud.gdshader")

const HEIGHT := 14.0
const REACH := 45.0
const PULL := 30.0
const CORE := 3.0
const FIELD_INTERVAL := 0.1

var _center := Vector3.ZERO
var _elapsed := 0.0
var _field_timer := 0.0
var _root: Node3D
var _disk: MeshInstance3D


func _init() -> void:
	display_name = "Kara Delik"
	kind = "blackhole"
	warning = "Gökyüzünde bir kara delik açılıyor! Her şeyi çekiyor: uzaklaş, sağlam bir yere tutun!"
	duration = 28.0
	mood = "storm"


func begin() -> void:
	var half: float = world.map_size * 0.35
	_center = Vector3(randf_range(-half, half), HEIGHT, randf_range(-half, half))
	_root = Node3D.new()
	_root.position = _center
	add_child(_root)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = CORE
	sphere.height = CORE * 2.0
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	sphere.material = black
	core.mesh = sphere
	_root.add_child(core)
	var disk_mat := ShaderMaterial.new()
	disk_mat.shader = DISK_SHADER
	disk_mat.set_shader_parameter("noise", Look.noise_texture())
	disk_mat.set_shader_parameter("color", Color(1.0, 0.55, 0.2))
	disk_mat.set_shader_parameter("opacity", 1.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 26)
	_disk = MeshInstance3D.new()
	_disk.mesh = plane
	_disk.material_override = disk_mat
	_disk.rotation = Vector3(0.35, 0, 0.2)
	_disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_disk)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.omni_range = 40.0
	glow.light_energy = 2.0
	_root.add_child(glow)


func _strength() -> float:
	var p := _elapsed / duration
	return smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.88, 1.0, p)) * power


func _process(delta: float) -> void:
	_disk.rotate_object_local(Vector3.UP, delta * 1.5)
	_root.scale = Vector3.ONE * (0.3 + 0.7 * minf(_strength() / power, 1.0))


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var k := _strength()
	get_tree().call_group("sound", "loop", "wind", 0.3 + k * 0.5, 0.5)
	get_tree().call_group("sound", "loop", "rumble", k * 0.6, 0.6)
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.alive:
			continue
		var to := _center - p.global_position
		var dist := to.length()
		if dist < CORE + 1.5:
			p.take_damage(1000.0)
		elif dist < REACH:
			p.push(to.normalized() * PULL * 0.35 * k * (1.0 - dist / REACH) * delta + Vector3.UP * 4.0 * k * delta)
	_field_timer -= delta
	if _field_timer <= 0.0 and k > 0.05:
		_field_timer = FIELD_INTERVAL
		var region := AABB(_center - Vector3(REACH, HEIGHT + 2.0, REACH), Vector3(REACH * 2.0, HEIGHT + 20.0, REACH * 2.0))
		get_tree().call_group("structures", "apply_field", region, func(at: Vector3) -> Vector3:
			var to := _center - at
			var dist := maxf(to.length(), 0.5)
			if dist > REACH:
				return Vector3.ZERO
			return to / dist * PULL * k * (1.0 - dist / REACH) * 1.6, FIELD_INTERVAL)
		# Whatever reaches the core is swallowed.
		get_tree().call_group("structures", "dissolve", _center, CORE + 2.0)


func danger_center() -> Vector3:
	return Vector3(_center.x, 0, _center.z)
