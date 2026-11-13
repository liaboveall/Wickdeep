class_name WickDialog
extends Overlay
## Fireside conversation with Wick, the lantern spirit. What he says is decided in
## src/characters/wick.gd; this is only the chat window.

const PANEL_SIZE := Vector2(600, 176)

var chat: ChatPanel


func _init() -> void:
	super()
	dim = 0.35   # keep the camp visible behind the conversation


func _build() -> void:
	chat = ChatPanel.new()
	chat.speaker_name = "灯芯"
	chat.speaker_color = UiTheme.AMBER
	chat.talk_sound = "talk_wick"
	chat.portrait = SpriteLib.region("portraits", "wick")
	chat.custom_minimum_size = PANEL_SIZE
	chat.size = PANEL_SIZE
	chat.position = Vector2((View.W - PANEL_SIZE.x) / 2.0, View.H - PANEL_SIZE.y - 10)
	add_child(chat)
	chat.submitted.connect(ask)
	for question: Array in GameText.WICK_QUESTIONS:
		chat.add_quick(question[0], ask.bind(question[1]))
	chat.add_quick("再见", close)
	if not AI.available():
		chat.disable_free_text("在 设置 → AI 角色 里填写 DeepSeek API Key 后可以自由聊天")
	if Run.wick_chat.is_empty():
		chat.say(Run.camp.wick_arrival if Run.camp.wick_arrival != "" else GameText.WICK_HELLO)
	else:
		chat.replay(Run.wick_chat)
	chat.focus_input()


func ask(text: String) -> void:
	chat.skip_typing()
	chat.player_said(text)
	if AI.available():
		chat.set_busy(true)
	Wick.hear(text, _on_reply)


func _on_reply(reply: String, note: String) -> void:
	chat.set_busy(false)
	if note != "":
		chat.set_status(note)
	chat.say(reply)
