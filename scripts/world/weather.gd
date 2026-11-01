extends Node3D
## Sky, sun, sea and the mood they set. Each round picks a time of day (TIMES);
## disasters pick a mood (MOODS) that the weather blends into over a few seconds
## and back to "clear" between rounds. A mood's colors are tinted by the time of
## day, so a storm at night is darker than one at noon.
## Rain wets the ground (puddles), storms add lightning bolts, rain ends with a
## rainbow, clear nights get stars and an aurora. Values the shaders share are
## global uniforms (project.godot [shader_globals]).

const Look := preload("res://scripts/world/look.gd")
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const SEA_SHADER := preload("res://shaders/sea.gdshader")

const SEA_LEVEL := -2.5
const BLEND_TIME := 4.0
const RAIN_DROPS := 450
const SPLASHES := 90
## Seconds for the ground to soak through, and to dry.
const WET_TIME := 8.0
const DRY_TIME := 45.0
const RAINBOW_TIME := 40.0
## Sea mesh: rings spaced wider with distance, so swells near the island get detail.
const SEA_RADIUS := 1000.0
const SEA_RINGS := 110
const SEA_SEGMENTS := 128

## Times of day, picked per round (weights in TIME_WEIGHTS). elevation/azimuth
## place the sun (the moon at night); tint colors every mood but "clear", which
## uses the colors here directly.
const TIMES := {
	"morning": {
		"elevation": 17.0, "azimuth": 70.0, "tint": Color(1.0, 0.93, 0.86), "exposure": 1.0, "night": 0.0, "stars": 0.0, "aurora": 0.0,
		"top": Color(0.24, 0.44, 0.74), "horizon": Color(0.88, 0.78, 0.68), "haze": Color(0.42, 0.5, 0.6),
		"sun": Color(1.0, 0.82, 0.62), "energy": 0.95, "ambient": 0.9, "fog": 0.0045, "rooms": 0.25,
		"clouds": 0.38, "cloud_light": Color(1.0, 0.9, 0.82), "cloud_dark": Color(0.55, 0.56, 0.66),
	},
	"day": {
		"elevation": 42.0, "azimuth": -35.0, "tint": Color(1, 1, 1), "exposure": 1.0, "night": 0.0, "stars": 0.0, "aurora": 0.0,
		"top": Color(0.18, 0.38, 0.72), "horizon": Color(0.66, 0.76, 0.86), "haze": Color(0.32, 0.48, 0.62),
		"sun": Color(1.0, 0.94, 0.84), "energy": 1.0, "ambient": 1.0, "fog": 0.0028, "rooms": 0.15,
		"clouds": 0.42, "cloud_light": Color(1.0, 0.98, 0.95), "cloud_dark": Color(0.6, 0.66, 0.74),
	},
	"golden": {
		"elevation": 7.0, "azimuth": -112.0, "tint": Color(1.0, 0.78, 0.62), "exposure": 1.05, "night": 0.0, "stars": 0.0, "aurora": 0.0,
		"top": Color(0.13, 0.2, 0.45), "horizon": Color(1.0, 0.56, 0.32), "haze": Color(0.36, 0.28, 0.32),
		"sun": Color(1.0, 0.52, 0.26), "energy": 0.9, "ambient": 0.75, "fog": 0.0042, "rooms": 0.6,
		"clouds": 0.5, "cloud_light": Color(1.0, 0.58, 0.42), "cloud_dark": Color(0.32, 0.2, 0.3),
	},
	"night": {
		"elevation": 38.0, "azimuth": 140.0, "tint": Color(0.28, 0.33, 0.5), "exposure": 1.55, "night": 1.0, "stars": 1.0, "aurora": 1.0,
		"top": Color(0.012, 0.022, 0.06), "horizon": Color(0.07, 0.1, 0.19), "haze": Color(0.03, 0.05, 0.09),
		"sun": Color(0.62, 0.72, 1.0), "energy": 0.7, "ambient": 0.95, "fog": 0.004, "rooms": 1.0,
		"clouds": 0.3, "cloud_light": Color(0.16, 0.19, 0.27), "cloud_dark": Color(0.04, 0.05, 0.08),
	},

}
const TIME_WEIGHTS := {"morning": 2, "day": 4, "golden": 2, "night": 2}

