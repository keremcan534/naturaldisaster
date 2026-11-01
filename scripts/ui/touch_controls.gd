extends CanvasLayer
## On-screen controls for touch devices, laid out the way mobile shooters do it
## (PUBG Mobile, Minecraft): both thumbs rest near the bottom corners.
## - Left thumb: a floating analog joystick. It rests at a home spot, jumps to
##   where the thumb lands in the lower left, and follows the thumb past its edge.
##   Pushed fully forward it sprints; dragged further up onto the lock above it
##   and released, it keeps running forward (auto-run) until the stick is touched.
## - Right thumb: drag anywhere outside the stick area to look; a big jump button
##   where the thumb rests, which can also be dragged to look.
## - A menu button (top left) opens the pause menu (settings, main menu); next
##   to it "Takip" (the nearest bots follow), "Selam" (wave) and "Kamera"
##   (first / third person).
## - Small buttons around the jump button: crouch (a toggle) and the items
##   bought in the shop, each with what is left this round.
## Movement goes through the regular input actions (analog strengths), so the
## player doesn't care where input comes from. Settings live in settings.gd.
##
## Every finger is tracked by its own index from press to release, and the view
## turns by that finger's own movement only, so a second finger landing or
## lifting never makes the camera jump.

signal menu_requested

const Settings := preload("res://scripts/core/settings.gd")

## Sizes at button size 1.
const STICK_RADIUS := 100.0
const KNOB_RADIUS := 44.0
const JUMP_RADIUS := 74.0
const GEAR_RADIUS := 28.0
const SMALL_RADIUS := 34.0
## Around the jump button: angle (degrees, 0 = right, 90 = down) and distance in
## jump radii.
const CROUCH_SPOT := Vector2(160.0, 2.05)
const ITEM_SPOTS := [Vector2(205.0, 2.1), Vector2(238.0, 2.1), Vector2(272.0, 2.0)]
const ITEM_IDS := ["parachute", "bandage", "hook"]
const ITEM_NAMES := {"parachute": "Paraşüt", "bandage": "Sargı", "hook": "Kanca"}
## Fraction of the radius ignored around the center, and the response curve.
const STICK_DEADZONE := 0.08
const STICK_CURVE := 1.1
## Pushed this far, mostly forward, the player sprints; it stops sprinting only
## below SPRINT_OFF, so a thumb resting at the edge doesn't flicker between them.
const AUTO_SPRINT := 0.92
const SPRINT_OFF := 0.8
## The auto-run lock sits this many stick radii above the stick's center.
const LOCK_DISTANCE := 1.9
const LOCK_RADIUS := 34.0
## Radians of turn per pixel dragged at sensitivity 1 (half a turn is about a
## third of the screen width).
const LOOK_SPEED := 0.0075
## A single drag step longer than this (fraction of screen height) can't be a
## finger moving; it is skipped. Fast swipes on a slow frame stay well below it.
const MAX_STEP := 0.4
## Touches starting left of this and below the top band go to the stick.
const STICK_AREA := Vector2(0.45, 0.3)

const COLOR_LINE := Color(1, 1, 1, 0.55)
const COLOR_ACTIVE := Color(1, 0.85, 0.3, 0.8)

var player: Node

var _canvas: Control
var _size := Vector2(1280, 720)

## Fingers on the screen: index -> {"role": "stick"/"look"/"jump", "last": Vector2}.
var _fingers := {}
## The finger turning the view (the newest one on the look side), or -1.
var _look_finger := -1
var _stick_finger := -1
var _jump_finger := -1

var _stick_center := Vector2.ZERO
var _knob := Vector2.ZERO
var _stick_value := Vector2.ZERO
var _sprinting := false
var _lock_armed := false
var _auto_run := false
var _jump_pos := Vector2.ZERO
var _gear_pos := Vector2.ZERO
var _crouch := false
var _items := {}

## Layout editing: which control a finger is dragging ("stick"/"jump").
var _editing := false
var _edit_finger := -1
var _edit_target := ""


func _ready() -> void:
	add_to_group("touch_controls")
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	get_viewport().size_changed.connect(_layout)
	if player:
		player.items_changed.connect(func(items: Dictionary) -> void:
			_items = items.duplicate()
			_canvas.queue_redraw())
	_layout()
	_request_fullscreen_on_touch()


## Shown while playing; hidden (and every finger let go) in menus.
func set_active(on: bool) -> void:
	if not on:
		_release_all()
	visible = on
	set_process_input(on)


## Settings changed (button size): redraw.
func apply_settings() -> void:
	_layout()


func start_editing() -> void:
	_release_all()
	_editing = true
	_canvas.queue_redraw()


func _stick_radius() -> float:
	return STICK_RADIUS * Settings.button_size


func _jump_radius() -> float:
	return JUMP_RADIUS * Settings.button_size


func _small_radius() -> float:
	return SMALL_RADIUS * Settings.button_size


func _around_jump(spot: Vector2) -> Vector2:
	var angle := deg_to_rad(spot.x)
	var at := _jump_pos + Vector2(cos(angle), sin(angle)) * spot.y * _jump_radius()
	var r := _small_radius()
	return at.clamp(Vector2(r, r), _size - Vector2(r, r))


## The small buttons now on screen: [id, center, label].
func _small_buttons() -> Array:
	var list := [["crouch", _around_jump(CROUCH_SPOT), "Çömel"],
			["follow", _gear_pos + Vector2(GEAR_RADIUS + _small_radius() + 14.0, 0), "Takip"],
			["wave", _gear_pos + Vector2(GEAR_RADIUS + _small_radius() * 3.0 + 26.0, 0), "Selam"],
			["camera", _gear_pos + Vector2(GEAR_RADIUS + _small_radius() * 5.0 + 38.0, 0), "Kamera"]]
	var slot := 0
	for id: String in ITEM_IDS:
		if _items.get(id, 0) > 0:
			list.append([id, _around_jump(ITEM_SPOTS[slot]), ITEM_NAMES[id]])
			slot += 1
	return list


