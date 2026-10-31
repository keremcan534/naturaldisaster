extends CanvasLayer
## On-screen controls for touch devices, laid out like a mobile shooter:
## - lower left: a floating analog joystick. It rests at a home spot, jumps to
##   where the thumb lands, and follows the thumb past its edge so the stick is
##   never lost. Pushed all the way forward it sprints.
## - everywhere else: drag to look. Dragging from the jump button looks too.
## - buttons: a big jump button, and a menu button (top left) for look
##   sensitivity, invert and graphics quality.
## Movement goes through the regular input actions (analog strengths), so the
## player doesn't care where input comes from.

const Quality := preload("res://scripts/core/quality.gd")

const SETTINGS_PATH := "user://settings.cfg"

const STICK_RADIUS := 105.0
const KNOB_RADIUS := 46.0
## Fraction of the radius ignored around the center, and the response curve
## (above 1: finer control near the center).
const STICK_DEADZONE := 0.08
const STICK_CURVE := 1.1
## Pushed this far, mostly forward, the player sprints.
const AUTO_SPRINT := 0.92
const JUMP_RADIUS := 80.0
const GEAR_RADIUS := 28.0
## Radians of turn per pixel dragged at sensitivity 1 (half a turn is about a
## third of the screen width).
const LOOK_SPEED := 0.0075
## A single drag step longer than this (fraction of screen height) can't be a
## finger: browsers can renumber fingers when one lifts, and trusting such a step
## would whip the camera around. Fast swipes on a slow frame stay well below it.
const MAX_STEP := 0.5
## The stick takes touches that start in the lower left (fractions of the screen).
const STICK_AREA := Vector2(0.42, 0.3)
const QUALITY_NAMES := ["Otomatik", "Düşük", "Orta", "Yüksek"]

const COLOR_LINE := Color(1, 1, 1, 0.55)
const COLOR_ACTIVE := Color(1, 0.85, 0.3, 0.75)

var player: Node

var sensitivity := 1.0
var invert_y := false

var _canvas: Control
var _settings: PanelContainer
var _size := Vector2(1280, 720)
var _margin := 28.0

var _stick_finger := -1
var _stick_home := Vector2.ZERO
var _stick_center := Vector2.ZERO
var _knob := Vector2.ZERO
var _stick_value := Vector2.ZERO
var _sprinting := false

var _look_finger := -1
var _look_last := Vector2.ZERO
var _jump_finger := -1
var _jump_pos := Vector2.ZERO
var _gear_pos := Vector2.ZERO


func _ready() -> void:
	_load_settings()
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_settings = _build_settings()
	add_child(_settings)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_request_fullscreen_on_touch()


func _layout() -> void:
	_size = get_viewport().get_visible_rect().size
	_margin = maxf(24.0, _size.y * 0.04)
	_stick_home = Vector2(_margin + STICK_RADIUS + 20.0, _size.y - _margin - STICK_RADIUS - 10.0)
	# Where the right thumb rests, a little in from the corner.
	_jump_pos = _size - Vector2(_margin + JUMP_RADIUS + 40.0, _margin + JUMP_RADIUS + 50.0)
	# Under the health bar, out of the way of both thumbs.
	_gear_pos = Vector2(_margin + GEAR_RADIUS + 4.0, 118.0)
	if _stick_finger < 0:
		_stick_center = _stick_home
		_knob = _stick_home
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _settings.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)


func _press(finger: int, pos: Vector2) -> void:
	# A new touch with the index of a stale finger (a lift that never arrived)
	# replaces it.
	if finger == _stick_finger or finger == _look_finger or finger == _jump_finger:
		_release(finger)
	if pos.distance_to(_gear_pos) < GEAR_RADIUS * 1.6:
		_open_settings()
		return
	if pos.distance_to(_jump_pos) < JUMP_RADIUS * 1.15:
		_jump_finger = finger
		Input.action_press("jump")
		Input.vibrate_handheld(15)
		# The jump thumb can keep turning the view.
		if _look_finger < 0:
			_look_finger = finger
			_look_last = pos
		_canvas.queue_redraw()
		return
	if pos.x < _size.x * STICK_AREA.x and pos.y > _size.y * STICK_AREA.y:
		_stick_finger = finger
		_stick_center = pos
		_knob = pos
		_set_stick(Vector2.ZERO)
	else:
		_look_finger = finger
		_look_last = pos


