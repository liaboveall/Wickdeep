class_name DepthLog
extends RefCounted
## What happened on the depth being played: Wick comments on it at the next camp.

var kills := {}          # enemy kind -> count
var hurt_by := {}        # enemy kind -> damage taken
var damage_taken := 0
var time := 0.0


func add_kill(kind: String) -> void:
	kills[kind] = int(kills.get(kind, 0)) + 1


func add_damage(amount: int, source: String) -> void:
	damage_taken += amount
	hurt_by[source] = int(hurt_by.get(source, 0)) + amount


func total_kills() -> int:
	var n := 0
	for kind in kills:
		n += kills[kind]
	return n


## The enemy kind that hurt the player most ("" if nothing did).
func worst_enemy() -> String:
	var worst := ""
	var most := 0
	for kind in hurt_by:
		if hurt_by[kind] > most:
			most = hurt_by[kind]
			worst = kind
	return worst


func summary(depth: int, hp: int, max_hp: int) -> Dictionary:
	return {
		"depth": depth, "kills": total_kills(), "damage_taken": damage_taken,
		"worst_enemy": worst_enemy(), "time": int(time), "hp": hp, "max_hp": max_hp,
	}
