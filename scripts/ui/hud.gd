extends CanvasLayer
## Round status, countdown, health bar and death message.

const BuildInfo := preload("res://scripts/core/build_info.gd")

## Set before adding to the tree; hides the keyboard hint.
var touch_mode := false

var _status: Label
var _timer: Label
var _center: Label
var _health: ProgressBar
var _health_fill: StyleBoxFlat


func _ready() -> void:
	# Soft dark edges pull the eye to the middle of the screen.
	var vignette := TextureRect.new()
	var shade := GradientTexture2D.new()
	shade.fill = GradientTexture2D.FILL_RADIAL
	shade.fill_from = Vector2(0.5, 0.5)
	shade.fill_to = Vector2(1.1, 1.1)
	shade.gradient = Gradient.new()
	shade.gradient.set_color(0, Color(0, 0, 0, 0))
	shade.gradient.set_color(1, Color(0, 0, 0, 0.55))
	shade.gradient.add_point(0.55, Color(0, 0, 0, 0))
	vignette.texture = shade
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	_status = _label(30)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 16
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_timer = _label(24)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_timer.offset_top = 60

	_center = _label(48)
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.text = "Öldün! Sonraki turu bekle"
	_center.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_center.visible = false

	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -2
	crosshair.offset_right = 2
	crosshair.offset_top = -2
	crosshair.offset_bottom = 2
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# Top-left keeps the bottom corners free for touch controls.
	_health = ProgressBar.new()
	_health.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_health.offset_left = 20
	_health.offset_right = 260
	_health.offset_top = 20
	_health.offset_bottom = 44
	_health.max_value = 100
	_health.value = 100
	_health.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	_health.add_theme_stylebox_override("background", bg)
	_health_fill = StyleBoxFlat.new()
	_health_fill.set_corner_radius_all(6)
	_health.add_theme_stylebox_override("fill", _health_fill)
	add_child(_health)
	_set_health(100, 100)

	var version := _label(12)
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	version.offset_left = 22
	version.offset_top = 48
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	version.text = "v " + BuildInfo.VERSION

	var hint := _label(14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -16
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = "WASD: yürü  Shift: koş  Space: zıpla  Fare: bak  Esc: imleci bırak  F12: ekran görüntüsü"
	hint.visible = not touch_mode


func bind(manager: Node, player: Node) -> void:
	manager.status_changed.connect(func(text: String) -> void: _status.text = text)
	manager.timer_changed.connect(func(seconds: int) -> void: _timer.text = str(seconds))
	player.health_changed.connect(_set_health)
	player.died.connect(func() -> void: _center.visible = true)
	player.respawned.connect(func() -> void: _center.visible = false)


func _set_health(value: float, max_value: float) -> void:
	_health.max_value = max_value
	_health.value = value
	_health_fill.bg_color = Color(0.9, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.35), value / max_value)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	return label
