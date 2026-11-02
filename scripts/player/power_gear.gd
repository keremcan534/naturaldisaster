extends RefCounted
## What power-ups (pickups.gd POWERS) look like on a character: a pink balloon
## on a string above the head, and a see-through blue shield bubble. Meshes and
## materials are shared by everyone; each character gets its own two hidden
## nodes at start (nothing is created during a round).

const SHIELD_SHADER := preload("res://shaders/shield.gdshader")

static var _balloon_mesh: Mesh
static var _string_mesh: Mesh
static var _bubble_mesh: Mesh


## A balloon tied above the head (local to a character whose feet are at the origin).
static func balloon() -> Node3D:
	if _balloon_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.38
		sphere.height = 0.95
		sphere.radial_segments = 14
		sphere.rings = 8
		var rubber := StandardMaterial3D.new()
		rubber.albedo_color = Color(1.0, 0.35, 0.65)
		rubber.roughness = 0.25
		rubber.emission_enabled = true
		rubber.emission = Color(0.5, 0.1, 0.3)
		sphere.material = rubber
		_balloon_mesh = sphere
		var line := CylinderMesh.new()
		line.top_radius = 0.008
		line.bottom_radius = 0.008
		line.height = 1.1
		line.radial_segments = 4
		line.rings = 1
		var white := StandardMaterial3D.new()
		white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		white.albedo_color = Color(0.92, 0.92, 0.92)
		line.material = white
		_string_mesh = line
	var holder := Node3D.new()
	var ball := MeshInstance3D.new()
	ball.mesh = _balloon_mesh
	ball.position = Vector3(0.25, 3.05, 0.1)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ball)
	var line_node := MeshInstance3D.new()
	line_node.mesh = _string_mesh
	line_node.position = Vector3(0.22, 2.1, 0.08)
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(line_node)
	holder.visible = false
	return holder


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
