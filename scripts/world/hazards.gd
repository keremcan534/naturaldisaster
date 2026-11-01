extends Node3D
## Dangers the island's own things make once disasters break them (see
## Structure._detonate): fuel tanks and red barrels explode (and set off the next
## ones nearby, a chain), and fallen power poles leave a live, sparking spot that
## shocks anyone who walks into it for a while; their cables drop.
## Reached through call_group("hazards", ...). Pools its sparks; nothing is made
## during a round.

const EXPLOSION_RADIUS := 5.0
const EXPLOSION_FORCE := 26.0
const EXPLOSION_DAMAGE := 70.0
const SPARK_TIME := 14.0
const SPARK_RADIUS := 2.6
const SPARK_DPS := 25.0
const SPARK_EMITTERS := 4

## Live spots: [position, time left].
var _live: Array = []
var _sparks: Array[CPUParticles3D] = []
var _queue: Array = []


func _ready() -> void:
	add_to_group("hazards")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.6, 1.6, 2.2)
	quad.material = mat
	for i in SPARK_EMITTERS:
		var p := CPUParticles3D.new()
		p.mesh = quad
		p.amount = 24
		p.lifetime = 0.5
		p.explosiveness = 0.3
		p.direction = Vector3.UP
		p.spread = 80.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -9.8, 0)
		p.color = Color(0.7, 0.85, 1.0)
		p.emitting = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_sparks.append(p)


## A blast at pos (power scales it). Deferred, so a chain of barrels goes off one
## after another instead of all inside one physics call.
func explode(pos: Vector3, power: float) -> void:
	_queue.append([pos, power, 0.12])


func sparks(pos: Vector3) -> void:
	_live.append([Vector3(pos.x, 0.3, pos.z), SPARK_TIME])
	get_tree().call_group("sound", "play", "crash", pos, 4.0, 2.0)
	for cable: Node3D in get_tree().get_nodes_in_group("cables"):
		var ends: Array = cable.get_meta("ends")
		if (ends[0] as Vector3).distance_to(pos) < 1.5 or (ends[1] as Vector3).distance_to(pos) < 1.5:
			cable.visible = false


## A new map: nothing burning or live.
func clear() -> void:
	_live.clear()
	_queue.clear()
	for p in _sparks:
		p.emitting = false


func _physics_process(delta: float) -> void:
	var k := 0
	while k < _queue.size():
		_queue[k][2] -= delta
		if _queue[k][2] <= 0.0:
			var item: Array = _queue[k]
			_queue.remove_at(k)
			_blast(item[0], item[1])
		else:
			k += 1
	k = 0
	while k < _live.size():
		_live[k][1] -= delta
		if _live[k][1] <= 0.0:
			_live.remove_at(k)
		else:
			k += 1
	for i in _sparks.size():
		_sparks[i].emitting = i < _live.size()
		if i < _live.size():
			_sparks[i].global_position = _live[i][0]
	if _live.is_empty():
		return
	for player: Node3D in get_tree().get_nodes_in_group("player"):
		if not player.alive:
			continue
		for spot: Array in _live:
			var at: Vector3 = spot[0]
			if Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < SPARK_RADIUS \
					and player.global_position.y < at.y + 2.0:
				player.take_damage(SPARK_DPS * delta)
				player.rumble(at, 80.0)
				break


func _blast(pos: Vector3, power: float) -> void:
	var radius := EXPLOSION_RADIUS * power
	get_tree().call_group("effects", "explosion", pos, radius)
	get_tree().call_group("structures", "damage_sphere", pos, radius, EXPLOSION_FORCE * power)
	get_tree().call_group("player", "explode_at", pos, radius, EXPLOSION_DAMAGE * power)
	get_tree().call_group("player", "add_shake", 0.5)
	get_tree().call_group("structures", "ignite", pos, 2.5)
