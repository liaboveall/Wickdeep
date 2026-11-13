class_name PauseMenu
extends Overlay
## Pause screen: resume, settings, abandon the run, quit; plus the list of owned relics.


func _build() -> void:
	var columns := Ui.hbox(12)
	columns.add_child(_build_menu())
	columns.add_child(_build_relic_list())
	add_centered(columns)


func _build_menu() -> Control:
	var menu := panel(Vector2(170, 0))
	var rows := Ui.vbox(6)
	menu.add_child(rows)
	rows.add_child(Ui.heading("暂停"))
	rows.add_child(Ui.centered_label("%s\n用时 %s · 击败 %d" % [Run.depth_title(), TextUtil.clock(Run.time), Run.kills],
		UiTheme.MIST))
	var resume := Ui.button("继续", close)
	rows.add_child(resume)
	rows.add_child(Ui.button("设置", game.pilot.settings))
	rows.add_child(Ui.button("放弃本局", game.abandon_run))
	rows.add_child(Ui.button("退出游戏", game.quit_game))
	resume.grab_focus.call_deferred()
	return menu


func _build_relic_list() -> Control:
	var relic_panel := panel(Vector2(260, 220))
	var rows := Ui.vbox(4)
	relic_panel.add_child(rows)
	rows.add_child(UiTheme.label("遗物（%d）" % Run.relics.size(), UiTheme.GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var list := Ui.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if Run.relics.is_empty():
		list.add_child(UiTheme.label("还没有遗物。去宝藏房的祭坛看看吧。", UiTheme.DIM))
	for entry: Array in Relics.tally(Run.relics):
		var id: String = entry[0]
		var copies: int = entry[1]
		var row := Ui.hbox(6)
		row.add_child(Ui.relic_icon(id))
		var text := "%s%s：%s" % [Relics.display_name(id), (" ×%d" % copies) if copies > 1 else "",
			Relics.description(id)]
		var line := Ui.wrapped_label(text, UiTheme.CREAM, 210)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		list.add_child(row)
	return relic_panel
