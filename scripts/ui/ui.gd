extends RefCounted
## Shared look for menus and panels: dark rounded panels, big thumb-sized
## buttons, outlined text, and a coin counter.

const ACCENT := Color(1.0, 0.78, 0.22)
const COIN := Color(1.0, 0.8, 0.2)


static func panel_style(alpha := 0.94) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, alpha)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(22)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(2)
	return style


static func text(value: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", maxi(4, size / 5))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


static func title(value: String, size: int) -> Label:
	var label := text(value, size, ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## primary: the bright call-to-action color (OYNA).
static func button(value: String, size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = value
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, size * 2.4)
	b.focus_mode = Control.FOCUS_NONE
	var base := Color(1.0, 0.72, 0.15) if primary else Color(0.2, 0.24, 0.3)
	var font := Color(0.1, 0.07, 0.02) if primary else Color.WHITE
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(12)
		style.set_content_margin_all(10)
		match state:
			"normal":
				style.bg_color = base
			"hover":
				style.bg_color = base.lightened(0.12)
			"pressed", "hover_pressed":
				# Also the look of a selected toggle (quality choice): clearly lit.
				style.bg_color = ACCENT.darkened(0.25) if primary else Color(0.85, 0.6, 0.12)
			_:
				style.bg_color = base.darkened(0.45)
		style.border_color = Color(1, 1, 1, 0.15)
		style.border_width_bottom = 4
		b.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, font)
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.02))
	b.add_theme_color_override("font_hover_pressed_color", Color(0.1, 0.07, 0.02))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.pressed.connect(func() -> void: b.get_tree().call_group("sound", "play", "click"))
	return b


## A coin icon and an amount; call set_amount to update it.
class CoinLabel extends HBoxContainer:
	var _label: Label
	var _size := 26

	func _init(size := 26) -> void:
		_size = size
		add_theme_constant_override("separation", 8)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(size, size)
		icon.draw.connect(func() -> void:
			var c := icon.size * 0.5
			var r := minf(icon.size.x, icon.size.y) * 0.5
			icon.draw_circle(c, r, Color(0.75, 0.5, 0.05))
			icon.draw_circle(c, r * 0.8, COIN)
			icon.draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.45), Vector2(r * 0.24, r * 0.9)), Color(0.8, 0.55, 0.08)))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(icon)
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", size)
		_label.add_theme_color_override("font_color", COIN)
		_label.add_theme_constant_override("outline_size", 6)
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		add_child(_label)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_amount(amount: int) -> void:
		_label.text = str(amount)
