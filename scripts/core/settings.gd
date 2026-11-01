extends RefCounted
## Control settings shared by the touch controls, the mouse look and the settings
## panel: look sensitivity, invert, button size and spots, auto-jump. Saved in the
## "touch" section of user://settings.cfg (other sections are kept).

const PATH := "user://settings.cfg"
const STICK_HOME := Vector2(0.16, 0.72)
const JUMP_HOME := Vector2(0.87, 0.7)

static var sensitivity := 1.0
static var invert_y := false
static var button_size := 1.0
static var stick_home := STICK_HOME
static var jump_home := JUMP_HOME
## Walking into something knee-high hops over it (touch screens).
static var auto_jump := true
## Master volume and music volume, 0..1.
static var volume := 0.8
static var music := 0.6
## Frame times, draw calls and physics load under the FPS readout.
static var perf_overlay := false
## Game mode (DisasterManager.MODES index) and how good the bots are (0..2).
static var game_mode := 0
static var bot_level := 1
## Turning the phone turns the view (web: device motion).
static var gyro := false
## The camera behind the character instead of its eyes.
static var third_person := false
## Orange/blue instead of red/green; interface scale (all menus and buttons);
## language ("tr" or "en").
static var colorblind := false
static var ui_scale := 1.0
static var language := "tr"


static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	sensitivity = config.get_value("touch", "sensitivity", 1.0)
	invert_y = config.get_value("touch", "invert_y", false)
	button_size = config.get_value("touch", "button_size", 1.0)
	stick_home = config.get_value("touch", "stick_home", STICK_HOME)
	jump_home = config.get_value("touch", "jump_home", JUMP_HOME)
	auto_jump = config.get_value("touch", "auto_jump", true)
	volume = config.get_value("touch", "volume", 0.8)
	music = config.get_value("touch", "music", 0.6)
	perf_overlay = config.get_value("touch", "perf_overlay", false)
	game_mode = config.get_value("touch", "game_mode", 0)
	bot_level = config.get_value("touch", "bot_level", 1)
	gyro = config.get_value("touch", "gyro", false)
	third_person = config.get_value("touch", "third_person", false)
	colorblind = config.get_value("touch", "colorblind", false)
	ui_scale = config.get_value("touch", "ui_scale", 1.0)
	language = config.get_value("touch", "language", "tr")


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("touch", "sensitivity", sensitivity)
	config.set_value("touch", "invert_y", invert_y)
	config.set_value("touch", "button_size", button_size)
	config.set_value("touch", "stick_home", stick_home)
	config.set_value("touch", "jump_home", jump_home)
	config.set_value("touch", "auto_jump", auto_jump)
	config.set_value("touch", "volume", volume)
	config.set_value("touch", "music", music)
	config.set_value("touch", "perf_overlay", perf_overlay)
	config.set_value("touch", "game_mode", game_mode)
	config.set_value("touch", "bot_level", bot_level)
	config.set_value("touch", "gyro", gyro)
	config.set_value("touch", "third_person", third_person)
	config.set_value("touch", "colorblind", colorblind)
	config.set_value("touch", "ui_scale", ui_scale)
	config.set_value("touch", "language", language)
	config.save(PATH)


static func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
