extends Node3D
const Prof := preload("res://scripts/core/prof.gd")
## Sliding glass doors in the buildings' front doorways: they slide open when
## anyone (player or bot) comes near and close behind them, and shatter when the
## wall holding them breaks. Every panel is drawn by one MultiMesh (one draw
## call for all doors); each has a kinematic body to bump into. Built for every
## structure's door_spots after a map loads (add_map), freed with clear().
## Spots marked "blast" (the concrete bunkers) get a steel door instead that
## never breaks: LOCK_DELAY seconds into a disaster it slams shut and stays shut
## until the round is over, so whoever is not inside by then is not getting in
## (the manager switches phases).

const Look := preload("res://scripts/world/look.gd")

const MAX_DOORS := 24
const NEAR := 3.4
const SPEED := 3.0
const TICK := 0.15
const LOCK_DELAY := 10.0
const STEEL_COLOR := Color(0.5, 0.52, 0.55)

var _doors: Array[Dictionary] = []
var _multimesh: MultiMesh
var _steel: MultiMesh
var _tick := 0.0
var _locked := false
## Seconds until the bunker doors lock (below 0: not counting).
var _lock_in := -1.0


func _ready() -> void:
	add_to_group("doors")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_multimesh = _batch(Look.surface(Look.GLASS_KEY), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var steel := StandardMaterial3D.new()
	steel.albedo_texture = _steel_texture()
	# Mapped on the unit box (the instance scales it), so each face shows the whole plate.
	steel.uv1_triplanar = true
	steel.uv1_offset = Vector3(0.5, 0.5, 0.5)
	steel.metallic = 0.35
	steel.roughness = 0.55
	_steel = _batch(steel, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


## A ribbed steel plate with a yellow and black hazard band along the bottom.
func _steel_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var c := STEEL_COLOR
			if y >= 50:
				c = Color(0.95, 0.72, 0.08) if posmod(x + y, 12) < 6 else Color(0.08, 0.08, 0.08)
			elif y % 8 == 0 or x < 2 or x > 61 or y < 2:
				c = STEEL_COLOR.darkened(0.35)
			elif y % 8 == 1:
				c = STEEL_COLOR.lightened(0.15)
			image.set_pixel(x, y, c)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _batch(material: Material, shadows: GeometryInstance3D.ShadowCastingSetting) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = MAX_DOORS
	mm.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = shadows
	instance.custom_aabb = AABB(Vector3(-300, -20, -300), Vector3(600, 80, 600))
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(instance)
	return mm


func clear() -> void:
	for door: Dictionary in _doors:
		door.body.queue_free()
	_doors.clear()
	_multimesh.visible_instance_count = 0
	_steel.visible_instance_count = 0
	_locked = false
	_lock_in = -1.0


## Round phases from the manager: "active" (with the disaster's length) starts
## the bunker countdown, any other phase opens them again.
func phase(name: String, duration := 0.0) -> void:
	if not _doors.any(func(door: Dictionary) -> bool: return door.blast):
		return
	if name == "active":
		_lock_in = minf(LOCK_DELAY, duration * 0.35)
		# The HUD translates the card's text as a whole, so the delay is spelled out.
		get_tree().call_group("hud", "alert", "SIĞINAK KAPISI KAPANIYOR",
				"Beton sığınağın çelik kapısı 10 saniye sonra kilitlenecek")
	else:
		_lock_in = -1.0
		_seal(false)


## A new map: a door in every structure's door spots.
func add_map() -> void:
	clear()
	for structure: Node3D in get_tree().get_nodes_in_group("structures"):
		for spot: Dictionary in structure.door_spots:
			if _doors.size() >= MAX_DOORS:
				return
			var basis := structure.global_basis
			var size: Vector3 = spot.size
			var body := AnimatableBody3D.new()
			body.sync_to_physics = true
			body.collision_layer = 2
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			body.add_child(shape)
			# Placed before entering the tree: a synced kinematic body keeps the
			# physics server's transform otherwise. The doors node sits at the origin.
			var closed: Vector3 = structure.global_transform * (spot.center as Vector3)
			body.transform = Transform3D(basis, closed)
			add_child(body)
			var blast: bool = spot.get("blast", false)
			var mm := _steel if blast else _multimesh
			var index := mm.visible_instance_count
			mm.set_instance_custom_data(index, Color(0, 0, 0, 0))
			mm.set_instance_transform(index, Transform3D(basis * Basis.from_scale(size), closed))
			mm.visible_instance_count = index + 1
			_doors.append({"body": body, "closed": closed, "slide": basis * (spot.slide as Vector3) * size.x * 0.92,
					"size": size, "basis": basis, "open": 0.0, "want": 0.0, "neighbors": spot.neighbors, "broken": false,
					"blast": blast, "mm": mm, "index": index, "structure": structure})


func _physics_process(delta: float) -> void:
	var _p := Prof.begin()
	if _doors.is_empty():
		Prof.end("doors", _p)
		return
	if _lock_in > 0.0:
		_lock_in -= delta
		if _lock_in <= 0.0:
			_lock()
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_check()
	for door: Dictionary in _doors:
		if door.broken or door.open == door.want:
			continue
		door.open = move_toward(door.open, door.want, delta * SPEED)
		door.body.global_position = door.closed + door.slide * smoothstep(0.0, 1.0, door.open)
	Prof.end("doors", _p)


func _process(_delta: float) -> void:
	var _p := Prof.begin()
	for k in _doors.size():
		var door: Dictionary = _doors[k]
		if not door.broken and (door.open > 0.0 or door.want > 0.0):
			_draw(k)
	Prof.end("doors", _p)


## The bunker doors slam shut until the round is over.
func _lock() -> void:
	_seal(true)
	_tick = 0.0
	for door: Dictionary in _doors:
		if door.blast:
			get_tree().call_group("sound", "play", "metal", door.closed)
	get_tree().call_group("hud", "alert", "SIĞINAK KAPANDI", "Dışarıda kalan içeri giremez")


## Locked bunkers carry the "sealed" meta: bots outside stop picking them.
func _seal(on: bool) -> void:
	_locked = on
	for door: Dictionary in _doors:
		if door.blast and is_instance_valid(door.structure):
			door.structure.set_meta("sealed", on)


## Who is near each door, and whether its wall still stands.
func _check() -> void:
	var people := get_tree().get_nodes_in_group("player")
	for k in _doors.size():
		var door: Dictionary = _doors[k]
		if door.broken:
			continue
		if door.blast and _locked:
			door.want = 0.0
			continue
		for piece: Variant in door.neighbors:
			if not is_instance_valid(piece) or not piece.freeze or piece.collision_layer == 0:
				_break(k)
				break
		if door.broken:
			continue
		var at: Vector3 = door.closed
		var near := false
		for p: Node3D in people:
			if p.alive and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < NEAR \
					and absf(p.global_position.y - (at.y - door.size.y * 0.5)) < 2.0:
				near = true
				break
		door.want = 1.0 if near else 0.0


func _break(k: int) -> void:
	var door: Dictionary = _doors[k]
	door.broken = true
	var body: AnimatableBody3D = door.body
	body.collision_layer = 0
	get_tree().call_group("debris", "shatter", body.global_transform, door.size, Look.GLASS_KEY, Vector3.ZERO,
			body.global_position - body.global_basis.z, 3.0)
	door.mm.set_instance_transform(door.index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _draw(k: int) -> void:
	var door: Dictionary = _doors[k]
	var body: AnimatableBody3D = door.body
	var xform := body.get_global_transform_interpolated()
	door.mm.set_instance_transform(door.index, Transform3D(xform.basis * Basis.from_scale(door.size), xform.origin))
