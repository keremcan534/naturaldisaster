extends RefCounted
## More maps, built from the same pieces as maps.gd (its helpers are passed in
## as M, since the two scripts can't preload each other): school, hospital,
## stadium, village, campsite, castle, city centre, airport, funfair, river
## with a bridge, desert town, ski resort, oil rig and a town below a dam. Each
## returns {name, size, spawn} like the maps in maps.gd (the dam map also
## "dam": where its wall stands, which water disasters burst).

const Structure := preload("res://scripts/world/structure.gd")
const Look := preload("res://scripts/world/look.gd")
const WaterZone := preload("res://scripts/world/water_zone.gd")
const Elevator := preload("res://scripts/world/elevator.gd")

const NAMES := ["Okul", "Hastane", "Stadyum", "Köy", "Kamp Alanı", "Kale", "Şehir Merkezi", "Havalimanı",
		"Lunapark", "Nehir ve Köprü", "Çöl Kasabası", "Kayak Merkezi", "Petrol Platformu", "Baraj"]
const COUNT := 14

const WOOD := Color(0.5, 0.36, 0.22)
const DARK_WOOD := Color(0.36, 0.25, 0.16)
const STONE := Color(0.6, 0.58, 0.54)
const STEEL := Color(0.45, 0.47, 0.5)
const WHITE := Color(0.92, 0.92, 0.9)
const SAND := Color(0.82, 0.7, 0.5)
const SNOW := Color(0.92, 0.94, 0.97)
const GLASS := Look.GLASS_KEY


static func build(M: GDScript, index: int, root: Node3D) -> Dictionary:
	match index:
		0:
			return _school(M, root)
		1:
			return _hospital(M, root)
		2:
			return _stadium(M, root)
		3:
			return _village(M, root)
		4:
			return _camp(M, root)
		5:
			return _castle(M, root)
		6:
			return _city(M, root)
		7:
			return _airport(M, root)
		8:
			return _funfair(M, root)
		9:
			return _river(M, root)
		10:
			return _desert(M, root)
		11:
			return _ski(M, root)
		12:
			return _oil_rig(M, root)
		_:
			return _dam(M, root)


# --- Shared bits -------------------------------------------------------------

## A tower of stacked blocks with a wider cap and a ladder up one side to it
## (a refuge for bots). Returns the structure.
static func _tower(M: GDScript, root: Node3D, pos: Vector3, width: float, height: float, colors: Array,
		strength := 2.4, cap := true) -> Structure:
	var tower := Structure.new()
	tower.position = pos
	tower.strength = strength
	var blocks := maxi(int(height / 3.0), 1)
	var block := height / blocks
	for k in blocks:
		tower.add_box(Vector3(0, block * (k + 0.5), 0), Vector3(width, block, width), colors[k % colors.size()])
	var top := height
	if cap:
		tower.add_box(Vector3(0, height + 0.15, 0), Vector3(width + 1.6, 0.3, width + 1.6), Color(0.25, 0.25, 0.27))
		top = height + 0.3
	var ladder_height := top + 1.0
	var rung := tower.add_box(Vector3(width * 0.5 + 0.08, ladder_height * 0.5, 0), Vector3(0.6, ladder_height, 0.12),
			Color(0.75, 0.62, 0.2), Basis(Vector3.UP, PI * 0.5), Look.ladder(ladder_height))
	rung.set_meta("ladder", true)
	root.add_child(tower)
	M._add_ladder_refuge(tower, rung, top)
	var rect: Rect2 = M._rect(pos, Vector2(width + 1.6, width + 1.6))
	M._bare.append(rect)
	M._shades.append(M._rect(pos, Vector2(width, width)))
	return tower


## A squat concrete shelter with a doorway: little gets through its roof (a
## refuge bots run into for things falling from the sky).
static func _bunker(M: GDScript, root: Node3D, pos: Vector3) -> void:
	var b := Structure.new()
	b.position = pos
	b.strength = 4.0
	var concrete := Color(0.5, 0.5, 0.48)
	var w := 6.0
	var d := 5.0
	var h := 2.6
	var t := 0.6
	b.add_box(Vector3(0, h * 0.5, -d * 0.5 + t * 0.5), Vector3(w, h, t), concrete)
	b.add_box(Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), Vector3(t, h, d - t * 2.0), concrete)
	b.add_box(Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), Vector3(t, h, d - t * 2.0), concrete)
	for x: float in [-w * 0.5 + 1.0, w * 0.5 - 1.0]:
		b.add_box(Vector3(x, h * 0.5, d * 0.5 - t * 0.5), Vector3(2.0, h, t), concrete)
	b.add_box(Vector3(0, h + 0.3, 0), Vector3(w, 0.6, d), concrete)
	b.add_box(Vector3(0, h + 0.75, d * 0.5 - 0.2), Vector3(1.6, 0.3, 0.1), Color(1.0, 0.75, 0.1), Basis.IDENTITY,
			Look.glow(Vector3(1.6, 0.3, 0.1), Color(1.0, 0.75, 0.1), 1.5))
	root.add_child(b)
	M.refuges.append({"path": [pos + Vector3(0, 0, d * 0.5 + 1.5), pos + Vector3(0, 0, -0.5)], "height": 0.0,
			"structure": b, "stairs": true})
	M._bare.append(M._rect(pos, Vector2(w + 1.0, d + 1.0)))
	M._shades.append(M._rect(pos, Vector2(w, d)))


static func _pole_light(s: Structure, pos: Vector3, height: float, color: Color) -> void:
	s.add_box(pos + Vector3(0, height * 0.5, 0), Vector3(0.3, height, 0.3), STEEL, Basis.IDENTITY,
			Look.cylinder(0.15, 0.12, height, STEEL))
	var head := Vector3(1.6, 0.5, 0.6)
	s.add_box(pos + Vector3(0, height + head.y * 0.5, 0), head, Color.WHITE, Basis.IDENTITY, Look.glow(head, color, 2.0))


