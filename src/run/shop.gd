class_name Shop
extends RefCounted
## Rules of Granny's stall: what is on offer, what it costs, what buying does.
## No UI in here: the shop screen and the autoplay bot both go through these functions.

enum Result { OK, SOLD, TOO_POOR, NOT_NEEDED }

const RELICS_ON_OFFER := 3
## Relics get dearer in deeper camps (lamp oil keeps its price).
const DEPTH_MARKUP := 0.12


## Fill the stall for this visit (kept if the visit was restored from a checkpoint).
static func restock(rng: RandomNumberGenerator) -> void:
	var visit := Run.camp
	if not visit.stock.is_empty():
		return
	visit.stock.append_array(Relics.roll(rng, Run.relics, RELICS_ON_OFFER))
	visit.stock.append_array(Relics.POTIONS.keys())


static func depth_scale(id: String, depth: int) -> float:
	if Relics.is_potion(id):
		return 1.0
	return 1.0 + DEPTH_MARKUP * maxi(0, depth - 2)


static func price_at(id: String, depth: int, price_mult: float) -> int:
	return maxi(1, int(round(Relics.base_price(id) * depth_scale(id, depth) * price_mult)))


## What the player pays right now, after depth mark-up and haggling.
static func price(id: String) -> int:
	return price_at(id, Run.depth, Run.camp.price_mult)


static func is_sold(id: String) -> bool:
	return id in Run.camp.sold


static func unsold() -> Array:
	return Run.camp.stock.filter(func(id: String) -> bool: return not is_sold(id))


static func check(id: String) -> Result:
	if not id in Run.camp.stock or is_sold(id):
		return Result.SOLD
	if Run.embers < price(id):
		return Result.TOO_POOR
	if Relics.is_potion(id) and not Run.is_hurt():
		return Result.NOT_NEEDED
	return Result.OK


static func buy(id: String) -> Result:
	var result := check(id)
	if result != Result.OK:
		return result
	Run.spend(price(id))
	Run.camp.sold.append(id)
	if Relics.is_potion(id):
		Run.heal(int(Relics.POTIONS[id].heal))
	else:
		Run.add_relic(id)
	return Result.OK


## "双芯（原价 75）、灯油（原价 25）": what Granny is told she still has.
static func describe_stock() -> String:
	var parts := PackedStringArray()
	for id: String in unsold():
		parts.append("%s（原价 %d）" % [Relics.display_name(id), Relics.base_price(id)])
	return "、".join(parts)