## Disaster moods. top/horizon: sky colors (the fog uses horizon), haze: far sea,
## sun: color and energy, fog: density, saturation: color adjustment, clouds: cover
## and lit/shaded colors, wind: grass and trees, waves: swell height, rooms: how
## bright indoor lamps glow, rain/lightning: storm effects. "clear" takes its
## colors from the time of day.
const MOODS := {
	"clear": {
		"wind": 0.35, "waves": 0.55, "rooms": 0.15, "saturation": 1.08, "rain": false, "lightning": false,
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
	"sandstorm": {
		"wind": 2.2,
		"clouds": 0.9, "cloud_light": Color(0.85, 0.66, 0.42), "cloud_dark": Color(0.5, 0.36, 0.22), "waves": 1.0, "rooms": 0.6,
		"saturation": 0.9,
		"top": Color(0.62, 0.48, 0.32), "horizon": Color(0.8, 0.62, 0.4), "haze": Color(0.6, 0.46, 0.3),
		"sun": Color(1.0, 0.75, 0.5), "energy": 0.55, "ambient": 0.9, "fog": 0.045, "rain": false, "lightning": false,
	},
	"acid": {
		"wind": 0.9,
		"clouds": 0.92, "cloud_light": Color(0.62, 0.7, 0.45), "cloud_dark": Color(0.25, 0.3, 0.16), "waves": 1.0, "rooms": 0.6,
		"saturation": 0.8,
		"top": Color(0.28, 0.34, 0.2), "horizon": Color(0.6, 0.66, 0.42), "haze": Color(0.3, 0.36, 0.22),
		"sun": Color(0.85, 1.0, 0.7), "energy": 0.45, "ambient": 0.8, "fog": 0.009, "rain": true, "lightning": false,
		"rain_color": Color(0.55, 1.0, 0.25, 0.5),
	},
	"hail": {
		"wind": 1.2,
		"clouds": 0.95, "cloud_light": Color(0.62, 0.65, 0.7), "cloud_dark": Color(0.2, 0.22, 0.26), "waves": 1.1, "rooms": 0.7,
		"saturation": 0.75,
		"top": Color(0.2, 0.23, 0.28), "horizon": Color(0.48, 0.52, 0.57), "haze": Color(0.24, 0.27, 0.3),
		"sun": Color(0.85, 0.9, 0.95), "energy": 0.4, "ambient": 0.75, "fog": 0.008, "rain": true, "lightning": false,
		"rain_color": Color(0.95, 0.97, 1.0, 0.85),
	},
	"heat": {
		"wind": 0.15,
		"clouds": 0.05, "cloud_light": Color(1.0, 0.95, 0.85), "cloud_dark": Color(0.8, 0.7, 0.6), "waves": 0.3, "rooms": 0.1,
		"saturation": 1.15,
		"top": Color(0.45, 0.62, 0.85), "horizon": Color(0.98, 0.9, 0.75), "haze": Color(0.75, 0.7, 0.62),
		"sun": Color(1.0, 0.9, 0.7), "energy": 1.45, "ambient": 1.1, "fog": 0.006, "rain": false, "lightning": false,
	},
	"gas": {
		"wind": 0.2,
		"clouds": 0.7, "cloud_light": Color(0.75, 0.82, 0.6), "cloud_dark": Color(0.35, 0.42, 0.25), "waves": 0.4, "rooms": 0.5,
		"saturation": 0.85,
		"top": Color(0.4, 0.5, 0.42), "horizon": Color(0.66, 0.74, 0.5), "haze": Color(0.4, 0.48, 0.32),
		"sun": Color(0.9, 1.0, 0.8), "energy": 0.7, "ambient": 0.85, "fog": 0.012, "rain": false, "lightning": false,
	},
	"flare": {
		"wind": 0.4,
		"clouds": 0.2, "cloud_light": Color(1.0, 0.95, 0.85), "cloud_dark": Color(0.6, 0.55, 0.65), "waves": 0.6, "rooms": 0.0,
		"saturation": 1.2,
		"top": Color(0.3, 0.32, 0.55), "horizon": Color(0.95, 0.85, 0.7), "haze": Color(0.5, 0.5, 0.6),
		"sun": Color(1.0, 0.95, 0.8), "energy": 1.6, "ambient": 1.0, "fog": 0.003, "rain": false, "lightning": false,
	},
	"snow": {
		"wind": 1.3,
		"clouds": 0.95, "cloud_light": Color(0.88, 0.9, 0.93), "cloud_dark": Color(0.55, 0.58, 0.63), "waves": 0.9, "rooms": 0.7,
		"saturation": 0.7,
		"top": Color(0.62, 0.66, 0.72), "horizon": Color(0.86, 0.88, 0.92), "haze": Color(0.7, 0.74, 0.78),
		"sun": Color(0.92, 0.95, 1.0), "energy": 0.6, "ambient": 1.05, "fog": 0.03, "rain": false, "lightning": false,
	},
	"ash": {
		"wind": 0.6,
		"clouds": 0.8, "cloud_light": Color(0.55, 0.32, 0.22), "cloud_dark": Color(0.18, 0.12, 0.1), "waves": 0.7, "rooms": 0.7,
		"saturation": 1.0,
		"top": Color(0.22, 0.14, 0.12), "horizon": Color(0.72, 0.38, 0.22), "haze": Color(0.32, 0.18, 0.14),
		"sun": Color(1.0, 0.62, 0.4), "energy": 0.6, "ambient": 0.75, "fog": 0.01, "rain": false, "lightning": false,
	},
}
## Blended values (everything compose() returns except the flags).
const BLENDED := ["top", "horizon", "haze", "sun", "energy", "ambient", "fog", "saturation", "clouds", "cloud_light",
		"cloud_dark", "wind", "waves", "rooms", "night", "stars", "aurora", "exposure"]

## Debug: a TIMES key to use every round.
var forced_time := ""

var _env: Environment
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _rain: CPUParticles3D
var _rain_material: StandardMaterial3D
var _splashes: CPUParticles3D
var _bolt: MeshInstance3D
var _bolt_mesh: ImmediateMesh
var _bolt_core: StandardMaterial3D
var _bolt_halo: StandardMaterial3D
var _flare: Control
## The OpenGL renderer (web builds) lights the same scene noticeably brighter.
var _sun_base := 1.3
var _ambient_base := 1.0
var _exposure_base := 1.0

var _time := "day"
var _mood := "clear"
## Current blended values (see BLENDED), and the blend from _from to _to.
var _now := {}
var _from := {}
var _to := {}
var _blend := 1.0
var _wet := 0.0
var _rainbow_age := RAINBOW_TIME
var _flash := 0.0
var _next_flash := 0.0
var _flare_visible := 0.0
var _flare_check := 0.0
var _sun_clear := true
var _flare_enabled := true
var _sea: MeshInstance3D
## Leaves and bits blown past in strong wind, around the camera.
var _leaves: CPUParticles3D
## Disasters that hit the power grid make lamps and windows flicker.
var _flicker := false
var _power_on := true
var _power_time := 0.0


func _ready() -> void:
	add_to_group("weather")
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	_sky.set_shader_parameter("noise", Look.noise_texture())

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = Sky.new()
	_env.sky.sky_material = _sky
	# Lighting doesn't sample the sky (no radiance re-bakes while clouds move or
	# a mood blends); ambient is a color from the mood, and water/glass reflect
	# the sky in their own shaders.
	_env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	# Distance haze ties the sea into the horizon and gives depth.
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = 0.4
	# Bloom on the bright stuff: lava, fire, the sun on water, lightning.
	_env.glow_enabled = true
	_env.glow_intensity = 0.65
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 1.05
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 90.0
	add_child(_sun)

	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_sun_base = 1.0
		_ambient_base = 0.8
		_exposure_base = 0.8

	var sea := MeshInstance3D.new()
	_sea = sea
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
	_leaves = _make_leaves()
	add_child(_leaves)
	_splashes = _make_splashes()
	add_child(_splashes)
	_bolt_mesh = ImmediateMesh.new()
	_bolt = MeshInstance3D.new()
	_bolt.mesh = _bolt_mesh
	_bolt_core = _bolt_material(Color(3.0, 3.4, 5.0, 1.0))
	_bolt_halo = _bolt_material(Color(0.6, 0.7, 1.2, 0.18))
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)
	var flare_layer := CanvasLayer.new()
	flare_layer.layer = -1
	_flare = Control.new()
	_flare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flare.material = additive
	_flare.draw.connect(_draw_flare)
	flare_layer.add_child(_flare)
	add_child(flare_layer)

	new_day()


