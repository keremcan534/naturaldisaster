extends "res://scripts/disasters/disaster.gd"
## A cloud of toxic gas, heavier than air, spreads over the island and slowly
## thickens up to the first floor. Anyone whose head is in it chokes; climb
## above it and wait for it to sink away.

const Look := preload("res://scripts/world/look.gd")
const GAS_SHADER := preload("res://shaders/gas.gdshader")

const TOP := 5.5
const RISE_PART := 0.45
const SINK_FROM := 0.82
const DPS := 7.0
const TICK := 0.25

var _top := 0.0
var _elapsed := 0.0
var _tick := 0.0
var _cloud: MeshInstance3D
var _mat: ShaderMaterial


func _init() -> void:
	display_name = "Zehirli Gaz"
	kind = "gas"
	warning = "Zehirli gaz yayılıyor! Yere çöküyor: yükseğe, üst katlara çık!"
	duration = 36.0
	mood = "gas"
	safe_height = TOP + 1.5


func begin() -> void:
	var size: float = world.map_size + 30.0
	var box := BoxMesh.new()
	box.size = Vector3(size, 1.0, size)
	_mat = ShaderMaterial.new()
	_mat.shader = GAS_SHADER
	_mat.set_shader_parameter("noise", Look.noise_texture())
	box.material = _mat
	_cloud = MeshInstance3D.new()
	_cloud.mesh = box
	_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud.visible = false
	add_child(_cloud)


func _process(_delta: float) -> void:
	_cloud.visible = _top > 0.05
	_cloud.scale.y = maxf(_top, 0.01)
	_cloud.position.y = _top * 0.5 - 0.05
	_mat.set_shader_parameter("top", _top)
	get_tree().call_group("sound", "loop", "wind", 0.2 if _top > 0.1 else 0.0, 0.55)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var p := _elapsed / duration
	_top = TOP * power * smoothstep(0.0, RISE_PART, p) * (1.0 - smoothstep(SINK_FROM, 1.0, p))
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for player: Node3D in get_tree().get_nodes_in_group("player"):
		if player.alive and player.global_position.y + 1.5 < _top:
			player.take_damage(DPS * TICK)
			player.rumble(player.global_position, 40.0)
