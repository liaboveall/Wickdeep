class_name TextUtil
extends RefCounted
## Small text helpers shared by the UI and the AI characters.

## Closing punctuation that must never start a line.
const NO_LINE_START := "，。！？、…）」”"


## Tidy a line that came from a language model: one line, bounded length.
static func clean(text: String, max_length := 90) -> String:
	var t := text.strip_edges().replace("\n", " ")
	if t.length() > max_length:
		t = t.left(max_length - 2) + "……"
	return t


## Break text into lines of at most `per_line` full-width characters (ASCII counts as half).
## Labels with autowrap resize unpredictably for CJK text, so speech bubbles wrap by hand.
static func wrap(text: String, per_line: int) -> String:
	var out := ""
	var width := 0.0
	for ch in text:
		var w := 1.0 if ch.unicode_at(0) > 255 else 0.5
		if width + w > per_line and not ch in NO_LINE_START:
			out += "\n"
			width = 0.0
		out += ch
		width += w
	return out


## Seconds as m:ss.
static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func pick(lines: Array) -> String:
	return lines[randi() % lines.size()]


static func pick_item(items: Array) -> Variant:
	return items[randi() % items.size()]


## RichTextLabel treats [ ] as markup; swap them for full-width brackets in untrusted text.
static func escape_bbcode(text: String) -> String:
	return text.replace("[", "［").replace("]", "］")
