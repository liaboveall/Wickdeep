class_name EndScreen
extends Control
## Shown after death or victory: Wick writes an epitaph / ending (AI or scripted), plus run stats.

var game: Game
var victory := false
var _epitaph_title: Label
var _epitaph: RichTextLabel
var _typewriter: Typewriter


func _ready() -> void:
	Ui.fill_parent(self)
	theme = UiTheme.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var backdrop := ColorRect.new()
	backdrop.color = Color("#1e1520") if victory else View.BACKDROP
	Ui.fill_parent(backdrop)
	add_child(backdrop)
	var rows := Ui.vbox(8)
	rows.position = Vector2(80, 26)
	rows.size = Vector2(480, 320)
	add_child(rows)
	rows.add_child(Ui.centered_label("圣火重燃" if victory else "灯火熄灭", UiTheme.GOLD if victory else UiTheme.RED, 24))
	rows.add_child(Ui.centered_label(_summary_line(), UiTheme.MIST))
	rows.add_child(_build_epitaph())
	rows.add_child(Ui.center(_build_stats()))
	rows.add_child(Ui.center(_build_relic_row()))
	var buttons := Ui.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := Ui.button("再来一局", game.start_run, 110)
	buttons.add_child(again)
	buttons.add_child(Ui.button("返回标题", game.show_title, 110))
	rows.add_child(buttons)
	again.grab_focus.call_deferred()
	Sound.music("victory" if victory else "death", 0.3)
	Wick.write_epitaph(victory, _show_epitaph)


func _summary_line() -> String:
	if victory:
		return "你击败了熄灯者，深渊重新有了光。"
	var line := "倒在了%s。" % Run.depth_title()
	if Run.killer != "":
		line += "击倒你的是%s。" % Bestiary.display_name(Run.killer, "黑暗")
	return line


func _build_epitaph() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(480, 96)
	var rows := Ui.vbox(4)
	frame.add_child(rows)
	var author := Ui.hbox(6)
	var wick := TextureRect.new()
	wick.texture = SpriteLib.region("wick", "idle")
	author.add_child(wick)
	_epitaph_title = UiTheme.label("灯芯正在写……", UiTheme.AMBER)
	author.add_child(_epitaph_title)
	rows.add_child(author)
	_epitaph = RichTextLabel.new()
	_epitaph.bbcode_enabled = false
	_epitaph.fit_content = true
	_epitaph.custom_minimum_size = Vector2(460, 48)
	rows.add_child(_epitaph)
	_typewriter = Typewriter.new(_epitaph)
	_typewriter.blip_volume = -12.0
	_typewriter.blip_pitch_var = 0.0
	_typewriter.blip_every = 4
	add_child(_typewriter)
	return frame


func _build_stats() -> Control:
	var stats := Ui.grid(4, 18, 4)
	for entry: Array in [
			["到达", Run.depth_title()], ["用时", TextUtil.clock(Run.time)],
			["击败", str(Run.kills)], ["造成伤害", str(int(Run.damage_dealt))],
			["受到伤害", str(Run.damage_taken)], ["清理房间", str(Run.rooms_cleared)],
			["余烬", str(Run.embers)], ["遗物", str(Run.relics.size())]]:
		stats.add_child(UiTheme.label(entry[0], UiTheme.DIM))
		stats.add_child(UiTheme.label(entry[1], UiTheme.CREAM))
	return stats


func _build_relic_row() -> Control:
	var icons := Ui.hbox(2)
	for id: String in Run.relics:
		var icon := TextureRect.new()
		icon.texture = SpriteLib.icon(id)
		icon.tooltip_text = Relics.display_name(id)
		icons.add_child(icon)
	return icons


func _show_epitaph(title: String, text: String) -> void:
	_epitaph_title.text = "「%s」" % title
	_epitaph.text = text
	_typewriter.start()
