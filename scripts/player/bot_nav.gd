extends RefCounted
## Ground-level paths for the bots: a 0.5 m grid over the island where a cell is
## solid if a piece of anything (walls, fences, furniture, cars, rubble) stands
## in it between knee and head height. The search runs in the engine
## (AStarGrid2D); route() returns only the corners, so bots walk around
## buildings and through doorways instead of into walls. Rebuilt with every map
## and every few seconds while things fall (main.gd).

const CELL := 0.5
## Kept away from obstacles: a bot's radius and a little.
const CLEARANCE := 0.35
## The band that blocks a walker, above the ground.
const LOW := 0.3
const HIGH := 1.6

static var grid: AStarGrid2D
static var _origin := Vector2.ZERO
static var _size := Vector2i.ZERO
static var base := 0.0
static var ready := false


## Builds the grid for a map (map_size wide, ground at base_y).
static func build(tree: SceneTree, map_size: float, base_y: float) -> void:
	if grid == null:
		grid = AStarGrid2D.new()
	var half := map_size * 0.5
	base = base_y
	_origin = Vector2(-half, -half)
	_size = Vector2i(ceili(map_size / CELL), ceili(map_size / CELL))
	grid.region = Rect2i(Vector2i.ZERO, _size)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var rects: Array[Rect2] = []
	for structure: Node in tree.get_nodes_in_group("structures"):
		structure.obstacles(base_y + LOW, base_y + HIGH, rects)
	for rect: Rect2 in rects:
		var grown := rect.grow(CLEARANCE)
		var a := _cell_of(grown.position)
		var b := _cell_of(grown.end)
		var cells := Rect2i(a, b - a + Vector2i.ONE).intersection(grid.region)
		if cells.has_area():
			grid.fill_solid_region(cells, true)
	ready = true


static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / CELL), floori((p.y - _origin.y) / CELL))


static func _point_of(cell: Vector2i) -> Vector3:
	return Vector3(_origin.x + (cell.x + 0.5) * CELL, base, _origin.y + (cell.y + 0.5) * CELL)


static func free_at(p: Vector3) -> bool:
	if not ready:
		return true
	var cell := _cell_of(Vector2(p.x, p.z))
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


## The nearest free cell to a point (searching outward a few meters), or -1s.
static func _nearest_free(p: Vector3, reach := 8) -> Vector2i:
	var c := _cell_of(Vector2(p.x, p.z))
	c = c.clamp(Vector2i.ZERO, _size - Vector2i.ONE)
	if not grid.is_point_solid(c):
		return c
	for r in range(1, reach + 1):
		for dx in range(-r, r + 1):
			for dy: int in [-r, r]:
				for cell: Vector2i in [c + Vector2i(dx, dy), c + Vector2i(dy, dx)]:
					if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
						return cell
	return Vector2i(-1, -1)


## Waypoints from `from` to `to` along the ground, corners only (the last one is
## `to` itself when it is reachable). Off the ground or before the first map: a
## straight line.
static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var straight: Array[Vector3] = [to]
	if not ready or from.y > base + 1.2 or to.y > base + 1.2:
		return straight
	var a := _nearest_free(from)
	var b := _nearest_free(to)
	if a.x < 0 or b.x < 0:
		return straight
	var cells := grid.get_id_path(a, b, true)
	if cells.size() < 2:
		return straight
	# Keep only the cells where a straight walk would hit something.
	var out: Array[Vector3] = []
	var anchor := 0
	var k := 2
	while k < cells.size():
		if not _clear(cells[anchor], cells[k]):
			out.append(_point_of(cells[k - 1]))
			anchor = k - 1
		k += 1
	var last := _point_of(cells[-1])
	if cells[-1] == b and free_at(to):
		last = Vector3(to.x, base, to.z)
	out.append(last)
	return out


## Nothing solid on the straight line between two cells.
static func _clear(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for s in range(1, steps):
		var t := float(s) / steps
		var cell := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if grid.is_point_solid(cell):
			return false
	return true


## A random free spot within reach of `near` (or near itself).
static func random_point(near: Vector3, reach: float, rng: RandomNumberGenerator) -> Vector3:
	for attempt in 16:
		var p := near + Vector3(rng.randf_range(-reach, reach), 0, rng.randf_range(-reach, reach))
		var half := _size.x * CELL * 0.5 - 3.0
		p = Vector3(clampf(p.x, -half, half), base, clampf(p.z, -half, half))
		if free_at(p):
			return p
	return Vector3(near.x, base, near.z)


## A random free spot inside a world rectangle (floor of a building), or INF.
static func point_in(rect: Rect2, rng: RandomNumberGenerator) -> Vector3:
	for attempt in 20:
		var p := Vector3(rng.randf_range(rect.position.x, rect.end.x), base, rng.randf_range(rect.position.y, rect.end.y))
		if free_at(p):
			return p
	return Vector3.INF


## How far from p to the nearest obstacle (up to `limit` meters), in 8 directions.
static func clearance(p: Vector3, limit := 10.0) -> float:
	if not ready:
		return limit
	var best := limit
	for k in 8:
		var dir := Vector2.from_angle(k * TAU / 8.0)
		var d := 0.5
		while d < best:
			var at := Vector2(p.x, p.z) + dir * d
			var cell := _cell_of(at)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				best = d
				break
			d += 0.5
	return best
