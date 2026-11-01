extends Node3D
## Shader warm-up. On the web every shader is compiled the first time it is
## drawn, which freezes the game for a moment: the first explosion, the first
## tornado, the first fire. This draws one tiny example of every effect's
## material right in front of the menu camera for a few frames, so all of that
## compiling happens once, behind the main menu, instead of mid-disaster.

const Look := preload("res://scripts/world/look.gd")
const SHADERS := [
	preload("res://shaders/tornado.gdshader"),
	preload("res://shaders/tornado_cloud.gdshader"),
	preload("res://shaders/gas.gdshader"),
]
## Shaders drawn through MultiMeshes with custom data (instanced variant).
const INSTANCED := [
	preload("res://shaders/tornado_dust.gdshader"),
	preload("res://shaders/flame.gdshader"),
]
const SHIMMER := preload("res://shaders/heat_shimmer.gdshader")
const FRAMES := 4

var _left := FRAMES


## Starts in front of camera; frees itself after a few frames.
func run(camera: Camera3D) -> void:
	global_transform = camera.global_transform.translated_local(Vector3(0, 0, -1.5))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.004, 0.004)
	var materials: Array[Material] = [Look.lava(), Look.tsunami_water(), Look.water(), Look.shard(),
			Look.surface(Look.GLASS_KEY), Look.surface(Look.CAR_GLASS_KEY), Look.tinted()]
	for shader: Shader in SHADERS:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("noise", Look.noise_texture())
		materials.append(mat)
	for kind in 4:
		var mat := StandardMaterial3D.new()
		match kind:
			0:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			1:
				mat.emission_enabled = true
			2:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			3:
				mat.vertex_color_use_as_albedo = true
		materials.append(mat)
	for mat in materials:
		var mesh := MeshInstance3D.new()
		mesh.mesh = quad
		mesh.material_override = mat
		add_child(mesh)
	for shader: Shader in INSTANCED:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.01), Vector3.ZERO))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = mat
		add_child(instance)
	# Particle sprites (dust, smoke, sparks, ash, sand).
	var puff := CPUParticles3D.new()
	var sprite_quad := QuadMesh.new()
	sprite_quad.size = Vector2(0.004, 0.004)
	sprite_quad.material = Look.sprite()
	puff.mesh = sprite_quad
	puff.amount = 1
	puff.lifetime = 1.0
	puff.gravity = Vector3.ZERO
	add_child(puff)
	# The heat haze: a full-screen canvas shader.
	var layer := CanvasLayer.new()
	layer.layer = -10
	var rect := ColorRect.new()
	rect.size = Vector2(2, 2)
	var shimmer := ShaderMaterial.new()
	shimmer.shader = SHIMMER
	rect.material = shimmer
	layer.add_child(rect)
	add_child(layer)


func _process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		queue_free()
