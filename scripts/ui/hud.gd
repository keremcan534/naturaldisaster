extends CanvasLayer
## Round status, countdown, health bar, death message, score and coins, how many
## are still alive, and the scoreboard after every disaster.

const BuildInfo := preload("res://scripts/core/build_info.gd")
const Quality := preload("res://scripts/core/quality.gd")
const Profile := preload("res://scripts/core/profile.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Structure := preload("res://scripts/world/structure.gd")
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
var _perf: Label
## Longest frame (ms) since the last readout, and their average.
var _worst := 0.0
var _frame_sum := 0.0
var _frames := 0
var _alive: Label
var _score: Label
var _coins: Ui.CoinLabel
var _board: PanelContainer
var _board_rows: VBoxContainer
var _board_time := 0.0
var _manager: Node
var _player: Node
## A big card announcing the coming disaster, the list of who fell, and a red
## flash when the player gets hurt (a slow pulse while health is low).
var _card: PanelContainer
var _card_title: Label
var _card_hint: Label
var _feed: VBoxContainer
var _hurt: TextureRect
var _hurt_amount := 0.0
var _last_health := 100.0
var _low_health := false
var _time := 0.0
## Mission / level / achievement notes, shown one after another.
var _toast: PanelContainer
var _toast_text: Label
var _toast_coins: Ui.CoinLabel
var _toast_queue: Array = []
var _toast_time := 0.0
## An arrow at the edge of a circle around the crosshair, pointing at the danger.
var _danger: Control
var _danger_label: Label
var _danger_angle := 0.0
## Map vote under the scoreboard (buttons, or the number keys on desktop).
var _vote: PanelContainer
var _vote_buttons: Array[Button] = []
var _items: Label


func _ready() -> void:
	add_to_group("hud")
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

	_perf = _label(13)
	_perf.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_perf.offset_left = 22
	_perf.offset_top = 150
	_perf.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_perf.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))

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

	_hurt = TextureRect.new()
	_hurt.texture = shade
	_hurt.stretch_mode = TextureRect.STRETCH_SCALE
	_hurt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.modulate = Color(1.0, 0.1, 0.05, 0.0)
	add_child(_hurt)
	move_child(_hurt, 1)

	_card = _build_card()
	add_child(_card)
	_toast = _build_toast()
	add_child(_toast)
	_danger = Control.new()
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.draw.connect(_draw_danger)
	add_child(_danger)
	_danger_label = Ui.text("", 18, Color(1.0, 0.75, 0.3))
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.custom_minimum_size = Vector2(220, 0)
	_danger.add_child(_danger_label)
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.offset_right = -20
	_feed.offset_top = 84
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	var hint := _label(14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -16
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = "WASD: yürü  Shift: koş  Space: zıpla  C: çömel  F: takip et  G: selam  P: fotoğraf  Esc: menü"
	hint.visible = not touch_mode

	_vote = _build_vote()
	add_child(_vote)
	# Desktop: what the number keys hold this round.
	_items = _label(18)
	_items.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_items.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_items.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_items.offset_bottom = -44
	_items.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))


func _process(delta: float) -> void:
	_worst = maxf(_worst, delta * 1000.0)
	_frame_sum += delta * 1000.0
	_frames += 1
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.25
		_update_perf()
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
	_update_vote()
	_time += delta
	_update_toast(delta)
	_update_danger()
	_hurt_amount = move_toward(_hurt_amount, 0.0, delta * 0.8)
	var pulse := (0.18 + 0.12 * sin(_time * 5.0)) if _low_health else 0.0
	_hurt.modulate.a = maxf(_hurt_amount, pulse)


