extends CanvasLayer
## On-screen controls for touch devices, laid out the way mobile shooters do it
## (PUBG Mobile, Minecraft): both thumbs rest near the bottom corners.
## - Left thumb: a floating analog joystick. It rests at a home spot, jumps to
##   where the thumb lands in the lower left, and follows the thumb past its edge.
##   Pushed fully forward it sprints; dragged further up onto the lock above it
##   and released, it keeps running forward (auto-run) until the stick is touched.
## - Right thumb: drag anywhere outside the stick area to look; a big jump button
##   where the thumb rests, which can also be dragged to look.
## - A menu button (top left): look sensitivity, invert, button size, moving the
##   buttons ("Tuşları yerleştir") and graphics quality. Saved in settings.cfg.
## Movement goes through the regular input actions (analog strengths), so the
## player doesn't care where input comes from.

const Quality := preload("res://scripts/core/quality.gd")

const SETTINGS_PATH := "user://settings.cfg"

## Sizes at button size 1.
const STICK_RADIUS := 100.0
const KNOB_RADIUS := 44.0
const JUMP_RADIUS := 74.0
const GEAR_RADIUS := 28.0
## Default spots (fractions of the screen); the player can move them.
const STICK_HOME := Vector2(0.16, 0.72)
const JUMP_HOME := Vector2(0.87, 0.7)
## Fraction of the radius ignored around the center, and the response curve.
const STICK_DEADZONE := 0.08
const STICK_CURVE := 1.1
## Pushed this far, mostly forward, the player sprints.
const AUTO_SPRINT := 0.92
## The auto-run lock sits this many stick radii above the stick's center.
const LOCK_DISTANCE := 1.9
const LOCK_RADIUS := 34.0
## Radians of turn per pixel dragged at sensitivity 1 (half a turn is about a
## third of the screen width).
const LOOK_SPEED := 0.0075
## A single drag step longer than this (fraction of screen height) can't be a
## finger: browsers can renumber fingers when one lifts. Fast swipes on a slow
## frame stay well below it.
const MAX_STEP := 0.5
## Touches starting left of this and below the top band go to the stick.
const STICK_AREA := Vector2(0.45, 0.3)
const QUALITY_NAMES := ["Otomatik", "Düşük", "Orta", "Yüksek"]

const COLOR_LINE := Color(1, 1, 1, 0.55)
const COLOR_ACTIVE := Color(1, 0.85, 0.3, 0.8)

var player: Node

var sensitivity := 1.0
var invert_y := false
var button_size := 1.0
var stick_home := STICK_HOME
var jump_home := JUMP_HOME

var _canvas: Control
var _settings: PanelContainer
var _size := Vector2(1280, 720)

var _stick_finger := -1
var _stick_center := Vector2.ZERO
var _knob := Vector2.ZERO
var _stick_value := Vector2.ZERO
var _sprinting := false
var _lock_armed := false
var _auto_run := false

var _look_finger := -1
var _look_last := Vector2.ZERO
var _jump_finger := -1
var _jump_pos := Vector2.ZERO
var _gear_pos := Vector2.ZERO

## Layout editing: which control a finger is dragging ("stick"/"jump").
var _editing := false
var _edit_finger := -1
var _edit_target := ""


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


func _stick_radius() -> float:
	return STICK_RADIUS * button_size


func _jump_radius() -> float:
	return JUMP_RADIUS * button_size


