extends RefCounted
## A three-storey shopping mall built into one structure: a glass-roofed atrium
## through the middle with escalator ramps and railings, a fountain and food
## court on the ground floor, shops with storefronts and signs along the back,
## an arcade and a cinema upstairs, and a car park on the roof (ramp in the
## back-left corner). Everything is ordinary structure pieces, so it all breaks.

const Look := preload("res://scripts/world/look.gd")
const Interior := preload("res://scripts/world/interior.gd")

## Footprint in cells and the atrium's cells (x0, z0, width, depth).
const SIZE := Vector2i(12, 9)
const ATRIUM := Rect2i(4, 3, 4, 3)
const FLOORS := 3
const COLOR := Color(0.86, 0.84, 0.8)
const ACCENT := Color(0.2, 0.45, 0.6)
const TILE := Color(0.82, 0.8, 0.76)
const RAIL := Color(0.75, 0.77, 0.8)
const ESCALATOR := Color(0.35, 0.37, 0.4)
const SIGNS := [Color(0.9, 0.25, 0.3), Color(0.2, 0.6, 0.95), Color(0.95, 0.7, 0.15), Color(0.3, 0.8, 0.45),
		Color(0.75, 0.35, 0.9), Color(1.0, 0.5, 0.2)]
const SHOP_KINDS := ["clothes", "electronics", "cafe", "toys", "clothes", "electronics"]
const RAIL_HEIGHT := 1.0
const PARTITION := 0.15
const GLASS := 0.12

## Built by build(); cell size and storey metrics come from the structure.
static var _s
static var _cell := 2.0
static var _w := 24.0
static var _d := 18.0


## Fills structure s (its origin is the mall's center at ground level).
static func build(s, rng: RandomNumberGenerator) -> void:
	_s = s
	_cell = s.CELL
	_w = SIZE.x * _cell
	_d = SIZE.y * _cell
	var wall: float = s.WALL_THICKNESS
	var slab: float = s.SLAB_THICKNESS
	var storey: float = s.FLOOR_HEIGHT
	var floor_material: Material = Look.slab(TILE, COLOR.darkened(0.25))

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_w, _d)
	plane.material = floor_material
	ground.mesh = plane
	ground.position.y = 0.005
	s.add_child(ground)

	for f in FLOORS:
		var y0 := f * storey
		if f > 0:
			_slab(y0, floor_material)
		var bottom := y0 + (slab if f > 0 else 0.0)
		var h := y0 + storey - bottom
		_outer_walls(f, bottom, h, wall)
		_columns(f, bottom, h)
		_shops(f, bottom, h, wall, rng)
		if f > 0:
			_railings(f, bottom)
	var roof := FLOORS * storey
	_slab(roof, Look.roof(COLOR.darkened(0.25)), true)
	_skylight(roof + slab * 0.5)

	# Escalators: ground -> first floor going +x, first -> second going -x.
	var a := _cells_to_local(ATRIUM.position.x + 1, ATRIUM.position.y)
	var b := _cells_to_local(ATRIUM.end.x, ATRIUM.position.y)
	var row0 := a.y + _cell * 0.5
	s.add_incline(Vector3(a.x, 0.0, row0), Vector3(b.x, storey + slab, row0), _cell - 0.2, 0.3, ESCALATOR)
	var row1 := _cells_to_local(0, ATRIUM.end.y - 1).y + _cell * 0.5
	s.add_incline(Vector3(b.x, storey + slab, row1), Vector3(_cells_to_local(ATRIUM.position.x, 0).x, storey * 2.0 + slab, row1),
			_cell - 0.2, 0.3, ESCALATOR)
	# To the roof: back-left corner, rising along +x over two cells.
	var corner := _cells_to_local(0, 0)
	s.add_incline(Vector3(corner.x + wall, storey * 2.0 + slab, corner.y + _cell * 0.5 + wall * 0.5),
			Vector3(corner.x + _cell * 2.0, roof + slab, corner.y + _cell * 0.5 + wall * 0.5), _cell - wall, 0.25, ESCALATOR)

	_parapet(roof + slab)
	_food_court(rng)
	_cinema(storey * 2.0 + slab, h_of(2, storey, slab))
	_arcade(storey * 2.0 + slab, rng)
	# A ladder up the right side to the roof, for a quick way out of the water.
	var ladder_height := roof + slab + 1.6
	var ladder: Node = s.add_box(Vector3(_w * 0.5 + 0.08, ladder_height * 0.5, 3.0), Vector3(0.6, ladder_height, 0.12),
			Color(0.75, 0.62, 0.2), Basis(Vector3.UP, PI * 0.5), Look.ladder(ladder_height))
	ladder.set_meta("ladder", true)
	_fountain()


