extends CanvasLayer
## On-screen controls for touch devices: a floating joystick on the left half,
## drag-to-look on the right half, and jump / sprint buttons. The joystick and
## buttons press the regular input actions, so the player doesn't care where
## input comes from.

const STICK_RADIUS := 90.0
const KNOB_RADIUS := 40.0
const STICK_DEADZONE := 0.15
const BUTTON_RADIUS := 58.0
## Radians of turn per pixel dragged.
const LOOK_SENSITIVITY := 0.005
## A drag step longer than this (fraction of screen height) is not a real finger
## movement: browsers can renumber fingers or skip events when one lifts, and
## trusting that step would whip the camera around.
const MAX_STEP := 0.15

var player: Node

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _look_finger := -1
## Last positions of the look and stick fingers; deltas are computed from these
## instead of trusting event.relative.
var _look_last := Vector2.ZERO
var _stick_last := Vector2.ZERO
## Finger index -> action held by that finger.
var _button_fingers := {}
var _base: Panel
var _knob: Panel
## Action -> button panel.
var _buttons := {}


func _ready() -> void:
	_base = _circle(STICK_RADIUS, Color(1, 1, 1, 0.12))
	_knob = _circle(KNOB_RADIUS, Color(1, 1, 1, 0.4))
	_base.visible = false
	_knob.visible = false
	_buttons["jump"] = _button("Zıpla")
	_buttons["sprint"] = _button("Koş")
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_place(_buttons["jump"], size - Vector2(110, 120))
	_place(_buttons["sprint"], size - Vector2(250, 80))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)


## Routes a drag to the stick or the look finger. A finger is matched by index
## first, but only if the new position is a plausible step from where that finger
## was; otherwise by position, so a renumbered finger keeps its role.
func _drag(finger: int, pos: Vector2) -> void:
	if _button_fingers.has(finger):
		return
	var max_step := get_viewport().get_visible_rect().size.y * MAX_STEP
	var to_look := pos.distance_to(_look_last) if _look_finger >= 0 else INF
	var to_stick := pos.distance_to(_stick_last) if _stick_finger >= 0 else INF
	if finger == _look_finger and to_look <= max_step:
		_look(pos)
	elif finger == _stick_finger and to_stick <= max_step:
		_move_stick(pos)
	elif to_look <= max_step and to_look <= to_stick:
		_look_finger = finger
		_look(pos)
	elif to_stick <= max_step:
		_stick_finger = finger
		_move_stick(pos)
	elif finger == _look_finger:
		# A jump: start again from here without turning.
		_look_last = pos


func _look(pos: Vector2) -> void:
	var step := pos - _look_last
	_look_last = pos
	if player:
		player.add_look(step * LOOK_SENSITIVITY)


func _press(finger: int, pos: Vector2) -> void:
	for action: String in _buttons:
		var button: Panel = _buttons[action]
		if pos.distance_to(button.position + button.size * 0.5) < BUTTON_RADIUS * 1.2:
			_button_fingers[finger] = action
			Input.action_press(action)
			button.modulate.a = 0.6
			return
	# A new touch always takes over its side: if a lift was missed (renumbered
	# finger), the stale finger would otherwise block the stick or look for good.
	if finger == _stick_finger:
		_release(finger)
	if finger == _look_finger:
		_release(finger)
	if pos.x < get_viewport().get_visible_rect().size.x * 0.5:
		_stick_finger = finger
		_stick_origin = pos
		_stick_last = pos
		_place(_base, pos)
		_place(_knob, pos)
		_base.visible = true
		_knob.visible = true
	else:
		_look_finger = finger
		_look_last = pos


func _release(finger: int) -> void:
	if _button_fingers.has(finger):
		var action: String = _button_fingers[finger]
		_button_fingers.erase(finger)
		Input.action_release(action)
		_buttons[action].modulate.a = 1.0
	elif finger == _stick_finger:
		_stick_finger = -1
		_base.visible = false
		_knob.visible = false
		for action in ["move_left", "move_right", "move_forward", "move_back"]:
			Input.action_release(action)
	elif finger == _look_finger:
		_look_finger = -1


func _move_stick(pos: Vector2) -> void:
	_stick_last = pos
	var offset := (pos - _stick_origin).limit_length(STICK_RADIUS)
	_place(_knob, _stick_origin + offset)
	var v := offset / STICK_RADIUS
	if v.length() < STICK_DEADZONE:
		v = Vector2.ZERO
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_forward", "move_back", v.y)


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


## Centers a panel on pos.
func _place(panel: Panel, pos: Vector2) -> void:
	panel.position = pos - panel.size * 0.5


func _circle(radius: float, color: Color) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2.ONE * radius * 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _button(text: String) -> Panel:
	var panel := _circle(BUTTON_RADIUS, Color(1, 1, 1, 0.22))
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(label)
	return panel
