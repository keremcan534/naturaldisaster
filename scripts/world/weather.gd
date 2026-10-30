extends Node3D
## Sky, sun, sea and the mood they set. Disasters pick a mood (see MOODS); the
## weather blends into it over a few seconds and back to "clear" between rounds.
## Storms add rain around the camera and lightning flashes. Sky colors are global
## shader uniforms (project.godot [shader_globals]) so water and glass can reflect them.

const Look := preload("res://scripts/world/look.gd")
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const SEA_SHADER := preload("res://shaders/sea.gdshader")

const SEA_LEVEL := -2.5
const BLEND_TIME := 4.0
const RAIN_DROPS := 400
## Sea mesh: rings spaced wider with distance, so swells near the island get detail.
const SEA_RADIUS := 1000.0
const SEA_RINGS := 110
const SEA_SEGMENTS := 128

## top/horizon: sky colors (the fog uses horizon), haze: far sea, sun: color and
## energy, fog: density, saturation: color adjustment, clouds: cover and lit/shaded
## colors, wind: grass and trees, waves: swell height, rooms: how bright lit windows glow,
## rain/lightning: storm effects.
const MOODS := {
	"clear": {
		"wind": 0.35,
		"clouds": 0.42, "cloud_light": Color(1.0, 0.98, 0.95), "cloud_dark": Color(0.6, 0.66, 0.74), "waves": 0.55, "rooms": 0.15,
		"saturation": 1.08,
		"top": Color(0.18, 0.38, 0.72), "horizon": Color(0.66, 0.76, 0.86), "haze": Color(0.32, 0.48, 0.62),
		"sun": Color(1.0, 0.94, 0.84), "energy": 1.0, "ambient": 1.0, "fog": 0.0028, "rain": false, "lightning": false,
	},
	"dust": {
		"wind": 0.6,
		"clouds": 0.3, "cloud_light": Color(0.95, 0.9, 0.8), "cloud_dark": Color(0.7, 0.65, 0.58), "waves": 0.5, "rooms": 0.2,
		"saturation": 0.95,
		"top": Color(0.3, 0.42, 0.6), "horizon": Color(0.78, 0.72, 0.62), "haze": Color(0.5, 0.5, 0.48),
		"sun": Color(1.0, 0.88, 0.72), "energy": 0.85, "ambient": 0.95, "fog": 0.009, "rain": false, "lightning": false,
	},
	"dusk": {
		"wind": 0.3,
		"clouds": 0.5, "cloud_light": Color(1.0, 0.62, 0.42), "cloud_dark": Color(0.32, 0.22, 0.32), "waves": 0.6, "rooms": 0.8,
		"saturation": 1.1,
		"top": Color(0.12, 0.14, 0.3), "horizon": Color(0.82, 0.52, 0.38), "haze": Color(0.3, 0.26, 0.34),
		"sun": Color(1.0, 0.72, 0.52), "energy": 0.8, "ambient": 0.8, "fog": 0.004, "rain": false, "lightning": false,
	},
	"overcast": {
		"wind": 0.8,
		"clouds": 0.85, "cloud_light": Color(0.7, 0.73, 0.76), "cloud_dark": Color(0.36, 0.4, 0.44), "waves": 0.9, "rooms": 0.5,
		"saturation": 0.85,
		"top": Color(0.3, 0.36, 0.44), "horizon": Color(0.56, 0.6, 0.64), "haze": Color(0.26, 0.33, 0.38),
		"sun": Color(0.9, 0.92, 0.95), "energy": 0.5, "ambient": 0.85, "fog": 0.006, "rain": true, "lightning": false,
	},
	"storm": {
		"wind": 1.6,
		"clouds": 0.97, "cloud_light": Color(0.42, 0.44, 0.47), "cloud_dark": Color(0.14, 0.15, 0.17), "waves": 1.4, "rooms": 0.9,
		"saturation": 0.7,
		"top": Color(0.13, 0.15, 0.18), "horizon": Color(0.36, 0.38, 0.4), "haze": Color(0.18, 0.21, 0.23),
		"sun": Color(0.8, 0.85, 0.9), "energy": 0.3, "ambient": 0.65, "fog": 0.011, "rain": true, "lightning": true,
	},
	"ash": {
		"wind": 0.6,
		"clouds": 0.8, "cloud_light": Color(0.55, 0.32, 0.22), "cloud_dark": Color(0.18, 0.12, 0.1), "waves": 0.7, "rooms": 0.7,
		"saturation": 1.0,
		"top": Color(0.22, 0.14, 0.12), "horizon": Color(0.72, 0.38, 0.22), "haze": Color(0.32, 0.18, 0.14),
		"sun": Color(1.0, 0.62, 0.4), "energy": 0.6, "ambient": 0.75, "fog": 0.01, "rain": false, "lightning": false,
	},
}

