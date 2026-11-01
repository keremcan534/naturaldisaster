extends PanelContainer
## The settings window, opened from the main menu and the pause menu: look
## sensitivity, graphics quality and, on touch screens, button size, invert,
## auto-jump and moving the buttons. Touches reach it as emulated mouse clicks
## (project setting pointing/emulate_mouse_from_touch).

signal closed

const Quality := preload("res://scripts/core/quality.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Ui := preload("res://scripts/ui/ui.gd")
const Gyro := preload("res://scripts/core/gyro.gd")
const Lang := preload("res://scripts/core/lang.gd")
const Profile := preload("res://scripts/core/profile.gd")

const QUALITY_NAMES := ["Otomatik", "Düşük", "Orta", "Yüksek"]
const BOT_LEVELS := ["Kolay", "Normal", "Zor"]

## The touch controls, or null on desktop.
var controls: Node

var _quality_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(660, 0)
	add_theme_stylebox_override("panel", Ui.panel_style())
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	add_child(outer)
	outer.add_child(Ui.title("Ayarlar", 30))
	# Everything but the title and the close button scrolls (short screens).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(640, 500)
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	# Name (shown on the scoreboard) and language.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(Ui.text("Adın", 20))
	var name_edit := LineEdit.new()
	name_edit.text = Profile.player_name
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(220, 44)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.text_changed.connect(func(text: String) -> void:
		var clean := text.strip_edges()
		if clean != "":
			Profile.player_name = clean
			Profile.save_profile())
	name_row.add_child(name_edit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)
	var language_group := ButtonGroup.new()
	for entry: Array in [["tr", "Türkçe"], ["en", "English"]]:
		var choice := Ui.button(entry[1], 18)
		choice.toggle_mode = true
		choice.button_group = language_group
		choice.button_pressed = Settings.language == entry[0]
		choice.pressed.connect(func() -> void:
			Settings.language = entry[0]
			Settings.save_settings()
			Lang.apply(entry[0]))
		name_row.add_child(choice)
	box.add_child(name_row)
	box.add_child(_slider_row("Bakış hassasiyeti", 0.3, 3.0, Settings.sensitivity, func(v: float) -> void:
		Settings.sensitivity = v))
	box.add_child(_slider_row("Ses", 0.0, 1.0, Settings.volume, func(v: float) -> void:
		Settings.volume = v
		Settings.apply_volume()))
	box.add_child(_slider_row("Müzik", 0.0, 1.0, Settings.music, func(v: float) -> void:
		Settings.music = v))
	box.add_child(_slider_row("Arayüz boyutu", 0.8, 1.3, Settings.ui_scale, func(v: float) -> void:
		Settings.ui_scale = v
		get_tree().root.content_scale_factor = v
		if controls:
			controls.apply_settings()))
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

	box.add_child(_toggle("Renk körü modu", Settings.colorblind, func(on: bool) -> void:
		Settings.colorblind = on))
	box.add_child(_toggle("Üçüncü şahıs kamera (V)", Settings.third_person, func(on: bool) -> void:
		Settings.third_person = on
		for p: Node in get_tree().get_nodes_in_group("player"):
			if not p.is_bot:
				p.apply_camera_mode()))
	if controls and Gyro.available():
		box.add_child(_toggle("Jiroskopla nişan (telefonu çevirerek bak)", Settings.gyro, func(on: bool) -> void:
			Settings.gyro = on
			if on:
				Gyro.start()))
	box.add_child(Ui.text("Bot seviyesi", 20))
	var bots := HBoxContainer.new()
	bots.add_theme_constant_override("separation", 8)
	var bot_group := ButtonGroup.new()
	for k in BOT_LEVELS.size():
		var choice := Ui.button(BOT_LEVELS[k], 20)
		choice.toggle_mode = true
		choice.button_group = bot_group
		choice.button_pressed = Settings.bot_level == k
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.pressed.connect(func() -> void:
			Settings.bot_level = k
			Settings.save_settings())
		bots.add_child(choice)
	box.add_child(bots)
	box.add_child(_toggle("Performans bilgisi göster (takılma olursa ekran görüntüsü at)", Settings.perf_overlay, func(on: bool) -> void:
		Settings.perf_overlay = on))
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
	outer.add_child(close)
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
	label.text = "%s: %.2f" % [Lang.t(caption), value]
	slider.value_changed.connect(func(v: float) -> void:
		label.text = "%s: %.2f" % [Lang.t(caption), v]
		changed.call(v)
		Settings.save_settings())
	row.add_child(slider)
	return row