## A sloped box between two points (stands, roofs, ramps): a rotated piece.
static func _beam(s: Structure, a: Vector3, b: Vector3, thickness: Vector2, color: Color) -> void:
	var along := b - a
	var basis := Basis.looking_at(along.normalized(), Vector3.UP if absf(along.normalized().y) < 0.99 else Vector3.RIGHT)
	s.add_box((a + b) * 0.5, Vector3(thickness.x, thickness.y, along.length()), color, basis)


# --- Maps --------------------------------------------------------------------

static func _school(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 8), Vector2(40, 12), M.PLAZA_COLOR)
	M._decal(root, Vector3(18, 0, 22), Vector2(14, 9), Color(0.75, 0.38, 0.2))
	M._road(root, Vector3(0, 0, 28), size, true)
	M._building(root, Vector3(-4, 0, -10), Vector2i(10, 4), 3, Color(0.86, 0.72, 0.55), 1.6, true, true)
	M._building(root, Vector3(18, 0, -8), Vector2i(6, 5), 2, Color(0.62, 0.68, 0.76), 1.3)
	var props: Structure = M._props()
	# Flagpole with a red flag, two basketball hoops on the court.
	props.add_box(Vector3(-2, 5.0, 4), Vector3(0.2, 10.0, 0.2), STEEL)
	props.add_box(Vector3(-1.2, 9.0, 4), Vector3(1.6, 1.0, 0.05), Color(0.85, 0.1, 0.1))
	for x: float in [12.0, 24.0]:
		var face := 1.0 if x < 18.0 else -1.0
		props.add_box(Vector3(x, 1.7, 22), Vector3(0.2, 3.4, 0.2), STEEL)
		props.add_box(Vector3(x + face * 0.15, 3.3, 22), Vector3(0.1, 1.0, 1.6), WHITE)
	M._slide(props, Vector3(-22, 0, 12))
	M._trampoline(props, Vector3(-16, 0, 20))
	M._fence(props, Rect2(-30, -24, 60, 48), 4.0)
	for p: Vector3 in [Vector3(-26, 0, -20), Vector3(26, 0, -20), Vector3(-26, 0, 18)]:
		M._tree(props, p)
	root.add_child(props)
	return {"name": NAMES[0], "size": size, "spawn": Vector3(0, 0.5, 14)}


static func _hospital(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 14), Vector2(36, 14), M.PLAZA_COLOR)
	M._road(root, Vector3(0, 0, 26), size, true)
	var tower: Structure = M._building(root, Vector3(0, 0, -8), Vector2i(6, 6), 7, WHITE, 2.3, true, true, true)
	M._building(root, Vector3(-18, 0, -6), Vector2i(4, 4), 2, Color(0.8, 0.86, 0.9), 1.2)
	var props: Structure = M._props()
	# A red cross over the entrance.
	var red := Color(0.9, 0.1, 0.1)
	props.add_box(Vector3(0, 0.6, 5), Vector3(0.4, 1.2, 0.4), STEEL)
	props.add_box(Vector3(0, 2.0, 5), Vector3(0.5, 1.6, 0.2), red, Basis.IDENTITY, Look.glow(Vector3(0.5, 1.6, 0.2), red, 1.8))
	props.add_box(Vector3(0, 2.0, 5.11), Vector3(1.6, 0.5, 0.2), red, Basis.IDENTITY, Look.glow(Vector3(1.6, 0.5, 0.2), red, 1.8))
	for k in 3:
		M._car(props, Vector3(-22 + k * 5, 0, 12), false, WHITE)
	for p: Vector3 in [Vector3(-26, 0, 20), Vector3(26, 0, 20), Vector3(24, 0, -22)]:
		M._tree(props, p)
	root.add_child(props)
	# A glass lift up the right side of the tower.
	_elevator(root, Vector3(6.0 + 1.4, 0, -8), tower.roof_height)
	return {"name": NAMES[1], "size": size, "spawn": Vector3(0, 0.5, 18)}


static func _elevator(root: Node3D, pos: Vector3, top: float) -> void:
	var lift := Elevator.new()
	lift.bottom = 0.0
	lift.top = top
	lift.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.3, 2.2)
	shape.shape = box
	shape.position.y = -0.15
	lift.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(2.2, 0.3, 2.2)
	plate.material = Look.surface(STEEL)
	floor_mesh.mesh = plate
	floor_mesh.position.y = -0.15
	lift.add_child(floor_mesh)
	var cage := MeshInstance3D.new()
	var glass := BoxMesh.new()
	glass.size = Vector3(2.2, 2.4, 2.2)
	glass.material = Look.shard()
	cage.mesh = glass
	cage.position.y = 1.2
	lift.add_child(cage)
	root.add_child(lift)


static func _stadium(M: GDScript, root: Node3D) -> Dictionary:
	var size := 80.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 0), Vector2(46, 28), Color(0.3, 0.55, 0.22))
	for x: float in [-23.0, 0.0, 23.0]:
		M._decal(root, Vector3(x, 0.002, 0), Vector2(0.3, 28), WHITE)
	for z: float in [-14.0, 14.0]:
		M._decal(root, Vector3(0, 0.002, z), Vector2(46, 0.3), WHITE)
	# Stands along both long sides: stepped tiers with a ramp up behind.
	for side: float in [-1.0, 1.0]:
		var stand := Structure.new()
		stand.strength = 1.5
		for tier in 6:
			var z := side * (18.0 + tier * 1.2)
			stand.add_box(Vector3(0, 0.4 + tier * 0.8, z), Vector3(40, 0.8 + tier * 1.6, 1.2), Color(0.6, 0.6, 0.62))
			stand.add_box(Vector3(0, 0.8 + tier * 1.6 + 0.2, z), Vector3(40, 0.4, 1.0),
					[Color(0.85, 0.15, 0.15), Color(0.95, 0.95, 0.95)][tier % 2])
		root.add_child(stand)
		M._bare.append(Rect2(-21, (18.0 if side > 0 else -25.8), 42, 7.8))
		M._shades.append(Rect2(-20, (18.0 if side > 0 else -25.0), 40, 7.0))
	# Floodlights at the corners (ladders up), goals, a scoreboard.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_tower(M, root, Vector3(corner.x * 30, 0, corner.y * 27), 1.2, 21.0, [STEEL], 2.0)
	var props: Structure = M._props()
	for x: float in [-23.0, 23.0]:
		props.add_box(Vector3(x, 1.2, -3.0), Vector3(0.15, 2.4, 0.15), WHITE)
		props.add_box(Vector3(x, 1.2, 3.0), Vector3(0.15, 2.4, 0.15), WHITE)
		props.add_box(Vector3(x, 2.47, 0), Vector3(0.15, 0.15, 6.15), WHITE)
	props.add_box(Vector3(-36, 3.0, 0), Vector3(0.5, 6.0, 0.5), STEEL)
	props.add_box(Vector3(-36, 7.2, 0), Vector3(0.5, 2.4, 7.0), Color(0.1, 0.1, 0.12), Basis.IDENTITY,
			Look.glow(Vector3(0.5, 2.4, 7.0), Color(1.0, 0.7, 0.2), 0.8))
	root.add_child(props)
	return {"name": NAMES[2], "size": size, "spawn": Vector3(0, 0.5, 8)}


