extends Node3D
## The world: owns the current map, the player, the AI teammates, the menus and
## the disaster loop. Starts in the main menu (the island and the bots behind it);
## OYNA starts a session of rounds, the pause menu can go back.

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
const Settings := preload("res://scripts/core/settings.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Bot := preload("res://scripts/player/bot.gd")
const Menu := preload("res://scripts/ui/menu.gd")

## AI teammates in every session.
const BOT_COUNT := 5
## After play/resume, how long before an uncaptured mouse counts as "the player
## left the game" (Esc in a browser drops the pointer lock without a key event).
const CAPTURE_GRACE := 0.6

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
var _player: Player
var _hud: Hud
var _controls: TouchControls
var _manager: DisasterManager
var _menu: Menu
var _touch := false
var _playing := false
var _capture_grace := 0.0
## Debug runs (screenshots) leave the mouse alone.
var auto_pause := true


func _ready() -> void:
	InputSetup.register()
	var args := OS.get_cmdline_user_args()
	# Tablets can report a desktop OS in the browser; a touchscreen settles it.
	_touch = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()) \
			or "--touch" in args
	Quality.load_settings(_touch)
	Settings.load_settings()
	Profile.load_profile()

	_weather = Weather.new()
	add_child(_weather)
	add_child(Effects.new())
	add_child(Debris.new())
	_apply_quality()

	_player = Player.new()
	_player.use_mouse = not _touch
	add_child(_player)
	_player.pause_requested.connect(_pause)

	_hud = Hud.new()
	_hud.touch_mode = _touch
	add_child(_hud)

	if _touch:
		_controls = TouchControls.new()
		_controls.player = _player
		add_child(_controls)
		_controls.menu_requested.connect(_pause)

	_manager = DisasterManager.new()
	_manager.world = self
	add_child(_manager)
	_hud.bind(_manager, _player)
	_manager.round_scored.connect(_on_round_scored)

	for i in BOT_COUNT:
		var bot := Bot.new()
		bot.setup(i, randi())
		bot.manager = _manager
		bot.world = self
		add_child(bot)

	_menu = Menu.new()
	_menu.world = self
	_menu.controls = _controls
	add_child(_menu)
	_menu.play_pressed.connect(play)
	_menu.resume_pressed.connect(_resume)
	_menu.main_menu_pressed.connect(show_menu)

	var debug := DebugTools.new()
	debug.manager = _manager
	add_child(debug)

	load_next_map()
	get_tree().call_group("bots", "respawn", spawn_point)
	if "--play" in args or "--fast" in args:
		play()
	else:
		show_menu()


## OYNA: a session of rounds on the island behind the menu, scores from zero.
func play() -> void:
	_playing = true
	_menu.hide_all()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.visible = true
	if not _player.is_in_group("player"):
		_player.add_to_group("player")
	_player.make_camera_current()
	_set_controls(true)
	_hud.visible = true
	_manager.start(true)


## Back to the main menu: the disaster stops, a fresh island loads behind it.
func show_menu() -> void:
	var was_playing := _playing
	_playing = false
	_manager.stop()
	_set_controls(false)
	_hud.visible = false
	_player.remove_from_group("player")
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.visible = false
	if was_playing:
		load_next_map()
		get_tree().call_group("bots", "respawn", spawn_point)
	set_mood("clear")
	_menu.show_main(spawn_point)


func _pause() -> void:
	if not _playing or _menu.is_open():
		return
	_set_controls(false)
	_menu.show_pause()


func _resume() -> void:
	_menu.hide_all()
	_set_controls(true)


## Hands input to the game (or takes it away for a menu): touch controls, the
## player's movement, and on desktop the captured mouse.
func _set_controls(on: bool) -> void:
	_player.controls_enabled = on
	if _controls:
		_controls.set_active(on)
	if _player.use_mouse and auto_pause:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	_capture_grace = CAPTURE_GRACE


func _on_round_scored(board: Array) -> void:
	var earned := 0
	if _player.is_in_group("player"):
		earned = Profile.add_round(_player.round_points, _player.alive, _player.score)
	_hud.show_board(board, earned)


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
	# A browser drops the pointer lock on Esc without telling the game: open the
	# pause menu, whose DEVAM click locks it again.
	if _playing and _player.use_mouse and auto_pause and not _menu.is_open():
		_capture_grace -= delta
		if _capture_grace <= 0.0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_pause()
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
