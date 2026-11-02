extends Node3D
const Prof := preload("res://scripts/core/prof.gd")
## Things to grab during a round: gold coins (round points) all over the
## island, many of them up on roofs and out in the open where the danger is,
## and first-aid kits. A few appear while waiting for the disaster and more keep
## coming while it lasts; whoever walks into one (player or bot) gets it. They
## spin and bob; all of them are two MultiMeshes. The manager switches phases.

const BotNav := preload("res://scripts/player/bot_nav.gd")
const Maps := preload("res://scripts/world/maps.gd")

const COIN_POINTS := 15
const KIT_HEAL := 35.0
const MAX := 12
const LIFETIME := 28.0
const PICK_RADIUS := 1.2
const TICK := 0.1
## Seconds between new ones while a disaster lasts.
const SPAWN_GAP := Vector2(2.0, 3.5)

## [position, kind ("coin"/"kit"), age]
var _items: Array = []
var _coins: MultiMesh
var _kits: MultiMesh
var _spawning := false
var _spawn_timer := 0.0
var _tick := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("pickups")
	_rng.randomize()
	var coin := CylinderMesh.new()
	coin.top_radius = 0.26
	coin.bottom_radius = 0.26
	coin.height = 0.07
	coin.radial_segments = 16
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.2)
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.65, 0.1)
	gold.emission_energy_multiplier = 0.6
	coin.material = gold
	_coins = _batch(coin)
	var kit := BoxMesh.new()
	kit.size = Vector3(0.5, 0.36, 0.3)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.15, 0.15)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.2, 0.15)
	red.emission_energy_multiplier = 0.5
	kit.material = red
	_kits = _batch(kit)


func _batch(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 120, 400))
	add_child(instance)
	return mm


## "wait" (a few to grab before the disaster), "active" (more keep coming),
## "results" / "off" (all gone).
func phase(name: String) -> void:
	match name:
		"wait":
			_items.clear()
			_spawning = false
			for k in 5:
				_spawn("coin")
		"active":
			_spawning = true
			_spawn_timer = 1.0
		_:
			_spawning = false
			_items.clear()
	_redraw()


## The nearest one within reach of pos on about the same level, or INF.
func nearest(pos: Vector3, reach: float) -> Vector3:
	var best := Vector3.INF
	var best_d := reach
	for item: Array in _items:
		var at: Vector3 = item[0]
		if absf(at.y - pos.y) > 1.5:
			continue
		var d := pos.distance_to(at)
		if d < best_d:
			best_d = d
			best = at
	return best


func _spawn(kind: String) -> void:
	if _items.size() >= MAX or not BotNav.ready:
		return
	var at := Vector3.INF
	# Up on a roof (worth the climb), or anywhere on the ground.
	if _rng.randf() < 0.35 and not Maps.refuges.is_empty():
		var refuge: Dictionary = Maps.refuges.pick_random()
		if is_instance_valid(refuge.structure):
			var top: Vector3 = refuge.path[-1]
			at = top + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
			if not _floor_under(at):
				at = top
	if at == Vector3.INF:
		var world := get_parent() as Node3D
		var size: float = world.map_size if "map_size" in world else 50.0
		at = BotNav.random_point(Vector3.ZERO, size * 0.42, _rng)
	_items.append([at + Vector3.UP * 0.9, kind, 0.0])


func _floor_under(p: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 1.0, 1 | 2)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	var _p := Prof.begin()
	if _items.is_empty() and not _spawning:
		Prof.end("pickups", _p)
		return
	if _spawning:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _rng.randf_range(SPAWN_GAP.x, SPAWN_GAP.y)
			_spawn("kit" if _rng.randf() < 0.2 else "coin")
	_tick -= delta
	if _tick > 0.0:
		Prof.end("pickups", _p)
		return
	_tick = TICK
	var k := 0
	while k < _items.size():
		var item: Array = _items[k]
		item[2] += TICK
		var taken := false
		if item[2] > LIFETIME:
			taken = true
		else:
			for p: Node3D in get_tree().get_nodes_in_group("player"):
				if not p.alive:
					continue
				var to: Vector3 = p.global_position + Vector3.UP * 0.9 - item[0]
				if Vector2(to.x, to.z).length() < PICK_RADIUS and absf(to.y) < 1.4:
					_give(p, item)
					taken = true
					break
		if taken:
			_items.remove_at(k)
		else:
			k += 1
	Prof.end("pickups", _p)


func _give(p: Node3D, item: Array) -> void:
	var kind: String = item[1]
	if kind == "coin":
		p.bonus_points += COIN_POINTS
		get_tree().call_group("sound", "play", "coin", item[0], -4.0)
	else:
		get_tree().call_group("sound", "play", "click", item[0], 0.0, 0.6)
	p.collected(kind, COIN_POINTS if kind == "coin" else int(KIT_HEAL))


func _process(delta: float) -> void:
	var _p := Prof.begin()
	if _items.is_empty() and _coins.visible_instance_count == 0 and _kits.visible_instance_count == 0:
		Prof.end("pickups", _p)
		return
	_time += delta
	_redraw()
	Prof.end("pickups", _p)


## Spinning, bobbing, and blinking out in their last seconds.
func _redraw() -> void:
	var coins := 0
	var kits := 0
	for item: Array in _items:
		var age: float = item[2]
		if age > LIFETIME - 4.0 and fmod(_time * 6.0, 1.0) < 0.35:
			continue
		var at: Vector3 = item[0] + Vector3.UP * sin(_time * 2.5 + age) * 0.12
		var spin := Basis(Vector3.UP, _time * 3.0 + age)
		if item[1] == "coin":
			_coins.set_instance_transform(coins, Transform3D(spin * Basis(Vector3.RIGHT, PI * 0.5), at))
			coins += 1
		else:
			_kits.set_instance_transform(kits, Transform3D(spin, at))
			kits += 1
	_coins.visible_instance_count = coins
	_kits.visible_instance_count = kits
