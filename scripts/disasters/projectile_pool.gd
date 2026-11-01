extends Node
## Pooled projectiles that explode on impact (meteors, lava bombs). Nothing is
## allocated after setup(). Hits are applied deferred because physics state
## can't change while contacts are being reported.

const Look := preload("res://scripts/world/look.gd")

const FLASH_POOL_SIZE := 8
const LOST_HEIGHT := -20.0

var blast_radius := 5.0
var blast_force := 14.0
var blast_damage := 80.0
## Chance that an impact sets what it hit on fire (see Structure.ignite).
var ignite_chance := 0.0

var _bodies: Array[RigidBody3D] = []
var _trails: Array[CPUParticles3D] = []
var _flashes: Array[MeshInstance3D] = []
var _next_flash := 0


func setup(count: int, radius: float, color: Color, glow: Color) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	var shape := SphereShape3D.new()
	shape.radius = radius

	for i in count:
		var body := RigidBody3D.new()
		body.collision_layer = 8
		body.collision_mask = 1 | 2 | 4
		body.mass = 20.0
		body.continuous_cd = true
		body.contact_monitor = true
		body.max_contacts_reported = 1
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(visual)
		var trail := _trail(radius, glow)
		body.add_child(trail)
		body.body_entered.connect(_on_hit.bind(body))
		add_child(body)
		_bodies.append(body)
		_trails.append(trail)
		_park(body)

	var flash_mesh := SphereMesh.new()
	for i in FLASH_POOL_SIZE:
		var flash := MeshInstance3D.new()
		var flash_mat := StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.albedo_color = Color(glow, 0.8)
		flash.mesh = flash_mesh
		flash.material_override = flash_mat
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false
		add_child(flash)
		_flashes.append(flash)


## Fires a free projectile; does nothing if all are in flight.
func launch(pos: Vector3, velocity: Vector3) -> void:
	for body in _bodies:
		if body.visible:
			continue
		body.global_position = pos
		body.reset_physics_interpolation()
		body.freeze = false
		body.linear_velocity = velocity
		body.visible = true
		_trails[_bodies.find(body)].emitting = true
		return


func _physics_process(_delta: float) -> void:
	for body in _bodies:
		if body.visible and body.global_position.y < LOST_HEIGHT:
			_park(body)


func _park(body: RigidBody3D) -> void:
	var i := _bodies.find(body)
	if i >= 0:
		_trails[i].emitting = false
	body.visible = false
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.global_position = Vector3(0, -500, 0)
	body.reset_physics_interpolation()


func _on_hit(_other: Node, body: RigidBody3D) -> void:
	if not body.visible:
		return
	var pos := body.global_position
	body.visible = false
	_park.call_deferred(body)
	_explode.call_deferred(pos)


func _explode(pos: Vector3) -> void:
	get_tree().call_group("structures", "damage_sphere", pos, blast_radius, blast_force)
	get_tree().call_group("player", "explode_at", pos, blast_radius, blast_damage)
	get_tree().call_group("player", "add_shake", 0.6)
	get_tree().call_group("effects", "explosion", pos, blast_radius)
	if randf() < ignite_chance:
		get_tree().call_group("structures", "ignite", pos, 2.2)

	var flash := _flashes[_next_flash]
	_next_flash = (_next_flash + 1) % _flashes.size()
	var mat := flash.material_override as StandardMaterial3D
	flash.global_position = pos
	flash.scale = Vector3.ONE * 0.5
	mat.albedo_color.a = 0.8
	flash.visible = true
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * blast_radius, 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(flash.hide)


## Fire fading into smoke behind a projectile, left in world space.
func _trail(radius: float, glow: Color) -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.material = Look.sprite(2.5)
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.amount = 28
	p.lifetime = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.5
	p.spread = 180.0
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 2, 0)
	p.scale_amount_min = radius * 2.0
	p.scale_amount_max = radius * 3.0
	p.scale_amount_curve = Look.grow(0.5)
	p.color_ramp = Look.ramp([Color(1, 0.9, 0.6), Color(glow, 0.8), Color(0.15, 0.12, 0.1, 0.5), Color(0.2, 0.2, 0.2, 0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
