class_name RelicChoice
extends Overlay
## "Choose one relic" cards shown at treasure altars.

signal chosen(id: String)

const CARD_SIZE := Vector2(150, 150)

var ids: Array = []
var title_text := "祭坛上的遗物 · 选择一件"


func _init() -> void:
	super()
	closable = false   # the altar's offer has to be answered


func _build() -> void:
	var box := Ui.vbox(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(Ui.heading(title_text))
	var row := Ui.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for id: String in ids:
		row.add_child(_card(id))
	add_centered(box)
	if row.get_child_count() > 0:
		(row.get_child(0) as Button).grab_focus.call_deferred()


func _card(id: String) -> Button:
	var def: Dictionary = Relics.DEFS[id]
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	Ui.add_sounds(card)
	card.pressed.connect(_choose.bind(id))
	var rows := Ui.vbox(5)
	Ui.fill_parent(rows)
	rows.offset_left = 8
	rows.offset_right = -8
	rows.offset_top = 10
	rows.offset_bottom = -8
	card.add_child(rows)
	rows.add_child(Ui.center(_framed_icon(id, def.rarity)))
	rows.add_child(Ui.centered_label(def.name))
	rows.add_child(Ui.centered_label(Relics.RARITY_NAME[def.rarity], Relics.RARITY_COLOR[def.rarity]))
	var text: String = def.desc
	var owned := Relics.count(Run.relics, id)
	if owned > 0:
		text += "（已有 %d）" % owned
	var desc := Ui.wrapped_label(text, UiTheme.MIST, 130)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(desc)
	# the card itself is the button: nothing inside may swallow the click
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Control in rows.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## The relic's icon at double size inside a frame coloured by rarity.
func _framed_icon(id: String, rarity: String) -> TextureRect:
	var frame := TextureRect.new()
	frame.texture = SpriteLib.ui("frame_" + rarity)
	frame.custom_minimum_size = Vector2(40, 40)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = SpriteLib.icon(id)
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = Vector2(4, 4)
	icon.size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	return frame


func _choose(id: String) -> void:
	chosen.emit(id)
	close()
