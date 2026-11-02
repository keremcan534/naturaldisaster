extends RefCounted
## What the shield power-up (pickups.gd POWERS) looks like on a character: a
## see-through blue bubble. The mesh and material are shared by everyone; each
## character gets its own hidden node at start (nothing is created during a round).

const SHIELD_SHADER := preload("res://shaders/shield.gdshader")

static var _bubble_mesh: Mesh


## A bubble around the whole body.
static func bubble() -> MeshInstance3D:
	if _bubble_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 1.15
		sphere.height = 2.3
		sphere.radial_segments = 20
		sphere.rings = 10
		var material := ShaderMaterial.new()
		material.shader = SHIELD_SHADER
		sphere.material = material
		_bubble_mesh = sphere
	var node := MeshInstance3D.new()
	node.mesh = _bubble_mesh
	node.position.y = 0.9
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	return node