func _layout() -> void:
	_size = get_viewport().get_visible_rect().size
	_jump_pos = jump_home * _size
	# Under the health bar, out of the way of both thumbs.
	_gear_pos = Vector2(maxf(24.0, _size.y * 0.04) + GEAR_RADIUS + 4.0, 118.0)
	if _stick_finger < 0:
		_stick_center = stick_home * _size
		_knob = _stick_center
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _settings.visible:
		return
	if _editing:
		_edit_input(event)
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
	if pos.distance_to(_jump_pos) < _jump_radius() * 1.25:
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
		_auto_run = false
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
		_auto_run = _lock_armed
		_lock_armed = false
		_stick_center = stick_home * _size
		_knob = _stick_center
		# Auto-run: keep running forward with the thumb off the screen.
		_set_stick(Vector2(0, -1) if _auto_run else Vector2.ZERO)
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
	var radius := _stick_radius()
	var offset := pos - _stick_center
	# Dragged up toward the lock: arm auto-run instead of dragging the base along.
	var up := offset.normalized().dot(Vector2.UP) > 0.8
	_lock_armed = up and offset.length() > radius * (LOCK_DISTANCE - 0.5)
	if not up and offset.length() > radius:
		# Past the edge the base follows the thumb.
		_stick_center = pos - offset.normalized() * radius
		offset = pos - _stick_center
	_knob = _stick_center + offset.limit_length(radius * LOCK_DISTANCE)
	var v := offset.limit_length(radius) / radius
	var amount := clampf((v.length() - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)
	_set_stick(v.normalized() * pow(amount, STICK_CURVE) if amount > 0.0 else Vector2.ZERO)


func _set_stick(v: Vector2) -> void:
	_stick_value = v
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_forward", "move_back", v.y)
	var sprint := _auto_run or (v.length() >= AUTO_SPRINT and v.y < -0.75)
	if sprint != _sprinting:
		_sprinting = sprint
		if sprint:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")
	_canvas.queue_redraw()


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
	var radius := _stick_radius()
	var active := _stick_finger >= 0
	# Stick: a ring and the knob.
	_canvas.draw_circle(_stick_center, radius, Color(0, 0, 0, 0.2 if active else 0.12))
	_canvas.draw_arc(_stick_center, radius, 0, TAU, 48, COLOR_LINE if active else Color(1, 1, 1, 0.35), 3.0, true)
	var knob_color := COLOR_ACTIVE if _sprinting else Color(1, 1, 1, 0.55 if active else 0.3)
	_canvas.draw_circle(_knob, KNOB_RADIUS * button_size, knob_color)
	_canvas.draw_arc(_knob, KNOB_RADIUS * button_size, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
	# The auto-run lock above the stick while it is held, or lit while running.
	if active or _auto_run:
		var lock := _stick_center + Vector2(0, -radius * LOCK_DISTANCE)
		var lit := _lock_armed or _auto_run
		_canvas.draw_circle(lock, LOCK_RADIUS, Color(1, 0.85, 0.3, 0.5) if lit else Color(0, 0, 0, 0.3))
		_canvas.draw_arc(lock, LOCK_RADIUS, 0, TAU, 32, COLOR_ACTIVE if lit else COLOR_LINE, 2.0, true)
		_arrow(lock, LOCK_RADIUS * 0.5, Color.WHITE)
		if _auto_run and not active:
			_text(font, lock + Vector2(0, -LOCK_RADIUS - 14), "OTOMATİK KOŞU", 18, COLOR_ACTIVE)
	elif _sprinting:
		_text(font, _stick_center + Vector2(0, -radius - 18), "KOŞ", 22, COLOR_ACTIVE)

	# Jump: a big round button with an up arrow.
	var jr := _jump_radius()
	var pressed := _jump_finger >= 0
	_canvas.draw_circle(_jump_pos, jr, Color(1, 0.85, 0.3, 0.35) if pressed else Color(0, 0, 0, 0.25))
	_canvas.draw_arc(_jump_pos, jr, 0, TAU, 48, COLOR_ACTIVE if pressed else COLOR_LINE, 3.0, true)
	_arrow(_jump_pos + Vector2(0, -4), jr * 0.42, Color.WHITE)

	# Menu: three bars.
	_canvas.draw_circle(_gear_pos, GEAR_RADIUS, Color(0, 0, 0, 0.25))
	_canvas.draw_arc(_gear_pos, GEAR_RADIUS, 0, TAU, 32, COLOR_LINE, 2.0, true)
	for k in 3:
		var y := _gear_pos.y + (k - 1) * 8.0
		_canvas.draw_line(Vector2(_gear_pos.x - 11, y), Vector2(_gear_pos.x + 11, y), Color.WHITE, 3.0, true)

	if _editing:
		_canvas.draw_rect(Rect2(Vector2.ZERO, _size), Color(0, 0, 0, 0.35))
		_text(font, Vector2(_size.x * 0.5, _size.y * 0.16), "Tuşları sürükleyip yerleştir", 30, Color.WHITE)
		for button: Array in _edit_buttons():
			var rect: Rect2 = button[1]
			_canvas.draw_rect(rect, Color(0.15, 0.17, 0.2, 0.9))
			_canvas.draw_rect(rect, COLOR_LINE, false, 2.0)
			_text(font, rect.get_center(), button[0], 24, Color.WHITE)
		_canvas.draw_arc(_stick_center, radius, 0, TAU, 48, COLOR_ACTIVE, 4.0, true)
		_canvas.draw_arc(_jump_pos, jr, 0, TAU, 48, COLOR_ACTIVE, 4.0, true)


## An upward arrow: a triangle head on a short shaft.
func _arrow(center: Vector2, size: float, color: Color) -> void:
	var head := PackedVector2Array([center + Vector2(0, -size), center + Vector2(size * 0.8, 0), center + Vector2(-size * 0.8, 0)])
	_canvas.draw_colored_polygon(head, color)
	_canvas.draw_rect(Rect2(center + Vector2(-size * 0.28, -0.01), Vector2(size * 0.56, size * 0.8)), color)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := center + Vector2(-width * 0.5, size * 0.35)
	_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.8))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _open_settings() -> void:
	_release_all()
	_settings.visible = true