static func _village(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 0), Vector2(18, 18), M.PATH_COLOR)
	var houses := [[Vector3(-16, 0, -16), Vector2i(4, 3), 2], [Vector3(0, 0, -20), Vector2i(4, 4), 1],
			[Vector3(16, 0, -16), Vector2i(4, 3), 2], [Vector3(-18, 0, 8), Vector2i(4, 4), 1], [Vector3(-6, 0, 20), Vector2i(4, 3), 2]]
	var colors := [Color(0.62, 0.45, 0.3), Color(0.85, 0.8, 0.7), Color(0.55, 0.4, 0.28), Color(0.9, 0.85, 0.75), Color(0.6, 0.5, 0.38)]
	for k in houses.size():
		M._building(root, houses[k][0], houses[k][1], houses[k][2], colors[k], 0.7, k == 1)
	# A big red barn with hay bales around it.
	M._building(root, Vector3(18, 0, 10), Vector2i(6, 5), 2, Color(0.7, 0.18, 0.12), 0.9)
	var props: Structure = M._props()
	var hay := Color(0.85, 0.72, 0.3)
	for p: Vector3 in [Vector3(10, 0, 20), Vector3(11.4, 0, 20), Vector3(10.7, 1.2, 20), Vector3(26, 0, 20), Vector3(27.4, 0, 21)]:
		props.add_box(p + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), hay)
	# The well in the square.
	props.add_box(Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 1.8), STONE)
	for x: float in [-0.8, 0.8]:
		props.add_box(Vector3(x, 1.75, 0), Vector3(0.15, 1.5, 0.15), DARK_WOOD)
	props.add_box(Vector3(0, 2.6, 0), Vector3(2.2, 0.2, 1.4), Color(0.5, 0.2, 0.15))
	for p: Vector3 in [Vector3(-26, 0, -26), Vector3(26, 0, -26), Vector3(-26, 0, 24), Vector3(6, 0, 26), Vector3(26, 0, 0)]:
		M._tree(props, p)
	M._fence(props, Rect2(-8, -8, 16, 16), 3.0)
	root.add_child(props)
	# An old stone mill tower with a ladder up.
	_tower(M, root, Vector3(-24, 0, -4), 3.0, 9.0, [STONE, Color(0.55, 0.53, 0.5)], 1.8, false)
	return {"name": NAMES[3], "size": size, "spawn": Vector3(4, 0.5, 4)}


static func _camp(M: GDScript, root: Node3D) -> Dictionary:
	var size := 60.0
	M._ground(root, size, M.GRASS_COLOR)
	M._pool(root, Vector3(-12, 0, -12), Vector2(18, 12))
	M._building(root, Vector3(14, 0, -14), Vector2i(4, 3), 1, WOOD, 0.8)
	var props: Structure = M._props()
	var tents := [Color(0.9, 0.45, 0.1), Color(0.2, 0.55, 0.3), Color(0.2, 0.4, 0.8), Color(0.85, 0.75, 0.2)]
	for k in 4:
		var c := Vector3(-14 + k * 7, 0, 12)
		var cloth: Color = tents[k]
		props.add_box(c + Vector3(-0.75, 0.75, 0), Vector3(0.1, 1.9, 2.6), cloth, Basis(Vector3.BACK, -0.68))
		props.add_box(c + Vector3(0.75, 0.75, 0), Vector3(0.1, 1.9, 2.6), cloth, Basis(Vector3.BACK, 0.68))
		M._bare.append(M._rect(c, Vector2(3, 3)))
	# Two caravans, a campfire ring with logs, a canoe by the water.
	for k in 2:
		var c := Vector3(16, 0, 6 + k * 8)
		props.add_box(c + Vector3(0, 0.3, 0), Vector3(0.4, 0.6, 0.4), Color(0.1, 0.1, 0.1))
		props.add_box(c + Vector3(0, 1.9, 0), Vector3(6.0, 2.6, 2.4), WHITE)
		props.add_box(c + Vector3(0, 2.3, 1.21), Vector3(4.0, 0.7, 0.05), GLASS)
		M._bare.append(M._rect(c, Vector2(6.5, 3)))
		M._shades.append(M._rect(c, Vector2(6, 2.4)))
	for k in 8:
		var a := k * TAU / 8.0
		props.add_box(Vector3(cos(a) * 1.1, 0.15, 20 + sin(a) * 1.1), Vector3(0.35, 0.3, 0.35), STONE)
	props.add_box(Vector3(-2.5, 0.2, 20), Vector3(2.0, 0.4, 0.45), DARK_WOOD)
	props.add_box(Vector3(2.5, 0.2, 20), Vector3(2.0, 0.4, 0.45), DARK_WOOD)
	props.add_box(Vector3(-2, 0.25, -12), Vector3(4.0, 0.5, 0.9), Color(0.8, 0.25, 0.15))
	for p: Vector3 in [Vector3(-24, 0, 4), Vector3(-22, 0, 22), Vector3(4, 0, -24), Vector3(24, 0, 24), Vector3(24, 0, -4),
			Vector3(-4, 0, 4), Vector3(8, 0, 24)]:
		M._tree(props, p)
	root.add_child(props)
	return {"name": NAMES[4], "size": size, "spawn": Vector3(0, 0.5, 16)}


