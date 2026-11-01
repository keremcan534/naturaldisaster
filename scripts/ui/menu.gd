extends CanvasLayer
## Main menu, shop, settings and the in-game pause menu. Behind the main menu the
## island stays alive: the camera stands near the spawn point, the bots wander
## around, and the player's own character (in its shop outfit) waits in front.
## The game never pauses (rounds go on while the pause menu is open), like an
## online game.

signal play_pressed
signal resume_pressed
signal main_menu_pressed
signal tutorial_closed

const Profile := preload("res://scripts/core/profile.gd")
const Progress := preload("res://scripts/core/progress.gd")
const BuildInfo := preload("res://scripts/core/build_info.gd")
const Avatar := preload("res://scripts/player/avatar.gd")
const Ui := preload("res://scripts/ui/ui.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

## Set before adding: the world (3D nodes go there) and the touch controls (or null).
var world: Node3D
var controls: Node

var _main: Control
var _shop: Control
var _pause: Control
var _settings: SettingsPanel
var _settings_back: Control
var _coins: Ui.CoinLabel
var _stats: Label
var _gift: Button
var _shop_list: VBoxContainer
var _shop_coins: Ui.CoinLabel
var _level: Label
var _level_bar: ProgressBar
var _goals: Control
var _goals_list: VBoxContainer
var _tutorial: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _tutorial_next: Button
var _tutorial_pages: Array = []
var _tutorial_page := 0
var _camera: Camera3D
var _preview: Avatar
var _spawn := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	layer = 20
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 800.0
	world.add_child(_camera)
	_preview = Avatar.new()
	world.add_child(_preview)

	_main = _build_main()
	add_child(_main)
	_shop = _build_shop()
	add_child(_shop)
	_pause = _build_pause()
	add_child(_pause)
	_goals = _build_goals()
	add_child(_goals)
	_tutorial = _build_tutorial()
	add_child(_tutorial)
	_settings = SettingsPanel.new()
	_settings.controls = controls
	_settings.closed.connect(func() -> void: _open(_settings_back))
	add_child(_settings)
	hide_all()


## The main menu over the island, looking past the player's character.
func show_main(spawn: Vector3) -> void:
	_spawn = spawn
	_camera.make_current()
	_preview.visible = true
	_preview.set_colors(Profile.skin_color(), Avatar.PANTS[0], Avatar.SKIN_TONES[0])
	_preview.set_hat(Profile.has("helmet"))
	_open(_main)


func show_pause() -> void:
	_open(_pause)


func hide_all() -> void:
	_open(null)
	_preview.visible = false


func is_open() -> bool:
	return _main.visible or _shop.visible or _pause.visible or _settings.visible or _goals.visible or _tutorial.visible


func _open(screen: Control) -> void:
	for s: Control in [_main, _shop, _pause, _settings, _goals, _tutorial]:
		s.visible = s == screen
	if screen == _main:
		_refresh_main()
	elif screen == _shop:
		_refresh_shop()
	elif screen == _goals:
		_refresh_goals()


func _process(delta: float) -> void:
	if not _preview.visible:
		return
	_time += delta
	# A slow sway of the camera, and the character idling (a cheer now and then).
	var sway := sin(_time * 0.25) * 0.25
	_camera.global_position = _spawn + Vector3(0.4 + sway, 1.55, 2.7)
	_camera.look_at(_spawn + Vector3(0.2 + sway * 0.5, 1.2, -8.0))
	_preview.global_position = _spawn + Vector3(-1.25, 0.0, -0.6)
	_preview.rotation.y = PI + 0.45 + sin(_time * 0.6) * 0.12
	_preview.animate(delta, 0.0, 1.0 if fmod(_time, 7.0) > 5.6 else 0.0)


func _build_main() -> Control:
	var root := _screen()
	var heading := VBoxContainer.new()
	heading.position = Vector2(40, 26)
	heading.add_child(Ui.text("DOĞAL AFET", 68, Ui.ACCENT))
	heading.add_child(Ui.text("Felaketlerden sağ çık, puanları topla!", 22))
	_level = Ui.text("", 20, Color(0.8, 0.95, 1.0))
	heading.add_child(_level)
	_level_bar = _xp_bar(300)
	heading.add_child(_level_bar)
	root.add_child(heading)

	_coins = Ui.CoinLabel.new(32)
	_coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_coins.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_coins.offset_right = -36
	_coins.offset_top = 30
	root.add_child(_coins)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.offset_right = -40
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", 14)
	var play := Ui.button("OYNA", 40, true)
	play.pressed.connect(func() -> void: play_pressed.emit())
	column.add_child(play)
	var goals := Ui.button("GÖREVLER", 26)
	goals.pressed.connect(func() -> void: _open(_goals))
	column.add_child(goals)
	var shop := Ui.button("MAĞAZA", 26)
	shop.pressed.connect(func() -> void: _open(_shop))
	column.add_child(shop)
	var settings := Ui.button("AYARLAR", 26)
	settings.pressed.connect(func() -> void:
		_settings_back = _main
		_open(_settings))
	column.add_child(settings)
	_gift = Ui.button("", 22)
	_gift.pressed.connect(func() -> void:
		Profile.claim_gift()
		_refresh_main())
	column.add_child(_gift)
	root.add_child(column)

	_stats = Ui.text("", 18, Color(1, 1, 1, 0.85))
	_stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stats.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stats.offset_left = 40
	_stats.offset_bottom = -26
	root.add_child(_stats)

	var version := Ui.text("v " + BuildInfo.VERSION, 14, Color(1, 1, 1, 0.6))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -20
	version.offset_bottom = -12
	root.add_child(version)
	return root


func _refresh_main() -> void:
	_coins.set_amount(Profile.coins)
	_gift.visible = Profile.gift_ready()
	_gift.text = "GÜNLÜK HEDİYE: +%d" % Profile.DAILY_GIFT
	_stats.text = "En yüksek puan: %d     Hayatta kalınan tur: %d / %d" % [
			Profile.best_score, Profile.rounds_survived, Profile.rounds_played]
	var progress := Progress.level_progress()
	_level.text = "Seviye %d   ·   %d / %d XP" % [Progress.level(), progress.x, progress.y]
	_level_bar.max_value = progress.y
	_level_bar.value = progress.x


## A thin bar for experience and mission progress.
func _xp_bar(width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 10)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.8, 1.0)
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Level, today's three missions and every achievement.
func _build_goals() -> Control:
	var root := _screen(0.55)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 30
	panel.offset_bottom = -30
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	var back := Ui.button("GERİ", 22)
	back.custom_minimum_size.x = 140
	back.pressed.connect(func() -> void: _open(_main))
	top.add_child(back)
	var title := Ui.title("GÖREVLER", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 140
	top.add_child(spacer)
	box.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_goals_list = VBoxContainer.new()
	_goals_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goals_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_goals_list)
	return root


