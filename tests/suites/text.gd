extends "res://tests/test_suite.gd"
## Text helpers.


func test_wrap() -> void:
	equal(TextUtil.wrap("一二三四五六", 3), "一二三\n四五六", "breaks after N full-width characters")
	equal(TextUtil.wrap("一二三，四五", 3), "一二三，\n四五", "punctuation never starts a line")
	equal(TextUtil.wrap("abcdef", 3), "abcdef", "ASCII counts as half width")
	equal(TextUtil.wrap("", 5), "", "empty")
	for line in TextUtil.wrap("深渊里的事，问我就对了——我可是在这盏灯里住了三百年。", 13).split("\n"):
		check(line.length() <= 14, "no line much longer than the limit: " + line)


func test_clean() -> void:
	equal(TextUtil.clean("  你好\n世界  "), "你好 世界", "one line, trimmed")
	equal(TextUtil.clean("长".repeat(200)).length(), 90, "long replies are cut")
	check(TextUtil.clean("长".repeat(200)).ends_with("……"), "with an ellipsis")
	equal(TextUtil.clean("短"), "短", "short text untouched")


func test_clock() -> void:
	equal(TextUtil.clock(0.0), "0:00", "zero")
	equal(TextUtil.clock(59.9), "0:59", "seconds round down")
	equal(TextUtil.clock(734.0), "12:14", "minutes")


func test_escape_and_pick() -> void:
	equal(TextUtil.escape_bbcode("[b]粗[/b]"), "［b］粗［/b］", "brackets neutralised")
	for k in 20:
		check(TextUtil.pick(["a", "b"]) in ["a", "b"], "pick stays in the list")
	equal(TextUtil.pick_item([[1, 2]]), [1, 2], "pick_item returns the element itself")


func test_every_scripted_line_fits_a_bubble() -> void:
	for mood: String in GameText.WICK_ARRIVE:
		for line: String in GameText.WICK_ARRIVE[mood]:
			check(TextUtil.wrap(line, SpeechBubble.CHARS_PER_LINE).count("\n") <= 3, "bubble of at most 4 lines: " + line)
	for key: String in GameText.GRANNY_LINES:
		check(not GameText.GRANNY_LINES[key].is_empty(), "granny has a line for " + key)
		check(GameText.granny_line(key) != "", "and it is not empty")
	check("%s" not in GameText.wick_system() and "世界设定" in GameText.wick_system(), "wick prompt includes the world facts")
	check("price_multiplier" in GameText.granny_system(), "granny prompt explains the reply format")
