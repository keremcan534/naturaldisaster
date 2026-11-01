extends RefCounted
## Rooms inside buildings: a partition wall with a doorway splits each floor in
## two, and each room gets furniture against its walls. Everything is ordinary
## structure pieces, so it shakes loose, falls and breaks like the rest.

const PARTITION := 0.15
const PARTITION_COLOR := Color(0.9, 0.88, 0.84)
const WOOD := Color(0.45, 0.3, 0.2)
const DARK_WOOD := Color(0.28, 0.19, 0.13)
const WHITE := Color(0.92, 0.91, 0.88)
const STEEL := Color(0.7, 0.72, 0.74)
const POT := Color(0.62, 0.33, 0.22)
const FABRICS := [Color(0.32, 0.38, 0.5), Color(0.55, 0.28, 0.24), Color(0.45, 0.45, 0.42), Color(0.3, 0.45, 0.35)]
const RUGS := [Color(0.6, 0.25, 0.2), Color(0.25, 0.3, 0.45), Color(0.7, 0.62, 0.45)]
const SCREENS := [Color(0.35, 0.6, 1.0), Color(1.0, 0.4, 0.6), Color(0.4, 1.0, 0.6), Color(1.0, 0.8, 0.3)]
const BOOKS := [Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.55), Color(0.75, 0.65, 0.3)]
## Space kept free in front of doors and stairs.
const CLEARANCE := 0.5

const Look := preload("res://scripts/world/look.gd")

## Furniture: each part is [offset from the item's floor center, size, color or
## "lamp"/"leaves"]. Items are modelled against a wall at -Z, facing +Z.
const ITEMS := {
	"sofa": [[Vector3(0, 0.21, 0), Vector3(2.0, 0.42, 0.85), "fabric"],
			[Vector3(0, 0.645, -0.315), Vector3(2.0, 0.45, 0.22), "fabric"]],
	"tv": [[Vector3(0, 0.25, 0), Vector3(1.4, 0.5, 0.45), DARK_WOOD],
			[Vector3(0, 0.84, -0.1), Vector3(1.2, 0.68, 0.06), Look.CAR_GLASS_KEY]],
	"table": [[Vector3(0, 0.36, 0), Vector3(0.3, 0.72, 0.3), DARK_WOOD],
			[Vector3(0, 0.75, 0), Vector3(1.4, 0.06, 0.9), WOOD]],
	"rug": [[Vector3(0, 0.01, 0), Vector3(2.2, 0.02, 1.5), "rug"]],
	"bed": [[Vector3(0, 0.175, 0), Vector3(1.6, 0.35, 2.1), WOOD],
			[Vector3(0, 0.45, 0), Vector3(1.5, 0.2, 2.0), WHITE],
			[Vector3(0, 0.61, -0.7), Vector3(1.2, 0.12, 0.4), WHITE],
			[Vector3(0, 0.57, 0.35), Vector3(1.5, 0.04, 1.2), "fabric"]],
	"wardrobe": [[Vector3(0, 1.05, 0), Vector3(1.2, 2.1, 0.6), WOOD]],
	"shelf": [[Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.35), DARK_WOOD],
			[Vector3(0, 1.95, 0), Vector3(0.8, 0.3, 0.25), "books"]],
	"counter": [[Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.65), WHITE],
			[Vector3(0, 0.925, 0), Vector3(2.2, 0.05, 0.67), DARK_WOOD]],
	"fridge": [[Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.7), STEEL]],
	"desk": [[Vector3(-0.6, 0.36, 0), Vector3(0.06, 0.72, 0.6), DARK_WOOD],
			[Vector3(0.6, 0.36, 0), Vector3(0.06, 0.72, 0.6), DARK_WOOD],
			[Vector3(0, 0.745, 0), Vector3(1.3, 0.05, 0.65), WOOD],
			[Vector3(0, 0.96, -0.15), Vector3(0.6, 0.38, 0.05), Look.CAR_GLASS_KEY]],
	"lamp": [[Vector3(0, 0.725, 0), Vector3(0.05, 1.45, 0.05), DARK_WOOD],
			[Vector3(0, 1.6, 0), Vector3(0.4, 0.3, 0.4), "lamp"]],
	"plant": [[Vector3(0, 0.225, 0), Vector3(0.4, 0.45, 0.4), POT],
			[Vector3(0, 0.9, 0), Vector3(0.8, 0.9, 0.8), "leaves"]],
	"chair": [[Vector3(0, 0.22, 0), Vector3(0.45, 0.44, 0.45), DARK_WOOD],
			[Vector3(0, 0.66, -0.2), Vector3(0.45, 0.44, 0.06), DARK_WOOD]],
	# Clothes on a rail: two posts, a bar, and a row of garments.
	"rack": [[Vector3(-0.7, 0.75, 0), Vector3(0.05, 1.5, 0.05), STEEL],
			[Vector3(0.7, 0.75, 0), Vector3(0.05, 1.5, 0.05), STEEL],
			[Vector3(0, 1.525, 0), Vector3(1.45, 0.05, 0.05), STEEL],
			[Vector3(0, 1.075, 0), Vector3(1.4, 0.85, 0.45), "fabric"]],
	"display": [[Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.6), WHITE],
			[Vector3(0, 1.15, -0.05), Vector3(1.0, 0.5, 0.06), "screen"]],
	"arcade": [[Vector3(0, 0.85, 0), Vector3(0.8, 1.7, 0.7), "fabric"],
			[Vector3(0, 1.2, 0.36), Vector3(0.6, 0.45, 0.02), "screen"]],
	"cooler": [[Vector3(0, 0.55, 0), Vector3(0.35, 1.1, 0.35), WHITE],
			[Vector3(0, 1.3, 0), Vector3(0.3, 0.4, 0.3), Color(0.55, 0.75, 0.95)]],
	"reception": [[Vector3(0, 0.55, 0), Vector3(2.6, 1.1, 0.7), WOOD],
			[Vector3(0, 1.125, 0), Vector3(2.7, 0.05, 0.8), DARK_WOOD]],
	"bench": [[Vector3(0, 0.22, 0), Vector3(1.8, 0.44, 0.5), WOOD]],
}
## Items that stand in the middle of a room rather than against a wall.
const CENTERED := ["table", "rug"]
const ROOMS := {
	"kitchen": ["counter", "fridge", "table", "plant"],
	"living": ["rug", "sofa", "tv", "lamp", "plant"],
	"bedroom": ["bed", "wardrobe", "lamp", "rug"],
	"office": ["desk", "shelf", "sofa", "plant"],
	# Office towers.
	"lobby": ["reception", "sofa", "plant", "plant", "rug", "sofa"],
	"workspace": ["desk", "desk", "desk", "desk", "cooler", "shelf", "plant", "desk"],
	# Mall shops.
	"clothes": ["rack", "rack", "rack", "counter", "plant"],
	"electronics": ["display", "display", "shelf", "counter"],
	"cafe": ["counter", "table", "table", "chair", "chair", "plant"],
	"toys": ["shelf", "shelf", "rug", "arcade"],
}