func _refresh_goals() -> void:
	for child in _goals_list.get_children():
		child.queue_free()
	var progress := Progress.level_progress()
	_goals_list.add_child(Ui.text("Seviye %d   ·   %d / %d XP" % [Progress.level(), progress.x, progress.y], 24, Color(0.8, 0.95, 1.0)))
	var bar := _xp_bar(0)
	bar.max_value = progress.y
	bar.value = progress.x
	_goals_list.add_child(bar)
	_goals_list.add_child(Ui.text("Günlük görevler (her gün yenilenir)", 22, Ui.ACCENT))
	for id: String in Progress.daily:
		var m := Progress.mission(id)
		if m.is_empty():
			continue
		var done: bool = id in Progress.missions_done
		var value: int = mini(Progress.mission_progress.get(id, 0), m.goal)
		_goals_list.add_child(_goal_row(m.text, "TAMAM" if done else "%d / %d" % [value, m.goal], m.reward, done, float(value) / m.goal))
	_goals_list.add_child(Ui.text("Başarımlar", 22, Ui.ACCENT))
	for a: Dictionary in Progress.ACHIEVEMENTS:
		var got: bool = a.id in Progress.unlocked
		var value: int = mini(Progress.counters.get(a.id, 0), a.goal)
		_goals_list.add_child(_goal_row("%s — %s" % [a.name, a.text], "AÇILDI" if got else "%d / %d" % [value, a.goal], a.reward, got, float(value) / a.goal))


