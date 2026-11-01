extends "res://scripts/disasters/sky_hazard.gd"
## Hailstones hammer the island: out in the open you take hits (worse as it
## builds), stones bounce off the ground, and they knock loose light things on
## roofs and break skylights. Get under a roof.

const HITS_PER_TICK := 12


func _init() -> void:
	display_name = "Dolu"
	kind = "hail"
	warning = "Dolu geliyor! Bir çatının altına gir!"
	duration = 30.0
	mood = "hail"
	exposed_dps = 12.0


func begin() -> void:
	var stone := SphereMesh.new()
	stone.radius = 0.045
	stone.height = 0.09
	stone.radial_segments = 6
	stone.rings = 3
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.92, 0.95, 1.0)
	ice.roughness = 0.2
	stone.material = ice
	var amount: int = [220, 380, 560][Quality.level]
	var fall := curtain(stone, amount, 22.0, Vector3.DOWN, Vector3(22, 1, 22), 1.0)
	fall.position = Vector3(0, 20, 0)
	# Stones bouncing off whatever is below the camera.
	var bounce := curtain(stone, amount / 3, 2.2, Vector3.UP, Vector3(10, 0.1, 10), 0.45)
	bounce.spread = 50.0
	bounce.gravity = Vector3(0, -12, 0)
	bounce.position = Vector3(0, -1.6, 0)


func _hazard_frame(_delta: float) -> void:
	var k := intensity()
	get_tree().call_group("sound", "loop", "rain", 0.4 + k * 0.6, 1.6)
	get_tree().call_group("sound", "loop", "rumble", k * 0.15, 1.8)


func _hazard_tick(k: float) -> void:
	for i in int(HITS_PER_TICK * k):
		get_tree().call_group("structures", "damage_sphere", random_top(), 1.8, 4.0)
