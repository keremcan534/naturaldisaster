extends RefCounted
## The shared look of the world: procedural textures and cached materials. Textures
## are generated once on first use, so there are no image files to import and no
## allocations during a round.

const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const TSUNAMI_SHADER := preload("res://shaders/tsunami.gdshader")
const LAVA_SHADER := preload("res://shaders/lava.gdshader")
const WINDOW_SHADER := preload("res://shaders/window.gdshader")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const LEAVES_SHADER := preload("res://shaders/leaves.gdshader")
const MAX_SHADES := 16

const ROCK_COLOR := Color(0.42, 0.36, 0.3)
## Pieces whose color is this get the glass material (see Structure).
const GLASS_KEY := Color(0.25, 0.35, 0.45)
## Plain dark glass without a frame (car windows).
const CAR_GLASS_KEY := Color(0.12, 0.15, 0.18)

static var _noise: Texture2D
static var _puff: Texture2D
static var _sprites := {}
static var _panel: Texture2D
static var _surfaces := {}
static var _grounds := {}
static var _leaves := {}
static var _canopies := {}
static var _trunks := {}
static var _shard: StandardMaterial3D
static var _grass: ShaderMaterial
static var _tuft: ArrayMesh


## Box pieces: the color times a plaster-like panel texture with darkened edges.
## BoxMesh lays its six faces out on a 3x2 UV grid, so a (3, 2) scale gives every
## face the whole texture.
static func surface(color: Color) -> Material:
	if not _surfaces.has(color):
		if color == GLASS_KEY:
			var window := ShaderMaterial.new()
			window.shader = WINDOW_SHADER
			_surfaces[color] = window
			return window
		var mat := StandardMaterial3D.new()
		if color == CAR_GLASS_KEY:
			mat.albedo_color = color
			mat.roughness = 0.08
			mat.metallic = 0.4
		else:
			mat.albedo_color = color
			mat.albedo_texture = _panel_texture()
			mat.roughness = 0.85
		mat.uv1_scale = Vector3(3, 2, 1)
		_surfaces[color] = mat
	return _surfaces[color]


## Broken glass: see-through, glinting.
static func shard() -> StandardMaterial3D:
	if _shard == null:
		_shard = StandardMaterial3D.new()
		_shard.albedo_color = Color(0.7, 0.85, 0.9, 0.45)
		_shard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shard.roughness = 0.05
		_shard.metallic_specular = 1.0
		_shard.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shard


## Grass, plaza, paths. road_size (width, length) adds lane markings.
static func ground(color: Color, road_size := Vector2.ZERO) -> Material:
	var key := [color, road_size]
	if not _grounds.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = GROUND_SHADER
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("noise", noise_texture())
		mat.set_shader_parameter("road_size", road_size)
		if road_size != Vector2.ZERO:
			mat.set_shader_parameter("contrast", 0.2)
			mat.set_shader_parameter("scale", 0.3)
		_grounds[key] = mat
	return _grounds[key]


## Contact shadows on every ground material: one Rect2 (x/z) per building, tree or car.
static func set_shades(rects: Array[Rect2]) -> void:
	var packed := PackedVector4Array()
	for r: Rect2 in rects.slice(0, MAX_SHADES):
		var c := r.get_center()
		packed.append(Vector4(c.x, c.y, r.size.x * 0.5, r.size.y * 0.5))
	packed.resize(MAX_SHADES)
	for mat: ShaderMaterial in _grounds.values():
		mat.set_shader_parameter("shade_rects", packed)
		mat.set_shader_parameter("shade_count", mini(rects.size(), MAX_SHADES))


## Rock seen from the side (island cliffs, the volcano).
static func cliff(color := ROCK_COLOR) -> Material:
	var key := ["cliff", color]
	if not _grounds.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = GROUND_SHADER
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("noise", noise_texture())
		mat.set_shader_parameter("vertical", true)
		mat.set_shader_parameter("scale", 0.2)
		mat.set_shader_parameter("contrast", 0.5)
		_grounds[key] = mat
	return _grounds[key]


## Flat water (pools). The sea is set up in weather.gd.
static func water() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("noise", noise_texture())
	mat.set_shader_parameter("ripple_strength", 0.12)
	mat.set_shader_parameter("deep_color", Color(0.05, 0.32, 0.45))
	mat.set_shader_parameter("shallow_color", Color(0.15, 0.6, 0.68))
	return mat


## The tsunami's breaking wave (fresh material: the disaster animates it).
static func tsunami_water() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TSUNAMI_SHADER
	mat.set_shader_parameter("noise", noise_texture())
	return mat


## Fresh material, so a disaster can fade its "energy".
static func lava() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LAVA_SHADER
	mat.set_shader_parameter("noise", noise_texture())
	return mat


