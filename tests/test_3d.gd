extends SceneTree
## Regras e uma missão real no cenário 3D, com progresso separado do jogador.

const MODEL_PATH: String = "res://scripts/mission_state.gd"
const SCENE_PATH: String = "res://scenes/third_person.tscn"
const MODEL_SAVE: String = "user://test_3d_model.json"
const SCENE_SAVE: String = "user://test_3d_save.json"
var checks: int = 0
var failures: int = 0
var game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FALHOU: " + message)


func clean_save(path: String) -> void:
	for file: String in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


func write_save(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func settle(frames: int = 3) -> void:
	for frame in range(frames):
		await physics_frame
		await process_frame


func _test_model() -> void:
	var model_script: Script = load(MODEL_PATH)
	if model_script == null:
		check(false, "Motor da missão carrega")
		return
	var model = model_script.new()
	model.save_path = MODEL_SAVE
	clean_save(MODEL_SAVE)
	model.start_new()
	check(not model.has_save(), "Sem inventar progresso antes do primeiro salvamento")
	check(not model.transmit(), "Não transmite sem reunir provas")
	check(not model.collect("prova_inexistente"), "Objetivo desconhecido é recusado")
	var first: String = model.evidence_ids[0]
	check(model.collect(first), "Primeira prova é recolhida")
	check(not model.collect(first) and model.collected.size() == 1, "Mesma prova não conta duas vezes")
	check(not model.transmit(), "Uma prova não completa o dossiê")
	model.tick(1.0, 1.0)
	check(model.alert > 0.0 and model.elapsed > 0.0, "Exposição avança perigo e relógio")
	var alert_before: float = model.alert
	model.tick(0.5, 0.0)
	check(model.alert < alert_before, "Afastar-se da patrulha reduz o alerta")
	var elapsed_before: float = model.elapsed
	model.tick(-1.0, 0.0)
	check(is_equal_approx(model.elapsed, elapsed_before), "Intervalo inválido não rebobina a missão")
	for index in range(1, model.evidence_ids.size()):
		check(model.collect(model.evidence_ids[index]), "Outra prova pode ser recolhida")
	check(model.transmit() and model.outcome == "transmitted", "Dossiê completo permite transmissão")
	var finished_elapsed: float = model.elapsed
	model.tick(10.0, 1.0)
	check(is_equal_approx(model.elapsed, finished_elapsed), "O resultado encerra a contagem da missão")
	check(not model.collect(first), "Missão encerrada recusa novas ações")
	model.start_new()
	model.elapsed = model.DURATION - 0.05
	model.tick(0.1, 0.0)
	check(model.outcome == "timed_out" and is_zero_approx(model.remaining()), "Prazo esgotado encerra a missão")
	model.start_new()
	model.alert = 99.9
	model.tick(0.1, 1.0)
	check(model.outcome == "detected", "Alerta total provoca detecção")
	model.start_new()
	model.collect(first)
	model.elapsed = 24.0
	model.alert = 12.0
	model.position = Vector3(-5.0, 0.1, -6.0)
	check(model.save_game() and model.last_save_ok, "Missão é gravada no armazenamento local")
	var restored = model_script.new()
	restored.save_path = MODEL_SAVE
	check(restored.load_game(), "Progresso salvo pode ser retomado")
	check(restored.collected == model.collected and restored.position.is_equal_approx(model.position), "Retomada preserva provas e posição")
	check(is_equal_approx(restored.elapsed, model.elapsed) and is_equal_approx(restored.alert, model.alert), "Retomada preserva prazo e alerta")
	check(not FileAccess.file_exists(MODEL_SAVE + ".tmp"), "Salvamento concluído não deixa arquivo parcial")
	var original_position: Vector3 = restored.position
	for invalid: String in ["{", "null", "[]", "{}", '{"version":999}']:
		write_save(MODEL_SAVE, invalid)
		check(not restored.load_game() and not restored.has_save(), "Progresso corrompido ou incompatível é recusado")
		check(restored.position.is_equal_approx(original_position), "Erro de leitura preserva sessão em memória")
	model.save_game()
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MODEL_SAVE))
	payload["collected"] = [first, first]
	write_save(MODEL_SAVE, JSON.stringify(payload))
	check(not restored.load_game(), "Save com prova duplicada é recusado")
	model.save_game()
	payload = JSON.parse_string(FileAccess.get_file_as_string(MODEL_SAVE))
	payload["position"] = [100000, 0, 0]
	write_save(MODEL_SAVE, JSON.stringify(payload))
	check(not restored.load_game(), "Posição fora do cenário é recusada")
	clean_save(MODEL_SAVE)


func touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = game.controls.get_global_transform_with_canvas() * at
	event.pressed = pressed
	game.controls._input(event)


