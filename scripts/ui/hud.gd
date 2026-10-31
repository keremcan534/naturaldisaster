extends CanvasLayer
## Round status, countdown, health bar, death message, score and coins, how many
## are still alive, and the scoreboard after every disaster.

const BuildInfo := preload("res://scripts/core/build_info.gd")
const Quality := preload("res://scripts/core/quality.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Ui := preload("res://scripts/ui/ui.gd")

## Set before adding to the tree; hides the keyboard hint.
var touch_mode := false

var _status: Label
var _timer: Label
var _center: Label
var _health: ProgressBar
var _health_fill: StyleBoxFlat
var _fps: Label
var _fps_timer := 0.0
var _alive: Label
var _score: Label
var _coins: Ui.CoinLabel
var _board: PanelContainer
var _board_rows: VBoxContainer
var _board_time := 0.0
var _manager: Node
var _player: Node


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

	_fps = _label(12)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_fps.offset_left = 22
	_fps.offset_top = 64
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Top right: coins and this session's score.
	var corner := VBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -20
	corner.offset_top = 16
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins = Ui.CoinLabel.new(24)
	_coins.size_flags_horizontal = Control.SIZE_SHRINK_END
	corner.add_child(_coins)
	_score = Ui.text("", 20)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(_score)
	add_child(corner)

	_alive = _label(20)
	_alive.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_alive.offset_top = 92
	_alive.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))

	_board = _build_board()
	add_child(_board)

	var hint := _label(14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -16
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = "WASD: yürü  Shift: koş  Space: zıpla  Fare: bak  Esc: imleci bırak  F12: ekran görüntüsü"
	hint.visible = not touch_mode


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.25
		var mode := " (oto)" if Quality.auto else ""
		_fps.text = "%d FPS · %s%s" % [Engine.get_frames_per_second(), Quality.current().name, mode]
		_coins.set_amount(Profile.coins)
		if _player:
			_score.text = "Puan: %d" % _player.score
		var players := get_tree().get_nodes_in_group("player")
		var alive := players.filter(func(p: Node) -> bool: return p.alive).size()
		var fighting: bool = _manager != null and _manager.coming_kind() != ""
		_alive.text = "Hayatta: %d / %d" % [alive, players.size()] if fighting and players.size() > 1 else ""
	if _board.visible:
		_board_time -= delta
		if _board_time <= 0.0:
			_board.visible = false


func bind(manager: Node, player: Node) -> void:
	_manager = manager
	_player = player
	manager.status_changed.connect(func(text: String) -> void: _status.text = text)
	manager.timer_changed.connect(func(seconds: int) -> void: _timer.text = str(seconds))
	manager.round_started.connect(func() -> void: _board.visible = false)
	player.health_changed.connect(_set_health)
	player.died.connect(func() -> void:
		_center.text = "Öldün! Sonraki turu bekle"
		_center.visible = true)
	player.respawned.connect(func() -> void: _center.visible = false)
	player.spectating.connect(func(bot_name: String) -> void:
		_center.text = "Öldün! İzliyorsun: %s" % bot_name if bot_name != "" else "Öldün! Sonraki turu bekle")


## The ranking after a disaster: total score, this round's points, and the coins
## the player just earned.
func show_board(board: Array, coins_earned: int) -> void:
	for child in _board_rows.get_children():
		child.queue_free()
	var rank := 0
	for p: Node in board:
		rank += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var mine: bool = not p.is_bot
		var color := Ui.ACCENT if mine else Color.WHITE
		var place := Ui.text("%d." % rank, 22, color)
		place.custom_minimum_size.x = 36
		row.add_child(place)
		var dot := ColorRect.new()
		dot.color = p.tint
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var name_label := Ui.text(p.display_name if p.alive else "%s (öldü)" % p.display_name, 22, color if p.alive else Color(1, 0.55, 0.5))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var gained := Ui.text("+%d" % p.round_points if p.round_points > 0 else "0", 22,
				Color(0.5, 1.0, 0.55) if p.round_points > 0 else Color(1, 1, 1, 0.5))
		gained.custom_minimum_size.x = 80
		gained.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(gained)
		var total := Ui.text(str(p.score), 22, color)
		total.custom_minimum_size.x = 90
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(total)
		_board_rows.add_child(row)
	if coins_earned > 0:
		var earned := Ui.CoinLabel.new(22)
		earned.set_amount(coins_earned)
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(Ui.text("Kazandın:  +", 22, Ui.COIN))
		line.add_child(earned)
		_board_rows.add_child(line)
	_board.visible = true
	_board_time = 7.5


func _build_board() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", Ui.panel_style(0.82))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(Ui.title("SKOR TABLOSU", 28))
	_board_rows = VBoxContainer.new()
	_board_rows.add_theme_constant_override("separation", 4)
	box.add_child(_board_rows)
	panel.visible = false
	return panel


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