static func _castle(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 0), Vector2(36, 36), M.PATH_COLOR)
	var walls := Structure.new()
	walls.strength = 2.6
	var half := 19.0
	var height := 7.0
	var thick := 1.6
	# Four walls of 2 m blocks, a gate gap in the front one, merlons on top.
	for side in 4:
		var along := Vector3.RIGHT if side % 2 == 0 else Vector3.BACK
		var normal := Vector3.BACK if side == 0 else (Vector3.FORWARD if side == 1 else (Vector3.RIGHT if side == 2 else Vector3.LEFT))
		var center := normal * half
		for k in 18:
			var t := -17.0 + k * 2.0
			if side == 0 and absf(t) < 2.5:
				continue
			var at := center + along * t
			var block := Vector3(2.0, height, thick) if side % 2 == 0 else Vector3(thick, height, 2.0)
			walls.add_box(at + Vector3.UP * height * 0.5, block, STONE)
			if k % 2 == 0:
				var merlon := Vector3(1.0, 0.8, thick * 0.5) if side % 2 == 0 else Vector3(thick * 0.5, 0.8, 1.0)
				walls.add_box(at + Vector3.UP * (height + 0.4) + normal * thick * 0.25, merlon, STONE)
	# A ramp up to the wall walk inside the front wall.
	walls.add_incline(Vector3(-15, 0, 16.6), Vector3(-6, height, 16.6), 2.4, 0.4, Color(0.55, 0.53, 0.5))
	root.add_child(walls)
	M._bare.append(Rect2(-21, -21, 42, 42))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_tower(M, root, Vector3(corner.x * half, 0, corner.y * half), 4.0, 12.0, [STONE, Color(0.55, 0.53, 0.5)], 2.6)
	M._building(root, Vector3(0, 0, -6), Vector2i(5, 5), 4, Color(0.62, 0.6, 0.56), 2.8, true)
	var props: Structure = M._props()
	for p: Vector3 in [Vector3(-26, 0, 26), Vector3(26, 0, 26), Vector3(-26, 0, -26), Vector3(26, 0, -26)]:
		M._tree(props, p)
	root.add_child(props)
	return {"name": NAMES[5], "size": size, "spawn": Vector3(0, 0.5, 12)}


static func _city(M: GDScript, root: Node3D) -> Dictionary:
	var size := 76.0
	M._ground(root, size, M.PLAZA_COLOR)
	M._road(root, Vector3(0, 0, 0), size, false)
	M._road(root, Vector3(0, 0.003, 0), size, true)
	M._building(root, Vector3(-19, 0, -19), Vector2i(5, 5), 9, Color(0.55, 0.62, 0.7), 2.6, false, true)
	var office: Structure = M._building(root, Vector3(19, 0, -19), Vector2i(4, 4), 7, Color(0.75, 0.72, 0.68), 2.3, true, true)
	M._building(root, Vector3(-19, 0, 19), Vector2i(5, 4), 6, Color(0.8, 0.6, 0.5), 2.0, true)
	_elevator(root, Vector3(19 + 4.0 + 1.4, 0, -19), office.roof_height)
	_gas_station(M, root, Vector3(19, 0, 17))
	_bunker(M, root, Vector3(-28, 0, 4))
	var props: Structure = M._props()
	# Traffic lights at the crossing, a bus stop, the metro entrance.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
		var p := Vector3(corner.x * 5.2, 0, corner.y * 5.2)
		props.add_box(p + Vector3(0, 2.0, 0), Vector3(0.15, 4.0, 0.15), Color(0.15, 0.15, 0.17))
		var lights := [Color(1, 0.15, 0.1), Color(1, 0.8, 0.1), Color(0.2, 1, 0.3)]
		for k in 3:
			var lamp := Vector3(0.28, 0.28, 0.28)
			props.add_box(p + Vector3(0, 4.14 + (2 - k) * 0.28, 0), lamp, lights[k], Basis.IDENTITY, Look.glow(lamp, lights[k], 1.4))
	props.add_box(Vector3(-8, 1.2, 8), Vector3(0.12, 2.4, 0.12), STEEL)
	props.add_box(Vector3(-4, 1.2, 8), Vector3(0.12, 2.4, 0.12), STEEL)
	props.add_box(Vector3(-6, 1.2, 8.5), Vector3(4.0, 2.4, 0.08), GLASS)
	props.add_box(Vector3(-6, 2.5, 8.2), Vector3(4.4, 0.2, 1.6), Color(0.3, 0.32, 0.35))
	var blue := Color(0.15, 0.35, 0.9)
	props.add_box(Vector3(8, 1.3, -8), Vector3(3.0, 2.6, 0.3), STONE)
	props.add_box(Vector3(8, 3.0, -8), Vector3(1.0, 0.8, 0.3), blue, Basis.IDENTITY, Look.glow(Vector3(1.0, 0.8, 0.3), blue, 1.8))
	for k in 3:
		M._car(props, Vector3(-30 + k * 8, 0, -2.5), true, M.CAR_COLORS[k])
	root.add_child(props)
	return {"name": NAMES[6], "size": size, "spawn": Vector3(-6, 0.5, 4)}


