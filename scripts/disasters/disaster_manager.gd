extends Node
## Round loop: new map + intermission -> warning -> disaster -> results.

signal status_changed(text: String)
signal timer_changed(seconds_left: int)
## After each disaster: every player and bot, best total score first.
signal round_scored(board: Array)
signal round_started
## A disaster was announced: its name and what to do.
signal disaster_warned(title: String, hint: String)

## Round points: surviving, plus half the health left, plus a bonus for every
## round survived in a row before this one, plus a team bonus for every other
## survivor (teammates are worth keeping alive).
const SURVIVE_POINTS := 100
const STREAK_POINTS := 25
const TEAM_POINTS := 10

const DISASTERS := [
	preload("res://scripts/disasters/earthquake.gd"),
	preload("res://scripts/disasters/meteor_shower.gd"),
	preload("res://scripts/disasters/tsunami.gd"),
	preload("res://scripts/disasters/tornado.gd"),
	preload("res://scripts/disasters/volcano.gd"),
	preload("res://scripts/disasters/mega_tsunami.gd"),
	preload("res://scripts/disasters/fire.gd"),
	preload("res://scripts/disasters/lightning_storm.gd"),
	preload("res://scripts/disasters/hail.gd"),
	preload("res://scripts/disasters/sandstorm.gd"),
	preload("res://scripts/disasters/flood.gd"),
	preload("res://scripts/disasters/acid_rain.gd"),
	preload("res://scripts/disasters/hurricane.gd"),
	preload("res://scripts/disasters/sinkhole.gd"),
	preload("res://scripts/disasters/heatwave.gd"),
	preload("res://scripts/disasters/gas.gd"),
	preload("res://scripts/disasters/big_meteor.gd"),
	preload("res://scripts/disasters/solar_flare.gd"),
	preload("res://scripts/disasters/wave_series.gd"),
	preload("res://scripts/disasters/ashfall.gd"),
]
## No easy rounds: every disaster is at least severe.
const SEVERITY_NAMES := ["Şiddetli", "Felaket", "Kıyamet"]
const SEVERITY_POWER := [1.15, 1.4, 1.7]
## Double disasters: after the first round of a session, sometimes a second one
## from this list joins the main one (never two floods, never the same kind).
const COMBO_CHANCE := 0.35
const COMBO_PARTNERS := [0, 6, 7, 8, 3]
const WATER_KINDS := ["tsunami"]

enum State { INTERMISSION, WARNING, ACTIVE, RESULTS }

var intermission_time := 15.0
var warning_time := 5.0
var results_time := 8.0
## Debug: values below 1 shorten every timer (see debug_tools.gd).
var time_scale := 1.0
## Debug: >= 0 always picks this disaster.
var forced_disaster := -1
var world: Node3D

var _state := State.INTERMISSION
var _time_left := 0.0
var _current: Node
## The second disaster of a double, or null.
var _extra: Node
var _last_index := -1
var _rounds := 0
## What the last finished round was, for missions: {kinds, mega, double}.
var last_round := {}
## The first round of a session plays on the map already loaded (the menu's).
var _keep_map := false


func _ready() -> void:
	set_process(false)


## Starts a session: scores back to zero, rounds begin.
func start(keep_map := false) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		p.score = 0
		p.streak = 0
		p.round_points = 0
	_keep_map = keep_map
	_rounds = 0
	set_process(true)
	_enter(State.INTERMISSION)


## Ends the session (back to the menu): the disaster stops where it is.
func stop() -> void:
	set_process(false)
	for d: Node in [_current, _extra]:
		if d:
			if d.is_inside_tree():
				d.end()
			d.queue_free()
	_current = null
	_extra = null
	_state = State.INTERMISSION
	get_tree().call_group("weather", "drain_sea", 0.0)


func running() -> bool:
	return is_processing()


## The disaster announced or under way (bots read it), or "" between them.
func coming_kind() -> String:
	if _current and (_state == State.WARNING or _state == State.ACTIVE):
		return _current.kind
	return ""


## The nearest danger to `from` and the disaster's name, for the HUD's arrow
## ([Vector3.INF, ""] when there is nothing to point at).
func danger_for(from: Vector3) -> Array:
	if _current and _state == State.ACTIVE:
		for d: Node in [_current, _extra]:
			if d:
				var at: Vector3 = d.danger_point(from)
				if at != Vector3.INF:
					return [at, d.display_name]
	return [Vector3.INF, ""]


## For floods: how high bots should climb (0 otherwise).
func safe_height() -> float:
	if _current and (_state == State.WARNING or _state == State.ACTIVE):
		return _current.safe_height
	return 0.0


func danger_center() -> Vector3:
	if _current and _state == State.ACTIVE:
		return _current.danger_center()
	return Vector3.INF


func _process(delta: float) -> void:
	_time_left -= delta
	timer_changed.emit(ceili(maxf(_time_left, 0.0)))
	if _time_left > 0.0:
		return
	match _state:
		State.INTERMISSION:
			_enter(State.WARNING)
		State.WARNING:
			_enter(State.ACTIVE)
		State.ACTIVE:
			_enter(State.RESULTS)
		State.RESULTS:
			_enter(State.INTERMISSION)


