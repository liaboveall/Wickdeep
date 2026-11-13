class_name Pickup
extends Node2D
## Embers (currency) and lamp oil (healing) dropped in the world. Magnetised towards the player.

enum Kind { EMBER, OIL }

const OIL_HEAL := 2
const SETTLE_TIME := 0.3        # a fresh drop scatters before it can be pulled in
const PULL_SPEED := 240.0
const COLLECT_DISTANCE := 7.0

var world: World
var kind := Kind.EMBER
var vel := Vector2.ZERO
var magnet := false             # pulled in from any distance (set when a room is cleared)
var _age := 0.0
var _bob := randf() * TAU
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = SpriteLib.make_sprite("ember" if kind == Kind.EMBER else "oil")
	_sprite.material = Fx.unshaded()
	_sprite.position = Vector2(0, -4)
	_sprite.frame = randi() % 4
	add_child(_sprite)
	if kind == Kind.OIL:
		add_child(Lights.make(Color(1.0, 0.8, 0.4), 26.0, 0.6))


func _physics_process(delta: float) -> void:
	_age += delta
	_bob += delta * 5.0
	_sprite.position.y = -4 + sin(_bob)
	var p := world.player
	if p and not p.dead:
		var to_player := p.global_position + Vector2(0, -4) - global_position
		var in_reach := magnet or to_player.length() < Run.stats.pickup_radius
		if _wanted() and _age > SETTLE_TIME and in_reach:
			vel = vel.move_toward(to_player.normalized() * PULL_SPEED, 1100.0 * delta)
			if to_player.length() < COLLECT_DISTANCE:
				_collect()
				return
		else:
			vel = vel.move_toward(Vector2.ZERO, 260.0 * delta)
	var next := position + vel * delta
	if world.grid.is_solid_at(next):
		vel = -vel * 0.4
	else:
		position = next


## Oil stays on the floor until the player can actually use it.
func _wanted() -> bool:
	return kind == Kind.EMBER or Run.is_hurt()


func _collect() -> void:
	if kind == Kind.EMBER:
		Run.add_embers(1)
		Sound.play("pickup", -6.0, 1.0 + randf() * 0.15)
	else:
		Run.heal(OIL_HEAL)
		Sound.play("heal")
		Fx.text(world.fx, global_position, "+%d" % OIL_HEAL, UiTheme.GOLD)
	Fx.burst(world.fx, global_position + Vector2(0, -4), UiTheme.AMBER, 4, 30, 0.25, 1.0)
	queue_free()