static var _lamp_meshes := {}


## Partition and furniture for one floor of structure s (untyped: structure.gd
## preloads this file). floor_y is the top of its floor slab; h the wall height.
## With stairs, the back row's first four cells hold the ramp and its landings,
## and the row in front of them is the walkway between ramps.
static func furnish(s, origin: Vector3, footprint: Vector2i, f: int, floor_y: float, h: float,
		stairs: bool, cell: float, wall: float, rng: RandomNumberGenerator, office := false) -> void:
	var w := footprint.x * cell
	var d := footprint.y * cell
	var blocked: Array[Rect2] = []
	if stairs:
		blocked.append(Rect2(-w * 0.5, -d * 0.5, cell * 4.0 + CLEARANCE, cell * 2.0 + CLEARANCE))
	if f == 0:
		var door_x := -w * 0.5 + cell * (footprint.x / 2 + 0.5)
		blocked.append(Rect2(door_x - 1.0, d * 0.5 - cell * 1.5, 2.0, cell * 1.5))
		if stairs:
			# A clear lane from the door back to the walkway (bots walk it, see
			# Structure._climb_path).
			blocked.append(Rect2(door_x - 0.8, -d * 0.5 + cell, 1.6, d - cell))

	var inner := Rect2(-w * 0.5 + wall, -d * 0.5 + wall, w - wall * 2.0, d - wall * 2.0)
	var rooms: Array[Rect2] = [inner]
	# The partition stays right of the stairs and their landing; narrow buildings
	# are one room.
	var split := maxi(footprint.x / 2, 4 if stairs else 2)
	if footprint.x - split >= 2:
		var px := -w * 0.5 + cell * split
		var gap_row := footprint.y / 2
		for j in footprint.y:
			if j == gap_row:
				continue
			var z0 := maxf(-d * 0.5 + cell * j, -d * 0.5 + wall)
			var z1 := minf(-d * 0.5 + cell * (j + 1), d * 0.5 - wall)
			s.add_box(origin + Vector3(px, floor_y + h * 0.5, (z0 + z1) * 0.5), Vector3(PARTITION, h, z1 - z0), PARTITION_COLOR)
		var gap_z := -d * 0.5 + cell * (gap_row + 0.5)
		blocked.append(Rect2(px - 1.2, gap_z - cell * 0.5, 2.4, cell))
		rooms = [Rect2(inner.position, Vector2(px - PARTITION * 0.5 - inner.position.x, inner.size.y)),
				Rect2(Vector2(px + PARTITION * 0.5, inner.position.y), Vector2(inner.end.x - px - PARTITION * 0.5, inner.size.y))]

	for r in rooms.size():
		var kind: String
		if office:
			kind = "lobby" if f == 0 else "workspace"
		elif f == 0:
			kind = "kitchen" if r == 0 and rooms.size() > 1 else "living"
		else:
			kind = ["bedroom", "office"][(r + f) % 2]
		var placed: Array[Rect2] = blocked.duplicate()
		for item: String in ROOMS[kind]:
			place(s, origin, floor_y, rooms[r], item, placed, rng)