func _release(finger: int) -> void:
	if finger == _jump_finger:
		_jump_finger = -1
		Input.action_release("jump")
		_canvas.queue_redraw()
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_center = _stick_home
		_knob = _stick_home
		_set_stick(Vector2.ZERO)
	if finger == _look_finger:
		_look_finger = -1


## Routes a drag to the stick or the look finger. Normally by index; but if the
## position is clearly the other thumb's (browsers can renumber fingers when one
## lifts), it goes to that thumb and the index is taken over.
func _drag(finger: int, pos: Vector2) -> void:
	# The jump thumb only looks if it started the look.
	if finger == _jump_finger and finger != _look_finger:
		return
	var to_look := pos.distance_to(_look_last) if _look_finger >= 0 else INF
	var to_stick := pos.distance_to(_knob) if _stick_finger >= 0 else INF
	var own_look := finger == _look_finger and to_look <= to_stick
	var own_stick := finger == _stick_finger and to_stick <= to_look
	if own_look or (finger != _stick_finger and to_look < to_stick):
		_look_finger = finger
		_look(pos)
	elif own_stick or to_stick < INF:
		_stick_finger = finger
		_move_stick(pos)


func _look(pos: Vector2) -> void:
	var step := pos - _look_last
	_look_last = pos
	# Not a finger movement: start again from here without turning.
	if step.length() > _size.y * MAX_STEP:
		return
	if invert_y:
		step.y = -step.y
	if player:
		player.add_look(step * LOOK_SPEED * sensitivity)