static func h_of(f: int, storey: float, slab: float) -> float:
	return storey - (slab if f > 0 else 0.0)


## Local x/z of a cell's back-left corner.
static func _cells_to_local(i: int, j: int) -> Vector2:
	return Vector2(-_w * 0.5 + i * _cell, -_d * 0.5 + j * _cell)


static func _in_atrium(i: int, j: int) -> bool:
	return ATRIUM.has_point(Vector2i(i, j))


## Floor tiles at height y, leaving the atrium open (and, on the roof, the corner
## the roof ramp comes up through).
static func _slab(y: float, material: Material, roof := false) -> void:
	var slab: float = _s.SLAB_THICKNESS
	for i in SIZE.x:
		for j in SIZE.y:
			if _in_atrium(i, j):
				continue
			if roof and j == 0 and i < 2:
				continue
			var c := _cells_to_local(i, j) + Vector2(_cell, _cell) * 0.5
			_s.add_box(Vector3(c.x, y + slab * 0.5, c.y), Vector3(_cell, slab, _cell), COLOR.darkened(0.25), Basis.IDENTITY,
					null, material)


## Glass panes over the atrium at roof level, local +Z turned up (window shader),
## resting on steel beams that span the atrium between the roof slabs.
static func _skylight(y: float) -> void:
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	var beam := 0.3
	var span := ATRIUM.size.x * _cell + 0.6
	for j in range(ATRIUM.position.y + 1, ATRIUM.end.y):
		var z := _cells_to_local(0, j).y
		_s.add_box(Vector3(_cells_to_local(ATRIUM.position.x, 0).x + ATRIUM.size.x * _cell * 0.5, y - 0.05 - beam * 0.5, z),
				Vector3(span, beam, 0.2), RAIL.darkened(0.3))
	for i in range(ATRIUM.position.x, ATRIUM.end.x):
		for j in range(ATRIUM.position.y, ATRIUM.end.y):
			var c := _cells_to_local(i, j) + Vector2(_cell, _cell) * 0.5
			_s.add_box(Vector3(c.x, y, c.y), Vector3(_cell, _cell, 0.1), Look.GLASS_KEY, up)


## Outside walls: glass all along the ground floor front with a two-cell
## entrance, windows every third cell elsewhere, and a solid cinema block
## upstairs on the right.
static func _outer_walls(f: int, bottom: float, h: float, wall: float) -> void:
	var cy := bottom + h * 0.5
	var entrance := [SIZE.x / 2 - 1, SIZE.x / 2]
	for i in SIZE.x:
		var x := -_w * 0.5 + _cell * (i + 0.5)
		var cinema: bool = f == FLOORS - 1 and i >= 8
		var front: Color = Look.GLASS_KEY if (f == 0 or i % 2 == 1) and not cinema else COLOR
		if not (f == 0 and i in entrance):
			_wall(Vector3(x, cy, _d * 0.5 - wall * 0.5), Vector3(_cell, h, wall), front, Basis.IDENTITY)
		var back: Color = Look.GLASS_KEY if i % 3 == 1 and not cinema and f > 0 else COLOR
		_wall(Vector3(x, cy, -_d * 0.5 + wall * 0.5), Vector3(_cell, h, wall), back, Basis(Vector3.UP, PI))
	var side_len := (_d - wall * 2.0) / SIZE.y
	for j in SIZE.y:
		var z := -_d * 0.5 + wall + side_len * (j + 0.5)
		var window: Color = Look.GLASS_KEY if j % 3 == 1 else COLOR
		var right: Color = COLOR if f == FLOORS - 1 else window
		_wall(Vector3(_w * 0.5 - wall * 0.5, cy, z), Vector3(side_len, h, wall), right, Basis(Vector3.UP, PI * 0.5))
		_wall(Vector3(-_w * 0.5 + wall * 0.5, cy, z), Vector3(side_len, h, wall), window, Basis(Vector3.UP, -PI * 0.5))