## Tries a few spots for an item: against a random wall of the room, or in its
## middle for CENTERED items. Gives up quietly if the room is too full. placed
## holds the floor already taken (and is extended).
static func place(s, origin: Vector3, floor_y: float, room: Rect2, item: String,
		placed: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var parts: Array = ITEMS[item]
	var extent := Vector2.ZERO
	for part: Array in parts:
		var o: Vector3 = part[0]
		var size: Vector3 = part[1]
		extent = extent.max(Vector2(absf(o.x) + size.x * 0.5, absf(o.z) + size.z * 0.5))
	var fabric: Color = FABRICS[rng.randi() % FABRICS.size()]
	var rug: Color = RUGS[rng.randi() % RUGS.size()]
	for attempt in 12:
		var turn := 0
		var center := room.get_center()
		if item not in CENTERED:
			# 0: against the back wall (facing +Z), 1: right, 2: front, 3: left.
			turn = rng.randi() % 4
			var along := rng.randf_range(-0.5, 0.5)
			match turn:
				0:
					center = Vector2(room.get_center().x + along * maxf(room.size.x - extent.x * 2.0, 0.0), room.position.y + extent.y)
				1:
					center = Vector2(room.end.x - extent.y, room.get_center().y + along * maxf(room.size.y - extent.x * 2.0, 0.0))
				2:
					center = Vector2(room.get_center().x + along * maxf(room.size.x - extent.x * 2.0, 0.0), room.end.y - extent.y)
				3:
					center = Vector2(room.position.x + extent.y, room.get_center().y + along * maxf(room.size.y - extent.x * 2.0, 0.0))
		else:
			center += Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
		var half := extent if turn % 2 == 0 else Vector2(extent.y, extent.x)
		var rect := Rect2(center - half, half * 2.0)
		if not room.grow(0.01).encloses(rect):
			continue
		var free := true
		for other in placed:
			if other.intersects(rect):
				free = false
				break
		if not free:
			continue
		# Rugs lie under things, so they don't claim floor space.
		if item != "rug":
			placed.append(rect.grow(0.25))
		var basis := Basis(Vector3.UP, [0.0, -PI * 0.5, PI, PI * 0.5][turn])
		for part: Array in parts:
			var size: Vector3 = part[1]
			var pos: Vector3 = origin + Vector3(center.x, floor_y, center.y) + basis * (part[0] as Vector3)
			var look = part[2]
			match look:
				"fabric":
					s.add_box(pos, size, fabric, basis)
				"rug":
					s.add_box(pos, size, rug, basis)
				"books":
					s.add_box(pos, size, BOOKS[rng.randi() % BOOKS.size()], basis)
				"lamp":
					s.add_box(pos, size, Color.WHITE, basis, _lamp_mesh(size))
				"leaves":
					s.add_box(pos, size, Color.GREEN, basis, Look.canopy(size, Color(0.25, 0.5, 0.22)))
				"screen":
					s.add_box(pos, size, Color.BLACK, basis, Look.glow(size, SCREENS[rng.randi() % SCREENS.size()], 1.6))
				_:
					s.add_box(pos, size, look, basis)
		return


static func _lamp_mesh(size: Vector3) -> Mesh:
	if not _lamp_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = Look.lamp()
		_lamp_meshes[size] = mesh
	return _lamp_meshes[size]
