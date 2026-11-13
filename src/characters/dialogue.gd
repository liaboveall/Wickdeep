class_name Dialogue
extends RefCounted
## Chat history helpers shared by Wick and Granny (OpenAI message format).
## Their own turns are stored as the JSON object the model is asked to produce, which keeps it
## answering in that format on later turns.


static func user(text: String) -> Dictionary:
	return {"role": "user", "content": text}


static func assistant(reply: String) -> Dictionary:
	return {"role": "assistant", "content": JSON.stringify({"reply": reply})}


static func is_user(message: Dictionary) -> bool:
	return message.get("role", "") == "user"


## The words a stored message shows in the chat log.
static func spoken(message: Dictionary) -> String:
	var content := str(message.get("content", ""))
	if is_user(message):
		return content
	var data: Dictionary = AI.parse_json_object(content)
	return str(data.get("reply", content))


## The last `count` messages: enough context for the model without growing the prompt forever.
static func recent(chat: Array, count: int) -> Array:
	return chat.slice(maxi(0, chat.size() - count))


## A string field of a model reply, or "" when it is missing or not a string
## (models sometimes send null or a number where text was asked for).
static func text_field(data: Dictionary, key: String) -> String:
	var v: Variant = data.get(key)
	return (v as String).strip_edges() if v is String else ""