func _move_stick(pos: Vector2) -> void:
	var offset := pos - _stick_center
	# Past the edge the base follows the thumb.
	if offset.length() > STICK_RADIUS:
		_stick_center = pos - offset.normalized() * STICK_RADIUS
		offset = pos - _stick_center
	_knob = pos
	var v := offset / STICK_RADIUS
	var amount := clampf((v.length() - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)
	_set_stick(v.normalized() * pow(amount, STICK_CURVE) if amount > 0.0 else Vector2.ZERO)


func _set_stick(v: Vector2) -> void:
	_stick_value = v
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_forward", "move_back", v.y)
	_update_sprint()
	_canvas.queue_redraw()


func _update_sprint() -> void:
	var forward := _stick_value.y < -0.3
	var sprint := forward and _stick_value.length() >= AUTO_SPRINT and _stick_value.y < -0.75
	if sprint != _sprinting:
		_sprinting = sprint
		if sprint:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")


func _set_axis(negative: String, positive: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	# Stick: a ring with a direction mark, and the knob.
	var active := _stick_finger >= 0
	_canvas.draw_circle(_stick_center, STICK_RADIUS, Color(0, 0, 0, 0.18 if active else 0.1))
	_canvas.draw_arc(_stick_center, STICK_RADIUS, 0, TAU, 48, COLOR_LINE if active else Color(1, 1, 1, 0.35), 3.0, true)
	var knob_color := COLOR_ACTIVE if _sprinting else Color(1, 1, 1, 0.55 if active else 0.3)
	_canvas.draw_circle(_knob, KNOB_RADIUS, knob_color)
	_canvas.draw_arc(_knob, KNOB_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
	if _sprinting:
		_text(font, _stick_center + Vector2(0, -STICK_RADIUS - 18), "KOŞ", 22, COLOR_ACTIVE)

	_round_button(_jump_pos, JUMP_RADIUS, "ZIPLA", _jump_finger >= 0)
	_round_button(_gear_pos, GEAR_RADIUS, "", false)
	# A menu icon: three bars.
	for k in 3:
		var y := _gear_pos.y + (k - 1) * 8.0
		_canvas.draw_line(Vector2(_gear_pos.x - 11, y), Vector2(_gear_pos.x + 11, y), Color.WHITE, 3.0, true)


func _round_button(pos: Vector2, radius: float, label: String, on: bool) -> void:
	_canvas.draw_circle(pos, radius, Color(1, 0.85, 0.3, 0.35) if on else Color(0, 0, 0, 0.22))
	_canvas.draw_arc(pos, radius, 0, TAU, 40, COLOR_ACTIVE if on else COLOR_LINE, 3.0, true)
	if label != "":
		_text(ThemeDB.fallback_font, pos, label, int(radius * 0.42), Color.WHITE)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := center + Vector2(-width * 0.5, size * 0.35)
	_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.8))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _open_settings() -> void:
	for finger in [_stick_finger, _look_finger, _jump_finger]:
		if finger >= 0:
			_release(finger)
	_settings.visible = true


## A small panel: look sensitivity and invert. Touches reach it as emulated mouse
## clicks (project setting pointing/emulate_mouse_from_touch).
func _build_settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.92)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Ayarlar"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 22)
	box.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.3
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = sensitivity
	slider.custom_minimum_size = Vector2(0, 48)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.2)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate()
	filled.bg_color = Color(1, 0.85, 0.3, 0.8)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var show_value := func(v: float) -> void: value_label.text = "Bakış hassasiyeti: %.2f" % v
	show_value.call(sensitivity)
	slider.value_changed.connect(func(v: float) -> void:
		sensitivity = v
		show_value.call(v)
		_save_settings())
	box.add_child(slider)

	var invert := CheckButton.new()
	invert.text = "Dikey bakışı ters çevir"
	invert.add_theme_font_size_override("font_size", 22)
	invert.button_pressed = invert_y
	invert.toggled.connect(func(on: bool) -> void:
		invert_y = on
		_save_settings())
	box.add_child(invert)

	var quality_label := Label.new()
	quality_label.text = "Grafik kalitesi (takılıyorsa düşür)"
	quality_label.add_theme_font_size_override("font_size", 22)
	box.add_child(quality_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for k in QUALITY_NAMES.size():
		var choice := Button.new()
		choice.text = QUALITY_NAMES[k]
		choice.toggle_mode = true
		choice.button_group = group
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size = Vector2(0, 56)
		choice.add_theme_font_size_override("font_size", 20)
		choice.button_pressed = Quality.auto if k == 0 else (not Quality.auto and Quality.level == k - 1)
		choice.pressed.connect(func() -> void:
			get_tree().current_scene.set_quality(Quality.level if k == 0 else k - 1, k == 0))
		row.add_child(choice)
	box.add_child(row)

	var close := Button.new()
	close.text = "Kapat"
	close.add_theme_font_size_override("font_size", 24)
	close.custom_minimum_size = Vector2(0, 56)
	close.pressed.connect(func() -> void: panel.visible = false)
	box.add_child(close)
	panel.visible = false
	return panel


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sensitivity = config.get_value("touch", "sensitivity", 1.0)
		invert_y = config.get_value("touch", "invert_y", false)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("touch", "sensitivity", sensitivity)
	config.set_value("touch", "invert_y", invert_y)
	config.save(SETTINGS_PATH)


## Browsers only allow fullscreen and an orientation lock from inside a real
## touch handler, so a one-shot listener asks for both on the first touch.
func _request_fullscreen_on_touch() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		document.addEventListener('touchend', function () {
			var el = document.documentElement;
			var go = el.requestFullscreen || el.webkitRequestFullscreen;
			if (go) {
				Promise.resolve(go.call(el)).then(function () {
					if (screen.orientation && screen.orientation.lock) {
						screen.orientation.lock('landscape').catch(function () {});
					}
				}).catch(function () {});
			}
		}, { once: true });
	""", true)