func _goal_row(text: String, state: String, reward: int, done: bool, fraction: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Ui.text(text, 20, Color(0.6, 1.0, 0.6) if done else Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(label)
	var bar := _xp_bar(0)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = 1.0 if done else fraction
	info.add_child(bar)
	row.add_child(info)
	var status := Ui.text(state, 20, Color(0.6, 1.0, 0.6) if done else Color(1, 1, 1, 0.8))
	status.custom_minimum_size.x = 110
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status)
	var coins := Ui.CoinLabel.new(20)
	coins.set_amount(reward)
	coins.custom_minimum_size.x = 90
	row.add_child(coins)
	return row


## First play: a few cards on how the game works.
func show_tutorial(touch: bool) -> void:
	var controls_text := "Sol başparmak: hareket. Tam ileri itersen koşarsın; yukarıdaki kilide çekip bırakırsan otomatik koşarsın.\nSağ başparmak: ekranı kaydırarak etrafa bak, büyük tuşla zıpla.\nMerdivenlere doğru yürüyerek tırman." if touch \
			else "WASD ile yürü, Shift ile koş, Space ile zıpla, fareyle bak.\nMerdivenlere doğru yürüyerek tırman. Esc menüyü açar."
	_tutorial_pages = [
		["Hoş geldin!", "Her turda adaya bir felaket gelir. Uyarı kartı çıkınca ne yapman gerektiği yazar: oku ve hemen harekete geç!"],
		["Nasıl hayatta kalırsın?", "Tsunami ve sel: yükseğe, çatıya çık.\nDeprem ve yangın: binalardan uzak, açık alana.\nDolu, yıldırım, asit, kum: kapalı bir yere gir.\nHortum ve volkan: uzaklaş. Kırmızı ok tehlikeyi gösterir."],
		["Kontroller", controls_text],
		["Ödüller", "Hayatta kaldıkça puan, coin ve XP kazanırsın. Günlük görevleri ve başarımları tamamla, mağazadan güçlendirme ve kıyafet al.\nTakım arkadaşların da hayatta kalmaya çalışıyor: hepiniz kurtulursanız bonus var!"],
	]
	_tutorial_page = 0
	_show_tutorial_page()
	_open(_tutorial)


func _show_tutorial_page() -> void:
	var page: Array = _tutorial_pages[_tutorial_page]
	_tutorial_title.text = page[0]
	_tutorial_body.text = page[1]
	_tutorial_next.text = "BAŞLA!" if _tutorial_page == _tutorial_pages.size() - 1 else "SONRAKİ"


func _build_tutorial() -> Control:
	var root := _screen(0.5)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	_tutorial_title = Ui.title("", 36)
	box.add_child(_tutorial_title)
	_tutorial_body = Ui.text("", 22)
	_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body.custom_minimum_size = Vector2(660, 0)
	box.add_child(_tutorial_body)
	_tutorial_next = Ui.button("SONRAKİ", 28, true)
	_tutorial_next.pressed.connect(func() -> void:
		_tutorial_page += 1
		if _tutorial_page >= _tutorial_pages.size():
			hide_all()
			tutorial_closed.emit()
		else:
			_show_tutorial_page())
	box.add_child(_tutorial_next)
	return root


func _build_shop() -> Control:
	var root := _screen(0.55)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 30
	panel.offset_bottom = -30
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	var back := Ui.button("GERİ", 22)
	back.custom_minimum_size.x = 140
	back.pressed.connect(func() -> void: _open(_main))
	top.add_child(back)
	var title := Ui.title("MAĞAZA", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_shop_coins = Ui.CoinLabel.new(28)
	_shop_coins.custom_minimum_size.x = 140
	top.add_child(_shop_coins)
	box.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_shop_list)
	return root


func _refresh_shop() -> void:
	_shop_coins.set_amount(Profile.coins)
	for child in _shop_list.get_children():
		child.queue_free()
	_shop_list.add_child(Ui.text("Güçlendirmeler (alınca hep açık)", 22, Ui.ACCENT))
	for entry: Dictionary in Profile.ITEMS:
		if entry.kind == "perk":
			_shop_list.add_child(_shop_row(entry))
	_shop_list.add_child(Ui.text("Kıyafetler", 22, Ui.ACCENT))
	for entry: Dictionary in Profile.ITEMS:
		if entry.kind == "skin":
			_shop_list.add_child(_shop_row(entry))


func _shop_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if entry.kind == "skin":
		var swatch := ColorRect.new()
		swatch.color = entry.color
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Ui.text(entry.name, 24))
	if entry.has("desc"):
		var desc := Ui.text(entry.desc, 17, Color(1, 1, 1, 0.75))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
	row.add_child(info)

	var action := Ui.button("", 20)
	action.custom_minimum_size = Vector2(220, 52)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var owned := Profile.has(entry.id)
	if entry.kind == "skin" and owned:
		var wearing: bool = Profile.skin == entry.id
		action.text = "GİYİLDİ" if wearing else "GİY"
		action.disabled = wearing
		action.pressed.connect(func() -> void:
			Profile.skin = entry.id
			Profile.save_profile()
			_preview.set_colors(Profile.skin_color(), Avatar.PANTS[0], Avatar.SKIN_TONES[0])
			_refresh_shop())
	elif owned:
		action.text = "ALINDI"
		action.disabled = true
	else:
		action.text = "SATIN AL  %d" % entry.price
		action.disabled = Profile.coins < entry.price
		action.pressed.connect(func() -> void:
			if Profile.buy(entry.id):
				_preview.set_colors(Profile.skin_color(), Avatar.PANTS[0], Avatar.SKIN_TONES[0])
				_preview.set_hat(Profile.has("helmet"))
			_refresh_shop())
	row.add_child(action)
	return row


func _build_pause() -> Control:
	var root := _screen(0.45)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(Ui.title("MENÜ", 32))
	var note := Ui.text("Oyun arkada devam ediyor", 16, Color(1, 1, 1, 0.7))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var resume := Ui.button("DEVAM", 30, true)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)
	var settings := Ui.button("AYARLAR", 24)
	settings.pressed.connect(func() -> void:
		_settings_back = _pause
		_open(_settings))
	box.add_child(settings)
	var quit := Ui.button("ANA MENÜ", 24)
	quit.pressed.connect(func() -> void: main_menu_pressed.emit())
	box.add_child(quit)
	return root


## A full-screen layer that takes every touch (nothing reaches the game behind),
## with an optional dark tint.
func _screen(shade := 0.0) -> Control:
	var root := ColorRect.new()
	root.color = Color(0, 0, 0, shade)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root
