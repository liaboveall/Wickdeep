extends Enemy
## Shadeling: fast, fragile chaser summoned by the Snuffer.


func _configure() -> void:
	sheet = "shade"
	max_hp = 10.0
	speed = 92.0
	accel = 520.0
	hit_radius = 5.0
	hit_offset = Vector2(0, -5)
	sprite_offset = Vector2(0, -6)
	shadow_width = 8
	embers = Vector2i(0, 1)


func _build() -> void:
	var glow := Lights.make(Color(0.6, 0.4, 0.9), 20.0, 0.5)
	glow.position = Vector2(0, -6)
	add_child(glow)


func _ai(delta: float) -> void:
	steer_to(player().global_position, speed, delta)
