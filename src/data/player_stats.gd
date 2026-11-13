class_name PlayerStats
extends RefCounted
## Everything relics can change about the player. Built by Relics.compute() from the list of owned
## relics, so there is never any "undo this bonus" bookkeeping: the list is the truth.

const BASE_DAMAGE := 10.0
const BASE_FIRE_INTERVAL := 0.25

# ---- ember bolts
var damage := BASE_DAMAGE
var fire_interval := BASE_FIRE_INTERVAL
var shot_speed := 280.0
var shot_range := 220.0
var projectiles := 1
var spread := 9.0            # degrees between bolts of a multi-shot
var inaccuracy := 2.0        # random spread in degrees
var pierce := 0
var bounces := 0
var homing := 0.0
var crit_chance := 0.03
var burn_chance := 0.0
var shatter := false
var bolt_scale := 1.0

# ---- movement
var move_speed := 96.0
var dash_cooldown := 0.75
var dash_damage := 0.0

# ---- utility
var pickup_radius := 22.0
var ember_mult := 1.0
var flare_rate := 1.0
var explode_on_kill := 0.0
var motes := 0
var shade := false           # block the first hit in every room
var moth := false            # heal a little every so many kills
var bell := false            # free flare when hurt
var revive := false
var enemy_bullet_speed := 1.0
var max_hp_bonus := 0

# ---- accumulators that relic effects write to; resolve() folds them into the stats above.
# Bonuses add up (+25% and +25% is +50%), multipliers multiply, and the two never depend on the
# order the relics were picked up in.
var damage_bonus := 1.0
var damage_mult := 1.0
var rate_bonus := 1.0
var rate_mult := 1.0
var mote_stacks := 0


## Apply one relic's effect table: {"add": {...}, "mul": {...}, "set": {...}}.
func apply(effect: Dictionary) -> void:
	var add: Dictionary = effect.get("add", {})
	for key in add:
		set(key, get(key) + add[key])
	var mul: Dictionary = effect.get("mul", {})
	for key in mul:
		set(key, get(key) * mul[key])
	var assign: Dictionary = effect.get("set", {})
	for key in assign:
		set(key, assign[key])


func resolve() -> void:
	damage = BASE_DAMAGE * (damage_bonus * damage_mult)
	fire_interval = BASE_FIRE_INTERVAL / (rate_bonus * rate_mult)
	# the first stack brings two motes, every further one adds one
	motes = mote_stacks + 1 if mote_stacks > 0 else 0


func has_property(key: String) -> bool:
	return key in self
