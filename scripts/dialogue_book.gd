extends RefCounted
## Conversas curtas, contextuais e locais; nenhuma mensagem sai do aparelho.

const DATA_PATH: String = "res://data/dialogues.json"
var _entries: Dictionary = {}


func _init() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null or file.get_length() > 131072:
		return
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return
	var data: Dictionary = parser.data
	if data.get("version") == 1 and data.get("characters") is Dictionary:
		_entries = data["characters"].duplicate(true)


func get_dialogue(id: String, context: Dictionary = {}) -> Array:
	if not _entries.has(id) or not _entries[id] is Dictionary:
		return []
	var entry: Dictionary = _entries[id]
	var variant: String = "first"
	var count: int = 0
	var count_value: Variant = context.get("collected", 0)
	if count_value is int or count_value is float:
		if is_finite(float(count_value)):
			count = clampi(int(count_value), 0, 3)
	var talked: Variant = context.get("talked", [])
	if count >= 3:
		variant = "ready"
	elif talked is Array and id in talked:
		variant = "repeat"
	elif count > 0:
		variant = "progress"
	var source: Variant = entry.get(variant, entry.get("first", []))
	if not source is Array:
		return []
	var lines: Array = []
	for line: Variant in source:
		if not line is Dictionary:
			return []
		if not line.get("speaker") is String or not line.get("text") is String:
			return []
		var speaker: String = line["speaker"].strip_edges()
		var text: String = line["text"].strip_edges()
		if speaker.is_empty() or text.is_empty() or speaker.length() > 64 or text.length() > 800:
			return []
		lines.append({"speaker": speaker, "text": text})
	return lines
