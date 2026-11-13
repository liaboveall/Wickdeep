class_name UiTour
extends Node
## Scripted walk through every screen and menu (`--ui-tour`), pressing the real buttons and
## checking what happened. It covers what the autoplay bot skips, because the bot never opens a
## menu: title -> settings -> new run -> pause -> altar -> camp -> quit and continue -> shop ->
## Wick -> next depth -> death -> retry -> abandon.
##
## Prints one line per step and "UI_TOUR n steps, m failures"; exits with 1 if any step failed.

const TIMEOUT := 8.0             # for one screen to appear
const WATCHDOG := 90.0           # for the whole tour

var game: Game
var steps := 0
var failures := 0
var _elapsed := 0.0


func _init(game_root: Game) -> void:
	game = game_root
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	Settings.ai_enabled = false   # scripted characters answer at once
	await _title_and_settings()
	await _first_level()
	await _camp()
	await _death_and_retry()
	print("UI_TOUR %d steps, %d failures" % [steps, failures])
	get_tree().quit(mini(failures, 1))


## If a step throws, its coroutine just stops; make sure the session still ends.
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > WATCHDOG:
		print("UI_TOUR aborted after %d steps: no progress (a step probably hit a script error)" % steps)
		get_tree().quit(1)


# ------------------------------------------------------------------ the route
func _title_and_settings() -> void:
	await _screen(TitleScreen)
	_press(game.screen, "设置")
	await _frames()
	_step("title: settings open and pause the tree", game.overlays.top() is SettingsMenu and get_tree().paused)
	_press(game.overlays.top(), "保存并返回")
	await _frames()
	_step("title: settings close again", game.overlays.is_empty() and not get_tree().paused)
	_press(game.screen, "新的旅程")


func _first_level() -> void:
	var level: Level = await _screen(Level)
	_step("new run: at depth 1 with a player", Run.active and Run.depth == 1 and level.player != null)
	_press_action("pause")
	await _frames()
	_step("level: pause key opens the pause menu", game.overlays.top() is PauseMenu and get_tree().paused)
	_press(game.overlays.top(), "设置")
	await _frames()
	_step("pause: settings stack on top", game.overlays.top() is SettingsMenu)
	_press(game.overlays.top(), "保存并返回")
	await _frames()
	_step("pause: back to the pause menu, still paused", game.overlays.top() is PauseMenu and get_tree().paused)
	_press(game.overlays.top(), "继续")
	await _frames()
	_step("pause: resume", game.overlays.is_empty() and not get_tree().paused)
	var altar := _find(level, Interactable.Kind.ALTAR)
	_step("level: has an altar", altar != null)
	altar.use()
	await _frames()
	var choice := game.overlays.top() as RelicChoice
	_step("altar: offers three relics", choice != null and choice.ids.size() == 3)
	_press_action("pause")
	await _frames()
	_step("altar: the choice cannot be dismissed", game.overlays.top() == choice)
	var offered: String = choice.ids[0]
	_press_first(choice)
	await _frames()
	_step("altar: picking a card grants the relic", Run.relics == [offered] and game.overlays.is_empty())
	_step("altar: spent afterwards", not altar.enabled)
	game.descend()


func _camp() -> void:
	var camp: Camp = await _screen(Camp)
	_step("camp: next depth is 2 and a checkpoint exists", Run.depth == 2 and SaveData.has_run())
	_step("camp: Wick has greeted the player", Run.camp.wick_arrival != "")
	_step("camp: stall stocked", Run.camp.stock.size() == Shop.RELICS_ON_OFFER + Relics.POTIONS.size())
	camp = await _quit_and_continue()
	Run.add_embers(300)
	_find(camp, Interactable.Kind.SHOP).use()
	await _frames()
	var shop := game.overlays.top() as ShopUi
	_step("shop: opens", shop != null)
	var wanted: String = Run.camp.stock[0]
	_press(shop, Relics.display_name(wanted))
	_press(shop, "买下")
	await _frames()
	_step("shop: buying a relic", Shop.is_sold(wanted) and wanted in Run.relics and Run.embers < 300)
	_press(shop, "砍价")
	await _frames()
	_step("shop: a quick reply uses one haggle line", Run.camp.haggles_used == 1)
	_press(shop, "离开")
	await _frames()
	_step("shop: closes", game.overlays.is_empty())
	_find(camp, Interactable.Kind.WICK).use()
	await _frames()
	var dialog := game.overlays.top() as WickDialog
	_step("wick: dialog opens", dialog != null)
	_press(dialog, "给我点建议")
	await _frames()
	_press(dialog, "再见")
	await _frames()
	_step("wick: dialog closes", game.overlays.is_empty() and not get_tree().paused)
	_find(camp, Interactable.Kind.STAIRS).use()


## Leave for the title screen and come back through "continue": the checkpoint written on
## arriving at the camp must bring back the same run.
func _quit_and_continue() -> Camp:
	var relics := Run.relics.duplicate()
	var stock := Run.camp.stock.duplicate()
	var hp := Run.hp
	game.show_title()
	await _screen(TitleScreen)
	_step("title: offers to continue", _find_button(game.screen, "继续旅程") != null)
	_press(game.screen, "继续旅程")
	var camp: Camp = await _screen(Camp)
	_step("continue: same depth, relics, health and stall",
		Run.active and Run.depth == 2 and Run.relics == relics and Run.camp.stock == stock and Run.hp == hp)
	return camp


func _death_and_retry() -> void:
	var level: Level = await _screen(Level)
	_step("depth 2: reached by the camp stairs", level.depth == 2)
	level.player.hurt(999.0, "slime", level.player.global_position + Vector2.RIGHT)
	_step("death: the player is down", level.player.dead and Run.hp == 0)
	await _screen(EndScreen)
	_step("death: run closed, checkpoint gone, epitaph kept",
		not Run.active and not SaveData.has_run() and SaveData.epitaphs.size() == 1)
	_press(game.screen, "再来一局")
	await _screen(Level)
	_step("retry: a fresh run at depth 1", Run.active and Run.depth == 1 and Run.relics.is_empty())
	_press_action("pause")
	await _frames()
	_press(game.overlays.top(), "放弃本局")
	await _screen(TitleScreen)
	_step("abandon: back at the title with no run", not Run.active and game.overlays.is_empty())


# ------------------------------------------------------------------ helpers
func _step(what: String, ok: bool) -> void:
	steps += 1
	if not ok:
		failures += 1
	print("UI_TOUR %s %s" % ["ok  " if ok else "FAIL", what])


## Wait until a screen of the given type is up and has faded in; returns it (or null on timeout).
func _screen(type: Variant) -> Node:
	var waited := 0.0
	while not (game.can_interact() and is_instance_of(game.screen, type)):
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > TIMEOUT:
			_step("screen did not appear in time", false)
			return null
	await _frames()
	return game.screen


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


## Press the first enabled button under `root` whose text contains `text` ("" = any button).
func _press(root: Node, text: String) -> void:
	var button := _find_button(root, text)
	if button == null:
		_step("no button \"%s\"" % text, false)
		return
	button.pressed.emit()


func _press_first(root: Node) -> void:
	_press(root, "")


func _find_button(node: Node, text: String) -> BaseButton:
	var button := node as Button
	if button and not button.disabled and button.is_visible_in_tree() and (text == "" or text in button.text):
		return button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null


func _find(world: World, kind: Interactable.Kind) -> Interactable:
	for it in world.interactables:
		if it.kind == kind:
			return it
	return null
