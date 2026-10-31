extends Node3D
## Prototype world: owns the current map, spawns the player and starts the disaster loop.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const Quality := preload("res://scripts/core/quality.gd")
const DebugTools := preload("res://scripts/core/debug_tools.gd")
const Player := preload("res://scripts/player/player.gd")
const Maps := preload("res://scripts/world/maps.gd")
const DisasterManager := preload("res://scripts/disasters/disaster_manager.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Weather := preload("res://scripts/world/weather.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Debris := preload("res://scripts/world/debris.gd")
const Structure := preload("res://scripts/world/structure.gd")

## Set by the loaded map; disasters read these.
var map_name := ""
var map_size := 50.0
var spawn_point := Vector3(0, 0.5, 0)
## Debug: >= 0 always loads this map.
var forced_map := -1
## Debug: a time of day (see weather.gd TIMES) for every round.
var forced_time := "":
	set(value):
		forced_time = value
		_weather.forced_time = value

## Auto quality: frames counted over a window, after a pause following map loads.
const FPS_WINDOW := 4.0
const FPS_SETTLE := 2.5

var _map_root: Node3D
var _map_index := -1
var _weather: Weather
var _fps_time := 0.0
var _fps_frames := 0
var _fps_settle := FPS_SETTLE


func _ready() -> void:
	InputSetup.register()
	# Tablets can report a desktop OS in the browser; a touchscreen settles it.
	var touch := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()) \
			or "--touch" in OS.get_cmdline_user_args()
	Quality.load_settings(touch)

	_weather = Weather.new()
	add_child(_weather)
	add_child(Effects.new())
	add_child(Debris.new())
	_apply_quality()

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
	get_tree().call_group("debris", "clear")
	Structure.awake = 0
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
	_weather.set_island(map_size * 0.5)
	_weather.new_day()
	_fps_settle = FPS_SETTLE


## Picks a quality level (see quality.gd); auto keeps adjusting it to the frame
## rate. Grass counts change with the next map.
func set_quality(level: int, auto: bool) -> void:
	Quality.level = clampi(level, 0, Quality.LEVELS.size() - 1)
	Quality.auto = auto
	Quality.save_settings()
	_apply_quality()


func _apply_quality() -> void:
	Quality.apply_viewport(get_viewport())
	_weather.apply_quality(Quality.current())


func _process(delta: float) -> void:
	if not Quality.auto:
		return
	if _fps_settle > 0.0:
		_fps_settle -= delta
		return
	_fps_time += delta
	_fps_frames += 1
	if _fps_time < FPS_WINDOW:
		return
	var fps := _fps_frames / _fps_time
	_fps_time = 0.0
	_fps_frames = 0
	var next := Quality.auto_level(fps)
	if next != Quality.level:
		set_quality(next, true)
		_fps_settle = FPS_SETTLE


## Blends sky, light and fog toward one of Weather.MOODS.
func set_mood(mood: String) -> void:
	_weather.set_mood(mood)
