class_name CampVisit
extends RefCounted
## Everything that only lasts for one stop at the camp: Granny's stock and mood, how much haggling
## is left, what Wick said on arrival. A fresh one is made each time a depth is finished.

var stock: Array = []            # relic / potion ids on the stall
var sold: Array = []
var price_mult := 1.0            # haggled price multiplier (see Haggle)
var haggles_used := 0
var gift_given := false
var story_told := false
var granny_chat: Array = []      # conversation so far, OpenAI message format
var wick_arrival := ""           # Wick's greeting, once it has been written
var rested := false              # the campfire heal has been used


func _init(starting_price_mult := 1.0) -> void:
	price_mult = starting_price_mult


func to_dict() -> Dictionary:
	return {
		"shop_stock": stock, "shop_sold": sold, "price_mult": price_mult,
		"haggles_used": haggles_used, "gift_given": gift_given, "story_told": story_told,
		"rested": rested,
	}


static func from_dict(d: Dictionary) -> CampVisit:
	var v := CampVisit.new(float(d.get("price_mult", 1.0)))
	v.stock = _strings(d.get("shop_stock", []))
	v.sold = _strings(d.get("shop_sold", []))
	v.haggles_used = int(d.get("haggles_used", 0))
	v.gift_given = bool(d.get("gift_given", false))
	v.story_told = bool(d.get("story_told", false))
	v.rested = bool(d.get("rested", false))
	return v


static func _strings(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for item in v:
			out.append(str(item))
	return out
