extends MeshInstance3D
## A blocky character 1.75 m tall, facing -Z, feet at the origin: shirt, pants,
## skin, shoes, hair and an optional hard hat. One shared mesh; each avatar has
## its own small material for its colors and pose (see shaders/avatar.gdshader).

const SHADER := preload("res://shaders/avatar.gdshader")

const SKIN_TONES := [Color(0.96, 0.8, 0.66), Color(0.87, 0.67, 0.5), Color(0.7, 0.5, 0.36), Color(0.48, 0.33, 0.24)]
const PANTS := [Color(0.16, 0.18, 0.26), Color(0.25, 0.22, 0.2), Color(0.12, 0.12, 0.13), Color(0.3, 0.35, 0.45)]

## Limb ids and color slots, matching the shader.
enum Part { BODY, LEFT_LEG, RIGHT_LEG, LEFT_ARM, RIGHT_ARM, HAT }
enum Slot { SHIRT, PANTS, SKIN, DARK, HAT }

static var _mesh: ArrayMesh

var _material: ShaderMaterial
var _phase := 0.0
var _swing := 0.0
var _arms := 0.0


func _init() -> void:
	mesh = _get_mesh()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material


func set_colors(shirt: Color, pants: Color, skin: Color) -> void:
	_material.set_shader_parameter("shirt", shirt)
	_material.set_shader_parameter("pants", pants)
	_material.set_shader_parameter("skin", skin)


func set_hat(on: bool) -> void:
	_material.set_shader_parameter("hat_on", 1.0 if on else 0.0)


## Call every frame: speed in m/s on the ground (0 in the air or standing),
## arms_up 0..1 to raise both arms.
func animate(delta: float, speed: float, arms_up: float) -> void:
	_phase += speed * delta * 2.2
	var target := sin(_phase) * clampf(speed / 4.5, 0.0, 1.0) * 0.7
	_swing = lerpf(_swing, target, minf(delta * 12.0, 1.0))
	_arms = move_toward(_arms, arms_up, delta * 4.0)
	_material.set_shader_parameter("swing", _swing)
	_material.set_shader_parameter("arms_up", _arms)


static func _get_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var leg := Part.LEFT_LEG if side < 0.0 else Part.RIGHT_LEG
		var arm := Part.LEFT_ARM if side < 0.0 else Part.RIGHT_ARM
		_box(st, Vector3(side * 0.12, 0.47, 0), Vector3(0.21, 0.7, 0.23), leg, Slot.PANTS)
		_box(st, Vector3(side * 0.12, 0.06, -0.025), Vector3(0.22, 0.12, 0.28), leg, Slot.DARK)
		_box(st, Vector3(side * 0.325, 1.27, 0), Vector3(0.16, 0.3, 0.18), arm, Slot.SHIRT)
		_box(st, Vector3(side * 0.325, 0.98, 0), Vector3(0.14, 0.28, 0.16), arm, Slot.SKIN)
		# Eyes on the front of the head.
		_box(st, Vector3(side * 0.07, 1.6, -0.165), Vector3(0.05, 0.06, 0.02), Part.BODY, Slot.DARK)
	_box(st, Vector3(0, 1.11, 0), Vector3(0.49, 0.59, 0.27), Part.BODY, Slot.SHIRT)
	_box(st, Vector3(0, 1.575, 0), Vector3(0.32, 0.31, 0.32), Part.BODY, Slot.SKIN)
	_box(st, Vector3(0, 1.75, 0.02), Vector3(0.34, 0.06, 0.34), Part.BODY, Slot.DARK)
	_box(st, Vector3(0, 1.62, 0.15), Vector3(0.34, 0.2, 0.06), Part.BODY, Slot.DARK)
	# A hard hat (hidden unless set_hat): dome and brim.
	_box(st, Vector3(0, 1.82, 0.0), Vector3(0.38, 0.12, 0.38), Part.HAT, Slot.HAT)
	_box(st, Vector3(0, 1.77, -0.04), Vector3(0.44, 0.03, 0.48), Part.HAT, Slot.HAT)
	_mesh = st.commit()
	return _mesh


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, part: int, slot: int) -> void:
	var h := size * 0.5
	var uv := Vector2(part, slot)
	# Each face: its normal and two in-plane axes with u x v = -normal, so the
	# same corner order is clockwise (Godot's front face) seen from outside.
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
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv)
			st.add_vertex(corners[k])
