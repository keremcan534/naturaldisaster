extends RefCounted
## A blocky cargo ship, about 31 m long: red and navy hull with a stepped bow,
## a white bridge with a funnel at the stern, and stacks of colored containers.
## One mesh with vertex colors (one draw call); bow along local +X, origin at the
## middle of the keel. The giant tsunami throws one onto the island, and a couple
## sail around it as scenery.

const LENGTH := 28.0
const WIDTH := 7.6
const HULL_HEIGHT := 5.0
## How deep it sits in the water.
const DRAFT := 2.4
const DECK := HULL_HEIGHT
const STERN := -14.0
const BOW := 16.8

const RED := Color(0.62, 0.12, 0.1)
const NAVY := Color(0.1, 0.15, 0.25)
const WHITE := Color(0.92, 0.92, 0.9)
const DECK_COLOR := Color(0.36, 0.42, 0.34)
const GLASS := Color(0.08, 0.1, 0.13)
const CONTAINERS := [Color(0.75, 0.2, 0.15), Color(0.15, 0.35, 0.65), Color(0.9, 0.55, 0.12),
		Color(0.2, 0.5, 0.3), Color(0.85, 0.85, 0.82), Color(0.9, 0.75, 0.15), Color(0.45, 0.25, 0.5)]
## Container stacks: x centers, z centers, size of one container.
const STACK_X := [-5.4, 0.8, 7.0]
const STACK_Z := [-2.5, 0.0, 2.5]
const CONTAINER := Vector3(6.0, 2.6, 2.4)

static var _mesh: ArrayMesh
static var _boxes: Array = []


## The ship's visible boxes as [center, size, color].
static func parts() -> Array:
	if not _boxes.is_empty():
		return _boxes
	var b: Array = []
	var hull_len := 14.0 - STERN
	var mid := (14.0 + STERN) * 0.5
	b.append([Vector3(mid, 1.0, 0), Vector3(hull_len, 2.0, WIDTH), RED])
	b.append([Vector3(mid, 3.5, 0), Vector3(hull_len, 3.0, WIDTH), NAVY])
	# The bow narrows in steps and rises a little.
	b.append([Vector3(15.0, 1.4, 0), Vector3(2.0, 1.6, 5.6), RED])
	b.append([Vector3(15.0, 3.7, 0), Vector3(2.0, 3.0, 5.6), NAVY])
	b.append([Vector3(16.2, 2.9, 0), Vector3(1.2, 2.6, 3.2), NAVY])
	b.append([Vector3(14.6, 5.5, 0), Vector3(2.8, 1.0, 6.2), NAVY])
	b.append([Vector3(mid, DECK + 0.05, 0), Vector3(hull_len - 0.4, 0.1, WIDTH - 0.4), DECK_COLOR])
	# A white stripe along the hull.
	b.append([Vector3(mid, 4.6, 0), Vector3(hull_len + 0.02, 0.25, WIDTH + 0.02), WHITE])
	# Bridge with a band of windows, wings, and the funnel.
	b.append([Vector3(-11.5, DECK + 3.5, 0), Vector3(5.0, 7.0, 6.8), WHITE])
	b.append([Vector3(-11.5, DECK + 6.0, 0), Vector3(5.06, 1.0, 6.86), GLASS])
	b.append([Vector3(-10.0, DECK + 6.6, 0), Vector3(2.0, 0.3, WIDTH + 1.6), WHITE])
	b.append([Vector3(-12.6, DECK + 8.2, 0), Vector3(1.6, 2.4, 1.6), RED])
	b.append([Vector3(-12.6, DECK + 9.6, 0), Vector3(1.7, 0.4, 1.7), Color(0.1, 0.1, 0.1)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for x: float in STACK_X:
		for z: float in STACK_Z:
			var count := rng.randi_range(1, 3)
			for k in count:
				var c: Color = CONTAINERS[rng.randi() % CONTAINERS.size()]
				var y := DECK + CONTAINER.y * (k + 0.5)
				b.append([Vector3(x, y, z), CONTAINER - Vector3(0.05, 0.04, 0.05), c])
	_boxes = b
	return _boxes


## Collision: the hull, the bow, the bridge and each container stack as one box.
static func collision_boxes() -> Array:
	var boxes: Array = [[Vector3((14.0 + STERN) * 0.5, HULL_HEIGHT * 0.5, 0), Vector3(14.0 - STERN, HULL_HEIGHT, WIDTH)],
			[Vector3(15.3, 3.0, 0), Vector3(3.0, 5.0, 4.4)],
			[Vector3(-11.5, DECK + 3.5, 0), Vector3(5.0, 7.0, 6.8)]]
	var tops := {}
	for part: Array in parts():
		var size: Vector3 = part[1]
		if size == CONTAINER - Vector3(0.05, 0.04, 0.05):
			var key := Vector2(part[0].x, part[0].z)
			tops[key] = maxf(tops.get(key, 0.0), part[0].y + size.y * 0.5)
	for key: Vector2 in tops:
		var top: float = tops[key]
		boxes.append([Vector3(key.x, (DECK + top) * 0.5, key.y), Vector3(CONTAINER.x, top - DECK, CONTAINER.z)])
	return boxes


static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts():
		_box(st, part[0], part[1], part[2])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.65
	mat.metallic = 0.15
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	# u x v = -normal for every face, so one corner order is Godot's front face.
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var c := center + n * h
		var corners := [c - u * h - v * h, c + u * h - v * h, c + u * h + v * h, c - u * h + v * h]
		# Container doors and hull plates: a little darker toward the bottom.
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(color.darkened(0.12) if k < 2 else color)
			st.set_normal(n)
			st.add_vertex(corners[k])