func bind(manager: Node, player: Node) -> void:
	_manager = manager
	_player = player
	manager.status_changed.connect(func(text: String) -> void: _status.text = text)
	manager.timer_changed.connect(func(seconds: int) -> void: _timer.text = str(seconds))
	manager.round_started.connect(func() -> void:
		_board.visible = false
		_close_vote()
		if not player.alive:
			_center.text = "Elendin! Son kalan belirlenince döneceksin"
			_center.visible = true)
	manager.vote_started.connect(_open_vote)
	player.helped.connect(func(bot_name: String) -> void:
		toast("%s ayağa kalktı! +25 puan" % bot_name, 0))
	player.rescued_now.connect(func() -> void:
		toast("KURTARILDIN! Bu tur artık hasar almazsın", 0))
	player.items_changed.connect(_show_items)
	manager.disaster_warned.connect(_show_card)
	player.health_changed.connect(_set_health)
	player.died.connect(func() -> void:
		_center.text = "Öldün! Sonraki turu bekle"
		_center.visible = true
		_add_feed(player.display_name, player.tint))
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
		get_tree().call_group("sound", "play", "coin")
		var earned := Ui.CoinLabel.new(22)
		earned.set_amount(coins_earned)
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(Ui.text("Kazandın:  +", 22, Ui.COIN))
		line.add_child(earned)
		_board_rows.add_child(line)
	_board.visible = true
	_board_time = 7.5
	_center.visible = false


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


## The optional performance readout (settings): enough to tell from a
## screenshot whether the phone is slowed by drawing, physics or scripts.
func _update_perf() -> void:
	_perf.visible = Settings.perf_overlay
	if not _perf.visible or _frames == 0:
		_worst = 0.0
		_frame_sum = 0.0
		_frames = 0
		return
	_perf.text = "kare: ort %.1f ms, en kötü %.1f ms\nscript %.1f ms, fizik %.1f ms\nçizim %d, üçgen %dk\nhareketli parça %d, yanan %d" % [
			_frame_sum / _frames, _worst,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			Structure.awake, Structure.fires]
	_worst = 0.0
	_frame_sum = 0.0
	_frames = 0


## Queues a note like "Görev tamam: ..." with the coins it gave.
func toast(text: String, coins: int) -> void:
	_toast_queue.append([text, coins])


func _update_toast(delta: float) -> void:
	_toast_time -= delta
	if _toast_time > 0.0:
		_toast.modulate.a = minf(1.0, minf(_toast_time, 2.6 - _toast_time) * 4.0)
		return
	_toast.visible = false
	if _toast_queue.is_empty():
		return
	var next: Array = _toast_queue.pop_front()
	_toast_text.text = next[0]
	_toast_coins.set_amount(next[1])
	_toast_coins.visible = next[1] > 0
	_toast.visible = true
	_toast_time = 2.6
	get_tree().call_group("sound", "play", "coin")


func _build_toast() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -40
	var style := Ui.panel_style(0.9)
	style.border_color = Ui.ACCENT
	style.set_border_width_all(3)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_toast_text = Ui.text("", 22, Ui.ACCENT)
	row.add_child(_toast_text)
	_toast_coins = Ui.CoinLabel.new(22)
	row.add_child(_toast_coins)
	panel.visible = false
	return panel


## Where the current danger is, relative to where the camera looks.
func _update_danger() -> void:
	var camera := get_viewport().get_camera_3d()
	var show := false
	if _manager and _player and _player.alive and camera:
		var found: Array = _manager.danger_for(_player.global_position)
		var at: Vector3 = found[0]
		if at != Vector3.INF:
			var local := camera.global_transform.affine_inverse() * at
			_danger_angle = atan2(local.x, -local.z)
			var dist := Vector2(at.x - _player.global_position.x, at.z - _player.global_position.z).length()
			_danger_label.text = "%s  %d m" % [found[1].to_upper(), int(dist)]
			show = dist > 2.0
	_danger.visible = show
	if show:
		var size := _danger.size
		var radius := size.y * 0.3
		var tip := size * 0.5 + Vector2(sin(_danger_angle), -cos(_danger_angle)) * (radius + 46.0)
		_danger_label.position = tip - Vector2(110, -6) + Vector2(sin(_danger_angle), -cos(_danger_angle)) * 22.0
		_danger.queue_redraw()


func _draw_danger() -> void:
	var size := _danger.size
	var radius := size.y * 0.3
	var dir := Vector2(sin(_danger_angle), -cos(_danger_angle))
	var side := Vector2(-dir.y, dir.x)
	var base := size * 0.5 + dir * radius
	var pulse := 0.75 + 0.25 * sin(_time * 8.0)
	var points := PackedVector2Array([base + dir * 34.0, base + side * 16.0, base - side * 16.0])
	_danger.draw_colored_polygon(points, Color(1.0, 0.35, 0.15, 0.85 * pulse))
	_danger.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.6), 2.0, true)