## Shadows, glow and rain density for a quality level (see quality.gd).
func apply_quality(q: Dictionary) -> void:
	_sun.shadow_enabled = q.shadows > 0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q.shadows > 1 \
			else DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 90.0 if q.shadows > 1 else 45.0
	_env.glow_enabled = q.glow
	_flare_enabled = q.flare
	_rain.amount = q.rain
	_splashes.amount = int(q.rain * 0.2)


## Picks this round's time of day and snaps the sky to it (a new map is loading).
## The time of day this round (a key of TIMES).
func time_of_day() -> String:
	return _time


func new_day() -> void:
	if forced_time != "":
		_time = forced_time
	else:
		var total := 0
		for key: String in TIME_WEIGHTS:
			total += TIME_WEIGHTS[key]
		var pick := randi() % total
		for key: String in TIME_WEIGHTS:
			pick -= TIME_WEIGHTS[key]
			if pick < 0:
				_time = key
				break
	var time: Dictionary = TIMES[_time]
	_sun.rotation_degrees = Vector3(-time.elevation, time.azimuth, 0)
	# The light shines along its -Z, so +Z points at the sun.
	RenderingServer.global_shader_parameter_set("sun_dir", _sun.global_basis.z.normalized())
	_to = _compose(_mood, _time)
	_now = _to.duplicate()
	_blend = 1.0
	_apply(_now)


