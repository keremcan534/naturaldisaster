extends Node
## Dev helpers.
##   F12                 saves a screenshot to user://screenshots
## Command line options (after `--`):
##   --play              skips the main menu (--fast does too)
##   --fast              shortens every round timer
##   --shots=<dir>       saves a screenshot every 2 seconds into <dir>
##   --run-for=<sec>     quits after <sec> seconds
##   --log               prints round status changes
##   --perf              prints frame costs every second (process, physics, draws)
##   --map=<i>           always loads map i (see maps.gd)
##   --quality=<0-2>     fixed graphics quality (0 low, 2 high), auto off
##   --time=<name>       always uses this time of day (morning, day, golden, night)
##   --disaster=<i>      always picks disaster i (see disaster_manager.gd)
##   --mode=<i>          plays game mode i (DisasterManager.MODES) without saving it
##   --rescue            the rescue helicopter comes every round
##   --third             third-person camera (not saved)
##   --selftest          plays every disaster once, each on another map (fast),
##                       reports loose pieces at rest and survivors, then quits
##   --touch             shows the mobile controls on desktop (read in main.gd)
##   --botlog            prints every bot's plan, position and health each second
##   --pos=x,y,z         puts the player there on the first frame
##   --yaw=<deg>         with --pos, turns the player
##   --pitch=<deg>       with --pos, looks up (positive) or down

const SHOT_INTERVAL := 2.0
const Structure := preload("res://scripts/world/structure.gd")

var manager: Node

var _shot_dir := ""
var _shot_timer := 0.0
var _run_for := -1.0
var _elapsed := 0.0
var _shot_index := 0
var _start_pos: Variant = null
var _start_yaw := 0.0
var _start_pitch := 0.0
var _perf := false
var _perf_timer := 0.0
var _bot_log := false
var _bot_timer := 0.0
var _selftest := false
var _test_round := 0
var _test_check := -1.0
var _test_warnings: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--fast":
			manager.time_scale = 0.3
		elif arg.begins_with("--shots="):
			_shot_dir = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(_shot_dir)
			# Unattended capture: don't grab the mouse of whoever is at the desk.
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			manager.world.auto_pause = false
		elif arg.begins_with("--map="):
			manager.world.forced_map = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--quality="):
			manager.world.set_quality(arg.get_slice("=", 1).to_int(), false)
		elif arg.begins_with("--time="):
			manager.world.forced_time = arg.get_slice("=", 1)
		elif arg.begins_with("--disaster="):
			manager.forced_disaster = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--mode="):
			preload("res://scripts/core/settings.gd").game_mode = arg.get_slice("=", 1).to_int()
		elif arg == "--rescue":
			manager.rescue_chance = 1.0
		elif arg == "--selftest":
			_selftest = true
			manager.time_scale = 0.3
			manager.world.forced_map = 0
			manager.forced_disaster = 0
			manager.round_started.connect(func() -> void: _test_check = 1.5)
			manager.round_scored.connect(_selftest_round)
		elif arg == "--third":
			preload("res://scripts/core/settings.gd").third_person = true
		elif arg.begins_with("--pos="):
			var p := arg.get_slice("=", 1).split_floats(",")
			_start_pos = Vector3(p[0], p[1], p[2])
		elif arg.begins_with("--yaw="):
			_start_yaw = deg_to_rad(arg.get_slice("=", 1).to_float())
		elif arg.begins_with("--pitch="):
			_start_pitch = deg_to_rad(arg.get_slice("=", 1).to_float())
		elif arg == "--perf":
			_perf = true
		elif arg == "--botlog":
			_bot_log = true
		elif arg == "--log":
			manager.status_changed.connect(func(text: String) -> void: print("[%.1fs] %s" % [_elapsed, text]))
		elif arg.begins_with("--run-for="):
			_run_for = arg.get_slice("=", 1).to_float()


## After each round: the next disaster on the next map; after the last, a report.
func _selftest_round(board: Array) -> void:
	var count: int = manager.DISASTERS.size()
	var alive := board.filter(func(p: Node) -> bool: return p.alive).size()
	print("[selftest] %2d/%d  %-20s on %-18s survivors %d/%d" % [_test_round + 1, count,
			manager.DISASTERS[manager.forced_disaster].resource_path.get_file().get_basename(), manager.world.map_name,
			alive, board.size()])
	_test_round += 1
	if _test_round >= count:
		print("[selftest] done: %d rounds, %d warnings" % [_test_round, _test_warnings.size()])
		for warning: String in _test_warnings:
			print("[selftest] WARNING " + warning)
		get_tree().quit()
		return
	manager.forced_disaster = _test_round
	manager.world.forced_map = _test_round % preload("res://scripts/world/maps.gd").COUNT


func _process(delta: float) -> void:
	if _selftest and _test_check > 0.0:
		_test_check -= delta
		if _test_check <= 0.0 and Structure.awake > 0:
			# A fresh map should stand still: anything moving fell by itself.
			_test_warnings.append("%s: %d pieces moving at rest" % [manager.world.map_name, Structure.awake])
	if _elapsed == 0.0 and _start_pos != null:
		for player: Node3D in get_tree().get_nodes_in_group("player"):
			if not player.is_bot:
				player.teleport(_start_pos)
				player.set_view(_start_yaw, _start_pitch)
	_elapsed += delta
	if _perf:
		_perf_timer -= delta
		if _perf_timer <= 0.0:
			_perf_timer = 1.0
			print("[%.1fs] fps %d, process %.2f ms, physics %.2f ms, draw calls %d, primitives %d, fires %d" % [_elapsed,
					Engine.get_frames_per_second(),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Structure.fires])
	if _bot_log:
		_bot_timer -= delta
		if _bot_timer <= 0.0:
			_bot_timer = 1.0
			for bot: Node3D in get_tree().get_nodes_in_group("bots"):
				print("[%.1fs] %s" % [_elapsed, bot.describe()])
	if _run_for > 0.0 and _elapsed >= _run_for:
		get_tree().quit()
		return
	if _shot_dir != "":
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = SHOT_INTERVAL
			_save_screenshot(_shot_dir.path_join("shot_%03d.png" % _shot_index))
			_shot_index += 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		_save_screenshot("user://screenshots/%d.png" % Time.get_unix_time_from_system())


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png(path)