var _env: Environment
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _rain: CPUParticles3D
## The OpenGL renderer (web builds) lights the same scene noticeably brighter.
var _sun_base := 1.3
var _ambient_base := 1.0

var _top: Color
var _horizon: Color
var _haze: Color
var _ambient := 1.0
var _clouds := 0.4
var _cloud_light: Color
var _cloud_dark: Color
var _wind := 0.3
var _waves := 0.5
var _rooms := 0.2

var _from := {}
var _to := {}
var _blend := 1.0
var _energy := 1.0
var _lightning := false
var _flash := 0.0
var _next_flash := 0.0


func _ready() -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	_sky.set_shader_parameter("noise", Look.noise_texture())

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = Sky.new()
	_env.sky.sky_material = _sky
	# Lighting doesn't sample the sky (no radiance re-bakes while clouds move or
	# a mood blends); ambient is a color from the mood, and water/glass reflect
	# the sky colors in their own shaders.
	_env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	# Distance haze ties the sea into the horizon and gives depth.
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = 0.4
	# Bloom on the bright stuff: lava, fire, the sun on water.
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.1
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42, -35, 0)
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 90.0
	add_child(_sun)

	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_sun_base = 1.0
		_ambient_base = 0.8
		_env.tonemap_exposure = 0.8

	var sea := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = SEA_SHADER
	mat.set_shader_parameter("noise", Look.noise_texture())
	sea.mesh = _sea_mesh()
	sea.material_override = mat
	# Swells move the vertices; don't let culling clip them.
	sea.extra_cull_margin = 4.0
	sea.position.y = SEA_LEVEL
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

	_rain = _make_rain()
	add_child(_rain)

	_to = MOODS.clear
	_apply(_to, _to, 1.0)


## Starts blending toward one of MOODS.
func set_mood(mood: String) -> void:
	var target: Dictionary = MOODS.get(mood, MOODS.clear)
	if target == _to:
		return
	_from = _snapshot()
	_to = target
	_blend = 0.0
	_lightning = target.lightning
	_rain.emitting = target.rain