## Columns just outside the atrium's corners carry the floors above the open
## halls (slabs only reach two cells sideways from what holds them up).
static func _columns(f: int, bottom: float, h: float) -> void:
	var a := _cells_to_local(ATRIUM.position.x, ATRIUM.position.y)
	var b := _cells_to_local(ATRIUM.end.x, ATRIUM.end.y)
	for x: float in [a.x - 0.3, b.x + 0.3]:
		for z: float in [a.y - 0.3, b.y + 0.3]:
			# Upstairs on the right the cinema wall does this job.
			if f == FLOORS - 1 and x > 0.0:
				continue
			_s.add_box(Vector3(x, bottom + h * 0.5, z), Vector3(0.5, h, 0.5), COLOR.darkened(0.05))


static func _wall(pos: Vector3, size: Vector3, color: Color, basis: Basis) -> void:
	var material: Material = Look.surface(color) if color == Look.GLASS_KEY else Look.wall(color)
	_s.add_box(pos, size, color, basis, null, material)


## Shops along the back: two cells wide and two deep, a glass front with a
## doorway and a colored sign, and furniture to match the kind of shop. The top
## floor keeps only the left ones (the cinema takes the right).
static func _shops(f: int, bottom: float, h: float, wall: float, rng: RandomNumberGenerator) -> void:
	var front_z := -_d * 0.5 + _cell * 2.0
	var count := SIZE.x / 2
	for k in count:
		if f == FLOORS - 1 and (k == 0 or k >= 4):
			continue
		var x0 := -_w * 0.5 + k * _cell * 2.0
		# Partition on the shop's right (the outer wall closes the last one).
		if k < count - 1:
			var length := front_z - (-_d * 0.5 + wall)
			_s.add_box(Vector3(x0 + _cell * 2.0, bottom + h * 0.5, front_z - length * 0.5), Vector3(PARTITION, h, length),
					Interior.PARTITION_COLOR)
		if f == FLOORS - 1 and k == 1:
			# On the top floor the first shop is the roof ramp corner; close it off.
			var length := front_z - (-_d * 0.5 + wall)
			_s.add_box(Vector3(x0, bottom + h * 0.5, front_z - length * 0.5), Vector3(PARTITION, h, length),
					Interior.PARTITION_COLOR)
		# Storefront: glass on the left cell, doorway on the right, sign above both.
		_s.add_box(Vector3(x0 + _cell * 0.5, bottom + h * 0.5, front_z - GLASS * 0.5), Vector3(_cell, h, GLASS), Look.GLASS_KEY)
		var sign_color: Color = SIGNS[(k + f * 2) % SIGNS.size()]
		var door_top := bottom + 2.3
		_s.add_box(Vector3(x0 + _cell * 1.5, (door_top + bottom + h) * 0.5, front_z - GLASS * 0.5),
				Vector3(_cell, bottom + h - door_top, GLASS), COLOR)
		var sign_size := Vector3(_cell * 1.6, 0.42, 0.08)
		_s.add_box(Vector3(x0 + _cell, bottom + h - 0.3, front_z + 0.04), sign_size, sign_color, Basis.IDENTITY,
				Look.glow(sign_size, sign_color, 1.3))
		var room := Rect2(x0 + PARTITION, -_d * 0.5 + wall, _cell * 2.0 - PARTITION * 2.0, _cell * 2.0 - wall - 0.15)
		var placed: Array[Rect2] = [Rect2(x0 + _cell, front_z - 1.2, _cell, 1.2)]
		for item: String in Interior.ROOMS[SHOP_KINDS[(k + f) % SHOP_KINDS.size()]]:
			Interior.place(_s, Vector3.ZERO, bottom, room, item, placed, rng)


