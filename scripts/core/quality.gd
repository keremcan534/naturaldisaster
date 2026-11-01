extends RefCounted
## Graphics quality levels. Rendering stays at full resolution on every level
## (no blurry upscaling); levels differ in what costs real GPU time: MSAA,
## shadows, glow, grass blades (only on high; the ground is painted grass below),
## rain, the lens flare, how many loose pieces may tumble at once ("chaos", see
## Structure.awake), and
## a "quality" global the shaders use to skip expensive parts (cloud lighting,
## reflected clouds, ripple noise, contact shadows). In auto mode the game
## measures its frame rate and moves between levels. Saved with the other
## settings in user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"

const LEVELS := [
	{
		"name": "Düşük", "msaa": Viewport.MSAA_DISABLED, "shadows": 0, "glow": false, "flare": false,
		"grass": 0, "grass_range": 24.0, "flowers": false, "shader": 0.0, "rain": 150, "chaos": 140,
	},
	{
		"name": "Orta", "msaa": Viewport.MSAA_DISABLED, "shadows": 1, "glow": true, "flare": true,
		"grass": 0, "grass_range": 32.0, "flowers": false, "shader": 1.0, "rain": 280, "chaos": 220,
	},
	{
		"name": "Yüksek", "msaa": Viewport.MSAA_2X, "shadows": 2, "glow": true, "flare": true,
		"grass": 12000, "grass_range": 42.0, "flowers": true, "shader": 2.0, "rain": 450, "chaos": 320,
	},
]
## Auto mode: below LOW_FPS over a measuring window, drop a level (and never go
## back above it this session); above HIGH_FPS, try the next level up.
const LOW_FPS := 40.0
const HIGH_FPS := 56.0

static var level := 2
static var auto := true
## Highest level auto mode may still try.
static var ceiling := 2


static func current() -> Dictionary:
	return LEVELS[level]


## Reads the saved choice; without one, phones start low (auto mode raises the
## level when the frame rate allows it).
static func load_settings(touch: bool) -> void:
	level = 0 if touch else 2
	auto = true
	ceiling = LEVELS.size() - 1
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		auto = config.get_value("graphics", "auto", true)
		level = clampi(config.get_value("graphics", "level", level), 0, LEVELS.size() - 1)


## Auto mode's decision after a measuring window; returns the level to use.
static func auto_level(fps: float) -> int:
	if fps < LOW_FPS and level > 0:
		ceiling = level - 1
		return level - 1
	if fps > HIGH_FPS and level < ceiling:
		return level + 1
	return level


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("graphics", "auto", auto)
	config.set_value("graphics", "level", level)
	config.save(SETTINGS_PATH)


## Applies the viewport and shader parts; weather.gd applies shadows, glow and
## rain, maps.gd reads the grass counts when it builds a map.
static func apply_viewport(viewport: Viewport) -> void:
	var q := current()
	viewport.scaling_3d_scale = 1.0
	viewport.msaa_3d = q.msaa
	RenderingServer.global_shader_parameter_set("quality", q.shader)
