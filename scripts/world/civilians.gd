extends Node3D
const Prof := preload("res://scripts/core/prof.gd")
## Hurt civilians to carry out while the disaster rages: when it hits, a few
## lie around the map (some up on roofs), waving and calling for help. Standing
## by one for a moment puts it on the player's shoulders (slower, lower jumps,
## no slides; see player.gd `carrying`); bringing it into the green light at
## the assembly point (the spawn) saves it for points. Whoever is still lying
## there when the disaster ends is lost. The manager switches phases like
## pickups.gd; everything is pooled (a few avatars, one ring, one beam).

const Avatar := preload("res://scripts/player/avatar.gd")
const BotNav := preload("res://scripts/player/bot_nav.gd")
const Maps := preload("res://scripts/world/maps.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Lang := preload("res://scripts/core/lang.gd")

const POOL := 3
const PICK_RADIUS := 1.6
const PICK_TIME := 0.8
const ZONE_RADIUS := 3.2
const POINTS := 80
const TICK := 0.1
## Not too close to the assembly point: carrying one out should be a trip.
const MIN_TRIP := 14.0
const SHIRTS := [Color(0.85, 0.85, 0.8), Color(0.35, 0.45, 0.6), Color(0.6, 0.25, 0.2), Color(0.3, 0.5, 0.3),
		Color(0.75, 0.6, 0.3)]
const CALLS := ["Yardım edin!", "Buradayım!", "Kurtarın beni!", "Yaralıyım!"]

## Where the saved are taken (INF when nobody needs saving).
var zone := Vector3.INF
## Bumped on every change the HUD compass should redraw for.
var version := 0
var saved_round := 0
## [avatar, call bubble, state ("off", "waiting", "carried", "saved"), position, yaw, call timer]
var _people: Array = []
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _tick := 0.0
var _hold := 0.0
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	add_to_group("civilians")
	# After the player has placed its body this frame.
	process_priority = 10
	_rng.randomize()
	for i in POOL:
		var body := Avatar.new()
		body.set_colors(SHIRTS[i % SHIRTS.size()], Avatar.PANTS[(i + 1) % Avatar.PANTS.size()],
				Avatar.SKIN_TONES[(i * 2 + 1) % Avatar.SKIN_TONES.size()])
		body.set_scared(1.0)
		body.visible = false
		body.visibility_range_end = 90.0
		add_child(body)
		var bubble := Label3D.new()
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.fixed_size = true
		bubble.font_size = 40
		bubble.outline_size = 14
		bubble.pixel_size = 0.001
		bubble.modulate = Color(1.0, 0.45, 0.4)
		bubble.outline_modulate = Color(0.1, 0.02, 0.02)
		bubble.no_depth_test = true
		bubble.visibility_range_end = 70.0
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble.visible = false
		add_child(bubble)
		_people.append([body, bubble, "off", Vector3.ZERO, 0.0, 0.0])
	# The assembly point: a green ring on the ground and a beam of light.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.no_depth_test = false
	glow.albedo_color = Color(0.2, 1.0, 0.4, 0.3)
	var ring := TorusMesh.new()
	ring.inner_radius = ZONE_RADIUS - 0.1
	ring.outer_radius = ZONE_RADIUS
	ring.rings = 32
	ring.ring_segments = 6
	ring.material = glow
	_ring = MeshInstance3D.new()
	_ring.mesh = ring
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	var beam_material := glow.duplicate() as StandardMaterial3D
	beam_material.albedo_color = Color(0.2, 1.0, 0.45, 0.18)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.6
	beam.bottom_radius = 0.9
	beam.height = 40.0
	beam.radial_segments = 12
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	beam.material = beam_material
	_beam = MeshInstance3D.new()
	_beam.mesh = beam
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


## "active" (they appear), "results" (the lost are counted, all go), "off".
func phase(name: String) -> void:
	match name:
		"active":
			_spawn_all()
		"results":
			var lost := 0
			for person: Array in _people:
				if person[2] in ["waiting", "carried"]:
					lost += 1
			if lost > 0:
				get_tree().call_group("hud", "add_note", Lang.t("%d yaralı kurtarılamadı") % lost)
			_clear()
		_:
			_clear()


## How many still need carrying out.
func waiting() -> int:
	var n := 0
	for person: Array in _people:
		if person[2] == "waiting":
			n += 1
	return n


## Compass marks: [position, color, letter] for each one waiting and the
## assembly point while anyone needs it.
func marks() -> Array:
	var list: Array = []
	for person: Array in _people:
		if person[2] == "waiting":
			list.append([person[3], Color(1.0, 0.45, 0.4), "+"])
	if zone != Vector3.INF and (waiting() > 0 or _carried() >= 0):
		list.append([zone, Color(0.35, 1.0, 0.45), "T"])
	return list


func _spawn_all() -> void:
	_clear()
	var world := get_parent() as Node3D
	if not BotNav.ready or world == null:
		return
	zone = world.spawn_point
	saved_round = 0
	var size: float = world.map_size if "map_size" in world else 50.0
	var count := 2 if _rng.randf() < 0.6 else 3
	for i in count:
		var at := _spot(size)
		if at == Vector3.INF:
			continue
		var person: Array = _people[i]
		person[2] = "waiting"
		person[3] = at
		person[4] = _rng.randf() * TAU
		person[5] = _rng.randf_range(0.5, 2.5)
		person[0].visible = true
		_lay(person)
	_ring.global_position = zone + Vector3.UP * 0.08
	_ring.visible = true
	_beam.global_position = zone + Vector3.UP * 20.0
	_beam.visible = true
	version += 1


## Somewhere on the ground or up on a roof, a fair walk from the assembly point.
func _spot(size: float) -> Vector3:
	for attempt in 12:
		var at := Vector3.INF
		if _rng.randf() < 0.3 and not Maps.refuges.is_empty():
			var refuge: Dictionary = Maps.refuges.pick_random()
			if is_instance_valid(refuge.structure):
				at = refuge.path[-1]
		if at == Vector3.INF:
			at = BotNav.random_point(Vector3.ZERO, size * 0.42, _rng)
		if Vector2(at.x - zone.x, at.z - zone.z).length() > MIN_TRIP:
			return at
	return Vector3.INF


func _clear() -> void:
	var player := _player()
	if player and player.carrying:
		player.carrying = false
	for person: Array in _people:
		person[2] = "off"
		person[0].visible = false
		person[1].visible = false
	_ring.visible = false
	_beam.visible = false
	zone = Vector3.INF
	_hold = 0.0
	version += 1


func _player() -> Node3D:
	for p: Node3D in get_tree().get_nodes_in_group("player"):
		if not p.is_bot:
			return p
	return null


func _carried() -> int:
	for k in _people.size():
		if _people[k][2] == "carried":
			return k
	return -1


func _physics_process(delta: float) -> void:
	if zone == Vector3.INF:
		return
	var _p := Prof.begin()
	_tick -= delta
	if _tick > 0.0:
		Prof.end("civilians", _p)
		return
	_tick = TICK
	var player := _player()
	var carried := _carried()
	if carried >= 0:
		var person: Array = _people[carried]
		if player == null or not player.alive:
			# Dropped where the carrier fell.
			person[2] = "waiting"
			person[3] = player.global_position if player else person[3]
			_lay(person)
			if player:
				player.carrying = false
			version += 1
		elif Vector2(player.global_position.x - zone.x, player.global_position.z - zone.z).length() < ZONE_RADIUS \
				and absf(player.global_position.y - zone.y) < 3.0:
			_save(player, person)
	elif player and player.alive:
		# Standing by one for a moment lifts it.
		var near := -1
		for k in _people.size():
			var person: Array = _people[k]
			if person[2] == "waiting" and player.global_position.distance_to(person[3]) < PICK_RADIUS:
				near = k
				break
		_hold = _hold + TICK if near >= 0 else 0.0
		if near >= 0 and _hold >= PICK_TIME:
			_hold = 0.0
			_people[near][2] = "carried"
			_people[near][1].visible = false
			player.carrying = true
			get_tree().call_group("sound", "play", "shout", _people[near][3] + Vector3.UP, -6.0, 1.1)
			get_tree().call_group("hud", "add_note", "Yaralıyı sırtladın: yeşil ışığa götür!")
			version += 1
	# Calls for help.
	for person: Array in _people:
		if person[2] != "waiting":
			continue
		person[5] -= TICK
		if person[5] <= 0.0:
			person[5] = _rng.randf_range(4.0, 7.0)
			var bubble: Label3D = person[1]
			bubble.text = Lang.t(CALLS[_rng.randi() % CALLS.size()])
			bubble.visible = true
			get_tree().call_group("sound", "play", "shout", person[3] + Vector3.UP * 0.5, -3.0, _rng.randf_range(0.9, 1.25))
		elif person[5] < 2.0:
			person[1].visible = false
	Prof.end("civilians", _p)


func _save(player: Node3D, person: Array) -> void:
	person[2] = "saved"
	player.carrying = false
	player.bonus_points += POINTS
	saved_round += 1
	Profile.count("civilians")
	# Set down standing in the light, waving.
	person[3] = zone + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
	var body: Avatar = person[0]
	body.global_transform = Transform3D(Basis(Vector3.UP, person[4]), person[3])
	body.set_scared(0.0)
	get_tree().call_group("sound", "play", "coin", null, -2.0, 0.8)
	get_tree().call_group("hud", "toast", Lang.t("Yaralı kurtarıldı! +%d puan") % POINTS, 0)
	version += 1


## Lying on the back where it is, with the call bubble above.
func _lay(person: Array) -> void:
	var body: Avatar = person[0]
	body.set_scared(1.0)
	body.global_transform = Transform3D(Basis(Vector3.UP, person[4]) * Basis(Vector3.RIGHT, PI * 0.5),
			person[3] + Vector3.UP * 0.18)
	var bubble: Label3D = person[1]
	bubble.global_position = person[3] + Vector3.UP * 1.0


func _process(delta: float) -> void:
	if zone == Vector3.INF:
		return
	var _p := Prof.begin()
	_time += delta
	var player := _player()
	for person: Array in _people:
		var body: Avatar = person[0]
		match person[2]:
			"waiting":
				body.animate(delta, 0.0, 1.0)
			"saved":
				body.animate(delta, 0.0, 1.0 if fmod(_time + person[4], 3.0) < 1.5 else 0.0)
			"carried":
				# Over the shoulders (third person only: in first person it would fill the view).
				body.visible = Settings.third_person and player != null
				if body.visible:
					# Follows the player's drawn body (placed every frame; this runs after it).
					var carrier: Transform3D = player.body_transform()
					var turn := carrier.basis * Basis(Vector3.BACK, PI * 0.5)
					var shoulders := carrier.origin + Vector3.UP * 1.55 + carrier.basis * Vector3(0, 0, 0.12)
					body.global_transform = Transform3D(turn, shoulders - turn * Vector3.UP * 0.9)
					body.animate(delta, 0.0, 0.0)
	# The light pulses gently. Up close the beam would fill the view: it shows
	# from afar (or while carrying someone, to find the way back).
	var pulse := 0.75 + 0.25 * sin(_time * 3.0)
	_ring.scale = Vector3(1.0, 0.3, 1.0) * (0.95 + 0.05 * pulse)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var away := Vector2(camera.global_position.x - zone.x, camera.global_position.z - zone.z).length()
		_beam.visible = away > 9.0
		_ring.visible = away > 2.0 or (player != null and player.carrying)
	Prof.end("civilians", _p)
