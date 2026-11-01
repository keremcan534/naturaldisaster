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
const Flames := preload("res://scripts/world/flames.gd")
const Ambience := preload("res://scripts/world/ambience.gd")
const Hazards := preload("res://scripts/world/hazards.gd")
const Warmup := preload("res://scripts/core/warmup.gd")
const Sound := preload("res://scripts/core/sound.gd")
const Structure := preload("res://scripts/world/structure.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Progress := preload("res://scripts/core/progress.gd")
const Bot := preload("res://scripts/player/bot.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const Events := preload("res://scripts/core/events.gd")
const RescueHeli := preload("res://scripts/world/rescue_heli.gd")
const Doors := preload("res://scripts/world/doors.gd")
const Boat := preload("res://scripts/world/boat.gd")
const Photo := preload("res://scripts/core/photo.gd")
const Season := preload("res://scripts/core/season.gd")

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
## The dam map: where the wall stands (Vector3.INF elsewhere) and its lake.
var dam := Vector3.INF
var dam_lake: Node3D
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
var _ambience: Ambience
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
var _warmed := false
## Debug runs (screenshots) leave the mouse alone.
var auto_pause := true


func _ready() -> void:
	# Physics interpolation is on in the project, but only for what moves in
	# physics steps (debris, bots, projectiles, structures' pieces, disaster
	# bodies): those nodes switch it back on. Everything moved in _process, and
	# the player's own camera (interpolated by hand), stays as drawn.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	InputSetup.register()
	var args := OS.get_cmdline_user_args()
	# Tablets can report a desktop OS in the browser; a touchscreen settles it.
	_touch = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()) \
			or "--touch" in args
	Quality.load_settings(_touch)
	Settings.load_settings()
	preload("res://scripts/core/lang.gd").apply(Settings.language)
	get_tree().root.content_scale_factor = Settings.ui_scale
	Profile.load_profile()
	Progress.load_progress()
	Season.load_season()
	if Settings.gyro and _touch:
		preload("res://scripts/core/gyro.gd").start()

	add_child(Sound.new())
	Settings.apply_volume()
	_weather = Weather.new()
	add_child(_weather)
	add_child(Effects.new())
	add_child(Debris.new())
	add_child(Flames.new())
	add_child(Hazards.new())
	_ambience = Ambience.new()
	add_child(_ambience)
	add_child(RescueHeli.new())
	add_child(Doors.new())
	_apply_quality()

	_player = Player.new()
	_player.use_mouse = not _touch
	add_child(_player)
	_player.pause_requested.connect(_pause)
	_player.photo_requested.connect(_take_photo)
	_player.helped.connect(func(_name: String) -> void: Profile.count("helps"))
	_player.rescued_now.connect(func() -> void: Profile.count("rescues"))
	_player.died.connect(func() -> void: get_tree().call_group("sound", "play", "lose", null, -2.0))

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
	_manager.disaster_warned.connect(func(_title: String, _hint: String) -> void:
		get_tree().call_group("sound", "play", "siren")
		get_tree().call_group("sound", "music", "tense"))
	_manager.round_started.connect(func() -> void: get_tree().call_group("sound", "music", "calm"))

	for i in BOT_COUNT:
		var bot := Bot.new()
		bot.setup(i, randi())
		bot.manager = _manager
		bot.world = self
		add_child(bot)
	_hud.watch_bots(get_tree().get_nodes_in_group("bots"))

	_menu = Menu.new()
	_menu.world = self
	_menu.controls = _controls
	add_child(_menu)
	_menu.play_pressed.connect(play)
	_menu.resume_pressed.connect(_resume)
	_menu.main_menu_pressed.connect(show_menu)
	_menu.photo_pressed.connect(func() -> void:
		_resume()
		_take_photo())
	_menu.tutorial_closed.connect(func() -> void:
		Progress.tutorial_done = true
		Progress.save_progress()
		_manager.set_process(true)
		_set_controls(true))

	var debug := DebugTools.new()
	debug.manager = _manager
	add_child(debug)

	load_next_map()
	get_tree().call_group("bots", "respawn", spawn_point)
	if "--play" in args or "--fast" in args or "--selftest" in args:
		play(false)
	else:
		show_menu()


## OYNA: a session of rounds on the island behind the menu, scores from zero.
## from_menu: a person pressed OYNA (debug runs that skip the menu skip the tutorial too).
func play(from_menu := true) -> void:
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
	# The first time: how to play, with the round clock held until it is read.
	if not Progress.tutorial_done and from_menu:
		_manager.set_process(false)
		_set_controls(false)
		_menu.show_tutorial(_touch)


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
	get_tree().call_group("sound", "music", "calm")
	_menu.show_main(spawn_point)
	# Compile every effect's shader now, behind the menu, not mid-disaster.
	if not _warmed:
		_warmed = true
		var warmup := Warmup.new()
		add_child(warmup)
		warmup.run(get_viewport().get_camera_3d())


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
	var toasts: Array = []
	if _player.is_in_group("player"):
		var multiplier := Events.coin_multiplier(_manager.last_round) if _player.alive else 1
		earned = Profile.add_round(_player.round_points, _player.alive, _player.score, multiplier,
				_manager.last_round.get("kinds", []), _player.streak)
		if multiplier > 1 and earned > 0:
			toasts.append(["%s: 2 kat coin!" % Events.current().name, 0])
		var everyone := board.all(func(p: Node) -> bool: return p.alive)
		var info := {"survived": _player.alive, "points": _player.round_points, "streak": _player.streak,
				"height": _player.max_height, "flawless": _player.alive and _player.damage_taken < 0.5,
				"team": everyone, "kinds": _manager.last_round.get("kinds", []),
				"mega": _manager.last_round.get("mega", false), "double": _manager.last_round.get("double", false)}
		var xp_before := Progress.xp
		toasts.append_array(Progress.record_round(info))
		toasts.append_array(Season.add_xp(Progress.xp - xp_before))
	_hud.show_board(board, earned)
	get_tree().call_group("sound", "music", "calm")
	if _player.is_in_group("player") and _player.alive:
		get_tree().call_group("sound", "play", "win", null, -2.0)
	for toast: Array in toasts:
		_hud.toast(toast[0], toast[1])


## Frees the current map and builds a different one (`choice`, a map vote's
## winner, or a random other one).
func load_next_map(choice := -1) -> void:
	if _map_root:
		_map_root.free()
	get_tree().call_group("debris", "clear")
	get_tree().call_group("hazards", "clear")
	RenderingServer.global_shader_parameter_set("hole", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("ash_cover", 0.0)
	RenderingServer.global_shader_parameter_set("cracks", 0.0)
	get_tree().call_group("effects", "clear")
	Structure.awake = 0
	Structure.fires = 0
	if forced_map >= 0:
		_map_index = forced_map
	elif choice >= 0:
		_map_index = choice
	else:
		var index := randi() % Maps.COUNT
		_map_index = (index + 1) % Maps.COUNT if index == _map_index else index
	_map_root = Node3D.new()
	add_child(_map_root)
	get_tree().call_group("doors", "clear")
	var info := Maps.build(_map_index, _map_root)
	get_tree().call_group("doors", "add_map")
	map_name = info.name
	map_size = info.size
	spawn_point = info.spawn
	dam = info.get("dam", Vector3.INF)
	dam_lake = _map_root.find_child("DamLake", true, false)
	_place_boat()
	_weather.set_island(map_size * 0.5)
	_weather.new_day()
	_ambience.set_island(map_size * 0.5)
	_ambience.set_night(_weather.time_of_day() == "night")
	_fps_settle = FPS_SETTLE


func map_index() -> int:
	return _map_index


## A lifeboat beside the spawn point, on open ground (floods float it).
func _place_boat() -> void:
	for offset: Vector3 in [Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(6, 0, 4), Vector3(-6, 0, 4), Vector3(0, 0, 6)]:
		var at := spawn_point + offset
		var spot := Rect2(at.x - 2.0, at.z - 3.0, 4.0, 6.0)
		if absf(at.x) > map_size * 0.5 - 3.0 or absf(at.z) > map_size * 0.5 - 3.5:
			continue
		if Maps.buildings.any(func(r: Rect2) -> bool: return r.grow(1.0).intersects(spot)):
			continue
		var boat := Boat.new()
		boat.position = Vector3(at.x, spawn_point.y - 0.5, at.z)
		boat.rotation.y = randf() * TAU
		_map_root.add_child(boat)
		return


## A screenshot without the HUD: saved (desktop) or downloaded (browser).
func _take_photo() -> void:
	if not _playing or _menu.is_open():
		return
	_hud.visible = false
	if _controls:
		_controls.visible = false
	var ok := await Photo.capture(get_viewport())
	_hud.visible = _playing
	if _controls:
		_controls.visible = _playing and not _menu.is_open()
	_hud.toast("Fotoğraf kaydedildi" if ok else "Fotoğraf kaydedilemedi", 0)
	get_tree().call_group("sound", "play", "click")


## Moves a node into the current map (it goes when the next map loads), e.g. a
## ship a disaster left stranded.
func keep_on_map(node: Node3D) -> void:
	if _map_root:
		node.reparent(_map_root)


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