## Starts blending toward one of MOODS (tinted by the time of day).
func set_mood(mood: String) -> void:
	var was_raining: bool = MOODS[_mood].rain
	_mood = mood if MOODS.has(mood) else "clear"
	var target := _compose(_mood, _time)
	if target == _to:
		return
	_from = _now.duplicate()
	_to = target
	_blend = 0.0
	_rain.emitting = MOODS[_mood].rain
	_splashes.emitting = _rain.emitting
	# After the rain, with the sun out: a rainbow (gone again if rain returns).
	if was_raining and not _rain.emitting and _time != "night":
		_rainbow_age = 0.0
	elif _rain.emitting:
		_rainbow_age = RAINBOW_TIME
		RenderingServer.global_shader_parameter_set("rainbow", 0.0)


## Tells the sea where the island's shore is (for foam and shallow water).
func set_island(half_size: float) -> void:
	RenderingServer.global_shader_parameter_set("island_half", half_size)


func _compose(mood: String, time_key: String) -> Dictionary:
	var m: Dictionary = MOODS[mood]
	var t: Dictionary = TIMES[time_key]
	var out := {}
	if mood == "clear":
		for key in ["top", "horizon", "haze", "sun", "energy", "ambient", "fog", "clouds", "cloud_light", "cloud_dark"]:
			out[key] = t[key]
		out.rooms = maxf(m.rooms, t.rooms)
		out.aurora = t.aurora
	else:
		var tint: Color = t.tint
		for key in ["top", "horizon", "haze", "sun", "cloud_light", "cloud_dark"]:
			out[key] = (m[key] as Color) * tint
		out.energy = m.energy * t.energy
		out.ambient = m.ambient * t.ambient
		out.fog = m.fog
		out.clouds = m.clouds
		out.rooms = maxf(m.rooms, t.rooms)
		out.aurora = 0.0
	out.wind = m.wind
	out.waves = m.waves
	out.saturation = m.saturation
	out.night = t.night
	out.stars = t.stars
	out.exposure = t.exposure
	return out