func _enter(state: State) -> void:
	_state = state
	match state:
		State.INTERMISSION:
			if not _keep_map:
				world.load_next_map()
			_keep_map = false
			world.set_mood("clear")
			get_tree().call_group("player", "respawn", world.spawn_point)
			_time_left = intermission_time * time_scale
			round_started.emit()
			status_changed.emit("Harita: %s - sonraki felakete hazırlan" % world.map_name)
		State.WARNING:
			_current = _pick_disaster()
			_extra = _pick_partner() if _rounds > 0 and randf() < COMBO_CHANCE else null
			_rounds += 1
			world.set_mood(_current.mood)
			_omens(true)
			_time_left = maxf(warning_time, _current.warning_time) * time_scale
			# The HUD's card shows what to do; the status line stays short.
			if _extra:
				status_changed.emit("UYARI: ÇİFTE FELAKET! %s + %s" % [_current.display_name, _extra.display_name])
				disaster_warned.emit("%s + %s" % [_current.display_name, _extra.display_name], "Çifte felaket! " + _current.warning)
			else:
				status_changed.emit("UYARI: %s geliyor!" % _current.display_name)
				disaster_warned.emit("%s · %s" % [_current.display_name, SEVERITY_NAMES[_current.severity - 1]], _current.warning)
		State.ACTIVE:
			_omens(false)
			_current.duration *= time_scale
			_time_left = _current.duration
			add_child(_current)
			_current.begin()
			var title: String = _current.display_name.to_upper()
			if _extra:
				_extra.duration = minf(_extra.duration * time_scale, _current.duration)
				add_child(_extra)
				_extra.begin()
				title += " + " + _extra.display_name.to_upper()
			status_changed.emit(title)
		State.RESULTS:
			last_round = {"kinds": [], "double": _extra != null,
					"mega": _current.get_script().resource_path.ends_with("mega_tsunami.gd")}
			for d: Node in [_current, _extra]:
				if d:
					last_round.kinds.append(d.kind)
					d.end()
					d.queue_free()
			_current = null
			_extra = null
			_time_left = results_time * time_scale
			status_changed.emit(_results_text())
			round_scored.emit(_score_round())


func _pick_disaster() -> Node:
	var index := randi() % DISASTERS.size()
	if index == _last_index:
		index = (index + 1) % DISASTERS.size()
	if forced_disaster >= 0:
		index = forced_disaster
	_last_index = index
	var disaster: Node = DISASTERS[index].new()
	disaster.world = world
	# Mild ones get rarer and catastrophic ones commoner as the session goes on.
	var roll := randf()
	var high := minf(0.12 + 0.05 * _rounds, 0.45)
	var low := maxf(0.5 - 0.06 * _rounds, 0.15)
	disaster.severity = 3 if roll < high else (1 if roll > 1.0 - low else 2)
	disaster.power = SEVERITY_POWER[disaster.severity - 1]
	return disaster


func _results_text() -> String:
	var players := get_tree().get_nodes_in_group("player")
	var alive := players.filter(func(p: Node) -> bool: return p.alive).size()
	if players.size() == 1:
		return "Hayatta kaldın!" if alive == 1 else "Öldün!"
	return "Hayatta kalanlar: %d / %d" % [alive, players.size()]


## Signs before it hits: the sea draws back before a tsunami (and returns with
## the wave), the gulls flee before a quake or an eruption.
func _omens(warning: bool) -> void:
	var tsunami: bool = _current.kind == "tsunami" and _current.safe_height > 5.0
	if tsunami:
		get_tree().call_group("weather", "drain_sea", 3.5 if warning else 0.0)
	if warning and _current.kind in ["earthquake", "volcano"]:
		get_tree().call_group("ambience", "scatter")
	if warning and _current.kind == "earthquake":
		get_tree().call_group("ambience", "barks")
	if _current.kind == "volcano":
		get_tree().call_group("ambience", "volcano_smoke", Vector3(0, 0, -world.map_size * 0.5 - 6.0), warning)


## A second disaster to go with the current one: a different kind, and never
## water on water.
func _pick_partner() -> Node:
	var options: Array = []
	for index: int in COMBO_PARTNERS:
		if index == _last_index or index >= DISASTERS.size():
			continue
		options.append(index)
	options.shuffle()
	for index: int in options:
		var partner: Node = DISASTERS[index].new()
		if partner.kind == _current.kind or (partner.kind in WATER_KINDS and _current.kind in WATER_KINDS):
			partner.free()
			continue
		partner.world = world
		return partner
	return null


func _score_round() -> Array:
	var players := get_tree().get_nodes_in_group("player")
	var survivors := players.filter(func(p: Node) -> bool: return p.alive).size()
	for p in players:
		var points := 0
		if p.alive:
			points = SURVIVE_POINTS + int(p.health * 0.5) + STREAK_POINTS * p.streak + TEAM_POINTS * (survivors - 1)
			p.streak += 1
		else:
			p.streak = 0
		p.round_points = points
		p.score += points
	players.sort_custom(func(a: Node, b: Node) -> bool: return a.score > b.score)
	return players