## Waist-high glass and steel around the atrium on the upper floors, open where
## the escalators arrive.
static func _railings(f: int, bottom: float) -> void:
	var y := bottom + RAIL_HEIGHT * 0.5
	var a := _cells_to_local(ATRIUM.position.x, ATRIUM.position.y)
	var b := _cells_to_local(ATRIUM.end.x, ATRIUM.end.y)
	for i in range(ATRIUM.position.x, ATRIUM.end.x):
		var x := _cells_to_local(i, 0).x + _cell * 0.5
		_rail(Vector3(x, y, a.y - 0.05), Vector3(_cell, RAIL_HEIGHT, 0.1))
		_rail(Vector3(x, y, b.y + 0.05), Vector3(_cell, RAIL_HEIGHT, 0.1))
	for j in range(ATRIUM.position.y, ATRIUM.end.y):
		var z := _cells_to_local(0, j).y + _cell * 0.5
		var first := j == ATRIUM.position.y
		var last := j == ATRIUM.end.y - 1
		# East edge: the ground escalator arrives on the first row of floor 1 and
		# the next one leaves from the last row (on floor 2 the cinema wall stands
		# there); west edge: the second escalator arrives on floor 2.
		if f == 1 and not (first or last):
			_rail(Vector3(b.x + 0.05, y, z), Vector3(0.1, RAIL_HEIGHT, _cell))
		if not (f == 2 and last):
			_rail(Vector3(a.x - 0.05, y, z), Vector3(0.1, RAIL_HEIGHT, _cell))


## A glass panel with a steel cap. Panels running along z are turned so their
## glass faces sideways (the window shader draws the face at local +Z).
static func _rail(pos: Vector3, size: Vector3) -> void:
	var along_z := size.z > size.x
	var basis := Basis(Vector3.UP, PI * 0.5) if along_z else Basis.IDENTITY
	var panel := Vector3(maxf(size.x, size.z), size.y - 0.06, 0.06)
	_s.add_box(pos - Vector3(0, 0.03, 0), panel, Look.GLASS_KEY, basis)
	_s.add_box(pos + Vector3(0, size.y * 0.5 - 0.03, 0), Vector3(panel.x, 0.06, 0.1), RAIL, basis)


## A low wall around the roof car park.
static func _parapet(y: float) -> void:
	var height := 0.9
	for i in SIZE.x:
		var x := -_w * 0.5 + _cell * (i + 0.5)
		_s.add_box(Vector3(x, y + height * 0.5, _d * 0.5 - 0.15), Vector3(_cell, height, 0.3), COLOR.darkened(0.1))
		_s.add_box(Vector3(x, y + height * 0.5, -_d * 0.5 + 0.15), Vector3(_cell, height, 0.3), COLOR.darkened(0.1))
	for j in SIZE.y:
		var z := -_d * 0.5 + _cell * (j + 0.5)
		if j == 0 or j == SIZE.y - 1:
			continue
		_s.add_box(Vector3(_w * 0.5 - 0.15, y + height * 0.5, z), Vector3(0.3, height, _cell), COLOR.darkened(0.1))
		_s.add_box(Vector3(-_w * 0.5 + 0.15, y + height * 0.5, z), Vector3(0.3, height, _cell), COLOR.darkened(0.1))


## Tables and chairs on the ground floor in front of the atrium.
static func _food_court(rng: RandomNumberGenerator) -> void:
	var area := Rect2(_cells_to_local(2, ATRIUM.end.y + 1), Vector2(_cell * 8.0, _cell * 2.0 - 0.4))
	var placed: Array[Rect2] = [Rect2(-_cell, _d * 0.5 - _cell * 2.0, _cell * 2.0, _cell * 2.0)]
	for k in 5:
		Interior.place(_s, Vector3.ZERO, 0.0, area, "table", placed, rng)
	var benches := Rect2(_cells_to_local(ATRIUM.position.x, ATRIUM.end.y), Vector2(_cell * 4.0, 1.6))
	for k in 2:
		Interior.place(_s, Vector3.ZERO, 0.0, benches, "bench", placed, rng)


