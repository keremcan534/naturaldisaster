extends Node3D
## Prototype world: owns the current map, spawns the player and starts the disaster loop.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const DebugTools := preload("res://scripts/core/debug_tools.gd")
const Player := preload("res://scripts/player/player.gd")
const Maps := preload("res://scripts/world/maps.gd")
const DisasterManager := preload("res://scripts/disasters/disaster_manager.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Look := preload("res://scripts/world/look.gd")

const SKY_TOP := Color(0.18, 0.38, 0.72)
const SKY_HORIZON := Color(0.66, 0.76, 0.86)
const SEA_HAZE := Color(0.32, 0.48, 0.62)
const SEA_LEVEL := -2.5

## Set by the loaded map; disasters read these.
var map_name := ""
var map_size := 50.0
var spawn_point := Vector3(0, 0.5, 0)
## Debug: >= 0 always loads this map.
var forced_map := -1

var _map_root: Node3D
var _map_index := -1


func _ready() -> void:
	InputSetup.register()
	_build_environment()

	var touch := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or "--touch" in OS.get_cmdline_user_args()

	var player := Player.new()
	player.use_mouse = not touch
	add_child(player)

	var hud := Hud.new()
	hud.touch_mode = touch
	add_child(hud)

	if touch:
		var controls := TouchControls.new()
		controls.player = player
		add_child(controls)

	var manager := DisasterManager.new()
	manager.world = self
	add_child(manager)
	hud.bind(manager, player)

	var debug := DebugTools.new()
	debug.manager = manager
	add_child(debug)

	manager.start()


## Frees the current map and builds a different one.
func load_next_map() -> void:
	if _map_root:
		_map_root.free()
	if forced_map >= 0:
		_map_index = forced_map
	else:
		var index := randi() % Maps.COUNT
		_map_index = (index + 1) % Maps.COUNT if index == _map_index else index
	_map_root = Node3D.new()
	add_child(_map_root)
	var info := Maps.build(_map_index, _map_root)
	map_name = info.name
	map_size = info.size
	spawn_point = info.spawn


func _build_environment() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = SKY_TOP
	sky.sky_horizon_color = SKY_HORIZON
	# Below the horizon the sky shows past the sea's far edge; match the hazy sea there.
	sky.ground_horizon_color = SKY_HORIZON
	sky.ground_bottom_color = SEA_HAZE
	sky.ground_curve = 0.3
	sky.sky_curve = 0.12
	sky.sun_angle_max = 20.0
	sky.sun_curve = 0.1

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Half sky, half neutral, so shaded sides don't turn deep blue.
	env.ambient_light_color = Color(0.72, 0.7, 0.66)
	env.ambient_light_sky_contribution = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	# Distance haze ties the sea into the horizon and gives depth.
	env.fog_enabled = true
	env.fog_light_color = SKY_HORIZON
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.4
	# Bloom on the bright stuff: lava, meteors, the sun on water.
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	# The OpenGL renderer (web builds) lights the same scene noticeably brighter.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy = 1.0
		env.ambient_light_energy = 0.8
		env.tonemap_exposure = 0.8

	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	var water := Look.water()
	water.set_shader_parameter("sky_color", SEA_HAZE)
	plane.material = water
	sea.mesh = plane
	sea.position.y = SEA_LEVEL
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
