class_name Pilot
extends RefCounted
## Whoever is playing. This base class is a person: the controls come from keyboard, mouse or
## gamepad, and every choice opens a menu. The autoplay bot (src/dev/bot_pilot.gd) overrides it to
## decide on the spot, so the rest of the game never has to ask "is this a test run?".

var game: Game


func _init(game_root: Game) -> void:
	game = game_root


func make_input() -> PlayerInput:
	return PlayerInput.Human.new()


## Offer relics; `on_chosen` receives the id that was picked.
func choose_relic(ids: Array, on_chosen: Callable) -> void:
	var menu := RelicChoice.new()
	menu.ids = ids
	menu.chosen.connect(on_chosen)
	game.overlays.push(menu)


func shop() -> void:
	game.overlays.push(ShopUi.new())


func wick_chat() -> void:
	game.overlays.push(WickDialog.new())


func settings() -> void:
	game.overlays.push(SettingsMenu.new())


func pause() -> void:
	game.overlays.push(PauseMenu.new())


## Whether losing window focus should pause the game.
func pauses_on_focus_loss() -> bool:
	return true