## Bots' deaths go into the feed too.
func watch_bots(bots: Array) -> void:
	for bot: Node in bots:
		bot.died.connect(func() -> void: _add_feed(bot.display_name, bot.tint))


## A line in the feed (rescues, team calls).
func add_note(text: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Ui.text(text, 18, Color(0.7, 0.95, 1.0)))
	_feed.add_child(row)
	if _feed.get_child_count() > 5:
		_feed.get_child(0).queue_free()
	var tween := row.create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(row, "modulate:a", 0.0, 0.8)
	tween.tween_callback(row.queue_free)


func _show_items(items: Dictionary) -> void:
	if touch_mode:
		_items.text = ""
		return
	var parts: Array = []
	var names := {"parachute": "1 Paraşüt", "bandage": "2 Sargı", "hook": "3 Kanca"}
	for id: String in ["parachute", "bandage", "hook"]:
		if items.get(id, 0) > 0:
			parts.append("%s ×%d" % [names[id], items[id]])
	_items.text = "   ".join(parts)


func _build_vote() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel", Ui.panel_style(0.75))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(Ui.title("SONRAKİ HARİTA: OY VER", 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for k in 3:
		var button := Ui.button("", 18)
		button.custom_minimum_size = Vector2(190, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: _cast_vote(k))
		row.add_child(button)
		_vote_buttons.append(button)
	panel.visible = false
	return panel


func _open_vote(options: Array) -> void:
	if _player == null or not _player.is_in_group("player"):
		return
	for k in _vote_buttons.size():
		_vote_buttons[k].visible = k < options.size()
	_vote.visible = true
	_player.voting = true
	_update_vote()


func _close_vote() -> void:
	_vote.visible = false
	if _player:
		_player.voting = false


func _cast_vote(k: int) -> void:
	if _manager and _vote.visible:
		_manager.vote(_player, k)
		get_tree().call_group("sound", "play", "click")


func _update_vote() -> void:
	if not _vote.visible:
		return
	if _manager.vote_options.is_empty():
		_close_vote()
		return
	for k: int in [0, 1, 2]:
		var action: String = ["item_parachute", "item_bandage", "item_hook"][k]
		if Input.is_action_just_pressed(action):
			_cast_vote(k)
	var counts: Array = _manager.vote_counts()
	var mine: int = _manager.votes.get(_player, -1)
	for k in _manager.vote_options.size():
		var key := "" if touch_mode else "%d) " % (k + 1)
		var option: Array = _manager.vote_options[k]
		_vote_buttons[k].text = "%s%s%s  · %d" % ["> " if k == mine else "", key, option[1], counts[k]]


func _add_feed(who: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Ui.text(who, 18, color.lightened(0.3)))
	row.add_child(Ui.text(" elendi", 18, Color(1, 1, 1, 0.85)))
	_feed.add_child(row)
	if _feed.get_child_count() > 5:
		_feed.get_child(0).queue_free()
	var tween := row.create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(row, "modulate:a", 0.0, 0.8)
	tween.tween_callback(row.queue_free)


func _show_card(title: String, hint: String) -> void:
	_card_title.text = title.to_upper()
	_card_hint.text = hint
	_card.visible = true
	_card.modulate.a = 0.0
	_card.scale = Vector2(1.15, 1.15)
	_card.pivot_offset = _card.size * 0.5
	var tween := _card.create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.2)
	tween.tween_property(_card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _card.visible = false)


func _build_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = 140
	card.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.06, 0.04, 0.88)
	style.border_color = Color(1.0, 0.8, 0.2)
	style.border_width_top = 5
	style.border_width_bottom = 5
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var tag := Ui.title("! UYARI !", 22)
	tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(tag)
	_card_title = Ui.title("", 52)
	_card_title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(_card_title)
	_card_hint = Ui.title("", 22)
	_card_hint.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_card_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_card_hint)
	card.visible = false
	return card


func _set_health(value: float, max_value: float) -> void:
	if value < _last_health:
		_hurt_amount = minf(_hurt_amount + (_last_health - value) / max_value * 2.0 + 0.15, 0.7)
		Input.vibrate_handheld(40)
	_last_health = value
	_low_health = value > 0.0 and value < max_value * 0.3
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