func drag(index: int, at: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	var transform: Transform2D = game.controls.get_global_transform_with_canvas()
	event.position = transform * at
	event.relative = transform.basis_xform(delta)
	game.controls._input(event)


func _test_scene() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		check(false, "Cena principal em terceira pessoa carrega")
		return
	game = scene.instantiate()
	game.mission.save_path = SCENE_SAVE
	clean_save(SCENE_SAVE)
	root.add_child(game)
	await settle()
	check(game.phase == "home", "Jogo abre no menu")
	check(game.player is CharacterBody3D and game.player.camera is Camera3D, "Personagem físico e câmera são 3D nativos")
	check(game.world.evidence_points.size() == 3 and game.world.patrols.size() >= 1, "Cidade tem três objetivos e patrulhas")
	game.start_mission()
	await settle(8)
	check(game.phase == "playing" and game.controls.enabled, "Início entrega o controle do personagem")
	check(game.player.is_on_floor() and absf(game.player.position.y) < 0.5, "Personagem encontra o chão e não cai pelo cenário")
	check(game.player.global_position.distance_to(game.player.camera.global_position) > 3.0, "Câmera mantém distância de terceira pessoa")
	game.interact()
	check(game.mission.collected.is_empty(), "Interagir longe de uma prova não a recolhe")
	# Um dedo move, outro olha e o terceiro corre: cada função sobrevive às outras.
	var joystick: Vector2 = Vector2(160.0, game.controls.size.y - 160.0)
	var looking: Vector2 = Vector2(game.controls.size.x * 0.70, game.controls.size.y * 0.45)
	touch(11, joystick + Vector2(0, -55), true)
	check(game.controls.move_vector.y < -0.5, "Toque no joystick produz avanço")
	var yaw_before: float = game.player.camera_yaw
	touch(12, looking, true)
	drag(12, looking + Vector2(35, -8), Vector2(35, -8))
	check(not is_equal_approx(game.player.camera_yaw, yaw_before), "Outro dedo gira a câmera sem soltar o joystick")
	var sprint_at: Vector2 = game.controls.sprint_button.get_rect().get_center()
	touch(13, sprint_at, true)
	check(game.controls.sprint_pressed and game.controls.move_vector.length() > 0.5, "Terceiro dedo permite correr enquanto move e olha")
	var start: Vector3 = game.player.global_position
	await settle(35)
	check(game.player.global_position.distance_to(start) > 1.5, "Entrada de toque desloca o corpo pelo mundo físico")
	touch(11, joystick, false)
	check(game.controls.move_vector.is_zero_approx() and game.controls.sprint_pressed, "Soltar joystick não solta o dedo de correr")
	touch(12, looking, false)
	touch(13, sprint_at, false)
	game.controls.reset_controls()
	await settle(8)
	game.pause_mission()
	await settle()
	var stopped: Vector3 = game.player.global_position
	var paused_elapsed: float = game.mission.elapsed
	game.controls.move_vector = Vector2.UP
	await settle(15)
	check(game.phase == "paused" and not game.player.controls_enabled, "Pausa bloqueia controle do personagem")
	check(game.player.global_position.distance_to(stopped) < 0.05, "Personagem não anda durante a pausa (%s → %s)" % [stopped, game.player.global_position])
	check(is_equal_approx(game.mission.elapsed, paused_elapsed), "Prazo não corre durante a pausa")
	game.resume_mission()
	game.controls.reset_controls()
	await settle()
	check(game.phase == "playing" and game.player.controls_enabled, "Retomar devolve o controle")
	check(game.player.is_on_floor() and absf(game.player.global_position.y) < 0.5, "Retomar preserva a colisão com o chão")
	# As provas são coletadas pelos controles reais, respeitando proximidade.
	for point: Dictionary in game.world.evidence_points:
		game.player.reset_player(point["position"] + Vector3(0, 0.1, 0))
		await settle(5)
		game.controls.interacted.emit()
		check(point["id"] in game.mission.collected, "Prova alcançável no cenário: " + point["id"])
		var count: int = game.mission.collected.size()
		game.controls.interacted.emit()
		check(game.mission.collected.size() == count, "Repetir interação não duplica prova")
	check(game.mission.collected.size() == 3, "Dossiê completo é formado em terceira pessoa")
	var remembered: Vector3 = game.player.global_position
	game.show_home()
	await settle()
	check(game.phase == "home", "Menu salva e suspende a missão")
	game.player.reset_player(Vector3(0, 0.1, 16))
	game.continue_mission()
	await settle(4)
	check(game.phase == "playing" and game.mission.collected.size() == 3, "Continuar restaura as provas reunidas")
	check(game.player.global_position.distance_to(remembered) < 0.3, "Continuar recoloca personagem na posição salva")
	game.player.reset_player(game.world.tower_point + Vector3(0, 0.1, 0))
	await settle(5)
	game.controls.interacted.emit()
	await settle()
	check(game.phase == "result" and game.mission.outcome == "transmitted", "Chegar à torre com as provas conclui a missão")
	check(not game.player.controls_enabled, "Resultado impede ações depois do encerramento")
	game.queue_free()
	await settle()
	clean_save(SCENE_SAVE)


func _run() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void:
		printerr("FALHOU: teste 3D excedeu o prazo; a cena não concluiu a validação.")
		quit(1)
	)
	_test_model()
	if not OS.get_cmdline_user_args().has("--model-only"):
		await _test_scene()
	clean_save(MODEL_SAVE)
	clean_save(SCENE_SAVE)
	print("Terceira pessoa 3D: %d verificações, %d falhas." % [checks, failures])
	quit(0 if failures == 0 else 1)