## Rows of seats facing a glowing screen on the back wall, in the dark.
static func _cinema(floor_y: float, h: float) -> void:
	var x0 := _cells_to_local(8, 0).x
	var x1 := _w * 0.5 - 0.3
	# The cinema's inner wall, with a doorway near the front.
	var px := x0 + PARTITION * 0.5
	for j in SIZE.y:
		if j == SIZE.y - 2:
			continue
		var z0 := maxf(-_d * 0.5 + _cell * j, -_d * 0.5 + 0.3)
		var z1 := minf(-_d * 0.5 + _cell * (j + 1), _d * 0.5 - 0.3)
		_s.add_box(Vector3(px, floor_y + h * 0.5, (z0 + z1) * 0.5), Vector3(PARTITION, h, z1 - z0), Color(0.25, 0.1, 0.12))
	var screen := Vector3(x1 - x0 - 1.0, 2.0, 0.08)
	# Touching the back wall (a hair of overlap), so it hangs from it.
	_s.add_box(Vector3((x0 + x1) * 0.5, floor_y + 1.5, -_d * 0.5 + 0.3 + screen.z * 0.5 - 0.005), screen, Color.WHITE, Basis.IDENTITY,
			Look.glow(screen, Color(0.75, 0.85, 1.0), 2.2))
	var seat := Color(0.6, 0.08, 0.1)
	for row in 5:
		var z := -_d * 0.5 + 4.5 + row * 1.6
		var x := x0 + 0.9
		while x < x1 - 0.5:
			_s.add_box(Vector3(x, floor_y + 0.22, z), Vector3(0.55, 0.44, 0.55), seat)
			_s.add_box(Vector3(x, floor_y + 0.66, z + 0.25), Vector3(0.55, 0.44, 0.08), seat)
			x += 0.7


## Game cabinets along the left wall upstairs.
static func _arcade(floor_y: float, rng: RandomNumberGenerator) -> void:
	var room := Rect2(_cells_to_local(0, 3) + Vector2(0.35, 0.0), Vector2(_cell * 2.0 - 0.4, _cell * 6.0 - 0.3))
	var placed: Array[Rect2] = []
	for k in 6:
		Interior.place(_s, Vector3.ZERO, floor_y, room, "arcade", placed, rng)


## A square basin with a pillar under the atrium, clear of the first escalator.
static func _fountain() -> void:
	var center := Vector3(-1.0, 0.0, _cells_to_local(0, ATRIUM.position.y + 1).y + _cell)
	var basin := 3.2
	var stone := Color(0.7, 0.7, 0.72)
	for side: float in [-1.0, 1.0]:
		_s.add_box(center + Vector3(side * basin * 0.5, 0.25, 0), Vector3(0.25, 0.5, basin), stone)
		_s.add_box(center + Vector3(0, 0.25, side * basin * 0.5), Vector3(basin - 0.25, 0.5, 0.25), stone)
	_s.add_box(center + Vector3(0, 0.6, 0), Vector3(0.4, 1.2, 0.4), stone)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(basin - 0.25, basin - 0.25)
	plane.material = Look.water()
	water.mesh = plane
	water.position = center + Vector3(0, 0.4, 0)
	_s.add_child(water)

	var drop := QuadMesh.new()
	drop.size = Vector2(0.12, 0.12)
	drop.material = Look.sprite(1.2)
	var spray := CPUParticles3D.new()
	spray.mesh = drop
	spray.amount = 90
	spray.lifetime = 1.1
	spray.direction = Vector3.UP
	spray.spread = 12.0
	spray.initial_velocity_min = 4.5
	spray.initial_velocity_max = 5.5
	spray.gravity = Vector3(0, -9.8, 0)
	spray.color_ramp = Look.ramp([Color(0.85, 0.93, 1.0, 0.8), Color(0.85, 0.93, 1.0, 0.6), Color(0.85, 0.93, 1.0, 0.0)])
	spray.position = center + Vector3(0, 1.25, 0)
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_s.add_child(spray)
