class_name Boss
extends Enemy
## Base for bosses: hand-tuned health, phases that start at health thresholds, a moment of
## invulnerability when a phase changes, and a `defeated` signal for the level.

signal defeated(boss: Boss)

## Health fractions at which phase 2, 3, ... begin.
var phase_thresholds: Array[float] = [0.66, 0.33]
var phase := 1
var _invulnerable_t := 0.0


func _init() -> void:
	scales_with_depth = false
	spawn_delay = 0.0
	body_radius = 9.0
	knock_resist = 0.0


func is_boss() -> bool:
	return true


func title() -> String:
	return "%s · %s" % [Bestiary.display_name(kind), Bestiary.boss_title(kind)]


func health_ratio() -> float:
	return hp / max_hp


## The arena in world coordinates; jumps, drifting and summons stay inside it.
func arena() -> Rect2:
	return (world as Level).boss_arena()


func summon(enemy_kind: String, pos: Vector2, depth: int) -> void:
	(world as Level).spawn_enemy_telegraphed(enemy_kind, pos, depth)


func _physics_process(delta: float) -> void:
	_invulnerable_t -= delta
	super(delta)


func take_damage(amount: float, _dir := Vector2.ZERO, crit := false, burn := false) -> void:
	if _invulnerable_t > 0.0 or _untouchable():
		return
	super(amount, Vector2.ZERO, crit, burn)   # bosses are never knocked back
	if dead:
		return
	if phase <= phase_thresholds.size() and health_ratio() < phase_thresholds[phase - 1]:
		phase += 1
		_on_phase(phase)


## Start the invulnerable beat that comes with a phase change, clearing bullets around the boss.
func stagger(invulnerable_for: float, clear_radius: float) -> void:
	_invulnerable_t = invulnerable_for
	Sound.play("boss_roar")
	world.clear_enemy_bullets(global_position, clear_radius)


func _on_death() -> void:
	defeated.emit(self)


# ---- for subclasses
## Called once when a new phase begins.
func _on_phase(_new_phase: int) -> void:
	pass


## Moments when hits pass through (e.g. while in the air).
func _untouchable() -> bool:
	return false