## A canopy blob filling a box of this size (slightly bigger, so blobs merge).
static func canopy(box_size: Vector3, color: Color) -> Mesh:
	var key := [box_size, color]
	if not _canopies.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = box_size.x * 0.6
		mesh.height = box_size.y * 1.25
		mesh.radial_segments = 14
		mesh.rings = 8
		if not _leaves.has(color):
			var mat := ShaderMaterial.new()
			mat.shader = LEAVES_SHADER
			mat.set_shader_parameter("noise", noise_texture())
			mat.set_shader_parameter("leaf_color", color)
			_leaves[color] = mat
		mesh.material = _leaves[color]
		_canopies[key] = mesh
	return _canopies[key]


static func trunk(box_size: Vector3, color: Color) -> Mesh:
	var key := [box_size, color]
	if not _trunks.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = box_size.x * 0.32
		mesh.bottom_radius = box_size.x * 0.48
		mesh.height = box_size.y
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.material = surface(color)
		_trunks[key] = mesh
	return _trunks[key]


static func grass_material(color: Color) -> ShaderMaterial:
	if _grass == null:
		_grass = ShaderMaterial.new()
		_grass.shader = GRASS_SHADER
		_grass.set_shader_parameter("noise", noise_texture())
	_grass.set_shader_parameter("root_color", color.darkened(0.2))
	_grass.set_shader_parameter("tip_color", color.lerp(Color(0.62, 0.66, 0.3), 0.35))
	return _grass


## A tuft of eight blades fanned around the origin; UV.y runs 0 (root) to 1 (tip).
static func grass_tuft() -> ArrayMesh:
	if _tuft == null:
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for b in 8:
			var a := TAU * b / 8.0 + rng.randf_range(-0.4, 0.4)
			var side := Vector3(cos(a), 0, sin(a)) * 0.022
			var base := Vector3(-sin(a), 0, cos(a)) * rng.randf_range(0.03, 0.2)
			var lean := Vector3(-sin(a), 0, cos(a)) * rng.randf_range(0.05, 0.18)
			var h := rng.randf_range(0.22, 0.45)
			var mid := base + lean * 0.4 + Vector3(0, h * 0.5, 0)
			var top := base + lean + Vector3(0, h, 0)
			verts.append_array([base - side, base + side, mid - side * 0.7, base + side, mid + side * 0.7, mid - side * 0.7,
					mid - side * 0.7, mid + side * 0.7, top])
			uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(1, 0), Vector2(1, 0.5), Vector2(0, 0.5),
					Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 1)])
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		normals.fill(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		_tuft = ArrayMesh.new()
		_tuft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _tuft


## Camera-facing particle quads tinted by the particles' color ramp. A brightness
## above 1 makes them glow (fire, sparks).
static func sprite(brightness := 1.0, soft := true) -> StandardMaterial3D:
	var key := [brightness, soft]
	if not _sprites.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(brightness, brightness, brightness)
		if soft:
			mat.albedo_texture = puff_texture()
		_sprites[key] = mat
	return _sprites[key]


## A soft round puff for smoke, dust and fire.
static func puff_texture() -> Texture2D:
	if _puff == null:
		var puff := GradientTexture2D.new()
		puff.width = 64
		puff.height = 64
		puff.fill = GradientTexture2D.FILL_RADIAL
		puff.fill_from = Vector2(0.5, 0.5)
		puff.fill_to = Vector2(0.5, 0.0)
		puff.gradient = Gradient.new()
		puff.gradient.set_color(0, Color.WHITE)
		puff.gradient.set_color(1, Color(1, 1, 1, 0))
		puff.gradient.add_point(0.5, Color(1, 1, 1, 0.45))
		_puff = puff
	return _puff


## Gradient for a particle color ramp: evenly spaced colors.
static func ramp(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	return gradient


## Curve rising from start to 1 (particle size over lifetime).
static func grow(start: float) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0, start), 0, 1.0 - start)
	curve.add_point(Vector2(1, 1))
	return curve


## Seamless 0..1 noise, sampled linearly by the shaders.
static func noise_texture() -> Texture2D:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.03
		noise.fractal_octaves = 4
		var image := noise.get_seamless_image(256, 256)
		image.convert(Image.FORMAT_L8)
		image.generate_mipmaps()
		_noise = ImageTexture.create_from_image(image)
	return _noise


static func _panel_texture() -> Texture2D:
	if _panel == null:
		var size := 64
		var noise := FastNoiseLite.new()
		noise.frequency = 0.12
		noise.fractal_octaves = 3
		var src := noise.get_seamless_image(size, size)
		src.convert(Image.FORMAT_L8)
		var data := src.get_data()
		for y in size:
			for x in size:
				var edge := minf(minf(x, size - 1 - x), minf(y, size - 1 - y)) / (size * 0.08)
				var shade := lerpf(0.86, 1.0, data[y * size + x] / 255.0) * lerpf(0.8, 1.0, clampf(edge, 0.0, 1.0))
				data[y * size + x] = int(shade * 255.0)
		var image := Image.create_from_data(size, size, false, Image.FORMAT_L8, data)
		image.generate_mipmaps()
		_panel = ImageTexture.create_from_image(image)
	return _panel
