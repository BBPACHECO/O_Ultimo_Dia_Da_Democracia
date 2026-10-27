extends RefCounted
class_name StoryGame

## Estado independente da interface. Toda a narrativa e o progresso ficam no aparelho.
const STORY_PATH := "res://data/story.json"
const SAVE_PATH := "user://game_save.json"
const SAVE_VERSION := 1
const INITIAL_STATS := {"voz": 55, "provas": 45, "risco": 20}

var save_path: String = SAVE_PATH
var stats: Dictionary = INITIAL_STATS.duplicate()
var step: int = 0
var history: Array = []
var last_save_ok: bool = true
var _cards: Array = []


func _init() -> void:
	var file := FileAccess.open(STORY_PATH, FileAccess.READ)
	if file == null:
		push_error("Não foi possível abrir a narrativa: " + STORY_PATH)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("A narrativa tem um formato inválido.")
		return
	var parsed = parser.data
	if parsed is Dictionary and parsed.get("chapters") is Array:
		_cards = parsed["chapters"]
	else:
		push_error("A narrativa tem um formato inválido.")


func start_new() -> void:
	stats = INITIAL_STATS.duplicate()
	step = 0
	history.clear()
	last_save_ok = save_game()


func get_card() -> Dictionary:
	if is_finished() or _cards.is_empty():
		return {}
	var card: Dictionary = _cards[step].duplicate(true)
	if not history.is_empty():
		var previous: Dictionary = history.back()
		var previous_card: Dictionary = _cards[step - 1]
		var response: String = previous_card["choices"][previous["index"]].get("after", "")
		card["consequence"] = response
	else:
		card["consequence"] = ""
	return card


func choose(index: int) -> bool:
	if is_finished() or _cards.is_empty():
		return false
	var card: Dictionary = _cards[step]
	var choices: Array = card["choices"]
	if index < 0 or index >= choices.size():
		return false
	var choice: Dictionary = choices[index]
	var effects: Dictionary = choice["effects"]
	for key in INITIAL_STATS:
		stats[key] = clampi(int(stats[key]) + int(effects.get(key, 0)), 0, 100)
	history.append({
		"chapter": step + 1,
		"title": card["title"],
		"label": choice["label"],
		"index": index,
		"effects": effects.duplicate(),
	})
	step += 1
	last_save_ok = save_game()
	return true


func is_finished() -> bool:
	return not _cards.is_empty() and step >= _cards.size()


func get_ending() -> Dictionary:
	if not is_finished():
		return {}
	if stats["risco"] >= 85:
		return {
			"id": "silencio",
			"title": "A frequência do silêncio",
			"body": "À meia-noite, a transmissão é interrompida. As portas da redação cedem antes que você consiga sair. O governo anuncia que nada aconteceu. Mas alguém, do outro lado da cidade, ouviu seu nome.",
			"epilogue": "Você expôs o suficiente para se tornar um alvo, mas não protegeu a rede que sustentava a notícia. Dias depois, cópias incompletas do seu trabalho começam a circular. A história continua, mesmo sem a sua assinatura.",
		}
	if stats["provas"] >= 75 and stats["voz"] >= 65:
		return {
			"id": "amanhecer",
			"title": "Ainda haverá amanhã",
			"body": "À meia-noite, milhares de rádios repetem as mesmas provas. Os documentos têm origem, as testemunhas têm proteção e as pessoas sabem onde se encontrar. A ordem de fechar a assembleia é suspensa. Pela primeira vez naquela noite, você escuta pássaros.",
			"epilogue": "Aurora não foi salva por uma única manchete. Professores, motoristas, vizinhos e repórteres mantêm as portas abertas até o amanhecer. O país ainda precisará responder pelo que aconteceu. Agora, poderá fazê-lo em público.",
		}
	if stats["provas"] >= 65:
		return {
			"id": "arquivo",
			"title": "O arquivo que ficou",
			"body": "À meia-noite, a cidade está quieta demais. A assembleia fecha e o decreto entra em vigor. Você não conseguiu reunir gente a tempo. Mas os arquivos cruzaram a fronteira, completos, com nomes, datas e cópias verificadas.",
			"epilogue": "Meses depois, uma comissão usa seu dossiê para encontrar os desaparecidos e contestar a versão oficial. Você não impediu aquela noite. Impediu que ela fosse apagada.",
		}
	if stats["voz"] >= 65:
		return {
			"id": "eco",
			"title": "Uma cidade em coro",
			"body": "À meia-noite, as praças estão cheias. A notícia ganhou as ruas antes que fosse possível provar cada detalhe. O decreto recua diante das janelas acesas, mas versões falsas começam a disputar o que as pessoas viram.",
			"epilogue": "Aurora comprou tempo. Na manhã seguinte, você volta à redação com uma tarefa mais difícil: transformar a coragem daquela noite em memória que resista à dúvida.",
		}
	return {
		"id": "exilio",
		"title": "A última travessia",
		"body": "À meia-noite, você atravessa a ponte com uma mochila e um caderno incompleto. Atrás de você, Aurora perde as últimas emissoras independentes. À frente, uma estação pequena mantém o sinal aberto para quem chegar.",
		"epilogue": "Você escolheu continuar vivo para contar. Ainda faltam provas e aliados, mas há uma primeira linha no seu caderno: ninguém transforma uma noite inteira em silêncio de uma vez.",
	}


