extends "res://scripts/disasters/disaster.gd"
## Meteors rain down over the map and blow holes in whatever they hit.

const ProjectilePool := preload("res://scripts/disasters/projectile_pool.gd")

const SPAWN_INTERVAL := 0.45
const SPAWN_HEIGHT := 90.0

var _pool: ProjectilePool
var _spawn_timer := 0.0


func _init() -> void:
	display_name = "Meteor Yağmuru"
	warning = "Sağlam bir yere saklan!"
	duration = 25.0
	mood = "dusk"


func begin() -> void:
	_pool = ProjectilePool.new()
	add_child(_pool)
	_pool.setup(16, 0.8, Color(0.3, 0.15, 0.1), Color(1.0, 0.45, 0.1))


func _physics_process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL
	var half: float = world.map_size * 0.5
	var pos := Vector3(randf_range(-half, half), SPAWN_HEIGHT, randf_range(-half, half))
	_pool.launch(pos, Vector3(randf_range(-8, 8), -45.0, randf_range(-8, 8)))
