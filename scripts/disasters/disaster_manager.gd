extends Node
## Round loop: new map + intermission -> warning -> disaster -> results.

signal status_changed(text: String)
signal timer_changed(seconds_left: int)
## After each disaster: every player and bot, best total score first.
signal round_scored(board: Array)
signal round_started

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
]

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
var _last_index := -1
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
	set_process(true)
	_enter(State.INTERMISSION)


## Ends the session (back to the menu): the disaster stops where it is.
func stop() -> void:
	set_process(false)
	if _current:
		if _current.is_inside_tree():
			_current.end()
		_current.queue_free()
		_current = null
	_state = State.INTERMISSION


func running() -> bool:
	return is_processing()


## The disaster announced or under way (bots read it), or "" between them.
func coming_kind() -> String:
	if _current and (_state == State.WARNING or _state == State.ACTIVE):
		return _current.kind
	return ""


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
			world.set_mood(_current.mood)
			_time_left = warning_time * time_scale
			status_changed.emit("UYARI: %s geliyor! %s" % [_current.display_name, _current.warning])
		State.ACTIVE:
			_current.duration *= time_scale
			_time_left = _current.duration
			add_child(_current)
			_current.begin()
			status_changed.emit(_current.display_name.to_upper())
		State.RESULTS:
			_current.end()
			_current.queue_free()
			_current = null
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
	return disaster


func _results_text() -> String:
	var players := get_tree().get_nodes_in_group("player")
	var alive := players.filter(func(p: Node) -> bool: return p.alive).size()
	if players.size() == 1:
		return "Hayatta kaldın!" if alive == 1 else "Öldün!"
	return "Hayatta kalanlar: %d / %d" % [alive, players.size()]


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