## A filling station: canopy on columns over three fuel pumps (they explode
## when knocked over), a little shop, and the tank vents.
static func _gas_station(M: GDScript, root: Node3D, pos: Vector3) -> void:
	var s := Structure.new()
	s.position = pos
	s.strength = 1.4
	for x: float in [-4.0, 4.0]:
		for z: float in [-2.5, 2.5]:
			s.add_box(Vector3(x, 2.25, z), Vector3(0.4, 4.5, 0.4), WHITE)
	s.add_box(Vector3(0, 4.7, 0), Vector3(10.0, 0.4, 6.0), Color(0.85, 0.15, 0.12))
	var red := Color(0.8, 0.1, 0.1)
	for x: float in [-2.5, 0.0, 2.5]:
		var pump := s.add_box(Vector3(x, 0.8, 0), Vector3(0.7, 1.6, 0.45), red)
		pump.set_meta("explosive", true)
	for x: float in [-5.0, 5.0]:
		var vent := s.add_box(Vector3(x, 0.5, 4.5), Vector3(0.6, 1.0, 0.6), Color(0.3, 0.3, 0.3), Basis.IDENTITY,
				Look.cylinder(0.3, 0.3, 1.0, Color(0.3, 0.3, 0.3)))
		vent.set_meta("explosive", true)
	root.add_child(s)
	M._building(root, pos + Vector3(0, 0, -8), Vector2i(3, 3), 1, Color(0.9, 0.88, 0.8), 1.0)
	M._bare.append(M._rect(pos, Vector2(11, 11)))
	M._shades.append(M._rect(pos, Vector2(10, 6)))


static func _airport(M: GDScript, root: Node3D) -> Dictionary:
	var size := 80.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 8), Vector2(76, 12), M.ROAD_COLOR)
	for k in 12:
		M._decal(root, Vector3(-33 + k * 6, 0.003, 8), Vector2(3.0, 0.3), WHITE)
	M._decal(root, Vector3(0, 0, -10), Vector2(50, 14), M.PLAZA_COLOR)
	M._building(root, Vector3(-14, 0, -24), Vector2i(9, 4), 2, Color(0.75, 0.8, 0.85), 1.6, false, true)
	M._building(root, Vector3(20, 0, -24), Vector2i(8, 6), 2, Color(0.6, 0.62, 0.65), 1.3)
	_tower(M, root, Vector3(30, 0, 22), 3.0, 18.0, [WHITE, Color(0.85, 0.85, 0.85)], 2.4)
	_airplane(M, root, Vector3(-4, 0, -10))
	_bunker(M, root, Vector3(-32, 0, 22))
	var props: Structure = M._props()
	for k in 4:
		props.add_box(Vector3(6 + k * 3, 0.5, -16), Vector3(2.0, 1.0, 1.2), Color(0.9, 0.7, 0.15))
	root.add_child(props)
	return {"name": NAMES[7], "size": size, "spawn": Vector3(0, 0.5, 20)}


## A passenger jet parked on the apron: gear, fuselage with windows, wings and
## tail; breakable like any structure.
static func _airplane(M: GDScript, root: Node3D, pos: Vector3) -> void:
	var plane := Structure.new()
	plane.position = pos
	plane.strength = 1.6
	for g: Vector3 in [Vector3(-7, 0.6, 0), Vector3(3, 0.6, -2.2), Vector3(3, 0.6, 2.2)]:
		plane.add_box(g, Vector3(0.5, 1.2, 0.5), Color(0.2, 0.2, 0.22))
	plane.add_box(Vector3(0, 2.7, 0), Vector3(24.0, 3.0, 3.2), WHITE)
	plane.add_box(Vector3(12.8, 2.7, 0), Vector3(1.6, 2.4, 2.6), WHITE)
	plane.add_box(Vector3(13.2, 3.2, 0), Vector3(0.8, 0.8, 2.2), GLASS)
	for z: float in [-1.62, 1.62]:
		plane.add_box(Vector3(0, 3.2, z), Vector3(18.0, 0.5, 0.05), GLASS)
	plane.add_box(Vector3(1.0, 2.5, 0), Vector3(5.0, 0.4, 26.0), Color(0.85, 0.85, 0.88))
	plane.add_box(Vector3(-10.5, 6.0, 0), Vector3(3.0, 3.6, 0.4), Color(0.15, 0.3, 0.8))
	plane.add_box(Vector3(-10.5, 4.35, 0), Vector3(2.6, 0.3, 8.0), Color(0.85, 0.85, 0.88))
	root.add_child(plane)
	M._bare.append(M._rect(pos, Vector2(28, 27)))
	M._shades.append(M._rect(pos, Vector2(24, 3.2)))


static func _funfair(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, M.GRASS_COLOR)
	M._decal(root, Vector3(0, 0, 4), Vector2(44, 30), M.PLAZA_COLOR)
	_ferris_wheel(M, root, Vector3(-14, 0, -12))
	_coaster(M, root, Vector3(10, 0, -14))
	var props: Structure = M._props()
	# Bumper car rink and a carousel.
	var rink := Rect2(4, 6, 14, 10)
	M._fence(props, rink, 2.0)
	var bumper := [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.95), Color(0.95, 0.8, 0.15), Color(0.3, 0.8, 0.35)]
	for k in 4:
		props.add_box(Vector3(7 + k * 3, 0.4, 11 + (k % 2) * 2.0), Vector3(1.6, 0.8, 1.1), bumper[k])
	var base := Color(0.85, 0.2, 0.5)
	props.add_box(Vector3(-12, 0.3, 10), Vector3(7, 0.6, 7), base, Basis.IDENTITY, Look.cylinder(3.5, 3.5, 0.6, base))
	props.add_box(Vector3(-12, 2.2, 10), Vector3(0.5, 3.2, 0.5), Color(0.9, 0.85, 0.3))
	props.add_box(Vector3(-12, 4.1, 10), Vector3(7.4, 0.6, 7.4), Color(0.95, 0.9, 0.6), Basis.IDENTITY,
			Look.cylinder(3.7, 0.6, 0.6, Color(0.95, 0.9, 0.6)))
	for k in 6:
		var a := k * TAU / 6.0
		props.add_box(Vector3(-12 + cos(a) * 2.6, 1.2, 10 + sin(a) * 2.6), Vector3(0.4, 1.2, 1.1), bumper[k % 4])
	M._bare.append(Rect2(-16, 6, 8, 8))
	M._shades.append(Rect2(-15.5, 6.5, 7, 7))
	root.add_child(props)
	return {"name": NAMES[8], "size": size, "spawn": Vector3(0, 0.5, 18)}


