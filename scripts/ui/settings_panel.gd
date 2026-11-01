extends PanelContainer
## The settings window, opened from the main menu and the pause menu: look
## sensitivity, graphics quality and, on touch screens, button size, invert,
## auto-jump and moving the buttons. Touches reach it as emulated mouse clicks
## (project setting pointing/emulate_mouse_from_touch).

signal closed

const Quality := preload("res://scripts/core/quality.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Ui := preload("res://scripts/ui/ui.gd")

const QUALITY_NAMES := ["Otomatik", "Düşük", "Orta", "Yüksek"]

## The touch controls, or null on desktop.
var controls: Node

var _quality_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(660, 0)
	add_theme_stylebox_override("panel", Ui.panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(Ui.title("Ayarlar", 30))

	box.add_child(_slider_row("Bakış hassasiyeti", 0.3, 3.0, Settings.sensitivity, func(v: float) -> void:
		Settings.sensitivity = v))
	box.add_child(_slider_row("Ses", 0.0, 1.0, Settings.volume, func(v: float) -> void:
		Settings.volume = v
		Settings.apply_volume()))
	if controls:
		box.add_child(_slider_row("Tuş boyutu", 0.8, 1.4, Settings.button_size, func(v: float) -> void:
			Settings.button_size = v
			controls.apply_settings()))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_toggle("Dikey bakışı ters çevir", Settings.invert_y, func(on: bool) -> void:
		Settings.invert_y = on))
	if controls:
		row.add_child(_toggle("Otomatik zıpla", Settings.auto_jump, func(on: bool) -> void:
			Settings.auto_jump = on))
	box.add_child(row)
	if controls:
		var place := Ui.button("Tuşları yerleştir", 22)
		place.pressed.connect(func() -> void:
			closed.emit()
			controls.start_editing())
		box.add_child(place)

	box.add_child(Ui.text("Grafik kalitesi (takılıyorsa düşür)", 20))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for k in QUALITY_NAMES.size():
		var choice := Ui.button(QUALITY_NAMES[k], 20)
		choice.toggle_mode = true
		choice.button_group = group
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.pressed.connect(func() -> void:
			get_tree().current_scene.set_quality(Quality.level if k == 0 else k - 1, k == 0))
		choices.add_child(choice)
		_quality_buttons.append(choice)
	box.add_child(choices)

	var close := Ui.button("Kapat", 24, true)
	close.pressed.connect(func() -> void: closed.emit())
	box.add_child(close)
	visibility_changed.connect(_sync)
	_sync()


## Shows the current quality choice (auto mode may have moved it).
func _sync() -> void:
	if not visible:
		return
	for k in _quality_buttons.size():
		_quality_buttons[k].set_pressed_no_signal(Quality.auto if k == 0 else (not Quality.auto and Quality.level == k - 1))


func _toggle(caption: String, on: bool, changed: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = caption
	check.add_theme_font_size_override("font_size", 20)
	check.button_pressed = on
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.toggled.connect(func(value: bool) -> void:
		changed.call(value)
		Settings.save_settings())
	return check


## A label with the current value and a thick, thumb-friendly slider.
func _slider_row(caption: String, low: float, high: float, value: float, changed: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	var label := Ui.text("", 20)
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
		Settings.save_settings())
	row.add_child(slider)
	return row
