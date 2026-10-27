extends SceneTree
## Regressões de combate, percepção, diálogo e controles da versão 0.3.
## Nenhum arquivo usado abaixo é o progresso real do jogador.

const MODEL_SAVE: String = "user://test_action_model.json"
const SCENE_SAVE: String = "user://test_action_scene.json"
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


func write_save(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func settle(frames: int = 3) -> void:
	for frame in range(frames):
		await physics_frame
		await process_frame


func _test_model() -> void:
	var script: Script = load("res://scripts/mission_state.gd")
	var model = script.new()
	model.save_path = MODEL_SAVE
	clean_save(MODEL_SAVE)
	check(model.has_method("take_damage"), "Missão implementa saúde e dano")
	if not model.has_method("take_damage"):
		return
	model.start_new()
	check(is_equal_approx(model.health, 100.0), "Nova missão começa com saúde completa")
	check(not model.take_damage(-12.0) and not model.take_damage(NAN), "Dano inválido não cura nem corrompe a vida")
	check(model.take_damage(22.0) and is_equal_approx(model.health, 78.0), "Ataque reduz a saúde")
	check(model.outcome.is_empty(), "Dano não letal mantém a missão jogável")
	model.defeated_ids.append("g1")
	model.talked_ids.append("lia")
	check(model.save_game(), "Vida, inimigos e conversas podem ser salvos")
	var restored = script.new()
	restored.save_path = MODEL_SAVE
	check(restored.load_game() and is_equal_approx(restored.health, 78.0), "Continuar preserva saúde")
	check(restored.defeated_ids == ["g1"] and restored.talked_ids == ["lia"], "Continuar preserva inimigo derrotado e conversa concluída")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MODEL_SAVE))
	for invalid: Variant in [-1, 101, "cheia", null]:
		var bad: Dictionary = payload.duplicate(true)
		bad["health"] = invalid
		write_save(MODEL_SAVE, bad)
		check(not restored.load_game(), "Save com saúde inválida é recusado")
	for field: String in ["defeated_ids", "talked_ids"]:
		for invalid: Variant in ["invalid", ["desconhecido"], ["g1", "g1"] if field == "defeated_ids" else ["lia", "lia"]]:
			var bad: Dictionary = payload.duplicate(true)
			bad[field] = invalid
			write_save(MODEL_SAVE, bad)
			check(not restored.load_game(), "Save rejeita listas inválidas: " + field)
	check(is_equal_approx(restored.health, 78.0), "Erro no save preserva a sessão em memória")
	var old: Dictionary = {
		"version": 1, "collected": [model.evidence_ids[0]], "elapsed": 42.0,
		"alert": 23.0, "outcome": "", "position": [-5.0, 0.1, -6.0],
	}
	write_save(MODEL_SAVE, old)
	check(restored.load_game(), "Progresso da fase 1 v0.2 continua compatível")
	check(restored.collected.size() == 1 and is_equal_approx(restored.elapsed, 42.0), "Migração conserva provas e prazo anteriores")
	check(is_equal_approx(restored.health, 100.0) and restored.defeated_ids.is_empty() and restored.talked_ids.is_empty(), "Migração inicializa os recursos novos sem inventar conquistas")
	check(restored.take_damage(120.0) and restored.outcome == "injured" and is_zero_approx(restored.health), "Perder toda a vida encerra a missão")
	check(not restored.take_damage(12.0), "Missão encerrada recusa dano posterior")
	restored.start_new()
	check(is_equal_approx(restored.health, 100.0) and restored.outcome.is_empty() and restored.defeated_ids.is_empty(), "Recomeçar restaura vida e os inimigos")
	clean_save(MODEL_SAVE)


