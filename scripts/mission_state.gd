extends RefCounted
## Regras da missão e progresso offline. A interface e o mundo não vivem aqui.
const DURATION: float = 300.0
const SAVE_VERSION: int = 1
var save_path: String = "user://mission_3d_v2.json"
var evidence_ids: Array[String] = ["arquivo", "praca", "redacao"]
var collected: Array[String] = []
var elapsed: float = 0.0
var alert: float = 0.0
var outcome: String = ""
var position: Vector3 = Vector3(0, 0.1, 16)
var last_save_ok: bool = true


func start_new() -> void:
	collected.clear()
	elapsed = 0.0
	alert = 0.0
	outcome = ""
	position = Vector3(0, 0.1, 16)
	last_save_ok = true


func remaining() -> float:
	return maxf(0.0, DURATION - elapsed)


func collect(id: String) -> bool:
	if not outcome.is_empty() or id not in evidence_ids or id in collected:
		return false
	collected.append(id)
	return true


func tick(delta: float, exposure: float) -> void:
	if not outcome.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	elapsed = minf(DURATION, elapsed + delta)
	alert = clampf(alert + (20.0 * exposure if exposure > 0.0 else -10.0) * delta, 0.0, 100.0)
	if remaining() <= 0.0:
		outcome = "timed_out"
	elif alert >= 100.0:
		outcome = "detected"


func transmit() -> bool:
	if not outcome.is_empty() or collected.size() != evidence_ids.size():
		return false
	outcome = "transmitted"
	return true


func save_game() -> bool:
	var file: FileAccess = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_save_ok = false
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION, "collected": collected, "elapsed": elapsed,
		"alert": alert, "outcome": outcome,
		"position": [position.x, position.y, position.z],
	}))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	last_save_ok = error == OK and DirAccess.rename_absolute(save_path + ".tmp", save_path) == OK
	return last_save_ok


func has_save() -> bool:
	return not _read_save().is_empty()


func load_game() -> bool:
	var data: Dictionary = _read_save()
	if data.is_empty():
		return false
	collected.assign(data["collected"])
	elapsed = float(data["elapsed"])
	alert = float(data["alert"])
	outcome = String(data["outcome"])
	var p: Array = data["position"]
	position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	last_save_ok = true
	return true


func _read_save() -> Dictionary:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 16384:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if data.get("version") != SAVE_VERSION or not data.get("collected") is Array:
		return {}
	var ids: Array = data["collected"]
	var seen: Array = []
	for id: Variant in ids:
		if not id is String or id not in evidence_ids or id in seen:
			return {}
		seen.append(id)
	for key: String in ["elapsed", "alert"]:
		if not _number(data.get(key)):
			return {}
	if float(data["elapsed"]) < 0.0 or float(data["elapsed"]) > DURATION:
		return {}
	if float(data["alert"]) < 0.0 or float(data["alert"]) > 100.0:
		return {}
	if data.get("outcome") not in ["", "transmitted", "detected", "timed_out"]:
		return {}
	if data["outcome"] == "transmitted" and ids.size() != evidence_ids.size():
		return {}
	if data["outcome"] == "detected" and float(data["alert"]) < 100.0:
		return {}
	if data["outcome"] == "timed_out" and float(data["elapsed"]) < DURATION:
		return {}
	if data["outcome"] == "" and (float(data["elapsed"]) >= DURATION or float(data["alert"]) >= 100.0):
		return {}
	var p: Variant = data.get("position")
	if not p is Array or p.size() != 3:
		return {}
	for value: Variant in p:
		if not _number(value):
			return {}
	if absf(float(p[0])) > 39.0 or absf(float(p[2])) > 39.0 or float(p[1]) < -2.0 or float(p[1]) > 10.0:
		return {}
	return data


func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