## A big wheel on two A-frames: spokes, a rim of short beams and cabins.
static func _ferris_wheel(M: GDScript, root: Node3D, pos: Vector3) -> void:
	var wheel := Structure.new()
	wheel.position = pos
	wheel.strength = 1.4
	wheel.span_limit = 14
	var hub := Vector3(0, 13.0, 0)
	var radius := 10.0
	for z: float in [-2.0, 2.0]:
		for x: float in [-5.0, 5.0]:
			_beam(wheel, Vector3(x, 0, z), hub + Vector3(0, 0, z), Vector2(0.45, 0.45), WHITE)
	wheel.add_box(hub, Vector3(0.7, 0.7, 4.6), STEEL)
	var red := Color(0.9, 0.2, 0.25)
	for z: float in [-1.6, 1.6]:
		for k in 8:
			var a := k * TAU / 8.0
			var tip := hub + Vector3(cos(a) * radius, sin(a) * radius, z)
			_beam(wheel, hub + Vector3(0, 0, z), tip, Vector2(0.25, 0.25), red)
		for k in 16:
			var a0 := k * TAU / 16.0
			var a1 := (k + 1) * TAU / 16.0
			_beam(wheel, hub + Vector3(cos(a0) * radius, sin(a0) * radius, z), hub + Vector3(cos(a1) * radius, sin(a1) * radius, z),
					Vector2(0.3, 0.3), red)
	var cabins := [Color(0.2, 0.55, 0.95), Color(0.95, 0.8, 0.15), Color(0.3, 0.8, 0.35), Color(0.95, 0.5, 0.15)]
	for k in 8:
		var a := k * TAU / 8.0 + PI / 8.0
		# Cabins hang just under the rim and span both wheels.
		wheel.add_box(hub + Vector3(cos(a) * radius, sin(a) * radius - 0.75, 0), Vector3(1.6, 1.6, 3.4), cabins[k % 4])
	root.add_child(wheel)
	M._bare.append(M._rect(pos, Vector2(24, 8)))
	M._shades.append(M._rect(pos, Vector2(12, 4.6)))


## A rollercoaster loop of track on posts, rising and dipping around a rectangle.
static func _coaster(M: GDScript, root: Node3D, pos: Vector3) -> void:
	var c := Structure.new()
	c.position = pos
	c.strength = 1.3
	c.span_limit = 6
	var points: Array[Vector3] = []
	var w := 9.0
	var d := 6.0
	var steps := 20
	for k in steps:
		var t := float(k) / steps * TAU
		var x := cos(t) * w
		var z := sin(t) * d
		var h := 3.0 + 3.5 * (0.5 + 0.5 * sin(t * 2.0 + 0.6))
		points.append(Vector3(x, h, z))
	for k in steps:
		var a := points[k]
		var b := points[(k + 1) % steps]
		c.add_box(Vector3(a.x, a.y * 0.5, a.z), Vector3(0.35, a.y, 0.35), WHITE)
		_beam(c, a + Vector3.UP * 0.2, b + Vector3.UP * 0.2, Vector2(1.4, 0.25), Color(0.15, 0.4, 0.85))
	root.add_child(c)
	M._bare.append(M._rect(pos, Vector2(w * 2.0 + 2.0, d * 2.0 + 2.0)))


## A river runs across the island, crossed by a suspension bridge; you can swim
## in it. The ground is two banks with a channel between.
static func _river(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	var half := size * 0.5
	var bank := 7.0
	var ground := StaticBody3D.new()
	ground.add_to_group("ground")
	for side: float in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size, 2.0, half - bank)
		shape.shape = box
		shape.position = Vector3(0, -1.0, side * (half + bank) * 0.5)
		ground.add_child(shape)
	var bed := CollisionShape3D.new()
	var bed_box := BoxShape3D.new()
	bed_box.size = Vector3(size, 2.0, bank * 2.0)
	bed.shape = bed_box
	bed.position = Vector3(0, -4.0, 0)
	ground.add_child(bed)
	root.add_child(ground)
	for side: float in [-1.0, 1.0]:
		var top := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(size, half - bank)
		plane.material = Look.ground(M.GRASS_COLOR)
		top.mesh = plane
		top.position = Vector3(0, 0, side * (half + bank) * 0.5)
		root.add_child(top)
		M._grass_areas.append(Rect2(-half, (bank if side > 0 else -half), size, half - bank))
		var cliff := MeshInstance3D.new()
		var rock := BoxMesh.new()
		rock.size = Vector3(size, M.CLIFF_DEPTH, half - bank)
		rock.material = Look.cliff()
		cliff.mesh = rock
		cliff.position = Vector3(0, -M.CLIFF_DEPTH * 0.5 - 0.03, side * (half + bank) * 0.5)
		root.add_child(cliff)
	var water := MeshInstance3D.new()
	var surface := PlaneMesh.new()
	surface.size = Vector2(size + 20.0, bank * 2.0)
	surface.material = Look.water()
	water.mesh = surface
	water.position = Vector3(0, -0.6, 0)
	root.add_child(water)
	var zone := WaterZone.new()
	zone.rects = [Rect2(-half - 10.0, -bank, size + 20.0, bank * 2.0)]
	zone.current = Vector3(2.0, 0, 0)
	root.add_child(zone)
	M._bare.append(Rect2(-half, -bank, size, bank * 2.0))
	# The suspension bridge: deck on piers, towers, hanging cables.
	var bridge := Structure.new()
	bridge.strength = 1.6
	for z: float in [-8.0, 8.0]:
		bridge.add_box(Vector3(0, 0.15, z), Vector3(4.0, 0.3, 2.0), STONE)
	for k in 7:
		var z := -6.0 + k * 2.0
		bridge.add_box(Vector3(0, 0.15, z), Vector3(4.0, 0.3, 2.0), WOOD)
		if k % 2 == 1:
			bridge.add_box(Vector3(0, -2.2, z), Vector3(0.6, 4.4, 0.6), STONE)
	for z: float in [-8.0, 8.0]:
		for x: float in [-1.8, 1.8]:
			bridge.add_box(Vector3(x, 3.3, z), Vector3(0.4, 6.0, 0.4), Color(0.75, 0.2, 0.15))
	root.add_child(bridge)
	M._bare.append(Rect2(-2.5, -10, 5, 20))
	M._building(root, Vector3(-16, 0, -20), Vector2i(4, 4), 3, Color(0.82, 0.78, 0.7), 1.0, true)
	M._building(root, Vector3(16, 0, 20), Vector2i(5, 4), 2, Color(0.7, 0.62, 0.55), 0.9)
	var props: Structure = M._props()
	for p: Vector3 in [Vector3(-26, 0, 14), Vector3(26, 0, -14), Vector3(10, 0, -24), Vector3(-10, 0, 24)]:
		M._tree(props, p)
	root.add_child(props)
	return {"name": NAMES[9], "size": size, "spawn": Vector3(0, 0.5, 14)}


