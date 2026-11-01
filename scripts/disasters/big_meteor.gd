extends "res://scripts/disasters/disaster.gd"
## One giant meteor: it appears far up in the sky, glowing and trailing fire,
## and grows as it falls toward a spot marked by a red ring on the ground. When
## it hits, everything in the ring is blown apart and set alight, a shock wave
## knocks people off their feet, and a crater is left behind. Get out of the ring.

const Look := preload("res://scripts/world/look.gd")

const IMPACT_PART := 0.55
const BLAST_RADIUS := 17.0
const BLAST_FORCE := 45.0
const BLAST_DAMAGE := 130.0
const SHOCK_RADIUS := 45.0

var _impact := Vector3.ZERO
var _from := Vector3.ZERO
var _elapsed := 0.0
var _hit := false
var _rock: Node3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _crater: MeshInstance3D


func _init() -> void:
	display_name = "Dev Meteor"
	kind = "bigmeteor"
	warning = "Dev bir meteor düşüyor! Kırmızı halkanın dışına kaç!"
	duration = 30.0
	mood = "dusk"


func begin() -> void:
	var half: float = world.map_size * 0.5
	var structures := get_tree().get_nodes_in_group("structures")
	_impact = Vector3(randf_range(-half * 0.5, half * 0.5), 0, randf_range(-half * 0.5, half * 0.5))
	if not structures.is_empty() and randf() < 0.6:
		var c: Vector3 = structures.pick_random().world_bounds().get_center()
		_impact = Vector3(clampf(c.x, -half * 0.6, half * 0.6), 0, clampf(c.z, -half * 0.6, half * 0.6))
	var angle := randf() * TAU
	_from = _impact + Vector3(cos(angle) * 260.0, 230.0, sin(angle) * 260.0)

	_rock = Node3D.new()
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.18, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 2.5
	sphere.material = mat
	body.mesh = sphere
	_rock.add_child(body)
	var trail := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.material = Look.sprite(2.0)
	trail.mesh = quad
	trail.amount = 60
	trail.lifetime = 2.5
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 5.0
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 6.0
	trail.scale_amount_max = 14.0
	trail.scale_amount_curve = Look.grow(0.4)
	trail.color_ramp = Look.ramp([Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.35, 0.05, 0.6), Color(0.2, 0.15, 0.12, 0.0)])
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rock.add_child(trail)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.omni_range = 60.0
	glow.light_energy = 3.0
	_rock.add_child(glow)
	_rock.position = _from
	add_child(_rock)

	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.3)
	var disc := CylinderMesh.new()
	disc.top_radius = BLAST_RADIUS
	disc.bottom_radius = BLAST_RADIUS
	disc.height = 0.05
	disc.radial_segments = 48
	disc.material = _ring_mat
	_ring = MeshInstance3D.new()
	_ring.mesh = disc
	_ring.position = _impact + Vector3.UP * 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / (duration * IMPACT_PART), 0.0, 1.0)
	if not _hit:
		# Slow at first, faster and faster: it seems to grow out of the sky.
		_rock.position = _from.lerp(_impact, t * t * t)
		_rock.rotate_y(delta * 0.6)
		_ring_mat.albedo_color.a = 0.2 + 0.2 * sin(_elapsed * (4.0 + t * 14.0)) + t * 0.25
		get_tree().call_group("sound", "loop", "wind", t * 0.8, 0.6)
		get_tree().call_group("player", "add_shake", t * t * 0.3)
		if t >= 1.0:
			_explode()


func _explode() -> void:
	_hit = true
	_rock.visible = false
	_ring.visible = false
	for k in 4:
		var a := k * TAU / 4.0
		get_tree().call_group("effects", "explosion", _impact + Vector3(cos(a), 0.5, sin(a)) * 5.0, 9.0)
	get_tree().call_group("effects", "explosion", _impact + Vector3.UP, 14.0)
	get_tree().call_group("structures", "damage_sphere", _impact, BLAST_RADIUS, BLAST_FORCE)
	get_tree().call_group("player", "explode_at", _impact, BLAST_RADIUS + 3.0, BLAST_DAMAGE)
	get_tree().call_group("player", "add_shake", 1.0)
	get_tree().call_group("sound", "play", "boom", _impact, 12.0, 0.5)
	get_tree().call_group("sound", "play", "boom", null, 0.0, 0.4)
	for k in 8:
		var a := randf() * TAU
		get_tree().call_group("structures", "ignite", _impact + Vector3(cos(a), 1.0, sin(a)) * randf_range(3.0, BLAST_RADIUS), 2.0)
	# The shock wave throws everyone farther out.
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		var away := p.global_position - _impact
		var dist := away.length()
		if dist < SHOCK_RADIUS and dist > 0.1:
			var falloff := 1.0 - dist / SHOCK_RADIUS
			p.push(away.normalized() * 14.0 * falloff + Vector3.UP * 6.0 * falloff)
	_crater = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = BLAST_RADIUS * 0.6
	disc.bottom_radius = BLAST_RADIUS * 0.6
	disc.height = 0.04
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.08, 0.06, 0.05)
	burnt.roughness = 1.0
	disc.material = burnt
	_crater.mesh = disc
	_crater.position = _impact + Vector3.UP * 0.03
	add_child(_crater)
	world.keep_on_map(_crater)


func danger_center() -> Vector3:
	return Vector3.INF if _hit else _impact
