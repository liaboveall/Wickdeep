class_name BotPilot
extends Pilot
## The autoplay bot's side of every decision a person would make in a menu: it takes the first
## relic, shops by a fixed rule, and never chats. Its hands are src/dev/bot_input.gd.

## The bot only buys healing when it is down by at least this much.
const HEAL_THRESHOLD := 2


func make_input() -> PlayerInput:
	return BotInput.new()


func choose_relic(ids: Array, on_chosen: Callable) -> void:
	on_chosen.call(ids[0])


## Heal when hurt, then buy whatever relics it can afford.
func shop() -> void:
	var order: Array = []
	for id: String in Run.camp.stock:
		if Relics.is_potion(id):
			order.push_front(id)
		else:
			order.append(id)
	for id: String in order:
		if Relics.is_potion(id) and Run.hp > Run.max_hp - HEAL_THRESHOLD:
			continue
		var price := Shop.price(id)
		if Shop.buy(id) == Shop.Result.OK:
			print("BOT_SHOP bought %s for %d" % [id, price])


func wick_chat() -> void:
	pass


func pauses_on_focus_loss() -> bool:
	return false