func _process(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(_blend + delta / BLEND_TIME, 1.0)
		var k := smoothstep(0.0, 1.0, _blend)
		for key: String in BLENDED:
			_now[key] = lerp(_from[key], _to[key], k)
		_apply(_now)

	var raining := _rain.emitting
	if raining:
		get_tree().call_group("sound", "loop", "rain", 0.5)
	if MOODS[_mood].lightning:
		get_tree().call_group("sound", "loop", "wind", 0.25, 1.0)
	_wet = clampf(_wet + delta / (WET_TIME if raining else -DRY_TIME), 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("wetness", _wet)
	if _rainbow_age < RAINBOW_TIME:
		_rainbow_age = minf(_rainbow_age + delta, RAINBOW_TIME)
		var strength := smoothstep(0.0, 6.0, _rainbow_age) * (1.0 - smoothstep(RAINBOW_TIME - 10.0, RAINBOW_TIME, _rainbow_age))
		RenderingServer.global_shader_parameter_set("rainbow", strength)

	if MOODS[_mood].lightning and _blend > 0.5:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = randf_range(2.5, 7.0)
			_flash = 1.0
			_strike()
			# Thunder: a deep, slowed boom.
			get_tree().call_group("sound", "play", "boom", null, -4.0, 0.55)
	# Flicker: two quick pulses as it fades.
	_flash = maxf(_flash - delta * 3.0, 0.0)
	var flicker := _flash * (1.0 if fmod(_flash, 0.4) > 0.15 else 0.3)
	_bolt.visible = _flash > 0.25 and fmod(_flash, 0.4) > 0.1
	var energy: float = _now.energy
	_sun.light_energy = _sun_base * energy + flicker * 2.5
	_sun.light_color = (_now.sun as Color).lerp(Color(0.8, 0.85, 1.0), minf(flicker, 1.0))
	RenderingServer.global_shader_parameter_set("sun_color", (_now.sun as Color) * minf(energy, 1.5))
	_sky.set_shader_parameter("flash", flicker * 1.5)

	if _flicker:
		_power_time -= delta
		if _power_time <= 0.0:
			# Mostly on, with short drops and the odd longer blackout.
			_power_on = not _power_on
			_power_time = randf_range(0.4, 2.5) if _power_on else randf_range(0.04, 0.5)
			Look.set_lamps(_now.rooms if _power_on else 0.0)

	var camera := get_viewport().get_camera_3d()
	var windy: bool = _now.get("wind", 0.0) > 0.75
	_leaves.emitting = windy
	if camera and windy:
		_leaves.global_position = camera.global_position + Vector3(-6.0, 1.0, 0.0)
	if camera:
		if raining:
			var ahead := -camera.global_basis.z
			_rain.global_position = camera.global_position + Vector3(ahead.x * 8.0, 14.0, ahead.z * 8.0)
			_splashes.global_position = camera.global_position + Vector3(ahead.x * 4.0, -1.55, ahead.z * 4.0)
		_update_flare(camera, delta)


func _apply(v: Dictionary) -> void:
	RenderingServer.global_shader_parameter_set("sky_top", v.top)
	RenderingServer.global_shader_parameter_set("sky_horizon", v.horizon)
	RenderingServer.global_shader_parameter_set("sea_haze", v.haze)
	RenderingServer.global_shader_parameter_set("cloud_cover", v.clouds)
	RenderingServer.global_shader_parameter_set("cloud_light", v.cloud_light)
	RenderingServer.global_shader_parameter_set("cloud_dark", v.cloud_dark)
	RenderingServer.global_shader_parameter_set("wind", v.wind)
	RenderingServer.global_shader_parameter_set("wave_height", v.waves)
	RenderingServer.global_shader_parameter_set("night", v.night)
	RenderingServer.global_shader_parameter_set("stars", v.stars)
	# The aurora needs a clear, dark sky.
	RenderingServer.global_shader_parameter_set("aurora", v.aurora * (1.0 - smoothstep(0.4, 0.7, v.clouds)))
	Look.set_lamps(v.rooms)
	_env.fog_light_color = v.horizon
	_env.fog_density = v.fog
	_env.ambient_light_energy = _ambient_base * v.ambient
	# Mostly neutral with a touch of the sky, so shaded sides don't turn deep blue;
	# at night the neutral part goes moonlit blue.
	var neutral := Color(0.72, 0.7, 0.66).lerp(Color(0.32, 0.4, 0.62), v.night)
	_env.ambient_light_color = neutral.lerp((v.top as Color).lerp(v.horizon, 0.6), 0.4)
	_env.adjustment_saturation = v.saturation
	_env.tonemap_exposure = _exposure_base * v.exposure
	_rain_material.albedo_color = MOODS[_mood].get("rain_color", Color(0.75, 0.8, 0.85, 0.35).lerp(Color(0.4, 0.45, 0.55, 0.25), v.night))


## A jagged bolt from the clouds to somewhere around the camera, with a branch.
func _strike() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Mostly somewhere in front of the player, where it can be seen.
	var forward := -camera.global_basis.z
	var angle := atan2(forward.z, forward.x) + randf_range(-0.9, 0.9)
	var ground := camera.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(50.0, 140.0)
	ground.y = 0.0
	_draw_bolt(ground)


## Before a tsunami the sea draws back from the shore (drop in meters); 0 brings it back.
func drain_sea(drop: float) -> void:
	var tween := create_tween()
	tween.tween_property(_sea, "position:y", SEA_LEVEL - drop, 4.0 if drop > 0.0 else 1.5).set_trans(Tween.TRANS_SINE)


## A bolt down to a given spot, with the sky flash (the lightning storm aims these).
## Earthquakes, storms and the like: the street lamps flicker until the round ends.
func power_flicker(on: bool) -> void:
	_flicker = on
	_power_on = true
	_power_time = randf_range(0.5, 2.0)
	if not on and not _now.is_empty():
		Look.set_lamps(_now.rooms)


func raining() -> bool:
	return _rain.emitting


## How hard it rains on the camera lens (storms harder).
func rain_strength() -> float:
	return 1.0 if MOODS[_mood].lightning else 0.6


func strike_at(ground: Vector3) -> void:
	_flash = 1.0
	_draw_bolt(ground)
	get_tree().call_group("effects", "scorch", ground, 1.6)


func _draw_bolt(ground: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var top := ground + Vector3(randf_range(-20, 20), 110.0, randf_range(-20, 20))
	_bolt_mesh.clear_surfaces()
	var main := _bolt_path(top, ground, 30, 0.55)
	var fork_start := main[randi_range(8, 14)]
	var fork := _bolt_path(fork_start, fork_start + Vector3(randf_range(-25, 25), -randf_range(25, 45), randf_range(-25, 25)), 14, 0.6)
	# A wide faint halo, then the bright core.
	for pass_width: float in [2.8, 0.5]:
		_bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _bolt_halo if pass_width > 1.0 else _bolt_core)
		_bolt_ribbon(main, camera.global_position, pass_width)
		_bolt_ribbon(fork, camera.global_position, pass_width * 0.6)
		_bolt_mesh.surface_end()


## A random walk from one point to another: each step wanders sideways by up to
## `wander` times its length, and is pulled back toward the straight line.
func _bolt_path(from: Vector3, to: Vector3, steps: int, wander: float) -> PackedVector3Array:
	var points := PackedVector3Array([from])
	var step := from.distance_to(to) / steps
	var drift := Vector3.ZERO
	for k in range(1, steps):
		drift += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * step * wander
		drift *= 0.8
		points.append(from.lerp(to, float(k) / steps) + drift)
	points.append(to)
	return points


## Flat strip along the points, turned to face the camera.
func _bolt_ribbon(points: PackedVector3Array, eye: Vector3, width: float) -> void:
	for k in points.size() - 1:
		var a := points[k]
		var b := points[k + 1]
		var side := (b - a).cross(eye - a).normalized() * width * 0.5
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_bolt_mesh.surface_add_vertex(v)


## Lens flare: glow and ghosts along the line from the sun through the screen
## center, while the sun is on screen and not hidden by clouds or buildings.
func _update_flare(camera: Camera3D, delta: float) -> void:
	var sun_dir := _sun.global_basis.z
	var target := 0.0
	var day: float = 1.0 - _now.night
	if _flare_enabled and sun_dir.y > 0.0 and day > 0.0 and not camera.is_position_behind(camera.global_position + sun_dir):
		_flare_check -= delta
		if _flare_check <= 0.0:
			_flare_check = 0.15
			var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + sun_dir * 300.0)
			_sun_clear = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if _sun_clear:
			target = day * (1.0 - smoothstep(0.45, 0.8, _now.clouds))
	_flare_visible = move_toward(_flare_visible, target, delta * 4.0)
	_flare.visible = _flare_visible > 0.01
	if _flare.visible:
		_flare.set_meta("sun", camera.unproject_position(camera.global_position + sun_dir * 100.0))
		_flare.queue_redraw()


func _draw_flare() -> void:
	var sun: Vector2 = _flare.get_meta("sun", Vector2.ZERO)
	var size := _flare.size
	var center := size * 0.5
	var a := _flare_visible
	var tint: Color = _now.sun
	# Glare around the sun itself, bigger when looking straight at it.
	var near := 1.0 - clampf(sun.distance_to(center) / size.length(), 0.0, 1.0)
	for k in 5:
		_flare.draw_circle(sun, size.y * (0.04 + k * 0.035) * (0.6 + near), Color(tint, 0.045 * a * (1.0 - k / 5.0)))
	# Ghosts: (position along sun->center->beyond, radius, color).
	var ghosts := [[0.35, 0.03, Color(1.0, 0.8, 0.5)], [0.6, 0.012, Color(0.6, 1.0, 0.7)], [1.2, 0.05, Color(0.5, 0.7, 1.0)],
			[1.5, 0.02, Color(1.0, 0.6, 0.9)], [1.9, 0.09, Color(0.7, 0.9, 1.0)]]
	for ghost: Array in ghosts:
		var pos := sun.lerp(center, ghost[0])
		var color: Color = ghost[2]
		_flare.draw_circle(pos, size.y * ghost[1], Color(color, 0.08 * a))


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
	quad.size = Vector2(0.022, 0.9)
	_rain_material = StandardMaterial3D.new()
	_rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = _rain_material
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


## Leaves, twigs and paper whirling past on the wind (a few dozen quads).
func _make_leaves() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.07)
	var leaf := StandardMaterial3D.new()
	leaf.vertex_color_use_as_albedo = true
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf.roughness = 0.9
	quad.material = leaf
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.amount = 40
	p.lifetime = 2.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(2, 3, 9)
	p.direction = Vector3(1, 0.15, 0.2)
	p.spread = 20.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -1.2, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.particle_flag_rotate_y = true
	var colors := Gradient.new()
	colors.set_color(0, Color(0.35, 0.5, 0.18))
	colors.set_color(1, Color(0.55, 0.38, 0.15))
	colors.add_point(0.6, Color(0.75, 0.6, 0.25))
	p.color_initial_ramp = colors
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Little bursts where drops hit the ground around the player's feet.
func _make_splashes() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.12)
	quad.material = Look.sprite(1.4)
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.amount = SPLASHES
	p.lifetime = 0.3
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 0.05, 9)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_curve = Look.grow(0.3)
	p.color_ramp = Look.ramp([Color(0.85, 0.9, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.55), Color(0.85, 0.9, 1.0, 0.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _bolt_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat
