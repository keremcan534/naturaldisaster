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


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("touch", "sensitivity", sensitivity)
	config.set_value("touch", "invert_y", invert_y)
	config.set_value("touch", "button_size", button_size)
	config.set_value("touch", "stick_home", stick_home)
	config.set_value("touch", "jump_home", jump_home)
	config.set_value("touch", "auto_jump", auto_jump)
	config.save(PATH)
