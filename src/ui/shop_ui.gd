class_name ShopUi
extends Overlay
## Granny's stall: the item list on the left, the haggling chat on the right.
## Prices and purchases are Shop's business, her replies Granny's and Haggle's; this screen only
## shows the result and plays the sounds.

const LIST_WIDTH := 214

var chat: ChatPanel
var _items: VBoxContainer
var _detail: Label
var _buy: Button
var _embers: Label
var _price_note: Label
var _selected := ""


func _build() -> void:
	var columns := Ui.hbox(8)
	columns.add_child(_build_stall())
	chat = ChatPanel.new()
	chat.speaker_name = "秤婆"
	chat.speaker_color = Color("#f08a6a")
	chat.talk_sound = "talk_granny"
	chat.portrait = SpriteLib.region("portraits", "granny")
	chat.custom_minimum_size = Vector2(370, 300)
	columns.add_child(chat)
	add_centered(columns)
	chat.submitted.connect(say_to_granny)
	for option: Dictionary in GameText.GRANNY_OPTIONS:
		chat.add_quick(option.label, say_to_granny.bind(option.say, option.id))
	if not AI.available():
		chat.disable_free_text("填写 DeepSeek API Key 后可以随便跟她说话")
	if Run.camp.granny_chat.is_empty():
		chat.say(Granny.greeting())
	else:
		chat.replay(Run.camp.granny_chat)
	_refresh()
	_show_haggle_state()


func _build_stall() -> Control:
	var stall := panel(Vector2(230, 300))
	var rows := Ui.vbox(4)
	stall.add_child(rows)
	rows.add_child(Ui.heading("秤婆的货摊"))
	var purse := Ui.hbox(4)
	purse.add_child(Ui.image(SpriteLib.ui("ember_icon")))
	_embers = UiTheme.label("", UiTheme.GOLD)
	purse.add_child(_embers)
	_price_note = UiTheme.label("", UiTheme.MIST)
	_price_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	purse.add_child(_price_note)
	rows.add_child(purse)
	_items = Ui.vbox(3)
	rows.add_child(_items)
	_detail = Ui.wrapped_label("", UiTheme.MIST, 210)
	_detail.custom_minimum_size.y = 44
	rows.add_child(_detail)
	var buttons := Ui.hbox(6)
	_buy = Ui.button("买下", _purchase, 90)
	buttons.add_child(_buy)
	buttons.add_child(Ui.button("离开", close, 90))
	rows.add_child(buttons)
	return stall


# ------------------------------------------------------------------ the stall
func _refresh() -> void:
	_embers.text = str(Run.embers)
	var percent := int(round((Run.camp.price_mult - 1.0) * 100.0))
	_price_note.text = "原价" if percent == 0 else "价格 %+d%%" % percent
	_price_note.add_theme_color_override("font_color",
		UiTheme.TEAL if percent < 0 else (UiTheme.RED if percent > 0 else UiTheme.MIST))
	for row in _items.get_children():
		row.queue_free()
	var first_for_sale: Button = null
	for id: String in Run.camp.stock:
		var row := _item_row(id)
		_items.add_child(row)
		if first_for_sale == null and not row.disabled:
			first_for_sale = row
	if _selected == "" or Shop.is_sold(_selected):
		_selected = ""
		if first_for_sale:
			first_for_sale.grab_focus.call_deferred()   # focusing a row selects it
	_show_detail()


func _item_row(id: String) -> Button:
	var sold := Shop.is_sold(id)
	var row := Button.new()
	row.custom_minimum_size = Vector2(LIST_WIDTH, 22)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.icon = SpriteLib.icon(id)
	row.text = Relics.display_name(id) + ("（已售出）" if sold else "")
	row.disabled = sold
	if not Relics.is_potion(id):
		row.add_theme_color_override("font_color", Relics.RARITY_COLOR[Relics.rarity(id)])
	if not sold:
		var price := Shop.price(id)
		var tag := UiTheme.label(str(price), UiTheme.GOLD if Run.embers >= price else UiTheme.RED)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.position = Vector2(150, 4)
		tag.size = Vector2(56, 14)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
	row.pressed.connect(_select.bind(id))
	row.focus_entered.connect(_select.bind(id))
	return row


func _select(id: String) -> void:
	_selected = id
	Sound.play("ui_move", -8.0)
	_show_detail()


func _show_detail() -> void:
	_buy.disabled = _selected == ""
	if _selected == "":
		_detail.text = "全都卖光啦。" if Shop.unsold().is_empty() else "选一件看看。"
		return
	var title := Relics.display_name(_selected)
	if not Relics.is_potion(_selected):
		title += " · " + Relics.RARITY_NAME[Relics.rarity(_selected)]
	_detail.text = "【%s】%s\n价格：%d 余烬" % [title, Relics.description(_selected), Shop.price(_selected)]


func _purchase() -> void:
	if _selected == "":
		return
	var is_relic := not Relics.is_potion(_selected)
	match Shop.buy(_selected):
		Shop.Result.OK:
			Sound.play("coin")
			if is_relic:
				Sound.play("relic", -4.0)
			chat.say(GameText.granny_line("buy"))
			_selected = ""
			_refresh()
		Shop.Result.TOO_POOR:
			Sound.play("deny")
			chat.say(GameText.granny_line("poor"))
		Shop.Result.NOT_NEEDED:
			Sound.play("deny")
			chat.say(GameText.granny_line("full"))


# ------------------------------------------------------------------ haggling
## Say something to Granny: free text, or a quick reply (then `option_id` names it).
func say_to_granny(text: String, option_id := "") -> void:
	chat.skip_typing()
	chat.player_said(text)
	if Granny.will_think():
		chat.set_busy(true)
	Granny.hear(text, option_id, _on_turn)


func _on_turn(turn: Haggle.Turn) -> void:
	chat.set_busy(false)
	chat.set_status(turn.note)
	if turn.price_change < 0:
		Sound.play("coin", -6.0, 1.2)
	elif turn.price_change > 0:
		Sound.play("deny", -6.0)
	if turn.gift:
		Sound.play("heal")
	chat.say(turn.reply)
	_refresh()
	_show_haggle_state()


func _show_haggle_state() -> void:
	var left := Haggle.lines_left()
	if left <= 0:
		chat.set_input_enabled(false)
		chat.set_status("秤婆说累了，不想再讲价了。")
	elif left < Haggle.MAX_LINES and chat.status.text == "":
		chat.set_status("还能再说 %d 句" % left)