func _release_all() -> void:
	for finger in [_stick_finger, _look_finger, _jump_finger]:
		if finger >= 0:
			_release(finger)
	_auto_run = false
	_set_stick(Vector2.ZERO)


## Layout editing: drag the stick or the jump button; "BİTTİ" saves, "SIFIRLA"
## puts both back.
func _edit_buttons() -> Array:
	var w := 200.0
	var y := _size.y * 0.25
	return [["BİTTİ", Rect2(_size.x * 0.5 - w - 10.0, y, w, 64.0)], ["SIFIRLA", Rect2(_size.x * 0.5 + 10.0, y, w, 64.0)]]


func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.index == _edit_finger:
				_edit_finger = -1
			return
		for button: Array in _edit_buttons():
			if (button[1] as Rect2).has_point(event.position):
				if button[0] == "SIFIRLA":
					stick_home = STICK_HOME
					jump_home = JUMP_HOME
					_layout()
				else:
					_editing = false
					_save_settings()
					_canvas.queue_redraw()
				return
		var to_stick: float = event.position.distance_to(_stick_center)
		var to_jump: float = event.position.distance_to(_jump_pos)
		if minf(to_stick, to_jump) < maxf(_stick_radius(), _jump_radius()) * 1.4:
			_edit_finger = event.index
			_edit_target = "stick" if to_stick < to_jump else "jump"
	elif event is InputEventScreenDrag and event.index == _edit_finger:
		var at: Vector2 = (event.position / _size).clamp(Vector2(0.05, 0.3), Vector2(0.95, 0.92))
		if _edit_target == "stick":
			stick_home = at
		else:
			jump_home = at
		_layout()


## The settings panel. Touches reach it as emulated mouse clicks (project
## setting pointing/emulate_mouse_from_touch).
func _build_settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(640, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.94)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Ayarlar"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	box.add_child(_slider_row("Bakış hassasiyeti", 0.3, 3.0, sensitivity, func(v: float) -> void:
		sensitivity = v))
	box.add_child(_slider_row("Tuş boyutu", 0.8, 1.4, button_size, func(v: float) -> void:
		button_size = v
		_layout()))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var invert := CheckButton.new()
	invert.text = "Dikey bakışı ters çevir"
	invert.add_theme_font_size_override("font_size", 20)
	invert.button_pressed = invert_y
	invert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invert.toggled.connect(func(on: bool) -> void:
		invert_y = on
		_save_settings())
	row.add_child(invert)
	var place := Button.new()
	place.text = "Tuşları yerleştir"
	place.add_theme_font_size_override("font_size", 20)
	place.custom_minimum_size = Vector2(220, 52)
	place.pressed.connect(func() -> void:
		panel.visible = false
		_editing = true
		_canvas.queue_redraw())
	row.add_child(place)
	box.add_child(row)

	var quality_label := Label.new()
	quality_label.text = "Grafik kalitesi (takılıyorsa düşür)"
	quality_label.add_theme_font_size_override("font_size", 20)
	box.add_child(quality_label)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for k in QUALITY_NAMES.size():
		var choice := Button.new()
		choice.text = QUALITY_NAMES[k]
		choice.toggle_mode = true
		choice.button_group = group
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size = Vector2(0, 52)
		choice.add_theme_font_size_override("font_size", 20)
		choice.button_pressed = Quality.auto if k == 0 else (not Quality.auto and Quality.level == k - 1)
		choice.pressed.connect(func() -> void:
			get_tree().current_scene.set_quality(Quality.level if k == 0 else k - 1, k == 0))
		choices.add_child(choice)
	box.add_child(choices)

	var close := Button.new()
	close.text = "Kapat"
	close.add_theme_font_size_override("font_size", 22)
	close.custom_minimum_size = Vector2(0, 56)
	close.pressed.connect(func() -> void: panel.visible = false)
	box.add_child(close)
	panel.visible = false
	return panel


## A label with the current value and a thick, thumb-friendly slider.
func _slider_row(caption: String, low: float, high: float, value: float, changed: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 40)
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
	label.text = "%s: %.2f" % [caption, value]
	slider.value_changed.connect(func(v: float) -> void:
		label.text = "%s: %.2f" % [caption, v]
		changed.call(v)
		_save_settings())
	row.add_child(slider)
	return row


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sensitivity = config.get_value("touch", "sensitivity", 1.0)
		invert_y = config.get_value("touch", "invert_y", false)
		button_size = config.get_value("touch", "button_size", 1.0)
		stick_home = config.get_value("touch", "stick_home", STICK_HOME)
		jump_home = config.get_value("touch", "jump_home", JUMP_HOME)


## Keeps the other sections (graphics) of the shared settings file.
func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("touch", "sensitivity", sensitivity)
	config.set_value("touch", "invert_y", invert_y)
	config.set_value("touch", "button_size", button_size)
	config.set_value("touch", "stick_home", stick_home)
	config.set_value("touch", "jump_home", jump_home)
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