func _process(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(_blend + delta / BLEND_TIME, 1.0)
		_apply(_from, _to, smoothstep(0.0, 1.0, _blend))

	if _lightning and _blend > 0.5:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = randf_range(2.5, 7.0)
			_flash = 1.0
	# Flicker: two quick pulses as it fades.
	_flash = maxf(_flash - delta * 3.0, 0.0)
	var flicker := _flash * (1.0 if fmod(_flash, 0.4) > 0.15 else 0.3)
	_sun.light_energy = _sun_base * _energy + flicker * 2.5
	_sky.set_shader_parameter("flash", flicker * 1.5)

	var camera := get_viewport().get_camera_3d()
	if camera and _rain.emitting:
		var ahead := -camera.global_basis.z
		_rain.global_position = camera.global_position + Vector3(ahead.x * 8.0, 14.0, ahead.z * 8.0)


func _apply(a: Dictionary, b: Dictionary, t: float) -> void:
	var top: Color = a.top.lerp(b.top, t)
	var horizon: Color = a.horizon.lerp(b.horizon, t)
	var haze: Color = a.haze.lerp(b.haze, t)
	_top = top
	_horizon = horizon
	_haze = haze
	RenderingServer.global_shader_parameter_set("sky_top", top)
	RenderingServer.global_shader_parameter_set("sky_horizon", horizon)
	RenderingServer.global_shader_parameter_set("sea_haze", haze)
	_clouds = lerpf(a.clouds, b.clouds, t)
	_cloud_light = (a.cloud_light as Color).lerp(b.cloud_light, t)
	_cloud_dark = (a.cloud_dark as Color).lerp(b.cloud_dark, t)
	_sky.set_shader_parameter("cloud_cover", _clouds)
	_sky.set_shader_parameter("cloud_light", _cloud_light)
	_sky.set_shader_parameter("cloud_dark", _cloud_dark)
	_wind = lerpf(a.wind, b.wind, t)
	RenderingServer.global_shader_parameter_set("wind", _wind)
	_waves = lerpf(a.waves, b.waves, t)
	RenderingServer.global_shader_parameter_set("wave_height", _waves)
	_rooms = lerpf(a.rooms, b.rooms, t)
	RenderingServer.global_shader_parameter_set("room_light", _rooms)
	_env.fog_light_color = horizon
	_env.fog_density = lerpf(a.fog, b.fog, t)
	_ambient = lerpf(a.ambient, b.ambient, t)
	_env.ambient_light_energy = _ambient_base * _ambient
	# Mostly neutral with a touch of the sky, so shaded sides don't turn deep blue.
	_env.ambient_light_color = Color(0.72, 0.7, 0.66).lerp(top.lerp(horizon, 0.6), 0.4)
	_sun.light_color = (a.sun as Color).lerp(b.sun, t)
	_energy = lerpf(a.energy, b.energy, t)
	_env.adjustment_saturation = lerpf(a.saturation, b.saturation, t)


## Tells the sea where the island's shore is (for foam and shallow water).
func set_island(half_size: float) -> void:
	RenderingServer.global_shader_parameter_set("island_half", half_size)


func _snapshot() -> Dictionary:
	return {
		"top": _top, "horizon": _horizon, "haze": _haze, "sun": _sun.light_color, "energy": _energy,
		"ambient": _ambient, "fog": _env.fog_density, "saturation": _env.adjustment_saturation,
		"clouds": _clouds, "cloud_light": _cloud_light, "cloud_dark": _cloud_dark, "wind": _wind, "waves": _waves, "rooms": _rooms,
	}


## A disc of rings around the island, denser near the middle.
func _sea_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.append(Vector3.ZERO)
	for ring in range(1, SEA_RINGS + 1):
		var r := SEA_RADIUS * pow(float(ring) / SEA_RINGS, 2.2)
		for seg in SEA_SEGMENTS:
			var a := TAU * seg / SEA_SEGMENTS
			verts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for seg in SEA_SEGMENTS:
		indices.append_array([0, 1 + seg, 1 + (seg + 1) % SEA_SEGMENTS])
	for ring in range(1, SEA_RINGS):
		var inner := 1 + (ring - 1) * SEA_SEGMENTS
		var outer := inner + SEA_SEGMENTS
		for seg in SEA_SEGMENTS:
			var next := (seg + 1) % SEA_SEGMENTS
			indices.append_array([inner + seg, outer + seg, inner + next])
			indices.append_array([inner + next, outer + seg, outer + next])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Streaks falling in a box that follows the camera.
func _make_rain() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.8)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.75, 0.8, 0.85, 0.35)
	quad.material = mat
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.amount = RAIN_DROPS
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 1, 18)
	p.direction = Vector3(0.1, -1, 0.05)
	p.spread = 3.0
	p.initial_velocity_min = 24.0
	p.initial_velocity_max = 28.0
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