func _body(parent: Node3D, at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


func _wait_for_windup(guard: CharacterBody3D, frames: int = 120) -> bool:
	for frame in range(frames):
		if guard.windup_remaining > 0.0:
			return true
		await settle(1)
	return false


func _test_enemy_arena() -> void:
	var arena: Node3D = Node3D.new()
	root.add_child(arena)
	_body(arena, Vector3(0, -0.3, 0), Vector3(50, 0.6, 50))
	var target: CharacterBody3D = CharacterBody3D.new()
	target.collision_layer = 2
	target.collision_mask = 1
	target.position = Vector3(20, 0.1, -15)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.9
	capsule.radius = 0.3
	shape.shape = capsule
	shape.position.y = 0.95
	target.add_child(shape)
	arena.add_child(target)
	var guard_script: Script = load("res://scripts/enemy_guard.gd")
	var guard: CharacterBody3D = guard_script.new()
	guard.target = target
	guard.guard_id = "arena"
	guard.position = Vector3(0, 0.1, 7)
	guard.patrol_route.assign([Vector3(0, 0, 7), Vector3(0, 0, 11)])
	var hits: Array = []
	var defeats: Array = []
	guard.struck_player.connect(func(damage: float) -> void: hits.append(damage))
	guard.defeated.connect(func(enemy: Node3D) -> void: defeats.append(enemy))
	arena.add_child(guard)
	guard.set_active(true)
	await settle(5)
	var start: Vector3 = guard.global_position
	await settle(30)
	check(guard.global_position.distance_to(start) > 0.5 and guard.state == "patrol", "Inimigo patrulha o cenário físico quando não vê o jogador")
	target.global_position = guard.global_position + Vector3(0, 0.1, -8)
	guard.visual.rotation.y = 0.0
	var distance_before: float = guard.global_position.distance_to(target.global_position)
	await settle(30)
	check(guard.state == "chase" and guard.global_position.distance_to(target.global_position) < distance_before - 0.5, "Inimigo detecta e persegue o jogador")
	target.global_position = guard.global_position + Vector3(0, 0.1, -1.4)
	var announced: bool = await _wait_for_windup(guard)
	check(announced, "Ataque inimigo tem preparação visível")
	var hit_count: int = hits.size()
	await settle(8)
	check(hits.size() == hit_count, "Golpe não causa dano instantâneo durante a preparação")
	target.global_position += Vector3(8, 0, 0)
	await settle(35)
	check(hits.size() == hit_count, "Sair do alcance evita o golpe anunciado")
	guard.set_active(false)
	guard.global_position = Vector3(0, 0.1, 7)
	target.global_position = Vector3(0, 0.1, 5.6)
	guard.visual.rotation.y = 0.0
	guard.set_active(true)
	announced = await _wait_for_windup(guard)
	check(announced, "Guarda volta a preparar um ataque em alcance")
	await settle(40)
	check(hits.size() == hit_count + 1 and float(hits.back()) > 0.0, "Golpe concluído em alcance causa dano real")
	hit_count = hits.size()
	guard.set_active(false)
	var frozen: Vector3 = guard.global_position
	await settle(45)
	check(hits.size() == hit_count and guard.global_position.is_equal_approx(frozen), "Pausar o inimigo bloqueia deslocamento e golpes")
	guard.global_position = Vector3(0, 0.1, 1.2)
	target.global_position = Vector3(0, 0.1, -1.2)
	guard.visual.rotation.y = 0.0
	var wall: StaticBody3D = _body(arena, Vector3(0, 1.5, 0), Vector3(8, 3, 0.4))
	await settle(3)
	guard.set_active(true)
	await settle(35)
	check(hits.size() == hit_count, "Parede impede o guarda de golpear através dela")
	var health: float = guard.health
	check(not guard.take_hit(25.0, target.global_position) and is_equal_approx(guard.health, health), "Parede também bloqueia o golpe do jogador")
	guard.set_active(false)
	wall.queue_free()
	await settle(3)
	guard.global_position = Vector3(0, 0.1, 1.2)
	target.global_position = Vector3(0, 0.1, -0.8)
	guard.set_active(true)
	guard.set_physics_process(false)
	check(guard.take_hit(25, target.global_position) and guard.health < health, "Golpe em alcance e sem parede fere o inimigo")
	guard.take_hit(25, target.global_position)
	guard.take_hit(25, target.global_position)
	await settle(3)
	check(guard.defeated_flag and guard.health <= 0.0 and defeats.size() == 1, "Inimigo derrotado cai e notifica uma única vez")
	check(not guard.take_hit(25, target.global_position) and defeats.size() == 1, "Inimigo derrotado não recebe novas derrotas")
	check(not guard.active and guard.collision_layer == 0, "Inimigo derrotado para de atacar e deixa de bloquear a passagem")
	arena.queue_free()
	await settle(3)


func _enemy(id: String) -> Node3D:
	for enemy: Node3D in game.enemies:
		if enemy.guard_id == id:
			return enemy
	return null


func _citizen(id: String) -> Node3D:
	for npc: Node3D in game.citizens:
		if npc.npc_id == id:
			return npc
	return null


func _quieten_enemies() -> void:
	for enemy: CharacterBody3D in game.enemies:
		enemy.set_physics_process(false)
		enemy.velocity = Vector3.ZERO


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = game.controls.get_global_transform_with_canvas() * at
	event.pressed = pressed
	game.controls._input(event)


func _finish_dialogue() -> void:
	for line in range(24):
		if game.phase != "dialogue":
			break
		game.advance_dialogue()
	await settle(2)


func _test_scene() -> void:
	var scene: PackedScene = load("res://scenes/third_person.tscn")
	game = scene.instantiate()
	game.mission.save_path = SCENE_SAVE
	clean_save(SCENE_SAVE)
	root.add_child(game)
	await settle(3)
	check(game.has_method("attack") and game.has_method("begin_dialogue"), "Cena implementa combate e conversa no mundo 3D")
	if not game.has_method("attack") or not game.has_method("begin_dialogue"):
		game.queue_free()
		await settle()
		return
	check(game.player.camera_mode == "tactical" and game.player.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Câmera inicial usa visão alta em três quartos")
	game.player.toggle_camera_mode()
	check(game.player.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "É possível voltar à câmera atrás do personagem")
	game.player.toggle_camera_mode()
	check(game.player.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Alternar novamente restaura a visão tática")
	game.start_mission()
	await settle(5)
	check(game.enemies.size() >= 3 and game.citizens.size() >= 3, "Fase preservada tem inimigos e personagens para conversar")
	_quieten_enemies()
	var enemy: Node3D = game.enemies[0]
	var enemy_id: String = enemy.guard_id
	for other: Node3D in game.enemies:
		other.global_position = Vector3(-34, 0.1, 34)
	game.player.reset_player(Vector3(0, 0.1, 16))
	game.player.set_physics_process(false)
	enemy.global_position = Vector3(0, 0.1, 14.5)
	await settle(3)
	var player_health: float = game.mission.health
	enemy.struck_player.emit(12.0)
	check(game.mission.health < player_health, "Golpe do guarda está conectado à vida do jogador na fase")
	game.mission.health = 100.0
	var health: float = enemy.health
	game.controls.attacked.emit()
	check(enemy.health < health, "Botão de ataque acerta o inimigo à frente")
	var after_hit: float = enemy.health
	game.controls.attacked.emit()
	check(is_equal_approx(enemy.health, after_hit), "Recarga impede dois golpes no mesmo instante")
	await settle(40)
	enemy.global_position = Vector3(0, 0.1, 17.5)
	game.attack()
	check(is_equal_approx(enemy.health, after_hit), "Ataque não acerta inimigo atrás do personagem")
	await settle(40)
	enemy.global_position = Vector3(0, 0.1, 10)
	game.attack()
	check(is_equal_approx(enemy.health, after_hit), "Ataque não alcança inimigo distante")
	await settle(40)
	enemy.global_position = Vector3(0, 0.1, 14.2)
	var wall: StaticBody3D = _body(game, Vector3(0, 1.5, 15.2), Vector3(3, 3, 0.2))
	await settle(3)
	game.attack()
	check(is_equal_approx(enemy.health, after_hit), "Ataque da cena respeita paredes")
	wall.queue_free()
	await settle(40)
	for hit in range(4):
		if enemy.defeated_flag:
			break
		enemy.global_position = Vector3(0, 0.1, 14.5)
		game.attack()
		await settle(40)
	check(enemy.defeated_flag and enemy_id in game.mission.defeated_ids, "Combate derrota o guarda e registra o progresso")
	game.mission.take_damage(24.0)
	var saved_health: float = game.mission.health
	game.show_home()
	await settle(3)
	game.continue_mission()
	await settle(5)
	check(is_equal_approx(game.mission.health, saved_health), "Retomar a fase preserva a vida restante")
	var restored_enemy: Node3D = _enemy(enemy_id)
	check(restored_enemy != null and restored_enemy.defeated_flag and not restored_enemy.active, "Guarda derrotado não reaparece ao continuar")
	_quieten_enemies()
	var lia: Node3D = _citizen("lia")
	check(lia != null, "Lia está presente na cidade")
	if lia == null:
		game.queue_free()
		await settle()
		return
	game.player.reset_player(Vector3(-30, 0.1, 25))
	game.begin_dialogue(lia)
	check(game.phase == "playing", "Conversa só começa próximo ao personagem")
	game.player.reset_player(lia.global_position + Vector3(0, 0.1, 1.8))
	await settle(3)
	game.mission.health = 50.0
	game.controls.move_vector = Vector2.UP
	game.begin_dialogue(lia)
	check(game.phase == "dialogue" and game.dialogue_panel.visible, "Personagem próximo abre diálogo integrado à fase")
	check(game.dialogue_lines.size() >= 3, "Diálogo contém uma conversa substancial")
	var meaningful: bool = true
	for line: Dictionary in game.dialogue_lines:
		meaningful = meaningful and not String(line.get("speaker", "")).is_empty() and not String(line.get("text", "")).is_empty()
	check(meaningful, "Cada fala identifica quem está falando e tem texto")
	var time: float = game.mission.elapsed
	var player_position: Vector3 = game.player.global_position
	var health_before: float = game.mission.health
	for active_enemy: Node3D in game.enemies:
		if not active_enemy.defeated_flag:
			active_enemy.global_position = player_position + Vector3(1.5, 0.1, 0)
		active_enemy.struck_player.emit(12.0)
	await settle(15)
	check(is_equal_approx(game.mission.elapsed, time), "Relógio da missão para durante a conversa")
	check(game.player.global_position.is_equal_approx(player_position) and not game.controls.enabled, "Conversa bloqueia movimento e reseta o joystick")
	check(is_equal_approx(game.mission.health, health_before), "Dano atrasado de inimigo não atinge o jogador durante diálogo")
	await _finish_dialogue()
	check(game.phase == "playing" and game.controls.enabled, "Concluir diálogo devolve o controle da fase")
	check("lia" in game.mission.talked_ids and game.mission.health > health_before, "Conversa concluída registra contato e ajuda do personagem")
	_quieten_enemies()
	game.mission.take_damage(10.0)
	health_before = game.mission.health
	game.begin_dialogue(lia)
	await _finish_dialogue()
	check(is_equal_approx(game.mission.health, health_before), "Repetir conversa não permite acumular cura")
	_quieten_enemies()
	var ines: Node3D = _citizen("ines")
	if ines != null:
		game.player.reset_player(ines.global_position + Vector3(0, 0.1, 1.8))
		game.begin_dialogue(ines)
		game.close_dialogue(false)
		check(game.phase == "playing" and "ines" not in game.mission.talked_ids, "Cancelar conversa não marca diálogo como concluído")
	game.pause_mission()
	health_before = game.mission.health
	for active_enemy: Node3D in game.enemies:
		if not active_enemy.defeated_flag:
			active_enemy.global_position = game.player.global_position + Vector3(1.5, 0.1, 0)
		active_enemy.struck_player.emit(12.0)
	await settle(3)
	check(is_equal_approx(game.mission.health, health_before), "Pausa bloqueia dano tardio dos inimigos")
	game.resume_mission()
	_quieten_enemies()
	# Um dedo continua no joystick enquanto o botão de ataque recebe outro.
	var joystick: Vector2 = Vector2(160, game.controls.size.y - 160)
	_touch(51, joystick + Vector2(0, -50), true)
	await settle(40)
	var attack_at: Vector2 = game.controls.attack_button.get_rect().get_center()
	_touch(52, attack_at, true)
	check(game.controls.move_vector.length() > 0.5 and game._attack_cooldown > 0.0, "Multitoque permite atacar sem soltar o movimento")
	_touch(52, attack_at, false)
	check(game.controls.move_vector.length() > 0.5, "Soltar ataque não solta o joystick")
	_touch(51, joystick, false)
	game.controls.reset_controls()
	game.mission.take_damage(1000)
	await settle(3)
	check(game.phase == "result" and game.mission.outcome == "injured", "Vida esgotada encerra a fase com derrota")
	game.start_mission()
	await settle(5)
	check(game.phase == "playing" and is_equal_approx(game.mission.health, 100.0), "Nova tentativa restaura jogador e combate")
	game.queue_free()
	await settle(3)
	clean_save(SCENE_SAVE)


func _run() -> void:
	create_timer(45.0, true, false, true).timeout.connect(func() -> void:
		printerr("FALHOU: validação de ação/diálogo excedeu o prazo.")
		quit(1)
	)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.has("--arena-only"):
		_test_model()
	if not arguments.has("--model-only"):
		await _test_enemy_arena()
		if not arguments.has("--arena-only"):
			await _test_scene()
	clean_save(MODEL_SAVE)
	clean_save(SCENE_SAVE)
	print("Ação e diálogos: %d verificações, %d falhas." % [checks, failures])
	quit(0 if failures == 0 else 1)