static func _desert(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, SAND)
	var adobe := [Color(0.8, 0.62, 0.42), Color(0.86, 0.72, 0.52), Color(0.74, 0.55, 0.38)]
	var spots := [Vector3(-18, 0, -16), Vector3(0, 0, -20), Vector3(18, 0, -14), Vector3(-20, 0, 10), Vector3(16, 0, 12)]
	for k in spots.size():
		M._building(root, spots[k], Vector2i(4, 3), 1 + (k % 2), adobe[k % 3], 0.8, k == 2)
	_water_tower(M, root, Vector3(0, 0, 8))
	var props: Structure = M._props()
	var cactus := Color(0.25, 0.5, 0.25)
	for p: Vector3 in [Vector3(-26, 0, -26), Vector3(24, 0, -24), Vector3(-8, 0, 22), Vector3(26, 0, 26), Vector3(-26, 0, 20)]:
		props.add_box(p + Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6), cactus)
		props.add_box(p + Vector3(0.6, 1.8, 0), Vector3(0.6, 0.35, 0.35), cactus)
		props.add_box(p + Vector3(0.75, 2.3, 0), Vector3(0.3, 0.9, 0.3), cactus)
	M._car(props, Vector3(8, 0, 22), true, Color(0.75, 0.45, 0.2))
	root.add_child(props)
	return {"name": NAMES[10], "size": size, "spawn": Vector3(0, 0.5, 20)}


## Four legs, a tank on top, a ladder to the tank's roof.
static func _water_tower(M: GDScript, root: Node3D, pos: Vector3) -> void:
	var t := Structure.new()
	t.position = pos
	t.strength = 2.0
	for x: float in [-2.0, 2.0]:
		for z: float in [-2.0, 2.0]:
			t.add_box(Vector3(x, 6.0, z), Vector3(0.5, 12.0, 0.5), Color(0.4, 0.3, 0.2))
	t.add_box(Vector3(0, 14.0, 0), Vector3(5.5, 4.0, 5.5), Color(0.55, 0.62, 0.68), Basis.IDENTITY,
			Look.cylinder(2.75, 2.75, 4.0, Color(0.55, 0.62, 0.68)))
	t.add_box(Vector3(0, 16.15, 0), Vector3(5.6, 0.3, 5.6), Color(0.45, 0.5, 0.55))
	var height := 17.3
	var rung := t.add_box(Vector3(2.0, height * 0.5, 2.0 + 0.35), Vector3(0.6, height, 0.12), Color(0.75, 0.62, 0.2),
			Basis.IDENTITY, Look.ladder(height))
	rung.set_meta("ladder", true)
	root.add_child(t)
	M._add_ladder_refuge(t, rung, 16.3)
	M._bare.append(M._rect(pos, Vector2(6, 6)))
	M._shades.append(M._rect(pos, Vector2(5, 5)))


static func _ski(M: GDScript, root: Node3D) -> Dictionary:
	var size := 64.0
	M._ground(root, size, SNOW)
	M._building(root, Vector3(0, 0, -16), Vector2i(6, 5), 3, Color(0.55, 0.38, 0.25), 1.6, true)
	for p: Vector3 in [Vector3(-20, 0, -4), Vector3(20, 0, -6), Vector3(-18, 0, 16)]:
		M._building(root, p, Vector2i(4, 3), 2, Color(0.62, 0.45, 0.3), 0.8)
	var props: Structure = M._props()
	# The chairlift: masts up the slope, with chairs (cables are visual).
	var last := Vector3.INF
	for k in 5:
		var mast := Vector3(14, 0, 22 - k * 9)
		props.add_box(mast + Vector3(0, 4.0 + k * 0.5, 0), Vector3(0.4, 8.0 + k, 0.4), STEEL)
		props.add_box(mast + Vector3(0, 8.15 + k, 0), Vector3(2.6, 0.3, 0.3), STEEL)
		var top := mast + Vector3(0, 8.0 + k, 0)
		if last != Vector3.INF:
			M._cable(props, last, top, Vector3.RIGHT)
		last = top
	var snowman := Color(0.97, 0.97, 0.98)
	props.add_box(Vector3(-6, 0.5, 8), Vector3(1.0, 1.0, 1.0), snowman)
	props.add_box(Vector3(-6, 1.3, 8), Vector3(0.65, 0.65, 0.65), snowman)
	for p: Vector3 in [Vector3(-26, 0, -26), Vector3(26, 0, -24), Vector3(-26, 0, 26), Vector3(8, 0, 26), Vector3(-10, 0, -26)]:
		M._tree(props, p)
	root.add_child(props)
	return {"name": NAMES[11], "size": size, "spawn": Vector3(0, 0.5, 10)}