func _press_small(id: String) -> void:
	Input.vibrate_handheld(10)
	match id:
		"crouch":
			_crouch = not _crouch
			if _crouch:
				Input.action_press("crouch")
			else:
				Input.action_release("crouch")
		"follow":
			player.call_followers()
		"wave":
			player.wave()
		"camera":
			player.toggle_camera()
		_:
			player.use_item(id)
	_canvas.queue_redraw()


func _layout() -> void:
	_size = get_viewport().get_visible_rect().size
	_jump_pos = Settings.jump_home * _size
	# Under the health bar, out of the way of both thumbs.
	_gear_pos = Vector2(maxf(24.0, _size.y * 0.04) + GEAR_RADIUS + 4.0, 118.0)
	if _stick_finger < 0:
		_stick_center = Settings.stick_home * _size
		_knob = _stick_center
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
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
	if _fingers.has(finger):
		_release(finger)
	if pos.distance_to(_gear_pos) < GEAR_RADIUS * 1.6:
		_release_all()
		menu_requested.emit()
		return
	var role := "look"
	for button: Array in _small_buttons():
		if pos.distance_to(button[1]) < _small_radius() * 1.15:
			_press_small(button[0])
			_fingers[finger] = {"role": "button", "last": pos}
			return
	if pos.distance_to(_jump_pos) < _jump_radius() * 1.25:
		role = "jump"
		_jump_finger = finger
		Input.action_press("jump")
		Input.vibrate_handheld(15)
		# The jump thumb can keep turning the view if nothing else does.
		if _look_finger < 0:
			_look_finger = finger
		_canvas.queue_redraw()
	elif pos.x < _size.x * STICK_AREA.x and pos.y > _size.y * STICK_AREA.y and _stick_finger < 0:
		role = "stick"
		_stick_finger = finger
		_auto_run = false
		_stick_center = pos
		_knob = pos
		_set_stick(Vector2.ZERO)
	else:
		_look_finger = finger
	_fingers[finger] = {"role": role, "last": pos}


func _release(finger: int) -> void:
	if not _fingers.has(finger):
		return
	_fingers.erase(finger)
	if finger == _jump_finger:
		_jump_finger = -1
		Input.action_release("jump")
		_canvas.queue_redraw()
	if finger == _stick_finger:
		_stick_finger = -1
		_auto_run = _lock_armed
		_lock_armed = false
		_stick_center = Settings.stick_home * _size
		_knob = _stick_center
		# Auto-run: keep running forward with the thumb off the screen.
		_set_stick(Vector2(0, -1) if _auto_run else Vector2.ZERO)
	if finger == _look_finger:
		# Another finger still on the look side takes over (from where it is now).
		_look_finger = -1
		for other: int in _fingers:
			if _fingers[other].role == "look" or _fingers[other].role == "jump":
				_look_finger = other


func _drag(finger: int, pos: Vector2) -> void:
	if not _fingers.has(finger):
		# A finger whose press never arrived: it starts counting from here. If it
		# lands on the stick while the stick's own finger went stale, it takes the stick.
		if _stick_finger >= 0 and pos.distance_to(_knob) < _stick_radius() * 1.2:
			_release(_stick_finger)
			_press(finger, pos)
		else:
			_fingers[finger] = {"role": "look", "last": pos}
			if _look_finger < 0:
				_look_finger = finger
		return
	var state: Dictionary = _fingers[finger]
	var step: Vector2 = pos - state.last
	state.last = pos
	if state.role == "stick":
		_move_stick(pos)
	elif finger == _look_finger:
		_look(step)


func _look(step: Vector2) -> void:
	if step.length() > _size.y * MAX_STEP:
		return
	if Settings.invert_y:
		step.y = -step.y
	if player:
		player.add_look(step * LOOK_SPEED * Settings.sensitivity)


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
	var forward := v.y < -0.7
	var sprint := _auto_run or (forward and v.length() >= (SPRINT_OFF if _sprinting else AUTO_SPRINT))
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
	_canvas.draw_circle(_knob, KNOB_RADIUS * Settings.button_size, knob_color)
	_canvas.draw_arc(_knob, KNOB_RADIUS * Settings.button_size, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
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

	# Crouch, items, team calls.
	for button: Array in _small_buttons():
		var at: Vector2 = button[1]
		var r := _small_radius()
		var lit: bool = button[0] == "crouch" and _crouch
		_canvas.draw_circle(at, r, Color(1, 0.85, 0.3, 0.4) if lit else Color(0, 0, 0, 0.28))
		_canvas.draw_arc(at, r, 0, TAU, 32, COLOR_ACTIVE if lit else COLOR_LINE, 2.0, true)
		var count: int = _items.get(button[0], 0)
		if count > 0:
			_text(font, at + Vector2(0, -6), button[2], 15, Color.WHITE)
			_text(font, at + Vector2(0, 12), "×%d" % count, 15, COLOR_ACTIVE)
		else:
			_text(font, at, button[2], 15, Color.WHITE)

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


func _release_all() -> void:
	for finger: int in _fingers.keys():
		_release(finger)
	_auto_run = false
	if _crouch:
		_crouch = false
		Input.action_release("crouch")
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
					Settings.stick_home = Settings.STICK_HOME
					Settings.jump_home = Settings.JUMP_HOME
					_layout()
				else:
					_editing = false
					Settings.save_settings()
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
			Settings.stick_home = at
		else:
			Settings.jump_home = at
		_layout()


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
