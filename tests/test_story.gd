extends SceneTree

const Game = preload("res://scripts/story_game.gd")
const TEST_SAVE := "user://test_story_save.json"
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FALHOU: " + message)


func _game():
	var game = Game.new()
	game.save_path = TEST_SAVE
	return game


func _run() -> void:
	var game = _game()
	game.wipe_save()
	_expect(not game.has_save(), "estado inicial não inventa progresso")
	_expect(not game.load_game(), "ausência de save é tratada")
	game.start_new()
	_expect(game.last_save_ok and game.has_save(), "partida nova é salva")
	_expect(game.step == 0 and game.stats == {"voz": 55, "provas": 45, "risco": 20}, "estado inicial")
	_expect(game.get_card()["time"] == "16:00", "narrativa começa às 16h")
	_expect(game.get_ending().is_empty(), "sem final antes de terminar")
	_expect(not game.choose(-1) and not game.choose(3), "escolhas inválidas recusadas")
	_expect(game.step == 0 and game.history.is_empty(), "escolha inválida não altera progresso")
	_expect(game.choose(1), "escolha investigativa aceita")
	_expect(game.stats == {"voz": 50, "provas": 59, "risco": 23}, "efeitos da escolha aplicados")
	_expect(game.step == 1 and game.history[0]["index"] == 1, "histórico registra decisão")
	_expect(not game.get_card()["consequence"].is_empty(), "capítulo seguinte reconhece decisão anterior")
	var restored = _game()
	_expect(restored.load_game(), "progresso pode ser restaurado")
	_expect(restored.step == game.step and restored.stats == game.stats and restored.history == game.history, "restauração completa")
	_expect(restored.get_card() == game.get_card(), "continuação mostra exatamente o mesmo capítulo")

	# Cada percurso usa as mesmas decisões públicas da interface.
	var paths := {
		"silencio": [0, 0, 0, 0, 0, 0, 0, 0],
		"arquivo": [1, 1, 1, 1, 1, 1, 1, 1],
		"eco": [2, 2, 2, 2, 2, 2, 2, 2],
		"amanhecer": [1, 1, 0, 2, 1, 2, 1, 0],
		"exilio": [1, 1, 1, 2, 2, 2, 0, 2],
	}
	var reached: Dictionary = {}
	for expected: String in paths:
		game.start_new()
		for index: int in paths[expected]:
			_expect(game.choose(index), "percurso " + expected + ": decisão executada")
			for stat: String in ["voz", "provas", "risco"]:
				_expect(game.stats[stat] >= 0 and game.stats[stat] <= 100, "indicador no intervalo")
		_expect(game.is_finished() and game.step == 8, "percurso " + expected + " termina após oito capítulos")
		var ending: Dictionary = game.get_ending()
		reached[ending.get("id", "")] = true
		_expect(ending.get("id") == expected, "final " + expected + " alcançável (obtido: " + str(ending.get("id")) + ", estado: " + str(game.stats) + ")")
		_expect(game.get_card().is_empty() and not game.choose(0), "não avança além do final")
		_expect(restored.load_game() and restored.get_ending() == ending, "final é preservado no save")
	_expect(reached.size() == 5, "cinco finais distintos alcançados")

	# Rejeitar corrupção e adulteração sem modificar o estado carregado.
	game.start_new()
	game.choose(0)
	var snapshot: Dictionary = game.stats.duplicate()
	var malformed: Array = ["{", "[]", "null", "{}", '{"version":1,"step":0.5,"stats":{},"history":[]}']
	for text: String in malformed:
		_write_save(text)
		_expect(not game.has_save() and not game.load_game(), "save malformado rejeitado")
		_expect(game.step == 1 and game.stats == snapshot, "erro no save não destrói sessão em memória")
	game.save_game()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	parsed["stats"]["voz"] = 100
	_write_save(JSON.stringify(parsed))
	_expect(not game.load_game(), "indicadores contraditórios rejeitados")
	game.save_game()
	parsed = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	parsed["history"][0]["index"] = 99
	_write_save(JSON.stringify(parsed))
	_expect(not game.load_game(), "índice impossível no histórico rejeitado")
	game.save_game()
	parsed = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	parsed["version"] = 999
	_write_save(JSON.stringify(parsed))
	_expect(not game.load_game(), "versão desconhecida rejeitada")
	game.wipe_save()
	_expect(not FileAccess.file_exists(TEST_SAVE) and not FileAccess.file_exists(TEST_SAVE + ".tmp"), "limpeza remove apenas saves de teste")
	_expect(game.step == 0 and game.history.is_empty(), "limpeza reinicia estado")
	print("Narrativa: %d verificações, %d falhas; 8 capítulos e 5 finais exercitados." % [checks, failures])
	quit(0 if failures == 0 else 1)


func _write_save(text: String) -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