## A rig on legs above a concrete pad: a deck of steel plates on a grid of
## columns, a ramp up, a derrick with a ladder, fuel tanks (explosive), living
## quarters and a helipad.
static func _oil_rig(M: GDScript, root: Node3D) -> Dictionary:
	var size := 52.0
	M._ground(root, size, Color(0.45, 0.45, 0.43))
	var deck_y := 9.0
	var rig := Structure.new()
	rig.strength = 2.2
	for x: float in [-12.0, 0.0, 12.0]:
		for z: float in [-12.0, 0.0, 12.0]:
			rig.add_box(Vector3(x, deck_y * 0.5, z), Vector3(1.4, deck_y, 1.4), Color(0.85, 0.65, 0.15))
	for ix in 7:
		for iz in 7:
			rig.add_box(Vector3(-12 + ix * 4, deck_y + 0.2, -12 + iz * 4), Vector3(4.0, 0.4, 4.0), STEEL)
	# Ramp from the pad up to the deck, with a landing on a column.
	rig.add_box(Vector3(12, deck_y * 0.5, 17), Vector3(1.0, deck_y, 1.0), Color(0.85, 0.65, 0.15))
	rig.add_box(Vector3(12, deck_y + 0.2, 16), Vector3(3.0, 0.4, 4.0), STEEL)
	rig.add_incline(Vector3(-14, 0, 18.5), Vector3(10.5, deck_y + 0.4, 18.5), 3.0, 0.4, STEEL)
	for x: float in [-16.0, -4.0, 6.0]:
		rig.add_box(Vector3(x, (deck_y * (x + 14.0) / 24.5) * 0.5, 18.5), Vector3(0.6, maxf(deck_y * (x + 14.0) / 24.5, 0.3), 0.6),
				Color(0.85, 0.65, 0.15))
	# Fuel tanks on the deck.
	for z: float in [-9.0, -5.0]:
		var tank := rig.add_box(Vector3(9, deck_y + 1.9, z), Vector3(3.0, 3.0, 3.0), Color(0.85, 0.85, 0.85), Basis.IDENTITY,
				Look.cylinder(1.5, 1.5, 3.0, Color(0.85, 0.85, 0.85)))
		tank.set_meta("explosive", true)
	root.add_child(rig)
	M._bare.append(Rect2(-14, -14, 28, 28))
	M._shades.append(Rect2(-14, -14, 28, 28))
	# The derrick and the living quarters stand on the deck.
	_tower(M, root, Vector3(-6, deck_y + 0.4, -6), 2.0, 18.0, [Color(0.85, 0.65, 0.15), STEEL], 2.0)
	M._building(root, Vector3(4, deck_y + 0.4, 6), Vector2i(4, 3), 2, WHITE, 1.6)
	var pad := Structure.new()
	pad.position = Vector3(-6, deck_y + 0.4, 8)
	for v: Vector3 in [Vector3(-0.9, 0.01, 0), Vector3(0.9, 0.01, 0)]:
		pad.add_box(v, Vector3(0.35, 0.02, 2.6), Color(0.95, 0.8, 0.15))
	pad.add_box(Vector3(0, 0.01, 0), Vector3(1.45, 0.02, 0.35), Color(0.95, 0.8, 0.15))
	root.add_child(pad)
	return {"name": NAMES[12], "size": size, "spawn": Vector3(-16, 0.5, 22)}


## A town below a concrete dam: the wall stands across the -Z end with a lake
## held high behind it between canyon walls. Water disasters here burst the dam
## and come down the valley (tsunami.gd reads world.dam).
static func _dam(M: GDScript, root: Node3D) -> Dictionary:
	var size := 56.0
	var half := size * 0.5
	M._ground(root, size, M.GRASS_COLOR)
	M._road(root, Vector3(0, 0, 10), size, true)
	M._decal(root, Vector3(0, 0, -6), Vector2(3, 22), M.PATH_COLOR)
	# The wall: concrete blocks, thicker toward the bottom, a walkway on top.
	var dam := Structure.new()
	dam.strength = 2.2
	dam.span_limit = 6
	var z := -half + 2.5
	var concrete := Color(0.68, 0.67, 0.64)
	for row in 7:
		for col in 14:
			var x := -half + 2.0 + col * 4.0
			var thick := 3.0 + (6 - row) * 0.35
			dam.add_box(Vector3(x, 1.0 + row * 2.0, z - thick * 0.5 + 1.5), Vector3(4.0, 2.0, thick), concrete if (row + col) % 2 == 0 else concrete.darkened(0.06))
	for col in 14:
		dam.add_box(Vector3(-half + 2.0 + col * 4.0, 14.5, z + 1.3), Vector3(4.0, 1.0, 0.25), concrete.darkened(0.15))
	# Spillway gates on the face.
	for x: float in [-6.0, 0.0, 6.0]:
		dam.add_box(Vector3(x, 9.0, z + 1.55), Vector3(2.4, 3.0, 0.15), Color(0.35, 0.37, 0.4))
	root.add_child(dam)
	# The lake behind the wall, between canyon walls that run off into the haze.
	var lake := MeshInstance3D.new()
	lake.name = "DamLake"
	var surface := PlaneMesh.new()
	surface.size = Vector2(size + 8.0, 300.0)
	surface.material = Look.water()
	lake.mesh = surface
	lake.position = Vector3(0, 12.6, -half - 150.0 + 0.5)
	root.add_child(lake)
	for side: float in [-1.0, 1.0]:
		var canyon := MeshInstance3D.new()
		var rock := BoxMesh.new()
		rock.size = Vector3(24.0, 46.0, 300.0)
		rock.material = Look.cliff()
		canyon.mesh = rock
		canyon.position = Vector3(side * (half + 11.0), 0.0, -half - 150.0)
		root.add_child(canyon)
	# The town on the valley floor: two blocks with stairs, houses, a water tower.
	M._building(root, Vector3(-12, 0, -6), Vector2i(5, 4), 3, Color(0.85, 0.8, 0.7), 1.3, true)
	M._building(root, Vector3(12, 0, -8), Vector2i(4, 4), 4, Color(0.7, 0.75, 0.82), 1.6)
	M._building(root, Vector3(-15, 0, 20), Vector2i(4, 3), 2, Color(0.62, 0.45, 0.3), 0.8)
	M._building(root, Vector3(15, 0, 21), Vector2i(4, 3), 1, Color(0.9, 0.85, 0.75), 0.7)
	_water_tower(M, root, Vector3(22, 0, 2))
	var props: Structure = M._props()
	for p: Vector3 in [Vector3(-24, 0, 4), Vector3(-4, 0, -16), Vector3(4, 0, -16), Vector3(24, 0, 14), Vector3(-24, 0, 14)]:
		M._tree(props, p)
	root.add_child(props)
	return {"name": NAMES[13], "size": size, "spawn": Vector3(0, 0.5, 18), "dam": Vector3(0, 7.0, z)}
