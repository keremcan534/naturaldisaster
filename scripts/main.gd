extends Node3D
## Prototype world: owns the current map, spawns the player and starts the disaster loop.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const DebugTools := preload("res://scripts/core/debug_tools.gd")
const Player := preload("res://scripts/player/player.gd")
const Maps := preload("res://scripts/world/maps.gd")
const DisasterManager := preload("res://scripts/disasters/disaster_manager.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

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
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	# The OpenGL renderer (web builds) lights the same scene noticeably brighter.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy = 0.7
		env.ambient_light_energy = 0.5
		env.tonemap_exposure = 0.85
