extends ColorRect
## The daily lucky wheel (main menu, once a day): eight slices of coins and a
## prize slice (an outfit or extra not owned yet). The result is decided when
## ÇEVİR is pressed (Profile.spin_wheel), then the wheel spins down onto it,
## clicking past every slice.

signal closed

const Profile := preload("res://scripts/core/profile.gd")
const Ui := preload("res://scripts/ui/ui.gd")
const Lang := preload("res://scripts/core/lang.gd")

const RADIUS := 140.0
const SPIN_TIME := 4.2
const COLORS := [Color(0.95, 0.3, 0.3), Color(1.0, 0.7, 0.15), Color(0.3, 0.8, 0.4), Color(0.25, 0.55, 0.95),
		Color(0.7, 0.4, 0.95), Color(1.0, 0.5, 0.75), Color(0.2, 0.8, 0.85), Color(1.0, 0.85, 0.3)]

var _disc: Control
var _result: Label
var _button: Button
var _angle := 0.0
var _spinning := false
var _last_slice := -1
var _done := false


func _ready() -> void:
	color = Color(0, 0, 0, 0.5)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	panel.add_child(row)
	_disc = Control.new()
	_disc.custom_minimum_size = Vector2(RADIUS * 2.0 + 16.0, RADIUS * 2.0 + 28.0)
	_disc.draw.connect(_draw_disc)
	row.add_child(_disc)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(250, 0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 16)
	row.add_child(side)
	side.add_child(Ui.title("ŞANS ÇARKI", 34))
	var note := Ui.text("Her gün bir kez bedava!", 18, Color(1, 1, 1, 0.8))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(note)
	_result = Ui.text("", 24, Ui.COIN)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_result)
	_button = Ui.button("ÇEVİR!", 30, true)
	_button.pressed.connect(_on_button)
	side.add_child(_button)
	visibility_changed.connect(func() -> void:
		if visible:
			_reset())


func _reset() -> void:
	_done = false
	_spinning = false
	_result.text = ""
	_button.text = tr("ÇEVİR!")
	_button.disabled = false


func _on_button() -> void:
	if _spinning:
		return
	if _done or not Profile.wheel_ready():
		closed.emit()
		return
	var outcome := Profile.spin_wheel()
	if outcome.is_empty():
		closed.emit()
		return
	var slices := Profile.WHEEL.size()
	var step := TAU / slices
	var index: int = outcome.slice
	# Several full turns, then the pointer (at the top) lands inside the slice.
	var land := float(index) + 0.5 + randf_range(-0.35, 0.35)
	var target := ceilf((_angle + 5.0 * TAU + land * step) / TAU) * TAU - land * step
	_spinning = true
	_button.disabled = true
	var tween := create_tween()
	tween.tween_method(_set_angle, _angle, target, SPIN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish.bind(outcome))


func _set_angle(value: float) -> void:
	_angle = value
	var slice := _slice_at_pointer()
	if slice != _last_slice:
		_last_slice = slice
		get_tree().call_group("sound", "play", "click", null, -8.0, 1.6)
	_disc.queue_redraw()


func _slice_at_pointer() -> int:
	var step := TAU / Profile.WHEEL.size()
	return int(fposmod(-_angle, TAU) / step) % Profile.WHEEL.size()


func _finish(outcome: Dictionary) -> void:
	_spinning = false
	_done = true
	_button.disabled = false
	_button.text = tr("TAMAM")
	if outcome.has("item"):
		_result.text = Lang.t("Yeni kıyafet: %s!") % tr(Profile.item(outcome.item).name)
	else:
		_result.text = Lang.t("+%d coin!") % outcome.coins
	get_tree().call_group("sound", "play", "win", null, -4.0)
	get_tree().call_group("sound", "play", "coin", null, -2.0)


func _draw_disc() -> void:
	var center := Vector2(RADIUS + 8.0, RADIUS + 20.0)
	var slices := Profile.WHEEL.size()
	var step := TAU / slices
	var font := ThemeDB.fallback_font
	for k in slices:
		# Slice k spans [k, k + 1) steps clockwise from the top, turned by _angle.
		var from := -PI * 0.5 + _angle + k * step
		var points := PackedVector2Array([center])
		for j in 13:
			var a := from + step * j / 12.0
			points.append(center + Vector2(cos(a), sin(a)) * RADIUS)
		_disc.draw_colored_polygon(points, COLORS[k % COLORS.size()])
		var slice: Dictionary = Profile.WHEEL[k]
		var label := tr("HEDİYE") if slice.get("prize", false) else str(slice.coins)
		_disc.draw_set_transform(center, from + step * 0.5, Vector2.ONE)
		_disc.draw_string_outline(font, Vector2(RADIUS * 0.3, 8), label, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 0.62,
				22, 5, Color(0, 0, 0, 0.7))
		_disc.draw_string(font, Vector2(RADIUS * 0.3, 8), label, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 0.62, 22)
		_disc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_disc.draw_arc(center, RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.9), 5.0, true)
	_disc.draw_circle(center, 18.0, Color(0.95, 0.95, 0.95))
	_disc.draw_circle(center, 10.0, Ui.ACCENT)
	# The pointer at the top.
	var tip := center + Vector2(0, -RADIUS + 14.0)
	_disc.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -30), tip + Vector2(14, -30)]), Color.WHITE)
	_disc.draw_polyline(PackedVector2Array([tip, tip + Vector2(-14, -30), tip + Vector2(14, -30), tip]),
			Color(0.1, 0.1, 0.1), 2.0, true)
