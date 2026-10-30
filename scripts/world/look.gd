extends RefCounted
## The shared look of the world: procedural textures and cached materials. Textures
## are generated once on first use, so there are no image files to import and no
## allocations during a round.

const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const CLEAR_WATER_SHADER := preload("res://shaders/water_clear.gdshader")
const LAVA_SHADER := preload("res://shaders/lava.gdshader")

const WINDOW_GLASS := Color(0.16, 0.24, 0.32)
const WINDOW_FRAME := Color(0.88, 0.87, 0.84)
const ROCK_COLOR := Color(0.42, 0.36, 0.3)
## Pieces whose color is this get the glass material (see Structure).
const GLASS_KEY := Color(0.25, 0.35, 0.45)
## Plain dark glass without a frame (car windows).
const CAR_GLASS_KEY := Color(0.12, 0.15, 0.18)

static var _noise: Texture2D
static var _panel: Texture2D
static var _window: Texture2D
static var _surfaces := {}
static var _grounds := {}


## Box pieces: the color times a plaster-like panel texture with darkened edges.
## BoxMesh lays its six faces out on a 3x2 UV grid, so a (3, 2) scale gives every
## face the whole texture.
static func surface(color: Color) -> Material:
	if not _surfaces.has(color):
		var mat := StandardMaterial3D.new()
		if color == GLASS_KEY:
			mat.albedo_texture = _window_texture()
			mat.roughness = 0.12
			mat.metallic = 0.3
			mat.metallic_specular = 0.8
		elif color == CAR_GLASS_KEY:
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


## Opaque water for the sea and pools; clear water for floods (fresh material, so
## a disaster can animate its parameters).
static func water(clear := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CLEAR_WATER_SHADER if clear else WATER_SHADER
	mat.set_shader_parameter("noise", noise_texture())
	return mat


## Fresh material, so a disaster can fade its "energy".
static func lava() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LAVA_SHADER
	mat.set_shader_parameter("noise", noise_texture())
	return mat


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


## A window pane: light frame, a mullion cross, glass darker toward the bottom.
static func _window_texture() -> Texture2D:
	if _window == null:
		var size := 64
		var image := Image.create(size, size, false, Image.FORMAT_RGB8)
		var frame := 5
		var bar := 2
		var mid := size / 2
		for y in size:
			for x in size:
				var border := x < frame or y < frame or x >= size - frame or y >= size - frame
				var cross := absi(x - mid) < bar or absi(y - mid + 6) < bar
				if border or cross:
					image.set_pixel(x, y, WINDOW_FRAME)
				else:
					var glare := 0.12 if (x + y) % 40 < 9 else 0.0
					image.set_pixel(x, y, WINDOW_GLASS.lightened(0.25 * (1.0 - float(y) / size) + glare))
		image.generate_mipmaps()
		_window = ImageTexture.create_from_image(image)
	return _window