func has_save() -> bool:
	# Um arquivo parcial ou incompatível não oferece uma continuação que falhará.
	return not _read_valid_save().is_empty()


func load_game() -> bool:
	var saved := _read_valid_save()
	if saved.is_empty():
		return false
	stats = saved["stats"].duplicate()
	step = int(saved["step"])
	history = saved["history"].duplicate(true)
	return true


func save_game() -> bool:
	var payload := {"version": SAVE_VERSION, "stats": stats, "step": step, "history": history}
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_save_ok = false
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_save_ok = false
		return false
	# O rename só acontece depois da escrita completa, preservando o save anterior.
	var result := DirAccess.rename_absolute(temporary, save_path)
	last_save_ok = result == OK
	return last_save_ok


func wipe_save() -> void:
	for path: String in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	stats = INITIAL_STATS.duplicate()
	step = 0
	history.clear()


func _read_valid_save() -> Dictionary:
	if _cards.is_empty() or not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary:
		return {}
	if parsed.get("version") != SAVE_VERSION:
		return {}
	if not _is_integer(parsed.get("step")):
		return {}
	var saved_step := int(parsed["step"])
	if saved_step < 0 or saved_step > _cards.size():
		return {}
	if not parsed.get("stats") is Dictionary or not parsed.get("history") is Array:
		return {}
	if parsed["history"].size() != saved_step:
		return {}
	var computed: Dictionary = INITIAL_STATS.duplicate()
	var canonical_history: Array = []
	# Reconstituir pelas decisões impede aceitar progresso contraditório ou adulterado.
	for turn in range(saved_step):
		var entry = parsed["history"][turn]
		if not entry is Dictionary or not _is_integer(entry.get("index")):
			return {}
		var index := int(entry["index"])
		var choices: Array = _cards[turn]["choices"]
		if index < 0 or index >= choices.size():
			return {}
		var original: Dictionary = choices[index]
		if entry.get("chapter") != turn + 1 or entry.get("title") != _cards[turn]["title"]:
			return {}
		if entry.get("label") != original["label"] or entry.get("effects") != original["effects"]:
			return {}
		for key in INITIAL_STATS:
			computed[key] = clampi(int(computed[key]) + int(original["effects"][key]), 0, 100)
		canonical_history.append({
			"chapter": turn + 1,
			"title": _cards[turn]["title"],
			"label": original["label"],
			"index": index,
			"effects": original["effects"].duplicate(),
		})
	for key in INITIAL_STATS:
		var value = parsed["stats"].get(key)
		if not _is_integer(value) or int(value) != computed[key]:
			return {}
	return {"version": SAVE_VERSION, "step": saved_step, "stats": computed, "history": canonical_history}


func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
