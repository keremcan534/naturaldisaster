extends Node
## Round loop: new map + intermission -> warning -> disaster -> results.

signal status_changed(text: String)
signal timer_changed(seconds_left: int)

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
var results_time := 6.0
## Debug: values below 1 shorten every timer (see debug_tools.gd).
var time_scale := 1.0
## Debug: >= 0 always picks this disaster.
var forced_disaster := -1
var world: Node3D

var _state := State.INTERMISSION
var _time_left := 0.0
var _current: Node
var _last_index := -1


func start() -> void:
	_enter(State.INTERMISSION)


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
			world.load_next_map()
			get_tree().call_group("player", "respawn", world.spawn_point)
			_time_left = intermission_time * time_scale
			status_changed.emit("Harita: %s - sonraki felakete hazırlan" % world.map_name)
		State.WARNING:
			_current = _pick_disaster()
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
