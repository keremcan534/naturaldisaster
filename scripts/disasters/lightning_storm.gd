extends "res://scripts/disasters/disaster.gd"
## Lightning strikes the island again and again: the tallest roofs, people out
## in the open, and anywhere at random. A glowing ring on the ground shows where
## the next bolt will land a moment before it does. Bolts hurt, knock pieces
## loose and start fires. Indoors, away from the top floor, is safe.

const Look := preload("res://scripts/world/look.gd")

const STRIKE_GAP := Vector2(0.7, 1.7)
const WARN_TIME := 1.2
const BLAST_RADIUS := 3.2
const BLAST_DAMAGE := 60.0
const FIRE_CHANCE := 0.6
const RINGS := 4

var _timer := 1.5
## Pending strikes: [position, time left].
var _pending: Array = []
var _rings: Array[MeshInstance3D] = []
var _ring_mat: StandardMaterial3D
var _time := 0.0


func _init() -> void:
	display_name = "Yıldırım Fırtınası"
	kind = "lightning"
	warning = "Yıldırımlar düşecek! Açıkta ve çatıda durma, içeri gir!"
	duration = 32.0
	mood = "storm"


func begin() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(0.6, 0.75, 1.0, 0.8)
	_ring_mat.albedo_texture = Look.puff_texture()
	var disc := PlaneMesh.new()
	disc.size = Vector2(BLAST_RADIUS * 2.0, BLAST_RADIUS * 2.0)
	disc.material = _ring_mat
	for i in RINGS:
		var ring := MeshInstance3D.new()
		ring.mesh = disc
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)


func _process(delta: float) -> void:
	_time += delta
	for i in _rings.size():
		var ring := _rings[i]
		if i < _pending.size():
			ring.visible = true
			ring.global_position = _pending[i][0] + Vector3.UP * 0.08
			var left: float = _pending[i][1]
			# Pulses faster as the bolt gets close.
			var pulse := 0.75 + 0.25 * sin(_time * lerpf(30.0, 8.0, left / WARN_TIME))
			ring.scale = Vector3.ONE * pulse
		else:
			ring.visible = false
	get_tree().call_group("sound", "loop", "wind", 0.4, 1.0)


func _physics_process(delta: float) -> void:
	var k := 0
	while k < _pending.size():
		_pending[k][1] -= delta
		if _pending[k][1] <= 0.0:
			_strike(_pending[k][0])
			_pending.remove_at(k)
		else:
			k += 1
	_timer -= delta
	if _timer <= 0.0 and _pending.size() < RINGS:
		_timer = randf_range(STRIKE_GAP.x, STRIKE_GAP.y)
		_pending.append([_pick_target(), WARN_TIME])


## Someone out in the open, the top of a building, or anywhere.
func _pick_target() -> Vector3:
	var roll := randf()
	if roll < 0.45:
		var exposed_players: Array = []
		for p: Node3D in get_tree().get_nodes_in_group("player"):
			if p.alive and exposed(p.global_position):
				exposed_players.append(p)
		if not exposed_players.is_empty():
			var target: Node3D = exposed_players.pick_random()
			return target.global_position
	if roll < 0.8:
		var tall: Array = []
		for s: Node in get_tree().get_nodes_in_group("structures"):
			if s.world_bounds().size.y > 5.0:
				tall.append(s)
		if not tall.is_empty():
			var b: AABB = tall.pick_random().world_bounds()
			var at := Vector3(randf_range(b.position.x + 1.0, b.end.x - 1.0), b.end.y + 2.0, randf_range(b.position.z + 1.0, b.end.z - 1.0))
			var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * (b.size.y + 3.0), 1 | 2)
			var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				return hit.position
	var half: float = world.map_size * 0.45
	return Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))


func _strike(at: Vector3) -> void:
	get_tree().call_group("weather", "strike_at", at)
	get_tree().call_group("player", "explode_at", at, BLAST_RADIUS, BLAST_DAMAGE)
	get_tree().call_group("player", "add_shake", 0.35)
	get_tree().call_group("structures", "damage_sphere", at, 1.8, 6.0)
	get_tree().call_group("effects", "dust", at)
	get_tree().call_group("sound", "play", "boom", at, 8.0, 1.4)
	if randf() < FIRE_CHANCE:
		get_tree().call_group("structures", "ignite", at, 1.6)

