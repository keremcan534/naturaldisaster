extends Node3D
## Sky, sun, sea and the mood they set. Disasters pick a mood (see MOODS); the
## weather blends into it over a few seconds and back to "clear" between rounds.
## Storms add rain around the camera and lightning flashes.

const Look := preload("res://scripts/world/look.gd")

const SEA_LEVEL := -2.5
const BLEND_TIME := 4.0
const RAIN_DROPS := 400

## top/horizon: sky colors (the fog uses horizon), haze: far sea, sun: color and
## energy, fog: density, saturation: color adjustment, rain/lightning: storm effects.
const MOODS := {
	"clear": {
		"saturation": 1.08,
		"top": Color(0.18, 0.38, 0.72), "horizon": Color(0.66, 0.76, 0.86), "haze": Color(0.32, 0.48, 0.62),
		"sun": Color(1.0, 0.94, 0.84), "energy": 1.0, "ambient": 1.0, "fog": 0.0028, "rain": false, "lightning": false,
	},
	"dust": {
		"saturation": 0.95,
		"top": Color(0.3, 0.42, 0.6), "horizon": Color(0.78, 0.72, 0.62), "haze": Color(0.5, 0.5, 0.48),
		"sun": Color(1.0, 0.88, 0.72), "energy": 0.85, "ambient": 0.95, "fog": 0.009, "rain": false, "lightning": false,
	},
	"dusk": {
		"saturation": 1.1,
		"top": Color(0.12, 0.14, 0.3), "horizon": Color(0.82, 0.52, 0.38), "haze": Color(0.3, 0.26, 0.34),
		"sun": Color(1.0, 0.72, 0.52), "energy": 0.8, "ambient": 0.8, "fog": 0.004, "rain": false, "lightning": false,
	},
	"overcast": {
		"saturation": 0.85,
		"top": Color(0.3, 0.36, 0.44), "horizon": Color(0.56, 0.6, 0.64), "haze": Color(0.26, 0.33, 0.38),
		"sun": Color(0.9, 0.92, 0.95), "energy": 0.5, "ambient": 0.85, "fog": 0.006, "rain": true, "lightning": false,
	},
	"storm": {
		"saturation": 0.7,
		"top": Color(0.13, 0.15, 0.18), "horizon": Color(0.36, 0.38, 0.4), "haze": Color(0.18, 0.21, 0.23),
		"sun": Color(0.8, 0.85, 0.9), "energy": 0.3, "ambient": 0.65, "fog": 0.011, "rain": true, "lightning": true,
	},
	"ash": {
		"saturation": 1.0,
		"top": Color(0.22, 0.14, 0.12), "horizon": Color(0.72, 0.38, 0.22), "haze": Color(0.32, 0.18, 0.14),
		"sun": Color(1.0, 0.62, 0.4), "energy": 0.6, "ambient": 0.75, "fog": 0.01, "rain": false, "lightning": false,
	},
}

var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _sea: ShaderMaterial
var _rain: CPUParticles3D
## The OpenGL renderer (web builds) lights the same scene noticeably brighter.
var _sun_base := 1.3
var _ambient_base := 1.0

var _from := {}
var _to := {}
var _blend := 1.0
var _energy := 1.0
var _lightning := false
var _flash := 0.0
var _next_flash := 0.0


func _ready() -> void:
	_sky = ProceduralSkyMaterial.new()
	# Below the horizon the sky shows past the sea's far edge; it takes the far sea color.
	_sky.ground_curve = 0.3
	_sky.sky_curve = 0.12
	_sky.sun_angle_max = 20.0
	_sky.sun_curve = 0.1

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = Sky.new()
	_env.sky.sky_material = _sky
	# The sky is re-baked while a mood blends; keep that cheap.
	_env.sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Half sky, half neutral, so shaded sides don't turn deep blue.
	_env.ambient_light_color = Color(0.72, 0.7, 0.66)
	_env.ambient_light_sky_contribution = 0.5
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
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
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	_sea = Look.water()
	plane.material = _sea
	sea.mesh = plane
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
	_env.background_energy_multiplier = 1.0 + flicker * 1.5

	var camera := get_viewport().get_camera_3d()
	if camera and _rain.emitting:
		var ahead := -camera.global_basis.z
		_rain.global_position = camera.global_position + Vector3(ahead.x * 8.0, 14.0, ahead.z * 8.0)


func _apply(a: Dictionary, b: Dictionary, t: float) -> void:
	var top: Color = a.top.lerp(b.top, t)
	var horizon: Color = a.horizon.lerp(b.horizon, t)
	var haze: Color = a.haze.lerp(b.haze, t)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon
	_sky.ground_bottom_color = haze
	_sea.set_shader_parameter("sky_color", haze)
	_env.fog_light_color = horizon
	_env.fog_density = lerpf(a.fog, b.fog, t)
	_env.ambient_light_energy = _ambient_base * lerpf(a.ambient, b.ambient, t)
	_sun.light_color = (a.sun as Color).lerp(b.sun, t)
	_energy = lerpf(a.energy, b.energy, t)
	_env.adjustment_saturation = lerpf(a.saturation, b.saturation, t)


func _snapshot() -> Dictionary:
	return {
		"top": _sky.sky_top_color, "horizon": _sky.sky_horizon_color, "haze": _sky.ground_bottom_color,
		"sun": _sun.light_color, "energy": _energy, "ambient": _env.ambient_light_energy / _ambient_base,
		"fog": _env.fog_density, "saturation": _env.adjustment_saturation,
	}


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
